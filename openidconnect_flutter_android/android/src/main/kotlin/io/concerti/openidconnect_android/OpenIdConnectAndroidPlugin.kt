package io.concerti.openidconnect_android

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class OpenIdConnectAndroidPlugin : FlutterPlugin, ActivityAware {
    companion object {
        private const val STORAGE_CHANNEL_NAME = "plugins.concerti.io/openidconnect_secure_storage"
        private const val AUTH_CHANNEL_NAME = "plugins.concerti.io/openidconnect_android_auth"

        private val pendingAuthorizationSessions =
                ConcurrentHashMap<String, PendingAuthorizationSession>()

        internal fun completeAuthorizationSuccess(requestId: String, redirectUrl: String) {
            pendingAuthorizationSessions.remove(requestId)?.result?.success(redirectUrl)
        }

        internal fun completeAuthorizationCanceled(requestId: String) {
            pendingAuthorizationSessions.remove(requestId)?.result?.error(
                    "user_cancelled",
                    "The user canceled interactive authentication.",
                    null,
            )
        }

        internal fun completeAuthorizationFailure(
                requestId: String,
                code: String,
                message: String,
                details: String? = null,
        ) {
            pendingAuthorizationSessions.remove(requestId)?.result?.error(code, message, details)
        }
    }

    private data class PendingAuthorizationSession(
            val plugin: OpenIdConnectAndroidPlugin,
            val result: Result,
    )

    private lateinit var applicationContext: Context
    private lateinit var storageChannel: MethodChannel
    private lateinit var authChannel: MethodChannel
    private lateinit var secureStorage: AndroidSecureStorage
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        secureStorage = AndroidSecureStorage(applicationContext)
        storageChannel = MethodChannel(binding.binaryMessenger, STORAGE_CHANNEL_NAME)
        storageChannel.setMethodCallHandler(::onStorageMethodCall)
        authChannel = MethodChannel(binding.binaryMessenger, AUTH_CHANNEL_NAME)
        authChannel.setMethodCallHandler(::onAuthMethodCall)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        storageChannel.setMethodCallHandler(null)
        authChannel.setMethodCallHandler(null)

        val interruptedRequestIds =
                pendingAuthorizationSessions.entries
                        .filter { it.value.plugin === this }
                        .map { it.key }

        interruptedRequestIds.forEach { requestId ->
            completeAuthorizationFailure(
                    requestId,
                    "engine_detached",
                    "Interactive authentication was interrupted because the plugin detached from the Flutter engine.",
            )
        }
    }

    private fun onStorageMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    secureStorage.initialize()
                    result.success(null)
                }
                "write" -> {
                    secureStorage.write(requiredKey(call), requiredValue(call))
                    result.success(null)
                }
                "read" -> result.success(secureStorage.read(requiredKey(call)))
                "delete" -> {
                    secureStorage.delete(requiredKey(call))
                    result.success(null)
                }
                "containsKey" -> result.success(secureStorage.containsKey(requiredKey(call)))
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error(
                    "secure_storage_error",
                    error.message,
                    error.stackTraceToString(),
            )
        }
    }

    private fun onAuthMethodCall(call: MethodCall, result: Result) {
        if (call.method != "authorizeInteractive") {
            result.notImplemented()
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                    "no_activity",
                    "Interactive authentication requires an attached Android activity.",
                    null,
            )
            return
        }

        if (pendingAuthorizationSessions.values.any { it.plugin === this }) {
            result.error(
                    "auth_in_progress",
                    "An interactive authentication flow is already in progress.",
                    null,
            )
            return
        }

        val authorizationUrl =
                call.argument<String>("authorizationUrl")
                        ?: run {
                            result.error(
                                    "invalid_arguments",
                                    "Missing required argument: authorizationUrl",
                                    null,
                            )
                            return
                        }
        val redirectUrl =
                call.argument<String>("redirectUrl")
                        ?: run {
                            result.error(
                                    "invalid_arguments",
                                    "Missing required argument: redirectUrl",
                                    null,
                            )
                            return
                        }
        val preferEphemeralSession = call.argument<Boolean>("preferEphemeralSession") ?: false
        val requestId = UUID.randomUUID().toString()

        pendingAuthorizationSessions[requestId] = PendingAuthorizationSession(this, result)
        currentActivity.startActivity(
                OpenIdConnectCallbackManagerActivity.createStartIntent(
                        context = currentActivity,
                        requestId = requestId,
                        authorizationUrl = authorizationUrl,
                        redirectUrl = redirectUrl,
                        preferEphemeralSession = preferEphemeralSession,
                ),
        )
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun requiredKey(call: MethodCall): String =
            call.argument<String>("key")
                    ?: throw IllegalArgumentException("Missing required argument: key")

    private fun requiredValue(call: MethodCall): String =
            call.argument<String>("value")
                    ?: throw IllegalArgumentException("Missing required argument: value")
}
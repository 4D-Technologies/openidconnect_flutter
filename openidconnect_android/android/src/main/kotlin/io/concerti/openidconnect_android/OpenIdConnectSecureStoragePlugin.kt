package io.concerti.openidconnect_android

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class OpenIdConnectSecureStoragePlugin : FlutterPlugin, ActivityAware {
    companion object {
        private const val STORAGE_CHANNEL_NAME = "plugins.concerti.io/openidconnect_secure_storage"
        private const val AUTH_CHANNEL_NAME = "plugins.concerti.io/openidconnect_android_auth"

        private var pendingAuthorizationResult: Result? = null

        internal fun completeAuthorizationSuccess(redirectUrl: String) {
            pendingAuthorizationResult?.success(redirectUrl)
            pendingAuthorizationResult = null
        }

        internal fun completeAuthorizationCanceled() {
            pendingAuthorizationResult?.error(
                    "user_cancelled",
                    "The user canceled interactive authentication.",
                    null,
            )
            pendingAuthorizationResult = null
        }

        internal fun completeAuthorizationFailure(
                code: String,
                message: String,
                details: String? = null,
        ) {
            pendingAuthorizationResult?.error(code, message, details)
            pendingAuthorizationResult = null
        }
    }

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
        completeAuthorizationFailure(
                "engine_detached",
                "Interactive authentication was interrupted because the plugin detached from the Flutter engine.",
        )
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

        if (pendingAuthorizationResult != null) {
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

        pendingAuthorizationResult = result
        currentActivity.startActivity(
                OpenIdConnectCallbackManagerActivity.createStartIntent(
                        context = currentActivity,
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

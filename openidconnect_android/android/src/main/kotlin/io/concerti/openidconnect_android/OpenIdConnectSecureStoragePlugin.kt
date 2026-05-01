package io.concerti.openidconnect_android

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class OpenIdConnectSecureStoragePlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "plugins.concerti.io/openidconnect_secure_storage"
    }

    private lateinit var applicationContext: Context
    private lateinit var channel: MethodChannel
    private lateinit var secureStorage: AndroidSecureStorage

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        secureStorage = AndroidSecureStorage(applicationContext)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
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

    private fun requiredKey(call: MethodCall): String =
            call.argument<String>("key")
                    ?: throw IllegalArgumentException("Missing required argument: key")

    private fun requiredValue(call: MethodCall): String =
            call.argument<String>("value")
                    ?: throw IllegalArgumentException("Missing required argument: value")
}

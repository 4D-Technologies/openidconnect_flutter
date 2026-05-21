package io.concerti.openidconnect_android

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.annotation.OptIn
import androidx.appcompat.app.AppCompatActivity
import androidx.browser.auth.AuthTabIntent
import androidx.browser.auth.ExperimentalAuthTab
import androidx.browser.customtabs.ExperimentalEphemeralBrowsing

private sealed interface RedirectCallbackConfig {
    data class CustomScheme(
            val scheme: String,
            val host: String? = null,
            val path: String? = null,
            val port: Int? = null,
    ) : RedirectCallbackConfig

    data class Https(
            val host: String,
            val path: String,
            val port: Int? = null,
    ) : RedirectCallbackConfig
}

private fun parseRedirectCallbackConfig(redirectUrl: String): RedirectCallbackConfig {
    val uri = Uri.parse(redirectUrl)
    val scheme = uri.scheme
    if (scheme.isNullOrEmpty()) {
        throw IllegalArgumentException(
                "Redirect URLs for Android interactive authentication must include a URI scheme. Received: $redirectUrl",
        )
    }

    if (scheme == "http") {
        throw IllegalArgumentException(
                "Android interactive authentication only supports custom-scheme and HTTPS redirect URLs. Received: $redirectUrl",
        )
    }

    if (scheme == "https") {
        val host = uri.host
        if (host.isNullOrEmpty()) {
            throw IllegalArgumentException(
                    "HTTPS redirect URLs must include a host. Received: $redirectUrl",
            )
        }
        val path = uri.path?.takeIf { it.isNotEmpty() } ?: "/"
        return RedirectCallbackConfig.Https(
                host = host,
                path = path,
                port = uri.port.takeIf { uri.port != -1 },
        )
    }

    return RedirectCallbackConfig.CustomScheme(
            scheme = scheme,
            host = uri.host.takeIf { it.isNotEmpty() },
            path = uri.path.takeIf { it.isNotEmpty() },
            port = uri.port.takeIf { uri.port != -1 },
    )
}

private fun redirectUriMatchesConfig(
        redirectUri: Uri,
        callbackConfig: RedirectCallbackConfig,
): Boolean {
    val normalizedPath = redirectUri.path?.takeIf { it.isNotEmpty() } ?: "/"
    val normalizedPort =
            redirectUri.port.takeIf { it != -1 }
                    ?: when (callbackConfig) {
                        is RedirectCallbackConfig.CustomScheme -> null
                        is RedirectCallbackConfig.Https -> 443
                    }

    if (redirectUri.scheme != when (callbackConfig) {
        is RedirectCallbackConfig.CustomScheme -> callbackConfig.scheme
        is RedirectCallbackConfig.Https -> "https"
    }) {
        return false
    }

    return when (callbackConfig) {
        is RedirectCallbackConfig.CustomScheme ->
                (callbackConfig.host == null || redirectUri.host == callbackConfig.host) &&
                        (callbackConfig.path == null || normalizedPath == callbackConfig.path) &&
                        (callbackConfig.port == null || normalizedPort == callbackConfig.port)

        is RedirectCallbackConfig.Https ->
                redirectUri.host == callbackConfig.host &&
                        normalizedPath == callbackConfig.path &&
                        normalizedPort == (callbackConfig.port ?: 443)
    }
}

@OptIn(ExperimentalAuthTab::class, ExperimentalEphemeralBrowsing::class)
class OpenIdConnectCallbackManagerActivity : AppCompatActivity() {
    companion object {
        private const val KEY_AUTHORIZATION_STARTED = "OpenIdConnect.AUTHORIZATION_STARTED"
        private const val KEY_AUTHORIZATION_URL = "OpenIdConnect.AUTHORIZATION_URL"
        private const val KEY_REDIRECT_URL = "OpenIdConnect.REDIRECT_URL"
        private const val KEY_PREFER_EPHEMERAL_SESSION = "OpenIdConnect.PREFER_EPHEMERAL_SESSION"

        fun createStartIntent(
                context: Context,
                authorizationUrl: String,
                redirectUrl: String,
                preferEphemeralSession: Boolean,
        ): Intent =
                Intent(context, OpenIdConnectCallbackManagerActivity::class.java).apply {
                    putExtra(KEY_AUTHORIZATION_URL, authorizationUrl)
                    putExtra(KEY_REDIRECT_URL, redirectUrl)
                    putExtra(KEY_PREFER_EPHEMERAL_SESSION, preferEphemeralSession)
                }
    }

    private var authorizationStarted = false
    private lateinit var authorizationUrl: String
    private lateinit var redirectUrl: String
    private lateinit var callbackConfig: RedirectCallbackConfig
    private var preferEphemeralSession = false

    private val authLauncher =
            AuthTabIntent.registerActivityResultLauncher(this, ::handleAuthTabResult)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val state = savedInstanceState ?: intent.extras
        if (state == null) {
            finishWithError(
                    code = "invalid_state",
                    message = "Interactive authentication could not restore its Android state.",
            )
            return
        }

        try {
            authorizationStarted = state.getBoolean(KEY_AUTHORIZATION_STARTED, false)
            authorizationUrl =
                    state.getString(KEY_AUTHORIZATION_URL)
                            ?: throw IllegalArgumentException(
                                    "Missing authorization URL for interactive authentication.",
                            )
            redirectUrl =
                    state.getString(KEY_REDIRECT_URL)
                            ?: throw IllegalArgumentException(
                                    "Missing redirect URL for interactive authentication.",
                            )
            preferEphemeralSession = state.getBoolean(KEY_PREFER_EPHEMERAL_SESSION, false)
            callbackConfig = parseRedirectCallbackConfig(redirectUrl)
        } catch (error: IllegalArgumentException) {
            finishWithError(
                    code = "invalid_redirect",
                    message = error.message ?: "Invalid interactive authentication redirect URL.",
            )
        }
    }

    override fun onResume() {
        super.onResume()
        if (!::callbackConfig.isInitialized) {
            return
        }

        if (!authorizationStarted) {
            authorizationStarted = true
            try {
                launchAuthTab()
            } catch (error: ActivityNotFoundException) {
                finishWithError(
                        code = "browser_unavailable",
                        message =
                                "Unable to launch the Android browser for interactive authentication.",
                        details = error.stackTraceToString(),
                )
            }
            return
        }

        val redirectUri = intent.data
        if (redirectUri != null) {
            finishWithValidatedSuccess(redirectUri)
        } else {
            finishWithCanceled()
        }
    }

    private fun launchAuthTab() {
        val authTabIntent =
                AuthTabIntent.Builder().setEphemeralBrowsingEnabled(preferEphemeralSession).build()

        when (val config = callbackConfig) {
            is RedirectCallbackConfig.CustomScheme ->
                    authTabIntent.launch(
                            authLauncher,
                            Uri.parse(authorizationUrl),
                            config.scheme,
                    )
            is RedirectCallbackConfig.Https ->
                    authTabIntent.launch(
                            authLauncher,
                            Uri.parse(authorizationUrl),
                            config.host,
                            config.path,
                    )
        }
    }

    private fun handleAuthTabResult(result: AuthTabIntent.AuthResult) {
        when (result.resultCode) {
            AuthTabIntent.RESULT_OK -> {
                val redirectUri = result.resultUri?.toString()
                if (redirectUri.isNullOrEmpty()) {
                    finishWithError(
                            code = "empty_redirect",
                            message =
                                    "Interactive authentication completed without a redirect URL.",
                    )
                } else {
                    finishWithValidatedSuccess(Uri.parse(redirectUri))
                }
            }
            AuthTabIntent.RESULT_CANCELED -> finishWithCanceled()
            AuthTabIntent.RESULT_VERIFICATION_FAILED ->
                    finishWithError(
                            code = "verification_failed",
                            message =
                                    "Android App Link verification failed for the configured HTTPS redirect URL.",
                    )
            AuthTabIntent.RESULT_VERIFICATION_TIMED_OUT ->
                    finishWithError(
                            code = "verification_timed_out",
                            message =
                                    "Android App Link verification timed out for the configured HTTPS redirect URL.",
                    )
            else ->
                    finishWithError(
                            code = "android_auth_error",
                            message = "An unknown Android authentication error occurred.",
                    )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        this.intent = intent
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(KEY_AUTHORIZATION_STARTED, authorizationStarted)
        outState.putString(KEY_AUTHORIZATION_URL, authorizationUrl)
        outState.putString(KEY_REDIRECT_URL, redirectUrl)
        outState.putBoolean(KEY_PREFER_EPHEMERAL_SESSION, preferEphemeralSession)
    }

    private fun finishWithSuccess(redirectUrl: String) {
        OpenIdConnectSecureStoragePlugin.completeAuthorizationSuccess(redirectUrl)
        finish()
    }

    private fun finishWithValidatedSuccess(redirectUri: Uri) {
        if (!redirectUriMatchesConfig(redirectUri, callbackConfig)) {
            finishWithError(
                    code = "invalid_redirect",
                    message = "Interactive authentication returned an unexpected redirect URL.",
                    details = redirectUri.toString(),
            )
            return
        }

        finishWithSuccess(redirectUri.toString())
    }

    private fun finishWithCanceled() {
        OpenIdConnectSecureStoragePlugin.completeAuthorizationCanceled()
        finish()
    }

    private fun finishWithError(code: String, message: String, details: String? = null) {
        OpenIdConnectSecureStoragePlugin.completeAuthorizationFailure(code, message, details)
        finish()
    }
}

class OpenIdConnectCallbackReceiverActivity : AppCompatActivity() {
    override fun onResume() {
        super.onResume()

        startActivity(
                Intent(this, OpenIdConnectCallbackManagerActivity::class.java).apply {
                    data = intent?.data
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
        )
        finish()
    }
}

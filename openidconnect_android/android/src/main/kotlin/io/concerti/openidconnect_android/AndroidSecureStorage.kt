package io.concerti.openidconnect_android

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import java.security.ProviderException

internal class AndroidSecureStorage(
        context: Context,
) {
    companion object {
        private const val DIRECTORY_NAME = "openidconnect_secure_storage"
        private const val FILE_SUFFIX = ".bin"
        private const val ENCODED_FILE_NAME_PREFIX = "_encoded_"
        private const val MASTER_KEY_SUFFIX = "_master_key"
    }

    private val appContext = context.applicationContext
    private val baseDir =
            File(appContext.filesDir, DIRECTORY_NAME).apply {
                if (!exists()) {
                    mkdirs()
                }
            }
    private val strongBoxSupported =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                    appContext.packageManager.hasSystemFeature(
                            PackageManager.FEATURE_STRONGBOX_KEYSTORE,
                    )

    private var useStrongBoxBackedKeystore = strongBoxSupported
    private var cryptographyManager = createCryptographyManager()

    fun initialize() {
        if (!baseDir.exists()) {
            baseDir.mkdirs()
        }
    }

    fun containsKey(key: String): Boolean = fileFor(key).exists()

    fun write(key: String, value: String) {
        val cipher =
                retryWithoutStrongBoxIfNeeded(key) {
                    cryptographyManager.getInitializedCipherForEncryption(masterKeyName(key))
                }
        val encrypted = cryptographyManager.encryptData(value, cipher)
        val file = fileFor(key)
        file.parentFile?.mkdirs()
        file.writeBytes(encrypted.encryptedPayload)
    }

    fun read(key: String): String? {
        val file = fileFor(key)
        if (!file.exists()) {
            return null
        }

        val cipher =
                retryWithoutStrongBoxIfNeeded(key) {
                    cryptographyManager.getInitializedCipherForDecryption(masterKeyName(key), file)
                }
        return cryptographyManager.decryptData(file.readBytes(), cipher)
    }

    fun delete(key: String) {
        cryptographyManager.deleteKey(masterKeyName(key))
        fileFor(key).delete()
    }

    private fun createCryptographyManager(): CryptographyManager = CryptographyManager {
        setUserAuthenticationRequired(false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            setIsStrongBoxBacked(useStrongBoxBackedKeystore)
        }
    }

    private fun fileFor(key: String): File = File(baseDir, fileName(key))

    private fun masterKeyName(key: String): String = fileName(key) + MASTER_KEY_SUFFIX

    private fun fileName(key: String): String {
        if (!key.contains('/') && !key.contains('\\')) {
            return "$key$FILE_SUFFIX"
        }

        val encoded =
                key.toByteArray(Charsets.UTF_8).joinToString(separator = "") {
                    "%02x".format(it.toInt() and 0xff)
                }
        return "$ENCODED_FILE_NAME_PREFIX$encoded$FILE_SUFFIX"
    }

    private inline fun <T> retryWithoutStrongBoxIfNeeded(
            key: String,
            operation: () -> T,
    ): T {
        try {
            return operation()
        } catch (error: ProviderException) {
            if (!useStrongBoxBackedKeystore) {
                throw error
            }
            cryptographyManager.deleteKey(masterKeyName(key))
            useStrongBoxBackedKeystore = false
            cryptographyManager = createCryptographyManager()
            return operation()
        }
    }
}

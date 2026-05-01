package io.concerti.openidconnect_android

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.nio.charset.Charset
import java.security.KeyStore
import java.security.KeyStoreException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface CryptographyManager {
    fun getInitializedCipherForEncryption(keyName: String): Cipher

    fun getInitializedCipherForDecryption(keyName: String, encryptedDataFile: File): Cipher

    fun encryptData(plaintext: String, cipher: Cipher): EncryptedData

    fun decryptData(ciphertext: ByteArray, cipher: Cipher): String

    fun deleteKey(keyName: String)
}

fun CryptographyManager(
        configure: KeyGenParameterSpec.Builder.() -> Unit,
): CryptographyManager = CryptographyManagerImpl(configure)

data class EncryptedData(val encryptedPayload: ByteArray)

private class CryptographyManagerImpl(
        private val configure: KeyGenParameterSpec.Builder.() -> Unit,
) : CryptographyManager {
    companion object {
        private const val KEY_SIZE = 256
        private const val KEY_PREFIX = "_OIDC_"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val ENCRYPTION_BLOCK_MODE = KeyProperties.BLOCK_MODE_GCM
        private const val ENCRYPTION_PADDING = KeyProperties.ENCRYPTION_PADDING_NONE
        private const val ENCRYPTION_ALGORITHM = KeyProperties.KEY_ALGORITHM_AES
        private const val IV_SIZE_IN_BYTES = 12
        private const val TAG_SIZE_IN_BYTES = 16
    }

    override fun getInitializedCipherForEncryption(keyName: String): Cipher {
        val cipher = getCipher()
        val secretKey = getOrCreateSecretKey(keyName)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey)
        return cipher
    }

    override fun getInitializedCipherForDecryption(
            keyName: String,
            encryptedDataFile: File,
    ): Cipher {
        val iv = ByteArray(IV_SIZE_IN_BYTES)
        encryptedDataFile.inputStream().use { stream ->
            val count = stream.read(iv)
            require(count == IV_SIZE_IN_BYTES) {
                "Encrypted payload is missing the initialization vector."
            }
        }
        val cipher = getCipher()
        val secretKey = getOrCreateSecretKey(keyName)
        cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey,
                GCMParameterSpec(TAG_SIZE_IN_BYTES * 8, iv),
        )
        return cipher
    }

    override fun encryptData(plaintext: String, cipher: Cipher): EncryptedData {
        val input = plaintext.toByteArray(Charsets.UTF_8)
        val ciphertext = ByteArray(IV_SIZE_IN_BYTES + input.size + TAG_SIZE_IN_BYTES)
        cipher.doFinal(input, 0, input.size, ciphertext, IV_SIZE_IN_BYTES)
        cipher.iv.copyInto(ciphertext)
        return EncryptedData(ciphertext)
    }

    override fun decryptData(ciphertext: ByteArray, cipher: Cipher): String {
        val iv = ciphertext.sliceArray(IntRange(0, IV_SIZE_IN_BYTES - 1))
        require(iv.contentEquals(cipher.iv)) {
            "Cipher initialization vector did not match the encrypted payload."
        }
        val plaintext =
                cipher.doFinal(
                        ciphertext,
                        IV_SIZE_IN_BYTES,
                        ciphertext.size - IV_SIZE_IN_BYTES,
                )
        return String(plaintext, Charset.forName("UTF-8"))
    }

    override fun deleteKey(keyName: String) {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)
        try {
            keyStore.deleteEntry(KEY_PREFIX + keyName)
        } catch (_: KeyStoreException) {}
    }

    private fun getCipher(): Cipher {
        val transformation = "$ENCRYPTION_ALGORITHM/$ENCRYPTION_BLOCK_MODE/$ENCRYPTION_PADDING"
        return Cipher.getInstance(transformation)
    }

    private fun getOrCreateSecretKey(keyName: String): SecretKey {
        val realKeyName = KEY_PREFIX + keyName
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)
        keyStore.getKey(realKeyName, null)?.let {
            return it as SecretKey
        }

        val paramsBuilder =
                KeyGenParameterSpec.Builder(
                                realKeyName,
                                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                        )
                        .apply {
                            setBlockModes(ENCRYPTION_BLOCK_MODE)
                            setEncryptionPaddings(ENCRYPTION_PADDING)
                            setKeySize(KEY_SIZE)
                            configure()
                        }

        val keyGenerator =
                KeyGenerator.getInstance(
                        KeyProperties.KEY_ALGORITHM_AES,
                        ANDROID_KEYSTORE,
                )
        keyGenerator.init(paramsBuilder.build())
        return keyGenerator.generateKey()
    }
}

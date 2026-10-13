package com.kairumo.padnote.profile

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * 設定檔鎖的生物辨識（Android）。與 Apple 端的 `ProfileBiometrics` 對應。
 *
 * **只認 `BIOMETRIC_STRONG`，不退到裝置密碼**：裝置密碼是共用裝置的人都知道的，
 * 退到它等於整個鎖形同虛設（見 [ProfileLockService]）。失敗或取消就回 false，由呼叫端改問 PIN。
 */
object ProfileBiometrics {
    private const val AUTHENTICATORS = BiometricManager.Authenticators.BIOMETRIC_STRONG

    /** 這台裝置能不能用生物辨識（有硬體、而且使用者註冊過）。 */
    fun isAvailable(activity: FragmentActivity): Boolean =
        BiometricManager.from(activity).canAuthenticate(AUTHENTICATORS) == BiometricManager.BIOMETRIC_SUCCESS

    fun authenticate(
        activity: FragmentActivity,
        title: String,
        cancelLabel: String,
        onResult: (Boolean) -> Unit
    ) {
        if (!isAvailable(activity)) {
            onResult(false)
            return
        }
        val prompt = BiometricPrompt(
            activity, ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onResult(true)
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) = onResult(false)
            }
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setNegativeButtonText(cancelLabel)  // 有負向按鈕就不會出現「改用裝置密碼」
            .setAllowedAuthenticators(AUTHENTICATORS)
            .build()
        prompt.authenticate(info)
    }
}

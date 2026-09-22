package com.kairumo.padnote.crypto

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.FfiUnlockedNotebook
import uniffi.padnote_core.cryptoRecoveryCanUnlock
import uniffi.padnote_core.cryptoUnlock
import uniffi.padnote_core.cryptoUnlockWithRecovery

/**
 * 打開一本已加密的筆記（H-CRYPTO-2 #1，Android）。
 *
 * # 在此之前會發生什麼
 *
 * 建立加密筆記本的流程兩端都做完了，**但沒有任何地方問過密碼** ——
 * 打開一本鎖著的筆記會一路走到「這個套件已加密，需要先解鎖才讀得出內容」
 * 這個錯誤，而使用者沒有任何辦法把密碼交出來。
 *
 * # 兩條路，而且要分得出來
 *
 * 密碼忘了還有復原碼。但**舊版建立的套件，它的復原碼從來沒有被用來包住
 * 金鑰**，所以再怎麼輸入都不會成功。那種情況要在使用者開始輸入**之前**就
 * 講清楚 —— `cryptoRecoveryCanUnlock` 看 manifest 就知道，不必先要他輸入。
 *
 * 與 Apple 端同一套流程、同一組字串、同一個核心。
 */
@Composable
fun UnlockNotebookDialog(
    packagePath: String,
    l10n: (String) -> String,
    onUnlocked: (FfiUnlockedNotebook) -> Unit,
    onDismiss: () -> Unit
) {
    var useRecovery by remember { mutableStateOf(false) }
    var passphrase by remember { mutableStateOf("") }
    var recovery by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    // null = 還沒問過核心。
    var recoveryUsable by remember { mutableStateOf<Boolean?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(packagePath) {
        // 進畫面就問，不要等使用者切過去才發現那條路是死的。
        recoveryUsable = withContext(Dispatchers.IO) { cryptoRecoveryCanUnlock(packagePath) }
    }

    fun attempt(withRecovery: Boolean) {
        if (working) return
        working = true
        error = ""
        scope.launch {
            // **一定要離開主執行緒。** Argon2id 是刻意慢的（64 MiB 記憶體
            // 成本），在主執行緒跑會讓畫面凍住好幾秒，而 Android 的 ANR
            // 監看在五秒就會跳出「應用程式沒有回應」。
            val handle = withContext(Dispatchers.IO) {
                runCatching {
                    if (withRecovery) cryptoUnlockWithRecovery(packagePath, recovery)
                    else cryptoUnlock(packagePath, passphrase)
                }.getOrNull()
            }
            working = false
            if (handle == null) {
                error = if (withRecovery) l10n("unlock_wrong_recovery")
                else l10n("encrypt_wrong_passphrase")
            } else {
                onUnlocked(handle)
                onDismiss()
            }
        }
    }

    AlertDialog(
        onDismissRequest = { if (!working) onDismiss() },
        title = { Text(l10n("unlock_title"), modifier = Modifier.testTag("unlock.title")) },
        text = {
            Column(Modifier.fillMaxWidth()) {
                Text(
                    if (useRecovery) l10n("unlock_recovery_prompt") else l10n("unlock_desc"),
                    style = MaterialTheme.typography.bodySmall
                )
                if (useRecovery) {
                    OutlinedTextField(
                        value = recovery,
                        onValueChange = { recovery = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp)
                            .testTag("unlock.recovery"),
                        // 復原碼全是小寫 —— 自動大寫會讓它對不上。
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.None,
                            autoCorrectEnabled = false
                        ),
                        textStyle = MaterialTheme.typography.bodyMedium
                            .copy(fontFamily = FontFamily.Monospace),
                        minLines = 3,
                        singleLine = false
                    )
                } else {
                    OutlinedTextField(
                        value = passphrase,
                        onValueChange = { passphrase = it },
                        label = { Text(l10n("encrypt_passphrase")) },
                        visualTransformation = PasswordVisualTransformation(),
                        singleLine = true,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp)
                            .testTag("unlock.passphrase")
                    )
                    when (recoveryUsable) {
                        // 復原碼那條路只有在**真的開得了**的時候才給入口。
                        // 給一個按下去注定失敗的入口，比沒有入口更糟。
                        true -> TextButton(
                            onClick = { error = ""; useRecovery = true },
                            modifier = Modifier.testTag("unlock.switch_to_recovery")
                        ) { Text(l10n("unlock_use_recovery")) }
                        false -> Text(
                            l10n("unlock_recovery_unavailable"),
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier
                                .padding(top = 8.dp)
                                .testTag("unlock.recovery_unavailable")
                        )
                        null -> Unit
                    }
                }
                if (error.isNotEmpty()) {
                    Text(
                        error,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .testTag("unlock.error")
                    )
                }
                if (working) {
                    Row(Modifier.padding(top = 12.dp)) {
                        CircularProgressIndicator()
                        Column(Modifier.padding(start = 12.dp)) {
                            Text(l10n("unlock_working"))
                            // 使用者不知道為什麼要等 —— 不講的話，
                            // 慢會被當成當機。
                            Text(
                                l10n("unlock_slow_hint"),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { attempt(useRecovery) },
                enabled = !working &&
                    (if (useRecovery) recovery.isNotBlank() else passphrase.isNotEmpty()),
                modifier = Modifier.testTag(
                    if (useRecovery) "unlock.submit_recovery" else "unlock.submit")
            ) { Text(l10n("encrypt_unlock")) }
        },
        dismissButton = {
            if (useRecovery) {
                TextButton(
                    onClick = { error = ""; useRecovery = false },
                    modifier = Modifier.testTag("unlock.switch_to_passphrase")
                ) { Text(l10n("unlock_use_passphrase")) }
            } else {
                TextButton(
                    onClick = onDismiss,
                    enabled = !working,
                    modifier = Modifier.testTag("unlock.cancel")
                ) { Text(l10n("cancel")) }
            }
        }
    )
}

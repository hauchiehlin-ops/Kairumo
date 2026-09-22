package com.kairumo.padnote.crypto

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.library.NotebookLibrary
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.cryptoCreateEncryptedNotebook
import uniffi.padnote_core.cryptoEncryptionScope

/**
 * 建立加密筆記本（H-CRYPTO，Android）。
 *
 * # 三步，而且不能跳
 *
 * 1. 設密碼
 * 2. **抄下復原碼**
 * 3. **把復原碼輸入回來**
 *
 * 第三步是整個流程的重點，也是最容易被說服拿掉的一步（「使用者嫌麻煩」）。
 * 但無後端就沒有「忘記密碼」信件，也沒有客服能救 —— 復原碼是唯一的後路，
 * 而「我等一下再抄」的使用者，就是後來會失去全部筆記的那一個。
 *
 * **與 Apple 端逐步對應。** 少一步的那一邊會產生一批沒有確認過復原碼的
 * 筆記本，而使用者不會知道那是哪一台裝置建的。
 */
@Composable
fun EncryptedNotebookDialog(
    l: (String) -> String,
    onDismiss: () -> Unit,
    onCreated: (String, String) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboardManager.current

    var step by remember { mutableStateOf(0) } // 0 設密碼 / 1 抄下 / 2 輸回來
    var title by remember { mutableStateOf("") }
    var passphrase by remember { mutableStateOf("") }
    var passphraseAgain by remember { mutableStateOf("") }
    var recovery by remember { mutableStateOf("") }
    var typed by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    var createdId by remember { mutableStateOf("") }

    fun discardIfUnconfirmed() {
        // 復原碼還沒被確認就離開 ⇒ 把剛建好的套件刪掉。
        // 留著的話，使用者手上會有一本他進不去、而且**不知道自己進不去**
        // 的筆記 —— 等到下次打開才發現，那時候連復原碼都沒有了。
        if (createdId.isEmpty()) return
        runCatching {
            File(NotebookLibrary.directory(context), "$createdId.${NotebookLibrary.EXTENSION}")
                .deleteRecursively()
        }
        createdId = ""
    }

    AlertDialog(
        onDismissRequest = {
            discardIfUnconfirmed()
            onDismiss()
        },
        title = { Text(l("encrypt_notebook")) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                when (step) {
                    0 -> {
                        val scopeInfo = cryptoEncryptionScope()
                        Text(l("encrypt_scope_title"), style = MaterialTheme.typography.labelMedium)
                        if (scopeInfo.coversNotes) Text("✓ " + l("encrypt_covers_notes"))
                        if (scopeInfo.coversImages) Text("✓ " + l("encrypt_covers_images"))
                        if (!scopeInfo.coversRecordings) {
                            // **這兩行不能拿掉。** 使用者會據此決定要不要
                            // 把敏感的東西錄進來。
                            //
                            // 而且要講**為什麼** —— 只說「錄音不加密」會讓
                            // 人以為是還沒做。這是拍板的取捨（2026-09-23）：
                            // 加密會讓錄音不再是 VLC 打得開的檔案，
                            // 而那是明講過的承諾。
                            Text(
                                "⚠ " + l("encrypt_not_recordings"),
                                color = MaterialTheme.colorScheme.error
                            )
                            Text(
                                l("encrypt_recordings_why"),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        Text(
                            l("encrypt_only_new"),
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                        OutlinedTextField(
                            value = title,
                            onValueChange = { title = it },
                            label = { Text(l("notebook_title_label")) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
                        )
                        OutlinedTextField(
                            value = passphrase,
                            onValueChange = { passphrase = it },
                            label = { Text(l("encrypt_passphrase")) },
                            singleLine = true,
                            visualTransformation = PasswordVisualTransformation(),
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                        )
                        OutlinedTextField(
                            value = passphraseAgain,
                            onValueChange = { passphraseAgain = it },
                            label = { Text(l("encrypt_passphrase_again")) },
                            singleLine = true,
                            visualTransformation = PasswordVisualTransformation(),
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                        )
                    }
                    1 -> {
                        Text(
                            l("recovery_warning"),
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Text(
                            recovery,
                            fontFamily = FontFamily.Monospace,
                            modifier = Modifier.padding(vertical = 12.dp)
                        )
                        TextButton(onClick = {
                            clipboard.setText(AnnotatedString(recovery))
                        }) { Text(l("recovery_copy")) }
                    }
                    else -> {
                        Text(l("recovery_confirm_prompt"))
                        OutlinedTextField(
                            value = typed,
                            onValueChange = { typed = it },
                            keyboardOptions = KeyboardOptions(
                                capitalization = KeyboardCapitalization.None
                            ),
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                        )
                    }
                }
                if (error.isNotEmpty()) {
                    Text(
                        error,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
        },
        confirmButton = {
            Row {
                if (working) {
                    CircularProgressIndicator(Modifier.padding(8.dp))
                } else {
                    TextButton(onClick = {
                        when (step) {
                            0 -> {
                                error = ""
                                if (passphrase.length < MIN_PASSPHRASE) {
                                    error = l("encrypt_passphrase_too_short")
                                    return@TextButton
                                }
                                if (passphrase != passphraseAgain) {
                                    error = l("encrypt_passphrase_mismatch")
                                    return@TextButton
                                }
                                working = true
                                scope.launch {
                                    val name = title.ifBlank { l("new_note") }
                                    val id = java.util.UUID.randomUUID().toString().lowercase()
                                    val path = File(
                                        NotebookLibrary.directory(context),
                                        "$id.${NotebookLibrary.EXTENSION}"
                                    ).absolutePath
                                    // **Argon2id 刻意很慢**（64 MiB 記憶體成本），
                                    // 在主執行緒上會把畫面凍住好幾秒。
                                    val made = withContext(Dispatchers.Default) {
                                        runCatching {
                                            cryptoCreateEncryptedNotebook(
                                                path, name,
                                                System.currentTimeMillis().toULong(),
                                                passphrase
                                            )
                                        }.getOrNull()
                                    }
                                    working = false
                                    if (made == null) {
                                        error = l("err_core_not_ready")
                                    } else {
                                        createdId = id
                                        recovery = made.recoveryPhrase
                                        step = 1
                                    }
                                }
                            }
                            1 -> step = 2
                            else -> {
                                val normalised = typed.trim().lowercase()
                                    .split(Regex("\\s+")).joinToString(" ")
                                if (normalised != recovery.lowercase()) {
                                    error = l("recovery_mismatch")
                                } else {
                                    onCreated(createdId, title.trim())
                                    createdId = ""
                                    onDismiss()
                                }
                            }
                        }
                    }) {
                        Text(if (step == 1) l("next_step") else l("confirm"))
                    }
                }
            }
        },
        dismissButton = {
            TextButton(onClick = {
                discardIfUnconfirmed()
                onDismiss()
            }) { Text(l("cancel")) }
        }
    )
}

/**
 * 密碼長度下限。
 *
 * 八個字不是安全的密碼，但它是一條**擋得住手滑**的線；
 * 真正的強度來自 Argon2id 的成本參數，而不是這個數字。
 * **與 Apple 端相同** —— 不同的話，同一個密碼在一邊設得起來、另一邊設不起來。
 */
private const val MIN_PASSPHRASE = 8

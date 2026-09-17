package com.kairumo.padnote.ai

import androidx.compose.foundation.layout.height
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.FfiTodoItem

/**
 * 「摘要與待辦」的畫面（工作項 S-20 收尾）。
 *
 * # 三種狀態要分開講
 *
 * 這個畫面最容易做錯的地方不是版面，是**把三種不同的失敗混成一種**：
 *
 * | 狀態 | 使用者該做什麼 |
 * |---|---|
 * | 這台裝置沒有模型 | 什麼也不用做，這裡就是沒有這個功能 |
 * | 模型還沒準備好 | 等一下再來 |
 * | 這則筆記沒有文字 | 先辨識手寫，或先打一些字 |
 *
 * 全部寫成「摘要失敗，請重試」的話，前兩種的人會一直按，而第三種的人
 * 永遠不知道自己缺的是什麼。
 *
 * Apple 端是同一套畫面與同一組語系鍵（見 `NoteIntelligenceSheet.swift`）。
 */
@Composable
fun NoteIntelligenceSheet(
    /** 要整理的文字。由呼叫端提供。 */
    text: String,
    /** BCP-47。 */
    locale: String,
    l: (String) -> String,
    /** 把整理結果插進筆記。 */
    onInsert: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("noteIntelligence", 420.dp)

    val scope = rememberCoroutineScope()
    var running by remember { mutableStateOf(false) }
    var summary by remember { mutableStateOf("") }
    var todos by remember { mutableStateOf<List<FfiTodoItem>>(emptyList()) }
    var failure by remember { mutableStateOf<String?>(null) }
    var hasResult by remember { mutableStateOf(false) }

    val availability = NoteIntelligence.availability()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("ai_summary")) },
        text = {
            Column(
                modifier = Modifier.height(height.value).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    l("ai_summary_desc"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                when (availability) {
                    NoteIntelligence.Availability.UNSUPPORTED -> notice(l("ai_unsupported"))
                    NoteIntelligence.Availability.NOT_READY -> notice(l("ai_not_ready"))
                    NoteIntelligence.Availability.AVAILABLE -> {
                        Button(
                            onClick = {
                                if (text.isBlank()) {
                                    failure = l("ai_nothing_to_summarize")
                                    return@Button
                                }
                                running = true
                                failure = null
                                scope.launch {
                                    // **一定要在背景。** 核心那個呼叫是同步的，
                                    // 模型一次要跑數秒到數十秒 —— 在主執行緒上
                                    // 畫面會整個停住。
                                    val s = withContext(Dispatchers.Default) {
                                        NoteIntelligence.summarize(text, locale)
                                    }
                                    val t = withContext(Dispatchers.Default) {
                                        NoteIntelligence.extractTodos(text, locale)
                                    }
                                    running = false
                                    if (s.ok) summary = s.summary else failure = s.error
                                    // 待辦失敗不覆蓋摘要的錯誤訊息 —— 兩段紅字
                                    // 只會更難讀。
                                    if (t.ok) todos = t.todos
                                    else if (failure == null) failure = t.error
                                    hasResult = s.ok || t.ok
                                }
                            },
                            enabled = !running,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                if (running) {
                                    CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                                }
                                Text(if (running) l("ai_running") else l("ai_run"))
                            }
                        }

                        // 隱私這一句放在按鈕旁邊，不是藏在說明頁裡 ——
                        // 使用者猶豫的那一刻就是按下去之前。
                        Text(
                            l("ai_on_device_note"),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                failure?.let { notice(it) }

                if (summary.isNotBlank()) {
                    Text(l("ai_key_points"), fontWeight = FontWeight.SemiBold)
                    Text(summary)
                }

                if (hasResult) {
                    Text(l("ai_todos"), fontWeight = FontWeight.SemiBold)
                    if (todos.isEmpty()) {
                        // **沒有待辦是正常的答案**，不是錯誤。
                        Text(
                            l("ai_no_todos"),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    } else {
                        todos.forEach { todo ->
                            Text("${if (todo.done) "☑" else "☐"} ${todo.text}")
                        }
                    }
                }
            }
            // 底部的拖曳把手：往下拖變高（S-72）。
            DialogResizeHandle(height, "noteIntelligence")
        },
        confirmButton = {
            if (hasResult) {
                TextButton(onClick = {
                    onInsert(insertableText(summary, todos, l))
                    onDismiss()
                }) { Text(l("ai_insert")) }
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("close")) } }
    )
}

/**
 * 插進筆記的樣子。
 *
 * 用 Markdown 的清單語法而不是純文字：這段會變成筆記裡的一個文字方塊，
 * 而使用者接下來多半會勾掉其中幾條。與 Apple 端產出的字串格式一致 ——
 * 同一則筆記在兩台裝置上插出來的東西要長得一樣。
 */
internal fun insertableText(
    summary: String,
    todos: List<FfiTodoItem>,
    l: (String) -> String
): String {
    val parts = mutableListOf<String>()
    if (summary.isNotBlank()) parts += "## ${l("ai_key_points")}\n\n$summary"
    if (todos.isNotEmpty()) {
        val lines = todos.joinToString("\n") { "- [${if (it.done) "x" else " "}] ${it.text}" }
        parts += "## ${l("ai_todos")}\n\n$lines"
    }
    return parts.joinToString("\n\n")
}

@Composable
private fun notice(message: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(12.dp)
        )
    }
}

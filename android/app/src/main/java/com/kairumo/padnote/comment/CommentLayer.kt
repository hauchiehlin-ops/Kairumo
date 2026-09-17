package com.kairumo.padnote.comment

import androidx.compose.foundation.layout.height
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.canvas.gesturesIf
import java.text.DateFormat

/**
 * 畫布上的討論圖釘層。
 *
 * 座標與其他物件一樣是**頁面點（＝dp）**。圖釘本身不縮放 —— 它是標記不是內容，
 * 跟著頁面縮放的話，頁面一小就點不到了。
 */
@Composable
fun CommentLayer(
    pins: List<CommentPin>,
    pageIndex: Int,
    interactive: Boolean,
    onOpen: (CommentPin) -> Unit,
    onMoved: (CommentPin) -> Unit,
    density: Float
) {
    for (pin in pins) {
        if (pin.pageIndex != pageIndex) continue
        val color = parse(pin.authorColor) ?: Color(0xFF007AFF)
        Box(
            modifier = Modifier
                .offset(pin.x.dp, pin.y.dp)
                // **一定要給 zIndex。**
                //
                // 其餘物件層都用 Modifier.zIndex 表達堆疊順序，而 Compose 是
                // **先比 zIndex、再比宣告順序**。圖釘不給的話預設是 0，
                // 就算寫在最後也會被 zIndex 較大的文字方塊蓋住 ——
                // 看起來像「圖釘沒存到」，實際上它一直在那裡（踩過）。
                //
                // 圖釘是標記不是內容，永遠在最上面。
                .zIndex(PIN_Z_INDEX)
                .size(28.dp)
                .background(
                    // 已解決的圖釘淡化但不隱藏 —— 藏起來的話，使用者找不到
                    // 自己剛標記完的那一串，會以為被刪掉了。
                    if (pin.isResolved) color.copy(alpha = 0.35f) else color,
                    CircleShape
                )
                .border(2.dp, Color.White, CircleShape)
                .gesturesIf(interactive) {
                    pointerInput(pin.id) {
                        detectDragGestures(
                            onDrag = { change, drag ->
                                change.consume()
                                pin.x += drag.x / density
                                pin.y += drag.y / density
                            },
                            onDragEnd = { onMoved(pin) }
                        )
                    }
                }
                .gesturesIf(interactive) {
                    clickable { onOpen(pin) }
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                "${pin.messages.size}",
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

/** 圖釘永遠在最上層。物件的堆疊值來自 ObjectStacking，不會接近這個數。 */
private const val PIN_Z_INDEX = 10_000f

/**
 * 討論串對話框。
 *
 * 與 Apple 端的 `CommentThreadView` 同一組字串鍵與同一套規則：
 * 已解決可以重新開啟、可以刪單則訊息、也可以刪整個圖釘。
 */
@Composable
fun CommentThreadDialog(
    pin: CommentPin,
    languageTag: String,
    currentUserId: String,
    currentUserName: String,
    currentUserColor: String,
    onChanged: (CommentPin) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("commentThread", 260.dp)

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var draft by remember(pin.id) { mutableStateOf("") }
    var revision by remember(pin.id) { mutableStateOf(0) }
    val fmt = remember { DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text(pin.authorName.ifBlank { l("default_user_name") })
                if (pin.isResolved) {
                    Text(
                        l("thread_resolved"),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                key(revision) {
                    if (pin.messages.isEmpty()) {
                        Text(l("comment_empty"), style = MaterialTheme.typography.bodySmall)
                    } else {
                        Column(
                            modifier = Modifier.height(height.value)
                                .verticalScroll(rememberScrollState()),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            for (m in pin.messages) {
                                Column(
                                    Modifier
                                        .fillMaxWidth()
                                        .background(
                                            MaterialTheme.colorScheme.surfaceVariant,
                                            RoundedCornerShape(8.dp)
                                        )
                                        .padding(8.dp)
                                ) {
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Box(
                                            Modifier
                                                .size(10.dp)
                                                .background(
                                                    parse(m.authorColor) ?: Color.Gray,
                                                    CircleShape
                                                )
                                        )
                                        Text(
                                            m.authorName,
                                            style = MaterialTheme.typography.labelSmall,
                                            fontWeight = FontWeight.Bold
                                        )
                                        Text(
                                            fmt.format(m.createdAt),
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    Text(m.text, style = MaterialTheme.typography.bodySmall)
                                    // 只能刪自己的。別人的留言不該被默默拿掉。
                                    if (m.authorId == currentUserId) {
                                        TextButton(onClick = {
                                            pin.messages.remove(m)
                                            revision++
                                            onChanged(pin)
                                        }) {
                                            Text(
                                                l("delete_message"),
                                                style = MaterialTheme.typography.labelSmall
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        // 底部的拖曳把手：往下拖變高。放在捲動容器**外面** ——
                        // 放進去的話把手會跟著內容捲走，捲到一半就再也找不到它。
                        DialogResizeHandle(height, "commentThread")
                    }
                }

                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    placeholder = { Text(l("comment_placeholder")) },
                    modifier = Modifier.fillMaxWidth()
                )

                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    TextButton(
                        enabled = draft.isNotBlank(),
                        onClick = {
                            pin.messages.add(
                                CommentMessage(
                                    id = java.util.UUID.randomUUID().toString(),
                                    authorId = currentUserId,
                                    authorName = currentUserName,
                                    authorColor = currentUserColor,
                                    text = draft.trim(),
                                    createdAt = java.util.Date()
                                )
                            )
                            draft = ""
                            revision++
                            onChanged(pin)
                        }
                    ) { Text(l("comment_send")) }

                    TextButton(onClick = {
                        pin.isResolved = !pin.isResolved
                        revision++
                        onChanged(pin)
                    }) { Text(l(if (pin.isResolved) "reopen" else "resolve")) }

                    TextButton(onClick = { onDelete(); onDismiss() }) {
                        Text(l("delete_comment"), color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("close")) } }
    )
}

@Composable
private inline fun key(revision: Int, content: @Composable () -> Unit) {
    androidx.compose.runtime.key(revision) { content() }
}

private fun parse(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }

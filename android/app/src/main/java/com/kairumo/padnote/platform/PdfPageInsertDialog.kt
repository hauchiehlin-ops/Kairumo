package com.kairumo.padnote.platform

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import android.graphics.BitmapFactory
import java.io.File

/**
 * 挑一份 PDF 的哪一頁插進筆記（Android）。
 *
 * # 為什麼要問「第幾頁」
 *
 * 只插第一頁的話，一份五十頁的講義使用者就拿不到第四十頁 —— 而那通常
 * 正是他想標註的那一頁。
 *
 * # 插進去之後它是什麼
 *
 * **一張圖**，走既有的圖片物件那條路。不是一種新的物件型別 —— 那會要一套
 * 新的同步欄位、一套新的畫布算繪、兩端各一份，而使用者要的「可以移動、
 * 縮放、疊層、刪除」圖片全部都已經會了。
 *
 * 代價是插進去之後不能再選取裡面的文字。對「把一頁講義放進筆記再手寫
 * 標註」這件事來說，那不是使用者會察覺的差別。Apple 端是同一個設計
 * （`PdfPageInsertSheet.swift`）。
 */
@Composable
fun PdfPageInsertDialog(
    l: (String) -> String,
    file: File,
    onDismiss: () -> Unit,
    onPick: (ByteArray) -> Unit
) {
    val pageCount = remember(file) { PageImageRenderer.pdfPageCount(file) }
    var pageIndex by remember(file) { mutableIntStateOf(0) }

    // 預覽與真正插進去的是**同一批位元組** —— 分成兩次算的話，使用者看到
    // 的與插進去的可能不一樣（倍率、底色），而那種差別沒有人會想到要查。
    val png by remember(file, pageIndex) {
        mutableStateOf(PageImageRenderer.renderPdfPage(file, pageIndex))
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("pdf_choose_page")) },
        text = {
            Column(Modifier.fillMaxWidth()) {
                val bytes = png
                if (bytes == null) {
                    Text(
                        l("pdf_render_failed"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    val bitmap = remember(bytes) {
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    }
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = null,
                            modifier = Modifier.fillMaxWidth().height(240.dp)
                                .testTag("pdf_insert.preview")
                        )
                    }
                }

                if (pageCount > 1) {
                    Row(
                        Modifier.fillMaxWidth().padding(top = 10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextButton(
                            onClick = { if (pageIndex > 0) pageIndex-- },
                            enabled = pageIndex > 0,
                            modifier = Modifier.testTag("pdf_insert.prev")
                        ) { Text("◀") }
                        Text("${pageIndex + 1} / $pageCount")
                        TextButton(
                            onClick = { if (pageIndex < pageCount - 1) pageIndex++ },
                            enabled = pageIndex < pageCount - 1,
                            modifier = Modifier.testTag("pdf_insert.next")
                        ) { Text("▶") }
                    }
                }

                Text(
                    String.format(l("pdf_page_range"), maxOf(1, pageCount).toString()),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { png?.let(onPick) },
                enabled = png != null,
                modifier = Modifier.testTag("pdf_insert.confirm")
            ) { Text(l("confirm")) }
        },
        dismissButton = {
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.testTag("pdf_insert.cancel")
            ) { Text(l("cancel")) }
        }
    )
}

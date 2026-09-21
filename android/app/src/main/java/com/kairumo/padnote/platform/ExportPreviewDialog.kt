package com.kairumo.padnote.platform

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import java.io.File

/**
 * 匯出預覽（工作項 S-100）。
 *
 * # 預覽的是**真的那個檔**，不是另外畫一次
 *
 * 匯出流程先把檔案產生出來，這裡再把它開起來給使用者看 —— PDF 走
 * `PdfRenderer`、PNG 走 `BitmapFactory`。所以畫面上看到的與送出去的
 * 是同一份位元組。
 *
 * 另外畫一份「大概長這樣」的預覽是行不通的：Apple 端已經踩過一次，
 * 匯出若在平台層另外算繪，畫出來的東西遲早會跟畫布上的不一樣
 * （那次是整頁空白，見 `Exporter` 的說明）。預覽如果也走那條路，
 * 它會變成一個**看起來沒問題、但不保證等於結果**的畫面 —— 那比沒有預覽更糟。
 *
 * # 取消要把檔案刪掉
 *
 * 檔案在預覽之前就已經落在 cache/exports 了。使用者按取消卻留著它，
 * 下次分享的檔案清單裡會冒出一堆他以為沒有匯出過的東西。
 */
@Composable
fun ExportPreviewDialog(
    file: File,
    format: Exporter.Format,
    languageTag: String,
    onExport: () -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    val pages = remember(file) { renderPreview(file, format) }
    var index by remember { mutableIntStateOf(0) }
    val markdown = remember(file) {
        if (format == Exporter.Format.MARKDOWN) runCatching { file.readText() }.getOrNull()
        else null
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("export_preview")) },
        text = {
            Column(
                Modifier.heightIn(max = 480.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                when {
                    markdown != null -> Text(
                        markdown,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.verticalScroll(rememberScrollState())
                    )

                    pages.isEmpty() -> Text(
                        l("export_preview_unavailable"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )

                    else -> {
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .background(MaterialTheme.colorScheme.surfaceVariant)
                                .padding(8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Image(
                                bitmap = pages[index.coerceIn(0, pages.lastIndex)].asImageBitmap(),
                                contentDescription = null,
                                contentScale = ContentScale.Fit
                            )
                        }
                        if (pages.size > 1) {
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                TextButton(
                                    enabled = index > 0,
                                    onClick = { index-- }
                                ) { Text("‹") }
                                Text(
                                    l("export_preview_page")
                                        .replace("%@", "${index + 1} / ${pages.size}"),
                                    style = MaterialTheme.typography.labelMedium
                                )
                                TextButton(
                                    enabled = index < pages.lastIndex,
                                    onClick = { index++ }
                                ) { Text("›") }
                            }
                        }
                        Text(
                            l("export_preview_hint"),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onExport) { Text(l("export_now")) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

/**
 * 把匯出檔算繪成預覽用的點陣圖。算不出來時回空清單 ——
 * **預覽失敗不等於匯出失敗**，所以 UI 那邊仍然讓使用者送出。
 */
private fun renderPreview(file: File, format: Exporter.Format): List<Bitmap> = runCatching {
    when (format) {
        Exporter.Format.PNG ->
            listOfNotNull(BitmapFactory.decodeFile(file.absolutePath))

        Exporter.Format.PDF -> ParcelFileDescriptor
            .open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            .use { fd ->
                PdfRenderer(fd).use { renderer ->
                    // 只算前幾頁。一本一百頁的筆記全部算繪要好幾秒，
                    // 而使用者按「預覽」想確認的是版面對不對，不是逐頁校對。
                    (0 until minOf(renderer.pageCount, MAX_PREVIEW_PAGES)).map { i ->
                        renderer.openPage(i).use { page ->
                            val scale = PREVIEW_WIDTH_PX.toFloat() / page.width
                            Bitmap.createBitmap(
                                PREVIEW_WIDTH_PX,
                                maxOf(1, (page.height * scale).toInt()),
                                Bitmap.Config.ARGB_8888
                            ).also {
                                // PdfRenderer 不會畫背景，少了這一步透明處
                                // 在深色主題下會變成黑的 —— 看起來像匯出壞了。
                                it.eraseColor(Color.WHITE)
                                page.render(it, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            }
                        }
                    }
                }
            }

        Exporter.Format.MARKDOWN -> emptyList()
    }
}.getOrDefault(emptyList())

private const val MAX_PREVIEW_PAGES = 12
private const val PREVIEW_WIDTH_PX = 720

package com.kairumo.padnote.platform

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogProperties
import android.graphics.BitmapFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * 插入 PDF（Android）：整份匯入成筆記內頁（預設），或只把某一頁插成一張圖。
 *
 * # 整份匯入
 *
 * 每一頁 PDF 成為一頁筆記內頁，等比縮放到整個內頁（位置由核心的 `pdfPagePlacement`
 * 決定，Apple 同一支）。插進去的是**一張圖**，走既有的圖片物件那條路。依核心的圖層規則，
 * 圖片在筆跡**下方**，在 PDF 上寫字、畫螢光筆都看得到。實際的匯入由編輯器做
 * （[onImportAll]，它要插頁、寫中繼資料），這裡只顯示進度。
 *
 * # 為什麼預覽也在背景算
 *
 * 原本預覽是在 `remember { }` 裡算繪 —— 那是 Compose 的組合階段、主執行緒。掃描版 PDF
 * 的頁面常寫成像素大小，「點數 × 2」一頁就是 4960×7016，換一頁就卡一次。
 * Apple 端是同一個設計（`PdfPageInsertSheet.swift`）。
 */
@Composable
fun PdfPageInsertDialog(
    l: (String) -> String,
    file: File,
    onDismiss: () -> Unit,
    onPick: (ByteArray) -> Unit,
    onImportAll: suspend (onProgress: (done: Int, total: Int) -> Unit) -> Unit
) {
    var pageCount by remember(file) { mutableIntStateOf(0) }
    var pageIndex by remember(file) { mutableIntStateOf(0) }
    // 預覽與「只插入這一頁」插進去的是**同一批位元組** —— 分成兩次算的話，使用者看到
    // 的與插進去的可能不一樣（倍率、底色），而那種差別沒有人會想到要查。
    var png by remember(file) { mutableStateOf<ByteArray?>(null) }
    var preview by remember(file) { mutableStateOf<ImageBitmap?>(null) }
    var loading by remember(file) { mutableStateOf(true) }
    var importJob by remember(file) { mutableStateOf<Job?>(null) }
    var imported by remember(file) { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    val importing = importJob != null

    LaunchedEffect(file) {
        pageCount = withContext(Dispatchers.IO) { PageImageRenderer.pdfPageCount(file) }
    }
    LaunchedEffect(file, pageIndex) {
        loading = true
        val (bytes, bitmap) = withContext(Dispatchers.IO) {
            val bytes = PageImageRenderer.renderPdfPage(file, pageIndex)
            bytes to bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size)?.asImageBitmap() }
        }
        png = bytes
        preview = bitmap
        loading = false
    }

    AlertDialog(
        onDismissRequest = { if (!importing) onDismiss() },
        // 匯入到一半點外面關掉的話，背景還在插頁、結果卻沒有人收。
        properties = DialogProperties(dismissOnBackPress = !importing, dismissOnClickOutside = !importing),
        title = { Text(l("pdf_import_title")) },
        text = {
            Column(Modifier.fillMaxWidth()) {
                Box(Modifier.fillMaxWidth().height(240.dp), contentAlignment = Alignment.Center) {
                    val bitmap = preview
                    when {
                        bitmap != null -> Image(
                            bitmap = bitmap,
                            contentDescription = null,
                            modifier = Modifier.fillMaxWidth().height(240.dp).testTag("pdf_insert.preview")
                        )
                        loading -> CircularProgressIndicator()
                        else -> Text(
                            l("pdf_render_failed"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                if (importing) {
                    LinearProgressIndicator(
                        progress = { imported.toFloat() / maxOf(1, pageCount) },
                        modifier = Modifier.fillMaxWidth().padding(top = 12.dp).testTag("pdf_insert.progress")
                    )
                    Text(
                        l("pdf_import_progress")
                            .replace("%1@", minOf(pageCount, imported + 1).toString())
                            .replace("%2@", pageCount.toString()),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 6.dp)
                    )
                } else {
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
                    OutlinedButton(
                        onClick = { png?.let(onPick) },
                        enabled = png != null,
                        modifier = Modifier.fillMaxWidth().padding(top = 6.dp).testTag("pdf_insert.single")
                    ) { Text(l("pdf_import_this_page_only")) }
                    Text(
                        l("pdf_import_hint"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 6.dp)
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (importJob == null) {
                        imported = 0
                        importJob = scope.launch {
                            onImportAll { done, total -> imported = done; pageCount = total }
                            importJob = null
                        }
                    }
                },
                enabled = pageCount > 0 && !importing,
                modifier = Modifier.testTag("pdf_insert.confirm")
            ) { Text(l("pdf_import_all_pages").replace("%@", maxOf(1, pageCount).toString())) }
        },
        dismissButton = {
            TextButton(
                onClick = {
                    importJob?.cancel()
                    importJob = null
                    onDismiss()
                },
                modifier = Modifier.testTag("pdf_insert.cancel")
            ) { Text(l("cancel")) }
        }
    )
}

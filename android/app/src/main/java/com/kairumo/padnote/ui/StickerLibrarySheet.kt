package com.kairumo.padnote.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiPathVerb
import uniffi.padnote_core.stickerCanvasSize
import uniffi.padnote_core.stickerCategories
import uniffi.padnote_core.stickerDrawing
import uniffi.padnote_core.stickerLabelKey

/**
 * 內建貼紙庫（Android）。
 *
 * # 為什麼原本沒有
 *
 * Android **完全沒有貼紙庫** —— 連選單項目都沒有，而 Apple 有。
 * 畫面規格漏了 `editor.insert.stickers` 這一項，所以跨平台對照閘門
 * 從來沒檢查過它：**漏一項的代價就是一個平台少一整個功能，沒有人會發現。**
 * 規格已補上，閘門現在會擋。
 *
 * 40 張貼紙的路徑資料在核心（`ffi_stickers`），Apple 讀同一份 ——
 * 各畫一套的話，兩邊的笑臉不會是同一個笑臉。
 */
@Composable
fun StickerLibrarySheet(
    languageTag: String,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit
) {
    fun l10n(key: String) = LocalizationStrings.localized(key, languageTag)
    val categories = stickerCategories()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l10n("sticker_library")) },
        text = {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = 76.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(420.dp)
                    .testTag("stickers.builtin")
            ) {
                categories.forEach { category ->
                    // 分類標題佔滿一整行 —— 不跨行的話它會擠在第一個格子
                    // 旁邊，看起來像一張沒畫出來的貼紙。
                    item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                        Text(
                            l10n(category.titleKey),
                            style = MaterialTheme.typography.titleSmall,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                    items(category.codes) { code ->
                        StickerCell(code, l10n(stickerLabelKey(code))) { onPick(code) }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("stickers.cancel")) {
                Text(l10n("cancel"))
            }
        }
    )
}

@Composable
private fun StickerCell(code: String, label: String, onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(4.dp)
            // 識別碼掛在整格上，不在裡面的 Text 上 ——
            // 掛在子元素的話，TalkBack 與測試按到的是那行字（S-263）。
            .testTag("stickers.item")
    ) {
        StickerGlyph(code, Modifier.size(48.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            maxLines = 1
        )
    }
}

/** 一張貼紙的預覽。路徑來自核心，與 Apple 端同一份資料。 */
@Composable
fun StickerGlyph(code: String, modifier: Modifier = Modifier, tint: Color = Color.Unspecified) {
    val paths = stickerDrawing(code)
    val unit = stickerCanvasSize()
    val base = if (tint == Color.Unspecified) MaterialTheme.colorScheme.onSurface else tint
    val accent = MaterialTheme.colorScheme.error

    Canvas(modifier) {
        val scale = minOf(size.width, size.height) / unit
        paths.forEach { item ->
            val path = Path()
            var start = Offset.Zero
            item.segs.forEach { s ->
                val x = s.x * scale
                val y = s.y * scale
                when (s.verb) {
                    FfiPathVerb.MOVE -> { path.moveTo(x, y); start = Offset(x, y) }
                    FfiPathVerb.LINE -> path.lineTo(x, y)
                    FfiPathVerb.CURVE -> path.cubicTo(
                        s.c1x * scale, s.c1y * scale,
                        s.c2x * scale, s.c2y * scale,
                        x, y
                    )
                    FfiPathVerb.CLOSE -> { path.lineTo(start.x, start.y); path.close() }
                }
            }
            drawPath(
                path = path,
                color = if (item.accent) accent else base,
                style = Stroke(
                    width = item.width * scale,
                    cap = StrokeCap.Round,
                    join = StrokeJoin.Round
                )
            )
        }
    }
}

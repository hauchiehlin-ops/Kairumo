package com.kairumo.padnote.text

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/**
 * 畫布上的文字方塊圖層（Android）。
 *
 * 外觀規則與 Apple 端一致（`format-spec.md` §6.2）：
 * - `backgroundColorHex == "clear"` 是**透明**，與白色是兩回事
 * - `null` 是「使用者沒設定」，套平台預設
 * - 段落設定（行距、縮排）要真的套上，不只是存著
 *
 * 內距 14 與 Apple 端的 `.padding(14)` 相同 —— 差幾點就會讓同一段文字
 * 在兩個平台換行位置不同，版面就分家了。
 */
const val TEXT_BOX_PADDING = 14f

@Composable
fun TextBoxLayer(
    boxes: List<TextBox>,
    density: Float,
    selectedId: String?,
    onSelect: (String?) -> Unit,
    onChanged: (TextBox) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        for (box in boxes) {
            TextBoxView(
                box = box,
                density = density,
                isSelected = box.id == selectedId,
                onSelect = { onSelect(box.id) },
                onChanged = onChanged
            )
        }
    }
}

@Composable
private fun TextBoxView(
    box: TextBox,
    density: Float,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onChanged: (TextBox) -> Unit
) {
    val shape = RoundedCornerShape(box.cornerRadius.dp)

    Box(
        modifier = Modifier
            .offset(x = box.x.dp, y = box.y.dp)
            .size(width = box.width.dp, height = box.height.dp)
            .clip(shape)
            .background(resolveBackground(box))
            .then(
                if (box.hasBorder) {
                    Modifier.border(
                        width = (box.borderWidth ?: 1.5f).dp,
                        color = parseColor(box.borderColorHex) ?: Color(0x804A90D9),
                        shape = shape
                    )
                } else if (isSelected) {
                    Modifier.border(1.5f.dp, Color(0xFF4A90D9), shape)
                } else {
                    Modifier
                }
            )
            .pointerInput(box.id) {
                detectDragGestures(
                    onDragStart = { onSelect() },
                    onDrag = { change, drag ->
                        change.consume()
                        // 位移要換回 dp：座標存的是與螢幕密度無關的頁面座標。
                        box.x += drag.x / density
                        box.y += drag.y / density
                    },
                    onDragEnd = { onChanged(box) }
                )
            }
            .padding(TEXT_BOX_PADDING.dp)
    ) {
        Text(
            text = box.text,
            style = TextStyle(
                fontSize = box.fontSize.sp,
                fontWeight = if (box.bold) FontWeight.Bold else FontWeight.Normal,
                fontStyle = if (box.italic) FontStyle.Italic else FontStyle.Normal,
                textDecoration = decoration(box),
                color = parseColor(box.textColorHex) ?: Color.Black,
                textAlign = alignment(box.alignment),
                // 行距在 Compose 是 lineHeight（字級 + 行距），
                // 不是 Apple 的「額外間距」—— 換算錯的話行數會不一樣。
                lineHeight = (box.fontSize + (box.lineSpacing ?: 0f)).sp
            ),
            modifier = Modifier.padding(start = (box.paragraphIndent ?: 0f).dp)
        )
    }
}

/** `"clear"` 是哨符不是顏色 —— 不能走 hex 轉換，那會丟掉 alpha 變成黑色。 */
internal fun resolveBackground(box: TextBox): Color = when {
    box.backgroundColorHex == null -> Color.White
    box.isBackgroundClear -> Color.Transparent
    else -> parseColor(box.backgroundColorHex) ?: Color.White
}

internal fun parseColor(hex: String?): Color? {
    val value = hex?.removePrefix("#") ?: return null
    if (value.length != 6) return null
    return runCatching { Color(value.toLong(16) or 0xFF000000L) }.getOrNull()
}

internal fun decoration(box: TextBox): TextDecoration? = when {
    box.underline && box.strikethrough ->
        TextDecoration.combine(listOf(TextDecoration.Underline, TextDecoration.LineThrough))
    box.underline -> TextDecoration.Underline
    box.strikethrough -> TextDecoration.LineThrough
    else -> null
}

internal fun alignment(raw: String): TextAlign = when (raw) {
    "center" -> TextAlign.Center
    "right" -> TextAlign.End
    "justified" -> TextAlign.Justify
    else -> TextAlign.Start
}

package com.kairumo.padnote.text

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.ui.Modifier
import com.kairumo.padnote.canvas.gesturesIf
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.canvas.CanvasRotation
import com.kairumo.padnote.canvas.ResizeHandle
import com.kairumo.padnote.canvas.RotationHandle
import com.kairumo.padnote.canvas.StyleHandle

/**
 * 畫布上的文字方塊圖層（Android）。
 *
 * 外觀規則與 Apple 端一致（`format-spec.md` §6.2）：
 * - `backgroundColorHex == "clear"` 是**透明**，與白色是兩回事
 * - `null` 是「使用者沒設定」，套平台預設
 * - 段落設定（行距、縮排）要真的套上，不只是存著
 *
 * 內距 14 與 Apple 端的 `TextBoxMetrics.padding` 相同 —— 差幾點就會讓同一段
 * 文字在兩個平台換行位置不同，版面就分家了。
 */
const val TEXT_BOX_PADDING = 14f

/**
 * 文字方塊的尺寸下限。與 Apple 端的 `TextBoxMetrics` 是同一組數字。
 *
 * 原本沿用一般物件的 120 × 60。週計畫、月計畫、待辦清單這些樣板的格子
 * 大約是 100 × 45 —— **下限比格子還大，文字方塊放不進任何一格**：
 * 想在「週二」那一欄填一件事，方塊一定會壓到隔壁兩欄。
 * 界線應該是「放得下一個字」，不是 120 點。
 */
const val MIN_TEXT_BOX_WIDTH_DP = 32f
const val MIN_TEXT_BOX_HEIGHT_DP = 24f

/** 小於這個短邊的方塊，內距按比例縮。剛好是舊的高度下限，所以既有筆記一個字都不會重排。 */
private const val FULL_PADDING_THRESHOLD_DP = 60f

/**
 * 這個尺寸的方塊該用多少內距。
 *
 * 小方塊仍然套 14 的話，內距就吃掉整個方塊：40 dp 高的格子扣掉上下各 14
 * 只剩 12 dp，一行 16sp 的字放不下 —— 看起來像「打了字卻沒出現」。
 */
fun textBoxPadding(width: Float, height: Float): Float {
    val shortSide = minOf(width, height)
    return if (shortSide >= FULL_PADDING_THRESHOLD_DP) TEXT_BOX_PADDING
    else maxOf(2f, shortSide / 6f)
}

@Composable
fun TextBoxLayer(
    /**
     * 這一層要不要吃觸控。
     *
     * 手寫模式下一律 false：使用者拿筆想在物件上圈重點，筆畫要到得了
     * 底下的畫布。與 Apple 端 `allowsHitTesting(editorMode != .draw)`
     * 是同一條規則 —— 兩邊不一致的話，同一個人換裝置就會發現
     * 「在 iPad 上圈得到重點，在 Android 上圈不到」。
     */
    interactive: Boolean,
    boxes: List<TextBox>,
    density: Float,
    selectedId: String?,
    onSelect: (String?) -> Unit,
    /**
     * 開啟這個方塊的排版面板。
     *
     * 原本**只有新增時**才開得起來 —— 建好之後關掉，就再也改不到字級、
     * 顏色、邊框與段落設定了。形狀與圖片都有這顆鈕，文字方塊沒有。
     */
    onEditStyle: (TextBox) -> Unit,
    onChanged: (TextBox) -> Unit,
    onMoved: ((box: TextBox, dx: Float, dy: Float) -> Unit)? = null,
    /**
     * 這個物件的堆疊 z 值。跨型別共用同一份順序（見 ObjectStacking）。
     */
    zIndexOf: (String) -> Float,
    modifier: Modifier = Modifier
) {
    // **不包一層自己的 Box。**
    //
    // Compose 的 zIndex 只在**同一個父容器的兄弟之間**生效。每一層各包一個 Box
    // 的話，圖片的 zIndex 只跟圖片比、文字的只跟文字比 —— 跨型別永遠是
    // 「圖片一定在文字下面」，圖層面板就排不動。
    // 直接把物件發到呼叫端的 Box 裡，它們才是彼此的兄弟。
        // 鎖定在畫布上的物件不接收觸控（見 canvas/ObjectLock.kt）。
        val lockedIds = com.kairumo.padnote.canvas.LocalLockedObjectIds.current
        for (box in boxes) {
            androidx.compose.runtime.key(box.id) {
                TextBoxView(
                    zIndex = zIndexOf(box.id),
                    interactive = interactive && box.id !in lockedIds,
                    box = box,
                    density = density,
                    isSelected = box.id == selectedId,
                    onSelect = { onSelect(box.id) },
                    onEditStyle = { onEditStyle(box) },
                    onChanged = onChanged,
                    onMoved = onMoved
                )
            }
        }
}

@Composable
private fun TextBoxView(
    /** 堆疊 z 值，見 ObjectStacking。 */
    zIndex: Float,
    /** 見 TextBoxLayer 的說明。 */
    interactive: Boolean,
    box: TextBox,
    density: Float,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onEditStyle: () -> Unit,
    onChanged: (TextBox) -> Unit,
    onMoved: ((box: TextBox, dx: Float, dy: Float) -> Unit)? = null
) {
    // 連續模式：拖到哪一頁就歸哪一頁（單頁模式為 null，照舊夾在本頁）。
    val crossing by androidx.compose.runtime.rememberUpdatedState(com.kairumo.padnote.canvas.LocalPageCrossing.current)
    val currentBox by androidx.compose.runtime.rememberUpdatedState(box)
    val shape = RoundedCornerShape(box.cornerRadius.dp)
    var startX by remember { mutableFloatStateOf(box.x) }
    var startY by remember { mutableFloatStateOf(box.y) }
    var liveX by remember(box.id, box.x) { mutableFloatStateOf(box.x) }
    var liveY by remember(box.id, box.y) { mutableFloatStateOf(box.y) }
    var liveWidth by remember(box.id, box.width) { mutableFloatStateOf(box.width) }
    var liveHeight by remember(box.id, box.height) { mutableFloatStateOf(box.height) }
    var liveRotation by remember(box.id, box.rotationDegrees) { mutableFloatStateOf(box.rotationDegrees ?: 0f) }
    val rotation = CanvasRotation.normalized(liveRotation)

    // 外層只負責定位，**不旋轉** —— 旋轉把手要掛在這一層，
    // 放進旋轉裡的話拖曳算出的角度會疊加自身旋轉，物件會失控加速。
    Box(modifier = Modifier.offset(x = liveX.dp, y = liveY.dp).zIndex(zIndex)) {

    Box(
        modifier = Modifier
            .width(liveWidth.dp)
            .heightIn(min = liveHeight.dp)
            .graphicsLayer { rotationZ = rotation }
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
                    Modifier.border(1.5f.dp, MaterialTheme.colorScheme.primary, shape)
                } else {
                    Modifier
                }
            )
            // 點一下＝選取。原本**只有拖曳**才會選到 —— 使用者點一下沒反應，
            // 就以為這個方塊不能編輯（形狀與圖片都是點一下就選到）。
            .gesturesIf(interactive) { pointerInput(box.id) {
                detectTapGestures(
                    onTap = { onSelect() },
                    onDoubleTap = { onEditStyle() }
                )
            } }
            .gesturesIf(interactive) { pointerInput(box.id) {
                var accX = 0f
                var accY = 0f
                detectDragGestures(
                    onDragStart = {
                        val b = currentBox
                        startX = b.x
                        startY = b.y
                        accX = 0f
                        accY = 0f
                        liveX = b.x
                        liveY = b.y
                        onSelect()
                        crossing?.began?.invoke()
                    },
                    onDragCancel = { crossing?.ended?.invoke() },
                    onDrag = { change, drag ->
                        change.consume()
                        accX += drag.x
                        accY += drag.y
                        val rad = liveRotation * kotlin.math.PI / 180.0
                        val c = kotlin.math.cos(rad).toFloat()
                        val sn = kotlin.math.sin(rad).toFloat()
                        // 位移要換回 dp：座標存的是與螢幕密度無關的頁面座標。
                        liveX = startX + (accX * c - accY * sn) / density
                        liveY = startY + (accX * sn + accY * c) / density
                        currentBox.x = liveX
                        currentBox.y = liveY
                    },
                    onDragEnd = {
                        val b = currentBox
                        // 拖出可列印範圍的物件推回邊界（S-85）；連續模式下中心拖到哪一頁就歸哪一頁。
                        // 規則在核心，與 Apple 的 PrintableArea.land 同一份。
                        val landed = com.kairumo.padnote.canvas.landObject(
                            b.id, liveX, liveY, liveWidth, liveHeight, crossing)
                        liveX = landed.x
                        liveY = landed.y
                        b.x = landed.x
                        b.y = landed.y
                        // 換頁時不算「在這一頁上平移」：跟著方塊走的東西留在原頁。
                        val dx = b.x - startX
                        val dy = b.y - startY
                        if (landed.page == null && (dx != 0f || dy != 0f)) {
                            onMoved?.invoke(b, dx, dy)
                        }
                        onChanged(b)
                        landed.page?.let { crossing?.moved?.invoke(b.id, it) }
                        crossing?.ended?.invoke()
                    }
                )
            } }
            .padding(textBoxPadding(liveWidth, liveHeight).dp)
    ) {
        // 有逐字格式時，每一段的字級、字型、顏色與醒目提示寫在 AnnotatedString 裡，
        // 底下的 TextStyle 是方塊層級的預設。
        Text(
            text = RichText.annotated(box),
            style = TextStyle(
                fontSize = box.fontSize.sp,
                fontFamily = resolveFontFamily(box.fontFamily),
                fontWeight = if (box.bold) FontWeight.Bold else FontWeight.Normal,
                fontStyle = if (box.italic) FontStyle.Italic else FontStyle.Normal,
                textDecoration = decoration(box),
                color = parseColor(box.textColorHex) ?: Color.Black,
                textAlign = alignment(box.alignment),
                // 行距在 Compose 是 lineHeight（行高），Apple 的是「額外間距」。
                //
                // 沒設額外間距時**不指定行高**，讓字型自己的行高生效：之前一律 = 字級（1.0 倍），
                // 西文勉強夠用，泰文的上下母音與聲調符號會疊到上一行、韓文與日文的行也擠在一起。
                // 設了額外間距就是「字型自然行高 + 額外間距」，與 Apple 同義（自然行高以 1.2 倍估）。
                lineHeight = box.lineSpacing
                    ?.let { (box.fontSize * 1.2f + it).sp }
                    ?: androidx.compose.ui.unit.TextUnit.Unspecified
            ),
            modifier = Modifier.padding(start = (box.paragraphIndent ?: 0f).dp)
        )
    }

        if (isSelected && interactive) {
            // 左下角的樣式鈕：字級、顏色、邊框、圓角、段落全部在那裡。
            StyleHandle(
                widthDp = liveWidth,
                heightDp = liveHeight,
                onTap = onEditStyle,
                objectId = box.id
            )

            // 右下角的縮放把手。原本 Android 完全沒有 —— 文字方塊的大小
            // 只能進編輯面板調，而 Apple 端畫布上就有把手。
            ResizeHandle(
                widthDp = liveWidth,
                heightDp = liveHeight,
                density = density,
                onResize = { dw, dh ->
                    liveWidth = maxOf(MIN_TEXT_BOX_WIDTH_DP, liveWidth + dw)
                    liveHeight = maxOf(MIN_TEXT_BOX_HEIGHT_DP, liveHeight + dh)
                    currentBox.width = liveWidth
                    currentBox.height = liveHeight
                },
                onCommit = {
                    currentBox.width = liveWidth
                    currentBox.height = liveHeight
                    onChanged(currentBox)
                }
            )

            RotationHandle(
                degrees = rotation,
                widthDp = liveWidth,
                heightDp = liveHeight,
                density = density,
                onRotate = {
                    liveRotation = it
                    currentBox.rotationDegrees = it
                },
                onCommit = {
                    currentBox.rotationDegrees = liveRotation
                    onChanged(currentBox)
                }
            )
        }
    }
}

internal fun resolveFontFamily(family: String?): androidx.compose.ui.text.font.FontFamily = when (family?.lowercase()) {
    "serif", "georgia", "times new roman" -> androidx.compose.ui.text.font.FontFamily.Serif
    "monospace", "mono", "courier", "menlo" -> androidx.compose.ui.text.font.FontFamily.Monospace
    "sans-serif", "sans", "system" -> androidx.compose.ui.text.font.FontFamily.SansSerif
    "cursive" -> androidx.compose.ui.text.font.FontFamily.Cursive
    else -> androidx.compose.ui.text.font.FontFamily.Default
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

package com.kairumo.padnote.text

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitTouchSlopOrCancellation
import androidx.compose.foundation.gestures.drag
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import kotlin.math.abs
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
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
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.ui.LocalAppLanguage
import com.kairumo.padnote.canvas.LocalObjectReorder
import com.kairumo.padnote.canvas.LocalObjectClipboard
import com.kairumo.padnote.canvas.ObjectStacking
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
    onDelete: ((TextBox) -> Unit)? = null,
    /** 目前就地編輯（即點即書）的方塊 id；與 Apple 的 `inlineEditingTextId` 同義。 */
    inlineEditingId: String? = null,
    /** 點選方塊（打字模式）時開始就地編輯。 */
    onInlineEditStart: (String) -> Unit = {},
    /** 失去焦點時結束就地編輯；空白方塊由呼叫端移除。 */
    onInlineEditEnd: (TextBox) -> Unit = {},
    /**
     * 這個物件的堆疊 z 值。跨型別共用同一份順序（見 ObjectStacking）。
     */
    zIndexOf: (String) -> Float,
    revision: Int = 0,
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
                    revision = revision,
                    onSelect = { onSelect(box.id) },
                    onEditStyle = { onEditStyle(box) },
                    onChanged = onChanged,
                    onMoved = onMoved,
                    onDelete = onDelete,
                    isEditing = box.id == inlineEditingId,
                    onStartEdit = { onInlineEditStart(box.id) },
                    onEndEdit = onInlineEditEnd
                )
            }
        }
}

@Composable
private fun TextActionButton(
    icon: String,
    title: String,
    backgroundColor: Color,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(7.dp))
            .background(backgroundColor)
            .clickable(onClick = onClick)
            .padding(horizontal = 9.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(icon, fontSize = 11.sp, color = Color.White)
        Text(
            title,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
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
    revision: Int = 0,
    onSelect: () -> Unit,
    onEditStyle: () -> Unit,
    onChanged: (TextBox) -> Unit,
    onMoved: ((box: TextBox, dx: Float, dy: Float) -> Unit)? = null,
    onDelete: ((TextBox) -> Unit)? = null,
    isEditing: Boolean = false,
    onStartEdit: () -> Unit = {},
    onEndEdit: (TextBox) -> Unit = {}
) {
    // 連續模式：拖到哪一頁就歸哪一頁（單頁模式為 null，照舊夾在本頁）。
    val crossing by androidx.compose.runtime.rememberUpdatedState(com.kairumo.padnote.canvas.LocalPageCrossing.current)
    val currentBox by androidx.compose.runtime.rememberUpdatedState(box)
    val language = LocalAppLanguage.current
    val reorder = LocalObjectReorder.current
    val clipboard = LocalObjectClipboard.current
    val editorMode = com.kairumo.padnote.canvas.LocalEditorMode.current
    val isCanvasNavigating = com.kairumo.padnote.canvas.LocalCanvasNavigating.current
    val isTypeMode = editorMode == com.kairumo.padnote.canvas.EditorMode.TYPE
    val selectedNow by androidx.compose.runtime.rememberUpdatedState(isSelected)
    val typeModeNow by androidx.compose.runtime.rememberUpdatedState(isTypeMode)
    val onSelectNow by androidx.compose.runtime.rememberUpdatedState(onSelect)
    val onStartEditNow by androidx.compose.runtime.rememberUpdatedState(onStartEdit)
    var contextMenuOpen by remember(box.id) { mutableStateOf(false) }
    var orderMenuOpen by remember(box.id) { mutableStateOf(false) }
    val shape = RoundedCornerShape(box.cornerRadius.dp)
    var startX by remember(box.id, box.x, revision) { mutableFloatStateOf(box.x) }
    var startY by remember(box.id, box.y, revision) { mutableFloatStateOf(box.y) }
    var liveX by remember(box.id, box.x, revision) { mutableFloatStateOf(box.x) }
    var liveY by remember(box.id, box.y, revision) { mutableFloatStateOf(box.y) }
    var liveWidth by remember(box.id, box.width, revision) { mutableFloatStateOf(box.width) }
    var liveHeight by remember(box.id, box.height, revision) { mutableFloatStateOf(box.height) }
    var liveRotation by remember(box.id, box.rotationDegrees, revision) { mutableFloatStateOf(box.rotationDegrees ?: 0f) }
    val rotation = CanvasRotation.normalized(liveRotation)
    var accX by remember { mutableFloatStateOf(0f) }
    var accY by remember { mutableFloatStateOf(0f) }

    val finishDrag: () -> Unit = {
        val b = currentBox
        val landed = com.kairumo.padnote.canvas.landObject(
            b.id, liveX, liveY, liveWidth, liveHeight, crossing)
        liveX = landed.x
        liveY = landed.y
        b.x = landed.x
        b.y = landed.y
        val dx = b.x - startX
        val dy = b.y - startY
        if (landed.page == null && (dx != 0f || dy != 0f)) {
            onMoved?.invoke(b, dx, dy)
        }
        onChanged(b)
        landed.page?.let { crossing?.moved?.invoke(b.id, it) }
        crossing?.ended?.invoke()
    }

    val topPadding = 56f
    val horizontalPadding = 24f
    val bottomPadding = 24f

    // 外層自帶安全邊界，不用負的 offset，避免把手與動作列被 Compose 視圖邊界裁切裁掉
    Box(
        modifier = Modifier
            .offset(x = (liveX - horizontalPadding).dp, y = (liveY - topPadding).dp)
            .size((liveWidth + horizontalPadding * 2f).dp, (liveHeight + topPadding + bottomPadding).dp)
            .zIndex(zIndex)
    ) {

    Box(
        modifier = Modifier
            .offset(x = horizontalPadding.dp, y = topPadding.dp)
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
            // 點一下＝選取，拖曳＝搬移（完全對齊 iPad）
            .gesturesIf(interactive && !isCanvasNavigating) {
                // 不以 isSelected／isTypeMode 當鍵（改讀最新值）：拖曳一開始就 onSelect()，選取狀態一變
                // 這段手勢就被重啟、拖到一半被取消 —— 打字模式下文字方塊完全拖不動（實機回報）。
                pointerInput(box.id, isCanvasNavigating) {
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        val isSelected = selectedNow
                        val isTypeMode = typeModeNow
                        val onSelect = onSelectNow
                        val onStartEdit = onStartEditNow
                        if (isCanvasNavigating) return@awaitEachGesture
                        // 手繪模式下觸控筆直接繪圖，不拖曳方塊
                        if (down.type == androidx.compose.ui.input.pointer.PointerType.Stylus && !isTypeMode) return@awaitEachGesture

                        // 手繪模式下未選取時：點擊僅選取，不直接拖曳，防止手繪或雙指導航時誤移動背景方塊
                        if (!isTypeMode && !isSelected) {
                            val up = waitForUpOrCancellation()
                            if (up != null) {
                                onSelect()
                            }
                            return@awaitEachGesture
                        }

                        var accDragX = 0f
                        var accDragY = 0f
                        val dragChange = awaitTouchSlopOrCancellation(down.id) { change, over ->
                            change.consume()
                            accDragX = over.x
                            accDragY = over.y
                        }
                        if (dragChange != null) {
                            val b = currentBox
                            startX = b.x
                            startY = b.y
                            accX = accDragX
                            accY = accDragY
                            liveX = b.x
                            liveY = b.y
                            onSelect()
                            crossing?.began?.invoke()
                            val rad = liveRotation * kotlin.math.PI / 180.0
                            val c = kotlin.math.cos(rad).toFloat()
                            val sn = kotlin.math.sin(rad).toFloat()
                            liveX = startX + (accX * c - accY * sn) / density
                            liveY = startY + (accX * sn + accY * c) / density
                            b.x = liveX
                            b.y = liveY

                            var cancelled = false
                            drag(dragChange.id) { change ->
                                if (isCanvasNavigating) {
                                    cancelled = true
                                    return@drag
                                }
                                // 先讀位移再 consume：consume 之後 positionChange() 一律回 0，方塊就拖不動。
                                val delta = change.positionChange()
                                change.consume()
                                accX += delta.x
                                accY += delta.y
                                liveX = startX + (accX * c - accY * sn) / density
                                liveY = startY + (accX * sn + accY * c) / density
                                b.x = liveX
                                b.y = liveY
                            }
                            if (cancelled) {
                                liveX = startX
                                liveY = startY
                                b.x = startX
                                b.y = startY
                                crossing?.ended?.invoke()
                            } else {
                                finishDrag()
                            }
                        } else {
                            onSelect()
                            // 打字模式點方塊＝就地編輯（對齊 Apple）。
                            if (isTypeMode) onStartEdit()
                        }
                    }
                }
            }
            .padding(textBoxPadding(liveWidth, liveHeight).dp)
    ) {
        // 有逐字格式時，每一段的字級、字型、顏色與醒目提示寫在 AnnotatedString 裡，
        // 底下的 TextStyle 是方塊層級的預設。
        val inlineStyle = TextStyle(
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
        )
        if (isEditing && interactive) {
            val focusRequester = remember(box.id) { FocusRequester() }
            val keyboard = LocalSoftwareKeyboardController.current
            var field by remember(box.id) {
                mutableStateOf(TextFieldValue(box.text, TextRange(box.text.length)))
            }
            var hadFocus by remember(box.id) { mutableStateOf(false) }
            LaunchedEffect(box.id) {
                focusRequester.requestFocus()
                keyboard?.show()
            }
            BasicTextField(
                value = field,
                onValueChange = { next ->
                    val b = currentBox
                    val old = b.text
                    field = next
                    if (next.text != old) {
                        b.text = next.text
                        RichText.adjustRuns(b, old)
                        onChanged(b)
                    }
                },
                textStyle = inlineStyle,
                // 方塊跟著內容長高（對齊 Apple）：無框的即點即書方塊也會縮回，其餘只增不減。
                onTextLayout = { result ->
                    val b = currentBox
                    val needed = RuledWriting.boxHeight(result.size.height / density)
                    val target = if (b.hasBorder) maxOf(b.height, needed) else needed
                    if (abs(target - b.height) > 0.5f) {
                        b.height = target
                        onChanged(b)
                    }
                },
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester)
                    .onFocusChanged { state ->
                        if (state.isFocused) hadFocus = true
                        else if (hadFocus) onEndEdit(currentBox)
                    }
            )
        } else {
        Text(
            text = RichText.annotated(box),
            style = inlineStyle
        )
        }
    }

        if (isSelected && interactive) {
            // 🌟 頂部精準拖曳把手（膠囊造型 ≡）
            Box(
                modifier = Modifier
                    .offset(x = (horizontalPadding + liveWidth / 2f - 19f).dp, y = (topPadding - 20f).dp)
                    .size(38.dp, 16.dp)
                    .shadow(2.dp, RoundedCornerShape(8.dp))
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.9f))
                    .gesturesIf(interactive && !isCanvasNavigating) {
                        pointerInput(box.id, isCanvasNavigating) {
                            detectDragGestures(
                                onDragStart = {
                                    if (isCanvasNavigating) return@detectDragGestures
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
                                onDragCancel = {
                                    liveX = startX
                                    liveY = startY
                                    currentBox.x = startX
                                    currentBox.y = startY
                                    crossing?.ended?.invoke()
                                },
                                onDrag = { change, drag ->
                                    if (isCanvasNavigating) {
                                        liveX = startX
                                        liveY = startY
                                        currentBox.x = startX
                                        currentBox.y = startY
                                        crossing?.ended?.invoke()
                                        return@detectDragGestures
                                    }
                                    change.consume()
                                    accX += drag.x
                                    accY += drag.y
                                    val rad = liveRotation * kotlin.math.PI / 180.0
                                    val c = kotlin.math.cos(rad).toFloat()
                                    val sn = kotlin.math.sin(rad).toFloat()
                                    liveX = startX + (accX * c - accY * sn) / density
                                    liveY = startY + (accX * sn + accY * c) / density
                                    currentBox.x = liveX
                                    currentBox.y = liveY
                                },
                                onDragEnd = finishDrag
                            )
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "≡",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // 🌟 選取時的動作列：編輯、圖層順序、剪下、複製、刪除（完全對齊 iPad）
            Row(
                modifier = Modifier
                    .offset(x = (horizontalPadding + 6f).dp, y = (topPadding - 54f).dp)
                    .shadow(5.dp, RoundedCornerShape(10.dp))
                    .clip(RoundedCornerShape(10.dp))
                    .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.95f))
                    .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                    .padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextActionButton("✏️", LocalizationStrings.localized("edit", language), Color(0xFF2980B9)) {
                    onEditStyle()
                }

                if (reorder != null) {
                    Box {
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(7.dp))
                                .background(Color(0xFF8E44AD))
                                .clickable { orderMenuOpen = true }
                                .padding(horizontal = 9.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text("≡", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            Text(
                                LocalizationStrings.localized("layer_bring_above_ink", language),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White
                            )
                            Text("▾", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        }
                        DropdownMenu(
                            expanded = orderMenuOpen,
                            onDismissRequest = { orderMenuOpen = false }
                        ) {
                            DropdownMenuItem(
                                text = { Text(LocalizationStrings.localized("layer_bring_above_ink", language)) },
                                onClick = { orderMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.BRING_ABOVE_INK) }
                            )
                            DropdownMenuItem(
                                text = { Text(LocalizationStrings.localized("layer_send_below_ink", language)) },
                                onClick = { orderMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.SEND_BELOW_INK) }
                            )
                            HorizontalDivider()
                            DropdownMenuItem(
                                text = { Text(LocalizationStrings.localized("layer_bring_front", language)) },
                                onClick = { orderMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.TO_FRONT) }
                            )
                            DropdownMenuItem(
                                text = { Text(LocalizationStrings.localized("layer_send_back", language)) },
                                onClick = { orderMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.TO_BACK) }
                            )
                            DropdownMenuItem(
                                text = { Text(LocalizationStrings.localized("layer_bring_forward", language)) },
                                onClick = { orderMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.FORWARD) }
                            )
                            DropdownMenuItem(
                                text = { Text(LocalizationStrings.localized("layer_send_backward", language)) },
                                onClick = { orderMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.BACKWARD) }
                            )
                        }
                    }
                }

                if (clipboard != null) {
                    TextActionButton("✂", LocalizationStrings.localized("action_cut", language), Color(0xFFE67E22)) {
                        clipboard.cut(box.id)
                    }
                    TextActionButton("📋", LocalizationStrings.localized("action_copy", language), Color(0xFF16A085)) {
                        clipboard.copy(box.id)
                    }
                }

                if (onDelete != null) {
                    TextActionButton("🗑", LocalizationStrings.localized("delete", language), Color(0xFFE74C3C)) {
                        onDelete(box)
                    }
                }
            }

            // 🌟 長按快顯功能表
            DropdownMenu(
                expanded = contextMenuOpen,
                onDismissRequest = { contextMenuOpen = false }
            ) {
                DropdownMenuItem(
                    text = { Text("✏️ " + LocalizationStrings.localized("edit_in_place", language)) },
                    onClick = { contextMenuOpen = false; onEditStyle() }
                )
                DropdownMenuItem(
                    text = { Text("🎨 " + LocalizationStrings.localized("text_studio", language)) },
                    onClick = { contextMenuOpen = false; onEditStyle() }
                )
                if (reorder != null) {
                    HorizontalDivider()
                    DropdownMenuItem(
                        text = { Text(LocalizationStrings.localized("layer_bring_above_ink", language)) },
                        onClick = { contextMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.BRING_ABOVE_INK) }
                    )
                    DropdownMenuItem(
                        text = { Text(LocalizationStrings.localized("layer_send_below_ink", language)) },
                        onClick = { contextMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.SEND_BELOW_INK) }
                    )
                    DropdownMenuItem(
                        text = { Text(LocalizationStrings.localized("layer_bring_front", language)) },
                        onClick = { contextMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.TO_FRONT) }
                    )
                    DropdownMenuItem(
                        text = { Text(LocalizationStrings.localized("layer_send_back", language)) },
                        onClick = { contextMenuOpen = false; reorder(box.id, ObjectStacking.Reorder.TO_BACK) }
                    )
                }
                if (onDelete != null) {
                    HorizontalDivider()
                    DropdownMenuItem(
                        text = { Text("🗑 " + LocalizationStrings.localized("delete", language), color = MaterialTheme.colorScheme.error) },
                        onClick = { contextMenuOpen = false; onDelete(box) }
                    )
                }
            }

            // 左下角的樣式鈕：字級、顏色、邊框、圓角、段落全部在那裡。
            StyleHandle(
                widthDp = liveWidth,
                heightDp = liveHeight,
                onTap = onEditStyle,
                objectId = box.id,
                modifier = Modifier.offset(x = horizontalPadding.dp, y = topPadding.dp)
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
                },
                modifier = Modifier.offset(x = horizontalPadding.dp, y = topPadding.dp)
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
                },
                modifier = Modifier.offset(x = horizontalPadding.dp, y = topPadding.dp)
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
    if (value.length == 8) {
        return runCatching { Color(value.toLong(16)) }.getOrNull()
    }
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

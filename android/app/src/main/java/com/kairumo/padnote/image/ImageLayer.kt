package com.kairumo.padnote.image

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.kairumo.padnote.canvas.CanvasRotation
import com.kairumo.padnote.canvas.MIN_OBJECT_HEIGHT_DP
import com.kairumo.padnote.canvas.MIN_OBJECT_WIDTH_DP
import com.kairumo.padnote.canvas.ResizeHandle
import com.kairumo.padnote.canvas.RotationHandle
import com.kairumo.padnote.canvas.StyleHandle
import com.kairumo.padnote.canvas.gesturesIf

/**
 * 畫布上的圖片層。
 *
 * 疊放順序、把手位置、下限尺寸都與文字方塊與形狀一致 —— 三種物件在畫面上
 * 行為不一樣的話，使用者要分別記三套操作。
 */
@Composable
fun ImageLayer(
    images: List<NoteImage>,
    store: ImageStore,
    density: Float,
    selectedId: String?,
    interactive: Boolean,
    onSelect: (String) -> Unit,
    onEditStyle: (NoteImage) -> Unit,
    onChanged: (NoteImage) -> Unit,
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
        for (image in images) {
            androidx.compose.runtime.key(image.id) {
                ImageObjectView(
                    zIndex = zIndexOf(image.id),
                    image = image,
                    bitmapProvider = { store.bitmap(image) },
                    density = density,
                    isSelected = image.id == selectedId,
                    interactive = interactive,
                    onSelect = { onSelect(image.id) },
                    onEditStyle = { onEditStyle(image) },
                    onChanged = onChanged
                )
            }
        }
}

@Composable
private fun ImageObjectView(
    /** 堆疊 z 值，見 ObjectStacking。 */
    zIndex: Float,
    image: NoteImage,
    bitmapProvider: () -> androidx.compose.ui.graphics.ImageBitmap?,
    density: Float,
    isSelected: Boolean,
    interactive: Boolean,
    onSelect: () -> Unit,
    onEditStyle: () -> Unit,
    onChanged: (NoteImage) -> Unit
) {
    // 鎖定在畫布上：不能拖曳、縮放、旋轉；點選、樣式面板照常（見 canvas/ObjectLock.kt）。
    val moveLocked = com.kairumo.padnote.canvas.isMoveLocked(image.id)
    // 底稿：鎖定、在筆跡下方、又撐滿頁寬或頁高（匯入的 PDF 頁面就是這樣放的）。照舊不接觸控，
    // 點它就是在頁面上寫字。其餘鎖定的圖片照常點得到、選得起來。與 Apple `isLockedBackdrop` 同一條規則。
    val isBackdrop = moveLocked &&
        image.id in com.kairumo.padnote.canvas.LocalUnderInkObjectIds.current &&
        (image.width >= com.kairumo.padnote.ink.PageGeometry.width * 0.9f ||
            image.height >= com.kairumo.padnote.ink.PageGeometry.height * 0.9f)
    @Suppress("NAME_SHADOWING") val interactive = interactive && !isBackdrop
    val currentImage by androidx.compose.runtime.rememberUpdatedState(image)
    var liveX by remember(image.id, image.x) { mutableFloatStateOf(image.x) }
    var liveY by remember(image.id, image.y) { mutableFloatStateOf(image.y) }
    var liveWidth by remember(image.id, image.width) { mutableFloatStateOf(image.width) }
    var liveHeight by remember(image.id, image.height) { mutableFloatStateOf(image.height) }
    var liveRotation by remember(image.id, image.rotationDegrees) { mutableFloatStateOf(image.rotationDegrees) }
    val rotation = CanvasRotation.normalized(liveRotation)
    val shape = RoundedCornerShape(image.cornerRadius.dp)
    // 連續模式：拖到哪一頁就歸哪一頁（單頁模式為 null，照舊夾在本頁）。
    val crossing by androidx.compose.runtime.rememberUpdatedState(com.kairumo.padnote.canvas.LocalPageCrossing.current)
    val editorMode = com.kairumo.padnote.canvas.LocalEditorMode.current
    val isCanvasNavigating = com.kairumo.padnote.canvas.LocalCanvasNavigating.current
    val isTypeMode = editorMode == com.kairumo.padnote.canvas.EditorMode.TYPE

    // 外層只定位、不旋轉 —— 旋轉把手掛在這一層。包進旋轉裡的話，拖曳算出的
    // 角度會疊加自身旋轉，物件會失控加速。
    // 座標的單位是**頁面點**（＝dp），與 Apple 端和 format-spec 一致。
    Box(modifier = Modifier.offset(liveX.dp, liveY.dp).zIndex(zIndex)) {

        Box(
            modifier = Modifier
                .size(liveWidth.dp, liveHeight.dp)
                .graphicsLayer { rotationZ = rotation }
                .then(
                    if (image.hasShadow) Modifier.shadow(4.dp, shape) else Modifier
                )
                .clip(shape)
                .background(resolveBackground(image))
                .then(
                    if (image.hasBorder) {
                        Modifier.border(
                            width = (image.borderWidth ?: 1.5f).dp,
                            color = parseColor(image.borderColorHex) ?: Color(0x804A90D9),
                            shape = shape
                        )
                    } else if (isSelected) {
                        Modifier.border(1.5f.dp, MaterialTheme.colorScheme.primary, shape)
                    } else {
                        Modifier
                    }
                )
                .gesturesIf(interactive) {
                    pointerInput(image.id) {
                        detectTapGestures(onTap = { onSelect() })
                    }
                }
                .gesturesIf(interactive && !moveLocked && (isSelected || isTypeMode) && !isCanvasNavigating) {
                    // 不以 isSelected 當鍵：拖曳一開始就 onSelect()，選取狀態一變這段手勢就被重啟、拖到一半被取消（實機回報：方塊拖不動）。
                    pointerInput(image.id, isTypeMode, isCanvasNavigating) {
                        var startX = 0f
                        var startY = 0f
                        var accX = 0f
                        var accY = 0f
                        val finishDrag: () -> Unit = {
                            val img = currentImage
                            val landed = com.kairumo.padnote.canvas.landObject(
                                img.id, liveX, liveY, liveWidth, liveHeight, crossing)
                            liveX = landed.x
                            liveY = landed.y
                            img.x = landed.x
                            img.y = landed.y
                            onChanged(img)
                            landed.page?.let { crossing?.moved?.invoke(img.id, it) }
                            crossing?.ended?.invoke()
                        }
                        detectDragGestures(
                            onDragStart = {
                                if (isCanvasNavigating) return@detectDragGestures
                                val img = currentImage
                                startX = img.x
                                startY = img.y
                                accX = 0f
                                accY = 0f
                                liveX = img.x
                                liveY = img.y
                                onSelect()
                                crossing?.began?.invoke()
                            },
                            onDragCancel = finishDrag,
                            onDrag = { change, drag ->
                                if (isCanvasNavigating) {
                                    val img = currentImage
                                    liveX = startX
                                    liveY = startY
                                    img.x = startX
                                    img.y = startY
                                    crossing?.ended?.invoke()
                                    return@detectDragGestures
                                }
                                change.consume()
                                accX += drag.x
                                accY += drag.y
                                val rad = liveRotation * kotlin.math.PI / 180.0
                                val c = kotlin.math.cos(rad).toFloat()
                                val sn = kotlin.math.sin(rad).toFloat()
                                // 位移要換回 dp：座標存的是與螢幕密度無關的頁面座標。
                                liveX = startX + (accX * c - accY * sn) / density
                                liveY = startY + (accX * sn + accY * c) / density
                                currentImage.x = liveX
                                currentImage.y = liveY
                            },
                            onDragEnd = finishDrag
                        )
                    }
                }
        ) {
            val bitmap = bitmapProvider()
            if (bitmap != null) {
                Image(
                    bitmap = bitmap,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    // 填滿並裁切，不要變形。使用者調整方框比例時，
                    // 拉扁的照片比裁掉一點更難看也更難修。
                    contentScale = ContentScale.Crop,
                    colorFilter = filterFor(image.filterStyle)
                )
            }
        }

        if (isSelected && interactive) {
            StyleHandle(
                widthDp = liveWidth,
                heightDp = liveHeight,
                onTap = onEditStyle,
                objectId = image.id
            )
            if (!moveLocked) ResizeHandle(
                widthDp = liveWidth,
                heightDp = liveHeight,
                density = density,
                onResize = { dw, dh ->
                    liveWidth = maxOf(MIN_OBJECT_WIDTH_DP, liveWidth + dw)
                    liveHeight = maxOf(MIN_OBJECT_HEIGHT_DP, liveHeight + dh)
                    currentImage.width = liveWidth
                    currentImage.height = liveHeight
                },
                onCommit = {
                    currentImage.width = liveWidth
                    currentImage.height = liveHeight
                    onChanged(currentImage)
                }
            )
            if (!moveLocked) RotationHandle(
                degrees = rotation,
                widthDp = liveWidth,
                heightDp = liveHeight,
                density = density,
                onRotate = {
                    liveRotation = it
                    currentImage.rotationDegrees = it
                },
                onCommit = {
                    currentImage.rotationDegrees = liveRotation
                    onChanged(currentImage)
                }
            )
        }
    }
}

/**
 * 濾鏡。
 *
 * **視覺結果要與 Apple 端的 `ImageFilterStyle` 相近** —— 同一張照片在兩個
 * 平台差太多的話，使用者會以為圖片被改過。用 ColorMatrix 而不是逐像素處理：
 * 那是 GPU 上的一次變換，捲動時不會掉幀。
 */
private fun filterFor(style: ImageFilterStyle): ColorFilter? = when (style) {
    ImageFilterStyle.ORIGINAL -> null
    ImageFilterStyle.MONO -> ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(0f) })
    ImageFilterStyle.VINTAGE -> ColorFilter.colorMatrix(
        ColorMatrix(
            floatArrayOf(
                0.393f, 0.769f, 0.189f, 0f, 0f,
                0.349f, 0.686f, 0.168f, 0f, 0f,
                0.272f, 0.534f, 0.131f, 0f, 0f,
                0f, 0f, 0f, 1f, 0f
            )
        )
    )
    ImageFilterStyle.CONTRAST -> ColorFilter.colorMatrix(
        ColorMatrix(
            floatArrayOf(
                1.35f, 0f, 0f, 0f, -35f,
                0f, 1.35f, 0f, 0f, -35f,
                0f, 0f, 1.35f, 0f, -35f,
                0f, 0f, 0f, 1f, 0f
            )
        )
    )
    ImageFilterStyle.WARM -> ColorFilter.colorMatrix(
        ColorMatrix(
            floatArrayOf(
                1.10f, 0f, 0f, 0f, 12f,
                0f, 1.02f, 0f, 0f, 6f,
                0f, 0f, 0.92f, 0f, 0f,
                0f, 0f, 0f, 1f, 0f
            )
        )
    )
}

/** `"clear"` 是哨符不是顏色 —— 不能走 hex 轉換，那會丟掉 alpha 變成黑色。 */
private fun resolveBackground(image: NoteImage): Color = when {
    image.backgroundColorHex == null -> Color.Transparent
    image.backgroundColorHex == "clear" -> Color.Transparent
    else -> parseColor(image.backgroundColorHex) ?: Color.Transparent
}

private fun parseColor(hex: String?): Color? =
    hex?.let { com.kairumo.padnote.chart.ChartRenderer.parseColor(it)?.let { c -> Color(c) } }

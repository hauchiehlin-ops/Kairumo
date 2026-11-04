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
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.boundsInRoot
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
    modifier: Modifier = Modifier,
    /**
     * 圖片在背景解碼（畫布用，預設）。開啟圖多的大筆記本時，原本每張圖第一次組合就在主執行緒讀 blob＋解碼。
     * 離屏縮圖（`PageSnapshot`）必須當下畫完，傳 `false` 走同步。與 Apple 畫布的背景預載一致。
     */
    decodeOffMain: Boolean = true
) {
    var decodedTick by remember { androidx.compose.runtime.mutableIntStateOf(0) }
    if (decodeOffMain) {
        val blobIds = images.map { it.blobId }.distinct()
        androidx.compose.runtime.LaunchedEffect(store, blobIds) {
            val missing = images.filter { store.cachedBitmap(it) == null }.map { it.blobId }.distinct()
            if (missing.isEmpty()) return@LaunchedEffect
            val decoded = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                missing.mapNotNull { id -> store.decodeOffMain(id)?.let { id to it } }
            }
            // LaunchedEffect 跑在主執行緒（Compose 的 Main dispatcher）：在這裡收進快取、推進重組。
            decoded.forEach { (id, bmp) -> store.adopt(id, bmp) }
            if (decoded.isNotEmpty()) decodedTick++
        }
    }
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
                    bitmapProvider = {
                        if (decodeOffMain) { decodedTick; store.cachedBitmap(image) } else store.bitmap(image)
                    },
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
    // 壓到下方選取物件（表格等）的工具列時也讓出觸控，鎖定鈕才點得到（見 canvas/ObjectLock.kt）。
    @Suppress("NAME_SHADOWING") val interactive = interactive && !isBackdrop &&
        !com.kairumo.padnote.canvas.yieldsToSelectedChrome(image.id, image.x, image.y, image.width, image.height)
    val currentImage by androidx.compose.runtime.rememberUpdatedState(image)
    var liveX by remember(image.id, image.x) { mutableFloatStateOf(image.x) }
    var liveY by remember(image.id, image.y) { mutableFloatStateOf(image.y) }
    var liveWidth by remember(image.id, image.width) { mutableFloatStateOf(image.width) }
    var liveHeight by remember(image.id, image.height) { mutableFloatStateOf(image.height) }
    var liveRotation by remember(image.id, image.rotationDegrees) { mutableFloatStateOf(image.rotationDegrees) }
    // 縮放手勢的基準尺寸與累計位移。不放進 state：只在手勢回呼裡讀寫，不驅動重組。
    // 以 id 為鍵：live 尺寸的 remember 會隨 width 變動重建，基準不能跟著被洗掉。
    val resizeGesture = remember(image.id) { ResizeGestureState() }
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
                // 選取中回報螢幕上的框：編修面板據此避開它（見 ui/FloatingPanel.kt）。
                // 離屏截圖（interactive = false）不回報：那條路可能不在主執行緒。
                .then(
                    if (!interactive) Modifier
                    else Modifier.onGloballyPositioned {
                        com.kairumo.padnote.ui.EditingObjectBounds.report(image.id, isSelected, it.boundsInRoot())
                    }
                )
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
                    // 等比、以開始拖曳時的尺寸為基準累計（見 ImageResize：與 Apple 同一套下限）。
                    val g = resizeGesture
                    val base = g.base ?: (liveWidth to liveHeight).also {
                        g.base = it
                        g.accX = 0f
                        g.accY = 0f
                    }
                    g.accX += dw
                    g.accY += dh
                    val (w, h) = ImageResize.resized(base.first, base.second, g.accX, g.accY)
                    liveWidth = w
                    liveHeight = h
                    currentImage.width = liveWidth
                    currentImage.height = liveHeight
                },
                onCommit = {
                    resizeGesture.base = null
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

/** 一次縮放手勢的基準尺寸與累計位移（頁面點）。 */
private class ResizeGestureState {
    var base: Pair<Float, Float>? = null
    var accX = 0f
    var accY = 0f
}

/**
 * 濾鏡。矩陣定義在 [ImageFilterStyle.matrix]，與 Apple `ImageEffects.filterMatrix` 同一組數字（I6）。
 * 用 ColorMatrix 而不是逐像素處理：那是 GPU 上的一次變換，捲動時不會掉幀。
 */
private fun filterFor(style: ImageFilterStyle): ColorFilter? =
    style.androidColorMatrix()?.let { ColorFilter.colorMatrix(ColorMatrix(it)) }

/** `"clear"` 是哨符不是顏色 —— 不能走 hex 轉換，那會丟掉 alpha 變成黑色。 */
private fun resolveBackground(image: NoteImage): Color = when {
    image.backgroundColorHex == null -> Color.Transparent
    image.backgroundColorHex == "clear" -> Color.Transparent
    else -> parseColor(image.backgroundColorHex) ?: Color.Transparent
}

private fun parseColor(hex: String?): Color? =
    hex?.let { com.kairumo.padnote.chart.ChartRenderer.parseColor(it)?.let { c -> Color(c) } }

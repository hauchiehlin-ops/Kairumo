package com.kairumo.padnote.image

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
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        for (image in images) {
            ImageObjectView(
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
    image: NoteImage,
    bitmapProvider: () -> androidx.compose.ui.graphics.ImageBitmap?,
    density: Float,
    isSelected: Boolean,
    interactive: Boolean,
    onSelect: () -> Unit,
    onEditStyle: () -> Unit,
    onChanged: (NoteImage) -> Unit
) {
    val rotation = CanvasRotation.normalized(image.rotationDegrees)
    val shape = RoundedCornerShape(image.cornerRadius.dp)

    // 外層只定位、不旋轉 —— 旋轉把手掛在這一層。包進旋轉裡的話，拖曳算出的
    // 角度會疊加自身旋轉，物件會失控加速。
    // 座標的單位是**頁面點**（＝dp），與 Apple 端和 format-spec 一致。
    Box(modifier = Modifier.offset(image.x.dp, image.y.dp)) {

        Box(
            modifier = Modifier
                .size(image.width.dp, image.height.dp)
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
                        Modifier.border(1.5f.dp, Color(0xFF4A90D9), shape)
                    } else {
                        Modifier
                    }
                )
                .gesturesIf(interactive) {
                    pointerInput(image.id) {
                        detectTapGestures(onTap = { onSelect() })
                    }
                }
                .gesturesIf(interactive) {
                    pointerInput(image.id) {
                        detectDragGestures(
                            onDragStart = { onSelect() },
                            onDrag = { change, drag ->
                                change.consume()
                                // 位移要換回 dp：座標存的是與螢幕密度無關的頁面座標。
                                image.x += drag.x / density
                                image.y += drag.y / density
                            },
                            onDragEnd = { onChanged(image) }
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
                widthDp = image.width,
                heightDp = image.height,
                onTap = onEditStyle
            )
            ResizeHandle(
                widthDp = image.width,
                heightDp = image.height,
                density = density,
                onResize = { dw, dh ->
                    image.width = maxOf(MIN_OBJECT_WIDTH_DP, image.width + dw)
                    image.height = maxOf(MIN_OBJECT_HEIGHT_DP, image.height + dh)
                },
                onCommit = { onChanged(image) }
            )
            RotationHandle(
                degrees = rotation,
                widthDp = image.width,
                heightDp = image.height,
                density = density,
                onRotate = { image.rotationDegrees = it },
                onCommit = { onChanged(image) }
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

package com.kairumo.padnote.asset

import android.graphics.Bitmap
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.graphics.createBitmap
import java.io.ByteArrayOutputStream
import uniffi.padnote_core.FfiAssetRenderStyle
import uniffi.padnote_core.FfiAssetSource
import uniffi.padnote_core.FfiDrawPath
import uniffi.padnote_core.FfiPathVerb
import uniffi.padnote_core.assetCanvasSize
import uniffi.padnote_core.assetDimensionCallout
import uniffi.padnote_core.assetDrawing
import uniffi.padnote_core.assetPalette

/**
 * 素材線圖的算繪（Android）。
 *
 * 圖形本身在核心（`assetDrawing()`）—— 這裡只認得路徑指令，不知道自己畫的是
 * 齒輪還是螺栓。Apple 端走的是同一份資料，所以同一件素材在兩個平台上長得一樣。
 *
 * 核心的座標系固定 400×400；畫進別的尺寸時整體等比縮放並置中，不拉伸 ——
 * 拉伸會讓圓變成橢圓，而工程線圖裡的圓通常代表孔徑。
 */
object AssetRenderer {

    fun draw(
        scope: DrawScope,
        code: String,
        style: FfiAssetRenderStyle,
        dark: Boolean,
        width: Float,
        height: Float
    ) {
        val canvas = assetCanvasSize()
        val scale = minOf(width, height) / canvas
        val dx = (width - canvas * scale) / 2f
        val dy = (height - canvas * scale) / 2f

        val palette = assetPalette(style, dark)
        val stroke = parseHex(palette.strokeHex, Color(0xFF1A4DA6))
        val accent = parseHex(palette.accentHex, Color(0xFFD93333))
        val fill = parseHex(palette.fillHex, Color.Transparent)

        val paths = buildList {
            addAll(assetDrawing(code))
            // 尺寸引線只在線框模式出現 —— 實物模式是要貼進筆記當一個物件用的。
            if (style == FfiAssetRenderStyle.BLUEPRINT) addAll(assetDimensionCallout())
        }

        for (item in paths) {
            val path = toPath(item, scale, dx, dy)
            val override = item.fillOverrideHex.takeIf { it.isNotEmpty() }?.let { parseHex(it, Color.Transparent) }
            when {
                // 指定填色（瀏覽器線框的紅黃綠）連線框模式也要填：那三顆點
                // 就是靠顏色辨識的，少了顏色只是三個一樣的圈圈。
                override != null -> scope.drawPath(path, color = override)
                item.fillable && style == FfiAssetRenderStyle.SOLID ->
                    scope.drawPath(path, color = fill)
            }
            scope.drawPath(
                path,
                color = if (item.accent) accent else stroke,
                style = Stroke(
                    width = item.width * scale,
                    pathEffect = if (item.dashed) {
                        PathEffect.dashPathEffect(floatArrayOf(5f * scale, 4f * scale))
                    } else {
                        null
                    }
                )
            )
        }
    }

    /** 核心的路徑指令 → Compose 的 Path。 */
    private fun toPath(item: FfiDrawPath, scale: Float, dx: Float, dy: Float): Path {
        val path = Path()
        for (s in item.segs) {
            val x = s.x * scale + dx
            val y = s.y * scale + dy
            when (s.verb) {
                FfiPathVerb.MOVE -> path.moveTo(x, y)
                FfiPathVerb.LINE -> path.lineTo(x, y)
                FfiPathVerb.CURVE -> path.cubicTo(
                    s.c1x * scale + dx, s.c1y * scale + dy,
                    s.c2x * scale + dx, s.c2y * scale + dy,
                    x, y
                )
                FfiPathVerb.CLOSE -> path.close()
            }
        }
        return path
    }

    fun backgroundColor(dark: Boolean): Color =
        parseHex(assetPalette(FfiAssetRenderStyle.BLUEPRINT, dark).backgroundHex, Color.White)

    fun gridColor(dark: Boolean): Color =
        parseHex(assetPalette(FfiAssetRenderStyle.BLUEPRINT, dark).gridHex, Color.LightGray)

    /** `#RRGGBB` 或 `#RRGGBBAA`。壞掉時用呼叫端給的備用色，不讓面板整個掛掉。 */
    private fun parseHex(hex: String, fallback: Color): Color {
        if (hex.isEmpty()) return fallback
        return runCatching {
            val body = hex.removePrefix("#")
            when (body.length) {
                6 -> Color(android.graphics.Color.parseColor("#$body"))
                // Android 的 parseColor 吃的是 #AARRGGBB，核心給的是 #RRGGBBAA。
                // 直接丟進去會把 alpha 當成紅色 —— 順序要自己搬。
                8 -> Color(android.graphics.Color.parseColor("#${body.substring(6)}${body.substring(0, 6)}"))
                else -> fallback
            }
        }.getOrDefault(fallback)
    }
}

/**
 * 把素材算繪成 PNG 位元組，供插進畫布當圖片區塊用。
 *
 * 為什麼落成點陣圖而不是保留向量：畫布上的圖片區塊是核心既有的型別，
 * 匯出 PDF 與其他讀取器都認得。Apple 端插素材時也是這樣做的 ——
 * 兩邊插出來的東西型別要一樣，不然同一份筆記在另一台裝置上會少東西。
 *
 * 算繪不出來時回 null，呼叫端顯示訊息即可。丟例外只會讓按一下「插入」
 * 變成閃退。
 */
fun renderAssetPng(
    code: String,
    style: FfiAssetRenderStyle,
    source: FfiAssetSource,
    size: Int = 400
): ByteArray? = runCatching {
    val dark = source == FfiAssetSource.AI_CONCEPT
    val bitmap = createBitmap(size, size)
    val canvas = android.graphics.Canvas(bitmap)
    // 背景透明：貼進筆記時不要壓住底下的手寫線條與紙張紋理。
    val drawScope = CanvasDrawScope()
    drawScope.draw(
        density = Density(1f),
        layoutDirection = LayoutDirection.Ltr,
        canvas = androidx.compose.ui.graphics.Canvas(canvas),
        size = Size(size.toFloat(), size.toFloat())
    ) {
        AssetRenderer.draw(this, code, style, dark, size.toFloat(), size.toFloat())
    }
    val out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
    out.toByteArray()
}.getOrNull()

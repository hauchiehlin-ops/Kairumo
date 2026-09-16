package com.kairumo.padnote.model3d

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import uniffi.padnote_core.FfiMaterial
import uniffi.padnote_core.model3dFaces
import uniffi.padnote_core.model3dKindFromRaw
import uniffi.padnote_core.model3dMaterialLook

/**
 * 3D 模型的算繪（Android）。
 *
 * 幾何、旋轉、投影、明暗全部來自核心 `model3dFaces()` —— Apple 端用 SceneKit，
 * Android 沒有對應品，所以那一份數學下沉到核心之後兩邊才畫得出同一個東西。
 *
 * 這裡只做一件事：把核心回傳的多邊形**照順序**填色。順序就是前後關係
 * （由遠而近），不要自己重排。
 */
object Model3DRenderer {

    fun draw(
        scope: DrawScope,
        model: Model3DObject,
        width: Float,
        height: Float
    ) {
        val look = model3dMaterialLook(model.material)
        val base = parseHex(look.hex)

        val faces = model3dFaces(
            model3dKindFromRaw(model.modelTypeRaw),
            model.rotationX, model.rotationY, model.rotationZ,
            model.scale, width, height
        )

        for (face in faces) {
            if (face.points.size < 3) continue
            val path = Path().apply {
                moveTo(face.points[0].x, face.points[0].y)
                for (i in 1 until face.points.size) lineTo(face.points[i].x, face.points[i].y)
                close()
            }
            scope.drawPath(path, color = shade(base, face.shade, look.metalness, look.roughness))
            // 描一條同色系的細邊。沒有它的話相鄰面之間會出現抗鋸齒的細縫，
            // 模型看起來像裂開的。
            scope.drawPath(
                path,
                color = shade(base, face.shade * 0.82f, look.metalness, look.roughness),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1f)
            )
        }

        if (faces.isEmpty()) {
            // 畫不出任何面代表資料壞了（例如 scale 是 NaN）。畫一個記號比
            // 留一塊空白好 —— 空白看起來像物件不見了。
            scope.drawCircle(
                color = base.copy(alpha = 0.3f),
                radius = minOf(width, height) / 4f,
                center = Offset(width / 2f, height / 2f)
            )
        }
    }

    /**
     * 明暗係數套到基本色上，並吃進材質的金屬度與粗糙度（工作項 S-63）。
     *
     * # 原本的問題
     *
     * 這個函式以前只有 `base * factor`，`metalness` 與 `roughness` 完全沒被
     * 用到 —— 核心明明算好了也傳過來了。結果是黃金、塑膠、玻璃畫出來只是
     * **色相不同的平塗**，看不出材質。Apple 端把同樣這兩個值餵給 SceneKit
     * 的 PBR，所以同一個模型兩邊長得不一樣。
     *
     * （原本的註解寫「金屬材質的暗部壓得更深一點」，但程式裡沒有這件事。）
     *
     * # 這裡怎麼近似
     *
     * Android 這條路是 2D 畫布，不可能真的做 PBR。但 PBR 之所以看起來像
     * 金屬，主要是兩件事，兩件都能在平面上近似：
     *
     * 1. **金屬的明暗反差大。** 金屬幾乎不漫射，亮面很亮、暗面很暗。
     *    所以 metalness 越高，就把明暗曲線的對比拉得越開。
     * 2. **越光滑，高光越集中。** roughness 越低，最亮的那幾面要再更亮，
     *    而且**金屬的高光帶自身顏色**（金子的反光是金色的），非金屬的
     *    高光偏白。這一點畫錯的話，金色會反出白光，看起來像塑膠。
     */
    private fun shade(base: Color, factor: Float, metalness: Float, roughness: Float): Color {
        val m = metalness.coerceIn(0f, 1f)
        val r = roughness.coerceIn(0f, 1f)
        val raw = factor.coerceIn(0f, 1f)

        // 1. 對比：以 0.5 為中心把明暗拉開，金屬拉得更多。
        val contrast = 1f + m * 0.9f
        var f = ((raw - 0.5f) * contrast + 0.5f).coerceIn(0f, 1f)
        // 金屬的漫射本來就暗，整體再壓一點，高光才顯得出來。
        f *= (1f - m * 0.22f)

        val lit = Color(
            red = (base.red * f).coerceIn(0f, 1f),
            green = (base.green * f).coerceIn(0f, 1f),
            blue = (base.blue * f).coerceIn(0f, 1f),
            alpha = base.alpha
        )

        // 2. 高光：只加在最亮的那一段，越光滑越強。
        val smooth = (1f - r) * (1f - r)
        val threshold = 0.80f
        if (raw <= threshold || smooth <= 0.01f) return lit
        val t = ((raw - threshold) / (1f - threshold)).coerceIn(0f, 1f) * smooth * 0.75f
        // 金屬的高光帶自身顏色，非金屬偏白。
        val specular = Color(
            red = base.red + (1f - base.red) * (1f - m),
            green = base.green + (1f - base.green) * (1f - m),
            blue = base.blue + (1f - base.blue) * (1f - m),
            alpha = base.alpha
        )
        return Color(
            red = (lit.red + (specular.red - lit.red) * t).coerceIn(0f, 1f),
            green = (lit.green + (specular.green - lit.green) * t).coerceIn(0f, 1f),
            blue = (lit.blue + (specular.blue - lit.blue) * t).coerceIn(0f, 1f),
            alpha = base.alpha
        )
    }

    /** 測試用：把單一面的最終顏色算出來，不必真的畫。 */
    internal fun shadeForTest(base: Color, factor: Float, metalness: Float, roughness: Float) =
        shade(base, factor, metalness, roughness)

    private fun parseHex(hex: String): Color =
        runCatching { Color(android.graphics.Color.parseColor(hex)) }
            .getOrDefault(Color(0xFFFFD61E))

    /** 面板上的材質色塊用得到。 */
    fun materialColor(material: FfiMaterial): Color = parseHex(model3dMaterialLook(material).hex)
}

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
            scope.drawPath(path, color = shade(base, face.shade))
            // 描一條同色系的細邊。沒有它的話相鄰面之間會出現抗鋸齒的細縫，
            // 模型看起來像裂開的。
            scope.drawPath(
                path,
                color = shade(base, face.shade * 0.82f),
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

    /** 明暗係數套到基本色上。金屬材質的暗部壓得更深一點，才看得出反差。 */
    private fun shade(base: Color, factor: Float): Color {
        val f = factor.coerceIn(0f, 1f)
        return Color(
            red = (base.red * f).coerceIn(0f, 1f),
            green = (base.green * f).coerceIn(0f, 1f),
            blue = (base.blue * f).coerceIn(0f, 1f),
            alpha = base.alpha
        )
    }

    private fun parseHex(hex: String): Color =
        runCatching { Color(android.graphics.Color.parseColor(hex)) }
            .getOrDefault(Color(0xFFFFD61E))

    /** 面板上的材質色塊用得到。 */
    fun materialColor(material: FfiMaterial): Color = parseHex(model3dMaterialLook(material).hex)
}

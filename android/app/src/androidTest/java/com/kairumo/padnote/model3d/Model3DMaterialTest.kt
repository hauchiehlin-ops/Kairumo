package com.kairumo.padnote.model3d

import androidx.compose.ui.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

/**
 * 材質要看得出是材質（工作項 S-63）。
 *
 * Android 的算繪器以前只用核心給的 hex，`metalness` 與 `roughness` 完全
 * 沒被用到 —— 黃金、塑膠、玻璃畫出來只是色相不同的平塗。Apple 端把這兩個
 * 值餵給 SceneKit 的 PBR，所以同一個模型兩邊長得不一樣。
 *
 * 這組測試釘的是**兩個看得見的性質**，不是某個像素值：金屬的明暗反差要比
 * 霧面大，光滑面要有高光而粗糙面沒有。
 */
@RunWith(AndroidJUnit4::class)
class Model3DMaterialTest {

    private val gold = Color(0xFFFFD700)

    private fun luminance(c: Color) = 0.2126f * c.red + 0.7152f * c.green + 0.0722f * c.blue

    private fun contrast(metalness: Float, roughness: Float): Float {
        val bright = Model3DRenderer.shadeForTest(gold, 0.95f, metalness, roughness)
        val dark = Model3DRenderer.shadeForTest(gold, 0.25f, metalness, roughness)
        return luminance(bright) - luminance(dark)
    }

    @Test
    fun metalHasMoreContrastThanMatte() {
        // 金屬幾乎不漫射：亮面很亮、暗面很暗。反差沒拉開的話，
        // 金子看起來就只是一塊黃色。
        val metal = contrast(metalness = 1f, roughness = 0.2f)
        val matte = contrast(metalness = 0f, roughness = 0.9f)
        assertTrue("金屬的明暗反差應大於霧面（metal=$metal matte=$matte）", metal > matte)
    }

    @Test
    fun aSmoothSurfaceGetsAHighlightAndARoughOneDoesNot() {
        val smooth = Model3DRenderer.shadeForTest(gold, 0.97f, metalness = 0f, roughness = 0.05f)
        val rough = Model3DRenderer.shadeForTest(gold, 0.97f, metalness = 0f, roughness = 1f)
        assertTrue(
            "光滑面的最亮處應該比粗糙面亮（smooth=${luminance(smooth)} rough=${luminance(rough)}）",
            luminance(smooth) > luminance(rough)
        )
    }

    @Test
    fun aMetalHighlightKeepsItsOwnHueInsteadOfTurningWhite() {
        // 金子的反光是金色的。高光一律加白的話，金色會反出白光 ——
        // 那看起來像塑膠，這是材質畫錯時最明顯的破綻。
        val metalSpec = Model3DRenderer.shadeForTest(gold, 0.99f, metalness = 1f, roughness = 0.05f)
        val plasticSpec = Model3DRenderer.shadeForTest(gold, 0.99f, metalness = 0f, roughness = 0.05f)
        // 金色的藍色分量本來就低；高光帶自身顏色時，藍色不該被拉上來太多。
        assertTrue(
            "金屬高光不該泛白（metal blue=${metalSpec.blue} plastic blue=${plasticSpec.blue}）",
            metalSpec.blue < plasticSpec.blue
        )
    }

    @Test
    fun theResultStaysInsideTheValidColourRange() {
        // 超出 0…1 會被截斷成奇怪的顏色，而那種錯誤在小小的縮圖上看不出來。
        for (m in listOf(0f, 0.5f, 1f)) {
            for (r in listOf(0f, 0.5f, 1f)) {
                for (f in listOf(0f, 0.3f, 0.8f, 1f)) {
                    val c = Model3DRenderer.shadeForTest(gold, f, m, r)
                    for (channel in listOf(c.red, c.green, c.blue)) {
                        assertTrue("m=$m r=$r f=$f 產生了超界的色值 $channel",
                            channel in 0f..1f && !channel.isNaN())
                    }
                    assertTrue("alpha 不該改變", abs(c.alpha - gold.alpha) < 0.001f)
                }
            }
        }
    }
}

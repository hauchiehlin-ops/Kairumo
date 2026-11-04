package com.kairumo.padnote.image

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 風格濾鏡兩端同一組矩陣（I6）。讀 Apple `ImageEffects.swift` 的 `filterMatrix` 原始碼逐項比對 ——
 * 原本兩端各寫一套（Apple 乘法疊加、Android 另一組矩陣），同一張圖兩邊長得不一樣，
 * 而 Apple 那套對深色線條的素材圖幾乎沒有效果（使用者回報「點了沒作用」）。
 */
class ImageFilterParityTest {

    private fun appleSource(): String {
        val candidates = listOf("../../apple/Sources/ImageEffects.swift", "../apple/Sources/ImageEffects.swift", "apple/Sources/ImageEffects.swift")
        val file = candidates.map(::File).firstOrNull { it.exists() }
        assertNotNull("找不到 apple/Sources/ImageEffects.swift（工作目錄：${File(".").absolutePath}）", file)
        return file!!.readText()
    }

    private fun appleMatrix(source: String, case: String): FloatArray {
        val m = Regex("""case \.$case: return \[([^\]]*)\]""").find(source)
        assertNotNull("Apple 端少了 .$case 的矩陣", m)
        return m!!.groupValues[1].split(',').map { it.trim().toFloat() }.toFloatArray()
    }

    @Test
    fun matricesMatchApple() {
        val src = appleSource()
        val pairs = mapOf(
            "vintage" to ImageFilterStyle.VINTAGE,
            "mono" to ImageFilterStyle.MONO,
            "contrast" to ImageFilterStyle.CONTRAST,
            "warm" to ImageFilterStyle.WARM
        )
        for ((case, style) in pairs) {
            assertArrayEquals("$case 與 Apple 不同", appleMatrix(src, case), style.matrix!!, 0f)
        }
        assertTrue(src.contains("case .original: return nil"))
        assertNull(ImageFilterStyle.ORIGINAL.matrix)
    }

    /** 每一種濾鏡都要讓「深藍線條」明顯變色 —— 素材圖庫的圖幾乎都是透明底深色線稿。 */
    @Test
    fun everyFilterVisiblyChangesDarkLineArt() {
        val navy = floatArrayOf(0.12f, 0.20f, 0.40f)
        for (style in ImageFilterStyle.entries.filter { it != ImageFilterStyle.ORIGINAL }) {
            val m = style.matrix!!
            val out = FloatArray(3) { row ->
                (m[row * 4] * navy[0] + m[row * 4 + 1] * navy[1] + m[row * 4 + 2] * navy[2] + m[row * 4 + 3]).coerceIn(0f, 1f)
            }
            val delta = (0..2).maxOf { kotlin.math.abs(out[it] - navy[it]) }
            assertTrue("$style 對深色線條幾乎沒有變化（最大差 $delta）", delta >= 0.06f)
        }
    }

    @Test
    fun androidMatrixScalesOffsetsTo255() {
        val m = ImageFilterStyle.WARM.androidColorMatrix()!!
        assertTrue(kotlin.math.abs(m[4] - 0.12f * 255f) < 1e-3)
        assertTrue(m[18] == 1f)
    }
}

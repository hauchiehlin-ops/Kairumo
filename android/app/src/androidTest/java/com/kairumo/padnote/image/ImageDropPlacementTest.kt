package com.kairumo.padnote.image

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 拖進來的圖片要放在哪、放多大（工作項 S-68，Android 端）。
 *
 * **拖放這個手勢本身在這裡驗不到** —— 要兩個 App 同時在畫面上（分割畫面），
 * 模擬器上驅動得動但自動化不了。能驗的是落點與尺寸的算法，而那正是會出事
 * 的地方：算錯的症狀是「圖有一半在頁面外」，畫面上看得見，匯出與列印時
 * 卻被裁掉。
 *
 * Apple 端的對照組是 `ImageDropPlacementTests.swift`，數字刻意一致。
 */
@RunWith(AndroidJUnit4::class)
class ImageDropPlacementTest {

    private val pageW = 800f
    private val pageH = 1132f

    @Test
    fun theImageIsCentredOnWhereYouLetGo() {
        val f = ImageDropPlacement.frame(400f, 500f, 1000f, 1000f, pageW, pageH)
        assertEquals(400f, f.x + f.width / 2f, 0.5f)
        assertEquals(500f, f.y + f.height / 2f, 0.5f)
    }

    @Test
    fun aPhoneCameraPhotoIsScaledDown() {
        // 4000 像素寬的照片照原尺寸放會蓋掉整個頁面。
        val f = ImageDropPlacement.frame(400f, 500f, 4032f, 3024f, pageW, pageH)
        assertEquals(ImageDropPlacement.PREFERRED_WIDTH, f.width, 0.5f)
        // 比例要留著 —— 拉變形比太大還糟。
        assertEquals(3024f / 4032f, f.height / f.width, 0.01f)
    }

    @Test
    fun aTinyIconIsNotBlownUp() {
        // 放大只會讓它糊掉。
        val f = ImageDropPlacement.frame(400f, 500f, 64f, 64f, pageW, pageH)
        assertEquals(64f, f.width, 0.5f)
    }

    @Test
    fun droppingAtTheEdgeKeepsTheWholeImageOnThePage() {
        val corners = listOf(0f to 0f, pageW to pageH, pageW to 0f, 0f to pageH)
        for ((x, y) in corners) {
            val f = ImageDropPlacement.frame(x, y, 1000f, 1000f, pageW, pageH)
            assertTrue("落在 ($x, $y) 時超出左／上緣", f.x >= 0f && f.y >= 0f)
            assertTrue("落在 ($x, $y) 時超出右緣", f.x + f.width <= pageW + 0.5f)
            assertTrue("落在 ($x, $y) 時超出下緣", f.y + f.height <= pageH + 0.5f)
        }
    }

    @Test
    fun aVeryTallImageStillLandsInsideThePage() {
        // 極端長條圖：高度可能比頁面還長。這時 max 與 min 會打架，
        // 沒有夾好的話算出來是負數座標。
        val f = ImageDropPlacement.frame(400f, 500f, 100f, 4000f, pageW, pageH)
        assertTrue(f.x >= 0f)
        assertTrue(f.y >= 0f)
    }

    @Test
    fun aNarrowPageNeverLetsOneImageFillTheWholeRow() {
        val f = ImageDropPlacement.frame(100f, 200f, 1000f, 1000f, 200f, 400f)
        assertTrue(f.width <= 200f * 0.8f + 0.5f)
    }

    @Test
    fun aDegenerateImageSizeDoesNotProduceZeroOrNaN() {
        // 讀不出尺寸的圖（BitmapFactory 的 inJustDecodeBounds 失敗時回 0）
        // 不能讓版面變成 0 或 NaN。
        val f = ImageDropPlacement.frame(400f, 500f, 0f, 0f, pageW, pageH)
        assertTrue(f.width > 0f)
        assertTrue(f.height > 0f)
        assertFalse(f.width.isNaN() || f.height.isNaN())
    }
}

package com.kairumo.padnote.ui

import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 響應式版面的規則（工作項 S-62）。
 *
 * 這兩條規則錯掉的症狀，都是「畫面看起來怪但說不出哪裡怪」：欄數算錯時
 * 手機上的卡片標題會被擠成「Start Recordi」，內容寬度沒有上限時平板橫向
 * 的一行字會橫跨整個螢幕。兩者都不會當掉，也不會有任何錯誤訊息 ——
 * 所以要用測試釘住。
 */
@RunWith(AndroidJUnit4::class)
class DesignSystemTest {

    @Test
    fun aPhoneWidthGetsASingleColumn() {
        // 手機直向可用寬度約 360dp。三張 200dp 的卡片塞不下，必須疊成一欄 ——
        // 硬塞的結果就是每張只剩 110dp，標題被截斷成「Start Recordi」。
        assertEquals(1, DS.columns(360.dp, minItem = 200.dp, max = 3))
    }

    @Test
    fun aTabletWidthGetsSeveralColumns() {
        assertEquals(3, DS.columns(900.dp, minItem = 200.dp, max = 3))
        assertEquals(2, DS.columns(500.dp, minItem = 200.dp, max = 3))
    }

    @Test
    fun theColumnCountNeverDropsBelowOneOrExceedsTheCap() {
        // 0 欄會讓整個區塊消失；超過上限會讓卡片細到看不清楚。
        assertEquals(1, DS.columns(0.dp, minItem = 200.dp))
        assertEquals(1, DS.columns(50.dp, minItem = 200.dp))
        assertEquals(3, DS.columns(5000.dp, minItem = 200.dp, max = 3))
    }

    @Test
    fun wideScreensGetABiggerGutterButContentStaysBounded() {
        assertTrue(DS.Content.gutter(1200.dp) > DS.Content.gutter(380.dp))
        // 內容寬度要有上限，否則平板橫向的一行字會橫跨整個螢幕。
        assertTrue(DS.Content.maxWidth < 1200.dp)
        assertTrue(DS.Content.readableMaxWidth < DS.Content.maxWidth)
    }
}

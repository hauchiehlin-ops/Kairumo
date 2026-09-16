package com.kairumo.padnote.text

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiSymbolCategory
import uniffi.padnote_core.symbolCategories
import uniffi.padnote_core.symbolPalette

/**
 * 符號盤（工作項 S-63）。
 *
 * Apple 端與 Android 端現在都向核心要這四組符號。這組測試守的是
 * **Android 真的拿得到**：綁定沒產生、或 so 沒更新時，符號面板會變成
 * 一片空白的格子，而那不會有任何錯誤訊息。
 */
@RunWith(AndroidJUnit4::class)
class SymbolPaletteTest {

    @Test
    fun allFourCategoriesComeBackFromTheCore() {
        val categories = symbolCategories()
        assertEquals("應該正好四類", 4, categories.size)
        for (category in categories) {
            assertTrue("$category 是空的 —— 面板上會是一個沒有東西的分頁",
                symbolPalette(category).isNotEmpty())
        }
    }

    @Test
    fun theCategoriesContainWhatTheirNameSays() {
        // 抽幾個代表字元：順序或分類錯位時，使用者會在「數學」分頁裡找到書名號。
        assertTrue(symbolPalette(FfiSymbolCategory.MATH).contains("∑"))
        assertTrue(symbolPalette(FfiSymbolCategory.ROMAN).contains("Ⅶ"))
        assertTrue(symbolPalette(FfiSymbolCategory.PUNCTUATION).contains("《"))
        assertTrue(symbolPalette(FfiSymbolCategory.SPECIAL).contains("※"))
    }

    @Test
    fun theOrderIsStable() {
        // 使用者會記住「星號在左上角第一個」。每次取都不一樣的話，
        // 這個面板就只能一個一個找。
        assertEquals(
            symbolPalette(FfiSymbolCategory.SPECIAL),
            symbolPalette(FfiSymbolCategory.SPECIAL)
        )
    }
}

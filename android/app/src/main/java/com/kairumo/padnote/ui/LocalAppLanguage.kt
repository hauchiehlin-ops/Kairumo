package com.kairumo.padnote.ui

import androidx.compose.runtime.compositionLocalOf

/**
 * 目前的介面語言標籤（BCP 47，例如 `zh-Hant`）。
 *
 * # 為什麼需要它
 *
 * 大部分元件都是從上層拿到 `languageTag` 參數。但畫布上的**把手**
 * （調整大小、旋轉）是最底層的元件，它們的呼叫端有六個檔案八處，
 * 而且中間好幾層都沒有語言參數 —— 為了兩個無障礙標籤把 `languageTag`
 * 一路串下去，會動到一大片與這件事無關的簽章。
 *
 * 所以改用 CompositionLocal：由 `MainActivity` 在最外層提供一次，
 * 需要的葉節點自己取。
 *
 * 預設值是繁體中文而不是拋例外：這個值只用來取顯示字串，少提供一次
 * 不該讓整個畫面崩掉 —— 最壞的情況是無障礙標籤念的是繁中。
 */
val LocalAppLanguage = compositionLocalOf { "zh-Hant" }

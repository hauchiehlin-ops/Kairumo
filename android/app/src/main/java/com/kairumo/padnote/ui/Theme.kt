package com.kairumo.padnote.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Kairumo 的配色（工作項 S-62）。
 *
 * # 在此之前有兩個問題
 *
 * `MainActivity` 直接寫 `MaterialTheme { ... }`，沒有給任何參數。那代表：
 *
 * 1. **用的是 Material 3 的預設基準色**，也就是那個紫色。Apple 端用的是
 *    系統藍，於是同一個 App 在兩個平台上是兩種顏色 —— 那是最容易被看出
 *    「這兩個不是同一個產品」的地方。
 * 2. **完全不跟隨深色模式。** 不給 colorScheme 時 Material 一律回淺色，
 *    使用者把系統切成深色，Kairumo 仍然是一片白。Apple 端因為用的是
 *    語意色（`.label`、`.systemGroupedBackground`）而自動跟著變。
 *
 * # 顏色怎麼挑的
 *
 * 對齊 Apple 的語意色，而不是自己發明一組：
 *
 * | 角色 | 對應的 iOS 語意色 |
 * |---|---|
 * | primary | systemBlue |
 * | background | systemGroupedBackground |
 * | surface | secondarySystemGroupedBackground |
 * | onSurfaceVariant | secondaryLabel |
 * | outlineVariant | separator |
 * | error | systemRed |
 *
 * 這樣兩個平台的明暗層次會一致：頁面底比卡片底深一階，卡片邊線極淡。
 */

// 淺色：對齊 iOS 淺色語意色
private val LightColors = lightColorScheme(
    primary = Color(0xFF007AFF),            // systemBlue
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFD6E9FF),
    onPrimaryContainer = Color(0xFF00305F),
    secondary = Color(0xFF5856D6),          // systemIndigo
    onSecondary = Color(0xFFFFFFFF),
    background = Color(0xFFF2F2F7),         // systemGroupedBackground
    onBackground = Color(0xFF1C1C1E),       // label
    surface = Color(0xFFFFFFFF),            // secondarySystemGroupedBackground
    onSurface = Color(0xFF1C1C1E),
    surfaceVariant = Color(0xFFF2F2F7),
    onSurfaceVariant = Color(0xFF6C6C70),   // secondaryLabel
    outline = Color(0xFFC6C6C8),            // separator
    outlineVariant = Color(0xFFD1D1D6),
    error = Color(0xFFFF3B30),              // systemRed
    onError = Color(0xFFFFFFFF)
)

// 深色：對齊 iOS 深色語意色
private val DarkColors = darkColorScheme(
    primary = Color(0xFF0A84FF),            // systemBlue（深色）
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF00305F),
    onPrimaryContainer = Color(0xFFD6E9FF),
    secondary = Color(0xFF5E5CE6),
    onSecondary = Color(0xFFFFFFFF),
    background = Color(0xFF000000),         // systemGroupedBackground（深色）
    onBackground = Color(0xFFF2F2F7),
    surface = Color(0xFF1C1C1E),            // secondarySystemGroupedBackground（深色）
    onSurface = Color(0xFFF2F2F7),
    surfaceVariant = Color(0xFF2C2C2E),
    onSurfaceVariant = Color(0xFFAEAEB2),   // secondaryLabel（深色）
    outline = Color(0xFF48484A),
    outlineVariant = Color(0xFF38383A),     // separator（深色）
    error = Color(0xFFFF453A),              // systemRed（深色）
    onError = Color(0xFFFFFFFF)
)

/**
 * 整個 App 的主題。
 *
 * **刻意不用 dynamic color（Material You）。** 動態取色會讓 Kairumo 跟著
 * 使用者的桌布變色 —— 在 Android 上那是個好功能，但這個 App 要的是兩個
 * 平台看起來是同一個產品。品牌色比跟隨桌布重要。
 */
@Composable
fun KairumoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content
    )
}

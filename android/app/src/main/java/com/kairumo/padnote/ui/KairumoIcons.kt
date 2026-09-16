package com.kairumo.padnote.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/**
 * 自己帶的兩個圖示（工作項 S-62）。
 *
 * # 為什麼不直接用 material-icons-extended
 *
 * 那個套件有數千個圖示，而這個模組 `isMinifyEnabled = false` —— 整包都會
 * 進到 APK 裡。為了兩個字形多背幾 MB，與這個專案在 reqwest、llama.cpp 上
 * 做過的判斷是同一件事：**平台裝得下不代表使用者該下載它**。
 *
 * # 為什麼不用文字符號
 *
 * 原本畫的是「◉」「◆」這兩個**字元**。字元會跟著字型走：對不齊基線、
 * 大小不一致，換一台裝置的字型就長得不一樣。那是「看起來像半成品」
 * 最直接的來源之一。
 *
 * # 為什麼不用 core 裡現成的
 *
 * core 圖示集裡沒有麥克風。最接近的 `PlayArrow` 是**播放**的意思 ——
 * 用它當「開始錄音」，使用者會以為是在播放某個東西。寧可自己畫一個對的，
 * 也不要用一個意思不對的。
 */
object KairumoIcons {

    /** 麥克風。用於「開始錄音」。 */
    val Mic: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoMic",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            // 收音頭
            path(fill = SolidColor(Color.Black)) {
                moveTo(12f, 2f)
                curveTo(10.34f, 2f, 9f, 3.34f, 9f, 5f)
                verticalLineTo(12f)
                curveTo(9f, 13.66f, 10.34f, 15f, 12f, 15f)
                curveTo(13.66f, 15f, 15f, 13.66f, 15f, 12f)
                verticalLineTo(5f)
                curveTo(15f, 3.34f, 13.66f, 2f, 12f, 2f)
                close()
            }
            // 拾音弧線
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(5.5f, 11.5f)
                verticalLineTo(12.2f)
                curveTo(5.5f, 15.8f, 8.4f, 18.7f, 12f, 18.7f)
                curveTo(15.6f, 18.7f, 18.5f, 15.8f, 18.5f, 12.2f)
                verticalLineTo(11.5f)
            }
            // 支架
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round
            ) {
                moveTo(12f, 18.7f)
                verticalLineTo(21.5f)
            }
        }.build()
    }

    /** 立方體。用於「素材圖庫」。 */
    val Cube: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoCube",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            // 外框
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 2.6f)
                lineTo(20.5f, 7.3f)
                verticalLineTo(16.7f)
                lineTo(12f, 21.4f)
                lineTo(3.5f, 16.7f)
                verticalLineTo(7.3f)
                close()
            }
            // 上表面與中軸，讓它讀起來是立方體而不是六邊形
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(3.5f, 7.3f)
                lineTo(12f, 12f)
                lineTo(20.5f, 7.3f)
            }
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round
            ) {
                moveTo(12f, 12f)
                verticalLineTo(21.4f)
            }
        }.build()
    }
}

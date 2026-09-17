package com.kairumo.padnote.ui

import android.app.Activity
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import kotlinx.coroutines.flow.collect

/**
 * 折疊機的姿態。
 *
 * # 為什麼不能只看寬度
 *
 * 版面的斷點（`layoutMetrics`）用寬度就夠了 —— 闔起來的折疊機就是一支手機、
 * 攤開的就是一台小平板，這部分本來就成立。**但寬度說不出「畫面中間橫著
 * 一條鉸鏈」**：攤開的 Pixel Fold 上，畫布正中央有一道實體摺痕，筆跡寫在
 * 那裡會斷成兩截；半開（桌面模式）的機器更是上半截立著、下半截躺平。
 *
 * 內容壓在鉸鏈上是折疊機最容易一眼看穿的毛病，而它只在折疊機上出現 ——
 * 所以要問系統，不能用猜的。
 *
 * # 為什麼不是用它重排整個畫面
 *
 * Apple 沒有折疊機，而對齊計劃的目標是「跟 Apple 一模一樣」。所以這裡
 * 只做**避開**：該讓開的讓開，版面本身仍然照同一套斷點走。折疊機上多
 * 長出一套 Android 專屬的版面，就是新的分家。
 */
data class FoldPosture(
    /** 鉸鏈把畫面切成左右兩半（攤開的直立姿態）。 */
    val separatingVertically: Boolean = false,
    /** 鉸鏈把畫面切成上下兩半（桌面模式／橫著攤開）。 */
    val separatingHorizontally: Boolean = false,
    /** 鉸鏈左緣離畫面左邊多遠。只有 `separatingVertically` 時有意義。 */
    val hingeStart: Dp = 0.dp,
    /** 鉸鏈本身有多寬／多高。摺痕型（無縫）的機器是 0。 */
    val hingeSize: Dp = 0.dp
) {
    /** 有沒有東西要讓開。 */
    val isSeparating: Boolean get() = separatingVertically || separatingHorizontally
}

/**
 * 訂閱系統回報的視窗版面資訊。
 *
 * 不是折疊機（或折疊機闔著）的時候回一個空姿態 —— 呼叫端不必分兩條路。
 */
@Composable
fun rememberFoldPosture(activity: Activity): FoldPosture {
    val density = LocalDensity.current
    val state: State<FoldPosture> = produceState(FoldPosture(), activity, density) {
        WindowInfoTracker.getOrCreate(activity)
            .windowLayoutInfo(activity)
            .collect { info ->
                val fold = info.displayFeatures
                    .filterIsInstance<FoldingFeature>()
                    .firstOrNull { it.isSeparating }
                value = if (fold == null) {
                    FoldPosture()
                } else {
                    val vertical = fold.orientation == FoldingFeature.Orientation.VERTICAL
                    with(density) {
                        FoldPosture(
                            separatingVertically = vertical,
                            separatingHorizontally = !vertical,
                            hingeStart = fold.bounds.left.toDp(),
                            hingeSize = if (vertical) {
                                (fold.bounds.right - fold.bounds.left).toDp()
                            } else {
                                (fold.bounds.bottom - fold.bounds.top).toDp()
                            }
                        )
                    }
                }
            }
    }
    return state.value
}

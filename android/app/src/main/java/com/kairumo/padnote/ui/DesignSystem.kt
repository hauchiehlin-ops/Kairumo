package com.kairumo.padnote.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 版面與外觀的共用尺度（工作項 S-62）。
 *
 * # 為什麼需要它
 *
 * 在此之前，間距、圓角、字級都是每一處各寫一個數字：8、10、12、14、16、18、
 * 20、22 的內距與圓角混用。單看每一處都合理，放在同一個畫面上就是
 * 「說不出哪裡怪，但就是不精緻」。
 *
 * # 與 Apple 的對應
 *
 * `apple/Sources/DesignSystem.swift` 是同一組尺度、同一組語意名稱。
 * 數字要一致，兩邊的畫面才會像同一個 App。改這裡之前先確認那邊。
 */
object DS {

    /**
     * 間距。4 的倍數，中間值刻意不提供 —— 兩個相鄰區塊一個用 14 一個用 16，
     * 看得出來不齊，但看不出來為什麼。
     */
    object Space {
        /** 4 —— 圖示與其標籤之間。 */
        val xxs: Dp = 4.dp
        /** 8 —— 同一組元件之內。 */
        val xs: Dp = 8.dp
        /** 12 —— 卡片內的列距。 */
        val s: Dp = 12.dp
        /** 16 —— 卡片內距、元件之間的標準距離。 */
        val m: Dp = 16.dp
        /** 24 —— 區塊與區塊之間。 */
        val l: Dp = 24.dp
        /** 32 —— 大段落之間、頁面上下留白。 */
        val xl: Dp = 32.dp
    }

    object Radius {
        val s: Dp = 8.dp
        val m: Dp = 12.dp
        val l: Dp = 16.dp
    }

    /**
     * 內容寬度。
     *
     * **這是「響應式」最關鍵的一個數字。** 在此之前內容會把整個視窗填滿，
     * 平板橫向時一列文字橫跨整個螢幕，眼睛要掃過全寬才讀完一行。
     * 上限之後，多出來的寬度變成兩側留白，內容維持可讀的行長。
     */
    object Content {
        val maxWidth: Dp = 1040.dp
        val readableMaxWidth: Dp = 720.dp

        /** 依可用寬度決定左右外距。 */
        fun gutter(width: Dp): Dp = when {
            width < 420.dp -> Space.m
            width < 900.dp -> Space.l
            else -> Space.xl
        }
    }

    /**
     * 一排放得下幾個至少 [minItem] 寬的項目。
     *
     * 抽成函式是為了**測得到**：這條規則錯掉的症狀是手機上的卡片被擠成
     * 「Start Recordi」，而那種錯誤只有把畫面叫出來才看得見。
     * 與 Apple 端 `GridItem(.adaptive(minimum:))` 是同一個意思。
     */
    fun columns(available: Dp, minItem: Dp, max: Int = 3, gap: Dp = Space.xs): Int {
        if (available <= 0.dp || minItem <= 0.dp) return 1
        return ((available + gap) / (minItem + gap)).toInt().coerceIn(1, max)
    }

    /** 圖示只有三種大小。四種以上就看得出來沒有系統。 */
    object Icon {
        val small: Dp = 16.dp
        val medium: Dp = 22.dp
        val large: Dp = 28.dp
    }
}

/** 卡片邊線。**非常淡** —— 邊線一重，整個畫面就吵。 */
@Composable
fun dsHairline(): Color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)

/**
 * 內容置中並限制最大寬度。**寬螢幕的版面就靠這一個。**
 */
fun Modifier.dsContentWidth(maxWidth: Dp = DS.Content.maxWidth): Modifier =
    this.widthIn(max = maxWidth)

/**
 * 標準卡片：底色、圓角、極淡的邊線。
 *
 * 用邊線而不是陰影：一個畫面上十幾張卡片各自投影時，整體會顯得髒。
 * 陰影留給真正浮起來的東西（對話框、拖曳中的物件）。
 */
@Composable
fun Modifier.dsCard(radius: Dp = DS.Radius.m): Modifier = this
    .clip(RoundedCornerShape(radius))
    .background(MaterialTheme.colorScheme.surface)
    .border(BorderStroke(1.dp, dsHairline()), RoundedCornerShape(radius))

/** 區塊標題。左邊標題、右邊動作，整個 App 一種寫法。 */
@Composable
fun DSSectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit = {}
) {
    Row(
        modifier = modifier.fillMaxWidth().padding(bottom = DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Box { trailing() }
    }
}

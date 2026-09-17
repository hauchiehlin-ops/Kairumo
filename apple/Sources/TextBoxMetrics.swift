//
//  TextBoxMetrics.swift
//  Kairumo
//
//  文字方塊的尺寸下限與內距。**兩個平台共用同一組規則**
//  （Android 端在 `text/TextBoxLayer.kt`，數字必須一致）。
//

import CoreGraphics

/// 文字方塊的尺寸規則。
///
/// # 為什麼下限要這麼小
///
/// 原本的下限是 120 × 60。週計畫、月計畫、待辦清單這些樣板的格子大約是
/// 100 × 45 —— **下限比格子還大，於是文字方塊放不進任何一格**：
/// 使用者想在「週二」那一欄填一件事，方塊一定會壓到隔壁兩欄。
/// 那個下限當初是為了「比一行字還窄的方框，每個字都會自己換一行」，
/// 但那件事的正確界線是「放得下一個字」，不是 120 點。
///
/// 現在的下限是放得下一個中文字加內距的大小。再小就真的只剩邊框了。
enum TextBoxMetrics {
    /// 寬度下限（點）。約等於一個 16pt 中文字加左右內距。
    static let minWidth: CGFloat = 32
    /// 高度下限（點）。約等於一行 16pt 中文字加上下內距。
    static let minHeight: CGFloat = 24

    /// 一般情況下的內距。
    ///
    /// 這個數字同時出現在畫布、縮圖與匯出三條路上，差幾點就會讓同一段文字
    /// 換行位置不同、版面分家。
    static let padding: CGFloat = 14

    /// 內距不再縮小的門檻。
    ///
    /// 剛好是舊的高度下限：**比這個大的方塊，內距一點都不會變**。
    /// 這不是巧合而是刻意的 —— 既有筆記裡的每一個方塊都不小於舊下限，
    /// 所以升級上來的版面一個字都不會重排。
    private static let fullPaddingThreshold: CGFloat = 60

    /// 這個尺寸的方塊該用多少內距。
    ///
    /// 小方塊仍然套 14 的話，內距就吃掉整個方塊：40 點高的格子扣掉上下
    /// 各 14 只剩 12 點，一行 16pt 的字放不下 —— 看起來像「打了字卻沒出現」。
    /// 所以小方塊的內距按比例縮，但保留最少 2 點，文字不會貼在邊框上。
    static func padding(width: CGFloat, height: CGFloat) -> CGFloat {
        let shortSide = min(width, height)
        guard shortSide < fullPaddingThreshold else { return padding }
        return max(2, shortSide / 6)
    }
}

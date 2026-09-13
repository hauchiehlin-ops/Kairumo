//
//  BrushCursor.swift
//  Kairumo
//
//  以筆頭取代滑鼠游標。
//
//  # 為什麼要做
//
//  選了螢光筆卻看到一個箭頭 —— 使用者得先畫一筆才知道自己選到什麼、
//  那一筆會有多粗。把游標換成對應的筆頭，「選了什麼」與「會畫多粗」
//  在落筆之前就看得見。
//
//  # 為什麼是程式繪製而不是圖檔
//
//  筆頭要**跟著筆寬變化**（拖曳筆寬時游標要同步變大變小），而且要在各種
//  螢幕倍率下都銳利。用 `UIBezierPath` 即時畫出來是向量的，兩件事都成立；
//  一張張預先切好的點陣圖兩件事都不成立。
//

import UIKit

enum BrushCursor {

    /// 游標圖的邊長上限。
    ///
    /// 太大的游標會擋住自己要畫的地方 —— 尤其是橡皮擦，使用者看不到
    /// 正要擦掉的東西。
    static let maxSide: CGFloat = 44

    /// 產生某個工具在某個筆寬下的筆頭形狀。
    ///
    /// 回傳 `UIBezierPath` 而不是圖：`UIPointerStyle` 吃的就是路徑，而且路徑是
    /// 真正的向量 —— 在任何螢幕倍率下都銳利，也能隨筆寬即時改變，
    /// 兩件事預先切好的點陣圖都做不到。
    ///
    /// - Returns: `nil` 代表這個工具維持系統游標（例如套索 —— 十字準心是
    ///   系統既有的語彙，自己畫一個只會更難認）。
    static func path(for tool: EditorToolType, strokeWidth: CGFloat) -> UIBezierPath? {
        guard tool != .lasso else { return nil }

        // 筆寬直接決定筆頭大小，但要有上下限：1pt 的筆頭在螢幕上小到看不見，
        // 太大的又會擋住自己正要畫（或正要擦）的地方。
        let tip = min(max(strokeWidth * tipScale(for: tool), 8), maxSide)

        switch tool {
        case .highlighter, .marker:
            return chiselPath(width: tip)
        default:
            // 圓筆頭與橡皮擦都是圓的。差別在系統怎麼呈現它：
            // 橡皮擦用比較大的圈，使用者才看得到圈內正要被擦掉的東西。
            return UIBezierPath(ovalIn: CGRect(
                x: -tip / 2, y: -tip / 2, width: tip, height: tip))
        }
    }

    /// 扁筆頭（螢光筆／麥克筆）：斜的圓角矩形。
    ///
    /// 斜角是它辨識度的來源 —— 正的矩形跟圓筆頭在小尺寸下分不出來。
    private static func chiselPath(width: CGFloat) -> UIBezierPath {
        let height = max(4, width / 2.4)
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: height / 2)
        path.apply(CGAffineTransform(rotationAngle: -.pi / 6))
        return path
    }

    /// 各工具的筆頭相對大小。
    ///
    /// 與 `applyTool` 裡餵給 PencilKit 的倍率一致 —— 游標顯示的粗細若跟實際
    /// 畫出來的不一樣，這個功能就變成誤導。
    static func tipScale(for tool: EditorToolType) -> CGFloat {
        switch tool {
        case .ballpoint, .pencil: return 0.65
        case .pen: return 1.1
        case .brush, .watercolor: return 2.2
        case .marker: return 2.8
        case .highlighter: return 3.8
        case .eraser: return 3.0
        case .lasso: return 1
        }
    }

    // MARK: - 給測試用的尺寸推算

    /// 這個工具在這個筆寬下的筆頭直徑（點）。
    ///
    /// 抽出來是為了讓測試能直接檢查「游標大小有沒有跟著筆寬變」，
    /// 而不必去量一條貝茲曲線的外框。
    static func tipDiameter(for tool: EditorToolType, strokeWidth: CGFloat) -> CGFloat {
        min(max(strokeWidth * tipScale(for: tool), 8), maxSide)
    }
}

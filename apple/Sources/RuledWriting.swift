//
//  RuledWriting.swift
//  Kairumo
//
//  文字模式「隨點即書」：點哪裡就從哪裡開始寫，橫線紙上字的基準線**坐在格線上**，
//  一行一行對著格線往下寫 —— 像 Word、像在真正的橫線紙上寫字。
//
//  # 為什麼獨立成純函式
//
//  這件事壞過兩次，兩次都是「看起來該對、實際差幾點」。幾何全是算術，
//  放在 View 裡就只能靠眼睛驗；抽出來之後每個數字都有測試守著。
//
//  # 版面怎麼對上格線
//
//  文字方塊裡，第一行的基準線距方塊頂端 = 內距 + 字體的 ascender；
//  行與行之間 = 字體行高 + `lineSpacing`。所以：
//
//  - 方塊頂端 = 格線 y − 內距 − ascender
//  - `lineSpacing` = 格線間距 − 字體行高（第二行以後的基準線也落在下一條格線上）
//
//  **內距固定用 `TextBoxMetrics` 的「完整」值（14）**，方塊高度一律不小於 60。
//  `TextBoxMetrics.padding(width:height:)` 在小方塊上會縮內距，方塊一長大內距就跳回 14 ——
//  文字會在使用者眼前往下掉 8 點，離開格線。

import CoreGraphics
import UIKit

enum RuledWriting {

    /// 方塊內距。固定為 `TextBoxMetrics` 的完整值，不隨方塊大小變。
    static var padding: CGFloat { TextBoxMetrics.padding(width: 200, height: fullPaddingHeight) }

    /// 方塊高度下限：不小於這個高度，`TextBoxMetrics` 才不會縮內距。
    static let fullPaddingHeight: CGFloat = 60

    // MARK: 找出格線

    /// 這一頁所有水平格線的 y，由上到下、去掉重複。
    ///
    /// **導引線與底紋都要收。** 原本只有「導引線是空的才看底紋」—— 橫線紙的版面常有一條
    /// 表頭分隔線，導引線就不是空的，底紋那幾十條橫線全被忽略，附近根本沒有線可以吸附。
    static func horizontalRules(guides: [FfiGuide], bands: [FfiTextureBand]) -> [CGFloat] {
        var ys: [CGFloat] = []
        for g in guides where g.kind == .line && abs(g.h) < 1 && g.w > 50 {
            ys.append(CGFloat(g.y))
        }
        for b in bands where b.kind == .line && abs(b.h) < 1 && b.w > 50 {
            for i in 0 ..< Int(b.count) {
                for j in 0 ..< Int(b.count2) {
                    ys.append(CGFloat(b.y + b.stepY * Float(i) + b.step2Y * Float(j)))
                }
            }
        }
        return dedupe(ys)
    }

    static func dedupe(_ values: [CGFloat], tolerance: CGFloat = 0.75) -> [CGFloat] {
        var out: [CGFloat] = []
        for y in values.sorted() where out.last.map({ y - $0 > tolerance }) ?? true {
            out.append(y)
        }
        return out
    }

    /// 格線的間距：相鄰間距的中位數。太少或太不規則（不像橫線紙）回 `nil`。
    static func step(of rules: [CGFloat]) -> CGFloat? {
        guard rules.count >= 3 else { return nil }
        let gaps = zip(rules.dropFirst(), rules).map { $0 - $1 }.filter { $0 > 6 }.sorted()
        guard !gaps.isEmpty else { return nil }
        let median = gaps[gaps.count / 2]
        // 橫線紙的間距在 14–80 點之間。超出這個範圍的多半是版面分隔線，不是讓人寫字的行。
        return (14 ... 80).contains(median) ? median : nil
    }

    // MARK: 擺放

    struct Placement: Equatable {
        /// 方塊頂端 y。
        var top: CGFloat
        /// 字級（格線間距太小放不下原字級時會縮）。
        var fontSize: CGFloat
        /// 行距，讓每一行的基準線都落在格線上。
        var lineSpacing: CGFloat
        /// 這個位置的格線 y（第一行基準線所在）。
        var rule: CGFloat
        /// 格線間距。沒有格線時為字體行高。
        var step: CGFloat
    }

    /// 點在 `tapY` 的時候，字該坐在哪一條格線上。
    ///
    /// 點在兩條線之間，就寫在**下面那一條**（像在紙上：字坐在線上，點在線上方的空白處）；
    /// 剛好點在線下一點點（不到間距的 30%）算那一條。
    static func rule(forTapY tapY: CGFloat, in rules: [CGFloat], step: CGFloat) -> CGFloat? {
        rules.first { $0 >= tapY - step * 0.3 } ?? rules.last
    }

    static func ascender(fontSize: CGFloat, bold: Bool = false) -> CGFloat {
        font(fontSize, bold: bold).ascender
    }

    static func lineHeight(fontSize: CGFloat, bold: Bool = false) -> CGFloat {
        font(fontSize, bold: bold).lineHeight
    }

    private static func font(_ size: CGFloat, bold: Bool) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    /// 橫線紙上的擺放。`rules` 不像橫線紙時回 `nil`，由呼叫端改用自由擺放。
    static func placement(
        tapY: CGFloat, rules: [CGFloat], fontSize: CGFloat, minTop: CGFloat
    ) -> Placement? {
        guard let step = step(of: rules) else { return nil }
        // 字級：一行要放得進格線間距。
        var size = fontSize
        while lineHeight(fontSize: size) > step && size > 9 { size -= 1 }
        let asc = ascender(fontSize: size)
        let natural = lineHeight(fontSize: size)

        // 從點到的那條線開始往下找，第一條讓方塊頂端落在可用範圍內的。
        guard var rule = rule(forTapY: tapY, in: rules, step: step) else { return nil }
        while rule - padding - asc < minTop, let next = rules.first(where: { $0 > rule + 0.5 }) {
            rule = next
        }
        return Placement(
            top: rule - padding - asc,
            fontSize: size,
            lineSpacing: max(0, step - natural),
            rule: rule,
            step: step)
    }

    /// 沒有格線（空白紙）的擺放：點的位置就是第一行文字的垂直中心，文字從點的地方開始。
    static func freePlacement(tapY: CGFloat, fontSize: CGFloat, minTop: CGFloat) -> Placement {
        let natural = lineHeight(fontSize: fontSize)
        let top = max(minTop, tapY - padding - natural / 2)
        return Placement(top: top, fontSize: fontSize, lineSpacing: 0, rule: top + padding + ascender(fontSize: fontSize), step: natural)
    }

    // MARK: 高度

    /// 內容需要的方塊高度（含上下內距，不小於 `fullPaddingHeight`）。
    static func boxHeight(
        text: String, width: CGFloat, fontSize: CGFloat, bold: Bool, lineSpacing: CGFloat
    ) -> CGFloat {
        let font = font(fontSize, bold: bold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        // 空字串也算一行 —— 剛點下去、還沒打字的方塊要有一行的高度。
        let sample = text.isEmpty ? " " : text
        let rect = (sample as NSString).boundingRect(
            with: CGSize(width: max(1, width - 2 * padding), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil)
        // 結尾是換行時，最後一行是空的但游標在那裡 —— 要算進去。
        let trailingNewline = text.hasSuffix("\n") ? font.lineHeight + lineSpacing : 0
        return max(fullPaddingHeight, ceil(rect.height + trailingNewline) + 2 * padding)
    }
}

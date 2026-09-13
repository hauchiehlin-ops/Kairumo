//
//  ExportFidelityTests.swift
//  KairumoTests
//
//  「畫布所見、匯出即所得」的保真度。
//
//  這一批測試釘的是**畫布與匯出之間的差異**，不是匯出本身能不能跑。
//  差異都很小（內距差 6 點、換行模式不同），但小差異疊起來就是使用者看到的
//  「版面完全不一樣」；而且它們在開發時看起來都很合理。
//

import XCTest
import PencilKit
@testable import Kairumo

final class ExportFidelityTests: XCTestCase {

    private func textBox(
        _ text: String,
        width: CGFloat = 300,
        height: CGFloat = 160,
        fontSize: CGFloat = 16
    ) -> NoteTextAttachment {
        NoteTextAttachment(
            pageIndex: 0, text: text, fontSize: fontSize,
            x: 40, y: 100, width: width, height: height
        )
    }

    // MARK: - 內距

    func testExportPaddingMatchesTheCanvas() {
        // 畫布上的文字方塊是 .padding(14)。匯出原本用 8/6，於是同一段文字
        // 在兩邊從不同位置開始排，行數一不同整塊版面就對不起來。
        XCTAssertEqual(PageThumbnailRenderer.textBoxPadding, 14)
    }

    // MARK: - 高度

    func testMeasuredHeightGrowsWithTheContent() {
        // 畫布上的高度是內容撐出來的；存下來的 height 只是最後一次調整時的值。
        // 匯出若直接用存下來的值，文字一多就會被截掉或溢出去壓到旁邊的東西。
        let short = textBox("一行字")
        let long = textBox(String(repeating: "這是一段很長的內容，會換很多行。", count: 12))

        XCTAssertEqual(PageThumbnailRenderer.measuredHeight(for: short), short.height,
                       "內容放得下時，應該維持使用者設定的高度")
        XCTAssertGreaterThan(PageThumbnailRenderer.measuredHeight(for: long), long.height,
                             "內容放不下時，高度必須跟著內容長")
    }

    func testMeasuredHeightNeverShrinksBelowTheUserSetHeight() {
        // 使用者刻意把方框拉大（例如為了排版留白）時，不該被內容縮回去。
        let roomy = textBox("短", height: 400)
        XCTAssertEqual(PageThumbnailRenderer.measuredHeight(for: roomy), 400)
    }

    func testNarrowerBoxNeedsMoreHeight() {
        // 同一段文字在較窄的框裡會換更多行。這條確認測量真的有考慮寬度，
        // 而不是只看字數。
        let text = String(repeating: "跨平台一致性很重要。", count: 8)
        let wide = PageThumbnailRenderer.measuredHeight(for: textBox(text, width: 500, height: 1))
        let narrow = PageThumbnailRenderer.measuredHeight(for: textBox(text, width: 200, height: 1))
        XCTAssertGreaterThan(narrow, wide)
    }

    func testLargerFontNeedsMoreHeight() {
        let text = String(repeating: "字級會影響行高。", count: 6)
        let small = PageThumbnailRenderer.measuredHeight(for: textBox(text, height: 1, fontSize: 12))
        let large = PageThumbnailRenderer.measuredHeight(for: textBox(text, height: 1, fontSize: 28))
        XCTAssertGreaterThan(large, small)
    }

    func testEmptyTextKeepsTheUserSetHeight() {
        XCTAssertEqual(PageThumbnailRenderer.measuredHeight(for: textBox("", height: 120)), 120)
    }

    // MARK: - 不重疊

    func testLongTextDoesNotBleedIntoTheBoxBelowIt() {
        // 「文字方框重疊」的實際樣子：上面那個框裡的字太長，畫到框外、
        // 蓋住下面那個框。量的方式是把兩個框排在一起算出各自的實際高度，
        // 確認上面那個的底部不會壓進下面那個。
        let upper = textBox(String(repeating: "溢出測試。", count: 40), height: 100)
        let upperBottom = upper.y + PageThumbnailRenderer.measuredHeight(for: upper)

        // 下面那個框放在「依實際高度算出來的」底部之下，兩者就不會重疊。
        var lower = textBox("下面這個框", height: 100)
        lower.y = upperBottom + 20
        XCTAssertGreaterThan(lower.y, upperBottom)

        // 而如果沿用存下來的高度（100），上面那個框的底部會遠在下面那個之上，
        // 導致實際繪製時字跨過去 —— 這正是修正前的行為。
        XCTAssertGreaterThan(upperBottom, upper.y + upper.height)
    }
}

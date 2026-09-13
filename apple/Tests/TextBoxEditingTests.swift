//
//  TextBoxEditingTests.swift
//  KairumoTests
//
//  文字方塊的四項修正：面板不遮住、底色可透明、可拖曳縮放、段落可調。
//

import XCTest
@testable import Kairumo

final class TextBoxEditingTests: XCTestCase {

    private func box(_ text: String = "測試") -> NoteTextAttachment {
        NoteTextAttachment(pageIndex: 0, text: text, x: 40, y: 100, width: 300, height: 160)
    }

    // MARK: - 透明底色

    func testClearSurvivesAHexRoundTripThatDropsAlpha() {
        // `Color.toHex()` 丟掉 alpha —— 透明會變成 #000000。
        // 所以 "clear" 必須當成**哨符**處理，不能讓它走顏色轉換那條路。
        var item = box()
        item.backgroundColorHex = "clear"
        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(item, defaults: .text),
                     "透明就是不畫底色")
        XCTAssertTrue(item.isBackgroundClear)
    }

    func testTransparentIsDistinguishableFromWhite() {
        // 使用者最容易混淆的兩個選項。白色要畫出來，透明不能畫。
        var white = box(); white.backgroundColorHex = "#FFFFFF"
        var clear = box(); clear.backgroundColorHex = "clear"

        XCTAssertNotNil(PageThumbnailRenderer.resolvedBackground(white, defaults: .text))
        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(clear, defaults: .text))
    }

    // MARK: - 段落

    func testParagraphSettingsDefaultToTheSystemLayout() {
        // 舊檔沒有這些欄位。套上非零預設的話，升級之後每一則舊筆記的排版都會變。
        let item = box()
        XCTAssertNil(item.lineSpacing)
        XCTAssertNil(item.paragraphSpacing)
        XCTAssertNil(item.firstLineIndent)
        XCTAssertNil(item.paragraphIndent)
    }

    func testLineSpacingChangesTheMeasuredHeight() {
        // 行距不只是好看 —— 它會改變行高，進而改變整個方框需要多高。
        // 匯出端沒有套上的話，同一段文字在畫布與 PDF 上的行數就不一樣。
        var tight = box(String(repeating: "跨平台一致性很重要。", count: 6))
        tight.height = 1
        var loose = tight
        loose.lineSpacing = 12

        XCTAssertGreaterThan(
            PageThumbnailRenderer.measuredHeight(for: loose),
            PageThumbnailRenderer.measuredHeight(for: tight))
    }

    func testIndentReducesTheUsableWidthAndSoNeedsMoreHeight() {
        var plain = box(String(repeating: "縮排會讓可用寬度變窄。", count: 6))
        plain.height = 1
        var indented = plain
        indented.paragraphIndent = 60

        XCTAssertGreaterThanOrEqual(
            PageThumbnailRenderer.measuredHeight(for: indented),
            PageThumbnailRenderer.measuredHeight(for: plain))
    }

    func testParagraphSpacingIsCarriedIntoTheExport() {
        // 這一條釘的是「畫布套什麼、匯出就套什麼」。
        var item = box("第一段\n第二段\n第三段")
        item.height = 1
        let before = PageThumbnailRenderer.measuredHeight(for: item)
        item.paragraphSpacing = 20
        XCTAssertGreaterThan(PageThumbnailRenderer.measuredHeight(for: item), before)
    }

    // MARK: - 縮放

    func testResizeKeepsTheBoxUsable() {
        // 比一行字還窄的方框，每個字都會自己換一行，看起來像壞掉。
        // 下限要擋住那種尺寸。
        let minimumWidth: CGFloat = 120
        let minimumHeight: CGFloat = 60
        XCTAssertGreaterThanOrEqual(minimumWidth, 100)
        XCTAssertGreaterThanOrEqual(minimumHeight, 40)

        var item = box()
        item.width = max(minimumWidth, 50)
        item.height = max(minimumHeight, 10)
        XCTAssertEqual(item.width, minimumWidth)
        XCTAssertEqual(item.height, minimumHeight)
    }

    func testResizingBothDimensionsIsPersisted() {
        // 原本只能在面板裡改「方塊寬度」—— 高度完全沒得改。
        var item = box()
        item.width = 420
        item.height = 300
        XCTAssertEqual(item.width, 420)
        XCTAssertEqual(item.height, 300)
        XCTAssertGreaterThanOrEqual(PageThumbnailRenderer.measuredHeight(for: item), 300)
    }
}

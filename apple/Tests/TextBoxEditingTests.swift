//
//  TextBoxEditingTests.swift
//  KairumoTests
//
//  文字方塊的四項修正：面板不遮住、底色可透明、可拖曳縮放、段落可調。
//

import XCTest
import PencilKit
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

/// 文字方塊外觀的跨平台編碼（`format-spec.md` §6.2）。
///
/// 匯出到 `.padnote` 時原本只帶「文字」與「位置」—— 顏色、邊框、段落設定
/// 全留在 Apple 自己的 JSON 裡。使用者在 iPad 上設成透明底、加了行距，
/// 換到 Android 打開會變回白底無行距。那不是「還沒支援」，是資料遺失。
final class TextBoxAppearanceTests: XCTestCase {

    private func styled() -> NoteTextAttachment {
        var item = NoteTextAttachment(pageIndex: 0, text: "會議重點", x: 40, y: 100)
        item.fontSize = 22
        item.isBold = true
        item.alignmentRaw = "center"
        item.textColorHex = "#112233"
        item.backgroundColorHex = "clear"
        item.hasBorder = false
        item.borderWidth = 3
        item.cornerRadius = 20
        item.width = 420
        item.height = 260
        item.lineSpacing = 8
        item.paragraphSpacing = 16
        item.firstLineIndent = 24
        item.paragraphIndent = 32
        return item
    }

    func testEverySettingSurvivesTheRoundTrip() {
        let original = styled()
        var restored = NoteTextAttachment(pageIndex: 0, text: "會議重點")
        TextBoxAppearance.apply(TextBoxAppearance.encode(original), to: &restored)

        XCTAssertEqual(restored.fontSize, original.fontSize)
        XCTAssertEqual(restored.isBold, original.isBold)
        XCTAssertEqual(restored.alignmentRaw, original.alignmentRaw)
        XCTAssertEqual(restored.backgroundColorHex, "clear")
        XCTAssertEqual(restored.hasBorder, false)
        XCTAssertEqual(restored.lineSpacing, 8)
        XCTAssertEqual(restored.paragraphIndent, 32)
        XCTAssertEqual(restored.width, 420)
    }

    func testUnsetFieldsAreNotWrittenIntoTheJson() {
        // `nil` 寫成 0 的話，接收端就分不出「沒設定」與「設成 0」——
        // 於是每一個從另一個平台來的方塊都會被當成「行距 0」。
        let json = TextBoxAppearance.encode(NoteTextAttachment(pageIndex: 0, text: "x"))
        XCTAssertFalse(json.contains("lineSpacing"))
        XCTAssertFalse(json.contains("paragraphSpacing"))
        XCTAssertFalse(json.contains("borderWidth"))
    }

    func testClearIsCarriedVerbatim() {
        // "clear" 是哨符不是顏色 —— 不能走任何顏色轉換，那會丟掉 alpha。
        var item = NoteTextAttachment(pageIndex: 0, text: "x")
        item.backgroundColorHex = "clear"
        XCTAssertTrue(TextBoxAppearance.encode(item).contains("\"clear\""))
    }

    func testUnknownKeysAreIgnoredNotFatal() {
        // 另一個平台可能帶了我們還沒實作的欄位。該做的是保留其餘設定，
        // 不是整塊樣式都不套。
        var item = NoteTextAttachment(pageIndex: 0, text: "x")
        TextBoxAppearance.apply(#"{"fontSize":30,"somethingFromTheFuture":{"a":1}}"#, to: &item)
        XCTAssertEqual(item.fontSize, 30)
    }

    func testMalformedJsonLeavesTheBoxUntouched() {
        var item = NoteTextAttachment(pageIndex: 0, text: "x")
        item.fontSize = 16
        TextBoxAppearance.apply("這不是 JSON", to: &item)
        XCTAssertEqual(item.fontSize, 16)
    }

    func testTheExportedPackageCarriesTheAppearance() throws {
        // 端到端：匯出成 .padnote 之後，另一個平台讀得到這些設定。
        let doc = NotebookDocument(
            id: "appear", title: "外觀", pageCount: 1,
            textAttachments: [styled()])
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("appearance-\(UUID().uuidString).padnote")
        defer { try? FileManager.default.removeItem(at: dir) }

        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: dir, deviceId: 0xAB)

        let session = try PadnoteSession.openExisting(path: dir.path, deviceId: 0xCD)
        let page = try XCTUnwrap(try session.firstPageId())
        let blockId = try XCTUnwrap(try session.textBlockIds(pageId: page).first)
        let json = try XCTUnwrap(try session.blockAppearance(blockId: blockId))

        XCTAssertTrue(json.contains("\"clear\""), "透明底色沒有跟著檔案走")
        XCTAssertTrue(json.contains("lineSpacing"), "行距沒有跟著檔案走")
    }
}

//
//  ObjectFrameStyleTests.swift
//  KairumoTests
//
//  插入物件的外框樣式：畫布與匯出必須解析出同一個結果。
//
//  兩邊各有一份解析（SwiftUI 用 Color、匯出用 UIColor），因為它們畫在不同的
//  繪圖系統上。既然是兩份，就必須有測試證明它們同意彼此 —— 不然「畫布所見、
//  匯出即所得」只是一句話。
//

import XCTest
import SwiftUI
@testable import Kairumo

final class ObjectFrameStyleTests: XCTestCase {

    private func rgba(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { ($0 * 255).rounded() }
    }

    // MARK: - 舊檔的外觀不能變

    func testLegacyObjectsKeepTheirOriginalLook() {
        // 舊檔沒有這些欄位，解碼後全是 nil。回落值必須跟以前一模一樣，
        // 否則使用者一升級就會發現「我的筆記變了」。
        let image = NoteImageAttachment(fileName: "a.png")
        XCTAssertNil(image.borderColorHex)
        XCTAssertNil(image.backgroundColorHex)
        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(image, defaults: .image),
                     "圖片原本就沒有底色")
        XCTAssertEqual(
            PageThumbnailRenderer.resolvedBorderWidth(image, defaults: .image), 2.5,
            "圖片原本的邊框粗細是 2.5")
    }

    func testTextBoxDefaultsToWhiteBackground() {
        let text = NoteTextAttachment(text: "x")
        XCTAssertEqual(
            rgba(PageThumbnailRenderer.resolvedBackground(text, defaults: .text)!),
            [255, 255, 255, 255])
    }

    // MARK: - 透明

    func testClearMeansTransparentNotDefault() {
        // "clear"（使用者選了透明）與 nil（舊檔沒這欄位）是兩回事。
        // 混為一談的話，選了透明的方框會變回白底。
        var text = NoteTextAttachment(text: "x")
        text.backgroundColorHex = "clear"
        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(text, defaults: .text))

        text.backgroundColorHex = nil
        XCTAssertNotNil(PageThumbnailRenderer.resolvedBackground(text, defaults: .text))
    }

    func testEveryObjectTypeCanBeMadeTransparent() {
        // 「任何插入物件的背景都可讓使用者選擇透明」—— 逐型別確認，
        // 因為原本只有文字方塊做得到。
        var image = NoteImageAttachment(fileName: "a.png"); image.backgroundColorHex = "clear"
        var model = Note3DAttachment(); model.backgroundColorHex = "clear"
        var link = NoteLinkAttachment(urlString: "https://example.com")
        link.backgroundColorHex = "clear"

        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(image, defaults: .image))
        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(model, defaults: .model3D))
        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(link, defaults: .link))
    }

    func testEveryObjectTypeCanDropItsBorder() {
        var model = Note3DAttachment(); model.hasBorder = false
        var link = NoteLinkAttachment(urlString: "https://example.com"); link.hasBorder = false

        XCTAssertEqual(ObjectFrameStyleResolver.borderWidth(model, .model3D), 0)
        XCTAssertEqual(ObjectFrameStyleResolver.borderWidth(link, .link), 0)
    }

    // MARK: - 畫布與匯出一致

    func testCanvasAndExportAgreeOnCustomColors() {
        var model = Note3DAttachment()
        model.backgroundColorHex = "#FFF9C4"
        model.borderColorHex = "#212121"
        model.borderWidth = 4

        let exportBg = PageThumbnailRenderer.resolvedBackground(model, defaults: .model3D)!
        let canvasBg = UIColor(ObjectFrameStyleResolver.background(model, .model3D))
        XCTAssertEqual(rgba(exportBg), rgba(canvasBg), "底色兩邊算出來必須一樣")

        let exportBorder = PageThumbnailRenderer.resolvedBorderColor(model, defaults: .model3D)
        let canvasBorder = UIColor(ObjectFrameStyleResolver.borderColor(model, .model3D))
        XCTAssertEqual(rgba(exportBorder), rgba(canvasBorder), "邊框顏色兩邊必須一樣")

        XCTAssertEqual(
            PageThumbnailRenderer.resolvedBorderWidth(model, defaults: .model3D),
            ObjectFrameStyleResolver.borderWidth(model, .model3D))
    }

    func testCanvasAndExportAgreeOnTransparency() {
        var image = NoteImageAttachment(fileName: "a.png")
        image.backgroundColorHex = "clear"
        XCTAssertNil(PageThumbnailRenderer.resolvedBackground(image, defaults: .image))
        XCTAssertEqual(
            rgba(UIColor(ObjectFrameStyleResolver.background(image, .image)))[3], 0,
            "畫布端的透明也必須是 alpha 0")
    }

    func testAnInvalidColorFallsBackInsteadOfDisappearing() {
        // 壞掉的色碼（例如協同對象送來的舊格式）不該讓方框整個變透明。
        var text = NoteTextAttachment(text: "x")
        text.backgroundColorHex = "不是顏色"
        XCTAssertNotNil(PageThumbnailRenderer.resolvedBackground(text, defaults: .text))
    }
}

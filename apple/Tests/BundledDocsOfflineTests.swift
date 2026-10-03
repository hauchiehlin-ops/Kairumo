import XCTest

@testable import Kairumo

/// 內建文件必須完全離線可讀：不得引用任何外部網址的資源（字型、樣式表、腳本、圖片）。
/// 外部樣式表會擋住第一次繪製 —— 離線或 VPN 下整頁空白（實機回報）。
final class BundledDocsOfflineTests: XCTestCase {

    func testBundledDocumentsReferenceNoExternalResources() throws {
        for doc in [BundledDocument.manual, .privacy] {
            let url = try XCTUnwrap(doc.url, "\(doc.rawValue) 沒有打包進 App")
            let html = try String(contentsOf: url, encoding: .utf8)
            let external = try NSRegularExpression(
                pattern: #"<(?:link|script|img|iframe)\b[^>]*\b(?:href|src)\s*=\s*["']https?://"#,
                options: [.caseInsensitive])
            let range = NSRange(html.startIndex..., in: html)
            XCTAssertNil(
                external.firstMatch(in: html, range: range),
                "\(doc.rawValue) 引用了外部資源 —— 離線時會擋住繪製，而且違反隱私承諾")
            XCTAssertFalse(html.contains("fonts.googleapis.com"), "\(doc.rawValue) 仍然連到 Google Fonts")
        }
    }
}

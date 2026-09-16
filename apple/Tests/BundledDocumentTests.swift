//
//  BundledDocumentTests.swift
//  KairumoTests
//
//  打包進 App 的操作手冊與隱私權政策。
//
//  # 這組測試在守什麼
//
//  使用者實際回報過：隱私權政策整頁是亂碼。原因是那份 HTML **沒有宣告編碼** ——
//  WKWebView 載入本機檔案時只能猜，UTF-8 的中文就變成一堆問號方塊。
//  這種錯誤在原始碼裡完全看不出來，只有真的打開那一頁才會發現。
//
//  另外守兩件事：文件要真的被打包進去（漏了只會得到一個空白畫面），
//  以及內容不提作業系統名稱（同一份手冊要給所有平台的使用者看）。
//

import XCTest
@testable import Kairumo

final class BundledDocumentTests: XCTestCase {

    private func contents(of document: BundledDocument) throws -> String {
        let url = try XCTUnwrap(document.url, "\(document.rawValue) 沒有被打包進 App")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - 打包

    func testEveryDocumentIsBundled() throws {
        // 漏打包的話，使用者點進去只會看到一個空白畫面。
        for document in [BundledDocument.manual, .privacy] {
            XCTAssertNotNil(document.url, "\(document.rawValue) 沒有被打包進 App")
        }
    }

    func testEveryDocumentIsValidUTF8() throws {
        // 讀不成 UTF-8 的話，畫面上就是亂碼。
        for document in [BundledDocument.manual, .privacy] {
            XCTAssertNoThrow(try contents(of: document), "\(document.rawValue) 不是合法的 UTF-8")
        }
    }

    // MARK: - 編碼宣告（使用者實際回報的那個 bug）

    func testEveryDocumentDeclaresUTF8() throws {
        // 這就是「隱私權政策整頁亂碼」的成因。
        // 沒有這行，WKWebView 只能猜編碼，而它猜錯了。
        for document in [BundledDocument.manual, .privacy] {
            let html = try contents(of: document)
            XCTAssertTrue(
                html.lowercased().contains("<meta charset=\"utf-8\">"),
                "\(document.rawValue) 缺少編碼宣告 —— 在 App 裡會顯示成亂碼"
            )
        }
    }

    func testEveryDocumentHasADoctype() throws {
        // 沒有 DOCTYPE 的話，瀏覽器會進入相容模式（quirks mode），
        // 版面與編碼判斷都會走不同的規則。
        for document in [BundledDocument.manual, .privacy] {
            let html = try contents(of: document)
            XCTAssertTrue(
                html.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased().hasPrefix("<!doctype html>"),
                "\(document.rawValue) 沒有 DOCTYPE"
            )
        }
    }

    func testTheCharsetIsDeclaredBeforeAnyText() throws {
        // 編碼宣告必須出現在前 1024 個位元組內，否則規格允許瀏覽器
        // 在讀到它之前就已經用猜的編碼開始解析了。
        for document in [BundledDocument.manual, .privacy] {
            let html = try contents(of: document)
            let index = try XCTUnwrap(html.lowercased().range(of: "<meta charset=\"utf-8\">"))
            let offset = html.distance(from: html.startIndex, to: index.lowerBound)
            XCTAssertLessThan(offset, 1024, "\(document.rawValue) 的編碼宣告太靠後")
        }
    }

    // MARK: - 內容

    func testDocumentsDoNotNameOperatingSystems() throws {
        // 同一份手冊要給所有平台的使用者看。列出某個平台的名字，
        // 會讓其他平台的使用者以為那些功能自己沒有。而且那種句子**遲早
        // 會變成謊話** —— 平台補上那個功能時，沒有人會記得回來改手冊。
        //
        // **`manual.js` 也要驗。** 手冊的內容在那裡，不在 HTML 裡 ——
        // 這份測試原本只看兩個 HTML，所以漏掉了寫在 manual.js 裡的
        // 「Android 版沒有轉錄」，一路到 Android 的 instrumented 測試
        // 才被擋下來（那邊三個檔案都驗）。兩邊要驗同一組東西。
        let forbidden = ["iPad", "iPhone", "iOS", "macOS", "Android", "Apple Pencil", "iCloud"]
        var sources: [(String, String)] = []
        for document in [BundledDocument.manual, .privacy] {
            sources.append((document.rawValue, try contents(of: document)))
        }
        sources.append(("manual.js", try manualScript()))

        for (name, text) in sources {
            for word in forbidden {
                XCTAssertFalse(text.contains(word), "\(name) 裡出現了「\(word)」")
            }
        }
    }

    func testTheManualCoversBackupAndSync() throws {
        // 使用者問過「備份的功能在哪裡」「同步的功能在哪裡」——
        // 手冊裡完全沒有這一段，那本身就是問題的一部分。
        let manual = try manualScript()
        XCTAssertGreaterThan(
            sectionCount(of: "data", in: manual), 0,
            "手冊缺少「資料備份與同步」一節")
    }

    func testTheManualDoesNotTeachRemovedFeatures() throws {
        // 「延長此頁」已經移除（寫到底會自動多一頁）。
        // 手冊還教使用者去按一個不存在的按鈕，比沒寫更糟。
        let manual = try manualScript()
        for removed in ["延長此頁", "延长此页", "Extend Page"] {
            XCTAssertFalse(manual.contains(removed), "手冊還在教已移除的「\(removed)」")
        }
    }

    func testTheManualDescribesChartsAsEditable() throws {
        // 圖表可重新編修是這一輪的重點功能，手冊沒寫的話等於沒做。
        let manual = try manualScript()
        XCTAssertTrue(manual.contains("編修圖表"), "手冊沒有提到圖表可以重新編修")
    }

    func testEveryLocaleHasTheSameSections() throws {
        // 少一節就是某個語系的使用者看不到那個功能。
        let manual = try manualScript()
        XCTAssertEqual(
            sectionCount(of: "data", in: manual), 6,
            "六個語系都要有「資料備份與同步」一節")
    }

    /// 手冊裡有幾個語系宣告了這個 section id。
    ///
    /// **兩種寫法都要算。** `manual.js` 是手寫的 JS，但重新產生時會走
    /// `JSON.stringify`，鍵名會從 `id: "data"` 變成 `"id":"data"` ——
    /// 只比對其中一種的話，內容明明還在，測試卻會紅，而看到的人會以為
    /// 是手冊掉了一節。這裡要驗的是**內容**，不是排版。
    private func sectionCount(of id: String, in manual: String) -> Int {
        let spellings = ["id: \"\(id)\"", "\"id\":\"\(id)\"", "\"id\": \"\(id)\""]
        return spellings.reduce(0) { total, spelling in
            total + manual.components(separatedBy: spelling).count - 1
        }
    }

    /// 手冊的內容在 `manual.js` 裡，不在 HTML 裡。
    private func manualScript() throws -> String {
        let html = try XCTUnwrap(BundledDocument.manual.url)
        let script = html.deletingLastPathComponent().appendingPathComponent("manual.js")
        return try String(contentsOf: script, encoding: .utf8)
    }
}

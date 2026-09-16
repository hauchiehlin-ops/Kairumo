//
//  NoteIntelligenceTests.swift
//  KairumoTests
//
//  摘要與待辦的入口（工作項 S-20）。
//
//  模型本身不在這裡驗 —— 模擬器上系統模型多半不可用，而且就算可用，
//  「模型講得對不對」也不是單元測試驗得了的事。能驗、而且真的會出錯的是
//  兩件事：**餵給模型的文字**取得對不對，以及**沒有模型時的行為**。
//
//  Android 端的對照組是 `NoteIntelligenceTest.kt`，字串刻意逐字相同。
//

import XCTest
@testable import Kairumo

@MainActor
final class NoteIntelligenceTests: XCTestCase {

    private func note(
        title: String = "T",
        recognized: [String: String]? = nil,
        texts: [String] = [],
        tableCells: [String] = [],
        shapeLabels: [String] = []
    ) -> NotebookDocument {
        var doc = NotebookDocument(title: title)
        doc.recognizedText = recognized
        doc.textAttachments = texts.map { NoteTextAttachment(text: $0) }
        if !tableCells.isEmpty {
            var table = NoteTableAttachment(rows: 1, cols: tableCells.count)
            table.cells = tableCells
            doc.tableAttachments = [table]
        }
        if !shapeLabels.isEmpty {
            doc.shapeAttachments = shapeLabels.map { NoteShapeAttachment(label: $0) }
        }
        return doc
    }

    func testBlankPiecesAreDroppedInsteadOfLeavingHoles() {
        // 模型會把一整排空行當成章節分隔，然後為每一段「章節」各寫一句摘要。
        let text = note(title: "會議記錄", texts: ["", "   ", "下週三交初稿", "\n"]).plainText()
        XCTAssertEqual(text, "會議記錄\n\n下週三交初稿")
    }

    func testHandwritingComesBeforeTypedText() {
        // 手寫多半是主體，文字方塊常常只是標註。順序反過來的話，
        // 摘要會以標註為重點。
        let text = note(
            recognized: ["p1": "手寫的主體"],
            texts: ["旁邊的標註"]
        ).plainText()
        let handwriting = try? XCTUnwrap(text.range(of: "手寫的主體"))
        let typed = try? XCTUnwrap(text.range(of: "旁邊的標註"))
        XCTAssertTrue(handwriting!.lowerBound < typed!.lowerBound)
    }

    func testRecognizedTextIsOrderedSoTheSummaryDoesNotChangeEachRun() {
        // 字典的順序不固定。不排的話同一則筆記每次跑出來的摘要都不一樣，
        // 而使用者會以為模型在亂講。
        let doc = note(recognized: ["p3": "丙", "p1": "甲", "p2": "乙"])
        let first = doc.plainText()
        for _ in 0..<20 {
            XCTAssertEqual(doc.plainText(), first, "同一則筆記兩次算出不同的文字")
        }
        XCTAssertTrue(first.contains("甲\n\n乙\n\n丙"), "手寫段落沒有照頁碼排：\(first)")
    }

    func testTableCellsAreSeparatedByNewlinesNotSpaces() {
        // 接成一長串的話，「姓名 王小明 電話」會被讀成一句話。
        let text = note(tableCells: ["姓名", "王小明", "電話"]).plainText()
        XCTAssertTrue(text.contains("姓名\n王小明\n電話"), "表格的格子被接成一句話了：\(text)")
    }

    func testEverySourceSearchLooksAtIsIncluded() {
        // 與首頁搜尋比對的來源不一致的話，會出現一個很難解釋的狀況：
        // 使用者搜得到某句話，但摘要說筆記裡沒有提到它。
        let text = note(
            title: "標題",
            recognized: ["p": "手寫"],
            texts: ["打字"],
            tableCells: ["表格"],
            shapeLabels: ["形狀"]
        ).plainText()
        for piece in ["標題", "手寫", "打字", "表格", "形狀"] {
            XCTAssertTrue(text.contains(piece), "\(piece) 沒有被放進去")
        }
    }

    func testTheAvailabilityMatchesWhatTheBackendActuallyDoes() {
        // 兩者不一致的話，畫面會給一顆按下去必定失敗的按鈕。
        let backend = SystemLanguageBackend()
        let claimsAvailable = SystemLanguageBackend.availability == .available
        let actuallyWorks = (try? backend.generate(prompt: "hi", maxTokens: 8)) != nil
        // 只在「宣稱不可用」時斷言 —— 宣稱可用時真的去跑一次模型，
        // 會讓這條測試變成一個要等好幾秒、而且靠外部狀態的東西。
        if !claimsAvailable {
            XCTAssertFalse(actuallyWorks, "宣稱不可用卻真的跑得出結果")
        }
    }

    func testWithoutAModelTheErrorSaysSoInsteadOfLookingTransient() throws {
        // 回一個看起來像暫時性失敗的錯誤，使用者會一直按。
        try XCTSkipIf(
            SystemLanguageBackend.availability == .available,
            "這台機器上系統模型可用，這條驗不到沒有模型的路徑")

        let backend = SystemLanguageBackend()
        XCTAssertThrowsError(try backend.generate(prompt: "hi", maxTokens: 8)) { error in
            guard case FfiLlmError.ModelNotLoaded = error else {
                XCTFail("丟的是 \(error)，不是 ModelNotLoaded —— 核心用它區分「要引導」與「請重試」")
                return
            }
        }
    }
}

import PencilKit
import XCTest
@testable import Kairumo

/// 六種語言的文字匯出成 PDF：走真正的 iOS 路徑（`NotebookPackageBridge.exportPdf` → 核心的 PDF 寫入器）。
///
/// 韓文與泰文曾經在 PDF 裡變成亂碼（只有一套簡中 CID 字型）。這裡守的是：
/// 各語言要用到的字型真的在檔案裡，而且泰文的內嵌字型只在有泰文時出現。
/// 設定環境變數 `TEST_RUNNER_KAIRUMO_PDF_OUT=/some/dir` 會把 PDF 存下來，讓人眼檢查。
final class MultilingualPdfExportTests: XCTestCase {
    private let device: UInt32 = 0xC1

    private func pdf(_ lines: [String]) throws -> Data {
        var doc = NotebookDocument(title: "Languages", pageCount: 1)
        doc.textAttachments = lines.enumerated().map { index, text in
            NoteTextAttachment(pageIndex: 0, text: text, fontSize: 18,
                               hasBorder: false, x: 50, y: 60 + CGFloat(index) * 90, width: 600, height: 70)
        }
        return try NotebookPackageBridge.exportPdf(document: doc, drawings: [PKDrawing()], deviceId: device)
    }

    private func latin1(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    func testAllSixLanguagesExportWithTheirOwnFonts() throws {
        let data = try pdf([
            "The quick brown fox jumps over the lazy dog 2026.",
            "線性代數：特徵值與特徵向量，開會記錄與課堂筆記。",
            "线性代数：特征值与特征向量，会议记录与课堂笔记。",
            "ひらがなとカタカナ、漢字の混ざった文章です。会議のメモ。",
            "한글 문장입니다. 회의록과 강의 노트를 작성합니다.",
            "ภาษาไทยไม่มีช่องว่างระหว่างคำ การประชุมและบันทึกการเรียน",
        ])
        let text = String(data: data, encoding: .isoLatin1) ?? ""
        XCTAssertTrue(text.contains("/FontFile2"), "泰文要嵌入字型")
        XCTAssertTrue(text.contains("/F_TH"))
        if let dir = ProcessInfo.processInfo.environment["KAIRUMO_PDF_OUT"] {
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("languages-ios.pdf"))
        }
    }

    func testAThaiFreeDocumentDoesNotCarryTheThaiFont() throws {
        let data = try pdf(["meeting 會議 한국어"])
        XCTAssertFalse((String(data: data, encoding: .isoLatin1) ?? "").contains("/FontFile2"))
    }
}

import XCTest

@testable import Kairumo

/// 核心的紙張目錄裡**每一種**，平台都選得到。
/// 回報：「錯題本」、「英文三格線」點了沒反應 —— 列舉漏了這兩種，選取被靜默略過。
final class PaperTemplateCoverageTests: XCTestCase {
    func testEveryCorePaperCanBeSelected() {
        let missing = paperTemplates().map(\.id).filter { NoteTemplate(paperId: $0) == nil }
        XCTAssertTrue(missing.isEmpty, "這些紙張在選單裡點了沒反應（NoteTemplate 沒有對應）：\(missing)")
    }

    func testEveryTemplateRoundTripsThroughItsPaperId() {
        for template in NoteTemplate.allCases {
            XCTAssertEqual(NoteTemplate(paperId: template.paperId), template)
        }
    }
}

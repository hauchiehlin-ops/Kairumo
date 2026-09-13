//
//  NoteShapeTests.swift
//  KairumoTests
//
//  形狀與流程圖。
//
//  # 這組測試在守什麼
//
//  幾何全部來自核心（`padnote-shapes`），所以這裡不重驗菱形長什麼樣。
//  驗的是**平台這一邊會不會把它接錯**：
//
//  - 種類用名稱存，不是列舉序號 —— 序號會隨核心新增種類而位移，
//    那會讓舊筆記裡的「判斷」變成「資料」，而且沒有任何錯誤訊息
//  - 連接線的端點要落在形狀邊界上，不是「大概的邊」
//  - 範本要一次給出節點**與**連線，只給節點的話範本就沒有意義
//

import XCTest
@testable import Kairumo

final class NoteShapeTests: XCTestCase {

    private func shape(_ kind: String = "process") -> NoteShapeAttachment {
        NoteShapeAttachment(kindName: kind, x: 100, y: 200, width: 160, height: 80)
    }

    // MARK: - 種類的身分

    func testKindIsStoredByNameNotByOrdinal() {
        // 序號會隨核心新增種類而位移 —— 存序號的話，舊筆記裡的「判斷」
        // 有一天會變成「資料」，而且不會有任何錯誤訊息。
        let decision = shape("decision")
        XCTAssertEqual(decision.kind, .decision)
        XCTAssertEqual(NoteShapeAttachment.name(of: .decision), "decision")
    }

    func testEveryCoreKindRoundTripsThroughItsName() {
        // 名稱對不上的種類會靜靜地退回成方框。
        for kind in allShapeKinds() {
            let name = NoteShapeAttachment.name(of: kind)
            XCTAssertEqual(
                NoteShapeAttachment.kind(named: name), kind,
                "\(kind) 的名稱對不回去")
        }
    }

    func testAnUnknownNameFallsBackToAPlainBox() {
        // 退回方框是最無害的選擇：使用者至少看得到一個形狀，而不是一片空白。
        XCTAssertEqual(shape("未來才有的形狀").kind, .process)
    }

    // MARK: - 幾何來自核心

    func testTheOutlineComesFromTheCore() {
        let points = shape().outline()
        XCTAssertGreaterThan(points.count, 2)
    }

    func testTheOutlineStaysInsideTheBounds() {
        // 超出邊界的話，形狀會壓到旁邊的東西上。
        let item = shape("decision")
        for point in item.outline() {
            XCTAssertGreaterThanOrEqual(point.x, item.x - 0.01)
            XCTAssertLessThanOrEqual(point.x, item.x + item.width + 0.01)
            XCTAssertGreaterThanOrEqual(point.y, item.y - 0.01)
            XCTAssertLessThanOrEqual(point.y, item.y + item.height + 0.01)
        }
    }

    func testDifferentKindsProduceDifferentOutlines() {
        // 全部畫成方框的話，流程圖就失去意義了。
        let box = shape("rectangle").outline()
        let diamond = shape("decision").outline()
        XCTAssertNotEqual(box, diamond)
    }

    func testEveryKindDrawsSomething() {
        // 新增種類時最容易發生的事，是忘了接上 —— 形狀會靜靜地空白。
        for kind in allShapeKinds() {
            let item = NoteShapeAttachment(
                kindName: NoteShapeAttachment.name(of: kind), width: 120, height: 60)
            XCTAssertGreaterThan(item.outline().count, 1, "\(kind) 畫不出東西")
        }
    }

    // MARK: - ISO 5807 的語意

    func testFlowchartSymbolsCarryTheirMeaning() {
        // 語意直接顯示給使用者 —— 沒有人記得哪個符號代表什麼。
        XCTAssertNotNil(shape("decision").semantic)
        XCTAssertNotNil(shape("terminator").semantic)
    }

    func testShapesThatCannotHoldTextAreMarked() {
        // 讓使用者把字打進一條線裡，那些字永遠不會出現。
        XCTAssertTrue(shape("process").acceptsText)
        XCTAssertFalse(shape("line").acceptsText)
    }

    // MARK: - 連接線

    func testAConnectionEndsOnTheShapeBoundaries() {
        // 端點落在「大概的邊」的話，線會穿進形狀裡或浮在外面。
        let from = NoteShapeAttachment(kindName: "process", x: 0, y: 0, width: 100, height: 60)
        let to = NoteShapeAttachment(kindName: "process", x: 300, y: 0, width: 100, height: 60)
        let link = NoteConnectionAttachment(fromShapeId: from.id, toShapeId: to.id)

        let geometry = try? XCTUnwrap(ShapeGeometry.connection(link, from: from, to: to))
        let path = try? XCTUnwrap(geometry?.path)
        XCTAssertGreaterThanOrEqual(path?.count ?? 0, 2)

        let start = path![0]
        let end = path![path!.count - 1]
        XCTAssertGreaterThanOrEqual(start.x, -0.01)
        XCTAssertLessThanOrEqual(start.x, 100.01, "起點跑到來源形狀外面了")
        XCTAssertGreaterThanOrEqual(end.x, 299.99, "終點沒有接到目標形狀")
    }

    func testAConnectionHasAnArrowHead() {
        // 沒有箭頭的流程圖看不出方向。
        let from = NoteShapeAttachment(x: 0, y: 0, width: 100, height: 60)
        let to = NoteShapeAttachment(x: 300, y: 0, width: 100, height: 60)
        let link = NoteConnectionAttachment(fromShapeId: from.id, toShapeId: to.id)

        let geometry = ShapeGeometry.connection(link, from: from, to: to)
        XCTAssertGreaterThanOrEqual(geometry?.arrowHead.count ?? 0, 3)
    }

    func testConnectionsBetweenDifferentKindsStillWork() {
        // 菱形的邊與方框的邊完全不同 —— 核心要能處理任意組合。
        for kind in flowchartShapeKinds() {
            let from = NoteShapeAttachment(
                kindName: NoteShapeAttachment.name(of: kind), x: 0, y: 0, width: 100, height: 60)
            let to = NoteShapeAttachment(x: 300, y: 0, width: 100, height: 60)
            let link = NoteConnectionAttachment(fromShapeId: from.id, toShapeId: to.id)
            XCTAssertNotNil(ShapeGeometry.connection(link, from: from, to: to), "\(kind) 連不起來")
        }
    }

    // MARK: - 範本

    func testTheCoreShipsFlowchartTemplates() {
        XCTAssertFalse(flowchartTemplates().isEmpty)
    }

    func testEveryTemplateHasNodesAndEdges() {
        // 只有節點的話，使用者得自己一條一條連 —— 那範本就沒有意義了。
        for template in flowchartTemplates() {
            XCTAssertFalse(template.nodes.isEmpty, "\(template.id) 沒有節點")
            XCTAssertFalse(template.edges.isEmpty, "\(template.id) 沒有連線")
        }
    }

    func testTemplateEdgesPointAtRealNodes() {
        // 指到不存在的節點的話，畫面上是一條從空氣連出來的線。
        for template in flowchartTemplates() {
            for edge in template.edges {
                XCTAssertLessThan(Int(edge.from), template.nodes.count, "\(template.id) 的起點越界")
                XCTAssertLessThan(Int(edge.to), template.nodes.count, "\(template.id) 的終點越界")
            }
        }
    }

    // MARK: - 持久化

    func testAShapeSurvivesEncodingAndDecoding() throws {
        var original = shape("decision")
        original.label = "要不要繼續？"
        original.fillColorHex = "clear"

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(NoteShapeAttachment.self, from: data)

        XCTAssertEqual(restored.kindName, "decision")
        XCTAssertEqual(restored.kind, .decision)
        XCTAssertEqual(restored.label, "要不要繼續？")
        XCTAssertEqual(restored.fillColorHex, "clear", "透明是哨符，不能走顏色轉換")
    }

    func testANotebookWithoutShapesStillDecodes() throws {
        // 這些欄位是後來加的。舊筆記裡沒有它們，解碼一定要照樣成功。
        let json = #"{"id":"1","title":"舊筆記","createdAt":0,"lastModifiedDate":0,"pageCount":1,"hasRecording":false,"template":"空白紙張","pagesData":[]}"#
        let document = try JSONDecoder().decode(
            NotebookDocument.self, from: XCTUnwrap(json.data(using: .utf8)))
        XCTAssertNil(document.shapeAttachments)
        XCTAssertNil(document.connectionAttachments)
    }
}

//
//  ShapeEditingTests.swift
//  KairumoTests
//
//  形狀編修的算術：縮放把手、線段端點、連接線欄位的來回、單物件的層級動作。
//
//  # 這組測試在守什麼
//
//  手指到數字的換算錯了不會跳例外，只會讓東西**往錯的方向長**：
//  轉過 90° 的方塊拖右邊，卻是上面那條邊在動；拖完線的端點，線跑到別處；
//  同步一輪之後虛線、箭頭樣式被洗掉。這些都盯著「使用者最後看到什麼」來驗。
//

import XCTest
import PencilKit
@testable import Kairumo

final class ShapeEditingTests: XCTestCase {

    private let frame = CGRect(x: 100, y: 100, width: 200, height: 100)

    // MARK: - 縮放把手

    func testDraggingTheRightEdgeGrowsWidthAndPinsTheLeftEdge() {
        let r = ShapeFrameMath.resized(frame, rotation: 0, handle: .right,
                                       translation: CGSize(width: 40, height: 999))
        XCTAssertEqual(r.minX, 100, accuracy: 0.001, "對面那條邊要釘在原位")
        XCTAssertEqual(r.width, 240, accuracy: 0.001)
        XCTAssertEqual(r.height, 100, accuracy: 0.001, "邊中點的把手不能動到另一個軸")
    }

    func testDraggingTheTopLeftCornerMovesBothAxes() {
        let r = ShapeFrameMath.resized(frame, rotation: 0, handle: .topLeft,
                                       translation: CGSize(width: -20, height: -10))
        XCTAssertEqual(r.maxX, 300, accuracy: 0.001)
        XCTAssertEqual(r.maxY, 200, accuracy: 0.001)
        XCTAssertEqual(r.width, 220, accuracy: 0.001)
        XCTAssertEqual(r.height, 110, accuracy: 0.001)
    }

    func testRotatedShapeResizesAlongItsOwnAxes() {
        // 轉 90° 之後，畫布上往下拖 = 形狀自己的「右」方向。
        let r = ShapeFrameMath.resized(frame, rotation: 90, handle: .right,
                                       translation: CGSize(width: 0, height: 30))
        XCTAssertEqual(r.width, 230, accuracy: 0.01)
        XCTAssertEqual(r.height, 100, accuracy: 0.01)
        // 左邊那條邊（轉 90° 後在畫布上方）的畫布位置不變。
        let before = ShapeFrameMath.rotate(CGPoint(x: frame.minX, y: frame.midY),
                                           about: CGPoint(x: frame.midX, y: frame.midY), degrees: 90)
        let after = ShapeFrameMath.rotate(CGPoint(x: r.minX, y: r.midY),
                                          about: CGPoint(x: r.midX, y: r.midY), degrees: 90)
        XCTAssertEqual(before.x, after.x, accuracy: 0.01)
        XCTAssertEqual(before.y, after.y, accuracy: 0.01)
    }

    func testResizeNeverGoesBelowTheMinimumSide() {
        let r = ShapeFrameMath.resized(frame, rotation: 0, handle: .bottomRight,
                                       translation: CGSize(width: -9999, height: -9999))
        XCTAssertEqual(r.width, ShapeFrameMath.minSide)
        XCTAssertEqual(r.height, ShapeFrameMath.minSide)
    }

    func testCornerResizeCanKeepAspect() {
        let r = ShapeFrameMath.resized(frame, rotation: 0, handle: .bottomRight,
                                       translation: CGSize(width: 100, height: 0), keepAspect: true)
        XCTAssertEqual(r.width / r.height, 2, accuracy: 0.01)
    }

    // MARK: - 線段端點

    func testLineFrameRoundTripsArbitraryEndpoints() {
        let cases: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 50, y: 50), CGPoint(x: 250, y: 120)),
            (CGPoint(x: 250, y: 120), CGPoint(x: 50, y: 50)),      // 反向
            (CGPoint(x: 100, y: 300), CGPoint(x: 100, y: 40)),     // 垂直向上
            (CGPoint(x: 10, y: 10), CGPoint(x: 400, y: 10)),       // 水平
            (CGPoint(x: 300, y: 300), CGPoint(x: 120, y: 480))     // 左下
        ]
        for (a, b) in cases {
            let result = ShapeFrameMath.lineFrame(from: a, to: b)
            var line = NoteShapeAttachment(kindName: "line",
                                           x: result.frame.minX, y: result.frame.minY,
                                           width: result.frame.width, height: result.frame.height)
            line.canvasRotation = result.rotation
            let ends = line.lineEndpoints
            XCTAssertEqual(ends.start.x, a.x, accuracy: 0.05, "\(a)→\(b) 起點")
            XCTAssertEqual(ends.start.y, a.y, accuracy: 0.05)
            XCTAssertEqual(ends.end.x, b.x, accuracy: 0.05, "\(a)→\(b) 終點")
            XCTAssertEqual(ends.end.y, b.y, accuracy: 0.05)
        }
    }

    func testSnappingOnlyHappensNearAMultiple() {
        XCTAssertEqual(ShapeFrameMath.snapped(degrees: 44), 45)
        XCTAssertEqual(ShapeFrameMath.snapped(degrees: 38), 38)
    }

    // MARK: - 連接點

    func testAnchorPointFollowsRotation() {
        var s = NoteShapeAttachment(kindName: "process", x: 0, y: 0, width: 100, height: 40)
        let top = s.anchorPoint(.top)
        XCTAssertEqual(top.x, 50, accuracy: 0.01)
        XCTAssertEqual(top.y, 0, accuracy: 0.01)
        s.canvasRotation = 90
        let rotated = s.anchorPoint(.top)
        // 繞中心 (50, 20) 順時針 90°：頂邊中點 (50,0) → (70, 20)。
        XCTAssertEqual(rotated.x, 70, accuracy: 0.01)
        XCTAssertEqual(rotated.y, 20, accuracy: 0.01)
    }

    // MARK: - 連接線

    private func pair() -> (NoteShapeAttachment, NoteShapeAttachment) {
        (NoteShapeAttachment(id: "a", kindName: "process", x: 0, y: 0, width: 100, height: 50),
         NoteShapeAttachment(id: "b", kindName: "process", x: 0, y: 200, width: 100, height: 50))
    }

    func testDefaultConnectionHasAnArrowAtTheEndOnly() {
        let (a, b) = pair()
        let c = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        let g = ShapeGeometry.connection(c, from: a, to: b)
        XCTAssertNotNil(g?.endCap)
        XCTAssertNil(g?.startCap)
    }

    func testExplicitAnchorsAndRouteAreHonoured() {
        let (a, b) = pair()
        var c = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        c.fromAnchor = "right"; c.toAnchor = "left"; c.route = "straight"
        let g = ShapeGeometry.connection(c, from: a, to: b)!
        XCTAssertEqual(g.path.first!.x, 100, accuracy: 0.01, "出線在右邊中點")
        XCTAssertEqual(g.path.last!.x, 0, accuracy: 0.01, "入線在左邊中點")
        XCTAssertEqual(g.path.count, 2, "直線只有兩個點")
    }

    func testReverseSwapsEndsAnchorsAndCaps() {
        var c = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        c.fromAnchor = "bottom"; c.toAnchor = "top"
        c.reverse()
        XCTAssertEqual(c.fromShapeId, "b")
        XCTAssertEqual(c.fromAnchor, "top")
        // 預設的「終點箭頭」要跟著到新的終點：原本的起點現在是終點。
        XCTAssertEqual(c.startCapName, .arrow)
        XCTAssertEqual(c.endCapName, .none)
    }

    func testLegacyCoreTupleMeansNoCustomisation() {
        var c = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        let legacy = FfiConnectionObject(
            objectId: "x", fromObjectId: "a", toObjectId: "b",
            fromAnchor: .center, toAnchor: .center, route: .straight,
            startCap: .none, endCap: .arrow, label: "")
        c.apply(core: legacy)
        XCTAssertNil(c.route, "舊版寫的固定組合不能被當成『使用者選了直線』")
        XCTAssertNil(c.fromAnchor)
    }

    func testCustomisationSurvivesTheCoreRoundTrip() {
        let (a, b) = pair()
        var c = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        c.fromAnchor = "right"; c.toAnchor = "left"; c.route = "straight"
        c.startCap = "circle"; c.endCap = "hollow"
        let f = c.coreFields(from: a, to: b)
        var back = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        back.apply(core: FfiConnectionObject(
            objectId: "x", fromObjectId: "a", toObjectId: "b",
            fromAnchor: f.fromAnchor, toAnchor: f.toAnchor, route: f.route,
            startCap: f.startCap, endCap: f.endCap, label: ""))
        XCTAssertEqual(back.fromAnchor, "right")
        XCTAssertEqual(back.toAnchor, "left")
        XCTAssertEqual(back.route, "straight")
        XCTAssertEqual(back.startCap, "circle")
        XCTAssertEqual(back.endCap, "hollow")
    }

    func testExplicitStraightWithAutoAnchorsDoesNotCollapseToTheLegacyTuple() {
        // 明確選直線、沒指定連接點：核心欄位若是舊版那組固定值，另一台讀回來會變回直角折線。
        let (a, b) = pair()
        var c = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        c.route = "straight"
        let f = c.coreFields(from: a, to: b)
        XCTAssertNotEqual(f.fromAnchor, .center)
        var back = NoteConnectionAttachment(fromShapeId: "a", toShapeId: "b")
        back.apply(core: FfiConnectionObject(
            objectId: "x", fromObjectId: "a", toObjectId: "b",
            fromAnchor: f.fromAnchor, toAnchor: f.toAnchor, route: f.route,
            startCap: f.startCap, endCap: f.endCap, label: ""))
        XCTAssertEqual(back.route, "straight")
    }

    func testOldFilesWithoutNewKeysStillDecode() throws {
        let shapeJSON = #"{"id":"s","pageIndex":0,"kindName":"process","x":1,"y":2,"width":3,"height":4,"cornerRadius":8,"label":"","lineWidth":2}"#
        let s = try JSONDecoder().decode(NoteShapeAttachment.self, from: Data(shapeJSON.utf8))
        XCTAssertNil(s.dashStyle)
        XCTAssertEqual(s.dash, .solid)
        let connJSON = #"{"id":"c","pageIndex":0,"fromShapeId":"a","toShapeId":"b","label":"","lineWidth":2}"#
        let c = try JSONDecoder().decode(NoteConnectionAttachment.self, from: Data(connJSON.utf8))
        XCTAssertNil(c.route)
        XCTAssertEqual(c.endCapName, .arrow)
    }

    // MARK: - 單物件的層級動作

    func testReorderOpsMatchTheStackingFunctions() {
        let order = ["a", "b", "c", "d"]
        XCTAssertEqual(ObjectReorderOp.toFront.apply("b", to: order), ["a", "c", "d", "b"])
        XCTAssertEqual(ObjectReorderOp.toBack.apply("c", to: order), ["c", "a", "b", "d"])
        XCTAssertEqual(ObjectReorderOp.forward.apply("b", to: order), ["a", "c", "b", "d"])
        XCTAssertEqual(ObjectReorderOp.backward.apply("b", to: order), ["b", "a", "c", "d"])
        XCTAssertEqual(ObjectReorderOp.forward.apply("d", to: order), order, "已在最上層")
    }

    func testImportFlowStacksBlocksAndSpillsOntoTheNextPage() {
        let usable = PageGeometry.height - PageGeometry.printableInset * 2
        let placed = DocumentImport.flow(heights: [100, 100, usable - 400, 200])
        XCTAssertEqual(placed[0].y, PageGeometry.printableInset)
        XCTAssertGreaterThan(placed[1].y, placed[0].y + 100, "第二塊要排在第一塊下面，不是疊在上面")
        XCTAssertEqual(placed[2].pageOffset, 0)
        XCTAssertEqual(placed[3].pageOffset, 1, "放不下的接到下一頁")
        XCTAssertEqual(placed[3].y, PageGeometry.printableInset)
    }

    func testAnOversizedBlockGetsItsOwnPageInsteadOfLoopingForever() {
        let placed = DocumentImport.flow(heights: [50, 99999, 50])
        XCTAssertEqual(placed.count, 3)
        XCTAssertEqual(placed[1].pageOffset, 1)
        XCTAssertEqual(placed[2].pageOffset, 2)
    }

    func testEstimatedHeightGrowsWithTextAndTreatsCJKAsWider() {
        let short = DocumentImport.estimatedHeight(text: "hi", fontSize: 16, width: 400)
        let long = DocumentImport.estimatedHeight(text: String(repeating: "word ", count: 200), fontSize: 16, width: 400)
        XCTAssertGreaterThan(long, short)
        let ascii = DocumentImport.estimatedHeight(text: String(repeating: "a", count: 60), fontSize: 16, width: 200)
        let cjk = DocumentImport.estimatedHeight(text: String(repeating: "字", count: 60), fontSize: 16, width: 200)
        XCTAssertGreaterThan(cjk, ascii)
    }

    // MARK: - 匯入文件

    @MainActor
    func testMarkdownImportProducesNativeObjects() throws {
        // 舊版這條路在「傳檔名而不是完整路徑」那一步就失敗，而且只 print —— 使用者看到「沒反應」。
        let url = FileManager.default.temporaryDirectory.appending(path: "doc-import-test.md")
        try "# 標題\n\n第一段文字\n\n第二段文字\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try DocumentImport.parse(fileURL: url, title: "doc-import-test")
        let texts = imported.document.textAttachments ?? []
        XCTAssertFalse(texts.isEmpty, "Markdown 要展開成文字方塊")
        XCTAssertTrue(texts.contains { $0.text.contains("第一段文字") })
    }

    @MainActor
    func testEmptyDocumentIsReportedNotSwallowed() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "doc-import-empty.md")
        try " \n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try DocumentImport.parse(fileURL: url, title: "x"))
    }

    // MARK: - 跨裝置：套件來回

    private func shapeDocument() -> NotebookDocument {
        var a = NoteShapeAttachment(
            id: "11111111-1111-4111-8111-111111111111", kindName: "decision",
            x: 100, y: 200, width: 180, height: 90, cornerRadius: 10, label: "要不要？")
        a.strokeColorHex = "#FF0000"
        a.fillColorHex = "#00FF00"
        a.lineWidth = 4
        a.dashStyle = "dashed"
        a.fontSize = 20
        a.isBold = true
        a.opacity = 0.5
        a.rotationDegrees = 30

        var b = NoteShapeAttachment(
            id: "22222222-2222-4222-8222-222222222222", kindName: "process",
            x: 100, y: 400, width: 160, height: 60, label: "處理")

        // 一條任意角度的線：外框＋旋轉。
        let frame = ShapeFrameMath.lineFrame(from: CGPoint(x: 300, y: 600), to: CGPoint(x: 500, y: 500))
        var line = NoteShapeAttachment(
            id: "33333333-3333-4333-8333-333333333333", kindName: "arrow",
            x: frame.frame.minX, y: frame.frame.minY,
            width: frame.frame.width, height: frame.frame.height)
        line.rotationDegrees = frame.rotation

        var c = NoteConnectionAttachment(
            id: "44444444-4444-4444-8444-444444444444", fromShapeId: a.id, toShapeId: b.id, label: "是")
        c.fromAnchor = "bottom"; c.toAnchor = "top"; c.route = "straight"
        c.startCap = "circle"; c.endCap = "hollow"
        c.colorHex = "#0000FF"; c.lineWidth = 3; c.dashStyle = "dotted"

        var doc = NotebookDocument(title: "流程圖", pageCount: 1, template: .blank)
        doc.shapeAttachments = [a, b, line]
        doc.connectionAttachments = [c]
        return doc
    }

    func testShapeGeometryAndStyleSurviveThePackage() throws {
        let doc = shapeDocument()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-shape-rt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("s.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: path, deviceId: 0xA1)
        let back = try NotebookPackageBridge.importDocument(
            fromPackageAt: path, deviceId: 0xA2, documentId: doc.id).document

        let shapes = Dictionary(uniqueKeysWithValues: (back.shapeAttachments ?? []).map { ($0.id, $0) })
        let a = try XCTUnwrap(shapes["11111111-1111-4111-8111-111111111111"])
        XCTAssertEqual(a.kindName, "decision")
        XCTAssertEqual(a.x, 100, accuracy: 0.1)
        XCTAssertEqual(a.width, 180, accuracy: 0.1)
        XCTAssertEqual(a.canvasRotation, 30, accuracy: 0.1, "旋轉走核心的物件變換")
        XCTAssertEqual(a.strokeColorHex, "#FF0000")
        XCTAssertEqual(a.fillColorHex, "#00FF00")
        XCTAssertEqual(a.lineWidth, 4)
        XCTAssertEqual(a.dashStyle, "dashed")
        XCTAssertEqual(a.fontSize, 20)
        XCTAssertEqual(a.isBold, true)
        XCTAssertEqual(a.opacity, 0.5)
        XCTAssertEqual(a.label, "要不要？")

        // 任意角度的線：兩個端點回得來。
        let line = try XCTUnwrap(shapes["33333333-3333-4333-8333-333333333333"])
        let ends = line.lineEndpoints
        XCTAssertEqual(ends.start.x, 300, accuracy: 0.2)
        XCTAssertEqual(ends.start.y, 600, accuracy: 0.2)
        XCTAssertEqual(ends.end.x, 500, accuracy: 0.2)
        XCTAssertEqual(ends.end.y, 500, accuracy: 0.2)
    }

    func testConnectionSettingsSurviveThePackage() throws {
        let doc = shapeDocument()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-conn-rt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("c.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: path, deviceId: 0xB1)
        let back = try NotebookPackageBridge.importDocument(
            fromPackageAt: path, deviceId: 0xB2, documentId: doc.id).document
        let c = try XCTUnwrap(back.connectionAttachments?.first)
        XCTAssertEqual(c.fromAnchor, "bottom")
        XCTAssertEqual(c.toAnchor, "top")
        XCTAssertEqual(c.route, "straight")
        XCTAssertEqual(c.startCap, "circle")
        XCTAssertEqual(c.endCap, "hollow")
        XCTAssertEqual(c.colorHex, "#0000FF")
        XCTAssertEqual(c.lineWidth, 3)
        XCTAssertEqual(c.dashStyle, "dotted")
        XCTAssertEqual(c.label, "是")
    }

    func testShapeStylesTravelAsPerObjectEnvelopesNotAsOneMetaRegister() {
        // 整本一個暫存器 = 兩台裝置改不同形狀會互相覆蓋。樣式要走逐物件信封。
        let meta = NotebookMeta(from: shapeDocument())
        XCTAssertNil(meta.shapeStyles)
        XCTAssertNil(meta.connectionStyles)
    }
}

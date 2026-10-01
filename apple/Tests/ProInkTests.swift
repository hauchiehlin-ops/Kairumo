//
//  ProInkTests.swift
//  KairumoTests
//
//  專業筆刷（自繪引擎）：資料、儲存、同步、算繪、筆刷目錄與核心對帳。
//

import PencilKit
import XCTest
@testable import Kairumo

final class ProInkTests: XCTestCase {

    private var workDir: URL!
    private let deviceA: UInt32 = 0x0A0A0A0A
    private let deviceB: UInt32 = 0x0B0B0B0B

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-proink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func stroke(_ tool: String = "charcoal", x: Float = 20, count: Int = 12) -> ProStroke {
        ProStroke(
            tool: tool, colorRGBA: [30, 60, 200, 255], baseWidth: 8,
            points: (0 ..< count).map {
                ProPoint(x: x + Float($0) * 9, y: 80 + sin(Float($0)) * 6, pressure: 0.3 + Float($0) / Float(count),
                         tilt: 0, azimuth: 0, dtUs: 8_000)
            })
    }

    // MARK: 筆刷目錄與核心對帳

    func testEveryToolHasACoreIconAndOnlyBrushesHaveAPreview() {
        for tool in EditorToolType.allCases {
            XCTAssertFalse(brushIcon(tool: tool.ffiTool).isEmpty, "\(tool) 沒有向量圖示")
            let preview = brushPreviewDabs(tool: tool.ffiTool, width: 80, height: 24)
            XCTAssertEqual(!preview.isEmpty, tool.isBrush, "\(tool) 的筆跡預覽有無不對")
        }
    }

    func testBrushFamiliesMatchTheCore() {
        let groups = FfiToolbar(locale: .english).allGroups()
        let infos = groups.flatMap(\.tools)
        XCTAssertEqual(infos.count, 19, "核心的工具清單數量變了，兩端要一起改")
        for info in infos {
            guard let tool = EditorToolType.allCases.first(where: { $0.parityIdentifier == info.identifier }) else {
                continue // 復原、重做、清除不是編輯器工具
            }
            XCTAssertEqual(tool.family, info.family, "\(tool) 的族與核心不一致")
        }
        // 核心清單裡的每一支筆，Apple 端都有對應的工具。
        let ids = Set(EditorToolType.allCases.map(\.parityIdentifier))
        for info in infos where info.family != nil {
            XCTAssertTrue(ids.contains(info.identifier), "核心有 \(info.identifier)，Apple 端沒有")
        }
    }

    func testShortcutsKeepTheirOriginalOrder() {
        XCTAssertEqual(
            EditorToolType.shortcutOrder.map(\.rawValue),
            ["pen", "ballpoint", "brush", "marker", "highlighter", "pencil", "watercolor", "eraser", "lasso", "masking_tape"],
            "⌘1…⌘0 是肌肉記憶，不能跟著工具列重排")
    }

    func testProBrushesAreExactlyTheCoreCustomEngineOnes() {
        for tool in EditorToolType.allCases {
            if let kind = tool.proToolKind {
                XCTAssertTrue(brushIsCustom(tool: kind), "\(tool) 不是自繪引擎筆刷")
            }
        }
        XCTAssertEqual(EditorToolType.allCases.filter { $0.proToolKind != nil }.count, 6)
    }

    // MARK: 儲存

    func testStorageRoundTripKeepsEveryPoint() {
        let strokes = [stroke("crayon"), stroke("airbrush", x: 100)]
        ProInkStore.save(strokes, in: workDir, notebookId: "nb", page: 2)
        XCTAssertEqual(ProInkStore.load(in: workDir, notebookId: "nb", page: 2), strokes)
        XCTAssertTrue(ProInkStore.load(in: workDir, notebookId: "nb", page: 3).isEmpty)
        ProInkStore.save([], in: workDir, notebookId: "nb", page: 2)
        XCTAssertTrue(ProInkStore.load(in: workDir, notebookId: "nb", page: 2).isEmpty, "存空陣列應該刪檔")
    }

    // MARK: 算繪

    func testEveryProBrushPutsInkOnTheBitmap() throws {
        for name in ["fineliner", "charcoal", "crayon", "airbrush", "oilpaint", "calligraphy"] {
            let s = stroke(name)
            let cached = try XCTUnwrap(ProInkRenderer.cache(for: s), "\(name) 算不出筆點")
            XCTAssertFalse(cached.dabs.isEmpty)
            let size = CGSize(width: 260, height: 160)
            UIGraphicsBeginImageContextWithOptions(size, false, 1)
            defer { UIGraphicsEndImageContext() }
            let ctx = try XCTUnwrap(UIGraphicsGetCurrentContext())
            ProInkRenderer.draw(cached, color: s.colorRGBA, in: ctx, clip: CGRect(origin: .zero, size: size))
            let image = try XCTUnwrap(UIGraphicsGetImageFromCurrentImageContext()?.cgImage)
            let data = try XCTUnwrap(image.dataProvider?.data as Data?)
            let inked = stride(from: 3, to: data.count, by: 4).filter { data[$0] > 0 }.count
            XCTAssertGreaterThan(inked, 50, "\(name) 畫完之後點陣圖幾乎是空的")
        }
    }

    // MARK: 畫布層

    @MainActor
    func testLayerCommitsPersistsErasesAndUndoes() throws {
        let manager = UndoManager()
        // 真實使用時每個動作是各自的 run loop 事件，各自成一組；測試沒有 run loop，要自己分組。
        manager.groupsByEvent = false
        let layer = ProInkLayerView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        layer.undoManagerProvider = { manager }
        layer.load(directory: workDir, notebookId: "nb", pageIndex: 0)

        let points = stroke("fineliner").points
        manager.beginUndoGrouping()
        layer.beginStroke(tool: .fineliner, color: [0, 0, 0, 255], width: 4, at: points[0])
        layer.extendStroke(with: Array(points.dropFirst()))
        layer.endStroke()
        manager.endUndoGrouping()
        XCTAssertEqual(layer.ownStrokes.count, 1)
        XCTAssertEqual(ProInkStore.load(in: workDir, notebookId: "nb", page: 0).count, 1, "畫完要立刻存檔")

        // 擦掉
        let path = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        manager.beginUndoGrouping()
        XCTAssertEqual(layer.erase(along: path, radius: 8), 1)
        manager.endUndoGrouping()
        XCTAssertTrue(layer.ownStrokes.isEmpty)
        XCTAssertTrue(ProInkStore.load(in: workDir, notebookId: "nb", page: 0).isEmpty)

        // 復原擦除 → 筆畫回來；再復原 → 筆畫消失（登記進同一個 UndoManager）。
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 1, "復原擦除之後筆畫應該回來")
        manager.undo()
        XCTAssertTrue(layer.ownStrokes.isEmpty, "復原落筆之後筆畫應該消失")
        manager.redo()
        XCTAssertEqual(layer.ownStrokes.count, 1)
    }

    @MainActor
    func testErasingMissesStrokesFarAway() {
        let layer = ProInkLayerView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        layer.load(directory: workDir, notebookId: "nb", pageIndex: 0)
        let s = stroke("charcoal")
        layer.beginStroke(tool: .charcoal, color: [0, 0, 0, 255], width: 6, at: s.points[0])
        layer.extendStroke(with: Array(s.points.dropFirst()))
        layer.endStroke()
        XCTAssertEqual(layer.erase(along: [CGPoint(x: 350, y: 280)], radius: 8), 0)
        XCTAssertEqual(layer.ownStrokes.count, 1)
    }

    // MARK: 同步

    func testProStrokesRoundTripThroughThePackageWithoutBecomingPencilKitStrokes() throws {
        let package = workDir.appendingPathComponent("pro.padnote")
        let original = stroke("charcoal")
        try NotebookPackageBridge.export(
            document: NotebookDocument(title: "P", pageCount: 1), drawings: [PKDrawing()],
            to: package, deviceId: deviceB, proStrokes: [[original]])

        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceA)
        XCTAssertEqual(imported.drawings.first?.strokes.count, 0, "專業筆畫不該變成 PKStroke")
        let back = try XCTUnwrap(imported.proStrokes.first?.first)
        XCTAssertEqual(imported.proStrokes.first?.count, 1)
        XCTAssertEqual(back.tool, "charcoal")
        XCTAssertEqual(back.colorRGBA, original.colorRGBA)
        XCTAssertEqual(back.points.count, original.points.count)
        XCTAssertEqual(back.contentKey, original.contentKey, "經過核心之後內容指紋要不變，同步才認得出是同一筆")
    }

    func testProStrokesDoNotMultiplyAcrossDevices() throws {
        let package = workDir.appendingPathComponent("two.padnote")
        let doc = NotebookDocument(title: "P", pageCount: 1)
        let bs = stroke("oilpaint", x: 20)
        let asStroke = stroke("airbrush", x: 120)

        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: package, deviceId: deviceB, proStrokes: [[bs]])

        // 兩台輪流「匯入 → 把別人的扣掉 → 只匯出自己的」，數量必須維持。
        var aOwn: [ProStroke] = [asStroke]
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: [PKDrawing()], to: package, deviceId: deviceA,
            proStrokes: [aOwn])
        for round in 0 ..< 6 {
            let device = round.isMultiple(of: 2) ? deviceA : deviceB
            let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: device)
            let merged = imported.proStrokes.first ?? []
            XCTAssertEqual(merged.count, 2, "第 \(round) 趟：合併後應該兩筆，實得 \(merged.count)")
            let own = device == deviceA ? aOwn : [bs]
            try NotebookPackageBridge.exportPreservingOtherDevices(
                document: imported.document, drawings: [PKDrawing()], to: package,
                deviceId: device, pageIds: imported.pageIds, proStrokes: [own])
            if device == deviceA { aOwn = own }
        }
    }
}

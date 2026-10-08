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
        XCTAssertEqual(infos.count, 20, "核心的工具清單數量變了，兩端要一起改")
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

    /// 別台（或舊安裝、重新下載之後）的筆畫看得見，橡皮擦與復原卻碰不到 ——
    /// 使用者看到的是「前幾筆擦不掉也無法復原」。
    @MainActor
    func testForeignStrokesCanBeErasedUndoneAndStayErasedAcrossSync() throws {
        let nb = "foreign-\(UUID().uuidString)"
        let foreign = stroke("charcoal")
        ProInkStore.save([foreign], in: workDir, notebookId: nb, page: 0, foreign: true)
        let manager = UndoManager()
        manager.groupsByEvent = false
        let layer = ProInkLayerView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        layer.undoManagerProvider = { manager }
        layer.load(directory: workDir, notebookId: nb, pageIndex: 0)
        XCTAssertEqual(layer.allStrokes.count, 1)

        let p = CGPoint(x: CGFloat(foreign.points[0].x), y: CGFloat(foreign.points[0].y))
        manager.beginUndoGrouping()
        XCTAssertEqual(layer.erase(along: [p], radius: 12), 1, "別台的筆畫要擦得掉")
        manager.endUndoGrouping()
        XCTAssertTrue(layer.allStrokes.isEmpty)
        XCTAssertTrue(ProInkStore.loadSuppressed(in: workDir, notebookId: nb, page: 0).contains(foreign.contentKey),
                      "要記住它被擦掉了，不然下一輪同步又帶回來")
        XCTAssertTrue(ProInkStore.load(in: workDir, notebookId: nb, page: 0, foreign: true).isEmpty)

        manager.undo()
        XCTAssertEqual(layer.allStrokes.count, 1, "復原要把它放回來")
        XCTAssertTrue(ProInkStore.loadSuppressed(in: workDir, notebookId: nb, page: 0).isEmpty)
        manager.redo()
        XCTAssertTrue(layer.allStrokes.isEmpty)
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

    // MARK: 刪除與改圖層的同步（墓碑）

    private func point(of s: ProStroke) -> CGPoint {
        CGPoint(x: CGFloat(s.points[0].x), y: CGFloat(s.points[0].y))
    }

    private func layerView(_ nb: String, undo: UndoManager? = nil) -> ProInkLayerView {
        let layer = ProInkLayerView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        if let undo { layer.undoManagerProvider = { undo } }
        layer.load(directory: workDir, notebookId: nb, pageIndex: 0)
        return layer
    }

    private func inkBytes(_ package: URL) -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: package.appendingPathComponent("ink"), includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func testProStrokeKeepsItsIdentityThroughThePackage() throws {
        // 同一條線每次匯出都要是同一個身分：別台的墓碑才對得上。
        let package = workDir.appendingPathComponent("identity.padnote")
        let original = stroke("fineliner")
        try NotebookPackageBridge.export(
            document: NotebookDocument(title: "I", pageCount: 1), drawings: [PKDrawing()],
            to: package, deviceId: deviceA, proStrokes: [[original]])
        let back = try XCTUnwrap(
            NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceB).proStrokes.first?.first)
        XCTAssertEqual(back.id, original.packageId)
    }

    func testAnotherDevicesTombstoneRemovesTheStrokeAndIsReportedToItsOwner() throws {
        // B 畫一筆 → A 把它改到別的圖層（擦掉原筆畫 + 自己名下一筆複本）→ B 匯入：原筆畫消失、複本出現、
        // 而且匯入結果明說「你的這一筆被擦掉了」（B 才知道要把本機那一筆拿掉）。
        let package = workDir.appendingPathComponent("tomb.padnote")
        let doc = NotebookDocument(title: "T", pageCount: 1)
        let bs = stroke("fineliner", x: 20)
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: package, deviceId: deviceB, proStrokes: [[bs]])

        let importedA = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceA)
        let theirs = try XCTUnwrap(importedA.proStrokes.first?.first)
        var copy = theirs
        copy.id = UUID().uuidString
        copy.layer = 3
        let ledger = ProInkLedger(retired: [.init(coreId: theirs.packageId, stroke: nil, exported: false)])
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: importedA.document, drawings: [PKDrawing()], to: package, deviceId: deviceA,
            pageIds: importedA.pageIds, proStrokes: [[copy]], proLedgers: [ledger])

        let importedB = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceB)
        let merged = try XCTUnwrap(importedB.proStrokes.first)
        XCTAssertEqual(merged.count, 1, "原筆畫要消失、只剩改過圖層的那一筆")
        XCTAssertEqual(merged.first?.layerId, 3)
        XCTAssertTrue(importedB.removedProStrokeIds.first?.contains(bs.packageId) == true,
                      "原作者要能從匯入結果知道自己的這一筆被擦掉了")
    }

    func testAMissingStrokeWithoutATombstoneIsNotReportedAsRemoved() throws {
        // 同步可能下載到較舊的筆畫檔，剛畫的筆畫暫時不見 —— 那不是被擦掉，不能被當成被擦掉。
        let package = workDir.appendingPathComponent("nottomb.padnote")
        try NotebookPackageBridge.export(
            document: NotebookDocument(title: "N", pageCount: 1), drawings: [PKDrawing()],
            to: package, deviceId: deviceA, proStrokes: [[stroke("fineliner")]])
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceB)
        XCTAssertTrue(imported.removedProStrokeIds.first?.isEmpty == true)
    }

    func testAnErasedOwnStrokeIsWrittenWithItsAddSoTheStrokeFileOnlyGrows() throws {
        // 同步只傳「變大」的筆畫檔。擦掉自己的筆畫若只是不寫它，檔案變小、墓碑永遠傳不出去。
        let doc = NotebookDocument(title: "G", pageCount: 1)
        let mine = stroke("fineliner")
        let before = workDir.appendingPathComponent("grow-before.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: before, deviceId: deviceA, proStrokes: [[mine]])
        let after = workDir.appendingPathComponent("grow-after.padnote")
        let ledger = ProInkLedger(retired: [.init(coreId: mine.packageId, stroke: mine, exported: false)])
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: after, deviceId: deviceA,
            proStrokes: [[]], proLedgers: [ledger])
        XCTAssertGreaterThan(inkBytes(after), inkBytes(before))
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: after, deviceId: deviceB)
        XCTAssertTrue(imported.proStrokes.first?.isEmpty == true, "寫了墓碑，這一筆在別台看不到")
    }

    @MainActor
    func testErasingAnExportedOwnStrokeLeavesATombstoneButAnUnexportedOneDoesNot() {
        let nb = "tomb-\(UUID().uuidString)"
        let sent = stroke("fineliner", x: 20), fresh = stroke("fineliner", x: 420)
        ProInkStore.save([sent, fresh], in: workDir, notebookId: nb, page: 0)
        ProInkStore.updateLedger(in: workDir, notebookId: nb, page: 0) { $0.exportedIds = [sent.packageId] }
        let layer = layerView(nb)
        XCTAssertEqual(layer.erase(along: [point(of: sent)], radius: 12), 1)
        XCTAssertEqual(layer.erase(along: [point(of: fresh)], radius: 12), 1)
        let ledger = ProInkStore.loadLedger(in: workDir, notebookId: nb, page: 0)
        XCTAssertEqual(ledger.retired.map(\.coreId), [sent.packageId], "沒匯出過的不必寫墓碑")
        XCTAssertEqual(ledger.retired.first?.stroke?.id, sent.id, "自己的筆畫要帶著整筆資料，匯出才寫得出 Add")
        XCTAssertTrue(ProInkStore.hasUnexportedRetirements(in: workDir, notebookId: nb, page: 0))
    }

    @MainActor
    func testUndoingAnEraseBeforeItWasExportedDropsTheTombstone() {
        let nb = "undo1-\(UUID().uuidString)"
        let sent = stroke("fineliner")
        ProInkStore.save([sent], in: workDir, notebookId: nb, page: 0)
        ProInkStore.updateLedger(in: workDir, notebookId: nb, page: 0) { $0.exportedIds = [sent.packageId] }
        let manager = UndoManager()
        manager.groupsByEvent = false
        let layer = layerView(nb, undo: manager)
        manager.beginUndoGrouping()
        XCTAssertEqual(layer.erase(along: [point(of: sent)], radius: 12), 1)
        manager.endUndoGrouping()
        XCTAssertEqual(ProInkStore.loadLedger(in: workDir, notebookId: nb, page: 0).retired.count, 1)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 1)
        XCTAssertTrue(ProInkStore.loadLedger(in: workDir, notebookId: nb, page: 0).retired.isEmpty,
                      "墓碑還沒寫出去，復原就把它撤掉")
        XCTAssertEqual(layer.ownStrokes.first?.packageId, sent.packageId)
    }

    @MainActor
    func testUndoingAnEraseAfterTheTombstoneWasExportedUsesANewPackageId() {
        // 已經上傳的墓碑撤不掉：同一個套件身分不能再活過來，這一筆要換新的。
        let nb = "undo2-\(UUID().uuidString)"
        let sent = stroke("fineliner")
        ProInkStore.save([sent], in: workDir, notebookId: nb, page: 0)
        ProInkStore.updateLedger(in: workDir, notebookId: nb, page: 0) { $0.exportedIds = [sent.packageId] }
        let manager = UndoManager()
        manager.groupsByEvent = false
        let layer = layerView(nb, undo: manager)
        manager.beginUndoGrouping()
        layer.erase(along: [point(of: sent)], radius: 12)
        manager.endUndoGrouping()
        ProInkStore.updateLedger(in: workDir, notebookId: nb, page: 0) { ledger in
            for i in ledger.retired.indices { ledger.retired[i].exported = true }
        }
        manager.undo()
        let back = layer.ownStrokes.first
        XCTAssertEqual(back?.id, sent.id, "本機身分不變，復原／重做才找得到它")
        XCTAssertNotEqual(back?.packageId, sent.packageId, "已寫出的墓碑撤不掉，要換新的套件身分")
        XCTAssertEqual(ProInkStore.loadLedger(in: workDir, notebookId: nb, page: 0).retired.count, 1,
                       "舊身分的墓碑要留著")
    }

    @MainActor
    func testReassigningAnExportedOwnStrokeRetiresTheOldVersion() {
        let nb = "layer1-\(UUID().uuidString)"
        let sent = stroke("fineliner")
        ProInkStore.save([sent], in: workDir, notebookId: nb, page: 0)
        ProInkStore.updateLedger(in: workDir, notebookId: nb, page: 0) { $0.exportedIds = [sent.packageId] }
        let layer = layerView(nb)
        XCTAssertTrue(layer.reassignLayer(near: point(of: sent), to: 3))
        let now = layer.ownStrokes[0]
        XCTAssertEqual(now.layerId, 3)
        XCTAssertNotEqual(now.packageId, sent.packageId, "內容變了要換套件身分，別台才收得到")
        let ledger = ProInkStore.loadLedger(in: workDir, notebookId: nb, page: 0)
        XCTAssertEqual(ledger.retired.map(\.coreId), [sent.packageId])
        XCTAssertEqual(ledger.retired.first?.stroke?.layerId, 0, "墓碑帶的是改之前的樣子")
    }

    @MainActor
    func testReassigningAnotherDevicesStrokeTombstonesItAndKeepsAnOwnCopy() {
        let nb = "layer2-\(UUID().uuidString)"
        var theirs = stroke("fineliner")
        theirs.id = "0192f0aa-1111-7222-8333-444455556666"   // 核心發的 id（小寫）
        ProInkStore.save([theirs], in: workDir, notebookId: nb, page: 0, foreign: true)
        let layer = layerView(nb)
        XCTAssertTrue(layer.reassignLayer(near: point(of: theirs), to: 2))
        XCTAssertEqual(layer.ownStrokes.count, 1)
        XCTAssertEqual(layer.ownStrokes[0].layerId, 2)
        XCTAssertNotEqual(layer.ownStrokes[0].packageId, theirs.id)
        XCTAssertTrue(ProInkStore.load(in: workDir, notebookId: nb, page: 0, foreign: true).isEmpty)
        let ledger = ProInkStore.loadLedger(in: workDir, notebookId: nb, page: 0)
        XCTAssertEqual(ledger.retired.map(\.coreId), [theirs.id])
        XCTAssertNil(ledger.retired.first?.stroke, "別台的筆畫只寫墓碑，不重寫它")
    }

    func testCopiesOfAStrokeNeverShareItsPackageId() {
        var original = stroke("fineliner")
        original.coreId = UUID().uuidString.lowercased()
        var copy = original
        copy.id = UUID().uuidString
        XCTAssertNil(copy.coreId, "複本沿用套件身分的話，擦掉其中一筆另一筆也跟著消失")
        XCTAssertNotEqual(copy.packageId, original.packageId)
    }

    // MARK: 圖學：圖層、線型、吸附

    private func drafted(layer: UInt8, lineType: UInt8, x: Float = 20) -> ProStroke {
        var s = stroke("fineliner", x: x)
        s.layer = layer == 0 ? nil : layer
        s.lineType = lineType == 0 ? nil : lineType
        return s
    }

    func testOldStrokesWithoutLayerFieldsStillDecodeAndKeepTheirFingerprint() throws {
        // 舊版存的 JSON 沒有 layer／lineType 兩個鍵。
        let plain = stroke("fineliner")
        let json = try JSONEncoder().encode(plain)
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        dict.removeValue(forKey: "layer")
        dict.removeValue(forKey: "lineType")
        let old = try JSONSerialization.data(withJSONObject: dict)
        let back = try JSONDecoder().decode(ProStroke.self, from: old)
        XCTAssertEqual(back.layerId, 0)
        XCTAssertEqual(back.lineTypeId, 0)
        // 沒有圖層的筆畫指紋不變：已同步過的內容不會被當成新的一筆。
        XCTAssertFalse(plain.contentKey.contains("|L"))
        XCTAssertNotEqual(plain.contentKey, drafted(layer: 3, lineType: 1).contentKey)
    }

    func testLayerAndLineTypeSurviveTheCorePackage() throws {
        let package = workDir.appendingPathComponent("draft.padnote")
        let doc = NotebookDocument(title: "D", pageCount: 1)
        let strokes = [drafted(layer: 3, lineType: 1, x: 20), drafted(layer: 2, lineType: 0, x: 90), stroke("fineliner", x: 160)]
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: package, deviceId: deviceA, proStrokes: [strokes])
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceB)
        let back = try XCTUnwrap(imported.proStrokes.first)
        XCTAssertEqual(back.count, 3)
        let pairs = Set(back.map { "\($0.layerId)/\($0.lineTypeId)" })
        XCTAssertEqual(pairs, ["3/1", "2/0", "0/0"], "圖層與線型要原樣經過核心格式")
    }

    func testDraftedInsertResamplesLinesAndKeepsTheirAttributes() throws {
        let item = FfiSheetStroke(
            points: [FfiPoint(x: 0, y: 0), FfiPoint(x: 100, y: 0)], layer: 3, lineType: 1, width: 1.4, colorHex: "#111827")
        let s = try XCTUnwrap(ProStroke(drafted: item, origin: CGPoint(x: 10, y: 20)))
        XCTAssertGreaterThanOrEqual(s.points.count, 25, "每 4 個單位一點，虛線間隔才準")
        XCTAssertEqual(s.points.first?.x, 10)
        XCTAssertEqual(s.points.first?.y, 20)
        XCTAssertEqual(s.layerId, 3)
        XCTAssertEqual(s.lineTypeId, 1)
        XCTAssertNil(ProStroke(drafted: FfiSheetStroke(points: [FfiPoint(x: 0, y: 0)], layer: 3, lineType: 0, width: 1, colorHex: "#000000")))
    }

    @MainActor
    func testLayersDrawBottomUpAndHiddenOnesAreSkipped() {
        let state = DraftingState.shared
        let nb = "draft-test-\(UUID().uuidString)"
        state.use(notebook: nb)
        let strokes = [drafted(layer: 3, lineType: 0, x: 1), drafted(layer: 1, lineType: 0, x: 2),
                       drafted(layer: 2, lineType: 0, x: 3), stroke("fineliner", x: 4)]
        XCTAssertEqual(state.drawOrder(strokes, notebookId: nb).map(\.layerId), [0, 1, 2, 3])
        state.setHidden(true, layer: 2)
        XCTAssertEqual(state.drawOrder(strokes, notebookId: nb).map(\.layerId), [0, 1, 3])
        XCTAssertFalse(state.canEdit(layer: 2, notebookId: nb), "隱藏的圖層擦不到")
        state.setHidden(false, layer: 2)
        state.setLocked(true, layer: 1)
        XCTAssertFalse(state.canEdit(layer: 1, notebookId: nb), "鎖定的圖層擦不到")
        XCTAssertTrue(state.canEdit(layer: 0, notebookId: nb), "一般筆跡永遠可以動")
        state.setLocked(false, layer: 1)
    }

    func testHoldToSnapStraightensAndLocksTheAngle() {
        let crooked = (0 ... 30).map { FfiPoint(x: Float($0) * 5, y: 40 + Float($0) * 0.9 + (Float($0 % 3) - 1)) }
        let snapped = draftSnapStroke(points: crooked, angleStepDeg: 90)
        XCTAssertEqual(snapped.kind, .line)
        XCTAssertEqual(snapped.points.count, crooked.count, "等長，壓感與時間戳才抄得回去")
        let ys = Set(snapped.points.map { Int(($0.y * 10).rounded()) })
        XCTAssertEqual(ys.count, 1, "鎖 90° 之後是水平線")
    }

    func testDraftingPensComeFromTheCore() {
        let pens = draftPens()
        XCTAssertEqual(Set(pens.map(\.id)), ["thick", "thin", "hidden", "center", "phantom", "aux", "given"])
        XCTAssertEqual(draftLayers().map(\.id), [1, 2, 3])
        XCTAssertEqual(DraftingState.rgba(fromHex: "#3B82F6"), [0x3B, 0x82, 0xF6, 255])
    }

    func testSolidSheetUsesDraftingPensAndSketchesExtrude() throws {
        // 草圖拉伸：四條各自一筆的邊圍成矩形。
        func line(_ a: (Float, Float), _ b: (Float, Float)) -> [FfiPoint] {
            (0 ... 10).map { FfiPoint(x: a.0 + (b.0 - a.0) * Float($0) / 10, y: a.1 + (b.1 - a.1) * Float($0) / 10) }
        }
        let profile = try XCTUnwrap(solidProfileFromStrokes(strokes: [
            line((0, 0), (120, 0)), line((120, 0), (120, 80)), line((120, 80), (0, 80)), line((0, 80), (0, 0)),
        ]))
        XCTAssertEqual(profile.width, 120, accuracy: 3)
        let options = FfiSolidSheetOptions(
            firstAngle: false, includeIso: true, projectionLines: true, centerLines: true,
            section: FfiSolidSection(kind: .none, angleDeg: 90, offset: 0.5, offset2: 0.7, step: 0.5, pivotX: 0.5,
                                     pivotY: 0.5, deltaDeg: 30, flip: true, depthFrac: 0.5, tiltDeg: 40),
            fitWidth: 600, fitHeight: 400, hatchSpacing: 6, dimensions: false, sectionLabel: false)
        let sheet = try XCTUnwrap(solidComposeSheet(profile: profile, depth: 60, options: options))
        var dimensioned = options
        dimensioned.dimensions = true
        let withDims = try XCTUnwrap(solidComposeSheet(profile: profile, depth: 60, options: dimensioned))
        XCTAssertGreaterThan(withDims.strokes.count, sheet.strokes.count, "標註尺寸要多出尺寸線與數字筆畫")
        XCTAssertTrue(sheet.strokes.contains { $0.layer == 3 && $0.lineType == 1 }, "等角圖背面三條隱藏線")
        XCTAssertTrue(sheet.strokes.contains { $0.layer == 2 }, "投射線在中層")
    }

    func testPdfExportCarriesProStrokesAndDashedLineTypes() throws {
        let doc = NotebookDocument(title: "P", pageCount: 1)
        let plain = try NotebookPackageBridge.exportPdf(document: doc, drawings: [PKDrawing()], deviceId: deviceA)
        let hidden = drafted(layer: 3, lineType: 1, x: 20)
        let withInk = try NotebookPackageBridge.exportPdf(
            document: doc, drawings: [PKDrawing()], deviceId: deviceA, proStrokes: [[hidden]])
        XCTAssertGreaterThan(withInk.count, plain.count, "匯出的 PDF 要含專業筆畫（製圖線）")
    }

    @MainActor
    func testHiddenLayerIsExcludedFromTheExportedPdf() throws {
        let state = DraftingState.shared
        let nb = "pdf-hidden-\(UUID().uuidString)"
        state.use(notebook: nb)
        let all = [drafted(layer: 3, lineType: 1, x: 20), drafted(layer: 2, lineType: 0, x: 90), stroke("fineliner", x: 160)]
        let doc = NotebookDocument(id: nb, title: "P", pageCount: 1)
        func pdf(_ strokes: [ProStroke]) throws -> Data {
            try NotebookPackageBridge.exportPdf(document: doc, drawings: [PKDrawing()], deviceId: deviceA, proStrokes: [strokes])
        }
        let full = try pdf(state.drawOrder(all, notebookId: nb))
        state.setHidden(true, layer: 2)
        defer { state.setHidden(false, layer: 2) }
        let hiddenAux = try pdf(state.drawOrder(all, notebookId: nb))
        XCTAssertLessThan(hiddenAux.count, full.count, "隱藏中層之後匯出的 PDF 要少一筆")
    }
}

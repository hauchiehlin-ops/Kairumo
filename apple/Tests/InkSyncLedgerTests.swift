//
//  InkSyncLedgerTests.swift
//  KairumoTests
//
//  PencilKit 筆畫的穩定身分與擦除同步（見 InkSyncLedger.swift）。
//

import PencilKit
import XCTest
@testable import Kairumo

final class InkSyncLedgerTests: XCTestCase {

    private func stroke(at x: CGFloat, count: Int = 6) -> PKStroke {
        let points = (0 ..< count).map { i in
            PKStrokePoint(
                location: CGPoint(x: x + CGFloat(i) * 3, y: 120), timeOffset: Double(i) * 0.01,
                size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 1, altitude: 1)
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
    }

    private func noForeign(_: String, _: Int, _: Set<String>) -> [String] { [] }

    func testTheSameContentGetsTheSameIdEveryTime() {
        let a = PKDrawing(strokes: [stroke(at: 10), stroke(at: 100)])
        let first = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: a, prevOwn: nil, current: a, others: PKDrawing(),
            resolveForeign: noForeign)
        let second = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: a, prevOwn: nil, current: a, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertEqual(first.ids, second.ids, "同一條線每次匯出都要是同一個身分，墓碑才對得上")
        XCTAssertEqual(Set(first.ids).count, 2)
        XCTAssertNotNil(UUID(uuidString: first.ids[0]))
    }

    func testErasingAnOwnStrokeAsksForGrowthAndKeepsTheSurvivorsIds() {
        // 自己擦掉的筆畫不必寫墓碑（自己的筆畫檔整個被換掉），但檔案要變大才傳得出去。
        let both = PKDrawing(strokes: [stroke(at: 10), stroke(at: 100)])
        let before = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: both, prevOwn: nil, current: both, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertFalse(before.grow, "沒擦東西不必變大")
        let one = PKDrawing(strokes: [both.strokes[0]])
        let erased = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: one, prevOwn: both, current: one, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertTrue(erased.grow)
        XCTAssertEqual(erased.ids, [before.ids[0]], "沒動過的那一筆身分不變")
        XCTAssertTrue(erased.foreignTombstones.isEmpty)
    }

    func testIdenticalStrokesKeepTheSurvivorsIdWhenOneIsErased() {
        let twin = stroke(at: 10)
        let two = PKDrawing(strokes: [twin, twin])
        let ids = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: two, prevOwn: nil, current: two, others: PKDrawing(),
            resolveForeign: noForeign).ids
        XCTAssertNotEqual(ids[0], ids[1], "完全相同的兩筆也要是兩個身分")
        let one = PKDrawing(strokes: [twin])
        let plan = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: one, prevOwn: two, current: one, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertEqual(plan.ids, [ids[0]], "留下來的那一筆身分不能變")
        XCTAssertTrue(plan.grow)
    }

    func testTombstonesForStrokesThatNoLongerExistAnywhereAreDropped() {
        // 自動清理：墓碑指向的 id 在套件裡已經沒有任何 Add（原作者重寫了檔案），沒有東西可擦。
        var ledger = ProInkLedger()
        ledger.foreignTombstones = ["aaaaaaaa-0000-4000-8000-000000000001", "aaaaaaaa-0000-4000-8000-000000000002"]
        let empty = PKDrawing()
        let plan = PKInkSync.plan(
            ledger: ledger, ownNow: empty, prevOwn: empty, current: empty, others: empty,
            addedIds: ["aaaaaaaa-0000-4000-8000-000000000002"], resolveForeign: noForeign)
        XCTAssertEqual(plan.foreignTombstones, ["aaaaaaaa-0000-4000-8000-000000000002"])
        // 讀不到套件時不清理（寧可多留）。
        let keep = PKInkSync.plan(
            ledger: ledger, ownNow: empty, prevOwn: empty, current: empty, others: empty,
            addedIds: nil, resolveForeign: noForeign)
        XCTAssertEqual(keep.foreignTombstones.count, 2)
    }

    func testWithoutAPreviousSnapshotNothingIsInferredAsErased() {
        // 升級前沒有「上次匯出」的快照。把它當成空的，整頁都會被當成剛擦掉。
        let a = PKDrawing(strokes: [stroke(at: 10)])
        let plan = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: a, prevOwn: nil, current: a, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertFalse(plan.grow)
        XCTAssertTrue(plan.foreignTombstones.isEmpty)
    }

    func testErasingAnotherDevicesStrokeAsksTheResolverForItsCoreId() {
        let theirs = stroke(at: 300)
        let others = PKDrawing(strokes: [theirs])
        let mine = PKDrawing(strokes: [stroke(at: 10)])
        let current = mine   // 別台那一筆被擦掉了
        var asked: [(String, Int)] = []
        let plan = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: mine, prevOwn: mine, current: current, others: others,
            resolveForeign: { key, count, _ in
                asked.append((key, count))
                return ["0192f0aa-1111-7222-8333-444455556666"]
            })
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(asked.first?.0, StrokeDelta.Identity(theirs).key)
        XCTAssertEqual(plan.foreignTombstones, ["0192f0aa-1111-7222-8333-444455556666"])
        XCTAssertEqual(plan.erasedForeign.count, 1)
    }

    func testOldLedgerJSONWithoutTheNewFieldsStillDecodes() throws {
        let old = #"{"retired":[],"exportedIds":["a"]}"#
        let ledger = try JSONDecoder().decode(ProInkLedger.self, from: Data(old.utf8))
        XCTAssertEqual(ledger.exportedIds, ["a"])
        XCTAssertEqual(ledger.schema, 0)
        XCTAssertTrue(ledger.pkRetiredOwn.isEmpty)
    }

    func testErasingOwnStrokesAppendsTombstonesAndNeverShrinksTheStrokeFile() throws {
        // ADR-0015：筆畫檔是只追加的事件串流。擦掉自己的筆畫＝追加墓碑，不重寫檔案 ——
        // 檔案只會變大（同步只傳變大的檔案），之前寫下的墓碑一筆都不會丟。
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-pad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let package = dir.appendingPathComponent("p.padnote")
        let doc = NotebookDocument(title: "P", pageCount: 1)
        let device: UInt32 = 0x0A0A
        let big = PKDrawing(strokes: (0 ..< 8).map { stroke(at: CGFloat($0) * 40) })
        // 與同步匯出相同：每一筆用由內容算出的穩定身分寫進去。
        let ids = big.strokes.map { PKStrokeId.make(key: StrokeDelta.Identity($0).key, n: 0, gen: 0) }
        try NotebookPackageBridge.export(
            document: doc, drawings: [big], to: package, deviceId: device, pkStrokeIds: [ids])

        func inkBytes() -> UInt64 {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: package.appendingPathComponent("ink"), includingPropertiesForKeys: [.fileSizeKey])) ?? []
            return files.reduce(0) { $0 + UInt64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        }
        let before = inkBytes()
        // 擦掉大部分。
        let small = PKDrawing(strokes: [big.strokes[0]])
        let erased = [NotebookPackageBridge.InkReconcile(erasedOwn: PKStrokeId.erasedOwn(previous: big, now: small))]
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: [small], to: package, deviceId: device, inkReconcile: erased)
        XCTAssertGreaterThan(inkBytes(), before, "擦除要以墓碑追加，檔案只會變大")
        // 再匯出一次同樣的內容：墓碑已經在了，不重複寫。
        let sizeNow = inkBytes()
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: [small], to: package, deviceId: device, inkReconcile: erased)
        XCTAssertEqual(inkBytes(), sizeNow, "沒有新的改動，筆畫檔不該再變")
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x0B0B)
        XCTAssertEqual(imported.drawings.first?.strokes.count, 1, "擦掉的 7 筆在別台也要不見")
    }

    func testAnEraseIsWrittenToThePackageTheMomentItHappens() throws {
        // ADR-0015 I2：擦除在當下寫成墓碑，不等匯出。之後任何一次匯入（含別台較大的舊檔）都看不到它。
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-now-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let package = dir.appendingPathComponent("p.padnote")
        let doc = NotebookDocument(title: "N", pageCount: 1)
        let device: UInt32 = 0x0C0C
        let a = stroke(at: 20), b = stroke(at: 220)
        let ids = [a, b].map { PKStrokeId.make(key: StrokeDelta.Identity($0).key, n: 0, gen: 0) }
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing(strokes: [a, b])], to: package, deviceId: device,
            pkStrokeIds: [ids])

        // 另一台擦掉 b（它是 a、b 的作者以外的裝置）。
        try NotebookPackageBridge.eraseInk(document: doc, pageIndex: 0, strokes: [b], at: package, deviceId: 0x0D0D)
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x0E0E)
        XCTAssertEqual(imported.drawings.first?.strokes.count, 1, "擦除在寫入的那一刻就該生效")

        // 原作者之後再匯出同樣的內容（它還不知道 b 被擦了）：b 不能因此復活。
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: [PKDrawing(strokes: [a, b])], to: package, deviceId: device,
            pkStrokeIds: [ids])
        let again = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x0E0E)
        XCTAssertEqual(again.drawings.first?.strokes.count, 1, "原作者的匯出把別台擦掉的筆畫帶回來了")
    }

    func testUndoingAnEraseOnTheCanvasBringsTheStrokeBackEverywhere() throws {
        // 擦的當下已經寫了墓碑（撤不掉）；復原把它加回畫布時，要以新身分寫入，每一台才都看得到。
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-revive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let package = dir.appendingPathComponent("p.padnote")
        let doc = NotebookDocument(title: "U", pageCount: 1)
        let device: UInt32 = 0x0F0F
        let a = stroke(at: 20), b = stroke(at: 220)
        let ids = [a, b].map { PKStrokeId.make(key: StrokeDelta.Identity($0).key, n: 0, gen: 0) }
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing(strokes: [a, b])], to: package, deviceId: device,
            pkStrokeIds: [ids])

        try NotebookPackageBridge.eraseInk(document: doc, pageIndex: 0, strokes: [b], at: package, deviceId: device)
        XCTAssertEqual(try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x0E0E)
            .drawings.first?.strokes.count, 1)
        try NotebookPackageBridge.reviveInk(document: doc, pageIndex: 0, strokes: [b], at: package, deviceId: device)
        XCTAssertEqual(try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x0E0E)
            .drawings.first?.strokes.count, 2, "復原擦除之後，別台看不到那一筆")
        // 已經看得見就不再加（不會變兩份）。
        try NotebookPackageBridge.reviveInk(document: doc, pageIndex: 0, strokes: [b], at: package, deviceId: device)
        XCTAssertEqual(try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x0E0E)
            .drawings.first?.strokes.count, 2, "同一筆被加了兩份")
    }

    @MainActor
    func testEditorEditsOnlyEraseStrokesTheUserCouldSee() throws {
        // 編輯器的副本可能已經含有別台剛同步進來、畫布還沒顯示的筆畫。套索刪掉選取範圍時，
        // 只有畫布上看得到的那幾筆可以寫成墓碑 —— 否則別台的筆畫會被這台「擦掉」。
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-sink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let package = dir.appendingPathComponent("p.padnote")
        let doc = NotebookDocument(title: "S", pageCount: 1)
        let device: UInt32 = 0x1A1A
        let seen = stroke(at: 20), unseen = stroke(at: 220)
        let ids = [seen, unseen].map { PKStrokeId.make(key: StrokeDelta.Identity($0).key, n: 0, gen: 0) }
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing(strokes: [seen, unseen])], to: package, deviceId: device,
            pkStrokeIds: [ids])

        InkEventSink.register(
            notebookId: doc.id, document: { doc }, package: package, baselineDirectory: dir,
            deviceId: device, queue: NotebookEditorView.coreInkQueue)
        defer { InkEventSink.unregister(notebookId: doc.id) }
        InkEventSink.sink(for: doc.id)?.editorEdited(
            page: 0, before: PKDrawing(strokes: [seen, unseen]), after: PKDrawing(),
            shown: PKDrawing(strokes: [seen]))
        NotebookEditorView.coreInkQueue.sync {}

        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x1B1B)
        XCTAssertEqual(imported.drawings.first?.strokes.count, 1, "使用者沒看到的筆畫被寫了墓碑")
        XCTAssertEqual(
            imported.drawings.first.map { StrokeDelta.Identity($0.strokes[0]).key },
            StrokeDelta.Identity(unseen).key)
    }

    // MARK: 清理

    func testCompactDropsLegacyRetiredStrokeDataAndKeepsForeignTombstones() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-janitor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let big = ProStroke(
            tool: "fineliner", colorRGBA: [0, 0, 0, 255], baseWidth: 2,
            points: (0 ..< 500).map { ProPoint(x: Float($0), y: 80, pressure: 0.5, tilt: 0, azimuth: 0, dtUs: 8_000) })
        ProInkStore.updateLedger(in: dir, notebookId: "nb", page: 0) { ledger in
            ledger.schema = 2
            ledger.retired = [
                .init(coreId: "own-done", stroke: big, exported: true),
                .init(coreId: "own-pending", stroke: big, exported: false),
                .init(coreId: "foreign", stroke: nil, exported: true),
            ]
            ledger.foreignTombstones = ["t1"]
            ledger.pkRetiredOwn = [.init(id: "x", drawing: Data(count: 4096))]
            ledger.pkGen = ["k#0": 3]
        }
        let file = dir.appending(path: "nb_p0.proink-ledger.json")
        func bytes() -> Int {
            ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? NSNumber)?.intValue ?? 0
        }
        let before = bytes()
        let report = InkLedgerJanitor.compact(drawingsDirectory: dir)
        let after = bytes()
        XCTAssertLessThan(after, before)
        XCTAssertEqual(report.bytesFreed, Int64(before - after))
        let ledger = ProInkStore.loadLedger(in: dir, notebookId: "nb", page: 0)
        XCTAssertEqual(Set(ledger.retired.map(\.coreId)), ["own-pending", "foreign"],
                       "已匯出的自己的退休記錄丟掉；還沒匯出的（要讓檔案變大）與別台的墓碑留著")
        XCTAssertEqual(ledger.foreignTombstones, ["t1"])
        XCTAssertTrue(ledger.pkRetiredOwn.isEmpty)
        XCTAssertTrue(ledger.pkGen.isEmpty)
    }

    func testClearEraseHistoryRemovesEveryTombstoneAndFingerprintList() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-janitor2-\(UUID().uuidString)", isDirectory: true)
        let drawings = root.appendingPathComponent("D"), baseline = root.appendingPathComponent("B")
        try FileManager.default.createDirectory(at: drawings, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: baseline, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        ProInkStore.updateLedger(in: drawings, notebookId: "nb", page: 0) { ledger in
            ledger.schema = 2
            ledger.retired = [.init(coreId: "foreign", stroke: nil, exported: true)]
            ledger.foreignTombstones = ["t1"]
        }
        ProInkStore.saveSuppressed(["k"], in: drawings, notebookId: "nb", page: 0)
        ErasedInkLedger.save(["e"], in: baseline, notebookId: "nb", page: 0)
        XCTAssertGreaterThan(InkLedgerJanitor.usage(drawingsDirectory: drawings, baselineDirectory: baseline), 0)
        InkLedgerJanitor.clearEraseHistory(drawingsDirectory: drawings, baselineDirectory: baseline)
        let ledger = ProInkStore.loadLedger(in: drawings, notebookId: "nb", page: 0)
        XCTAssertTrue(ledger.foreignTombstones.isEmpty)
        XCTAssertTrue(ledger.retired.isEmpty)
        XCTAssertEqual(ledger.schema, 2, "帳本版本不能被清掉，否則整本筆記會被當成升級前再重寫一次")
        XCTAssertTrue(ProInkStore.loadSuppressed(in: drawings, notebookId: "nb", page: 0).isEmpty)
        XCTAssertTrue(ErasedInkLedger.load(in: baseline, notebookId: "nb", page: 0).isEmpty)
    }
}

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

    func testErasingAnOwnStrokeRetiresItsIdAndRedrawingItUsesANewOne() {
        let both = PKDrawing(strokes: [stroke(at: 10), stroke(at: 100)])
        let before = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: both, prevOwn: nil, current: both, others: PKDrawing(),
            resolveForeign: noForeign)
        // 擦掉第二筆。
        let one = PKDrawing(strokes: [both.strokes[0]])
        var ledger = ProInkLedger()
        let erased = PKInkSync.plan(
            ledger: ledger, ownNow: one, prevOwn: both, current: one, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertEqual(erased.pkRetiredOwn.map(\.id), [before.ids[1]], "擦掉的那一筆要寫墓碑，用的是它當初匯出的身分")
        XCTAssertEqual(erased.ids, [before.ids[0]])

        // 墓碑上傳之後又把同一條線畫回來（復原）：身分必須換新，已寫出的墓碑撤不掉。
        ledger.pkRetiredOwn = erased.pkRetiredOwn
        ledger.pkGen = erased.pkGen
        let redrawn = PKInkSync.plan(
            ledger: ledger, ownNow: both, prevOwn: one, current: both, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertNotEqual(redrawn.ids[1], before.ids[1])
        XCTAssertEqual(redrawn.ids[0], before.ids[0], "沒動過的那一筆身分不變")
    }

    func testIdenticalStrokesAreRetiredFromTheEnd() {
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
        XCTAssertEqual(plan.ids, [ids[0]], "留下來的那一筆身分不能變，不然會被墓碑誤殺")
        XCTAssertEqual(plan.pkRetiredOwn.map(\.id), [ids[1]])
    }

    func testWithoutAPreviousSnapshotNothingIsInferredAsErased() {
        // 升級前沒有「上次匯出」的快照。把它當成空的，整頁都會被當成剛擦掉。
        let a = PKDrawing(strokes: [stroke(at: 10)])
        let plan = PKInkSync.plan(
            ledger: ProInkLedger(), ownNow: a, prevOwn: nil, current: a, others: PKDrawing(),
            resolveForeign: noForeign)
        XCTAssertTrue(plan.pkRetiredOwn.isEmpty)
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

    func testPaddingKeepsARewrittenStrokeFileFromShrinking() throws {
        // 同步只傳「變大」的檔案：重寫之後的筆畫檔不能比重寫前小，否則擦掉的東西永遠傳不出去。
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-pad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let package = dir.appendingPathComponent("p.padnote")
        let doc = NotebookDocument(title: "P", pageCount: 1)
        let device: UInt32 = 0x0A0A
        let big = PKDrawing(strokes: (0 ..< 8).map { stroke(at: CGFloat($0) * 40) })
        try NotebookPackageBridge.export(document: doc, drawings: [big], to: package, deviceId: device)

        func inkBytes() -> UInt64 {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: package.appendingPathComponent("ink"), includingPropertiesForKeys: [.fileSizeKey])) ?? []
            return files.reduce(0) { $0 + UInt64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        }
        let before = inkBytes()
        // 擦掉大部分：不補位的話檔案會小很多。
        let small = PKDrawing(strokes: [big.strokes[0]])
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: [small], to: package, deviceId: device)
        XCTAssertGreaterThanOrEqual(inkBytes(), before, "重寫之後的筆畫檔不能比重寫前小")
        // 升級後第一次匯出：內容身分整批換了，大小要「至少多一點」才會被傳出去。
        let sizeNow = inkBytes()
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: [small], to: package, deviceId: device, growInkFiles: true)
        XCTAssertGreaterThan(inkBytes(), sizeNow)
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: 0x0B0B)
        XCTAssertEqual(imported.drawings.first?.strokes.count, 1, "補位不能影響內容")
    }
}

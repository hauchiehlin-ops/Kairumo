//
//  CollabSyncTests.swift
//  KairumoTests
//
//  即時協同（docs/plans/realtime-collaboration.md §10）：同一組操作不論以什麼順序、
//  重複幾次套用，每一台的結果都相同。協定積木的測試向量與 Android 端
//  `CollabProtocolTest` 完全相同 —— 兩邊算出不同的答案，就是兩個人看到不同的筆記。
//

import PencilKit
import XCTest
@testable import Kairumo

/// 一台參與者：自己的筆記本、自己的合併狀態、自己的時鐘。
private final class Replica {
    var doc: NotebookDocument
    let sync = CollabObjectSync()
    let user: String
    var clock: UInt64 = 0

    init(_ doc: NotebookDocument, user: String) {
        self.doc = doc
        self.user = user
        sync.reset(to: doc)
    }

    struct Message {
        let patches: [ObjectPatch]
        let textEdits: [(id: String, old: String, new: String)]
        let stamp: LamportStamp
    }

    func edit(_ change: (inout NotebookDocument) -> Void) -> Message {
        change(&doc)
        clock += 1
        let stamp = LamportStamp(lamport: clock, user: user)
        let out = sync.outgoing(for: doc, stamp: stamp)
        return Message(patches: out.patches, textEdits: out.textEdits, stamp: stamp)
    }

    func receive(_ message: Message) {
        clock = max(clock, message.stamp.lamport)
        for patch in message.patches { sync.apply(patch, stamp: message.stamp, to: &doc) }
        // 頁面：依合併後的順序調整（App 裡由編輯器透過 NotebookStore 做，這裡直接排）。
        let order = sync.desiredPageOrder()
        if !order.isEmpty, order != doc.pageIds {
            doc.pageIds = order
            doc.pageCount = order.count
        }
        sync.retryDeferred(into: &doc)
        let stacking = sync.desiredStacking()
        CollabCanonical.writeStacking(orders: stacking.orders, under: stacking.under, locked: stacking.locked, into: &doc)
        sync.refreshShadow(from: doc)
    }

    var state: CanvasObjectState { CanvasObjectState(doc) }
}

final class CollabSyncTests: XCTestCase {

    private func base() -> NotebookDocument {
        var doc = NotebookDocument(title: "t")
        doc.pageIds = ["p1"]
        doc.attachments = [NoteImageAttachment(id: "0d0f6f9e-1111-4000-8000-000000000001", fileName: "a.png", x: 10, y: 10)]
        doc.textAttachments = [NoteTextAttachment(id: "0d0f6f9e-2222-4000-8000-000000000002", text: "hi")]
        return doc
    }

    private func image(_ r: Replica) -> NoteImageAttachment? { r.doc.attachments?.first }

    // MARK: - 物件收斂

    func testConcurrentEditsOfTheSameFieldConverge() {
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        let ma = a.edit { $0.attachments?[0].x = 100 }
        let mb = b.edit { $0.attachments?[0].x = 200 }
        a.receive(mb)
        b.receive(ma)
        XCTAssertEqual(a.state, b.state)
        XCTAssertEqual(image(a)?.x, 200, "時鐘相同時以使用者 id 決定（B > A）")
    }

    func testConcurrentEditsOfDifferentFieldsAreBothKept() {
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        let ma = a.edit { $0.attachments?[0].x = 300 }
        let mb = b.edit { $0.attachments?[0].borderColorHex = "#FF0000" }
        a.receive(mb)
        b.receive(ma)
        XCTAssertEqual(a.state, b.state)
        XCTAssertEqual(image(a)?.x, 300)
        XCTAssertEqual(image(a)?.borderColorHex, "#FF0000")
    }

    func testFieldsAreTheSharedPackageFormat() {
        // 線上格式 = 套件格式：外觀鍵以 `a.` 開頭，與 Android 讀寫的同一組。
        let a = Replica(base(), user: "A")
        let m = a.edit { $0.attachments?[0].borderColorHex = "#00FF00" }
        let fields = m.patches.first { $0.type == "image" }?.fields ?? [:]
        XCTAssertEqual(fields["a.image.borderColorHex"] as? String, "#00FF00")
        XCTAssertNil(fields["borderColorHex"], "不是 Apple 自己的記憶體結構")
    }

    func testAnyDeliveryOrderGivesTheSameResult() {
        let r = [Replica(base(), user: "A"), Replica(base(), user: "B"), Replica(base(), user: "C")]
        let messages = [
            r[0].edit { $0.attachments?[0].x = 11 },
            r[1].edit { $0.attachments?[0].y = 22; $0.attachments?[0].x = 12 },
            r[2].edit { $0.textAttachments = [] },
        ]
        r[0].receive(messages[2]); r[0].receive(messages[1]); r[0].receive(messages[1])
        r[1].receive(messages[0]); r[1].receive(messages[2])
        r[2].receive(messages[1]); r[2].receive(messages[0]); r[2].receive(messages[2])
        XCTAssertEqual(r[0].state, r[1].state)
        XCTAssertEqual(r[1].state, r[2].state)
    }

    func testAnOlderEditDoesNotResurrectADeletedObject() {
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        let old = b.edit { $0.attachments?[0].x = 5 }
        a.receive(old)
        let delete = a.edit { $0.attachments = [] }
        b.receive(delete)
        a.receive(old)
        XCTAssertNil(image(a))
        XCTAssertEqual(a.state, b.state)
    }

    func testNewObjectsArriveComplete() {
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        let m = a.edit {
            $0.tableAttachments = [NoteTableAttachment(id: "0d0f6f9e-3333-4000-8000-000000000003",
                                                       x: 40, y: 50, rows: 2, cols: 3, cells: ["1", "2", "3", "4", "5", "6"])]
        }
        b.receive(m)
        XCTAssertEqual(b.doc.tableAttachments?.first?.cols, 3)
        XCTAssertEqual(b.doc.tableAttachments?.first?.cells.last, "6")
        XCTAssertEqual(b.doc.tableAttachments?.first?.x, 40)
    }

    func testTextContentOfAnExistingBoxGoesThroughTheCRDTNotLWW() {
        // 內容以字元合併（§8.3）；欄位修改裡不帶 `text`。
        let a = Replica(base(), user: "A")
        let m = a.edit { $0.textAttachments?[0].text = "hi there" }
        XCTAssertFalse(m.patches.contains { $0.fields["text"] != nil })
        XCTAssertEqual(m.textEdits.first?.old, "hi")
        XCTAssertEqual(m.textEdits.first?.new, "hi there")
    }

    func testANewTextBoxCarriesItsText() {
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        b.receive(a.edit {
            $0.textAttachments?.append(NoteTextAttachment(id: "0d0f6f9e-4444-4000-8000-000000000004", text: "new box"))
        })
        XCTAssertTrue(b.doc.textAttachments?.contains { $0.text == "new box" } == true)
    }

    // MARK: - 頁面（§8.4）

    func testAPageAddedByOneIsAddedForAll() {
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        let m = a.edit { $0.pageIds = ["p1", "p2"]; $0.pageCount = 2 }
        b.receive(m)
        XCTAssertEqual(b.doc.pageIds, ["p1", "p2"])
    }

    func testConcurrentInsertsAtTheSameSpotKeepBothInTheSameOrder() {
        var start = base(); start.pageIds = ["p1", "p9"]; start.pageCount = 2
        let a = Replica(start, user: "A"), b = Replica(start, user: "B")
        let ma = a.edit { $0.pageIds = ["p1", "pa", "p9"]; $0.pageCount = 3 }
        let mb = b.edit { $0.pageIds = ["p1", "pb", "p9"]; $0.pageCount = 3 }
        a.receive(mb)
        b.receive(ma)
        XCTAssertEqual(a.doc.pageIds, b.doc.pageIds)
        XCTAssertEqual(Set(a.doc.pageIds ?? []), ["p1", "pa", "pb", "p9"])
        XCTAssertEqual(a.doc.pageIds?.first, "p1")
        XCTAssertEqual(a.doc.pageIds?.last, "p9")
    }

    func testMovingAPageOnlyChangesThatPage() {
        var start = base(); start.pageIds = ["p1", "p2", "p3"]; start.pageCount = 3
        let a = Replica(start, user: "A"), b = Replica(start, user: "B")
        let m = a.edit { $0.pageIds = ["p2", "p3", "p1"] }
        XCTAssertEqual(m.patches.filter { $0.type == "page" }.map(\.id), ["p1"], "只有搬動的那一頁換排序鍵")
        b.receive(m)
        XCTAssertEqual(b.doc.pageIds, ["p2", "p3", "p1"])
    }

    func testConcurrentMovesOfTheSamePageConverge() {
        var start = base(); start.pageIds = ["p1", "p2", "p3"]; start.pageCount = 3
        let a = Replica(start, user: "A"), b = Replica(start, user: "B")
        let ma = a.edit { $0.pageIds = ["p2", "p3", "p1"] }
        let mb = b.edit { $0.pageIds = ["p2", "p1", "p3"] }
        a.receive(mb)
        b.receive(ma)
        XCTAssertEqual(a.doc.pageIds, b.doc.pageIds)
    }

    func testDeletingAPageRemovesItEverywhere() {
        var start = base(); start.pageIds = ["p1", "p2"]; start.pageCount = 2
        let a = Replica(start, user: "A"), b = Replica(start, user: "B")
        b.receive(a.edit { $0.pageIds = ["p1"]; $0.pageCount = 1 })
        XCTAssertEqual(b.doc.pageIds, ["p1"])
    }

    func testAnObjectOnAPageThatHasNotArrivedYetWaitsForIt() {
        // 物件比它的頁先到：先留著，頁面到了再放上去。
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        let pageMsg = a.edit { $0.pageIds = ["p1", "p2"]; $0.pageCount = 2 }
        let objMsg = a.edit {
            $0.textAttachments?.append(NoteTextAttachment(id: "0d0f6f9e-5555-4000-8000-000000000005", pageIndex: 1, text: "p2 box"))
        }
        b.receive(objMsg)
        XCTAssertFalse(b.doc.textAttachments?.contains { $0.text == "p2 box" } == true)
        // 擱著的物件本機還沒有，但那不是「被刪除」：下一次本機修改不能把它當成刪除送出去。
        let next = b.edit { _ in }
        XCTAssertFalse(next.patches.contains { $0.key == objMsg.patches.first { $0.type == "text" }?.key })
        b.receive(pageMsg)
        XCTAssertEqual(b.doc.textAttachments?.first { $0.text == "p2 box" }?.pageIndex, 1)
    }

    // MARK: - 第四階段：堆疊順序、整份狀態

    private let idA = "0d0f6f9e-1111-4000-8000-00000000000a"
    private let idB = "0d0f6f9e-1111-4000-8000-00000000000b"
    private let idC = "0d0f6f9e-1111-4000-8000-00000000000c"

    private func stacked() -> NotebookDocument {
        var doc = NotebookDocument(title: "t")
        doc.pageIds = ["p1"]
        doc.attachments = [idA, idB, idC].map { NoteImageAttachment(id: $0, fileName: "\($0).png") }
        doc.objectOrderByPage = ["0": [idA, idB, idC]]
        return doc
    }

    func testReorderingDifferentObjectsAtTheSameTimeKeepsBoth() {
        let a = Replica(stacked(), user: "A"), b = Replica(stacked(), user: "B")
        let ma = a.edit { $0.objectOrderByPage = ["0": [self.idB, self.idC, self.idA]] } // A 把 a 移到最上層
        let mb = b.edit { $0.objectOrderByPage = ["0": [self.idA, self.idC, self.idB]] } // B 把 b 移到最上層
        a.receive(mb)
        b.receive(ma)
        XCTAssertEqual(a.doc.objectOrderByPage, b.doc.objectOrderByPage)
        let order = a.doc.objectOrderByPage?["0"] ?? []
        XCTAssertEqual(order.first, idC, "兩個人的動作都留下：c 在最下")
        XCTAssertEqual(Set(order.dropFirst()), [idA, idB])
    }

    func testMovingOneObjectOnlySendsThatObject() {
        let a = Replica(stacked(), user: "A")
        let m = a.edit { $0.objectOrderByPage = ["0": [self.idA, self.idC, self.idB]] }
        XCTAssertEqual(m.patches.map(\.key), ["image:\(idB)"])
    }

    func testLockingDifferentObjectsAtTheSameTimeKeepsBoth() {
        // 「鎖定在畫布上」與 `under` 一樣是每個物件自己的欄位：兩人各鎖一個，兩個都鎖住。
        let a = Replica(stacked(), user: "A"), b = Replica(stacked(), user: "B")
        let ma = a.edit { $0.setLockedObjectIds([self.idA], forPage: 0) }
        let mb = b.edit { $0.setLockedObjectIds([self.idB], forPage: 0) }
        XCTAssertEqual(ma.patches.map(\.key), ["image:\(idA)"])
        XCTAssertEqual(ma.patches.first?.fields["locked"] as? Bool, true)
        a.receive(mb)
        b.receive(ma)
        XCTAssertEqual(a.doc.lockedObjectIdsByPage, ["0": [idA, idB]])
        XCTAssertEqual(a.doc.lockedObjectIdsByPage, b.doc.lockedObjectIdsByPage)
        // 解除鎖定也傳得過去。
        b.receive(a.edit { $0.setLockedObjectIds([self.idB], forPage: 0) })
        XCTAssertEqual(b.doc.lockedObjectIdsByPage, ["0": [idB]])
    }

    func testAJoinerAdoptsTheRoomsStateAndPushesWhatOnlyItHas() {
        let room = Replica(base(), user: "R")
        room.receive(room.edit { $0.attachments?[0].x = 42 })
        var stale = base()
        stale.attachments?[0].x = 10
        stale.attachments?.append(NoteImageAttachment(id: "0d0f6f9e-9999-4000-8000-000000000009", fileName: "mine.png"))
        let joiner = Replica(stale, user: "J")
        _ = joiner.sync.applySnapshot(room.sync.snapshot(), to: &joiner.doc)
        XCTAssertEqual(image(joiner)?.x, 42, "房間裡的內容優先於加入者過期的那一份")
        let localOnly = joiner.sync.liveKeys.subtracting(room.sync.liveKeys).filter { !$0.hasPrefix("meta:") }
        XCTAssertEqual(localOnly, ["image:0d0f6f9e-9999-4000-8000-000000000009"])
        joiner.sync.forget(localOnly)
        let push = joiner.edit { _ in }
        XCTAssertTrue(push.patches.contains { $0.key == localOnly.first && ($0.fields[ObjectPatch.deletedField] as? Bool) == false })
    }

    func testTheRoomsBaselineLosesToARealEdit() {
        let joiner = Replica(base(), user: "J")
        joiner.receive(joiner.edit { $0.attachments?[0].x = 7 })
        let room = Replica(base(), user: "R")
        _ = joiner.sync.applySnapshot(room.sync.snapshot(), to: &joiner.doc)
        XCTAssertEqual(image(joiner)?.x, 7)
    }

    func testADifferentTextIsReportedForRebase() {
        let room = Replica(base(), user: "R")
        var stale = base()
        stale.textAttachments?[0].text = "old"
        let joiner = Replica(stale, user: "J")
        let result = joiner.sync.applySnapshot(room.sync.snapshot(), to: &joiner.doc)
        XCTAssertEqual(result.textOverrides.first?.text, "hi")
    }

    func testSnapshotEntriesRoundTripThroughJSON() throws {
        let room = Replica(base(), user: "R")
        room.receive(room.edit { $0.attachments?[0].x = 3 })
        let entries = room.sync.snapshot()
        let data = try JSONSerialization.data(withJSONObject: entries.map(\.json))
        let back = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]]).compactMap(SnapshotEntry.init(json:))
        XCTAssertEqual(Set(back.map(\.key)), Set(entries.map(\.key)))
    }

    // MARK: - 復原

    func testUndoKeepsWhatOthersChangedAfterwards() {
        let a = Replica(base(), user: "A"), b = Replica(base(), user: "B")
        let before = a.doc
        let ma = a.edit { $0.attachments?[0].x = 50; $0.attachments?[0].borderColorHex = "#123456" }
        b.receive(ma)
        a.receive(b.edit { $0.attachments?[0].x = 80 })
        var target = before
        XCTAssertTrue(a.sync.protectRemoteEdits(target: &target, current: a.doc, me: "A"))
        XCTAssertEqual(target.attachments?.first?.x, 80, "別人之後改的欄位保留")
        XCTAssertNil(target.attachments?.first?.borderColorHex, "自己改的欄位照樣復原")
    }

    // MARK: - 筆跡

    private func stroke(_ x: CGFloat) -> PKStroke {
        let points = (0..<4).map {
            PKStrokePoint(location: CGPoint(x: x + CGFloat($0) * 5, y: 20), timeOffset: TimeInterval($0) * 0.01,
                          size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    func testStrokesTravelInTheCoreFormat() {
        let json = CollabStroke.encode(stroke(10), id: "w1")
        XCTAssertEqual(json["id"] as? String, "w1")
        XCTAssertEqual((json["points"] as? [Double])?.count, 4 * 7, "每點 7 個數字攤平")
        let back = CollabStroke.decode(json)
        XCTAssertEqual(back?.id, "w1")
        XCTAssertEqual(back?.stroke.path.count, 4)
    }

    func testRemoteStrokeIdsMapBackToLocalStrokes() {
        let ledger = CollabInkLedger()
        let s = stroke(10)
        ledger.remember(wire: "android-42", local: CollabInk.strokeId(s))
        XCTAssertEqual(ledger.wireId(for: s), "android-42", "擦掉別台的筆畫時送回對方給的 id")
        XCTAssertEqual(ledger.localId(forWire: "android-42"), CollabInk.strokeId(s))
    }

    func testConcurrentStrokesAreBothKept() {
        let a = stroke(10), b = stroke(100)
        let pageA = CollabInk.adding([b], to: PKDrawing(strokes: [a]))
        let pageB = CollabInk.adding([a], to: PKDrawing(strokes: [b]))
        XCTAssertEqual(Set(CollabInk.ids(of: pageA)), Set(CollabInk.ids(of: pageB)))
    }
}

/// 協定積木：與 Android `CollabProtocolTest` 共用同一組測試向量。
final class CollabProtocolTests: XCTestCase {

    // MARK: 文字 CRDT

    private func exchange(_ base: String, _ editA: String, _ editB: String) -> (String, String) {
        let a = CollabText(base: base, site: "A"), b = CollabText(base: base, site: "B")
        let opsA = a.localEdit(from: base, to: editA)
        let opsB = b.localEdit(from: base, to: editB)
        opsB.forEach { a.apply($0) }
        opsA.forEach { b.apply($0) }
        return (a.text, b.text)
    }

    func testVectorConcurrentInsertAtTheSameSpot() {
        let (a, b) = exchange("abc", "abXc", "abYc")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, "abYXc")
    }

    func testVectorTypingAtTheSameSpotDoesNotInterleave() {
        // 兩人同時在開頭打兩個字：各自的字連在一起，不會交錯成 "x1y2"。
        let (a, b) = exchange("ab", "12ab", "xyab")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, "xy12ab")
    }

    func testVectorConcurrentDeleteAndInsert() {
        let (a, b) = exchange("hello", "helo", "hello!")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, "helo!")
    }

    func testVectorBothDeleteTheSameCharacter() {
        let (a, b) = exchange("abc", "ac", "ac")
        XCTAssertEqual(a, "ac")
        XCTAssertEqual(b, "ac")
    }

    func testOutOfOrderOpsWaitForTheirAnchor() {
        let a = CollabText(base: "", site: "A"), b = CollabText(base: "", site: "B")
        let ops = a.localEdit(from: "", to: "hey")
        for op in ops.reversed() { b.apply(op) } // 反序到達
        XCTAssertEqual(b.text, "hey")
        XCTAssertFalse(b.hasPending)
    }

    func testOpsRoundTripThroughJSON() {
        let a = CollabText(base: "x", site: "A")
        for op in a.localEdit(from: "x", to: "xy") + a.localEdit(from: "xy", to: "y") {
            XCTAssertEqual(CollabText.Op(json: op.json), op)
        }
    }

    // MARK: 分數索引

    func testVectorFractionalKeys() {
        XCTAssertEqual(FractionalIndex.initialKeys(3), ["V", "l", "t"])
        XCTAssertEqual(FractionalIndex.between("V", "l"), "d")
        XCTAssertEqual(FractionalIndex.between("", "V"), "G")
        XCTAssertEqual(FractionalIndex.between("V", "W"), "VV")
    }

    func testKeysBetweenAreAlwaysStrictlyBetween() {
        var low = "V", high = "W"
        for _ in 0..<40 {
            let mid = FractionalIndex.between(low, high)
            XCTAssertTrue(low < mid && mid < high, "\(low) < \(mid) < \(high)")
            high = mid
        }
        _ = low
        low = ""
    }

    // MARK: 攤平

    func testFlattenRoundTrip() {
        let json: [String: Any] = ["object": "image", "image": ["width": 120.0, "fileName": "a.png"], "runs": [1, 2]]
        let flat = CollabJSON.flatten(json, prefix: "a.")
        XCTAssertEqual(flat["a.image.width"] as? Double, 120)
        XCTAssertNotNil(flat["a.runs"] as? [Int], "陣列是葉子")
        let back = CollabJSON.unflatten(flat, prefix: "a.")
        XCTAssertEqual((back["image"] as? [String: Any])?["fileName"] as? String, "a.png")
    }

    func testRunAnchorsFollowTheirCharacters() {
        // 與 Android 端 `runAnchorsFollowTheirCharactersUnderConcurrentTyping` 同一個情境。
        let a = CollabText(base: "hello world", site: "A")
        let b = CollabText(base: "hello world", site: "B")
        let anchors = CollabRunAnchors.anchors([(start: 6, length: 5)], in: a) // A 把 "world" 設成粗體
        _ = b.localEdit(from: "hello world", to: "XXhello world")             // 同時 B 在最前面打了兩個字
        let resolved = CollabRunAnchors.resolve(anchors, in: b)
        XCTAssertEqual(resolved.first??.start, 8)
        XCTAssertEqual(resolved.first??.length, 5)
    }

    func testADeletedAnchorMovesInward() {
        let a = CollabText(base: "abcdef", site: "A")
        let anchors = CollabRunAnchors.anchors([(start: 1, length: 3)], in: a)
        _ = a.localEdit(from: "abcdef", to: "acdef")
        XCTAssertEqual(CollabRunAnchors.resolve(anchors, in: a).first??.start, 1)
        XCTAssertEqual(CollabRunAnchors.resolve(anchors, in: a).first??.length, 2)
        _ = a.localEdit(from: "acdef", to: "aef")
        XCTAssertNil(CollabRunAnchors.resolve(anchors, in: a).first ?? nil)
    }

    func testBaseHashMatchesAndroid() {
        // 與 Android 端 `CollabProtocolTest` 同一個向量：SHA-256("hello") 的前 8 個位元組。
        XCTAssertEqual(CollabText.hash("hello"), "2cf24dba5fb0a30e")
    }

    func testToolNamesMatchAndroid() {
        XCTAssertEqual(CollabStroke.toolName(.fountainPen), "fountain_pen")
        XCTAssertEqual(CollabStroke.tool(named: "oil_paint"), .oilPaint)
    }
}

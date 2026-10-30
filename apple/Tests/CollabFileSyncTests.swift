//
//  CollabFileSyncTests.swift
//  KairumoTests
//
//  即時協同與背景檔案同步同時運作：兩邊不能互相干擾。
//
//  - 協同中，檔案同步不匯入開著的那一本（照常上傳），離開房間再補一次匯入。
//  - 同一筆協同筆畫在每一台的套件裡是同一個 id（送出者的），核心才能去重。
//  - 協同擦掉的筆畫，檔案同步把還有它的舊檔帶回來時不會復活。
//

import PencilKit
import XCTest
@testable import Kairumo

@MainActor
final class CollabFileSyncTests: XCTestCase {
    private var workDir: URL!
    private var cloud: URL!
    private var alice: FakeStore!
    private var bob: FakeStore!
    private var carol: FakeStore!
    private let aliceId: UInt32 = 0x0A11CE
    private let bobId: UInt32 = 0x0B0B
    private let carolId: UInt32 = 0x0CA401

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("kairumo-collab-sync-\(UUID().uuidString)", isDirectory: true)
        cloud = workDir.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        alice = FakeStore(root: workDir.appendingPathComponent("Alice", isDirectory: true))
        bob = FakeStore(root: workDir.appendingPathComponent("Bob", isDirectory: true))
        carol = FakeStore(root: workDir.appendingPathComponent("Carol", isDirectory: true))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func stroke(at x: CGFloat) -> PKStroke {
        let points = (0..<6).map { i in
            PKStrokePoint(location: CGPoint(x: x + CGFloat(i) * 3, y: 120 + CGFloat(i * i)),
                          timeOffset: Double(i) * 0.01, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 1, altitude: 1)
        }
        return PKStroke(ink: PKInk(.pen, color: .black),
                        path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
    }

    private func sync(_ store: FakeStore, _ deviceId: UInt32) async {
        _ = await NotebookSyncCoordinator.run(store: store, folder: cloud, deviceId: deviceId)
    }

    private func strokes(_ store: FakeStore, _ note: NotebookDocument) -> Int {
        store.syncLoadDrawing(notebookId: note.id, pageIndex: 0).strokes.count
    }

    /// 某台的套件裡這一頁看得到的筆畫 id。
    private func packageIds(_ store: FakeStore, _ note: NotebookDocument, _ deviceId: UInt32) throws -> [String] {
        let path = store.syncPackagesDirectory.appending(path: "\(note.id.lowercased()).padnote").path
        let session = try PadnoteSession.openExisting(path: path, deviceId: deviceId)
        let page = try XCTUnwrap(try session.firstPageId())
        return try session.visibleStrokeDetails(pageId: page).map { $0.id.lowercased() }
    }

    /// 收到一筆協同筆畫：經過線上格式，記下送出者的 id，畫進這一頁。
    private func receive(_ json: [String: Any], on store: FakeStore, _ note: NotebookDocument,
                         keeping existing: [PKStroke] = []) throws -> PKStroke {
        let decoded = try XCTUnwrap(CollabStroke.decode(json))
        CollabInkPersistence.remoteAdded([(decoded.stroke, CollabStroke.coreId(json))],
                                         in: store.syncBaselineDirectory, notebookId: note.id, page: 0)
        store.syncSaveDrawing(notebookId: note.id, pageIndex: 0,
                              drawing: PKDrawing(strokes: existing + [decoded.stroke]))
        return decoded.stroke
    }

    // MARK: - 協同中不匯入

    func testTheHoldOnlyDefersWhileCollaborating() {
        let id = "B5A2F7F4-0000-4000-8000-000000000001"
        XCTAssertFalse(CollabImportHold.deferIfHeld(id), "不在協同中照常匯入")
        CollabImportHold.hold(id)
        XCTAssertTrue(CollabImportHold.deferIfHeld(id.lowercased()))
        XCTAssertTrue(CollabImportHold.release(id), "協同期間略過了匯入，離開時要補")
        XCTAssertFalse(CollabImportHold.release(id), "補過一次就不再欠")
        XCTAssertFalse(CollabImportHold.deferIfHeld(id))
    }

    func testAFileSyncWhileCollaboratingDoesNotReplaceTheRoomStateAndCatchesUpAfterLeaving() async throws {
        let note = NotebookDocument(title: "協同", pageCount: 1)
        let a = stroke(at: 10), b = stroke(at: 120), c = stroke(at: 240)
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        XCTAssertEqual(strokes(bob, note), 1)

        // Bob 進了房間，在房間裡寫了 b；不在房間裡的 Alice 寫了 c，經檔案同步送出。
        bob.heldNotebookIds = [note.id.lowercased()]
        bob.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        let roomTitle = "房間裡改的標題"
        bob.documents[0].title = roomTitle
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, c]))
        await sync(alice, aliceId)
        await sync(bob, bobId)

        XCTAssertEqual(bob.syncLoadDrawing(notebookId: note.id, pageIndex: 0).strokes.map { StrokeDelta.Identity($0) },
                       [a, b].map { StrokeDelta.Identity($0) }, "協同中的工作副本被檔案同步換掉了")
        XCTAssertEqual(bob.documents.first?.title, roomTitle)
        XCTAssertEqual(bob.deferredImports, [note.id.lowercased()])

        // 自己的檔照常上傳：Alice 收得到 Bob 在房間裡寫的。
        await sync(alice, aliceId)
        XCTAssertEqual(strokes(alice, note), 3)

        // 離開房間：補一次匯入，Alice 的 c 進來，房間裡寫的 b 還在。
        bob.heldNotebookIds = []
        let caughtUp = await NotebookSyncCoordinator.importReceived(store: bob, deviceId: bobId, notebookId: note.id)
        XCTAssertTrue(caughtUp)
        XCTAssertEqual(strokes(bob, note), 3)
    }

    // MARK: - 同一筆協同筆畫只有一個 id

    func testAStrokeFromAnAndroidPeerKeepsItsIdInThisPackage() async throws {
        // Android 的線上 id 就是它套件裡的核心 id。Bob 照內容另算一個的話，
        // Android 的筆畫檔同步過來之後，同一條線在套件裡有兩份。
        let note = NotebookDocument(title: "跨平台", pageCount: 1)
        bob.documents = [note]
        await sync(bob, bobId)
        let s = stroke(at: 60)
        let androidId = UUID().uuidString.lowercased()

        // Android 那台把這一筆寫進自己的筆畫檔（同一個套件目錄 = 已經同步過來）。
        let path = bob.syncPackagesDirectory.appending(path: "\(note.id.lowercased()).padnote").path
        let android = try PadnoteSession.openExisting(path: path, deviceId: 0xA0D0)
        let page = try XCTUnwrap(try android.firstPageId())
        let draft = InkInterop.draft(from: s)
        try android.addStrokeDraftedWithId(pageId: page, strokeId: androidId, tool: draft.tool,
                                           colorRgba: draft.colorRgba, baseWidth: draft.baseWidth,
                                           points: draft.points, layer: 0, lineType: 0)

        // 同一筆經協同送到 Bob（Android 不帶 cid，線上 id 就是核心 id）。
        _ = try receive(CollabStroke.encode(s, id: androidId), on: bob, note)
        await sync(bob, bobId)

        XCTAssertEqual(try packageIds(bob, note, bobId), [androidId], "同一條線在套件裡有兩個 id")
        XCTAssertEqual(strokes(bob, note), 1)
    }

    func testIncrementalWritesUseThePinnedCollabId() throws {
        // 編輯器的增量寫入（`CoreInkFlush`）與完整匯出用同一個 id。
        let note = NotebookDocument(title: "增量", pageCount: 1)
        let s = stroke(at: 30)
        let wireId = UUID().uuidString.lowercased()
        CollabInkPersistence.remoteAdded([(s, wireId)], in: bob.syncBaselineDirectory, notebookId: note.id, page: 0)
        let package = bob.syncPackagesDirectory.appending(path: "inc.padnote")
        _ = CoreInkFlush.apply(
            [.init(page: 0, drawing: PKDrawing(strokes: [s]),
                   drawingFileURL: bob.root.appending(path: "inc_p0.drawing"), cachedBaseline: PKDrawing())],
            document: note, package: package, baselineDirectory: bob.syncBaselineDirectory, deviceId: bobId)
        let session = try PadnoteSession.openExisting(path: package.path, deviceId: bobId)
        let page = try XCTUnwrap(try session.firstPageId())
        XCTAssertEqual(try session.visibleStrokeDetails(pageId: page).map { $0.id.lowercased() }, [wireId])
    }

    func testAnAppleSenderTellsReceiversWhichIdToUse() async throws {
        // Apple 的線上 id 是內容雜湊（不是核心 id），所以另外附上套件裡的 id（`cid`）。
        let note = NotebookDocument(title: "Apple 對 Apple", pageCount: 1)
        let s = stroke(at: 90)
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [s]))
        let cid = CollabInkIds.coreIds(of: [s], pinned: [:])[0]
        let json = CollabStroke.encode(s, id: CollabInk.strokeId(s), coreId: cid)
        XCTAssertEqual(CollabStroke.coreId(json), cid)

        await sync(alice, aliceId)
        await sync(bob, bobId)
        bob.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing())
        _ = try receive(json, on: bob, note)
        await sync(bob, bobId)
        await sync(alice, aliceId)

        XCTAssertEqual(try packageIds(alice, note, aliceId), [cid])
        XCTAssertEqual(try packageIds(bob, note, bobId), [cid])
    }

    // MARK: - 協同擦除不會被檔案同步帶回來

    func testACollabEraseIsNotUndoneByAnOldFileComingBack() async throws {
        // Bob 寫了 b；Carol 在房間裡收到 b、寫進了自己的筆畫檔，之後離線。
        // Alice 在房間裡擦掉 b，Bob 收到擦除。b 是 Bob 自己的筆畫 —— 自己擦掉的不寫墓碑 ——
        // 所以 Carol 那份還有 b 的舊檔同步過來時，沒有任何東西擋得住它，除非 Bob 記得自己（被協同）擦掉了它。
        let note = NotebookDocument(title: "擦除", pageCount: 1)
        let a = stroke(at: 15), b = stroke(at: 160)
        bob.documents = [note]
        bob.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        let cores = CollabInkIds.coreIds(of: [a, b], pinned: [:])
        let bJson = CollabStroke.encode(b, id: CollabInk.strokeId(b), coreId: cores[1])

        carol.documents = [note]
        let carolB = try receive(bJson, on: carol, note)
        await sync(bob, bobId)
        await sync(carol, carolId)
        await sync(bob, bobId)
        XCTAssertEqual(strokes(bob, note), 2)
        XCTAssertEqual(Set(try packageIds(bob, note, bobId)), Set(cores), "Carol 寫的 b 換了 id，套件裡多一份")
        _ = carolB

        // 協同擦掉 b（Carol 已經離線，她的筆畫檔裡還有 b）。
        bob.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a]))
        CollabInkPersistence.remoteRemoved([b], in: bob.syncBaselineDirectory, notebookId: note.id, page: 0)
        await sync(bob, bobId)
        await sync(bob, bobId)

        XCTAssertEqual(strokes(bob, note), 1, "協同擦掉的筆畫被檔案同步帶回來了")
    }
}

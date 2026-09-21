//
//  CloudSyncFolderTests.swift
//  KairumoTests
//
//  用使用者自己的雲端硬碟同步（決策 D3 選項 A）。
//
//  這裡不需要真的雲端：iCloud Drive 在檔案系統上就是一個資料夾，所以拿兩個
//  暫存目錄當「本機」與「雲端」測得出全部行為。真正只有實機能驗的是
//  「iCloud 有沒有把檔案傳過去」—— 那是作業系統的事，不是我們的程式碼。
//

import XCTest
@testable import Kairumo

final class CloudSyncFolderTests: XCTestCase {

    private var root: URL!
    private var localPackage: URL!
    private var cloud: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-sync-\(UUID().uuidString)", isDirectory: true)
        localPackage = root.appendingPathComponent("note.padnote", isDirectory: true)
        cloud = root.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: localPackage, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ relative: String, _ contents: String, in base: URL) throws {
        let url = base.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    private func read(_ relative: String, in base: URL) -> String? {
        (try? Data(contentsOf: base.appendingPathComponent(relative)))
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    private var remotePackage: URL { cloud.appendingPathComponent("note.padnote") }

    // MARK: - 列檔

    func testListingIsRecursive() throws {
        // 只列單層的話，doc/ops 與 ink 底下的東西 —— 也就是真正的內容 ——
        // 一個都不會被同步，而計畫看起來會是「成功，沒事要做」。
        try write("manifest.json", "{}", in: localPackage)
        try write("doc/ops/0001-aaaa.oplog", "op", in: localPackage)
        try write("ink/page-aaaa.strokes", "ink", in: localPackage)

        let paths = CloudSyncFolder.entries(in: localPackage).map(\.path).sorted()
        XCTAssertEqual(paths, ["doc/ops/0001-aaaa.oplog", "ink/page-aaaa.strokes", "manifest.json"])
    }

    func testSizesAreReported() throws {
        try write("a.oplog", "12345", in: localPackage)
        XCTAssertEqual(CloudSyncFolder.entries(in: localPackage).first?.size, 5)
    }

    // MARK: - 第一次同步

    func testFirstSyncUploadsEverything() throws {
        try write("manifest.json", "{}", in: localPackage)
        try write("doc/ops/0001-aaaa.oplog", "op", in: localPackage)

        let result = CloudSyncFolder.sync(localPackage: localPackage, into: cloud)
        XCTAssertEqual(result.uploaded.sorted(), ["doc/ops/0001-aaaa.oplog", "manifest.json"])
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(read("doc/ops/0001-aaaa.oplog", in: remotePackage), "op")
    }

    func testNewDevicePullsEverything() throws {
        // 在新裝置上接上同步資料夾就是這個情況：本機空的，雲端有東西。
        try write("manifest.json", "{}", in: remotePackage)
        try write("ink/page-bbbb.strokes", "ink", in: remotePackage)

        let result = CloudSyncFolder.sync(localPackage: localPackage, into: cloud)
        XCTAssertEqual(result.downloaded.sorted(), ["ink/page-bbbb.strokes", "manifest.json"])
        XCTAssertEqual(read("ink/page-bbbb.strokes", in: localPackage), "ink")
    }

    // MARK: - 兩台裝置

    func testBothDevicesInkFilesSurvive() throws {
        // 這是整個方案要保護的東西：兩台裝置在同一頁上寫字，兩份都要在。
        // 筆畫檔名帶 device 就是為了讓這件事成立。
        try write("ink/page-11111111.strokes", "A 的筆跡", in: localPackage)
        try write("ink/page-22222222.strokes", "B 的筆跡", in: remotePackage)

        CloudSyncFolder.sync(localPackage: localPackage, into: cloud)

        XCTAssertEqual(read("ink/page-11111111.strokes", in: localPackage), "A 的筆跡")
        XCTAssertEqual(read("ink/page-22222222.strokes", in: localPackage), "B 的筆跡")
        XCTAssertEqual(read("ink/page-11111111.strokes", in: remotePackage), "A 的筆跡")
        XCTAssertEqual(read("ink/page-22222222.strokes", in: remotePackage), "B 的筆跡")
    }

    func testTheLongerAppendOnlyFileWins() throws {
        // append-only ⇒ 較長的那份是超集。反過來覆蓋會截掉後面寫的內容。
        try write("doc/ops/0001-aaaa.oplog", "op1op2op3", in: localPackage)
        try write("doc/ops/0001-aaaa.oplog", "op1", in: remotePackage)

        CloudSyncFolder.sync(localPackage: localPackage, into: cloud)
        XCTAssertEqual(read("doc/ops/0001-aaaa.oplog", in: remotePackage), "op1op2op3")
    }

    func testTheLongerRemoteFileComesDown() throws {
        try write("doc/ops/0001-aaaa.oplog", "op1", in: localPackage)
        try write("doc/ops/0001-aaaa.oplog", "op1op2op3", in: remotePackage)

        CloudSyncFolder.sync(localPackage: localPackage, into: cloud)
        XCTAssertEqual(read("doc/ops/0001-aaaa.oplog", in: localPackage), "op1op2op3")
    }

    // MARK: - 不該默默做的事

    func testDivergingManifestIsLeftAloneOnBothSides() throws {
        // manifest.json 是整份覆寫的，不是 append-only —— 「比較長的是超集」
        // 對它不成立，所以兩邊都有時**各留各的**。
        //
        // 它的欄位只有三類：不可變（notebook_id、created_at）、權威在別處
        // （標題由 notebooks/index.json 與 oplog 的 SetTitle 決定）、
        // 以及本機專屬（encryption 的金鑰包裝參數 —— 被對面蓋掉就等於
        // 把這台裝置的解密資訊換成另一台的）。
        //
        // 舊版把它列進 needsAttention，症狀是每次同步都跳一句「需要注意」，
        // 而使用者無論做什麼都不會消失 —— 那本來就不是他能回答的問題。
        try write("manifest.json", "{\"title\":\"我改的\"}", in: localPackage)
        try write("manifest.json", "{\"title\":\"另一台改的\"}", in: remotePackage)

        let result = CloudSyncFolder.sync(localPackage: localPackage, into: cloud)
        XCTAssertTrue(result.needsAttention.isEmpty, "不該要使用者處理")
        XCTAssertEqual(read("manifest.json", in: localPackage), "{\"title\":\"我改的\"}",
                       "本機那份不該被覆蓋")
        XCTAssertEqual(read("manifest.json", in: remotePackage), "{\"title\":\"另一台改的\"}",
                       "雲端那份不該被覆蓋")
    }

    func testSyncingTwiceChangesNothingTheSecondTime() throws {
        // 自動同步會一直跑。第二次還在搬檔案，代表策略有問題。
        try write("manifest.json", "{}", in: localPackage)
        try write("doc/ops/0001-aaaa.oplog", "op", in: localPackage)

        CloudSyncFolder.sync(localPackage: localPackage, into: cloud)
        let second = CloudSyncFolder.sync(localPackage: localPackage, into: cloud)
        XCTAssertTrue(second.isNoOp, "第二次應該什麼都不用做，實得 \(second)")
    }

    func testNothingIsDeletedOnEitherSide() throws {
        // 同步只做聯集。任何「刪除」都必須是使用者的動作 ——
        // 同步程式自作主張刪檔是最不可挽回的一種 bug。
        try write("only-local.oplog", "x", in: localPackage)
        try write("only-remote.oplog", "y", in: remotePackage)

        CloudSyncFolder.sync(localPackage: localPackage, into: cloud)

        XCTAssertNotNil(read("only-local.oplog", in: localPackage))
        XCTAssertNotNil(read("only-remote.oplog", in: localPackage))
        XCTAssertNotNil(read("only-local.oplog", in: remotePackage))
        XCTAssertNotNil(read("only-remote.oplog", in: remotePackage))
    }
}

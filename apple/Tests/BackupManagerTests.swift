//
//  BackupManagerTests.swift
//  KairumoTests
//
//  個人資料備份與一鍵復原。
//
//  這一批測試釘的是「App 毀損時真的救得回來」。容器格式本身在核心有測試；
//  這裡測的是 Apple 端的決定：哪些東西進備份、設定怎麼帶、復原前有沒有安全網。
//

import XCTest
@testable import Kairumo

final class BackupManagerTests: XCTestCase {

    private var root: URL!
    private var documents: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-backup-\(UUID().uuidString)", isDirectory: true)
        documents = root.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix("kairumo.test.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func write(_ relative: String, _ contents: String) throws {
        let url = documents.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    private func read(_ relative: String) -> String? {
        (try? Data(contentsOf: documents.appendingPathComponent(relative)))
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    /// 一份看起來像真的的資料：筆記清單、資料夾結構、手繪、圖片、錄音、快照。
    private func seedEverything() throws {
        try write("notebooks_v1.json", "[{\"id\":\"a\",\"title\":\"我的筆記\"}]")
        try write("folders_v1.json", "[{\"id\":\"f1\",\"name\":\"工作\"}]")
        try write("recordings_v1.json", "[{\"id\":\"r1\"}]")
        try write("Drawings/a_p0.drawing", "筆畫位元組")
        try write("Attachments/att_1.png", "圖片位元組")
        try write("Recordings/r1.opus", "錄音位元組")
        try write("Snapshots/a/s1.snapshot", "快照位元組")
        try write("Packages/a.padnote/manifest.json", "{}")
    }

    // MARK: - 備份內容

    func testEveryKindOfUserDataIsIncluded() throws {
        // 漏掉一種的後果是使用者復原之後發現「錄音全沒了」——
        // 而他會在最需要那些錄音的時候才發現。
        try seedEverything()
        let (url, info) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(info.fileCount, 8, "八種資料都要進備份")
        XCTAssertGreaterThan(info.totalBytes, 0)
    }

    func testTheBackupFileIsSelfDescribing() throws {
        try seedEverything()
        let (url, _) = try BackupManager.createBackup(
            documentsDirectory: documents, appVersion: "9.9.9",
            date: Date(timeIntervalSince1970: 1_757_635_200))
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try BackupManager.inspect(url)
        XCTAssertEqual(info.appVersion, "9.9.9")
        XCTAssertEqual(info.createdUnixMs, 1_757_635_200_000)
        XCTAssertTrue(info.digestOk)
    }

    func testTheFilenameCarriesTheDate() throws {
        try seedEverything()
        let date = Date(timeIntervalSince1970: 1_757_635_200)
        let (url, _) = try BackupManager.createBackup(documentsDirectory: documents, date: date)
        defer { try? FileManager.default.removeItem(at: url) }

        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        XCTAssertTrue(url.lastPathComponent.contains("\(year)"))
        XCTAssertEqual(url.pathExtension, BackupManager.fileExtension)
    }

    func testTwoBackupsInTheSameSecondDoNotOverwriteEachOther() throws {
        // 只帶到秒的話兩份會同名而互相覆蓋 —— 而「復原前先備份現況」正好就
        // 發生在使用者按下復原的同一秒，結果是安全備份把要復原的那份蓋掉。
        try seedEverything()
        let date = Date(timeIntervalSince1970: 1_757_635_200)
        let (a, _) = try BackupManager.createBackup(documentsDirectory: documents, date: date)
        defer { try? FileManager.default.removeItem(at: a) }
        let (b, _) = try BackupManager.createBackup(documentsDirectory: documents, date: date)
        defer { try? FileManager.default.removeItem(at: b) }

        XCTAssertNotEqual(a.lastPathComponent, b.lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
    }

    func testTheSafetyBackupIsDistinguishable() throws {
        // 使用者在一堆備份檔裡要分得出哪一份是系統自動留的。
        try seedEverything()
        let (url, _) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = try BackupManager.restore(from: url, into: documents)
        let safety = try XCTUnwrap(outcome.safetyBackup)
        defer { try? FileManager.default.removeItem(at: safety) }
        XCTAssertTrue(safety.lastPathComponent.contains("safety"))
    }

    // MARK: - 設定

    func testOurOwnSettingsAreCarriedButOtherAppsKeysAreNot() throws {
        // 整包 UserDefaults 倒出來會夾帶系統與其他框架的東西，
        // 還原時寫回去可能造成很難追的行為。
        UserDefaults.standard.set("我的筆記", forKey: "kairumo.test.rootName")
        UserDefaults.standard.set("別碰我", forKey: "someOtherApp.setting")

        let json = BackupManager.currentSettings()
        XCTAssertTrue(json.contains("kairumo.test.rootName"))
        XCTAssertFalse(json.contains("someOtherApp.setting"))
    }

    func testSettingsComeBackAfterRestore() throws {
        try seedEverything()
        UserDefaults.standard.set("復原前", forKey: "kairumo.test.rootName")
        let (url, _) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: url) }

        UserDefaults.standard.set("被改掉了", forKey: "kairumo.test.rootName")
        _ = try BackupManager.restore(from: url, into: documents)

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "kairumo.test.rootName"), "復原前",
            "復原之後設定要回到備份當時的樣子")
    }

    // MARK: - 復原

    func testRestoreBringsBackDeletedFiles() throws {
        // 「App 毀損時一鍵復原」的實際樣子。
        try seedEverything()
        let (url, _) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: url) }

        // 模擬毀損
        try FileManager.default.removeItem(at: documents.appendingPathComponent("Drawings"))
        try FileManager.default.removeItem(at: documents.appendingPathComponent("Recordings"))
        XCTAssertNil(read("Drawings/a_p0.drawing"))

        let outcome = try BackupManager.restore(from: url, into: documents)
        XCTAssertEqual(outcome.restored, 8)
        XCTAssertTrue(outcome.corrupted.isEmpty)
        XCTAssertEqual(read("Drawings/a_p0.drawing"), "筆畫位元組")
        XCTAssertEqual(read("Recordings/r1.opus"), "錄音位元組")
    }

    func testRestoreMakesASafetyBackupFirst() throws {
        // 使用者按下復原的那一刻，手上的資料就要被覆蓋了。備份檔本身有問題的話，
        // 沒有安全網他會同時失去兩份。
        try seedEverything()
        let (url, _) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: url) }

        let outcome = try BackupManager.restore(from: url, into: documents)
        let safety = try XCTUnwrap(outcome.safetyBackup, "復原前一定要留一份現況")
        defer { try? FileManager.default.removeItem(at: safety) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: safety.path))

        let info = try BackupManager.inspect(safety)
        XCTAssertTrue(info.digestOk)
    }

    func testRestoringAJunkFileFailsClearly() throws {
        // 使用者選錯檔案是常態。要明確拒絕，而不是把半份垃圾寫進去。
        let junk = root.appendingPathComponent("photo.jpg")
        try Data("這不是備份".utf8).write(to: junk)
        XCTAssertThrowsError(try BackupManager.inspect(junk))
    }

    func testAnEmptyDocumentsDirectoryStillBacksUp() throws {
        // 新使用者第一次按備份就是這個情況，不該當掉。
        let (url, info) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(info.fileCount, 0)
        XCTAssertTrue(try BackupManager.inspect(url).digestOk)
    }

    func testABackupDoesNotIncludePreviousBackups() throws {
        // 備份檔放在 tmp 而不是 Documents，否則每備份一次檔案就翻倍。
        try seedEverything()
        let (first, _) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: first) }
        let (second, info) = try BackupManager.createBackup(documentsDirectory: documents)
        defer { try? FileManager.default.removeItem(at: second) }
        XCTAssertEqual(info.fileCount, 8, "第二份備份不該把第一份包進去")
    }
}

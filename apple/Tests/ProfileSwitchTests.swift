//
//  ProfileSwitchTests.swift
//  KairumoTests
//
//  切換引擎的測試。
//
//  # 兩層
//
//  1. **順序與失敗路徑**（假的參與者）：舊設定檔還有效時停活動、同步安靜之後才做最後存檔、
//     切完之後才重載；任何一步失敗都整個放棄、使用者留在原本的設定檔。
//  2. **真的單例**：`NotebookStore` 等全部換成真的，從預設設定檔切到另一個、再切回來，
//     比對兩邊的筆記、同步身分、偏好沒有互相滲透。這是「經過多人切換之後，目前登入者仍保有
//     完整的、屬於自己的環境」這個需求本身。

import XCTest
@testable import Kairumo

@MainActor
private final class CallLog {
    var entries: [String] = []
    func add(_ text: String) { entries.append(text) }
}

@MainActor
private final class FakeScoped: ProfileScoped {
    let name: String
    let log: CallLog
    init(_ name: String, _ log: CallLog) { self.name = name; self.log = log }
    func prepareForProfileSwitch() async { log.add("prepare:\(name)@\(ProfileContext.activeId)") }
    func finishPreparingForProfileSwitch() async { log.add("finish:\(name)@\(ProfileContext.activeId)") }
    func resetForProfileSwitch() { log.add("reset:\(name)@\(ProfileContext.activeId)") }
}

@MainActor
final class ProfileSwitchEngineTests: XCTestCase {
    private var dir: URL!
    private var storage: ProfileRegistryStorage!
    private var other: ProfileRecord!
    private var originalActive = ProfileContext.activeId

    override func setUp() async throws {
        try await super.setUp()
        originalActive = ProfileContext.activeId
        ProfileContext.setActive(ProfileRecord.defaultId)
        dir = FileManager.default.temporaryDirectory.appending(path: "switch-\(UUID().uuidString)")
        storage = ProfileRegistryStorage(fileURL: dir.appending(path: "profiles_v1.json"))
        var registry = ProfileRegistry.initial(displayName: "我", colorHex: "#007AFF")
        other = try registry.add(displayName: "別人")
        try storage.save(registry)
    }

    override func tearDown() async throws {
        ProfileContext.setActive(originalActive)
        try? FileManager.default.removeItem(at: dir)
        try await super.tearDown()
    }

    private func makeManager(
        log: CallLog,
        quiesceSucceeds: Bool = true,
        storage customStorage: ProfileRegistryStorage? = nil
    ) -> ProfileManager {
        ProfileManager(
            storage: customStorage ?? storage,
            lockService: ProfileLockService(store: InMemorySecretStore()),
            participants: { [FakeScoped("a", log), FakeScoped("b", log)] },
            extraResets: { [{ log.add("extra@\(ProfileContext.activeId)") }] },
            quiesce: {
                log.add("quiesce@\(ProfileContext.activeId)")
                return quiesceSucceeds
                    ? ProfileManager.SyncQuiesceToken { log.add("release") }
                    : nil
            },
            restart: { log.add("restart@\(ProfileContext.activeId)") }
        )
    }

    func testTheSwitchRunsInTheRequiredOrderAndEachStepSeesTheRightProfile() async throws {
        let log = CallLog()
        let manager = makeManager(log: log)
        let oldId = ProfileRecord.defaultId, newId = other.id
        let epochBefore = manager.epoch

        try await manager.switchTo(newId)

        XCTAssertEqual(log.entries, [
            // 舊設定檔還有效：停活動。
            "prepare:a@\(oldId)", "prepare:b@\(oldId)",
            // 同步安靜（取得閘門）之後才做最後存檔 —— 兩者都還是舊設定檔。
            "quiesce@\(oldId)",
            "finish:a@\(oldId)", "finish:b@\(oldId)",
            // 切了之後才重載：每個單例讀到的都是新設定檔。
            "reset:a@\(newId)", "reset:b@\(newId)", "extra@\(newId)",
            // 閘門在重啟之前放掉（`defer`），新設定檔的同步才起得來。
            "release", "restart@\(newId)",
        ])
        XCTAssertEqual(manager.registry.activeId, newId)
        XCTAssertEqual(ProfileContext.activeId, newId)
        XCTAssertGreaterThan(manager.epoch, epochBefore, "畫面要整棵重建")
        XCTAssertFalse(manager.isSwitching)
        XCTAssertEqual(storage.load()?.activeId, newId, "名單要先寫進磁碟 —— 切換中被殺掉，下次啟動才不會回到舊的")
    }

    func testTheEditorGetsTheWillSwitchNotificationWhileTheOldProfileIsStillActive() async throws {
        let log = CallLog()
        let manager = makeManager(log: log)
        var seenActive: String?
        let token = NotificationCenter.default.addObserver(
            forName: .kairumoProfileWillSwitch, object: nil, queue: nil
        ) { _ in seenActive = ProfileContext.activeId }
        defer { NotificationCenter.default.removeObserver(token) }

        try await manager.switchTo(other.id)

        XCTAssertEqual(seenActive, ProfileRecord.defaultId, "存檔通知送到時，ProfileContext 必須還是舊的 —— 存下去的位置才對")
    }

    func testIfSyncCannotBeQuietedNothingChangesAndNoSingletonIsReset() async throws {
        let log = CallLog()
        let manager = makeManager(log: log, quiesceSucceeds: false)
        let epochBefore = manager.epoch

        do {
            try await manager.switchTo(other.id)
            XCTFail("同步沒停下來，不該切")
        } catch {
            XCTAssertEqual(error as? ProfileManager.SwitchError, .syncBusy)
        }

        XCTAssertEqual(manager.registry.activeId, ProfileRecord.defaultId)
        XCTAssertEqual(ProfileContext.activeId, ProfileRecord.defaultId)
        XCTAssertFalse(log.entries.contains { $0.hasPrefix("reset:") || $0.hasPrefix("finish:") },
                       "還沒切就不能重設任何東西，也不能做最後存檔")
        XCTAssertGreaterThan(manager.epoch, epochBefore, "畫面已經被拆成等待畫面，要重建回來")
        XCTAssertFalse(manager.isSwitching)
        XCTAssertEqual(storage.load()?.activeId, ProfileRecord.defaultId, "名單沒動")
    }

    func testIfTheRegistryCannotBeSavedNothingChanges() async throws {
        // 名單的路徑指到一個**檔案底下**：建不出目錄，寫不進去。
        let blocker = dir.appending(path: "blocker")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: blocker)
        let log = CallLog()
        let manager = makeManager(log: log)
        manager.storage = ProfileRegistryStorage(fileURL: blocker.appending(path: "sub/profiles.json"))

        do {
            try await manager.switchTo(other.id)
            XCTFail("名單寫不進去，不該切")
        } catch {
            XCTAssertEqual(error as? ProfileManager.SwitchError, .registryNotSaved)
        }
        XCTAssertEqual(ProfileContext.activeId, ProfileRecord.defaultId)
        XCTAssertFalse(log.entries.contains { $0.hasPrefix("reset:") })
    }

    func testSwitchingToTheActiveOrAnUnknownProfileIsRejected() async throws {
        let manager = makeManager(log: CallLog())
        do { try await manager.switchTo(ProfileRecord.defaultId); XCTFail() } catch {
            XCTAssertEqual(error as? ProfileManager.SwitchError, .alreadyActive)
        }
        do { try await manager.switchTo("nope"); XCTFail() } catch {
            XCTAssertEqual(error as? ProfileManager.SwitchError, .unknownProfile)
        }
    }

    func testABAKeepsTheActiveProfileConsistentAcrossRepeatedSwitches() async throws {
        let log = CallLog()
        let manager = makeManager(log: log)
        for _ in 0 ..< 3 {
            try await manager.switchTo(other.id)
            XCTAssertEqual(ProfileContext.activeId, other.id)
            try await manager.switchTo(ProfileRecord.defaultId)
            XCTAssertEqual(ProfileContext.activeId, ProfileRecord.defaultId)
        }
        XCTAssertEqual(manager.registry.activeId, ProfileRecord.defaultId)
        XCTAssertEqual(log.entries.filter { $0.hasPrefix("quiesce@") }.count, 6, "每次切換都要讓同步安靜")
    }

    func testTheDefaultParticipantListCoversEveryProfileScopedSingleton() {
        // 新增了標成 `profile` 的單例卻忘了加進清單，切換之後它就把上一個人的狀態留給下一個人。
        // 這裡核對清單裡的型別；腳本（check-profile-scope.py）保證每個 profile 單例都有 reset 實作。
        let names = ProfileManager.defaultParticipants().map { String(describing: type(of: $0)) }
        for expected in [
            "NotebookStore", "AccountSyncStore", "AccountManager", "GoogleAuth", "LocalizationManager",
            "AutoSyncController", "FocusSyncController", "AudioRecorderManager", "CollaborationManager",
            "ToolbarSettings", "NotebookSearchIndex", "StickerManager", "PenHardwareSettings",
            "GuidanceSuppressionManager", "DraftingState", "SyncLogger", "CloudSyncFolderMonitor",
        ] {
            XCTAssertTrue(names.contains(expected), "\(expected) 沒有在切換清單裡")
        }
    }
}

/// 用**真的**單例做 A→B→A。會讀預設設定檔（這台機器上真實的資料）、並在另一個臨時設定檔裡寫東西，
/// 最後把臨時設定檔整個刪掉。不會改動預設設定檔的內容（切換時的存檔只是把同樣的內容再寫一次）。
@MainActor
final class ProfileIsolationTests: XCTestCase {
    private var dir: URL!
    private var originalActive = ProfileContext.activeId
    private var profileB: ProfileRecord!

    override func setUp() async throws {
        try await super.setUp()
        originalActive = ProfileContext.activeId
        ProfileContext.setActive(ProfileRecord.defaultId)
        dir = FileManager.default.temporaryDirectory.appending(path: "isolation-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        if let profileB {
            for url in ProfileContext.ownedDirectories(for: profileB.id) { try? FileManager.default.removeItem(at: url) }
            ProfileDefaults.removeAll(forProfile: profileB.id)
        }
        ProfileContext.setActive(originalActive)
        try? FileManager.default.removeItem(at: dir)
        try await super.tearDown()
    }

    private struct Snapshot: Equatable {
        var notebookIds: [String]
        var titles: [String]
        var folderCount: Int
        var syncDeviceId: String
        var coreDeviceId: UInt32
    }

    private func snapshot() -> Snapshot {
        let store = NotebookStore.shared
        return Snapshot(
            notebookIds: store.notebooks.map(\.id).sorted(),
            titles: store.notebooks.map(\.title).sorted(),
            folderCount: store.folders.count,
            syncDeviceId: AccountSyncStore.shared.deviceId,
            coreDeviceId: NotebookMigration.deviceId)
    }

    func testTwoProfilesDoNotLeakIntoEachOtherAndTheOriginalComesBackIntact() async throws {
        let storage = ProfileRegistryStorage(fileURL: dir.appending(path: "profiles_v1.json"))
        var registry = ProfileRegistry.initial(displayName: "我", colorHex: "#007AFF")
        profileB = try registry.add(displayName: "測試用的另一個人")
        try storage.save(registry)
        let manager = ProfileManager(
            storage: storage, lockService: ProfileLockService(store: InMemorySecretStore()),
            restart: {})

        // ── A（預設設定檔）：記下現況。
        let before = snapshot()
        XCTAssertFalse(before.notebookIds.isEmpty)

        // ── 切到 B。
        try await manager.switchTo(profileB.id)
        let inB = snapshot()
        XCTAssertEqual(ProfileContext.activeId, profileB.id)
        XCTAssertNotEqual(inB.syncDeviceId, before.syncDeviceId, "每個設定檔是同步協定裡獨立的一台裝置")
        XCTAssertNotEqual(inB.coreDeviceId, before.coreDeviceId, "oplog 檔名裡的 device id 不能共用")
        XCTAssertTrue(
            NotebookStore.shared.documentsDirectory.path.contains("/Profiles/\(profileB.id)/"),
            "B 的資料根目錄必須是它自己的")
        // B 是全新的：只有範例筆記，沒有 A 的任何使用者筆記。
        let userNotebooksInA = Set(before.notebookIds).filter { !$0.hasPrefix("seed-") && !$0.hasPrefix("a0d10000") }
        XCTAssertTrue(userNotebooksInA.isDisjoint(with: Set(inB.notebookIds)), "A 的筆記不該出現在 B")
        XCTAssertTrue(SyncLogger.shared.entries.isEmpty, "同步日誌有筆記本標題，不能留給下一個人")

        // ── 在 B 裡寫東西。
        let marker = "只屬於B-\(UUID().uuidString.prefix(6))"
        _ = NotebookStore.shared.createNotebook(title: marker, template: .blank)
        NotebookStore.shared.markDirtyAndPersist(signalsLocalEdit: false)
        XCTAssertTrue(NotebookStore.shared.notebooks.contains { $0.title == marker })
        ProfileDefaults.current.set("b-only", forKey: "kairumo.test.isolation")

        // ── 切回 A。
        try await manager.switchTo(ProfileRecord.defaultId)
        let after = snapshot()
        XCTAssertEqual(after, before, "切了一圈回來，A 必須和原本完全一樣")
        XCTAssertFalse(NotebookStore.shared.notebooks.contains { $0.title == marker }, "B 寫的東西不能出現在 A")
        XCTAssertNil(ProfileDefaults.current.string(forKey: "kairumo.test.isolation"), "B 的偏好不能出現在 A")

        // ── 再切到 B：它寫的東西還在（資料真的落了盤，不是只在記憶體）。
        try await manager.switchTo(profileB.id)
        XCTAssertTrue(NotebookStore.shared.notebooks.contains { $0.title == marker }, "B 的筆記要在")
        XCTAssertEqual(ProfileDefaults.current.string(forKey: "kairumo.test.isolation"), "b-only")

        try await manager.switchTo(ProfileRecord.defaultId)
        XCTAssertEqual(snapshot(), before)
    }
}

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

/// 管理操作：新增、重新命名、刪除、鎖、Google 帳號綁定。
/// 全部用臨時名單與記憶體裡的 PIN 儲存，不碰真的設定檔名單與 Keychain。
@MainActor
final class ProfileManagementTests: XCTestCase {
    private var dir: URL!
    private var created: [String] = []
    private var originalActive = ProfileContext.activeId

    override func setUp() async throws {
        try await super.setUp()
        originalActive = ProfileContext.activeId
        ProfileContext.setActive(ProfileRecord.defaultId)
        dir = FileManager.default.temporaryDirectory.appending(path: "mgmt-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        for id in created {
            for url in ProfileContext.ownedDirectories(for: id) { try? FileManager.default.removeItem(at: url) }
            ProfileDefaults.removeAll(forProfile: id)
        }
        ProfileContext.setActive(originalActive)
        try? FileManager.default.removeItem(at: dir)
        try await super.tearDown()
    }

    private func makeManager() -> ProfileManager {
        let storage = ProfileRegistryStorage(fileURL: dir.appending(path: "profiles_v1.json"))
        try? storage.save(ProfileRegistry.initial(displayName: "我", colorHex: "#007AFF"))
        return ProfileManager(
            storage: storage, lockService: ProfileLockService(store: InMemorySecretStore()),
            participants: { [] }, extraResets: { [] }, quiesce: { .init(release: {}) }, restart: {})
    }

    private func addProfile(_ manager: ProfileManager, _ name: String) throws -> ProfileRecord {
        let record = try manager.createProfile(name: name)
        created.append(record.id)
        return record
    }

    func testCreatingAProfileSeedsItsOwnIdentityAndLanguageWithoutTouchingTheDefault() throws {
        let manager = makeManager()
        let record = try addProfile(manager, "小明")

        XCTAssertEqual(manager.profiles.count, 2)
        let defaults = ProfileDefaults(profileId: record.id)
        let identity = try JSONDecoder().decode(UserProfile.self, from: XCTUnwrap(defaults.data(forKey: "kairumo.user.profile")))
        XCTAssertEqual(identity.displayName, "小明")
        XCTAssertEqual(identity.colorHex, record.colorHex)
        XCTAssertEqual(defaults.string(forKey: "kairumo.app.language"), LocalizationManager.shared.currentLanguage.rawValue)
        XCTAssertEqual(manager.active.id, ProfileRecord.defaultId, "新增不會自動切過去")
    }

    func testTheFiveProfileLimitAppliesToCreate() throws {
        let manager = makeManager()
        for i in 1 ..< ProfileRegistry.maxProfiles { _ = try addProfile(manager, "人\(i)") }
        XCTAssertFalse(manager.canAddProfile)
        XCTAssertThrowsError(try manager.createProfile(name: "第六個")) {
            XCTAssertEqual($0 as? ProfileError, .limitReached)
        }
    }

    func testRenameKeepsTheCollaborationIdentityInSync() throws {
        let manager = makeManager()
        let record = try addProfile(manager, "舊名")

        try manager.renameProfile(id: record.id, to: "新名")
        try manager.setProfileColor(id: record.id, hex: "#FF2D55")

        XCTAssertEqual(manager.registry.profile(id: record.id)?.displayName, "新名")
        let identity = try JSONDecoder().decode(
            UserProfile.self,
            from: XCTUnwrap(ProfileDefaults(profileId: record.id).data(forKey: "kairumo.user.profile")))
        XCTAssertEqual(identity.displayName, "新名", "選單上叫新名，協作畫面上也要叫新名")
        XCTAssertEqual(identity.colorHex, "#FF2D55")
        XCTAssertThrowsError(try manager.renameProfile(id: record.id, to: "我")) {
            XCTAssertEqual($0 as? ProfileError, .duplicateName)
        }
    }

    func testDeleteRemovesEverythingOfThatProfileAndNothingElse() throws {
        let manager = makeManager()
        let doomed = try addProfile(manager, "要刪的")
        let kept = try addProfile(manager, "要留的")
        try manager.setPIN("1234", for: doomed.id)
        // 假裝它有資料：目錄、偏好。
        let dirs = ProfileContext.ownedDirectories(for: doomed.id)
        for url in dirs { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        ProfileDefaults(profileId: doomed.id).set("x", forKey: "kairumo.some.pref")
        ProfileDefaults(profileId: kept.id).set("keep", forKey: "kairumo.some.pref")
        let keptDirs = ProfileContext.ownedDirectories(for: kept.id)
        for url in keptDirs { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }

        try manager.deleteProfile(id: doomed.id)

        XCTAssertNil(manager.registry.profile(id: doomed.id))
        XCTAssertTrue(dirs.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertNil(ProfileDefaults(profileId: doomed.id).object(forKey: "kairumo.some.pref"))
        XCTAssertFalse(manager.lockService.hasPIN(for: doomed.id), "PIN 也要清掉")
        // 別的設定檔完全不受影響。
        XCTAssertEqual(ProfileDefaults(profileId: kept.id).string(forKey: "kairumo.some.pref"), "keep")
        XCTAssertTrue(keptDirs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertNotNil(manager.registry.profile(id: kept.id))
    }

    func testTheDefaultAndTheActiveProfileCannotBeDeleted() throws {
        let manager = makeManager()
        let other = try addProfile(manager, "別人")
        XCTAssertThrowsError(try manager.deleteProfile(id: ProfileRecord.defaultId)) {
            XCTAssertEqual($0 as? ProfileError, .cannotDeleteActive, "它現在就是使用中的")
        }
        // 切到 other 之後，預設設定檔不再是使用中的，但仍然不能刪。
        var next = manager.registry
        try next.activate(id: other.id)
        manager.registry = next
        XCTAssertThrowsError(try manager.deleteProfile(id: ProfileRecord.defaultId)) {
            XCTAssertEqual($0 as? ProfileError, .cannotDeleteDefault, "預設設定檔對應升級前的資料，不能刪")
        }
        XCTAssertThrowsError(try manager.deleteProfile(id: other.id)) {
            XCTAssertEqual($0 as? ProfileError, .cannotDeleteActive)
        }
        XCTAssertThrowsError(try manager.deleteProfile(id: "nope")) {
            XCTAssertEqual($0 as? ProfileError, .notFound)
        }
    }

    func testPINLifecycleSetVerifyChangeRemove() throws {
        let manager = makeManager()
        XCTAssertFalse(manager.active.lock.isEnabled)

        try manager.setPIN("2468", for: ProfileRecord.defaultId)
        XCTAssertTrue(manager.active.lock.hasPIN)
        XCTAssertEqual(manager.verifyPIN("2468", for: ProfileRecord.defaultId), .ok)

        // 沒有 PIN 就不能開生物辨識；有了才可以。
        try manager.setBiometrics(true, for: ProfileRecord.defaultId)
        XCTAssertTrue(manager.active.lock.useBiometrics)
        // 更換 PIN 之後生物辨識設定保留。
        try manager.setPIN("1357", for: ProfileRecord.defaultId)
        XCTAssertTrue(manager.active.lock.useBiometrics)
        XCTAssertEqual(manager.verifyPIN("2468", for: ProfileRecord.defaultId).isOK, false)

        // 移除鎖需要目前的 PIN：錯的 PIN 拿不掉。
        XCTAssertThrowsError(try manager.removeLock(for: ProfileRecord.defaultId, currentPIN: "0000")) {
            XCTAssertEqual($0 as? ProfileError, .wrongPIN)
        }
        XCTAssertTrue(manager.active.lock.hasPIN, "輸錯 PIN，鎖還在")
        try manager.removeLock(for: ProfileRecord.defaultId, currentPIN: "1357")
        XCTAssertEqual(manager.active.lock, .none)
        XCTAssertFalse(manager.lockService.hasPIN(for: ProfileRecord.defaultId))
        XCTAssertThrowsError(try manager.setBiometrics(true, for: ProfileRecord.defaultId)) {
            XCTAssertEqual($0 as? ProfileError, .pinRequired)
        }
    }

    func testUnlockingTheActiveProfileLiftsTheScreenGateOnlyWithTheRightPIN() throws {
        let manager = makeManager()
        try manager.setPIN("2468", for: ProfileRecord.defaultId)
        manager.isLocked = true

        XCTAssertNotEqual(manager.unlockActive(pin: "1111"), .ok)
        XCTAssertTrue(manager.isLocked)
        XCTAssertEqual(manager.unlockActive(pin: "2468"), .ok)
        XCTAssertFalse(manager.isLocked)
    }

    func testTheLockComesBackAfterTheAppWasAwayLongEnoughButNotForAQuickLook() throws {
        let manager = makeManager()
        try manager.setPIN("2468", for: ProfileRecord.defaultId)
        manager.isLocked = false
        let t0 = Date(timeIntervalSince1970: 1_000_000)

        manager.noteEnteredBackground(now: t0)
        manager.noteBecameActive(now: t0.addingTimeInterval(ProfileManager.relockAfterBackground - 1))
        XCTAssertFalse(manager.isLocked, "只是看一下通知，不該重新上鎖")

        manager.noteEnteredBackground(now: t0)
        manager.noteBecameActive(now: t0.addingTimeInterval(ProfileManager.relockAfterBackground + 1))
        XCTAssertTrue(manager.isLocked)
    }

    func testAProfileWithoutALockIsNeverGated() throws {
        let manager = makeManager()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        manager.noteEnteredBackground(now: t0)
        manager.noteBecameActive(now: t0.addingTimeInterval(3600))
        XCTAssertFalse(manager.isLocked)
    }

    func testOneGoogleAccountCannotBeBoundToTwoProfiles() throws {
        let manager = makeManager()
        let other = try addProfile(manager, "別人")
        try manager.bindGoogle(email: "Me@Example.com")  // 綁在使用中的（預設）

        var next = manager.registry
        try next.activate(id: other.id)
        manager.registry = next
        XCTAssertThrowsError(try manager.bindGoogle(email: "me@example.com")) {
            XCTAssertEqual($0 as? ProfileError, .googleAlreadyBound(profileName: "我"))
        }
        // 預設設定檔登出之後帳號才放出來。
        var back = manager.registry
        back.unbindGoogle(id: ProfileRecord.defaultId)
        manager.registry = back
        XCTAssertNoThrow(try manager.bindGoogle(email: "me@example.com"))
        XCTAssertEqual(manager.registry.profile(id: other.id)?.googleEmail, "me@example.com")
    }
}

private extension PINVerifyResult {
    var isOK: Bool { self == .ok }
}

/// 同步身分的隔離：每個設定檔有自己的雲端快照、同步索引、`deviceId`。
@MainActor
final class ProfileSyncIsolationTests: XCTestCase {
    private var originalActive = ProfileContext.activeId
    private let other = "sync-iso-\(UUID().uuidString.lowercased())"

    override func setUp() async throws {
        try await super.setUp()
        originalActive = ProfileContext.activeId
        ProfileContext.setActive(ProfileRecord.defaultId)
    }

    override func tearDown() async throws {
        for url in ProfileContext.ownedDirectories(for: other) { try? FileManager.default.removeItem(at: url) }
        try? FileManager.default.removeItem(
            at: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Kairumo/sync/\(other)", isDirectory: true))
        ProfileDefaults.removeAll(forProfile: other)
        ProfileContext.setActive(originalActive)
        try await super.tearDown()
    }

    func testEachProfileHasItsOwnRemoteSnapshotFileEvenWithoutAGoogleAccount() {
        let store = AccountSyncStore.shared
        let defaultPath = store.remoteIndexURL(account: "").path
        ProfileContext.setActive(other)
        let otherPath = store.remoteIndexURL(account: "").path
        XCTAssertNotEqual(defaultPath, otherPath, "沒登入帳號時兩個設定檔不能共用同一個快照檔")
        XCTAssertTrue(otherPath.contains("/Kairumo/sync/\(other)/"))
        XCTAssertFalse(defaultPath.contains("/Kairumo/sync/\(other)/"), "預設設定檔維持原位置")
    }

    func testTheSyncIdentityIsPerProfile() {
        let before = NotebookMigration.deviceId
        ProfileContext.setActive(other)
        let inOther = NotebookMigration.deviceId
        XCTAssertNotEqual(before, inOther, "oplog 檔名裡的 device id：兩個設定檔共用的話，綁到同一個雲端資料夾時檔名會撞")
        XCTAssertEqual(NotebookMigration.deviceId, inOther, "同一個設定檔每次取到的是同一個（存起來了）")
        ProfileContext.setActive(ProfileRecord.defaultId)
        XCTAssertEqual(NotebookMigration.deviceId, before, "切回來還是原本的")
    }

    func testKeychainTokensAreScopedPerProfile() {
        XCTAssertNotEqual(
            ProfileContext.scopedAccount("tokens", for: ProfileRecord.defaultId),
            ProfileContext.scopedAccount("tokens", for: other),
            "兩個設定檔的 Google 登入不能放在同一個 Keychain 項目裡")
        XCTAssertEqual(ProfileContext.scopedAccount("tokens", for: ProfileRecord.defaultId), "tokens",
                       "預設設定檔的項目名不能變 —— 升級前登入過的人不必重新登入")
    }
}

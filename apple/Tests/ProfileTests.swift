//
//  ProfileTests.swift
//  KairumoTests
//
//  多設定檔的規則與根基：名單規則、偏好設定的前綴隔離、PIN 與鎖定。
//  這些都是純邏輯，不需要啟動 App 就能完整驗證 —— 切換流程與畫面是之後階段的事。
//

import XCTest
@testable import Kairumo

final class ProfileRegistryTests: XCTestCase {
    private func registry() -> ProfileRegistry {
        ProfileRegistry.initial(displayName: "我", colorHex: "#007AFF", now: Date(timeIntervalSince1970: 1000))
    }

    func testInitialRegistryHasOnlyTheDefaultProfileAndItIsActive() {
        let r = registry()
        XCTAssertEqual(r.profiles.count, 1)
        XCTAssertEqual(r.active.id, ProfileRecord.defaultId)
        XCTAssertTrue(r.active.isDefault)
    }

    func testTheLimitIsFiveProfilesInTotal() throws {
        var r = registry()
        for i in 1 ..< ProfileRegistry.maxProfiles {
            try r.add(displayName: "人\(i)")
        }
        XCTAssertEqual(r.profiles.count, 5)
        XCTAssertFalse(r.canAdd)
        XCTAssertThrowsError(try r.add(displayName: "第六個")) {
            XCTAssertEqual($0 as? ProfileError, .limitReached)
        }
    }

    func testNamesMustBeNonEmptyShortAndUniqueIgnoringCase() throws {
        var r = registry()
        XCTAssertThrowsError(try r.add(displayName: "   ")) { XCTAssertEqual($0 as? ProfileError, .invalidName) }
        XCTAssertThrowsError(try r.add(displayName: String(repeating: "長", count: 25))) {
            XCTAssertEqual($0 as? ProfileError, .invalidName)
        }
        try r.add(displayName: "Alice")
        XCTAssertThrowsError(try r.add(displayName: " alice ")) { XCTAssertEqual($0 as? ProfileError, .duplicateName) }
        // 改成自己現在的名字不算重複。
        let alice = r.profiles.first { $0.displayName == "Alice" }!
        XCTAssertNoThrow(try r.rename(id: alice.id, to: "Alice"))
    }

    func testNewProfilesGetDistinctColorsUntilThePaletteRunsOut() throws {
        var r = registry()
        try r.add(displayName: "A")
        try r.add(displayName: "B")
        XCTAssertEqual(Set(r.profiles.map(\.colorHex)).count, 3)
    }

    func testTheLastProfileCannotBeRemoved() {
        var r = registry()
        XCTAssertThrowsError(try r.remove(id: ProfileRecord.defaultId)) {
            XCTAssertEqual($0 as? ProfileError, .lastProfile)
        }
    }

    func testRemovingTheActiveProfileFallsBackToTheMostRecentlyUsedOne() throws {
        var r = registry()
        let a = try r.add(displayName: "A", now: Date(timeIntervalSince1970: 2000))
        let b = try r.add(displayName: "B", now: Date(timeIntervalSince1970: 3000))
        try r.activate(id: a.id, now: Date(timeIntervalSince1970: 4000))
        try r.remove(id: a.id)
        XCTAssertEqual(r.activeId, b.id, "最近用過的是 B（3000），不是預設（1000）")
    }

    func testOneGoogleAccountCanOnlyBeBoundToOneProfile() throws {
        var r = registry()
        let a = try r.add(displayName: "A")
        try r.bindGoogle(email: "Me@Example.com", to: ProfileRecord.defaultId)
        XCTAssertThrowsError(try r.bindGoogle(email: " me@example.COM ", to: a.id)) {
            XCTAssertEqual($0 as? ProfileError, .googleAlreadyBound(profileName: "我"))
        }
        // 綁回自己是可以的（重新登入同一個帳號）。
        XCTAssertNoThrow(try r.bindGoogle(email: "me@example.com", to: ProfileRecord.defaultId))
        // 解綁之後別的設定檔就能用。
        r.unbindGoogle(id: ProfileRecord.defaultId)
        XCTAssertNoThrow(try r.bindGoogle(email: "me@example.com", to: a.id))
        XCTAssertEqual(r.profile(boundTo: "ME@example.com")?.id, a.id)
    }

    func testBiometricsCannotExistWithoutAPIN() throws {
        var r = registry()
        try r.setLock(id: ProfileRecord.defaultId, ProfileLock(hasPIN: false, useBiometrics: true))
        XCTAssertEqual(r.active.lock, .none, "沒有 PIN 就不能只靠生物辨識（見 ProfileLock 的說明）")
        try r.setLock(id: ProfileRecord.defaultId, ProfileLock(hasPIN: true, useBiometrics: true))
        XCTAssertTrue(r.active.lock.useBiometrics)
    }

    func testRepairFixesAnInconsistentFile() {
        let a = ProfileRecord(id: "x", displayName: "A", colorHex: "#000", googleEmail: "same@x.com")
        let b = ProfileRecord(id: "y", displayName: "B", colorHex: "#111", googleEmail: "same@x.com")
        let broken = ProfileRegistry(profiles: [a, a, b], activeId: "missing")
        let fixed = broken.repaired(fallbackName: "我", fallbackColor: "#007AFF")
        XCTAssertEqual(fixed.profiles.map(\.id), ["x", "y"], "重複的 id 只留一個")
        XCTAssertEqual(fixed.activeId, "x", "使用中的 id 不存在 → 退到第一個")
        XCTAssertNil(fixed.profiles[1].googleEmail, "同一個 Google 帳號不能出現兩次")
        let empty = ProfileRegistry(profiles: [], activeId: "x").repaired(fallbackName: "我", fallbackColor: "#007AFF")
        XCTAssertEqual(empty.profiles.count, 1, "名單不能是空的")
    }

    func testStorageRoundTripsAndKeepsACorruptFile() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "profiles-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let storage = ProfileRegistryStorage(fileURL: dir.appending(path: "profiles_v1.json"))
        XCTAssertNil(storage.load())

        var r = registry()
        try r.add(displayName: "A", now: Date(timeIntervalSince1970: 2000))
        try storage.save(r)
        XCTAssertEqual(storage.load(), r)

        try Data("not json".utf8).write(to: storage.fileURL)
        XCTAssertNil(storage.load())
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: dir.appending(path: "profiles_v1.corrupt.json").path),
            "壞掉的名單要留一份，不能直接被覆蓋")
    }
}

final class ProfileDefaultsTests: XCTestCase {
    private let id = "test-\(UUID().uuidString.lowercased())"

    override func tearDown() {
        ProfileDefaults.removeAll(forProfile: id)
        UserDefaults.standard.removeObject(forKey: "kairumo.test.plain")
        super.tearDown()
    }

    func testTheDefaultProfileUsesTheOriginalKeysUntouched() {
        let d = ProfileDefaults(profileId: ProfileRecord.defaultId)
        d.set("value", forKey: "kairumo.test.plain")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "kairumo.test.plain"), "value",
                       "預設設定檔的鍵名不能有前綴，否則升級後既有使用者的設定就全部消失")
    }

    func testOtherProfilesAreIsolatedFromEachOtherAndFromTheDefault() {
        let a = ProfileDefaults(profileId: id)
        let b = ProfileDefaults(profileId: id + "-b")
        defer { ProfileDefaults.removeAll(forProfile: id + "-b") }
        a.set(1, forKey: "k")
        b.set(2, forKey: "k")
        XCTAssertEqual(a.integer(forKey: "k"), 1)
        XCTAssertEqual(b.integer(forKey: "k"), 2)
        XCTAssertNil(ProfileDefaults(profileId: ProfileRecord.defaultId).object(forKey: "k"))
    }

    func testRemoveAllClearsOnlyThatProfile() {
        let a = ProfileDefaults(profileId: id)
        a.set(true, forKey: "x")
        a.set("y", forKey: "z")
        UserDefaults.standard.set("keep", forKey: "kairumo.test.plain")
        ProfileDefaults.removeAll(forProfile: id)
        XCTAssertNil(a.object(forKey: "x"))
        XCTAssertNil(a.object(forKey: "z"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "kairumo.test.plain"), "keep")
    }

    func testDictionaryRepresentationStripsThePrefixAndExcludesOtherProfiles() {
        let a = ProfileDefaults(profileId: id)
        a.set("v", forKey: "alpha")
        XCTAssertEqual(a.dictionaryRepresentation()["alpha"] as? String, "v")
        XCTAssertNil(a.dictionaryRepresentation()["kairumo.profiles.activeId"])
        let defaultDictionary = ProfileDefaults(profileId: ProfileRecord.defaultId).dictionaryRepresentation()
        XCTAssertFalse(defaultDictionary.keys.contains { $0.hasPrefix("kairumo.pf.") },
                       "預設設定檔的備份不能夾帶別的設定檔的資料")
        XCTAssertNil(defaultDictionary[ProfileContext.activeKey], "裝置共用的鍵不屬於任何設定檔")
    }

    func testKeychainAccountsAreScopedExceptForTheDefault() {
        XCTAssertEqual(ProfileContext.scopedAccount("tokens", for: ProfileRecord.defaultId), "tokens")
        XCTAssertEqual(ProfileContext.scopedAccount("tokens", for: "abc"), "tokens.abc")
    }

    func testDirectoriesAreSeparatePerProfileAndTheDefaultKeepsItsOwnLocation() {
        XCTAssertNil(ProfileContext.documentsRoot(for: ProfileRecord.defaultId))
        XCTAssertNil(ProfileContext.cachesRoot(for: ProfileRecord.defaultId))
        let a = ProfileContext.documentsRoot(for: "aaa")!
        let b = ProfileContext.documentsRoot(for: "bbb")!
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a.path.contains("/Profiles/aaa/"))
        XCTAssertNotEqual(ProfileContext.cachesRoot(for: "aaa"), ProfileContext.cachesRoot(for: "bbb"))
        XCTAssertTrue(ProfileContext.ownedDirectories(for: ProfileRecord.defaultId).isEmpty,
                      "刪除設定檔時不能把預設設定檔（使用者自己選的位置）當成我們擁有的")
    }
}

final class ProfileLockServiceTests: XCTestCase {
    private func service() -> ProfileLockService { ProfileLockService(store: InMemorySecretStore()) }
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testPINFormat() {
        XCTAssertTrue(ProfileLockService.isValidPIN("1234"))
        XCTAssertTrue(ProfileLockService.isValidPIN("12345678"))
        XCTAssertFalse(ProfileLockService.isValidPIN("123"))
        XCTAssertFalse(ProfileLockService.isValidPIN("123456789"))
        XCTAssertFalse(ProfileLockService.isValidPIN("12a4"))
        XCTAssertFalse(ProfileLockService.isValidPIN("１２３４"), "全形數字不算")
    }

    func testCorrectPINUnlocksAndTheWrongOneDoesNot() throws {
        let s = service()
        XCTAssertEqual(s.verify("1234", for: "p", now: t0), .noPIN)
        try s.setPIN("2468", for: "p")
        XCTAssertTrue(s.hasPIN(for: "p"))
        XCTAssertEqual(s.verify("2468", for: "p", now: t0), .ok)
        XCTAssertEqual(s.verify("1111", for: "p", now: t0), .wrong(attemptsBeforeLock: 4))
    }

    func testPINsAreIndependentPerProfile() throws {
        let s = service()
        try s.setPIN("1111", for: "a")
        try s.setPIN("2222", for: "b")
        XCTAssertEqual(s.verify("1111", for: "a", now: t0), .ok)
        XCTAssertNotEqual(s.verify("1111", for: "b", now: t0), .ok)
    }

    func testRepeatedFailuresLockOutWithIncreasingDelayAndSurviveRelaunch() throws {
        let store = InMemorySecretStore()
        let s = ProfileLockService(store: store)
        try s.setPIN("2468", for: "p")
        for _ in 0 ..< 4 { _ = s.verify("0000", for: "p", now: t0) }
        // 第 5 次錯：鎖 30 秒。
        guard case let .lockedOut(until) = s.verify("0000", for: "p", now: t0) else { return XCTFail("應該鎖定") }
        XCTAssertEqual(until.timeIntervalSince(t0), 30, accuracy: 0.1)
        // 鎖定中連正確的 PIN 也不收。
        XCTAssertEqual(s.verify("2468", for: "p", now: t0.addingTimeInterval(10)), .lockedOut(until: until))
        // 「重開 App」：換一個 service 實例、同一份 Keychain，鎖定狀態還在。
        let relaunched = ProfileLockService(store: store)
        XCTAssertEqual(relaunched.verify("2468", for: "p", now: t0.addingTimeInterval(10)), .lockedOut(until: until))
        // 鎖定結束後正確的 PIN 可以開，並且歸零。
        XCTAssertEqual(relaunched.verify("2468", for: "p", now: t0.addingTimeInterval(31)), .ok)
        XCTAssertEqual(relaunched.verify("0000", for: "p", now: t0.addingTimeInterval(32)), .wrong(attemptsBeforeLock: 4))
    }

    func testLockDurationsGrowAndAreCapped() {
        XCTAssertEqual(ProfileLockService.lockDuration(forFailures: 4), 0)
        XCTAssertEqual(ProfileLockService.lockDuration(forFailures: 5), 30)
        XCTAssertEqual(ProfileLockService.lockDuration(forFailures: 8), 900)
        XCTAssertEqual(ProfileLockService.lockDuration(forFailures: 50), 3600)
    }

    func testTheStoredRecordNeverContainsThePIN() throws {
        let store = InMemorySecretStore()
        let s = ProfileLockService(store: store)
        try s.setPIN("97531", for: "p")
        let raw = String(decoding: store.read(account: "pin.p")!, as: UTF8.self)
        XCTAssertFalse(raw.contains("97531"))
    }

    func testInvalidPINIsRejectedAndClearRemovesIt() throws {
        let s = service()
        XCTAssertThrowsError(try s.setPIN("12", for: "p")) { XCTAssertEqual($0 as? ProfileError, .invalidPIN) }
        try s.setPIN("1234", for: "p")
        s.clearPIN(for: "p")
        XCTAssertFalse(s.hasPIN(for: "p"))
    }
}

/// 儲存失敗的路徑：PIN 存不進去要如實回報，不能謊報成「格式不對」。
final class ProfileLockStorageFailureTests: XCTestCase {
    private final class FailingStore: ProfileSecretStore {
        func read(account: String) -> Data? { nil }
        func write(_ data: Data, account: String) -> Bool { false }
        func delete(account: String) {}
    }

    func testAFailingStoreIsReportedAsFailureNotAsAnInvalidPIN() throws {
        let service = ProfileLockService(store: FailingStore())
        XCTAssertFalse(try service.setPIN("2468", for: "p"), "寫不進去就是 false，不是丟 invalidPIN")
        XCTAssertFalse(service.hasPIN(for: "p"))
        XCTAssertThrowsError(try service.setPIN("12", for: "p")) {
            XCTAssertEqual($0 as? ProfileError, .invalidPIN, "格式不對才是 invalidPIN")
        }
    }
}

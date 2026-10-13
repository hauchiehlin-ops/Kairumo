//
//  ProfileLockService.swift
//  Kairumo
//
//  設定檔鎖：PIN，加上可選的生物辨識捷徑。
//
//  # 這是什麼、不是什麼
//
//  它擋的是「同一台裝置上的**另一個設定檔的使用者**不小心（或好奇）點進你的環境」。
//  它**不是**加密：資料在裝置的 App 沙盒裡，核心直接讀寫檔案，沒有針對設定檔的加密層。
//  真正的保密要靠作業系統的使用者帳號或裝置密碼。畫面與說明文件都要把這件事講清楚。
//
//  # PIN
//
//  4～8 位數字。用 PBKDF2-HMAC-SHA256（12 萬次）加隨機鹽雜湊後存進 Keychain，
//  設定檔的 JSON 裡只記「有沒有設 PIN」。連續輸錯會**遞增鎖定**，而且鎖定狀態存在 Keychain，
//  重開 App 不會歸零。
//
//  **忘記 PIN 沒有救援。** 用裝置密碼救援的話，知道裝置密碼的家人就能重設別人的 PIN ——
//  那正是這個鎖要擋的對象。唯一的出路是刪除這個設定檔；有登入 Google 的話，
//  重新登入就能把雲端上的筆記拉回來。

import CommonCrypto
import Foundation
import LocalAuthentication
import Security

// MARK: - 秘密儲存

/// 抽象的小型秘密儲存。正式版是 Keychain，測試用記憶體版。
public protocol ProfileSecretStore: AnyObject {
    func read(account: String) -> Data?
    func write(_ data: Data, account: String) -> Bool
    func delete(account: String)
}

public final class KeychainSecretStore: ProfileSecretStore {
    private let service: String

    public init(service: String = "com.kairumo.padnote.profilelock") {
        self.service = service
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func read(account: String) -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    public func write(_ data: Data, account: String) -> Bool {
        let query = baseQuery(account)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            // 只在這台裝置解鎖後可讀，不進 iCloud 鑰匙圈、不跟著備份搬到別台。
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    public func delete(account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}

public final class InMemorySecretStore: ProfileSecretStore {
    private var items: [String: Data] = [:]
    public init() {}
    public func read(account: String) -> Data? { items[account] }
    public func write(_ data: Data, account: String) -> Bool { items[account] = data; return true }
    public func delete(account: String) { items[account] = nil }
}

// MARK: - PIN

public enum PINVerifyResult: Equatable {
    case ok
    /// 輸錯了。`attemptsBeforeLock` 是再錯幾次會開始鎖定（0 = 已經在鎖定中）。
    case wrong(attemptsBeforeLock: Int)
    case lockedOut(until: Date)
    /// 這個設定檔根本沒有設 PIN。
    case noPIN
}

public final class ProfileLockService {
    public static let shared = ProfileLockService(store: KeychainSecretStore())

    public static let minDigits = 4
    public static let maxDigits = 8
    /// 連續輸錯幾次以內不鎖定。
    public static let freeAttempts = 4
    static let iterations = 120_000

    private struct Record: Codable {
        var salt: Data
        var hash: Data
        var iterations: Int
        var failures: Int
        var lockedUntil: Date?
    }

    private let store: ProfileSecretStore
    private let queue = DispatchQueue(label: "kairumo.profile.lock")

    public init(store: ProfileSecretStore) {
        self.store = store
    }

    private func account(_ profileId: String) -> String { "pin.\(profileId)" }

    public static func isValidPIN(_ pin: String) -> Bool {
        (minDigits ... maxDigits).contains(pin.count) && pin.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// 鎖定時間表：第 5 次錯 30 秒、第 6 次 1 分鐘、第 7 次 5 分鐘、第 8 次 15 分鐘、之後每次 1 小時。
    static func lockDuration(forFailures failures: Int) -> TimeInterval {
        switch failures {
        case ..<5: return 0
        case 5: return 30
        case 6: return 60
        case 7: return 300
        case 8: return 900
        default: return 3600
        }
    }

    public func hasPIN(for profileId: String) -> Bool {
        queue.sync { load(profileId) != nil }
    }

    @discardableResult
    public func setPIN(_ pin: String, for profileId: String) throws -> Bool {
        guard Self.isValidPIN(pin) else { throw ProfileError.invalidPIN }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { return false }
        let hash = Self.derive(pin: pin, salt: salt, iterations: Self.iterations)
        let record = Record(salt: salt, hash: hash, iterations: Self.iterations, failures: 0, lockedUntil: nil)
        return queue.sync { save(record, profileId) }
    }

    public func clearPIN(for profileId: String) {
        queue.sync { store.delete(account: account(profileId)) }
    }

    public func verify(_ pin: String, for profileId: String, now: Date = Date()) -> PINVerifyResult {
        queue.sync {
            guard var record = load(profileId) else { return .noPIN }
            if let until = record.lockedUntil, until > now {
                return .lockedOut(until: until)
            }
            let candidate = Self.derive(pin: pin, salt: record.salt, iterations: record.iterations)
            if Self.constantTimeEqual(candidate, record.hash) {
                record.failures = 0
                record.lockedUntil = nil
                _ = save(record, profileId)
                return .ok
            }
            record.failures += 1
            let lock = Self.lockDuration(forFailures: record.failures)
            if lock > 0 {
                record.lockedUntil = now.addingTimeInterval(lock)
                _ = save(record, profileId)
                return .lockedOut(until: record.lockedUntil!)
            }
            _ = save(record, profileId)
            return .wrong(attemptsBeforeLock: max(0, Self.freeAttempts + 1 - record.failures))
        }
    }

    /// 生物辨識成功之後呼叫：把輸錯次數歸零（人確實是本人）。
    public func noteBiometricSuccess(for profileId: String) {
        queue.sync {
            guard var record = load(profileId) else { return }
            record.failures = 0
            record.lockedUntil = nil
            _ = save(record, profileId)
        }
    }

    // MARK: - 內部

    private func load(_ profileId: String) -> Record? {
        guard let data = store.read(account: account(profileId)) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    private func save(_ record: Record, _ profileId: String) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else { return false }
        return store.write(data, account: account(profileId))
    }

    static func derive(pin: String, salt: Data, iterations: Int) -> Data {
        var derived = Data(count: 32)
        let pinBytes = Array(pin.utf8)
        _ = derived.withUnsafeMutableBytes { out in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pinBytes.map { Int8(bitPattern: $0) }, pinBytes.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                    out.bindMemory(to: UInt8.self).baseAddress!, 32)
            }
        }
        return derived
    }

    static func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a, b) { diff |= x ^ y }
        return diff == 0
    }
}

// MARK: - 生物辨識

public enum ProfileBiometrics {
    /// 這台裝置能不能用生物辨識（有硬體、而且使用者註冊過）。
    public static func isAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// 要求生物辨識。**只認生物辨識，不退到裝置密碼** —— 裝置密碼是全家都知道的，
    /// 退到它等於整個鎖形同虛設（見 `ProfileLockService` 檔頭）。失敗就回 false，由呼叫端改問 PIN。
    public static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

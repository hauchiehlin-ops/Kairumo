//
//  Profile.swift
//  Kairumo
//
//  多設定檔（profile）的資料模型與規則。
//
//  # 這一層只管「有哪些設定檔、各自的設定」
//
//  不碰任何檔案、不碰 UserDefaults 的使用者資料 —— 那些由 `ProfileContext` 依「現在是哪個設定檔」
//  決定放在哪裡。這裡是純資料與規則，所以可以不啟動 App 就完整測試：
//  上限 5 個、名稱不可空白或重複、一個 Google 帳號只能綁一個設定檔、不能刪掉最後一個。
//
//  # 預設設定檔
//
//  `ProfileRecord.defaultId`（`"default"`）永遠對應**升級前就存在的那一份資料**：
//  它的檔案位置、偏好設定、Keychain 項目全部維持原樣，既有使用者升級後沒有任何東西被搬動。
//  只有「新增」的設定檔才會用新的位置。

import Foundation

/// 設定檔鎖。**PIN 是基礎，生物辨識只是它上面的捷徑。**
///
/// 生物辨識不能單獨存在：Face ID／Touch ID 可能被使用者重設、移除或暫時失效，
/// 那時候沒有 PIN 就等於把人鎖死在自己的資料外面。要有 PIN 才能加生物辨識。
public struct ProfileLock: Codable, Equatable, Sendable {
    /// 這個設定檔設了 PIN（雜湊存在 Keychain，不在這裡）。
    public var hasPIN: Bool
    /// 用生物辨識代替輸入 PIN。只有 `hasPIN` 為 true 時才有意義。
    public var useBiometrics: Bool

    public static let none = ProfileLock(hasPIN: false, useBiometrics: false)

    public init(hasPIN: Bool = false, useBiometrics: Bool = false) {
        self.hasPIN = hasPIN
        self.useBiometrics = hasPIN && useBiometrics
    }

    public var isEnabled: Bool { hasPIN }
}

/// 一個設定檔：一個獨立的使用者環境（自己的筆記、偏好、雲端帳號、同步身分）。
public struct ProfileRecord: Codable, Equatable, Identifiable, Sendable {
    /// 升級前就存在的那一份資料的 id。永遠不改。
    public static let defaultId = "default"

    public var id: String
    public var displayName: String
    public var colorHex: String
    public var createdAt: Date
    public var lastActiveAt: Date
    public var lock: ProfileLock
    /// 綁定的 Google 帳號（小寫）。**一個帳號只能綁一個設定檔** —— 範例筆記的 id 是固定的，
    /// 兩個設定檔登入同一個帳號，雲端上的筆記就混在一起了。
    public var googleEmail: String?

    public var isDefault: Bool { id == Self.defaultId }

    public init(
        id: String, displayName: String, colorHex: String,
        createdAt: Date = Date(), lastActiveAt: Date = Date(),
        lock: ProfileLock = .none, googleEmail: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.lock = lock
        self.googleEmail = googleEmail
    }
}

public enum ProfileError: Error, Equatable {
    /// 已經有 `ProfileRegistry.maxProfiles` 個設定檔。
    case limitReached
    case invalidName
    case duplicateName
    case notFound
    /// 不能刪掉最後一個設定檔 —— 沒有設定檔就沒有地方放資料。
    case lastProfile
    /// 這個 Google 帳號已經綁在另一個設定檔上（附該設定檔的名稱，給畫面顯示）。
    case googleAlreadyBound(profileName: String)
    case invalidPIN
    case pinRequired
}

/// 所有設定檔與「現在是哪一個」。純資料，可編碼存檔。
public struct ProfileRegistry: Codable, Equatable, Sendable {
    public static let maxProfiles = 5
    public static let maxNameLength = 24

    public private(set) var profiles: [ProfileRecord]
    public private(set) var activeId: String

    /// 第一次使用：只有預設設定檔（它對應既有的資料，見檔頭說明）。
    public static func initial(displayName: String, colorHex: String, now: Date = Date()) -> ProfileRegistry {
        let name = normalized(displayName)
        let record = ProfileRecord(
            id: ProfileRecord.defaultId,
            displayName: name.isEmpty ? "Kairumo" : name,
            colorHex: colorHex, createdAt: now, lastActiveAt: now)
        return ProfileRegistry(profiles: [record], activeId: record.id)
    }

    init(profiles: [ProfileRecord], activeId: String) {
        self.profiles = profiles
        self.activeId = activeId
    }

    // MARK: - 查詢

    public var active: ProfileRecord {
        profiles.first { $0.id == activeId } ?? profiles[0]
    }

    public func profile(id: String) -> ProfileRecord? {
        profiles.first { $0.id == id }
    }

    public var canAdd: Bool { profiles.count < Self.maxProfiles }

    /// 綁著這個 Google 帳號的設定檔（有的話）。
    public func profile(boundTo email: String) -> ProfileRecord? {
        let key = Self.normalizedEmail(email)
        guard !key.isEmpty else { return nil }
        return profiles.first { $0.googleEmail == key }
    }

    // MARK: - 變更

    /// 新增一個設定檔。回傳新設定檔（**不會**自動切過去）。
    @discardableResult
    public mutating func add(
        displayName: String, colorHex: String? = nil, now: Date = Date(), id: String = UUID().uuidString.lowercased()
    ) throws -> ProfileRecord {
        guard canAdd else { throw ProfileError.limitReached }
        let name = try validatedName(displayName)
        let used = Set(profiles.map(\.colorHex))
        let color = colorHex
            ?? IdentityPalette.hexes.first { !used.contains($0) }
            ?? IdentityPalette.defaultHex
        let record = ProfileRecord(
            id: id, displayName: name, colorHex: color, createdAt: now, lastActiveAt: now)
        profiles.append(record)
        return record
    }

    public mutating func rename(id: String, to displayName: String) throws {
        let name = try validatedName(displayName, excluding: id)
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw ProfileError.notFound }
        profiles[index].displayName = name
    }

    public mutating func setColor(id: String, hex: String) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw ProfileError.notFound }
        profiles[index].colorHex = hex
    }

    /// 刪除設定檔。刪掉的若是目前使用的，改成最近用過的另一個。
    /// 呼叫端負責**實際清掉資料**（檔案、偏好設定、Keychain）—— 這裡只管名單。
    @discardableResult
    public mutating func remove(id: String) throws -> ProfileRecord {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw ProfileError.notFound }
        guard profiles.count > 1 else { throw ProfileError.lastProfile }
        let removed = profiles.remove(at: index)
        if activeId == id {
            activeId = profiles.max { $0.lastActiveAt < $1.lastActiveAt }?.id ?? profiles[0].id
        }
        return removed
    }

    public mutating func activate(id: String, now: Date = Date()) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw ProfileError.notFound }
        activeId = id
        profiles[index].lastActiveAt = now
    }

    public mutating func setLock(id: String, _ lock: ProfileLock) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw ProfileError.notFound }
        profiles[index].lock = ProfileLock(hasPIN: lock.hasPIN, useBiometrics: lock.useBiometrics)
    }

    /// 把 Google 帳號綁到設定檔。已經綁在**別的**設定檔上就拒絕。
    public mutating func bindGoogle(email: String, to id: String) throws {
        let key = Self.normalizedEmail(email)
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw ProfileError.notFound }
        guard !key.isEmpty else { return }
        if let other = profiles.first(where: { $0.googleEmail == key && $0.id != id }) {
            throw ProfileError.googleAlreadyBound(profileName: other.displayName)
        }
        profiles[index].googleEmail = key
    }

    public mutating func unbindGoogle(id: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].googleEmail = nil
    }

    // MARK: - 驗證

    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func validatedName(_ raw: String, excluding id: String? = nil) throws -> String {
        let name = Self.normalized(raw)
        guard !name.isEmpty, name.count <= Self.maxNameLength else { throw ProfileError.invalidName }
        let clash = profiles.contains {
            $0.id != id && $0.displayName.caseInsensitiveCompare(name) == .orderedSame
        }
        guard !clash else { throw ProfileError.duplicateName }
        return name
    }

    /// 載入後的自我修復：名單不能是空的、使用中的 id 必須存在、同一個 Google 帳號不能出現兩次。
    /// 檔案可能被舊版、手動編輯或半途寫壞 —— 寧可修成一個合法狀態，也不要讓 App 開不起來。
    func repaired(fallbackName: String, fallbackColor: String) -> ProfileRegistry {
        var list = profiles
        if list.isEmpty {
            return ProfileRegistry.initial(displayName: fallbackName, colorHex: fallbackColor)
        }
        var seen = Set<String>()
        list = list.filter { seen.insert($0.id).inserted }
        var boundEmails = Set<String>()
        for index in list.indices {
            if let email = list[index].googleEmail, !boundEmails.insert(email).inserted {
                list[index].googleEmail = nil
            }
        }
        if list.count > Self.maxProfiles {
            list = Array(list.prefix(Self.maxProfiles))
        }
        let active = list.contains { $0.id == activeId } ? activeId : list[0].id
        return ProfileRegistry(profiles: list, activeId: active)
    }
}

/// 名單的存檔。放在**任何設定檔的資料根目錄之外** —— 它是整台裝置共用的。
public struct ProfileRegistryStorage {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// 預設位置：`Application Support/Kairumo/profiles_v1.json`。
    public static var standardURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Kairumo", directoryHint: .isDirectory)
            .appending(path: "profiles_v1.json")
    }

    /// 讀取。檔案不存在 → `nil`（呼叫端建立初始名單）。壞掉的檔案留一份 `.corrupt` 再當成不存在，
    /// 不直接覆蓋 —— 那裡面可能是使用者唯一的設定檔名單。
    public func load() -> ProfileRegistry? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let registry = try? decoder.decode(ProfileRegistry.self, from: data) {
            return registry
        }
        let backup = fileURL.deletingLastPathComponent().appending(path: "profiles_v1.corrupt.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: fileURL, to: backup)
        return nil
    }

    public func save(_ registry: ProfileRegistry) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(registry).write(to: fileURL, options: .atomic)
    }
}

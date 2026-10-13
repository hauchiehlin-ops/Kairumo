//
//  ProfileManagerOperations.swift
//  Kairumo
//
//  設定檔的管理操作：新增、重新命名、刪除、鎖、Google 帳號綁定。
//  （切換引擎在 `ProfileManager.swift`。）

import Foundation
import SwiftUI

extension ProfileManager {
    // MARK: - 新增

    /// 新增一個設定檔（**不會**自動切過去）。新設定檔從一個乾淨的環境開始：
    /// 自己的筆記庫（第一次打開時放範例筆記）、自己的偏好、自己的同步身分。
    @discardableResult
    public func createProfile(name: String, colorHex: String? = nil) throws -> ProfileRecord {
        var next = registry
        let record = try next.add(displayName: name, colorHex: colorHex)
        try storage.save(next)
        registry = next

        // 新設定檔的起點：協作身分（名稱與顏色）、語言沿用建立者目前的 —— 兩個人共用一台裝置，
        // 多半是同一種語言，一開始就看到另一種語言的介面是最糟的第一印象。
        let defaults = ProfileDefaults(profileId: record.id)
        if let data = try? JSONEncoder().encode(UserProfile(displayName: record.displayName, colorHex: record.colorHex)) {
            defaults.set(data, forKey: "kairumo.user.profile")
        }
        defaults.set(record.displayName, forKey: "kairumo.user.customDisplayName")
        defaults.set(LocalizationManager.shared.currentLanguage.rawValue, forKey: "kairumo.app.language")
        return record
    }

    // MARK: - 重新命名與顏色

    public func renameProfile(id: String, to name: String) throws {
        var next = registry
        try next.rename(id: id, to: name)
        try storage.save(next)
        registry = next
        let trimmed = next.profile(id: id)?.displayName ?? name
        syncIdentity(id: id) { $0.displayName = trimmed }
    }

    /// 使用中的設定檔登入了 Google：設定檔名稱跟著雲端帳號名稱（與首頁身分卡的既有規則一致 ——
    /// 有登入雲端就以該帳號名稱為使用者名稱）。名稱與別的設定檔重複、或存不進去時維持原名，不打擾使用者。
    public func adoptCloudAccountName(_ cloudName: String) {
        let trimmed = String(cloudName.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(ProfileRegistry.maxNameLength))
        guard !trimmed.isEmpty, registry.active.displayName != trimmed else { return }
        try? renameProfile(id: registry.activeId, to: trimmed)
    }

    public func setProfileColor(id: String, hex: String) throws {
        var next = registry
        try next.setColor(id: id, hex: hex)
        try storage.save(next)
        registry = next
        syncIdentity(id: id) { $0.colorHex = hex }
    }

    /// 設定檔的名稱與顏色同時是協作身分（游標與留言者標記）。兩邊不同步的話，
    /// 選單上叫「小明」的人在協作畫面上卻叫別的名字。
    private func syncIdentity(id: String, _ change: (inout UserProfile) -> Void) {
        if id == registry.activeId {
            var profile = AccountManager.shared.profile
            change(&profile)
            AccountManager.shared.profile = profile
            if !profile.displayName.isEmpty { AccountManager.shared.customDisplayName = profile.displayName }
            return
        }
        let defaults = ProfileDefaults(profileId: id)
        let current = defaults.data(forKey: "kairumo.user.profile")
            .flatMap { try? JSONDecoder().decode(UserProfile.self, from: $0) }
            ?? UserProfile(displayName: registry.profile(id: id)?.displayName ?? "")
        var updated = current
        change(&updated)
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: "kairumo.user.profile")
            defaults.set(updated.displayName, forKey: "kairumo.user.customDisplayName")
        }
    }

    // MARK: - 刪除

    /// 刪除一個設定檔：**它的所有資料**（筆記、偏好、登入、PIN、同步快取）。不可復原，呼叫端要先讓使用者確認。
    ///
    /// 雲端上的那份**不動** —— 刪除設定檔是「這台裝置不再有這個人」，不是「這個人的雲端資料不要了」。
    /// 用同一個 Google 帳號重新建立設定檔並登入，筆記就會回來。
    public func deleteProfile(id: String) throws {
        guard id != registry.activeId else { throw ProfileError.cannotDeleteActive }
        var next = registry
        let removed = try next.remove(id: id)  // 預設設定檔、最後一個、不存在，都在這裡擋下
        try storage.save(next)
        registry = next

        for url in ProfileContext.ownedDirectories(for: removed.id) {
            try? FileManager.default.removeItem(at: url)
        }
        ProfileDefaults.removeAll(forProfile: removed.id)
        KeychainTokens.clear(account: ProfileContext.scopedAccount("tokens", for: removed.id))
        if let email = removed.googleEmail { LanKeychain.delete(account: email) }
        lockService.clearPIN(for: removed.id)
        let syncDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kairumo/sync", isDirectory: true)
            .appending(path: removed.id, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: syncDir)
    }

    // MARK: - 鎖

    /// 設定 PIN（新設定或更換）。要更換**既有**的 PIN 時，呼叫端要先用 `verifyPIN` 確認舊的。
    public func setPIN(_ pin: String, for id: String) throws {
        guard registry.profile(id: id) != nil else { throw ProfileError.notFound }
        guard try lockService.setPIN(pin, for: id) else { throw ProfileError.pinStorageFailed }
        var next = registry
        let useBio = next.profile(id: id)?.lock.useBiometrics ?? false
        try next.setLock(id: id, ProfileLock(hasPIN: true, useBiometrics: useBio))
        try storage.save(next)
        registry = next
    }

    /// 移除鎖（PIN 與生物辨識一起）。**需要目前的 PIN** —— 否則走過來的人按一下就把你的鎖拿掉了。
    public func removeLock(for id: String, currentPIN: String) throws {
        guard case .ok = lockService.verify(currentPIN, for: id) else { throw ProfileError.wrongPIN }
        lockService.clearPIN(for: id)
        var next = registry
        try next.setLock(id: id, .none)
        try storage.save(next)
        registry = next
        if id == registry.activeId { isLocked = false }
    }

    public func setBiometrics(_ enabled: Bool, for id: String) throws {
        guard let record = registry.profile(id: id) else { throw ProfileError.notFound }
        guard record.lock.hasPIN else { throw ProfileError.pinRequired }
        var next = registry
        try next.setLock(id: id, ProfileLock(hasPIN: true, useBiometrics: enabled))
        try storage.save(next)
        registry = next
    }

    public func verifyPIN(_ pin: String, for id: String) -> PINVerifyResult {
        lockService.verify(pin, for: id)
    }

    /// 解鎖**目前使用中**的設定檔。成功回 `.ok`。
    @discardableResult
    public func unlockActive(pin: String) -> PINVerifyResult {
        let result = lockService.verify(pin, for: registry.activeId)
        if result == .ok { isLocked = false }
        return result
    }

    /// 用生物辨識解鎖（任一個設定檔，切換前用）。只認生物辨識，不退到裝置密碼。
    public func authenticateWithBiometrics(for id: String, reason: String) async -> Bool {
        guard registry.profile(id: id)?.lock.useBiometrics == true else { return false }
        let ok = await ProfileBiometrics.authenticate(reason: reason)
        if ok { lockService.noteBiometricSuccess(for: id) }
        return ok
    }

    public func unlockActiveWithBiometrics(reason: String) async -> Bool {
        let ok = await authenticateWithBiometrics(for: registry.activeId, reason: reason)
        if ok { isLocked = false }
        return ok
    }

    // MARK: - Google 帳號：一個帳號只能綁一個設定檔

    /// 目前設定檔登入了某個 Google 帳號：綁上去。已經綁在**別的**設定檔上就丟錯（呼叫端要登出）。
    public func bindGoogle(email: String) throws {
        var next = registry
        try next.bindGoogle(email: email, to: registry.activeId)
        if next != registry {
            try storage.save(next)
            registry = next
        }
    }

    /// 目前設定檔登出：解除綁定，帳號可以讓別的設定檔用。
    public func unbindGoogle() {
        var next = registry
        next.unbindGoogle(id: registry.activeId)
        if next != registry {
            try? storage.save(next)
            registry = next
        }
    }
}

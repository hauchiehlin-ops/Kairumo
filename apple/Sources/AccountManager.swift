//
//  AccountManager.swift
//  Kairumo
//
//  協作身分管理員
//
//  這裡**沒有帳號系統**：名稱與顏色純粹用來在多人協作時顯示「誰在編輯」，
//  只存在本機 UserDefaults，不連任何雲端服務，也不讀取作業系統帳號。
//

import SwiftUI
import Combine

/// 協作身分。
///
/// 刻意只有兩個欄位。舊版還有 `username` / `email` / `isLoggedIn` /
/// `syncStatusText`，那些是帳號系統的殘留物 —— 本 App 沒有後端也沒有登入流程，
/// 留著只會讓畫面顯示「已登入」這種不成立的狀態。
/// 多人協作要顯示的就兩件事：**叫什麼名字、用什麼顏色**。
public struct UserProfile: Codable, Equatable {
    public var displayName: String
    /// 游標、選取框與留言者標記的顏色。
    public var colorHex: String

    public init(displayName: String, colorHex: String = IdentityPalette.defaultHex) {
        self.displayName = displayName
        self.colorHex = colorHex
    }
}

/// 可選的身分顏色。
///
/// 固定一組而非任意調色盤：協作時顏色要能互相區辨，
/// 讓人自由選會出現兩個人都挑到相近的灰。
public enum IdentityPalette {
    public static let hexes = [
        "#007AFF", "#34C759", "#AF52DE", "#FF9500",
        "#FF2D55", "#5856D6", "#00C7BE", "#A2845E"
    ]
    public static let defaultHex = "#007AFF"
}

/// 協作身分管理中樞
@MainActor
public final class AccountManager: ObservableObject {
    public static let shared = AccountManager()

    private let profileKey = "kairumo.user.profile"
    private let customNameKey = "kairumo.user.customDisplayName"
    private var cancellables = Set<AnyCancellable>()

    @Published public var profile: UserProfile {
        didSet { saveProfile() }
    }

    /// 使用者自訂編輯的名稱（未進行同步登入時使用）
    public var customDisplayName: String {
        get {
            UserDefaults.standard.string(forKey: customNameKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: customNameKey)
        }
    }

    public enum CloudProviderPreference: String, CaseIterable {
        case iCloud = "iCloud"
        case googleDrive = "google"
    }

    private let cloudPrefKey = "kairumo.account.cloudProviderPreference"

    /// 若兩者（Google Drive 與 iCloud）同時登錄時的偏好。預設以 Apple (iCloud) 名稱為優先。
    public var cloudProviderPreference: CloudProviderPreference {
        get {
            if let saved = UserDefaults.standard.string(forKey: cloudPrefKey),
               let pref = CloudProviderPreference(rawValue: saved) {
                return pref
            }
            return .iCloud
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: cloudPrefKey)
            refreshDisplayName()
        }
    }

    /// 是否同時登入 iCloud 與 Google Drive
    public var hasBothCloudsSignedIn: Bool {
        isICloudSignedIn && GoogleAuth.shared.isSignedIn
    }

    /// Google Drive 帳號名稱（若登入且已獲取）
    public var googleAccountName: String? {
        guard GoogleAuth.shared.isSignedIn else { return nil }
        if let name = GoogleAuth.shared.accountName, !name.isEmpty {
            return name
        }
        if let email = GoogleAuth.shared.accountEmail, !email.isEmpty {
            return email
        }
        Task {
            await GoogleAuth.shared.refreshAccountEmail()
        }
        return nil
    }

    /// 目前生效的雲端帳號名稱（Google Drive 或 iCloud）。
    /// 未進行同步登入時為 nil。
    /// 若兩者（Google Drive 與 iCloud）同時登錄，以 Apple (iCloud) 帳戶名稱為預設。
    public var activeCloudAccountName: String? {
        let hasICloud = isICloudSignedIn
        let hasGoogle = GoogleAuth.shared.isSignedIn

        if hasICloud && hasGoogle {
            // 兩者同時登錄：預設為 Apple (iCloud)
            if cloudProviderPreference == .googleDrive {
                return googleAccountName
            } else {
                return iCloudAccountName
            }
        }

        // 僅登入 iCloud
        if hasICloud {
            return iCloudAccountName
        }

        // 僅登入 Google Drive
        if hasGoogle {
            return googleAccountName
        }

        return nil
    }

    /// 目前生效的雲端服務標籤（iCloud 或 Google Drive）
    public var activeCloudProviderBadge: String? {
        let hasICloud = isICloudSignedIn
        let hasGoogle = GoogleAuth.shared.isSignedIn

        if hasICloud && hasGoogle {
            return cloudProviderPreference == .googleDrive ? "Google Drive" : "iCloud"
        }
        if hasICloud {
            return "iCloud"
        }
        if hasGoogle {
            return "Google Drive"
        }
        return nil
    }

    /// 是否在 Kairumo 啟用了 iCloud / 資料夾雲端同步。
    /// 只有在使用者實際設定了同步資料夾、且資料夾位於 iCloud 範圍或已啟用時才成立。
    /// 未設定同步資料夾時絕對不應視為已登入 iCloud。
    public var isICloudSignedIn: Bool {
        guard let folder = CloudSyncFolder.resolveFolder() else {
            return false
        }
        return DocumentStorageLocation.isICloudSynced(folder)
            || folder.path.contains("/Mobile Documents/")
            || folder.path.contains("com~apple~CloudDocs")
    }

    /// 從裝置名稱解析出 Apple 帳號名稱（支援中文、英文、日文及歐洲語系命名）
    public static func extractAppleAccountName(fromDeviceName deviceName: String) -> String? {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern1 = #"^(.*?)(?:'s|’s|\s*的|\s*の)\s*(?:iPhone|iPad|iPod|Mac|Apple\s*Watch).*"#
        if let regex = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)),
           let range = Range(match.range(at: 1), in: trimmed) {
            let extracted = String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidAppleAccountName(extracted) {
                return extracted
            }
            return nil
        }
        let pattern2 = #"^(?:iPhone|iPad|iPod|Mac)\s*(?:von|de|de\s+la)\s*(.*)"#
        if let regex = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)),
           let range = Range(match.range(at: 1), in: trimmed) {
            let extracted = String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidAppleAccountName(extracted) {
                return extracted
            }
            return nil
        }
        if isValidAppleAccountName(trimmed) {
            return trimmed
        }
        return nil
    }

    /// 檢驗是否為有效的 Apple 帳號顯示名稱（過濾常見裝置型號或系統預設佔位名稱）
    public static func isValidAppleAccountName(_ name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return false }
        let lower = clean.lowercased()
        let invalid = [
            "iphone", "ipad", "ipod", "mac", "apple", "apple watch",
            "mobile user", "mobil user", "mobile", "user", "root",
            "mobileuser", "admin", "administrator", "guest", "default"
        ]
        if invalid.contains(lower) {
            return false
        }
        if lower.contains("mobile user") || lower.contains("mobil user") || lower.contains("mobileuser") {
            return false
        }
        if lower.contains("iphone") || lower.contains("ipad") || lower.contains("ipod") || lower.contains("apple watch") {
            return false
        }
        return true
    }

    /// 取得 iCloud 帳號名稱
    public var iCloudAccountName: String {
        // Mac / Mac Catalyst 上，系統使用者全名即為 Apple/iCloud 帳號名稱
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if AccountManager.isValidAppleAccountName(fullName) {
            return fullName
        }

        #if canImport(UIKit)
        if let extracted = AccountManager.extractAppleAccountName(fromDeviceName: UIDevice.current.name) {
            return extracted
        }
        #endif

        let userName = NSUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if AccountManager.isValidAppleAccountName(userName) {
            return userName
        }

        return "iCloud"
    }

    /// 根據同步登入狀態刷新名稱：
    /// 若有登入 Google Drive 或 iCloud，自動以該帳號名稱為使用者名稱；
    /// 若兩者同時登入，以 Apple (iCloud) 為預設；
    /// 若無同步登入，維持現狀（使用者自訂名稱）。
    public func refreshDisplayName() {
        if let cloudName = activeCloudAccountName, !cloudName.isEmpty {
            if profile.displayName != cloudName {
                profile.displayName = cloudName
            }
        } else if GoogleAuth.shared.isSignedIn && (!isICloudSignedIn || cloudProviderPreference == .googleDrive) {
            Task {
                await GoogleAuth.shared.refreshAccountEmail()
            }
        } else {
            let manual = customDisplayName.isEmpty
                ? LocalizationManager.shared.localized("default_user_name")
                : customDisplayName
            if profile.displayName != manual {
                profile.displayName = manual
            }
        }
    }

    private init() {
        if let savedData = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
            self.profile = decoded
            if UserDefaults.standard.string(forKey: customNameKey) == nil {
                self.customDisplayName = decoded.displayName
            }
        } else {
            // 舊版可能存過含 username/email 的格式，欄位對不上就解不出來。
            // 盡量把名字撈回來，撈不到就用預設值，不去讀系統帳號。
            let legacyName = (UserDefaults.standard.data(forKey: profileKey))
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .flatMap { $0?["displayName"] as? String }
            let initial = legacyName ?? LocalizationManager.shared.localized("default_user_name")
            self.profile = UserProfile(displayName: initial)
            self.customDisplayName = initial
        }
        cleanUpLegacyKeys()
        #if canImport(UIKit)
        let isPlaceholder = !AccountManager.isValidAppleAccountName(profile.displayName)
            || profile.displayName == UIDevice.current.name
        if isPlaceholder {
            if GoogleAuth.shared.isSignedIn {
                profile.displayName = GoogleAuth.shared.accountName
                    ?? GoogleAuth.shared.accountEmail
                    ?? LocalizationManager.shared.localized("default_user_name")
            } else if !customDisplayName.isEmpty && AccountManager.isValidAppleAccountName(customDisplayName) {
                profile.displayName = customDisplayName
            } else {
                profile.displayName = LocalizationManager.shared.localized("default_user_name")
            }
        }
        #endif
        refreshDisplayName()

        // 監聽 Google 帳號狀態變化，一旦背景非同步取得或登入/登出，立即自動刷新名稱
        GoogleAuth.shared.$accountName
            .combineLatest(GoogleAuth.shared.$accountEmail, GoogleAuth.shared.$isSignedIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDisplayName()
            }
            .store(in: &cancellables)

        // 監聽同步資料夾設定變化（設定或清除 iCloud/資料夾同步）
        CloudSyncFolderMonitor.shared.$currentFolder
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDisplayName()
            }
            .store(in: &cancellables)
    }

    /// 清掉訪客模式時代留下的鍵，避免舊狀態在未來被誤讀。
    private func cleanUpLegacyKeys() {
        for key in ["kairumo.user.profile.beforeGuest", "kairumo.user.isGuest"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
        }
    }

    /// 更新顯示名稱。空白會退回預設名 —— 協作中出現一個沒有名字的游標最難辨認。
    public func updateDisplayName(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = clean.isEmpty
            ? LocalizationManager.shared.localized("default_user_name")
            : clean
        customDisplayName = resolved
        if activeCloudAccountName == nil {
            profile.displayName = resolved
        }
    }

    public func updateColor(_ hex: String) {
        profile.colorHex = hex
    }
}

/// 協作身分編輯視圖
public struct AccountProfileSheet: View {
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var googleAuth = GoogleAuth.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var tempDisplayName: String = ""
    @State private var tempColorHex: String = IdentityPalette.defaultHex

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: tempColorHex) ?? .blue)
                                .frame(width: 60, height: 60)
                            Text(String(tempDisplayName.prefix(1)).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(tempDisplayName.isEmpty
                                 ? localizationManager.localized("default_user_name")
                                 : tempDisplayName)
                                .font(.headline)
                            Text(localizationManager.localized("identity_preview_hint"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)

                    if let cloudName = accountManager.activeCloudAccountName {
                        HStack {
                            Text(localizationManager.localized("display_name"))
                                .frame(width: 80, alignment: .leading)
                            Text(cloudName)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(accountManager.activeCloudProviderBadge ?? (GoogleAuth.shared.isSignedIn ? "Google Drive" : "iCloud"))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }

                        if accountManager.hasBothCloudsSignedIn {
                            Picker(localizationManager.currentLanguage == .zhHant ? "同步身分來源" : "Identity Source", selection: Binding(
                                get: { accountManager.cloudProviderPreference },
                                set: { pref in
                                    accountManager.cloudProviderPreference = pref
                                    tempDisplayName = accountManager.activeCloudAccountName ?? tempDisplayName
                                }
                            )) {
                                Text("Apple (iCloud)").tag(AccountManager.CloudProviderPreference.iCloud)
                                Text("Google Drive").tag(AccountManager.CloudProviderPreference.googleDrive)
                            }
                            .pickerStyle(.segmented)
                            .padding(.top, 4)
                        }
                    } else if GoogleAuth.shared.isSignedIn {
                        HStack {
                            Text(localizationManager.localized("display_name"))
                                .frame(width: 80, alignment: .leading)
                            Text(GoogleAuth.shared.accountEmail ?? "...")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Google Drive")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    } else {
                        HStack {
                            Text(localizationManager.localized("display_name"))
                                .frame(width: 80, alignment: .leading)
                            TextField(localizationManager.localized("display_name"), text: $tempDisplayName)
                        }
                    }
                } header: {
                    Text(localizationManager.localized("identity_title"))
                } footer: {
                    if accountManager.hasBothCloudsSignedIn {
                        Text(localizationManager.currentLanguage == .zhHant
                             ? "已同時登入 iCloud 與 Google Drive，預設採用 Apple (iCloud) 帳號名稱，可自由切換。"
                             : "Both iCloud and Google Drive are signed in. Apple (iCloud) name is used by default.")
                    } else if accountManager.activeCloudAccountName != nil {
                        Text(localizationManager.currentLanguage == .zhHant
                             ? "已登入同步帳號，首頁「使用者」名稱已自動採用該帳號名稱。"
                             : localizationManager.localized("identity_desc"))
                    } else {
                        // 講清楚這不是帳號，免得使用者以為需要註冊或擔心資料上傳。
                        Text(localizationManager.localized("identity_desc"))
                    }
                }

                Section(localizationManager.localized("identity_color")) {
                    let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(IdentityPalette.hexes, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: tempColorHex == hex ? 3 : 0)
                                )
                                .onTapGesture { tempColorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(localizationManager.localized("preferences_lang")) {
                    Picker(localizationManager.localized("language"), selection: $localizationManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.endonym).tag(lang)
                        }
                    }

                    Button {
                        AudioRecorderManager.shared.openRecordingsFolderInFinder()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                            Text(localizationManager.localized("open_folder"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(localizationManager.localized("security")) {
                    HStack {
                        Text(localizationManager.localized("storage_location"))
                        Spacer()
                        Text("Documents / Kairumo Record") // i18n-ok: 檔案系統路徑，不是文字
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    // **這一列講的是「資料去了哪裡」，不是「資料有加密」。**
                    //
                    // 原本的字是「資料加密 / 端對端本地隔離」，而套件實際上
                    // 一律是 `Encryption::None` —— `padnote-crypto` 的信封加密
                    // 寫好了，但**沒有任何 FFI 出口**，平台根本呼叫不到。
                    //
                    // 一行會被讀成「內容有加密」的字，比沒有這一行更糟：
                    // 使用者會據此決定要不要把敏感內容寫進來。
                    // 等加密真的接上（見 docs/TODO.md 的 H-CRYPTO）再改回去。
                    HStack {
                        Text(localizationManager.localized("encryption"))
                        Spacer()
                        Text(localizationManager.localized("encryption_desc"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(localizationManager.localized("identity_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("save")) {
                        if !GoogleAuth.shared.isSignedIn && accountManager.activeCloudAccountName == nil {
                            accountManager.updateDisplayName(tempDisplayName)
                        }
                        accountManager.updateColor(tempColorHex)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if GoogleAuth.shared.isSignedIn {
                    Task {
                        await GoogleAuth.shared.refreshAccountEmail()
                    }
                }
                tempDisplayName = accountManager.activeCloudAccountName ?? (accountManager.customDisplayName.isEmpty ? accountManager.profile.displayName : accountManager.customDisplayName)
                tempColorHex = accountManager.profile.colorHex
            }
        }
    }
}

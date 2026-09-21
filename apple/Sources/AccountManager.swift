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

    @Published public var profile: UserProfile {
        didSet { saveProfile() }
    }

    private init() {
        if let savedData = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
            self.profile = decoded
        } else {
            // 舊版可能存過含 username/email 的格式，欄位對不上就解不出來。
            // 盡量把名字撈回來，撈不到就用預設值，不去讀系統帳號。
            let legacyName = (UserDefaults.standard.data(forKey: profileKey))
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .flatMap { $0?["displayName"] as? String }
            self.profile = UserProfile(
                displayName: legacyName ?? LocalizationManager.shared.localized("default_user_name")
            )
        }
        cleanUpLegacyKeys()
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
        profile.displayName = clean.isEmpty
            ? LocalizationManager.shared.localized("default_user_name")
            : clean
    }

    public func updateColor(_ hex: String) {
        profile.colorHex = hex
    }
}

/// 協作身分編輯視圖
public struct AccountProfileSheet: View {
    @ObservedObject var accountManager = AccountManager.shared
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

                    HStack {
                        Text(localizationManager.localized("display_name"))
                            .frame(width: 80, alignment: .leading)
                        TextField(localizationManager.localized("display_name"), text: $tempDisplayName)
                    }
                } header: {
                    Text(localizationManager.localized("identity_title"))
                } footer: {
                    // 講清楚這不是帳號，免得使用者以為需要註冊或擔心資料上傳。
                    Text(localizationManager.localized("identity_desc"))
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
                        Text("Documents / Kairumo Record")
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
                        accountManager.updateDisplayName(tempDisplayName)
                        accountManager.updateColor(tempColorHex)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                tempDisplayName = accountManager.profile.displayName
                tempColorHex = accountManager.profile.colorHex
            }
        }
    }
}

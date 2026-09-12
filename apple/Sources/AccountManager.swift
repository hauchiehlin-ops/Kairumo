//
//  AccountManager.swift
//  Kairumo
//
//  使用者帳號與登入狀態管理員
//  支援 macOS / iOS / iPadOS 系統帳號名稱讀取與本機持久化
//

import SwiftUI
import Combine

/// 使用者個人設定與帳號資料模型
public struct UserProfile: Codable, Equatable {
    public var displayName: String
    public var username: String
    public var email: String
    public var avatarColorHex: String
    public var isLoggedIn: Bool
    public var syncStatusText: String

    public init(
        displayName: String,
        username: String,
        email: String = "",
        avatarColorHex: String = "#0A84FF",
        isLoggedIn: Bool = true,
        syncStatusText: String = "本地帳號 · 離線優先"
    ) {
        self.displayName = displayName
        self.username = username
        self.email = email
        self.avatarColorHex = avatarColorHex
        self.isLoggedIn = isLoggedIn
        self.syncStatusText = syncStatusText
    }
}

/// 帳號管理中樞
@MainActor
public final class AccountManager: ObservableObject {
    public static let shared = AccountManager()

    private let profileKey = "kairumo.user.profile"

    @Published public var profile: UserProfile {
        didSet {
            saveProfile()
        }
    }

    private init() {
        if let savedData = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
            self.profile = decoded
        } else {
            // 自動讀取系統使用者名稱
            var defaultName = "Barret Lin"
            var defaultUser = "barretlin"

            #if os(macOS) || targetEnvironment(macCatalyst)
            let sysFull = NSFullUserName()
            let sysUser = NSUserName()
            if !sysFull.isEmpty { defaultName = sysFull }
            if !sysUser.isEmpty { defaultUser = sysUser }
            #endif

            self.profile = UserProfile(
                displayName: defaultName,
                username: defaultUser,
                email: "\(defaultUser)@kairumo.local",
                avatarColorHex: "#0A84FF",
                isLoggedIn: true,
                syncStatusText: "本地帳號 · 離線優先"
            )
        }
    }

    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
        }
    }

    /// 更新使用者資訊
    public func updateProfile(displayName: String, email: String) {
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "使用者" : displayName
        profile.email = email
    }
}

/// 使用者個人檔案與帳號設定視圖
public struct AccountProfileSheet: View {
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var tempDisplayName: String = ""
    @State private var tempEmail: String = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section(localizationManager.localized("user_profile")) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 60, height: 60)
                            Text(String(accountManager.profile.displayName.prefix(1)).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(accountManager.profile.displayName)
                                .font(.headline)
                            Text("@\(accountManager.profile.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(accountManager.profile.syncStatusText)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 6)

                    HStack {
                        Text(localizationManager.localized("display_name"))
                            .frame(width: 80, alignment: .leading)
                        TextField(localizationManager.localized("display_name"), text: $tempDisplayName)
                    }

                    HStack {
                        Text(localizationManager.localized("email"))
                            .frame(width: 80, alignment: .leading)
                        TextField(localizationManager.localized("email"), text: $tempEmail)
                    }
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
                        Text(localizationManager.localized("login_status"))
                        Spacer()
                        Text(localizationManager.localized("logged_in"))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(localizationManager.localized("storage_location"))
                        Spacer()
                        Text("Documents / Kairumo Record")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Text(localizationManager.localized("encryption"))
                        Spacer()
                        Text(localizationManager.localized("encryption_desc"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        tempDisplayName = "訪客使用者"
                        tempEmail = "guest@kairumo.local"
                        accountManager.updateProfile(displayName: tempDisplayName, email: tempEmail)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text(localizationManager.localized("guest_account"))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("account_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("save")) {
                        accountManager.updateProfile(displayName: tempDisplayName, email: tempEmail)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                tempDisplayName = accountManager.profile.displayName
                tempEmail = accountManager.profile.email
            }
        }
    }
}

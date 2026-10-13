//
//  ProfileViews.swift
//  Kairumo
//
//  設定檔（使用者）的介面：切換、新增、管理、鎖定畫面。
//
//  這一層只管「畫出來、收使用者的操作」。規則（上限、名稱、PIN 格式）在 `ProfileRegistry` 與
//  `ProfileLockService`，切換引擎在 `ProfileManager` —— 介面不重寫任何一條。

import SwiftUI

// MARK: - 共用小元件

struct ProfileAvatar: View {
    let name: String
    let colorHex: String
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: colorHex) ?? .blue)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 只收數字的 PIN 輸入欄。
private struct PINField: View {
    let title: String
    @Binding var text: String
    var identifier: String

    var body: some View {
        SecureField(title, text: $text)
            .textContentType(.oneTimeCode)  // 不要讓系統跳出「儲存密碼」
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onChange(of: text) { value in
                let digits = value.filter { $0.isASCII && $0.isNumber }
                let clipped = String(digits.prefix(ProfileLockService.maxDigits))
                if clipped != value { text = clipped }
            }
            .accessibilityIdentifier(identifier)
    }
}

private func pinFailureText(_ result: PINVerifyResult) -> String? {
    switch result {
    case .ok, .noPIN:
        return nil
    case let .wrong(left):
        return L10n.f("profile_pin_wrong", left)
    case let .lockedOut(until):
        let seconds = max(1, Int(until.timeIntervalSinceNow.rounded(.up)))
        let text = seconds >= 60 ? "\(seconds / 60):" + String(format: "%02d", seconds % 60) : "\(seconds)"
        return L10n.f("profile_pin_locked", seconds >= 60 ? text : "\(text) s")
    }
}

private func profileErrorText(_ error: Error) -> String {
    switch error {
    case ProfileError.invalidName: return L10n.t("profile_error_name")
    case ProfileError.duplicateName: return L10n.t("profile_error_duplicate")
    case ProfileError.limitReached: return L10n.f("profile_limit_reached", ProfileRegistry.maxProfiles)
    case ProfileError.cannotDeleteDefault: return L10n.t("profile_delete_default")
    case ProfileError.cannotDeleteActive: return L10n.t("profile_delete_active")
    case ProfileError.invalidPIN: return L10n.t("profile_pin_invalid")
    case ProfileError.pinStorageFailed: return L10n.t("profile_error_pin_storage")
    case ProfileError.wrongPIN: return L10n.t("profile_pin_wrong").replacingOccurrences(of: "%1@", with: "0")
    case ProfileManager.SwitchError.syncBusy: return L10n.t("profile_error_busy")
    default: return L10n.t("profile_error_generic")
    }
}

// MARK: - 切換選單

struct ProfilePickerSheet: View {
    @ObservedObject private var manager = ProfileManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var unlockTarget: ProfileRecord?
    @State private var showCreate = false
    @State private var managing: ProfileRecord?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(manager.profiles) { profile in
                        row(profile)
                    }
                }
                Section {
                    Button {
                        showCreate = true
                    } label: {
                        Label(L10n.t("profile_add"), systemImage: "plus.circle.fill")
                    }
                    .disabled(!manager.canAddProfile)
                    .accessibilityIdentifier("profile.add")
                } footer: {
                    if !manager.canAddProfile {
                        Text(L10n.f("profile_limit_reached", ProfileRegistry.maxProfiles))
                    }
                }
            }
            .navigationTitle(L10n.t("profile_picker_title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("done")) { dismiss() }
                        .accessibilityIdentifier("profile.picker.done")
                }
            }
            .sheet(item: $unlockTarget) { target in
                ProfileUnlockSheet(profile: target) {
                    unlockTarget = nil
                    startSwitch(to: target.id)
                }
            }
            .sheet(isPresented: $showCreate) { ProfileCreateSheet { dismiss() } }
            .sheet(item: $managing) { profile in ProfileEditSheet(profileId: profile.id) }
            .alert(
                errorText ?? "",
                isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
            ) {
                Button(L10n.t("confirm"), role: .cancel) {}
            }
        }
        .accessibilityIdentifier("profile.picker")
    }

    private func row(_ profile: ProfileRecord) -> some View {
        let isActive = profile.id == manager.active.id
        return HStack(spacing: 12) {
            Button {
                select(profile)
            } label: {
                HStack(spacing: 12) {
                    ProfileAvatar(name: profile.displayName, colorHex: profile.colorHex)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName).font(.headline).foregroundColor(.primary)
                        Text(subtitle(profile, isActive: isActive))
                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                    } else if profile.lock.isEnabled {
                        Image(systemName: "lock.fill").foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(profile.displayName + (isActive ? "，" + L10n.t("profile_current") : ""))
            .accessibilityIdentifier("profile.row.\(profile.id)")

            Button {
                managing = profile
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.t("profile_manage"))
            .accessibilityIdentifier("profile.manage.\(profile.id)")
        }
    }

    private func subtitle(_ profile: ProfileRecord, isActive: Bool) -> String {
        if isActive { return L10n.t("profile_current") }
        if let email = profile.googleEmail { return email }
        return profile.lock.isEnabled ? L10n.t("profile_lock_on_hint") : ""
    }

    private func select(_ profile: ProfileRecord) {
        guard profile.id != manager.active.id else { dismiss(); return }
        if profile.lock.isEnabled {
            unlockTarget = profile
        } else {
            startSwitch(to: profile.id)
        }
    }

    private func startSwitch(to id: String) {
        dismiss()
        Task { @MainActor in
            do {
                try await ProfileManager.shared.switchTo(id)
            } catch {
                ProfileManager.shared.notice = profileErrorText(error)
            }
        }
    }
}

// MARK: - 解鎖（切換前，或鎖定畫面）

struct ProfileUnlockSheet: View {
    let profile: ProfileRecord
    let onUnlocked: () -> Void
    @ObservedObject private var manager = ProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var message: String?
    @State private var triedBiometrics = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ProfileAvatar(name: profile.displayName, colorHex: profile.colorHex, size: 72)
                Text(L10n.f("profile_unlock_title", profile.displayName)).font(.title3.bold())
                PINField(title: L10n.t("profile_pin_enter"), text: $pin, identifier: "profile.unlock.pin")
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .onSubmit(submit)
                if let message {
                    Text(message).font(.footnote).foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("profile.unlock.message")
                }
                Button(L10n.t("profile_unlock_button"), action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(pin.count < ProfileLockService.minDigits)
                    .accessibilityIdentifier("profile.unlock.button")
                if profile.lock.useBiometrics, ProfileBiometrics.isAvailable() {
                    Button { Task { await tryBiometrics() } } label: {
                        Label(L10n.t("profile_use_biometrics"), systemImage: "faceid")
                    }
                    .accessibilityIdentifier("profile.unlock.biometrics")
                }
                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("cancel")) { dismiss() } }
            }
            .task {
                // 開著就先試一次生物辨識；失敗或取消就留在 PIN 輸入。
                if profile.lock.useBiometrics, !triedBiometrics {
                    triedBiometrics = true
                    await tryBiometrics()
                }
            }
        }
    }

    private func submit() {
        let result = manager.verifyPIN(pin, for: profile.id)
        if result == .ok {
            onUnlocked()
        } else {
            message = pinFailureText(result)
            pin = ""
        }
    }

    private func tryBiometrics() async {
        if await manager.authenticateWithBiometrics(for: profile.id, reason: L10n.t("profile_unlock_biometric_reason")) {
            onUnlocked()
        }
    }
}

// MARK: - 新增

struct ProfileCreateSheet: View {
    var onCreatedAndSwitching: () -> Void
    @ObservedObject private var manager = ProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = IdentityPalette.hexes.first { hex in
        !ProfileManager.shared.profiles.map(\.colorHex).contains(hex)
    } ?? IdentityPalette.defaultHex
    @State private var useLock = false
    @State private var pin = ""
    @State private var pinConfirm = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("profile_name_placeholder"), text: $name)
                        .accessibilityIdentifier("profile.create.name")
                    ColorChoices(selected: $colorHex)
                } header: {
                    Text(L10n.t("profile_name"))
                } footer: {
                    Text(L10n.t("profile_create_footer"))
                }
                Section {
                    Toggle(L10n.t("profile_lock_set"), isOn: $useLock)
                        .accessibilityIdentifier("profile.create.lock")
                    if useLock {
                        PINField(title: L10n.t("profile_pin_new"), text: $pin, identifier: "profile.create.pin")
                        PINField(title: L10n.t("profile_pin_confirm"), text: $pinConfirm, identifier: "profile.create.pin2")
                    }
                } header: {
                    Text(L10n.t("profile_lock_section"))
                } footer: {
                    if useLock { Text(L10n.t("profile_lock_note")) }
                }
                if let errorText {
                    Section { Text(errorText).foregroundColor(.red).accessibilityIdentifier("profile.create.error") }
                }
            }
            .navigationTitle(L10n.t("profile_create_title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("profile_create_button"), action: create)
                        .accessibilityIdentifier("profile.create.confirm")
                }
            }
        }
    }

    private func create() {
        errorText = nil
        if useLock {
            guard ProfileLockService.isValidPIN(pin) else { errorText = L10n.t("profile_pin_invalid"); return }
            guard pin == pinConfirm else { errorText = L10n.t("profile_pin_mismatch"); return }
        }
        do {
            let record = try manager.createProfile(name: name, colorHex: colorHex)
            if useLock {
                do {
                    try manager.setPIN(pin, for: record.id)
                } catch {
                    // 要鎖卻設不上：整個回滾。留下一個「沒有鎖的使用者」比建立失敗更糟 —— 使用者以為上鎖了。
                    try? manager.deleteProfile(id: record.id)
                    throw error
                }
            }
            dismiss()
            onCreatedAndSwitching()
            Task { @MainActor in
                do { try await ProfileManager.shared.switchTo(record.id) }
                catch { ProfileManager.shared.notice = profileErrorText(error) }
            }
        } catch {
            errorText = profileErrorText(error)
        }
    }
}

private struct ColorChoices: View {
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(IdentityPalette.hexes, id: \.self) { hex in
                Button {
                    selected = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .blue)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.primary, lineWidth: selected == hex ? 3 : 0).padding(-3))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(hex)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("profile.colors")
    }
}

// MARK: - 管理

struct ProfileEditSheet: View {
    let profileId: String
    @ObservedObject private var manager = ProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorText: String?
    @State private var showPINSetup = false
    @State private var confirmDelete = false
    @State private var removePIN = ""
    @State private var showRemoveLock = false
    @State private var loaded = false

    private var profile: ProfileRecord? { manager.registry.profile(id: profileId) }

    var body: some View {
        NavigationStack {
            Form {
                if let profile {
                    nameSection(profile)
                    googleSection(profile)
                    lockSection(profile)
                    deleteSection(profile)
                    if let errorText {
                        Section { Text(errorText).foregroundColor(.red) }
                    }
                }
            }
            .navigationTitle(profile?.displayName ?? "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L10n.t("done")) { dismiss() } }
            }
            .onAppear {
                if !loaded { name = profile?.displayName ?? ""; loaded = true }
            }
            .sheet(isPresented: $showPINSetup) { PINSetupSheet(profileId: profileId) }
            .alert(
                L10n.f("profile_delete_title", profile?.displayName ?? ""),
                isPresented: $confirmDelete
            ) {
                Button(L10n.t("profile_delete"), role: .destructive) { delete() }
                Button(L10n.t("cancel"), role: .cancel) {}
            } message: {
                Text(L10n.f("profile_delete_message", profile?.displayName ?? ""))
            }
            .alert(L10n.t("profile_lock_remove"), isPresented: $showRemoveLock) {
                SecureField(L10n.t("profile_pin_current"), text: $removePIN)
                Button(L10n.t("profile_lock_remove"), role: .destructive) { removeLock() }
                Button(L10n.t("cancel"), role: .cancel) { removePIN = "" }
            }
        }
        .accessibilityIdentifier("profile.edit")
    }

    private func nameSection(_ profile: ProfileRecord) -> some View {
        Section {
            HStack {
                TextField(L10n.t("profile_name"), text: $name)
                    .accessibilityIdentifier("profile.edit.name")
                Button(L10n.t("profile_save")) { rename() }
                    .disabled(name.trimmingCharacters(in: .whitespaces) == profile.displayName)
                    .accessibilityIdentifier("profile.edit.save")
            }
            ColorChoices(selected: Binding(
                get: { profile.colorHex },
                set: { try? manager.setProfileColor(id: profile.id, hex: $0) }
            ))
        } header: {
            Text(L10n.t("profile_rename"))
        }
    }

    private func googleSection(_ profile: ProfileRecord) -> some View {
        Section {
            HStack {
                Text(L10n.t("profile_google_account"))
                Spacer()
                Text(profile.googleEmail ?? L10n.t("profile_google_none")).foregroundColor(.secondary)
            }
        }
    }

    private func lockSection(_ profile: ProfileRecord) -> some View {
        Section {
            HStack {
                Text(L10n.t("profile_lock_section"))
                Spacer()
                Text(lockStateText(profile.lock)).foregroundColor(.secondary)
            }
            Button(profile.lock.hasPIN ? L10n.t("profile_lock_change") : L10n.t("profile_lock_set")) {
                showPINSetup = true
            }
            .accessibilityIdentifier("profile.edit.setpin")
            if profile.lock.hasPIN {
                if ProfileBiometrics.isAvailable() {
                    Toggle(L10n.t("profile_lock_biometrics"), isOn: Binding(
                        get: { profile.lock.useBiometrics },
                        set: { try? manager.setBiometrics($0, for: profile.id) }
                    ))
                    .accessibilityIdentifier("profile.edit.biometrics")
                }
                Button(L10n.t("profile_lock_remove"), role: .destructive) { showRemoveLock = true }
                    .accessibilityIdentifier("profile.edit.removelock")
            }
        } header: {
            Text(L10n.t("profile_lock_section"))
        } footer: {
            Text(L10n.t("profile_lock_note"))
        }
    }

    private func deleteSection(_ profile: ProfileRecord) -> some View {
        Section {
            Button(L10n.t("profile_delete"), role: .destructive) { confirmDelete = true }
                .disabled(profile.isDefault || profile.id == manager.active.id)
                .accessibilityIdentifier("profile.edit.delete")
        } footer: {
            if profile.isDefault {
                Text(L10n.t("profile_delete_default"))
            } else if profile.id == manager.active.id {
                Text(L10n.t("profile_delete_active"))
            }
        }
    }

    private func lockStateText(_ lock: ProfileLock) -> String {
        if lock.useBiometrics { return L10n.t("profile_lock_on_bio") }
        return lock.hasPIN ? L10n.t("profile_lock_on_pin") : L10n.t("profile_lock_off")
    }

    private func rename() {
        errorText = nil
        do { try manager.renameProfile(id: profileId, to: name) }
        catch { errorText = profileErrorText(error) }
    }

    private func removeLock() {
        errorText = nil
        do { try manager.removeLock(for: profileId, currentPIN: removePIN) }
        catch { errorText = profileErrorText(error) }
        removePIN = ""
    }

    private func delete() {
        errorText = nil
        do {
            try manager.deleteProfile(id: profileId)
            dismiss()
        } catch {
            errorText = profileErrorText(error)
        }
    }
}

/// 設定或更換 PIN。已經有 PIN 時要先輸入目前的（否則走過來的人按一下就換掉你的鎖）。
struct PINSetupSheet: View {
    let profileId: String
    @ObservedObject private var manager = ProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var pin = ""
    @State private var confirm = ""
    @State private var errorText: String?

    private var hasPIN: Bool { manager.registry.profile(id: profileId)?.lock.hasPIN ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if hasPIN {
                        PINField(title: L10n.t("profile_pin_current"), text: $current, identifier: "profile.pin.current")
                    }
                    PINField(title: L10n.t("profile_pin_new"), text: $pin, identifier: "profile.pin.new")
                    PINField(title: L10n.t("profile_pin_confirm"), text: $confirm, identifier: "profile.pin.confirm")
                } footer: {
                    Text(L10n.t("profile_lock_note"))
                }
                if let errorText {
                    Section { Text(errorText).foregroundColor(.red).accessibilityIdentifier("profile.pin.error") }
                }
            }
            .navigationTitle(hasPIN ? L10n.t("profile_lock_change") : L10n.t("profile_lock_set"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("profile_save"), action: save).accessibilityIdentifier("profile.pin.save")
                }
            }
        }
    }

    private func save() {
        errorText = nil
        if hasPIN {
            let result = manager.verifyPIN(current, for: profileId)
            guard result == .ok else { errorText = pinFailureText(result); return }
        }
        guard ProfileLockService.isValidPIN(pin) else { errorText = L10n.t("profile_pin_invalid"); return }
        guard pin == confirm else { errorText = L10n.t("profile_pin_mismatch"); return }
        do {
            try manager.setPIN(pin, for: profileId)
            dismiss()
        } catch {
            errorText = profileErrorText(error)
        }
    }
}

// MARK: - 鎖定畫面

/// 使用中的設定檔上了鎖：啟動、或離開 App 超過一分鐘再回來時顯示。
/// **只是畫面閘門**（見 `ProfileLockService` 檔頭）—— 資料已經在記憶體裡。
struct ProfileLockView: View {
    @ObservedObject private var manager = ProfileManager.shared
    @State private var pin = ""
    @State private var message: String?
    @State private var showPicker = false
    @State private var triedBiometrics = false

    var body: some View {
        let profile = manager.active
        VStack(spacing: 20) {
            Spacer()
            ProfileAvatar(name: profile.displayName, colorHex: profile.colorHex, size: 88)
            Text(L10n.f("profile_unlock_title", profile.displayName)).font(.title2.bold())
            PINField(title: L10n.t("profile_pin_enter"), text: $pin, identifier: "profile.lock.pin")
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
                .onSubmit(submit)
            if let message {
                Text(message).font(.footnote).foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("profile.lock.message")
            }
            Button(L10n.t("profile_unlock_button"), action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(pin.count < ProfileLockService.minDigits)
                .accessibilityIdentifier("profile.lock.unlock")
            if profile.lock.useBiometrics, ProfileBiometrics.isAvailable() {
                Button { Task { await tryBiometrics() } } label: {
                    Label(L10n.t("profile_use_biometrics"), systemImage: "faceid")
                }
                .accessibilityIdentifier("profile.lock.biometrics")
            }
            Spacer()
            if manager.profiles.count > 1 {
                Button(L10n.t("profile_other_user")) { showPicker = true }
                    .accessibilityIdentifier("profile.lock.other")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showPicker) { ProfilePickerSheet() }
        .task {
            if profile.lock.useBiometrics, !triedBiometrics {
                triedBiometrics = true
                await tryBiometrics()
            }
        }
        .accessibilityIdentifier("profile.lock")
    }

    private func submit() {
        let result = manager.unlockActive(pin: pin)
        if result != .ok {
            message = pinFailureText(result)
            pin = ""
        }
    }

    private func tryBiometrics() async {
        _ = await manager.unlockActiveWithBiometrics(reason: L10n.t("profile_unlock_biometric_reason"))
    }
}

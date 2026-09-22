//
//  NotebookEncryptionSheet.swift
//  Kairumo
//
//  建立加密筆記本的流程（H-CRYPTO）。
//
//  # 為什麼是三步，而且不能跳
//
//  1. 設密碼
//  2. **抄下復原碼**
//  3. **把復原碼輸入回來**
//
//  第三步是整個流程的重點，也是最容易被說服拿掉的一步（「使用者嫌麻煩」）。
//  但無後端就沒有「忘記密碼」信件，也沒有客服能救 —— 復原碼是唯一的後路，
//  而「我等一下再抄」的使用者，就是後來會失去全部筆記的那一個。
//
//  # 涵蓋範圍直接問核心
//
//  文案不在這裡寫死。範圍變了（例如之後把錄音也加密）而文案沒跟上的話，
//  那一邊就是在騙使用者 —— 所以顯示什麼由 `cryptoEncryptionScope()` 決定。
//

import SwiftUI

@MainActor
struct NotebookEncryptionSheet: View {

    /// 建好之後回報：筆記本 id 與標題。
    let onCreated: (String, String) -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case setPassphrase
        case writeDownRecovery
        case confirmRecovery
    }

    @State private var step: Step = .setPassphrase
    @State private var title: String = ""
    @State private var passphrase: String = ""
    @State private var passphraseAgain: String = ""
    @State private var recoveryPhrase: String = ""
    @State private var typedRecovery: String = ""
    @State private var errorText: String = ""
    @State private var isWorking = false
    @State private var createdId: String = ""

    /// 密碼長度下限。
    ///
    /// 八個字不是安全的密碼，但它是一條**擋得住手滑**的線；
    /// 真正的強度來自 Argon2id 的成本參數，而不是這個數字。
    private static let minPassphraseLength = 8

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .setPassphrase: passphraseStep
                case .writeDownRecovery: recoveryStep
                case .confirmRecovery: confirmStep
                }
            }
            .navigationTitle(localizationManager.localized("encrypt_notebook"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // **復原碼還沒確認就取消的話，那本筆記不能留下。**
                    // 留著等於留下一本使用者進不去、也不知道自己進不去的筆記。
                    Button(localizationManager.localized("cancel")) {
                        discardIfUnconfirmed()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 第一步：設密碼

    private var passphraseStep: some View {
        Group {
            Section(localizationManager.localized("encrypt_scope_title")) {
                let scope = cryptoEncryptionScope()
                if scope.coversNotes {
                    Label(localizationManager.localized("encrypt_covers_notes"),
                          systemImage: "checkmark.circle.fill")
                        .foregroundColor(.primary)
                }
                if scope.coversImages {
                    Label(localizationManager.localized("encrypt_covers_images"),
                          systemImage: "checkmark.circle.fill")
                }
                if !scope.coversRecordings {
                    // **這一行不能拿掉。** 使用者會據此決定要不要把敏感的
                    // 東西錄進來。
                    Label(localizationManager.localized("encrypt_not_recordings"),
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                // **Apple 端的工作副本在套件外面。**
                //
                // `notebooks_v1.json` 與 `Drawings/*.drawing` 住在 Documents，
                // 而加密保護的是 `.padnote` 套件 —— 也就是**同步出去的那一份**。
                // 不講的話，使用者會以為這台裝置上的檔案也加密了。
                //
                // 要真的涵蓋本機副本，Apple 的儲存模型得搬進套件裡；
                // 那是一件大事，見 docs/TODO.md 的 H-CRYPTO-2。
                Label(localizationManager.localized("encrypt_local_copy_warning"),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)

                Text(localizationManager.localized("encrypt_only_new"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                TextField(localizationManager.localized("notebook_title_label"), text: $title)
                SecureField(localizationManager.localized("encrypt_passphrase"), text: $passphrase)
                SecureField(localizationManager.localized("encrypt_passphrase_again"),
                            text: $passphraseAgain)
            }

            if !errorText.isEmpty {
                Section { Text(errorText).foregroundColor(.red).font(.caption) }
            }

            Section {
                Button {
                    Task { await createNotebook() }
                } label: {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text(localizationManager.localized("confirm"))
                    }
                }
                .disabled(isWorking)
            }
        }
    }

    // MARK: - 第二步：抄下復原碼

    private var recoveryStep: some View {
        Group {
            Section(localizationManager.localized("recovery_title")) {
                Text(localizationManager.localized("recovery_warning"))
                    .font(.callout)
                    .foregroundColor(.orange)
            }
            Section {
                Text(recoveryPhrase)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Button(localizationManager.localized("recovery_copy")) {
                    UIPasteboard.general.string = recoveryPhrase
                }
            }
            Section {
                Button(localizationManager.localized("next_step")) {
                    step = .confirmRecovery
                }
            }
        }
    }

    // MARK: - 第三步：把它輸入回來

    private var confirmStep: some View {
        Group {
            Section {
                Text(localizationManager.localized("recovery_confirm_prompt"))
                    .font(.callout)
            }
            Section {
                TextEditor(text: $typedRecovery)
                    .frame(minHeight: 96)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            if !errorText.isEmpty {
                Section { Text(errorText).foregroundColor(.red).font(.caption) }
            }
            Section {
                Button(localizationManager.localized("confirm")) {
                    confirmRecovery()
                }
            }
        }
    }

    // MARK: - 動作

    private func createNotebook() async {
        errorText = ""
        guard passphrase.count >= Self.minPassphraseLength else {
            errorText = localizationManager.localized("encrypt_passphrase_too_short")
            return
        }
        guard passphrase == passphraseAgain else {
            errorText = localizationManager.localized("encrypt_passphrase_mismatch")
            return
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? localizationManager.localized("new_note")
            : title
        let id = UUID().uuidString.lowercased()
        let path = NotebookStore.shared.corePackagesDirectory
            .appending(path: "\(id).padnote").path
        let pass = passphrase

        isWorking = true
        defer { isWorking = false }
        // **Argon2id 刻意很慢**（64 MiB 記憶體成本），在主執行緒上會把
        // 畫面凍住好幾秒。
        let result = await Task.detached(priority: .userInitiated) {
            try? cryptoCreateEncryptedNotebook(
                packagePath: path, title: name, nowUnixMs: UInt64(Date().timeIntervalSince1970 * 1000),
                passphrase: pass)
        }.value

        guard let result else {
            errorText = localizationManager.localized("err_core_not_ready")
            return
        }
        createdId = id
        recoveryPhrase = result.recoveryPhrase
        step = .writeDownRecovery
    }

    private func confirmRecovery() {
        let typed = typedRecovery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard typed == recoveryPhrase.lowercased() else {
            errorText = localizationManager.localized("recovery_mismatch")
            return
        }
        onCreated(createdId, title.trimmingCharacters(in: .whitespacesAndNewlines))
        createdId = ""
        dismiss()
    }

    /// 復原碼還沒被確認就離開 ⇒ 把剛建好的套件刪掉。
    ///
    /// 留著的話，使用者手上會有一本**他進不去、而且不知道自己進不去**的
    /// 筆記 —— 他要等到下次打開才發現，那時候連復原碼都沒有了。
    private func discardIfUnconfirmed() {
        guard !createdId.isEmpty else { return }
        let path = NotebookStore.shared.corePackagesDirectory
            .appending(path: "\(createdId).padnote")
        try? FileManager.default.removeItem(at: path)
        createdId = ""
    }
}

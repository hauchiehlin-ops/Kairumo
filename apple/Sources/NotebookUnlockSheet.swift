//
//  NotebookUnlockSheet.swift
//  Kairumo
//
//  打開一本已加密的筆記（H-CRYPTO-2 #1）。
//
//  # 在此之前會發生什麼
//
//  建立加密筆記本的流程兩端都做完了，**但沒有任何地方問過密碼** ——
//  打開一本鎖著的筆記會一路走到「這個套件已加密，需要先解鎖才讀得出內容」
//  這個錯誤字串，而使用者沒有任何辦法把密碼交出來。
//
//  # 兩條路，而且要分得出來
//
//  密碼忘了還有復原碼。但**舊版建立的套件，它的復原碼從來沒有被用來包住
//  金鑰**（那是 fix(crypto) 那一筆修掉的事），所以再怎麼輸入都不會成功。
//  那種情況要在使用者開始輸入**之前**就講清楚，而不是讓他對著一串抄得
//  好好的詞一直重打。`cryptoRecoveryCanUnlock` 看 manifest 就知道。
//

import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

@MainActor
struct NotebookUnlockSheet: View {

    /// 要打開的套件路徑。
    let packagePath: String
    /// 解開之後把 handle 交出去。**不要存起來** —— 持有它等於持有金鑰。
    let onUnlocked: (FfiUnlockedNotebook) -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    private enum Route { case passphrase, recovery }

    @State private var route: Route = .passphrase
    @State private var passphrase: String = ""
    @State private var recoveryPhrase: String = ""
    @State private var errorText: String = ""
    @State private var isWorking = false
    /// 這本筆記的復原碼**真的開得了**嗎。`nil` = 還沒問過核心。
    @State private var recoveryUsable: Bool?

    private func L(_ key: String) -> String { localizationManager.localized(key) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L("unlock_title")).font(.headline)
                        .accessibilityIdentifier("unlock.title")
                    Text(route == .passphrase ? L("unlock_desc") : L("unlock_recovery_prompt"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                switch route {
                case .passphrase: passphraseSection
                case .recovery: recoverySection
                }

                if !errorText.isEmpty {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityIdentifier("unlock.error")
                    }
                }

                if isWorking {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(L("unlock_working"))
                        }
                        // 使用者不知道為什麼要等 —— 不講的話，慢會被當成當機。
                        Text(L("unlock_slow_hint"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L("encrypt_unlock"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("cancel")) { dismiss() }
                        .accessibilityIdentifier("unlock.cancel")
                }
            }
            .task {
                // 進畫面就問，不要等使用者切過去才發現那條路是死的。
                let path = packagePath
                recoveryUsable = await Task.detached(priority: .userInitiated) {
                    cryptoRecoveryCanUnlock(packagePath: path)
                }.value
            }
        }
    }

    private var passphraseSection: some View {
        Section {
            SecureField(L("encrypt_passphrase"), text: $passphrase)
                .accessibilityIdentifier("unlock.passphrase")
                .onSubmit { Task { await unlockWithPassphrase() } }
            Button(L("encrypt_unlock")) { Task { await unlockWithPassphrase() } }
                .disabled(passphrase.isEmpty || isWorking)
                .accessibilityIdentifier("unlock.submit")

            // 復原碼那條路只有在**真的開得了**的時候才給入口。
            // 給一個按下去注定失敗的入口，比沒有入口更糟。
            if recoveryUsable == true {
                Button(L("unlock_use_recovery")) {
                    errorText = ""
                    route = .recovery
                }
                .accessibilityIdentifier("unlock.switch_to_recovery")
            } else if recoveryUsable == false {
                Text(L("unlock_recovery_unavailable"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("unlock.recovery_unavailable")
            }
        }
    }

    private var recoverySection: some View {
        Section {
            TextEditor(text: $recoveryPhrase)
                .frame(minHeight: 88)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalizationNeverIfAvailable()
                .accessibilityIdentifier("unlock.recovery")
            Button(L("encrypt_unlock")) { Task { await unlockWithRecovery() } }
                .disabled(recoveryPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || isWorking)
                .accessibilityIdentifier("unlock.submit_recovery")
            Button(L("unlock_use_passphrase")) {
                errorText = ""
                route = .passphrase
            }
            .accessibilityIdentifier("unlock.switch_to_passphrase")
        }
    }

    /// **一定要離開主執行緒。** Argon2id 是刻意慢的（64 MiB 記憶體成本），
    /// 在主執行緒跑會讓畫面凍住好幾秒，而 iOS 的看門狗數到十秒就送 SIGKILL。
    private func unlockWithPassphrase() async {
        guard !isWorking else { return }
        isWorking = true
        errorText = ""
        let path = packagePath
        let secret = passphrase
        let result = await Task.detached(priority: .userInitiated) {
            try? cryptoUnlock(packagePath: path, passphrase: secret)
        }.value
        isWorking = false
        guard let result else {
            errorText = L("encrypt_wrong_passphrase")
            return
        }
        onUnlocked(result)
        dismiss()
    }

    private func unlockWithRecovery() async {
        guard !isWorking else { return }
        isWorking = true
        errorText = ""
        let path = packagePath
        let phrase = recoveryPhrase
        let result = await Task.detached(priority: .userInitiated) {
            try? cryptoUnlockWithRecovery(packagePath: path, recoveryPhrase: phrase)
        }.value
        isWorking = false
        guard let result else {
            errorText = L("unlock_wrong_recovery")
            return
        }
        onUnlocked(result)
        dismiss()
    }
}

private extension View {
    /// `textInputAutocapitalization` 在 macOS 上沒有 —— 復原碼全是小寫，
    /// 讓系統自動把第一個字母變大寫會讓它對不上。
    @ViewBuilder
    func textInputAutocapitalizationNeverIfAvailable() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }
}

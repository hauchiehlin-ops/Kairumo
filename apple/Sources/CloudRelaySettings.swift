//
//  CloudRelaySettings.swift
//  Kairumo
//
//  協同面板裡的「雲端共享中繼」設定：使用者可以改用自己部署的中繼，
//  旁邊附零基礎的取得步驟（Cloudflare 一鍵部署，全程在瀏覽器裡）。與 Android `CloudRelaySettings` 相同。

import SwiftUI

enum CloudRelayLinks {
    /// Cloudflare「一鍵部署」：把專案裡的 `deploy/relay-cloudflare` 複製到使用者自己的帳號並部署。
    /// 專案必須是公開的、資料夾要在 main 上（見 Cloudflare 文件 Deploy buttons）。
    static let deploy = URL(string: "https://deploy.workers.cloudflare.com/?url=https://github.com/hauchiehlin-ops/Kairumo/tree/main/deploy/relay-cloudflare")!
    static let signupCloudflare = URL(string: "https://dash.cloudflare.com/sign-up")!
    static let signupGitHub = URL(string: "https://github.com/signup")!
}

struct CloudRelaySettingView: View {
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @State private var draft = ""
    @State private var message: String?
    @State private var isError = false
    @State private var showGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizationManager.localized("cloud_relay_title"))
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack {
                TextField(CollaborationManager.publicRelayURL, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .accessibilityIdentifier("collab.cloud_relay.field")
                Button(localizationManager.localized("cloud_relay_save")) { save() }
                    .font(.caption)
                Button(localizationManager.localized("reset")) {
                    draft = ""
                    save()
                }
                .font(.caption)
            }
            if let message {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(isError ? .orange : .green)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(localizationManager.localized("cloud_relay_hint"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showGuide = true
            } label: {
                Label(localizationManager.localized("cloud_relay_guide"), systemImage: "questionmark.circle")
                    .font(.caption)
            }
            .accessibilityIdentifier("collab.cloud_relay.guide")
        }
        .onAppear { draft = collaborationManager.customCloudRelay }
        .sheet(isPresented: $showGuide) { CloudRelayGuideView() }
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // 貼成 https:// 的也收：換成 wss://（教學裡就是叫使用者這樣改，順手代勞）。
        let normalized = text.lowercased().hasPrefix("https://") ? "wss://" + text.dropFirst("https://".count) : text
        if !normalized.isEmpty && !CollaborationManager.isValidCloudRelay(normalized) {
            message = localizationManager.localized("cloud_relay_invalid")
            isError = true
            return
        }
        draft = normalized
        collaborationManager.customCloudRelay = normalized
        message = localizationManager.localized("cloud_relay_saved")
        isError = false
    }
}

/// 零基礎的取得步驟。
struct CloudRelayGuideView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localizationManager.localized("cloud_relay_guide_intro"))
                        .font(.subheadline)
                    HStack(spacing: 10) {
                        Button(localizationManager.localized("cloud_relay_signup_cloudflare")) {
                            openURL(CloudRelayLinks.signupCloudflare)
                        }
                        Button(localizationManager.localized("cloud_relay_signup_github")) {
                            openURL(CloudRelayLinks.signupGitHub)
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    ForEach(["cloud_relay_step1", "cloud_relay_step2", "cloud_relay_step3",
                             "cloud_relay_step4", "cloud_relay_step5", "cloud_relay_step6"], id: \.self) { key in
                        Text(localizationManager.localized(key))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    Button {
                        openURL(CloudRelayLinks.deploy)
                    } label: {
                        Label(localizationManager.localized("cloud_relay_open_deploy"), systemImage: "cloud")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("collab.cloud_relay.deploy")
                    Text(localizationManager.localized("cloud_relay_guide_note"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .navigationTitle(localizationManager.localized("cloud_relay_guide_title"))
            #if os(iOS) || targetEnvironment(macCatalyst)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("done")) { dismiss() }
                }
            }
        }
    }
}

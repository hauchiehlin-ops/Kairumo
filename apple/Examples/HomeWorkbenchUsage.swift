//
//  HomeWorkbenchUsage.swift
//  Kairumo
//
//  Apple 平台首頁「今日工作台」整合與版本號展示範例（docs/ui-design.md §2.1）
//

import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 應用程式主入口範例（支援 iOS、iPadOS 與 Mac Catalyst 通用）
@main
struct KairumoApp: App {
    init() {
        // 啟動時確認 Rust Core 與版本狀態
        #if canImport(PadnoteCore)
        let coreVer = coreVersion()
        let info = appInfo()
        print("🚀 Kairumo 啟動完成 - 核心引擎版本: \(coreVer), 平台目標: \(info.targetOs)/\(info.targetArch)")
        #endif
    }

    private var appVersionTitle: String { AppVersion.windowTitle }

    /// App 回到前景時自動同步一輪。
    ///
    /// **這一段是「跨裝置感覺得到」的全部差別。** 機制本身早就寫好了，
    /// 但在此之前只有設定頁裡那一個按鈕會觸發它 —— 使用者在 iPad 上寫完，
    /// 打開 Mac，什麼也不會發生，除非他知道要去設定頁點一下。
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup(appVersionTitle) {
            HomeWorkbenchView()
                // 單參數的 onChange：新的兩參數版本要 iOS 17，而部署目標更低。
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task { await AutoCloudSync.runIfSignedIn() }
                }
                #if os(macOS) || targetEnvironment(macCatalyst)
                .frame(minWidth: 800, minHeight: 600)
                // `.frame(minWidth:)` **不會限制 Mac 上的視窗大小** ——
                // 它只約束內容，視窗照樣可以被拖到比它更窄，然後內容被裁掉。
                // 實測：視窗縮到 500pt 時，浮動面板的關閉鈕與最後一個分頁
                // 整個被切在視窗外，使用者連把面板關掉都做不到。
                // Catalyst 要限制視窗得走 windowScene.sizeRestrictions。
                .onAppear { applyMacWindowMinimumSize() }
                #endif
        }

        // 操作手冊與隱私權政策各自是一個**真正的視窗**，不是彈出的工作表。
        //
        // 工作表在 Mac 上既不能移動也不能調整大小 —— 使用者要一邊看手冊
        // 一邊操作 App 的時候，那個工作表就擋在那裡。
        WindowGroup(id: DocumentWindow.id, for: BundledDocument.ID.self) { $documentId in
            DocumentWindowContent(documentId: documentId)
                #if os(macOS) || targetEnvironment(macCatalyst)
                .frame(minWidth: 520, minHeight: 420)
                #endif
        }
    }
}

#if os(macOS) || targetEnvironment(macCatalyst)
/// 讓 Mac 視窗不能被拖得比版面需要的還窄。
///
/// 數值與 `.frame(minWidth:minHeight:)` 一致 —— 兩邊都留著：
/// frame 管內容佈局，sizeRestrictions 管視窗本身，少了任何一邊都不完整。
private func applyMacWindowMinimumSize() {
    let minimum = CGSize(width: 800, height: 600)
    for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        windowScene.sizeRestrictions?.minimumSize = minimum
    }
}
#endif


/// 自動同步。與設定頁裡的「立即同步」走同一條路，差別只在**不出訊息**。
///
/// 自動同步是背景行為：網路不通就下次再說。每次回到前景都跳一次
/// 「同步失敗」，使用者只會去把這個功能關掉。
@MainActor
enum AutoCloudSync {

    /// 同一時間只跑一輪。前景切換在 Catalyst 上會連續來好幾次，
    /// 不擋的話會有好幾輪同步同時在寫同一個套件。
    private static var running = false

    static func runIfSignedIn() async {
        guard !running, GoogleAuth.shared.isSignedIn else { return }
        running = true
        defer { running = false }
        _ = await NotebookSyncCoordinator.runDrive(
            store: NotebookStore.shared, deviceId: NotebookMigration.deviceId)
    }
}

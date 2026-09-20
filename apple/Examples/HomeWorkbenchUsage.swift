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
/// 第一次啟動先給引導，之後直接進首頁（見 `OnboardingView`）。
private struct RootView: View {
    @State private var showOnboarding = !OnboardingView.hasSeen

    var body: some View {
        if showOnboarding {
            OnboardingView(onDone: { showOnboarding = false })
        } else {
            HomeWorkbenchView()
        }
    }
}

@main
struct KairumoApp: App {
    /// 實體鍵盤快捷鍵靠它註冊（見 `AppCommands.swift`）。
    ///
    /// 純 SwiftUI 的 App 沒有 delegate，而 `buildMenu(with:)` 需要一個 ——
    /// 命令沿著響應鏈往上找不到人處理時，最後會落到它身上。
    @UIApplicationDelegateAdaptor(KairumoAppDelegate.self) private var appDelegate

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
            RootView()
                // 單參數的 onChange：新的兩參數版本要 iOS 17，而部署目標更低。
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task { await AutoCloudSync.runIfSignedIn() }
                }
                .onOpenURL { url in
                    let ext = url.pathExtension.lowercased()
                    if ext == "padnote" || ext == "zip" {
                        _ = try? NotebookStore.shared.importNotebookArchive(from: url)
                    } else if GoogleAuth.shared.handleCallbackURL(url) {
                        // 成功截獲系統／瀏覽器回呼之 Google OAuth 跳轉
                    }
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
        // ⌘N 與 ⌘F 只能走這裡，不能走 delegate 的 `buildMenu`。
        //
        // 「檔案」選單整個是 SwiftUI 的：新增視窗、複製、移動、重新命名、
        // 輸出，都是它從 `WindowGroup` 產生的。delegate 的 `buildMenu` 先跑，
        // SwiftUI 之後**重建整個選單**，於是插進去的兩個項目被無聲抹掉 ——
        // 不當機、不警告，選單裡就是沒有。實測：`.file` 存在、`insertChild`
        // 有跑，但選單列裡查不到那兩項。
        //
        // 其餘命令（⌘E、⌘1–⌘9）插在「顯示」選單，SwiftUI 不碰那裡，
        // 所以留在 delegate 裡沒問題。
        .commands {
            CommandGroup(after: .newItem) {
                Button(LocalizationManager.shared.localizedUnsafe("new_note")) {
                    NotificationCenter.default.post(name: AppCommand.newNotebook, object: nil)
                }
                // ⇧⌘N 而不是 ⌘N：⌘N 是系統的「新增視窗」（`requestNewScene:`）。
                // 搶同一組鍵時 UIKit 直接丟例外把 App 打掉，訊息明說
                // 「Replacement elements contain duplicates」。
                // Finder 的「新增檔案夾」也是 ⇧⌘N，使用者不會覺得陌生。
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button(LocalizationManager.shared.localizedUnsafe("search_placeholder")) {
                    NotificationCenter.default.post(name: AppCommand.focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
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

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

    var body: some Scene {
        WindowGroup(appVersionTitle) {
            HomeWorkbenchView()
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

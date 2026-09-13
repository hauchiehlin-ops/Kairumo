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

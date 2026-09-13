//
//  DocumentViewerSheet.swift
//  Kairumo
//
//  App 內建文件檢視器（操作手冊、隱私權政策）。
//
//  文件是隨 App 一起打包的本機 HTML，離線可讀，不需要網路，也不需要登入任何服務。
//

import SwiftUI
import WebKit

/// App 內附的文件
public enum BundledDocument: String, Identifiable {
    case manual = "manual"
    case privacy = "privacy"

    public var id: String { rawValue }

    /// 檔名（在 App bundle 的 Docs 資料夾裡）
    var fileName: String {
        switch self {
        case .manual: return "manual.html"
        case .privacy: return "privacy.html"
        }
    }

    var titleKey: String {
        switch self {
        case .manual: return "user_manual"
        case .privacy: return "privacy_policy"
        }
    }

    /// 打包進 App 的檔案位置。
    /// Docs 是「資料夾參照」，所以要連同子目錄一起找，圖片的相對路徑才會正確。
    var url: URL? {
        if let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".html", with: ""),
                                    withExtension: "html",
                                    subdirectory: "Docs") {
            return url
        }
        // 有些打包設定會把資源攤平到 bundle 根目錄
        return Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".html", with: ""),
                               withExtension: "html")
    }
}

/// 以 WKWebView 呈現本機 HTML 文件
struct DocumentWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        // 讀取權限要給到文件所在的資料夾，否則同目錄的 manual.js 與 img/ 會載不進來
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// 文件檢視彈窗
public struct DocumentViewerSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    public let document: BundledDocument

    public init(document: BundledDocument) {
        self.document = document
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let url = document.url {
                    DocumentWebView(url: url)
                } else {
                    // 打包漏掉檔案時要講清楚，而不是給一個空白畫面
                    VStack(spacing: 10) {
                        Image(systemName: "doc.questionmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(localizationManager.localized("document_missing"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle(localizationManager.localized(document.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("done")) { dismiss() }
                }
            }
        }
    }
}

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

/// 文件視窗的識別。
public enum DocumentWindow {
    public static let id = "kairumo.document"

    /// 這個平台開不開得出獨立視窗。
    ///
    /// Mac 才有「可以移動、可以調整大小、可以放在旁邊」的視窗概念。
    /// iPhone 與 iPad 上仍然用工作表 —— 在那裡強行開一個新場景，
    /// 使用者只會看到 App 整個換了一頁，而且回不去。
    public static var supportsSeparateWindow: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }
}

/// 獨立視窗裡的文件內容。
///
/// 沒有工作表的導覽列與「完成」按鈕 —— 視窗本身就有關閉鈕，
/// 再放一個只是多一個看起來一樣、行為不同的東西。
public struct DocumentWindowContent: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    private let document: BundledDocument?

    public init(documentId: BundledDocument.ID?) {
        self.document = documentId.flatMap(BundledDocument.init(rawValue:))
    }

    public var body: some View {
        Group {
            if let document, let url = document.url {
                DocumentWebView(url: url)
            } else {
                DocumentMissingView()
            }
        }
        .navigationTitle(document.map { localizationManager.localized($0.titleKey) } ?? "")
    }
}

/// 打包漏掉檔案時要講清楚，而不是給一個空白畫面。
struct DocumentMissingView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
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
                    DocumentMissingView()
                }
            }
            .navigationTitle(localizationManager.localized(document.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            // iPad 上讓使用者把工作表拉大拉小 —— 那是這個平台的「調整大小」。
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("done")) { dismiss() }
                }
            }
        }
    }
}

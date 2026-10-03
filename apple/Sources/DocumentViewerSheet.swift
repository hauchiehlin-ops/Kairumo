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

    /// 公開網頁版網址（符合 App Store 審核對公開隱私權政策與手冊網址之要求）
    public var onlineURL: URL? {
        switch self {
        case .manual:
            return URL(string: "https://hauchiehlin-ops.github.io/Kairumo/manual/index-apple.html")
        case .privacy:
            return URL(string: "https://hauchiehlin-ops.github.io/Kairumo/legal/privacy-apple.html")
        }
    }
}

/// 以 WKWebView 呈現本機 HTML 文件。
///
/// # 為什麼這麼囉嗦
///
/// 回報是「點了操作手冊／隱私權政策，整頁空白」，而且只在實機（iPad、Mac）上發生；模擬器上正常。
/// 空白的 WKWebView 沒有任何錯誤可看，常見成因有三個，這裡都擋：
///
/// 1. **初始 frame 是 `.zero`。** 在工作表／新視窗還沒排版完時建立，載入會在 0×0 的視圖上完成，
///    之後放大也不一定會重畫。給一個非零的起始 frame，並在視圖真的有尺寸之後才載入。
/// 2. **網頁內容行程被系統收掉**（記憶體壓力、App 在背景時），畫面就停在空白。
///    `webViewWebContentProcessDidTerminate` 時重新載入。
/// 3. **載入完了但頁面是空的**（腳本沒跑起來）。載入完成後量一下內文長度，太短就當成失敗：
///    重試一次，仍然空白就改載公開網頁版，而不是讓使用者看一片白。
struct DocumentWebView: UIViewRepresentable {
    let url: URL
    /// 本機載入失敗時的備援（公開網頁版）。
    var fallbackURL: URL? = nil

    func makeCoordinator() -> Coordinator { Coordinator(url: url, fallbackURL: fallbackURL) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 有真實尺寸才載入第一次。
        guard !context.coordinator.hasStartedLoading, uiView.bounds.width > 1, uiView.bounds.height > 1 else {
            if !context.coordinator.hasStartedLoading {
                DispatchQueue.main.async { [weak uiView] in
                    guard let uiView else { return }
                    context.coordinator.loadIfReady(uiView)
                }
            }
            return
        }
        context.coordinator.loadIfReady(uiView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let url: URL
        let fallbackURL: URL?
        weak var webView: WKWebView?
        private(set) var hasStartedLoading = false
        private var retried = false
        private var usedFallback = false

        init(url: URL, fallbackURL: URL?) {
            self.url = url
            self.fallbackURL = fallbackURL
        }

        func loadIfReady(_ webView: WKWebView) {
            guard !hasStartedLoading else { return }
            guard webView.bounds.width > 1, webView.bounds.height > 1 else {
                // 還沒排版完：下一個 run loop 再看一次（最多等一下，不會無限輪詢）。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak webView] in
                    guard let self, let webView, !self.hasStartedLoading else { return }
                    self.loadLocal(webView)
                }
                return
            }
            loadLocal(webView)
        }

        private func loadLocal(_ webView: WKWebView) {
            hasStartedLoading = true
            // 讀取權限要給到文件所在的資料夾，否則同目錄的 manual.js 與 img/ 會載不進來
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        // unused-param-ok: 簽名由 WKNavigationDelegate 規定
        // unused-param-ok: 簽名由 WKNavigationDelegate 規定
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 頁面的腳本是在載入後才長出內容的；等一下再量。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self, weak webView] in
                guard let self, let webView else { return }
                webView.evaluateJavaScript("document.body ? document.body.innerText.length : 0") { value, _ in
                    let length = (value as? Int) ?? 0
                    if length < 200 { self.recover(webView) }
                }
            }
        }

        // unused-param-ok: 簽名由 WKNavigationDelegate 規定；失敗原因不影響處理（一律重試／換備援）
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            recover(webView)
        }

        // unused-param-ok: 同上
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            recover(webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            recover(webView)
        }

        /// 先重載一次本機；還是不行就換公開網頁版。
        private func recover(_ webView: WKWebView) {
            if !retried {
                retried = true
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else if !usedFallback, let fallbackURL {
                usedFallback = true
                webView.load(URLRequest(url: fallbackURL))
            }
        }
    }
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
                DocumentWebView(url: url, fallbackURL: document.onlineURL)
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
                    DocumentWebView(url: url, fallbackURL: document.onlineURL)
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
                ToolbarItem(placement: .cancellationAction) {
                    if let onlineURL = document.onlineURL {
                        Link(destination: onlineURL) {
                            Image(systemName: "safari")
                        }
                        .help("Open in Browser")
                        .accessibilityLabel("Open in Browser")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("done")) { dismiss() }
                }
            }
        }
    }
}

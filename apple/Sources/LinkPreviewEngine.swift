//
//  LinkPreviewEngine.swift
//  Kairumo
//
//  網址連結即時預覽引擎與 Rich Link Preview 卡片視圖
//

import SwiftUI

public struct LinkMetadata {
    public let url: URL
    public let title: String
    public let description: String
    public let siteName: String
}

/// 抓一個網址的中繼資料。
///
/// # 解析在核心，這裡只做 HTTP
///
/// 與 `FfiDriveHttp` 同一個分工。Android 那一側叫的是同一個
/// `link_parse_metadata` —— 各寫一份正規表示式的話，兩邊遲早會分岔，
/// 而症狀是「同一個網址在 iPad 上抓得到標題、在 Android 上抓不到」。
///
/// # 抓不到就回主機名，**不編**
///
/// 舊版對 `apple.com`、`github.com`、`wikipedia.org` 內建了一組寫死的標題
/// 與描述（而且是寫死的繁體中文）。那是**捏造的中繼資料**：網路抓不到時，
/// 使用者會得到一段看起來像真的、實際上是我們編的網站簡介，而且不管他的
/// 介面語言是什麼都是中文。已經拿掉。
public class LinkPreviewFetcher {
    public static func fetchPreview(for rawUrl: String) async -> LinkMetadata {
        let normalized = linkNormalizeUrl(raw: rawUrl)
        guard let url = URL(string: normalized) else {
            let meta = linkParseMetadata(html: "", url: normalized)
            return LinkMetadata(
                url: URL(string: "https://")!,
                title: meta.title,
                description: meta.description,
                siteName: meta.siteName
            )
        }

        var request = URLRequest(url: url)
        // 三秒。抓中繼資料是錦上添花，不該讓使用者對著轉圈等一個慢站台。
        request.timeoutInterval = 3.0
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            forHTTPHeaderField: "User-Agent")

        var html = ""
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200 {
            // 先試 UTF-8，再退回 ISO-8859-1。**不要用 .ascii**：
            // 非 ASCII 的位元組會讓整份解碼失敗，而那正是中文網站的常態。
            html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
        }

        let meta = linkParseMetadata(html: html, url: normalized)
        return LinkMetadata(
            url: URL(string: meta.url) ?? url,
            title: meta.title,
            description: meta.description,
            siteName: meta.siteName
        )
    }
}

public struct LinkPreviewSheet: View {
    var onInsertLink: (NoteLinkAttachment) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    @State private var urlInput: String = "https://apple.com"
    @State private var isFetching: Bool = false
    @State private var metadata: LinkMetadata? = nil

    private let sampleUrls = [
        "https://apple.com",
        "https://github.com",
        "https://wikipedia.org"
    ]

    public init(onInsertLink: @escaping (NoteLinkAttachment) -> Void) {
        self.onInsertLink = onInsertLink
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 網址輸入列
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localized("enter_url"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("https://...", text: $urlInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit {
                                loadPreview()
                            }

                        Button(localizationManager.localized("fetch_preview")) {
                            loadPreview()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(urlInput.isEmpty || isFetching)
                    }
                }
                .padding(.horizontal)

                // 範例網址
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sampleUrls, id: \.self) { sample in
                            Button(sample) {
                                urlInput = sample
                                loadPreview()
                            }
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }

                // 預覽卡片展示
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)

                    if isFetching {
                        ProgressView(localizationManager.localized("fetch_preview"))
                    } else if let meta = metadata {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                Text(meta.siteName.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            Text(meta.title)
                                .font(.headline)
                                .lineLimit(2)

                            Text(meta.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)

                            HStack {
                                Text(meta.url.absoluteString)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                        .padding(18)
                    } else {
                        Text(LocalizationManager.shared.localized("link_preview_hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(minHeight: 160, maxHeight: 200)
                .padding(.horizontal)

                Spacer()

                // 貼入畫布按鈕
                if let meta = metadata {
                    Button {
                        let linkItem = NoteLinkAttachment(
                            urlString: meta.url.absoluteString,
                            title: meta.title,
                            descriptionText: meta.description,
                            siteName: meta.siteName,
                            x: 100,
                            y: 180,
                            width: 320,
                            height: 140
                        )
                        onInsertLink(linkItem)
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link.badge.plus")
                            Text(LocalizationManager.shared.localized("link_preview_insert"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .padding(.top)
            .navigationTitle(localizationManager.localized("link_preview"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPreview()
            }
        }
        .frame(minWidth: 460, minHeight: 450)
    }

    private func loadPreview() {
        guard !urlInput.isEmpty else { return }
        isFetching = true
        Task {
            let res = await LinkPreviewFetcher.fetchPreview(for: urlInput)
            await MainActor.run {
                self.metadata = res
                self.isFetching = false
            }
        }
    }
}

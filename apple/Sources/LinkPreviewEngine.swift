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

public class LinkPreviewFetcher {
    public static func fetchPreview(for rawUrl: String) async -> LinkMetadata {
        var clean = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "https://" + clean
        }

        guard let url = URL(string: clean), let host = url.host else {
            return LinkMetadata(
                url: URL(string: "https://")!,
                title: "未知連結",
                description: rawUrl,
                siteName: "網路連結"
            )
        }

        var title = host
        var desc = clean
        var siteName = host.replacingOccurrences(of: "www.", with: "")

        // 預設知名網站優化
        if host.contains("apple.com") {
            title = "Apple 官方網站"
            desc = "探索 Apple 創新的世界，選購 iPhone、iPad、Apple Watch、Mac 等各項產品。"
            siteName = "apple.com"
        } else if host.contains("github.com") {
            title = "GitHub: Let's build from here"
            desc = "全球領先的開源程式碼託管與協作平台。"
            siteName = "github.com"
        } else if host.contains("wikipedia.org") {
            title = "維基百科，自由的百科全書"
            desc = "海量知識庫與自由開放的多語言協同百科全書。"
            siteName = "wikipedia.org"
        }

        // 嘗試發起超時限制之非同步網路爬取以獲取真實 HTML 標題與 og 標籤
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        if let (data, response) = try? await URLSession.shared.data(for: request),
           let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
           let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {

            // 擷取 og:title 或 <title>
            if let ogTitle = extractTagContent(from: html, pattern: "<meta[^>]*property=[\"']og:title[\"'][^>]*content=[\"']([^\"']+)[\"']") {
                title = ogTitle
            } else if let titleTag = extractTagContent(from: html, pattern: "<title[^>]*>([^<]+)</title>") {
                title = titleTag
            }

            // 擷取 og:description 或 meta description
            if let ogDesc = extractTagContent(from: html, pattern: "<meta[^>]*property=[\"']og:description[\"'][^>]*content=[\"']([^\"']+)[\"']") {
                desc = ogDesc
            } else if let metaDesc = extractTagContent(from: html, pattern: "<meta[^>]*name=[\"']description[\"'][^>]*content=[\"']([^\"']+)[\"']") {
                desc = metaDesc
            }

            // 擷取 og:site_name
            if let ogSite = extractTagContent(from: html, pattern: "<meta[^>]*property=[\"']og:site_name[\"'][^>]*content=[\"']([^\"']+)[\"']") {
                siteName = ogSite
            }
        }

        return LinkMetadata(
            url: url,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: desc.trimmingCharacters(in: .whitespacesAndNewlines),
            siteName: siteName
        )
    }

    private static func extractTagContent(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           match.numberOfRanges > 1,
           let captureRange = Range(match.range(at: 1), in: html) {
            return String(html[captureRange])
        }
        return nil
    }
}

/// 插入連結網址彈出面板
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
                        Text("輸入網址後點選「解析預覽」以產生卡片")
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
                            Text("將連結預覽卡片插入筆記")
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

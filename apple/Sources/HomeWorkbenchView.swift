//
//  HomeWorkbenchView.swift
//  Kairumo
//
//  首頁採用：今日工作台（docs/ui-design.md §2.1）
//  支援跨平台架構：iOS / iPadOS / macOS (Mac Catalyst)
//

import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 筆記卡片摘要資料模型
public struct NotebookItem: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var lastModifiedDate: Date
    public var pageCount: Int
    public var hasRecording: Bool
    public var previewSnippet: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        lastModifiedDate: Date = Date(),
        pageCount: Int = 1,
        hasRecording: Bool = false,
        previewSnippet: String? = nil
    ) {
        self.id = id
        self.title = title
        self.lastModifiedDate = lastModifiedDate
        self.pageCount = pageCount
        self.hasRecording = hasRecording
        self.previewSnippet = previewSnippet
    }
}

/// 最近錄音摘要資料模型
public struct RecentRecordingItem: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var durationSeconds: Int
    public var recordedDate: Date
    public var transcriptionStatus: String
    public var isTranscribed: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        durationSeconds: Int,
        recordedDate: Date = Date(),
        transcriptionStatus: String = "已完成",
        isTranscribed: Bool = true
    ) {
        self.id = id
        self.title = title
        self.durationSeconds = durationSeconds
        self.recordedDate = recordedDate
        self.transcriptionStatus = transcriptionStatus
        self.isTranscribed = isTranscribed
    }
}

/// Kairumo 首頁：今日工作台視圖（SwiftUI 跨平台相容）
public struct HomeWorkbenchView: View {
    @State private var searchText: String = ""
    @State private var showInfoSheet: Bool = false
    @State private var selectedFilter: Int = 0

    // 範例資料
    @State private var recentNotebooks: [NotebookItem] = [
        NotebookItem(title: "線性代數 第三週", lastModifiedDate: Date().addingTimeInterval(-3600), pageCount: 5, hasRecording: true, previewSnippet: "特徵值與特徵向量定理證明"),
        NotebookItem(title: "產品架構評審會議", lastModifiedDate: Date().addingTimeInterval(-86400), pageCount: 12, hasRecording: true, previewSnippet: "跨平台渲染管線與延遲預算評估"),
        NotebookItem(title: "靈感草稿與手繪圖形", lastModifiedDate: Date().addingTimeInterval(-172800), pageCount: 3, hasRecording: false, previewSnippet: "向量幾何吸附與貝茲曲線控制點")
    ]

    @State private var recentRecordings: [RecentRecordingItem] = [
        RecentRecordingItem(title: "線性代數 課程錄音", durationSeconds: 2710, recordedDate: Date().addingTimeInterval(-3600), transcriptionStatus: "轉錄完成", isTranscribed: true),
        RecentRecordingItem(title: "每週架構會議", durationSeconds: 1540, recordedDate: Date().addingTimeInterval(-86400), transcriptionStatus: "轉錄完成", isTranscribed: true)
    ]

    public init() {}

    /// 取得核心版本資訊（支援動態 Rust Core 與 Bundle 回退機制）
    public var appVersionString: String {
        #if canImport(PadnoteCore)
        // 優先讀取 Rust 核心引擎所報告之精確版本
        let v = coreVersion()
        if !v.isEmpty {
            return "v\(v)"
        }
        #endif
        // 若尚未鏈接原生動態庫，退回讀取應用程式 Bundle
        let bundleVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.4"
        return "v\(bundleVer)"
    }

    /// 核心平台環境描述
    public var platformArchitectureDescription: String {
        #if targetEnvironment(macCatalyst)
        return "Mac Catalyst (Apple Silicon / Intel)"
        #elseif os(macOS)
        return "macOS 原生"
        #elseif os(iOS)
        #if targetEnvironment(simulator)
        return "iOS 模擬器"
        #else
        return "iOS / iPadOS 實機"
        #endif
        #else
        return "Apple 通用架構"
        #endif
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. 頂部搜尋列
                    searchBarSection

                    // 2. 主要動作：新增筆記、開始錄音
                    primaryActionsSection

                    // 3. 繼續：最近開啟與最近編輯的筆記
                    continueWorkingSection

                    // 4. 最近錄音：播放狀態、波形、轉錄狀態
                    recentRecordingsSection

                    // 5. 全部筆記
                    allNotebooksSection

                    // 6. 底部工作台品牌與【版本號標註】
                    footerVersionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("今日工作台")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInfoSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text(appVersionString)
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("關於 Kairumo 與版本號")
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                AppDiagnosticsSheet(versionString: appVersionString, platformDesc: platformArchitectureDescription)
            }
        }
    }

    // MARK: - 1. 頂部搜尋列
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜尋筆記、轉錄文字或手寫辨識內容…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - 2. 主要動作
    private var primaryActionsSection: some View {
        HStack(spacing: 14) {
            Button {
                // 動作：新增筆記
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("新增筆記")
                            .font(.headline)
                        Text("空白紙張、網格、康乃爾")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    Spacer()
                }
                .padding()
                .foregroundColor(.white)
                .background(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(14)
            }

            Button {
                // 動作：開始錄音
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.title3)
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("開始錄音")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("同步語音轉錄與書寫對齊")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 3. 繼續 Working Section
    private var continueWorkingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("繼續")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("最近開啟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recentNotebooks) { note in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.accentColor)
                                Spacer()
                                if note.hasRecording {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 6, height: 6)
                                        Image(systemName: "waveform")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }

                            Text(note.title)
                                .font(.headline)
                                .lineLimit(1)

                            if let snippet = note.previewSnippet {
                                Text(snippet)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            HStack {
                                Text("\(note.pageCount) 頁")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(note.lastModifiedDate, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(width: 220, height: 140)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 4. 最近錄音
    private var recentRecordingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近錄音與轉錄")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("一鍵點擊筆畫跳播")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(recentRecordings) { rec in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "play.fill")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(rec.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack(spacing: 8) {
                                Text(formatDuration(seconds: rec.durationSeconds))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(rec.transcriptionStatus)
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }

                        Spacer()

                        Image(systemName: "waveform")
                            .foregroundColor(.secondary.opacity(0.7))
                            .font(.title3)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - 5. 全部筆記
    private var allNotebooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("全部筆記")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Menu {
                    Button("依修改時間排序", action: {})
                    Button("依名稱排序", action: {})
                    Button("僅顯示含錄音筆記", action: {})
                } label: {
                    HStack(spacing: 4) {
                        Text("排序與篩選")
                            .font(.caption)
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 14)], spacing: 14) {
                ForEach(recentNotebooks) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                .frame(height: 110)
                            VStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(note.title)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                        }

                        Text(note.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        HStack {
                            Text("\(note.pageCount) 頁")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(note.lastModifiedDate, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - 6. 底部工作台品牌與【版本號標註】
    private var footerVersionSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                Text("Kairumo")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.footnote)
                    .foregroundColor(.secondary.opacity(0.6))

                // 明確標註版本號
                Button {
                    showInfoSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("版本 \(appVersionString)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                Text("•")
                    .font(.footnote)
                    .foregroundColor(.secondary.opacity(0.6))

                Text(platformArchitectureDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("手寫與錄音雙向對齊 · 離線優先 · 開源透明")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private func formatDuration(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 應用程式與核心診斷面板（點擊版本號展開）
public struct AppDiagnosticsSheet: View {
    let versionString: String
    let platformDesc: String
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            List {
                Section("應用程式版本資訊") {
                    HStack {
                        Text("版本號")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Rust Core 引擎")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("執行平台")
                        Spacer()
                        Text(platformDesc)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("架構模式")
                        Spacer()
                        Text("Mac Catalyst / iOS 通用 (方案一)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("核心技術與授權") {
                    HStack {
                        Text("開源授權")
                        Spacer()
                        Text("Apache-2.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("跨平台架構")
                        Spacer()
                        Text("Rust Core + UniFFI + Metal/SwiftUI")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("關於 Kairumo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeWorkbenchView()
}

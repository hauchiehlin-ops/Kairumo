//
//  AudioAttachment.swift
//  Kairumo
//
//  頁面上的錄音物件：插入、播放、搬移、縮放、旋轉、改名、刪除。
//
//  # 為什麼要有這個
//
//  在此之前，錄音只存在兩個地方：首頁的「最近錄音」清單，以及筆記本層級的
//  `recordingAudioPath`。兩者都沒有座標 —— 使用者在首頁錄完一段課堂內容，
//  打開筆記本後，那段錄音不在任何一頁上，也就無從「放在這一段筆記旁邊」。
//
//  這一層把錄音變成**和圖片、表格同一層級的畫布物件**：有頁次、有位置、
//  有尺寸，也就進得了堆疊順序與圖層面板。
//

import SwiftUI

// MARK: - 顯示格式

enum AudioAttachmentFormat {
    /// `mm:ss`。錄音很少超過一小時，超過就讓分鐘欄位自己長出去 ——
    /// 補上小時欄位會讓九成的卡片多兩個字元的空白。
    static func duration(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }
}

// MARK: - 畫布上的錄音卡片

struct AudioAttachmentItemView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var audioManager = AudioRecorderManager.shared
    @Binding var item: NoteAudioAttachment
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isSelected: Bool = false
    /// 縮放拖曳中的即時尺寸。直接改 item.width 會每一幀都寫回筆記。
    @State private var liveSize: CGSize? = nil
    @State private var resizeBase: CGSize? = nil
    @State private var isRenaming: Bool = false
    @State private var renameText: String = ""

    private var displayWidth: CGFloat { liveSize?.width ?? item.width }
    private var displayHeight: CGFloat { liveSize?.height ?? item.height }

    /// 播放狀態是以**附件 id** 為鍵，不是錄音 id ——
    /// 同一段錄音可以插在兩頁上，按下第 2 頁那張時第 1 頁不該一起變成暫停鈕。
    private var isPlayingThis: Bool {
        audioManager.isPlaying && audioManager.playingRecordingId == item.id
    }

    private var fileUrl: URL {
        audioManager.recordingsDirectory.appendingPathComponent(item.fileName)
    }

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileUrl.path)
    }

    var body: some View {
        let currentX = item.x + dragOffset.width
        let currentY = item.y + dragOffset.height

        card
            // 卡片本體跟著轉；把手掛在旋轉**外面**的 overlay ——
            // 包進去的話拖曳算出的角度會疊加自身旋轉，卡片會失控加速。
            .rotationEffect(.degrees(item.canvasRotation))
            .overlay {
                if isSelected {
                    GeometryReader { geo in
                        ObjectRotationHandle(degrees: $item.canvasRotation, size: geo.size)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                    .accessibilityLabel(localizationManager.localized("action_delete"))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected { resizeHandle }
            }
            .overlay(alignment: .bottomLeading) {
                if isSelected {
                    Button {
                        renameText = item.title
                        isRenaming = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .offset(x: -10, y: 10)
                    .accessibilityLabel(localizationManager.localized("rename_audio_card"))
                    .help(localizationManager.localized("rename_audio_card"))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        item.x += value.translation.width
                        item.y += value.translation.height
                        dragOffset = .zero
                    }
            )
            .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
            .alert(localizationManager.localized("rename_audio_card"), isPresented: $isRenaming) {
                TextField(localizationManager.localized("recording_title"), text: $renameText)
                Button(localizationManager.localized("done")) {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { item.title = trimmed }
                }
                Button(localizationManager.localized("cancel"), role: .cancel) {}
            }
    }

    private var card: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(fileExists ? 0.12 : 0.05))
                        .frame(width: 34, height: 34)
                    Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(fileExists ? .red : .secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!fileExists)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty
                     ? localizationManager.localized("layer_kind_audio")
                     : item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if fileExists {
                    if isPlayingThis {
                        ProgressView(value: audioManager.playbackProgress)
                            .progressViewStyle(.linear)
                            .tint(.red)
                    } else {
                        Text(AudioAttachmentFormat.duration(item.durationSeconds))
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 檔案不見了要講清楚。否則使用者只會看到一個按不動的播放鈕。
                    Text(localizationManager.localized("audio_file_missing"))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "waveform")
                .font(.system(size: 15))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: displayWidth, height: displayHeight)
        .background(ObjectFrameStyleResolver.background(item, .audio))
        .cornerRadius(item.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: item.cornerRadius)
                .stroke(
                    isSelected ? Color.accentColor
                               : ObjectFrameStyleResolver.borderColor(item, .audio),
                    lineWidth: isSelected ? 1.5
                                          : ObjectFrameStyleResolver.borderWidth(item, .audio)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .contentShape(Rectangle())
        // 選取用長按，不用點擊 —— 點擊要留給卡片裡的播放鈕，
        // 兩者都掛 onTapGesture 的話，按播放會先被外層吃掉。
        .onLongPressGesture(minimumDuration: 0.35) {
            isSelected.toggle()
        }
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(Color.accentColor)
            .clipShape(Circle())
            .contentShape(Circle())
            .offset(x: 10, y: 10)
            .accessibilityLabel(localizationManager.localized("resize_audio_card"))
            .help(localizationManager.localized("resize_audio_card"))
            .highPriorityGesture(
                DragGesture(minimumDistance: 1,
                            coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        let base = resizeBase ?? CGSize(width: item.width, height: item.height)
                        if resizeBase == nil { resizeBase = base }
                        // 下限取播放鈕還按得到的尺寸。
                        liveSize = CGSize(
                            width: max(150, base.width + value.translation.width),
                            height: max(56, base.height + value.translation.height)
                        )
                    }
                    .onEnded { _ in
                        if let size = liveSize {
                            item.width = size.width
                            item.height = size.height
                        }
                        resizeBase = nil
                        liveSize = nil
                    }
            )
    }

    private func togglePlayback() {
        guard fileExists else { return }
        if isPlayingThis {
            audioManager.pauseAudio()
        } else {
            audioManager.playAudio(url: fileUrl, recordingId: item.id)
        }
    }
}

// MARK: - 插入選單

/// 挑一段已存在的錄音插到目前這一頁。
///
/// 清單來源就是首頁那一份 `NotebookStore.recordings` —— 使用者在首頁錄的、
/// 在筆記本裡錄的，都在這裡找得到。不另外做一份索引，兩份遲早會不一致。
struct AudioInsertPickerSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var store = NotebookStore.shared
    @ObservedObject private var audioManager = AudioRecorderManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 回傳被選中的錄音。位置與頁次由呼叫端決定。
    let onPick: (AudioRecordingRecord) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.recordings.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "mic.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(localizationManager.localized("no_recordings_hint"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.recordings) { rec in
                            Button {
                                onPick(rec)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "waveform.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(rec.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        HStack(spacing: 6) {
                                            Text(AudioAttachmentFormat.duration(rec.durationSeconds))
                                                .monospacedDigit()
                                            Text("•")
                                            Text(rec.recordedDate, style: .date)
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.accentColor)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("insert_audio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - 從首頁把錄音放進筆記

/// 首頁錄音清單的「插入至筆記」：挑一本筆記、挑一頁，把錄音放上去。
///
/// 頁次要讓使用者選 —— 一律塞到第 1 頁的話，十頁的會議記錄裡那段錄音
/// 永遠離它對應的段落十頁遠，等於沒有插。
struct RecordingToNotebookSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var store = NotebookStore.shared
    @Environment(\.dismiss) private var dismiss

    let recording: AudioRecordingRecord

    @State private var selectedNotebookId: String? = nil
    @State private var pageNumber: Int = 1

    private var selectedNotebook: NotebookDocument? {
        store.notebooks.first { $0.id == selectedNotebookId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localizationManager.localized("recording_title")) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recording.title).font(.subheadline)
                            Text(AudioAttachmentFormat.duration(recording.durationSeconds))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(localizationManager.localized("all_notebooks")) {
                    if store.notebooks.isEmpty {
                        Text(localizationManager.localized("notebook_empty"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(store.notebooks) { book in
                        Button {
                            selectedNotebookId = book.id
                            pageNumber = min(pageNumber, max(1, book.pageCount))
                        } label: {
                            HStack {
                                Text(book.displayTitle())
                                    .foregroundColor(.primary)
                                Spacer()
                                if book.id == selectedNotebookId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let book = selectedNotebook {
                    Section(localizationManager.localized("insert_audio_page")) {
                        Stepper(
                            "\(localizationManager.localized("page_label")) \(pageNumber) / \(max(1, book.pageCount))",
                            value: $pageNumber,
                            in: 1...max(1, book.pageCount)
                        )
                    }
                }
            }
            .navigationTitle(localizationManager.localized("insert_to_notebook"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("insert")) { insert() }
                        .disabled(selectedNotebookId == nil)
                }
            }
        }
    }

    private func insert() {
        guard var book = selectedNotebook else { return }
        let page = max(0, min(pageNumber - 1, max(0, book.pageCount - 1)))
        let existing = (book.audioAttachments ?? []).filter { $0.pageIndex == page }.count
        let offset = CGFloat(existing % 6) * 18
        var list = book.audioAttachments ?? []
        list.append(
            NoteAudioAttachment(
                pageIndex: page,
                recordingId: recording.id,
                fileName: recording.fileName,
                title: recording.title,
                durationSeconds: recording.durationSeconds,
                x: 80 + offset,
                y: 120 + offset
            )
        )
        book.audioAttachments = list
        book.hasRecording = true
        store.updateNotebook(book)
        dismiss()
    }
}

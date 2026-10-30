//
//  TranslationPenOverlay.swift
//  Kairumo
//
//  掃描翻譯筆（Translation Pen）互動覆蓋層、首次語系設定面板、智慧混合文字擷取與快顯雙語卡片。
//

import AVFoundation
import PencilKit
import SwiftUI
import UIKit

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 掃描翻譯筆單次（或跨行連掃）快顯卡片的狀態。
struct TranslationPenCardState: Identifiable, Equatable {
    let id: String
    var scanRect: CGRect
    var sourceText: String
    var translatedText: String
    var userNote: String
    var analysis: FfiScanAnalysis
    var isTranslating: Bool
    var isBlurryWarning: Bool = false
}

/// 掃描翻譯筆的雙語朗讀合成器（支援 1.0x 正常語速與 0.75x 慢速跟讀）。
@MainActor
final class TranslationPenSpeechPlayer: ObservableObject {
    // profile-scope: device 硬體語音合成器不隨帳號切換保存任何個人狀態
    static let shared = TranslationPenSpeechPlayer()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(text: String, langTag: String, slow: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let localeTag = Self.resolveTtsLocale(for: langTag)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: localeTag)
            ?? AVSpeechSynthesisVoice(language: langTag)
        utterance.rate = slow
            ? max(AVSpeechUtteranceMinimumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 0.72)
            : AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private static func resolveTtsLocale(for tag: String) -> String {
        if let matched = translationPenLanguages().first(where: {
            $0.tag.caseInsensitiveCompare(tag) == .orderedSame
        }) {
            return matched.ttsLocale
        }
        return tag
    }
}

/// 畫布上的掃描翻譯筆覆蓋層。
public struct TranslationPenOverlayView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Binding public var notebook: NotebookDocument
    @Binding public var drawing: PKDrawing
    public let pageIndex: Int
    public let isActive: Bool
    public let onNotebookChanged: () -> Void
    public var onDrawingChanged: ((PKDrawing) -> Void)? = nil

    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil
    @State private var activeCard: TranslationPenCardState? = nil
    @State private var isShowingSetupSheet: Bool = false
    @State private var hasCheckedFirstActivation: Bool = false
    @State private var translationTaskId: Int = 0

    private let supportedLanguages: [FfiTranslationLangInfo] = translationPenLanguages()

    public init(
        notebook: Binding<NotebookDocument>,
        drawing: Binding<PKDrawing>,
        pageIndex: Int,
        isActive: Bool,
        onNotebookChanged: @escaping () -> Void,
        onDrawingChanged: ((PKDrawing) -> Void)? = nil
    ) {
        self._notebook = notebook
        self._drawing = drawing
        self.pageIndex = pageIndex
        self.isActive = isActive
        self.onNotebookChanged = onNotebookChanged
        self.onDrawingChanged = onDrawingChanged
    }

    private var currentConfig: NoteTranslationPenConfig {
        if let existing = notebook.translationPenConfig {
            return existing
        }
        let def = translationPenDefaultConfig(uiLanguage: localizationManager.currentLanguage.rawValue)
        return NoteTranslationPenConfig(
            sourceLang: def.sourceLang,
            targetLang: def.targetLang,
            multiLineStitch: def.multiLineStitch,
            slowTts: def.slowTts,
            configured: def.configured
        )
    }

    private func updateConfig(_ mutate: (inout NoteTranslationPenConfig) -> Void) {
        var cfg = currentConfig
        mutate(&cfg)
        notebook.translationPenConfig = cfg
        onNotebookChanged()
    }

    private func shortLabel(for tag: String) -> String {
        supportedLanguages.first(where: { $0.tag.caseInsensitiveCompare(tag) == .orderedSame })?.shortLabel
            ?? tag.uppercased()
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(isActive)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            guard isActive else { return }
                            if dragStart == nil {
                                dragStart = value.startLocation
                            }
                            dragCurrent = value.location
                        }
                        .onEnded { value in
                            guard isActive else { return }
                            if let start = dragStart {
                                let rect = Self.normalizedRect(from: start, to: value.location)
                                dragStart = nil
                                dragCurrent = nil
                                if rect.width >= 10 && rect.height >= 6 {
                                    handleScanCompleted(in: rect)
                                }
                            }
                        }
                )

            // 1. 拖曳中的光學掃描筆光束框
            if isActive, let start = dragStart, let current = dragCurrent {
                let rect = Self.normalizedRect(from: start, to: current)
                ScanBeamPreviewView(rect: rect)
                    .allowsHitTesting(false)
            }

            // 2. 已掃描鎖定的區域標記框
            if isActive, let card = activeCard {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cyan.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                Color.teal,
                                style: StrokeStyle(lineWidth: 1.8, dash: [5, 3])
                            )
                    )
                    .frame(width: card.scanRect.width, height: card.scanRect.height)
                    .position(x: card.scanRect.midX, y: card.scanRect.midY)
                    .allowsHitTesting(false)

                // 3. 快顯雙語翻譯與編輯卡片
                TranslationPenPopoverCard(
                    card: Binding(
                        get: { activeCard ?? card },
                        set: { activeCard = $0 }
                    ),
                    config: currentConfig,
                    onRetranslate: { editedSource in
                        retranslate(sourceText: editedSource)
                    },
                    onToggleSlowTts: {
                        updateConfig { $0.slowTts.toggle() }
                    },
                    onClearStitch: {
                        activeCard = nil
                    },
                    onPinAsComment: {
                        pinCurrentCardAsComment()
                    },
                    onInsertTextBox: {
                        insertCurrentCardAsTextBox()
                    },
                    onHighlightArea: {
                        highlightCurrentScanArea()
                    },
                    onMaskingTapeArea: {
                        maskCurrentScanAreaWithTape()
                    },
                    onCopyText: {
                        copyCurrentCardToPasteboard()
                    },
                    onDismiss: {
                        TranslationPenSpeechPlayer.shared.stop()
                        activeCard = nil
                    }
                )
                .position(popoverPosition(for: card.scanRect))
                .zIndex(20)
            }

            // 4. 畫布頂部懸浮語系與跨行連掃狀態膠囊
            if isActive {
                topLanguagePill
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(25)
            }
        }
        .modifier(TranslationBridge.modifier())
        .onChange(of: isActive) { _, active in
            if active {
                ensureFirstTimeLanguageSetupIfNeeded()
            } else {
                TranslationPenSpeechPlayer.shared.stop()
                dragStart = nil
                dragCurrent = nil
            }
        }
        .onAppear {
            if isActive {
                ensureFirstTimeLanguageSetupIfNeeded()
            }
        }
        .sheet(isPresented: $isShowingSetupSheet) {
            TranslationPenSetupSheet(
                config: currentConfig,
                languages: supportedLanguages,
                onConfirm: { updated in
                    var saved = updated
                    saved.configured = true
                    notebook.translationPenConfig = saved
                    onNotebookChanged()
                    if let current = activeCard, !current.sourceText.isEmpty {
                        retranslate(sourceText: current.sourceText)
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - 頂部語系與連掃膠囊

    private var topLanguagePill: some View {
        let cfg = currentConfig
        return HStack(spacing: 8) {
            Button {
                isShowingSetupSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.teal)
                    Text(shortLabel(for: cfg.sourceLang))
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(shortLabel(for: cfg.targetLang))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.teal)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.teal.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.translationPen.languagePill")

            Button {
                updateConfig { c in
                    let oldSource = c.sourceLang
                    c.sourceLang = c.targetLang
                    c.targetLang = oldSource
                    c.configured = true
                }
                if let current = activeCard, !current.sourceText.isEmpty {
                    retranslate(sourceText: current.sourceText)
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("trans_pen_swap_lang"))

            Button {
                updateConfig { c in
                    c.multiLineStitch.toggle()
                    c.configured = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: cfg.multiLineStitch ? "text.append" : "line.diagonal")
                        .font(.system(size: 11, weight: .semibold))
                    Text(
                        localizationManager.localized(
                            cfg.multiLineStitch ? "trans_pen_stitch_active" : "trans_pen_stitch_off"
                        )
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(cfg.multiLineStitch ? Color.white : Color.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    cfg.multiLineStitch ? Color.teal : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)

            if activeCard == nil {
                Text(localizationManager.localized("trans_pen_drag_hint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.teal.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
    }

    // MARK: - 首次啟動語系選擇檢查

    private func ensureFirstTimeLanguageSetupIfNeeded() {
        // UI 測試環境下不自動跳出模態視窗，以免遮擋自動化稽核樹
        guard ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] != "1" else { return }
        if notebook.translationPenConfig == nil {
            let def = translationPenDefaultConfig(uiLanguage: localizationManager.currentLanguage.rawValue)
            notebook.translationPenConfig = NoteTranslationPenConfig(
                sourceLang: def.sourceLang,
                targetLang: def.targetLang,
                multiLineStitch: def.multiLineStitch,
                slowTts: def.slowTts,
                configured: false
            )
        }
        if notebook.translationPenConfig?.configured != true && !hasCheckedFirstActivation {
            hasCheckedFirstActivation = true
            isShowingSetupSheet = true
        }
    }

    // MARK: - 智慧混合文字擷取 (方案 A：物件文字直取 + PDF/圖片/手寫 OCR)

    private func handleScanCompleted(in rect: CGRect) {
        let cfg = currentConfig
        let previousCard = activeCard
        let shouldStitch = cfg.multiLineStitch
            && previousCard != nil
            && !(previousCard?.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        let combinedRect: CGRect = if shouldStitch, let prev = previousCard {
            prev.scanRect.union(rect)
        } else {
            rect
        }

        // 先顯示快顯視窗骨架，讓使用者獲得零延遲回饋
        let placeholderAnalysis = translationPenAnalyzeScan(
            text: previousCard?.sourceText ?? "",
            sourceLang: cfg.sourceLang
        )
        activeCard = TranslationPenCardState(
            id: previousCard?.id ?? UUID().uuidString.lowercased(),
            scanRect: combinedRect,
            sourceText: previousCard?.sourceText ?? "",
            translatedText: previousCard?.translatedText ?? "",
            userNote: previousCard?.userNote ?? "",
            analysis: placeholderAnalysis,
            isTranslating: true
        )

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        translationTaskId += 1
        let currentTask = translationTaskId

        Task { @MainActor in
            let extraction = await extractTextFromCanvas(in: rect)
            guard currentTask == translationTaskId else { return }
            let rawExtracted = extraction.text

            let mergedSource: String
            if shouldStitch, let prevText = previousCard?.sourceText, !prevText.isEmpty, !rawExtracted.isEmpty, !extraction.isBlurryOrLowConfidence {
                mergedSource = translationPenStitchLines(
                    previousText: prevText,
                    newText: rawExtracted,
                    sourceLang: cfg.sourceLang
                )
            } else if !rawExtracted.isEmpty {
                mergedSource = rawExtracted
            } else {
                mergedSource = shouldStitch ? (previousCard?.sourceText ?? "") : ""
            }

            let analysis = translationPenAnalyzeScan(
                text: mergedSource,
                sourceLang: cfg.sourceLang
            )
            let cleaned = analysis.cleanedText
            let isBlurry = extraction.isBlurryOrLowConfidence || (!cleaned.isEmpty && analysis.isLowConfidence)
            activeCard?.sourceText = cleaned
            activeCard?.analysis = analysis
            activeCard?.isBlurryWarning = isBlurry

            // 當目標文字模糊、系統難以判斷或無有效文字時，提出快顯說明，絕不胡亂編造輸出語言
            guard !cleaned.isEmpty && !isBlurry else {
                activeCard?.translatedText = ""
                activeCard?.isTranslating = false
                return
            }

            let translated = await TranscriptTranslation.finalize(
                cleaned,
                recognizedIn: cfg.sourceLang,
                targetLanguage: cfg.targetLang
            )
            guard currentTask == translationTaskId else { return }
            activeCard?.translatedText = translated
            activeCard?.isTranslating = false
        }
    }

    private func retranslate(sourceText: String) {
        let cfg = currentConfig
        let analysis = translationPenAnalyzeScan(text: sourceText, sourceLang: cfg.sourceLang)
        let cleaned = analysis.cleanedText
        activeCard?.sourceText = cleaned
        activeCard?.analysis = analysis
        activeCard?.isBlurryWarning = false
        guard !cleaned.isEmpty else {
            activeCard?.translatedText = ""
            activeCard?.isTranslating = false
            return
        }
        activeCard?.isTranslating = true
        translationTaskId += 1
        let currentTask = translationTaskId

        Task { @MainActor in
            let translated = await TranscriptTranslation.finalize(
                cleaned,
                recognizedIn: cfg.sourceLang,
                targetLanguage: cfg.targetLang
            )
            guard currentTask == translationTaskId else { return }
            activeCard?.translatedText = translated
            activeCard?.isTranslating = false
        }
    }

    /// 智慧混合文字擷取：
    /// 1. 優先擷取與掃描框相交的結構化畫布物件（文字方塊、表格儲存格、流程圖形狀、連結卡片）。
    /// 2. 若未命中結構化文字（或同時掃過手寫筆跡／PDF 底圖／圖片附件），自動裁切筆劃與圖片區域進行裝置端 Vision OCR。
    /// 3. 若掃過圖片或手寫筆跡但辨識信心過低／字跡模糊，標記 `isBlurryOrLowConfidence = true`，防止胡亂編造譯文。
    private func extractTextFromCanvas(in scanRect: CGRect) async -> (text: String, isBlurryOrLowConfidence: Bool) {
        let expandedRect = scanRect.insetBy(dx: -6, dy: -6)
        let sourceLang = currentConfig.sourceLang
        var pieces: [String] = []

        // 1. 文字方塊 (NoteTextAttachment)
        let pageTexts = (notebook.textAttachments ?? [])
            .filter { $0.pageIndex == pageIndex }
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        for item in pageTexts {
            let frame = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
            if frame.intersects(expandedRect) {
                let extracted = Self.extractSubstringInRect(
                    fullText: item.text,
                    itemFrame: frame,
                    scanRect: expandedRect
                )
                if !extracted.isEmpty {
                    pieces.append(extracted)
                }
            }
        }

        // 2. 表格 (NoteTableAttachment)
        let pageTables = (notebook.tableAttachments ?? [])
            .filter { $0.pageIndex == pageIndex }
        for table in pageTables {
            let estimatedHeight = CGFloat(max(1, table.rows)) * 36.0
            let frame = CGRect(x: table.x, y: table.y, width: table.width, height: estimatedHeight)
            if frame.intersects(expandedRect) {
                let nonEmptyCells = table.cells
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !nonEmptyCells.isEmpty {
                    pieces.append(nonEmptyCells.joined(separator: " "))
                }
            }
        }

        // 3. 形狀與流程圖標籤 (NoteShapeAttachment)
        let pageShapes = (notebook.shapeAttachments ?? [])
            .filter { $0.pageIndex == pageIndex }
        for shape in pageShapes {
            let frame = CGRect(x: shape.x, y: shape.y, width: shape.width, height: shape.height)
            if frame.intersects(expandedRect) {
                let label = shape.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if !label.isEmpty {
                    pieces.append(label)
                }
            }
        }

        // 4. 連結預覽卡片 (NoteLinkAttachment)
        let pageLinks = (notebook.linkAttachments ?? [])
            .filter { $0.pageIndex == pageIndex }
        for link in pageLinks {
            let frame = CGRect(x: link.x, y: link.y, width: link.width, height: link.height)
            if frame.intersects(expandedRect) {
                let combined = [link.title, link.descriptionText]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !combined.isEmpty {
                    pieces.append(combined)
                }
            }
        }

        if !pieces.isEmpty {
            return (pieces.joined(separator: " "), false)
        }

        var hadVisualTarget = false
        var sawLowConfidence = false

        // 5. 檢查圖片／匯入之 PDF 頁面附件並裁切掃描區域跑 Vision OCR
        let pageImages = (notebook.attachments ?? [])
            .filter { $0.pageIndex == pageIndex }
        let attachmentsDir = NotebookStore.shared.attachmentsDirectory
        for att in pageImages {
            let frame = CGRect(x: att.x, y: att.y, width: att.width, height: att.height)
            let intersection = frame.intersection(expandedRect)
            guard !intersection.isNull, intersection.width >= 6, intersection.height >= 6 else {
                continue
            }
            hadVisualTarget = true
            let fileURL = attachmentsDir.appending(path: att.fileName)
            if let image = UIImage(contentsOfFile: fileURL.path),
               let cropped = Self.cropImage(image, attachmentFrame: frame, cropRect: intersection)
            {
                let ocrResult = await HandwritingRecognizer.recognizeForScanPen(
                    image: cropped,
                    languageTag: sourceLang
                )
                if ocrResult.isLowConfidence {
                    sawLowConfidence = true
                }
                if !ocrResult.text.isEmpty {
                    pieces.append(ocrResult.text)
                }
            }
        }

        // 6. 檢查手寫筆劃 (PKDrawing) 並針對掃描區域內的筆跡做 Vision 辨識
        let matchedStrokes = drawing.strokes.filter { stroke in
            stroke.renderBounds.intersects(expandedRect.insetBy(dx: -8, dy: -8))
        }
        if !matchedStrokes.isEmpty {
            hadVisualTarget = true
            let inkResult = await HandwritingRecognizer.recognizeForScanPen(
                strokes: matchedStrokes,
                languageTag: sourceLang
            )
            if inkResult.isLowConfidence {
                sawLowConfidence = true
            }
            if !inkResult.text.isEmpty {
                pieces.append(inkResult.text)
            }
        }

        let joined = pieces.joined(separator: " ")
        let isBlurry = sawLowConfidence || (hadVisualTarget && joined.isEmpty)
        return (joined, isBlurry)
    }

    /// 當掃描框只掃過多行文字方塊的其中一行或局部水平區段時，依垂直與水平比例擷取對應行／詞。
    private static func extractSubstringInRect(
        fullText: String,
        itemFrame: CGRect,
        scanRect: CGRect
    ) -> String {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1, itemFrame.height > 28 else {
            return extractHorizontalWords(from: trimmed, itemFrame: itemFrame, scanRect: scanRect)
        }
        let lineHeight = itemFrame.height / CGFloat(lines.count)
        var selectedLines: [String] = []
        for (idx, line) in lines.enumerated() {
            let lineMinY = itemFrame.minY + CGFloat(idx) * lineHeight
            let lineMaxY = lineMinY + lineHeight
            if scanRect.maxY >= lineMinY && scanRect.minY <= lineMaxY {
                selectedLines.append(
                    extractHorizontalWords(from: line, itemFrame: itemFrame, scanRect: scanRect)
                )
            }
        }
        let joined = selectedLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? trimmed : joined
    }

    private static func extractHorizontalWords(
        from line: String,
        itemFrame: CGRect,
        scanRect: CGRect
    ) -> String {
        guard itemFrame.width > 40 else { return line }
        let relStart = max(0, min(1, (scanRect.minX - itemFrame.minX) / itemFrame.width))
        let relEnd = max(0, min(1, (scanRect.maxX - itemFrame.minX) / itemFrame.width))
        // 若掃描寬度涵蓋超過 65% 的文字方塊寬度，直接取整行
        if (relEnd - relStart) >= 0.65 {
            return line
        }
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count >= 3 {
            let totalChars = max(1, line.count)
            var cursor = 0
            var picked: [String] = []
            for word in words {
                let wordStart = CGFloat(cursor) / CGFloat(totalChars)
                let wordEnd = CGFloat(cursor + word.count) / CGFloat(totalChars)
                cursor += word.count + 1
                if wordEnd >= relStart && wordStart <= relEnd {
                    picked.append(word)
                }
            }
            if !picked.isEmpty {
                return picked.joined(separator: " ")
            }
        }
        return line
    }

    private static func cropImage(
        _ image: UIImage,
        attachmentFrame: CGRect,
        cropRect: CGRect
    ) -> UIImage? {
        guard let cgImage = image.cgImage,
              attachmentFrame.width > 1,
              attachmentFrame.height > 1
        else { return nil }
        let scaleX = CGFloat(cgImage.width) / attachmentFrame.width
        let scaleY = CGFloat(cgImage.height) / attachmentFrame.height
        let pixelRect = CGRect(
            x: max(0, (cropRect.minX - attachmentFrame.minX) * scaleX),
            y: max(0, (cropRect.minY - attachmentFrame.minY) * scaleY),
            width: min(CGFloat(cgImage.width), cropRect.width * scaleX),
            height: min(CGFloat(cgImage.height), cropRect.height * scaleY)
        ).integral
        guard pixelRect.width >= 4, pixelRect.height >= 4,
              let croppedCG = cgImage.cropping(to: pixelRect)
        else { return nil }
        return UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - 卡片持久化動作（轉為圖釘、貼入註解、一鍵螢光標記、一鍵遮蔽膠帶）

    private func formattedCardMessage() -> String {
        guard let card = activeCard else { return "" }
        let cfg = currentConfig
        return translationPenFormatPinMessage(
            sourceText: card.sourceText,
            translatedText: card.translatedText,
            note: card.userNote,
            sourceLang: cfg.sourceLang,
            targetLang: cfg.targetLang
        )
    }

    private func pinCurrentCardAsComment() {
        guard let card = activeCard else { return }
        let messageText = formattedCardMessage()
        guard !messageText.isEmpty else { return }

        let identity = UserIdentityStore.shared
        let msg = NoteCommentMessage(
            authorId: identity.userId,
            authorName: identity.displayName,
            authorColor: identity.colorHex,
            text: messageText
        )
        let pinX = min(max(28, card.scanRect.maxX + 12), PageGeometry.width - 28)
        let pinY = min(max(28, card.scanRect.minY), PageGeometry.height - 28)
        let pin = NoteCommentPin(
            pageIndex: pageIndex,
            x: pinX,
            y: pinY,
            authorId: identity.userId,
            authorName: identity.displayName,
            authorColor: identity.colorHex,
            messages: [msg]
        )
        if notebook.commentPins == nil {
            notebook.commentPins = []
        }
        notebook.commentPins?.append(pin)
        onNotebookChanged()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        activeCard = nil
    }

    private func insertCurrentCardAsTextBox() {
        guard let card = activeCard else { return }
        let content = formattedCardMessage()
        guard !content.isEmpty else { return }

        let boxWidth: CGFloat = min(320, max(220, card.scanRect.width + 80))
        let boxHeight: CGFloat = card.userNote.isEmpty ? 96 : 124
        let boxX = min(max(24, card.scanRect.minX), PageGeometry.width - boxWidth - 24)
        let boxY = min(max(24, card.scanRect.maxY + 10), PageGeometry.height - boxHeight - 24)

        let attachment = NoteTextAttachment(
            pageIndex: pageIndex,
            text: content,
            fontSize: 14,
            alignmentRaw: "left",
            textColorHex: "#1E293B",
            backgroundColorHex: "#FFFBEB",
            hasBorder: true,
            cornerRadius: 10,
            borderColorHex: "#0D9488",
            borderWidth: 1.5,
            x: boxX,
            y: boxY,
            width: boxWidth,
            height: boxHeight
        )
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(attachment)

        // 若掃描框下有手寫筆劃，一併建立動態流式錨定 (Fluid Sticky Annotation)
        let matchedIndices = drawing.strokes.indices.filter { idx in
            drawing.strokes[idx].renderBounds.intersects(card.scanRect.insetBy(dx: -6, dy: -6))
        }
        if !matchedIndices.isEmpty {
            let anchor = StickyAnnotationAnchor(
                pageIndex: pageIndex,
                targetId: attachment.id,
                strokeIndices: Array(matchedIndices),
                anchorOriginX: Float(boxX),
                anchorOriginY: Float(boxY)
            )
            if notebook.stickyAnchors == nil {
                notebook.stickyAnchors = []
            }
            notebook.stickyAnchors?.append(anchor)
        }

        onNotebookChanged()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        activeCard = nil
    }

    private func highlightCurrentScanArea() {
        guard let card = activeCard else { return }
        let midY = card.scanRect.midY
        let startX = card.scanRect.minX + 4
        let endX = max(startX + 12, card.scanRect.maxX - 4)
        let bandHeight = min(max(18, card.scanRect.height * 0.8), 36)
        let pointSize = CGSize(width: bandHeight, height: bandHeight)

        let p0 = PKStrokePoint(
            location: CGPoint(x: startX, y: midY),
            timeOffset: 0,
            size: pointSize,
            opacity: 0.35,
            force: 1.0,
            azimuth: 0,
            altitude: .pi / 2
        )
        let p1 = PKStrokePoint(
            location: CGPoint(x: endX, y: midY),
            timeOffset: 0.08,
            size: pointSize,
            opacity: 0.35,
            force: 1.0,
            azimuth: 0,
            altitude: .pi / 2
        )
        let path = PKStrokePath(controlPoints: [p0, p1], creationDate: Date())
        let ink = PKInk(.marker, color: UIColor.systemYellow.withAlphaComponent(0.38))
        let stroke = PKStroke(ink: ink, path: path)
        var updatedStrokes = drawing.strokes
        updatedStrokes.append(stroke)
        let updatedDrawing = PKDrawing(strokes: updatedStrokes)
        drawing = updatedDrawing
        onDrawingChanged?(updatedDrawing)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func maskCurrentScanAreaWithTape() {
        guard let card = activeCard else { return }
        let tape = NoteTapeAttachment(
            pageIndex: pageIndex,
            x: card.scanRect.minX,
            y: card.scanRect.minY,
            width: max(48, card.scanRect.width),
            height: max(24, card.scanRect.height),
            colorHex: "#0D9488",
            patternRaw: TapePattern.striped.rawValue,
            isRevealed: false
        )
        if notebook.tapeAttachments == nil {
            notebook.tapeAttachments = []
        }
        notebook.tapeAttachments?.append(tape)
        onNotebookChanged()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func copyCurrentCardToPasteboard() {
        let msg = formattedCardMessage()
        guard !msg.isEmpty else { return }
        UIPasteboard.general.string = msg
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    // MARK: - 幾何定位輔助

    private static func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        let minX = min(a.x, b.x)
        let maxX = max(a.x, b.x)
        let minY = min(a.y, b.y)
        let maxY = max(a.y, b.y)
        return CGRect(
            x: minX,
            y: minY,
            width: max(16, maxX - minX),
            height: max(22, maxY - minY)
        )
    }

    private func popoverPosition(for scanRect: CGRect) -> CGPoint {
        let cardWidth: CGFloat = 356
        let cardHeight: CGFloat = 290
        let clampedX = min(
            max(cardWidth / 2 + 12, scanRect.midX),
            PageGeometry.width - cardWidth / 2 - 12
        )
        let belowY = scanRect.maxY + cardHeight / 2 + 14
        let aboveY = scanRect.minY - cardHeight / 2 - 14
        let clampedY = (belowY + cardHeight / 2 <= PageGeometry.height - 12)
            ? belowY
            : max(cardHeight / 2 + 54, aboveY)
        return CGPoint(x: clampedX, y: clampedY)
    }
}

// MARK: - 掃描光束動態預覽

private struct ScanBeamPreviewView: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.26),
                            Color.teal.opacity(0.14),
                            Color.cyan.opacity(0.26),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.cyan, lineWidth: 2)

            // 中央雷射掃描導引線
            Rectangle()
                .fill(Color.cyan.opacity(0.85))
                .frame(width: max(4, rect.width - 8), height: 1.5)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .shadow(color: Color.cyan.opacity(0.35), radius: 6)
    }
}

// MARK: - 快顯雙語翻譯與學習卡片

private struct TranslationPenPopoverCard: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Binding var card: TranslationPenCardState
    let config: NoteTranslationPenConfig
    let onRetranslate: (String) -> Void
    let onToggleSlowTts: () -> Void
    let onClearStitch: () -> Void
    let onPinAsComment: () -> Void
    let onInsertTextBox: () -> Void
    let onHighlightArea: () -> Void
    let onMaskingTapeArea: () -> Void
    let onCopyText: () -> Void
    let onDismiss: () -> Void

    private var kindBadgeKey: String {
        switch card.analysis.kind {
        case .word: return "trans_pen_kind_word"
        case .phrase: return "trans_pen_kind_phrase"
        case .sentence: return "trans_pen_kind_sentence"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 頂列：智慧分流標籤（單字精查／片語／整句對照）+ 語速切換 + 重新起掃 + 關閉
            HStack(spacing: 6) {
                Text(localizationManager.localized(kindBadgeKey))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        card.analysis.kind == .word ? Color.indigo : Color.teal,
                        in: Capsule()
                    )

                if !card.analysis.grammarHintKey.isEmpty {
                    Text(localizationManager.localized(card.analysis.grammarHintKey))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onToggleSlowTts) {
                    Text(
                        localizationManager.localized(
                            config.slowTts ? "trans_pen_slow_tts" : "trans_pen_normal_tts"
                        )
                    )
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(config.slowTts ? Color.orange : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                if config.multiLineStitch {
                    Button(action: onClearStitch) {
                        Text(localizationManager.localized("trans_pen_clear_stitch"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.teal.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("close"))
            }

            // 目標文字模糊／難以判斷時的快顯警示橫幅（防止胡亂編造輸出語言）
            if card.isBlurryWarning {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(localizationManager.localized("trans_pen_blurry_warning"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            }

            // 單字模式專屬：詞根／字首字尾拆解提示 + 系統內建字典查詢
            if !card.analysis.phoneticOrStemHint.isEmpty || card.analysis.kind == .word {
                HStack(spacing: 8) {
                    if !card.analysis.phoneticOrStemHint.isEmpty {
                        Text(card.analysis.phoneticOrStemHint)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.indigo)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !card.sourceText.isEmpty {
                        Button {
                            presentSystemDictionary(for: card.sourceText)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 10))
                                Text(localizationManager.localized("trans_pen_lookup_dict"))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.indigo.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 原文區（可編輯修訂 + 原文發音朗讀 + 重新翻譯）
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(localizationManager.localized("trans_pen_source_label"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        TranslationPenSpeechPlayer.shared.speak(
                            text: card.sourceText,
                            langTag: config.sourceLang,
                            slow: config.slowTts
                        )
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                            Text(localizationManager.localized("trans_pen_speak_source"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.teal)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onRetranslate(card.sourceText)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                            Text(localizationManager.localized("trans_pen_retranslate"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                TextField(
                    localizationManager.localized("trans_pen_empty_scan"),
                    text: $card.sourceText,
                    axis: .vertical
                )
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1...3)
                .padding(7)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            // 譯文區（可編輯修正 + 譯文發音朗讀）
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(localizationManager.localized("trans_pen_target_label"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if card.isTranslating {
                        ProgressView()
                            .controlSize(.mini)
                        Text(localizationManager.localized("trans_pen_scanning"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        TranslationPenSpeechPlayer.shared.speak(
                            text: card.translatedText,
                            langTag: config.targetLang,
                            slow: config.slowTts
                        )
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                            Text(localizationManager.localized("trans_pen_speak_target"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.teal)
                    }
                    .buttonStyle(.plain)
                }

                TextField(
                    localizationManager.localized("trans_pen_target_label"),
                    text: $card.translatedText,
                    axis: .vertical
                )
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.teal)
                .lineLimit(1...4)
                .padding(7)
                .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            // 補充筆記欄
            TextField(
                localizationManager.localized("trans_pen_note_placeholder"),
                text: $card.userNote
            )
            .font(.system(size: 12))
            .padding(6)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.7), in: RoundedRectangle(cornerRadius: 7))

            Divider()

            // 底部動作列：圖釘、貼入註解、螢光標記、遮蔽膠帶、複製
            HStack(spacing: 6) {
                actionButton(
                    icon: "pin.fill",
                    labelKey: "trans_pen_action_pin",
                    tint: .orange,
                    action: onPinAsComment
                )
                actionButton(
                    icon: "note.text.badge.plus",
                    labelKey: "trans_pen_action_textbox",
                    tint: .teal,
                    action: onInsertTextBox
                )
                actionButton(
                    icon: "highlighter",
                    labelKey: "trans_pen_action_highlight",
                    tint: .yellow,
                    action: onHighlightArea
                )
                actionButton(
                    icon: "bandage.fill",
                    labelKey: "trans_pen_action_tape",
                    tint: .brown,
                    action: onMaskingTapeArea
                )
                actionButton(
                    icon: "doc.on.doc",
                    labelKey: "trans_pen_action_copy",
                    tint: .blue,
                    action: onCopyText
                )
            }
        }
        .padding(12)
        .frame(width: 356)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.teal.opacity(0.4), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
    }

    private func actionButton(
        icon: String,
        labelKey: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(localizationManager.localized(labelKey))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(tint == .yellow ? Color.orange : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func presentSystemDictionary(for term: String) {
        let cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let dictVC = UIReferenceLibraryViewController(term: cleaned)
        dictVC.modalPresentationStyle = .Automatic
        topVC.present(dictVC, animated: true)
        #endif
    }
}

// MARK: - 首次啟動與語系設定視窗 (Requirement 1)

private struct TranslationPenSetupSheet: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var draftConfig: NoteTranslationPenConfig
    let languages: [FfiTranslationLangInfo]
    let onConfirm: (NoteTranslationPenConfig) -> Void

    init(
        config: NoteTranslationPenConfig,
        languages: [FfiTranslationLangInfo],
        onConfirm: @escaping (NoteTranslationPenConfig) -> Void
    ) {
        self._draftConfig = State(initialValue: config)
        self.languages = languages
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(localizationManager.localized("trans_pen_setup_desc"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker(
                        localizationManager.localized("trans_pen_source_lang"),
                        selection: $draftConfig.sourceLang
                    ) {
                        ForEach(languages, id: \.tag) { lang in
                            Text("\(lang.endonym) (\(lang.shortLabel))")
                                .tag(lang.tag)
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            let oldSource = draftConfig.sourceLang
                            draftConfig.sourceLang = draftConfig.targetLang
                            draftConfig.targetLang = oldSource
                        } label: {
                            Label(
                                localizationManager.localized("trans_pen_swap_lang"),
                                systemImage: "arrow.up.arrow.down.circle.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.teal)
                        }
                        Spacer()
                    }

                    Picker(
                        localizationManager.localized("trans_pen_target_lang"),
                        selection: $draftConfig.targetLang
                    ) {
                        ForEach(languages, id: \.tag) { lang in
                            Text("\(lang.endonym) (\(lang.shortLabel))")
                                .tag(lang.tag)
                        }
                    }
                }

                Section {
                    Toggle(
                        localizationManager.localized("trans_pen_multiline_stitch"),
                        isOn: $draftConfig.multiLineStitch
                    )
                    Text(localizationManager.localized("trans_pen_multiline_desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(
                        localizationManager.localized("trans_pen_slow_tts"),
                        isOn: $draftConfig.slowTts
                    )
                }
            }
            .navigationTitle(localizationManager.localized("trans_pen_setup_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("trans_pen_start")) {
                        onConfirm(draftConfig)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

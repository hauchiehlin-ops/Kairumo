//
//  PlatformSelfCheck.swift
//  Kairumo
//
//  裝置上的一鍵自檢（驗證層 L4，見 docs/plans/ipad-first-verification.md）。
//
//  # 為什麼需要它
//
//  模擬器永遠缺：真實麥克風、「檔案」App 的真實 provider、背景／前景切換、記憶體壓力。
//  使用者回報「Mac 好好的、iPad 不行」時，我們只拿到一句症狀。這裡把那幾個**平台能力**
//  在使用者的裝置上真的跑一遍，並把結果整理成一份可以貼回來的報告 ——
//  通過／失敗與原因，而不是「播放沒反應」。
//
//  每一項都是獨立的、可重複執行的、不改使用者資料的（用暫存檔，用完刪）。
//

import AVFoundation
import Foundation
import Speech
import SwiftUI
import UIKit

/// 單一檢查項的結果。
struct SelfCheckResult: Identifiable, Equatable {
    enum Status: String { case pass, warn, fail }
    let id: String
    let title: String
    var status: Status
    var detail: String
}

@MainActor
final class PlatformSelfCheck: ObservableObject {
    @Published private(set) var results: [SelfCheckResult] = []
    @Published private(set) var isRunning = false

    /// 文字報告，給「複製」用。
    var report: String {
        let device = UIDevice.current
        var lines = [
            "Kairumo self-check",
            "device: \(device.model) / \(device.systemName) \(device.systemVersion) / idiom=\(device.userInterfaceIdiom.rawValue)",
            "screen: \(Int(UIScreen.main.bounds.width))×\(Int(UIScreen.main.bounds.height)) @\(UIScreen.main.scale)x",
            "language: \(LocalizationManager.shared.currentLanguage.rawValue)",
            "",
        ]
        for r in results { lines.append("[\(r.status.rawValue.uppercased())] \(r.title) — \(r.detail)") }
        return lines.joined(separator: "\n")
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        results = []
        let checks: [() async -> SelfCheckResult] = [
            checkAudioSession, checkPlaybackPipeline, checkMicrophonePermission,
            checkSpeechRecognizer, checkLibraryFolder, checkFilePickerPresenter,
            checkTranscriptScript, checkFreeSpace,
        ]
        for check in checks { results.append(await check()) }
        isRunning = false
    }

    // MARK: - 各項檢查

    /// 目前的 audio session。錄完音後若還停在 `.playAndRecord`，播放就可能失敗（見 `CoreAudioCapture.stop`）。
    private func checkAudioSession() async -> SelfCheckResult {
        let s = AVAudioSession.sharedInstance()
        let detail = "category=\(s.category.rawValue) mode=\(s.mode.rawValue) input=\(s.isInputAvailable) otherAudio=\(s.isOtherAudioPlaying)"
        return SelfCheckResult(id: "audio.session", title: "Audio session", status: .pass, detail: detail)
    }

    /// 合成一小段 Opus → 用真正的播放器播 → 時間要前進。這是「錄完按播放沒聲音」的直接檢驗。
    private func checkPlaybackPipeline() async -> SelfCheckResult {
        let title = "Playback pipeline"
        let url = FileManager.default.temporaryDirectory.appending(path: "selfcheck-\(UUID().uuidString).opus")
        defer { try? FileManager.default.removeItem(at: url) }
        let pcm = (0..<16_000).map { Float(sin(Double($0) * 2 * .pi * 440 / 16_000)) * 0.05 }
        guard audioEncodePcmToOpus(pcm16kMono: pcm, outPath: url.path) != nil else {
            return SelfCheckResult(id: "audio.playback", title: title, status: .fail, detail: "core encoder failed")
        }
        let manager = AudioRecorderManager.shared
        let wasPlaying = manager.isPlaying
        manager.stopPlayback()
        manager.playAudio(url: url, recordingId: "selfcheck")
        defer { manager.stopPlayback() }
        if let failure = manager.playbackFailure {
            return SelfCheckResult(id: "audio.playback", title: title, status: .fail, detail: failure)
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        let advanced = manager.currentPlaybackTime > 0.05
        let session = AVAudioSession.sharedInstance()
        return SelfCheckResult(
            id: "audio.playback", title: title,
            status: advanced ? .pass : .fail,
            detail: advanced
                ? "time advanced to \(String(format: "%.2f", manager.currentPlaybackTime))s (category=\(session.category.rawValue))"
                : "player started but time did not advance (category=\(session.category.rawValue), wasPlaying=\(wasPlaying))")
    }

    private func checkMicrophonePermission() async -> SelfCheckResult {
        let status: String
        let ok: Bool
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: status = "granted"; ok = true
            case .denied: status = "denied"; ok = false
            default: status = "undetermined"; ok = true
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted: status = "granted"; ok = true
            case .denied: status = "denied"; ok = false
            default: status = "undetermined"; ok = true
            }
        }
        return SelfCheckResult(
            id: "mic.permission", title: "Microphone permission",
            status: ok ? .pass : .fail, detail: status)
    }

    /// 介面語言對得上系統聽寫的 locale、而且可用（`zh-Hant` 這類腳本標籤要先轉成地區）。
    private func checkSpeechRecognizer() async -> SelfCheckResult {
        let locale = AudioTranscriber.speechLocale(forUILanguage: LocalizationManager.shared.currentLanguage.rawValue)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return SelfCheckResult(
                id: "speech.recognizer", title: "Speech recognizer", status: .warn,
                detail: "no recognizer for \(locale.identifier); falls back to system default")
        }
        return SelfCheckResult(
            id: "speech.recognizer", title: "Speech recognizer",
            status: recognizer.isAvailable ? .pass : .warn,
            detail: "\(locale.identifier) available=\(recognizer.isAvailable) onDevice=\(recognizer.supportsOnDeviceRecognition)")
    }

    /// 錄音資料夾：存在、寫得進去，而且 App 有宣告檔案共享（否則「檔案」App 看不到它）。
    private func checkLibraryFolder() async -> SelfCheckResult {
        let dir = AudioRecorderManager.shared.recordingsDirectory
        let probe = dir.appending(path: ".selfcheck-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: probe) }
        let writable = (try? Data("x".utf8).write(to: probe)) != nil
        let sharing = (Bundle.main.object(forInfoDictionaryKey: "UIFileSharingEnabled") as? Bool) == true
        let inPlace = (Bundle.main.object(forInfoDictionaryKey: "LSSupportsOpeningDocumentsInPlace") as? Bool) == true
        let iCloud = DocumentStorageLocation.isICloudSynced(dir)
        let ok = writable && sharing && inPlace
        return SelfCheckResult(
            id: "folder.library", title: "Recordings folder", status: ok ? .pass : .fail,
            detail: "\(dir.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) writable=\(writable) fileSharing=\(sharing) openInPlace=\(inPlace) iCloud=\(iCloud)")
    }

    /// 檔案選擇器能不能從目前畫面呈現（找得到最上層 view controller）。
    private func checkFilePickerPresenter() async -> SelfCheckResult {
        let available = DocumentPickerPresenter.canPresent()
        return SelfCheckResult(
            id: "picker.presenter", title: "File picker presenter",
            status: available ? .pass : .fail,
            detail: available ? "top view controller found" : "no view controller to present from")
    }

    /// 核心的簡繁轉換有接上（繁體介面的轉錄不會是簡體）。
    private func checkTranscriptScript() async -> SelfCheckResult {
        let converted = localizeTranscriptScript(text: "语音识别", uiLanguage: "zh-Hant")
        let ok = converted == "語音識別"
        return SelfCheckResult(
            id: "transcript.script", title: "Transcript script (zh-Hant)", status: ok ? .pass : .fail,
            detail: "语音识别 → \(converted)")
    }

    private func checkFreeSpace() async -> SelfCheckResult {
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let free = values?.volumeAvailableCapacityForImportantUsage ?? 0
        let mb = free / 1_048_576
        return SelfCheckResult(
            id: "storage.free", title: "Free storage",
            status: mb >= 200 ? .pass : (mb >= 50 ? .warn : .fail), detail: "\(mb) MB")
    }
}

/// 診斷面板裡的自檢區塊。
struct PlatformSelfCheckSection: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @StateObject private var check = PlatformSelfCheck()

    var body: some View {
        Section(loc.localized("selfcheck_title")) {
            Button {
                Task { await check.run() }
            } label: {
                HStack {
                    Image(systemName: "stethoscope")
                    Text(check.isRunning ? loc.localized("selfcheck_running") : loc.localized("selfcheck_run"))
                    Spacer()
                    if check.isRunning { ProgressView() }
                }
            }
            .disabled(check.isRunning)
            .accessibilityIdentifier("diagnostics.selfcheck.run")

            ForEach(check.results) { r in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: r.status == .pass ? "checkmark.circle.fill"
                          : r.status == .warn ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                        .foregroundColor(r.status == .pass ? .green : r.status == .warn ? .orange : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title).font(.subheadline.weight(.medium))
                        Text(r.detail).font(.caption).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("diagnostics.selfcheck.\(r.id)")
            }

            if !check.results.isEmpty {
                Button {
                    UIPasteboard.general.string = check.report
                } label: {
                    Label(loc.localized("selfcheck_copy"), systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("diagnostics.selfcheck.copy")
            }
        }
    }
}

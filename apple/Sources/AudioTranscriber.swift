//
//  AudioTranscriber.swift
//  Kairumo
//
//  本機語音辨識與轉錄引擎（工作項 S-95）
//  支援 Rust Core Whisper 端側神經網路加速、多國語言自動偵測與標點還原，
//  並無縫相容 Apple Speech 系統聽寫平滑降級機制。
//

import Foundation
import Speech
import AVFoundation
import UIKit

// MARK: - 音訊 PCM 解碼器 (硬體加速轉換為 16kHz 單聲道 Float32)

public enum AudioPCMDecoder {
    /// 將本地音訊檔（.m4a, .wav, .caf 等）解碼並重採樣為 16,000 Hz 單聲道 Float32 PCM
    public static func decodeTo16kMono(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioPCMDecoder", code: 1, userInfo: [NSLocalizedDescriptionKey: "無法初始化 16kHz 目標格式"])
        }

        let sourceFormat = file.processingFormat
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw NSError(domain: "AudioPCMDecoder", code: 2, userInfo: [NSLocalizedDescriptionKey: "無法建立音訊格式轉換器"])
        }

        let ratio = 16000.0 / sourceFormat.sampleRate
        let targetFrameCapacity = AVAudioFrameCount(Double(file.length) * ratio + 4096)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCapacity) else {
            throw NSError(domain: "AudioPCMDecoder", code: 3, userInfo: [NSLocalizedDescriptionKey: "無法配置輸出音訊緩衝區"])
        }

        var error: NSError? = nil
        var allRead = false
        converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            if allRead {
                outStatus.pointee = .endOfStream
                return nil
            }
            guard let readBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: inNumPackets) else {
                outStatus.pointee = .noDataNow
                return nil
            }
            do {
                try file.read(into: readBuffer)
                if readBuffer.frameLength == 0 {
                    allRead = true
                    outStatus.pointee = .endOfStream
                    return nil
                }
                outStatus.pointee = .haveData
                return readBuffer
            } catch {
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        if let error = error {
            throw error
        }

        guard let channelData = outputBuffer.floatChannelData?[0] else {
            return []
        }

        let count = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: count))
    }
}

// MARK: - 模型下載委派

private final class ModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let destPath: String
    let onProgress: @Sendable (Int64, Int64, Double) -> Void
    let onComplete: @Sendable (Result<URL, Error>) -> Void
    private let fallbackTotalBytes: Int64 = 574_041_195

    init(
        destPath: String,
        onProgress: @escaping @Sendable (Int64, Int64, Double) -> Void,
        onComplete: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        self.destPath = destPath
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : fallbackTotalBytes
        let progress = min(max(Double(totalBytesWritten) / Double(total), 0.0), 1.0)
        onProgress(totalBytesWritten, total, progress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 重要：必須在 didFinishDownloadingTo 返回前同步移轉暫存檔，否則 iOS/macOS 系統會在方法返回後立即刪除它
        do {
            let destUrl = URL(fileURLWithPath: destPath)
            let parentDir = destUrl.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            let stagingUrl = parentDir.appendingPathComponent("whisper-downloading-\(UUID().uuidString).tmp")
            if FileManager.default.fileExists(atPath: stagingUrl.path) {
                try? FileManager.default.removeItem(at: stagingUrl)
            }
            try FileManager.default.moveItem(at: location, to: stagingUrl)

            let attrs = try FileManager.default.attributesOfItem(atPath: stagingUrl.path)
            let size = (attrs[.size] as? Int64) ?? 0
            guard size > 500_000_000 else {
                try? FileManager.default.removeItem(at: stagingUrl)
                throw NSError(
                    domain: "WhisperDownload",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "下載檔案不完整（大小僅 \(size / 1_000_000) MB，預期 ~574 MB），請切換鏡像分流重試"]
                )
            }

            if FileManager.default.fileExists(atPath: destUrl.path) {
                try FileManager.default.removeItem(at: destUrl)
            }
            try FileManager.default.moveItem(at: stagingUrl, to: destUrl)
            onComplete(.success(destUrl))
        } catch {
            onComplete(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onComplete(.failure(error))
        }
    }
}

// MARK: - 音訊轉錄核心管理員

@MainActor
public final class AudioTranscriber: ObservableObject {
    public static let shared = AudioTranscriber()

    @Published public var isTranscribing: Bool = false
    @Published public var lastError: String? = nil
    @Published public var lastUsedOnDevice: Bool = false
    @Published public var lastEngineUsed: String = "Whisper"

    // 模型下載狀態
    @Published public var isDownloadingModel: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadStatusText: String = ""
    @Published public var downloadError: String? = nil

    public static let primaryModelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin"
    public static let mirrorModelUrl = "https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin"

    private var activeDownloadSession: URLSession?
    private var activeDownloadTask: URLSessionDownloadTask?
    private var lastLoggedProgressPct: Int = -1
    private var lastProgressSampleTime: Date = Date()
    private var lastProgressSampleBytes: Int64 = 0

    public enum OfflineStatus: Equatable {
        /// 本地離線語音模型已就緒
        case ready
        /// 本地 Whisper 端側神經模型已就緒（支援多語自動偵測）
        case whisperReady
        /// Apple 系統內建聽寫模型已就緒
        case appleSpeechReady
        /// 尚未下載離線模型
        case needsDownload
        /// 當前環境不支援
        case unsupported
    }

    private init() {}

    /// 本地 Whisper 模型檔案路徑
    public var whisperModelPath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = docs.appendingPathComponent("models", isDirectory: true)
        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        return modelsDir.appendingPathComponent("whisper-large-v3-turbo-q5.bin").path
    }

    /// 本地 Whisper 模型是否可用
    public var isWhisperAvailable: Bool {
        whisperIsModelAvailable(modelPath: whisperModelPath)
    }

    /// 檢查當前指定語言之本機離線辨識支援與模型狀態
    public func checkOfflineStatus(languageCode: String? = nil) -> OfflineStatus {
        if isWhisperAvailable {
            return .whisperReady
        }

        let locale: Locale
        if let languageCode = languageCode, !languageCode.isEmpty {
            locale = Locale(identifier: languageCode)
        } else {
            locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer() else {
            return .unsupported
        }
        if recognizer.supportsOnDeviceRecognition {
            return .ready
        } else {
            return .needsDownload
        }
    }

    /// 開啟系統設定中的「聽寫 / 鍵盤」頁面，指引使用者由系統下載離線語音包
    public func openSystemDictationSettings() {
        #if targetEnvironment(macCatalyst) || os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Dictation") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let generalUrl = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
            UIApplication.shared.open(generalUrl, options: [:], completionHandler: nil)
        }
        #else
        if let url = URL(string: "App-Prefs:root=General&path=Keyboard") {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success, let appSettings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                }
            }
        } else if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
        }
        #endif
    }

    /// 一鍵非同步下載 Whisper 離線模型權重 (574 MB)
    public func downloadWhisperModel(useMirror: Bool = false) {
        guard !isDownloadingModel, !isWhisperAvailable else { return }
        let urlString = useMirror ? Self.mirrorModelUrl : Self.primaryModelUrl
        guard let url = URL(string: urlString) else { return }

        // 清除先前懸浮的 Session
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        activeDownloadSession?.invalidateAndCancel()
        activeDownloadSession = nil

        isDownloadingModel = true
        downloadProgress = 0.0
        downloadStatusText = "連線中..."
        downloadError = nil
        lastLoggedProgressPct = -1
        lastProgressSampleTime = Date()
        lastProgressSampleBytes = 0

        let destPath = whisperModelPath
        let delegate = ModelDownloadDelegate(
            destPath: destPath,
            onProgress: { [weak self] written, total, progress in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isDownloadingModel else { return }
                    self.downloadProgress = progress

                    let writtenMB = Double(written) / 1_000_000.0
                    let totalMB = Double(total) / 1_000_000.0
                    let pct = Int(progress * 100)

                    let now = Date()
                    let elapsed = now.timeIntervalSince(self.lastProgressSampleTime)
                    var speedStr = ""
                    if elapsed >= 0.8 {
                        let bytesDiff = written - self.lastProgressSampleBytes
                        let speedMBps = Double(bytesDiff) / (elapsed * 1_000_000.0)
                        if speedMBps > 0.01 {
                            speedStr = String(format: " · %.1f MB/s", speedMBps)
                        }
                        self.lastProgressSampleTime = now
                        self.lastProgressSampleBytes = written
                    }

                    self.downloadStatusText = String(format: "%.1f MB / %.1f MB (%d%%)%@", writtenMB, totalMB, pct, speedStr)

                    if pct >= self.lastLoggedProgressPct + 10 {
                        self.lastLoggedProgressPct = (pct / 10) * 10
                        StartupLogger.log("📥 Whisper 下載進度: \(self.downloadStatusText)")
                    }
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isDownloadingModel = false
                    self.activeDownloadSession?.finishTasksAndInvalidate()
                    self.activeDownloadSession = nil
                    self.activeDownloadTask = nil

                    switch result {
                    case .success(let destUrl):
                        StartupLogger.log("✅ Whisper 離線模型下載並就緒: \(destUrl.path)")
                        self.downloadStatusText = "已完成"
                        self.downloadError = nil
                        self.objectWillChange.send()
                    case .failure(let error):
                        let nsError = error as NSError
                        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                            self.downloadStatusText = ""
                            self.downloadError = nil
                            StartupLogger.log("⏹️ 使用者取消了 Whisper 模型下載")
                        } else {
                            self.downloadError = error.localizedDescription
                            self.downloadStatusText = "下載中斷"
                            StartupLogger.log("❌ Whisper 模型下載失敗: \(error.localizedDescription)")
                        }
                    }
                }
            }
        )

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 7200
        config.waitsForConnectivity = true

        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        activeDownloadSession = session

        var request = URLRequest(url: url)
        request.setValue("Padnote/1.0 (iOS/macOS; WhisperModelDownload)", forHTTPHeaderField: "User-Agent")

        let task = session.downloadTask(with: request)
        activeDownloadTask = task
        task.resume()
        StartupLogger.log("🚀 開始下載 Whisper 模型 (574 MB, \(useMirror ? "分流鏡像" : "官方節點"))...")
    }

    /// 取消模型下載
    public func cancelModelDownload() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        activeDownloadSession?.invalidateAndCancel()
        activeDownloadSession = nil
        isDownloadingModel = false
        downloadProgress = 0.0
        downloadStatusText = ""
    }

    /// 從檔案或外部 URL 匯入離線模型
    public func importWhisperModel(from sourceUrl: URL) throws {
        let isAccessing = sourceUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                sourceUrl.stopAccessingSecurityScopedResource()
            }
        }

        let destUrl = URL(fileURLWithPath: whisperModelPath)
        let parentDir = destUrl.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: sourceUrl.path)
        let size = (attrs[.size] as? Int64) ?? 0
        guard size > 100_000_000 else {
            throw NSError(
                domain: "WhisperImport",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "模型檔案大小異常（僅 \(size / 1_000_000) MB），請確認選取的是完整的 Whisper ggml 權重檔"]
            )
        }

        if FileManager.default.fileExists(atPath: destUrl.path) {
            try FileManager.default.removeItem(at: destUrl)
        }
        try FileManager.default.copyItem(at: sourceUrl, to: destUrl)
        StartupLogger.log("✅ 成功匯入 Whisper 離線模型 (\(size / 1_000_000) MB)")
        objectWillChange.send()
    }

    /// 刪除本機 Whisper 模型以釋放空間
    public func deleteWhisperModel() throws {
        let destUrl = URL(fileURLWithPath: whisperModelPath)
        if FileManager.default.fileExists(atPath: destUrl.path) {
            try FileManager.default.removeItem(at: destUrl)
            StartupLogger.log("🗑️ 已刪除本地 Whisper 模型以釋放空間")
            objectWillChange.send()
        }
    }

    /// 檢查並請求語音辨識權限
    public func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// 將音訊檔案轉錄為文字稿
    /// - Parameters:
    ///   - url: 音訊檔案的本地路徑
    ///   - languageCode: 語言代碼（若為 nil 則啟用自動語言偵測）
    /// - Returns: 辨識出的文字稿字串
    public func transcribe(url: URL, languageCode: String? = nil) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }

        // 1. 優先路徑：若已下載端側 Whisper 模型，走 Rust 核心 ASR 管線（支援多語言自動偵測與標點還原）
        if isWhisperAvailable {
            do {
                StartupLogger.log("🎙️ 開始使用端側 Whisper 模型轉錄（自動語言偵測）...")
                let result = try await Task.detached(priority: .userInitiated) { [path = whisperModelPath] () -> FfiTranscribeResult in
                    let pcm = try AudioPCMDecoder.decodeTo16kMono(url: url)
                    return try whisperTranscribePcm(modelPath: path, pcm16kMono: pcm, language: languageCode)
                }.value

                lastUsedOnDevice = true
                lastEngineUsed = "Whisper (\(result.language))"
                StartupLogger.log("🎙️ Whisper 轉錄完成（語言: \(result.language), 片段數: \(result.segments.count)）")
                let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } catch {
                StartupLogger.log("⚠️ Whisper 轉錄異常: \(error.localizedDescription)，平滑降級至 Apple Speech...")
            }
        }

        // 2. 降級備援路徑：走 Apple 系統聽寫框架
        lastEngineUsed = "Apple Speech"
        StartupLogger.log("🎙️ 使用 Apple Speech 系統聽寫進行轉錄...")
        return try await transcribeWithAppleSpeech(url: url, languageCode: languageCode)
    }

    private func transcribeWithAppleSpeech(url: URL, languageCode: String? = nil) async throws -> String {
        let granted = await requestPermission()
        guard granted else {
            throw NSError(
                domain: "AudioTranscriber",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission denied"]
            )
        }

        let locale: Locale
        if let languageCode = languageCode, !languageCode.isEmpty {
            locale = Locale(identifier: languageCode)
        } else {
            locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer() else {
            throw NSError(
                domain: "AudioTranscriber",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable for current locale"]
            )
        }

        guard recognizer.isAvailable else {
            throw NSError(
                domain: "AudioTranscriber",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is currently unavailable"]
            )
        }

        if recognizer.supportsOnDeviceRecognition {
            do {
                let res = try await performRecognitionTask(recognizer: recognizer, url: url, requiresOnDevice: true)
                lastUsedOnDevice = true
                return res
            } catch {
                lastUsedOnDevice = false
                return try await performRecognitionTask(recognizer: recognizer, url: url, requiresOnDevice: false)
            }
        } else {
            lastUsedOnDevice = false
            return try await performRecognitionTask(recognizer: recognizer, url: url, requiresOnDevice: false)
        }
    }

    private func performRecognitionTask(
        recognizer: SFSpeechRecognizer,
        url: URL,
        requiresOnDevice: Bool
    ) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = requiresOnDevice

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    let lock = NSLock()
                    var hasResumed = false
                    let task = recognizer.recognitionTask(with: request) { result, error in
                        lock.lock()
                        defer { lock.unlock() }
                        if let error = error {
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(throwing: error)
                            }
                            return
                        }

                        if let result = result, result.isFinal {
                            if !hasResumed {
                                hasResumed = true
                                let formattedText = result.bestTranscription.formattedString
                                continuation.resume(returning: formattedText)
                            }
                        }
                    }
                    _ = task
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                throw NSError(
                    domain: "AudioTranscriber",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "語音辨識超時（15秒）。請檢查網路連線或系統聽寫模型。"]
                )
            }

            guard let result = try await group.next() else {
                throw NSError(domain: "AudioTranscriber", code: 5, userInfo: [NSLocalizedDescriptionKey: "轉錄無結果"])
            }
            group.cancelAll()
            return result
        }
    }
}

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
    let onProgress: @Sendable (Double) -> Void
    let onComplete: @Sendable (Result<URL, Error>) -> Void

    init(
        onProgress: @escaping @Sendable (Double) -> Void,
        onComplete: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
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
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress(progress)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        onComplete(.success(location))
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
    @Published public var downloadError: String? = nil

    private var activeDownloadSession: URLSession?
    private var activeDownloadTask: URLSessionDownloadTask?

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

    /// 一鍵非同步下載 Whisper 離線模型權重 (574 MB, Hugging Face 鏡像)
    public func downloadWhisperModel() {
        guard !isDownloadingModel, !isWhisperAvailable else { return }
        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin") else { return }

        isDownloadingModel = true
        downloadProgress = 0.0
        downloadError = nil

        let destPath = whisperModelPath

        let delegate = ModelDownloadDelegate(
            onProgress: { [weak self] p in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = p
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isDownloadingModel = false
                    switch result {
                    case .success(let tempUrl):
                        do {
                            let destUrl = URL(fileURLWithPath: destPath)
                            if FileManager.default.fileExists(atPath: destPath) {
                                try FileManager.default.removeItem(at: destUrl)
                            }
                            try FileManager.default.moveItem(at: tempUrl, to: destUrl)
                            StartupLogger.log("✅ Whisper 離線模型下載並就緒: \(destPath)")
                            self.objectWillChange.send()
                        } catch {
                            self.downloadError = error.localizedDescription
                            StartupLogger.log("❌ 移動模型檔案失敗: \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        self.downloadError = error.localizedDescription
                        StartupLogger.log("❌ Whisper 模型下載失敗: \(error.localizedDescription)")
                    }
                }
            }
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        activeDownloadSession = session
        let task = session.downloadTask(with: url)
        activeDownloadTask = task
        task.resume()
        StartupLogger.log("🚀 開始下載 Whisper 模型 (574 MB)...")
    }

    /// 取消模型下載
    public func cancelModelDownload() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        isDownloadingModel = false
        downloadProgress = 0.0
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

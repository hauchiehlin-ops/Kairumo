//
//  AudioTranscriber.swift
//  Kairumo
//
//  基於 Apple Speech 框架的本機語音辨識與轉錄引擎
//  提供端側神經網路加速、離線優先、噪音與標點自動還原
//

import Foundation
import Speech

@MainActor
public final class AudioTranscriber: ObservableObject {
    public static let shared = AudioTranscriber()

    @Published public var isTranscribing: Bool = false
    @Published public var lastError: String? = nil

    private init() {}

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
    ///   - languageCode: 語言代碼（如 "zh-Hant", "zh-Hans", "en", "ja"）
    /// - Returns: 辨識出的文字稿字串
    public func transcribe(url: URL, languageCode: String? = nil) async throws -> String {
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
            locale = Locale.current
        }

        // 嘗試以指定 locale 建立識別器，若不支援則以預設/系統 locale 備援
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

        isTranscribing = true
        defer { isTranscribing = false }

        // 優先嘗試使用裝置端（On-Device）離線神經網路引擎；
        // 若系統本機尚未下載該語言之離線語音模型（常拋出 error 216 "Retry"），自動平滑降級為標準辨識
        if recognizer.supportsOnDeviceRecognition {
            do {
                return try await performRecognitionTask(recognizer: recognizer, url: url, requiresOnDevice: true)
            } catch {
                return try await performRecognitionTask(recognizer: recognizer, url: url, requiresOnDevice: false)
            }
        } else {
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

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let task = recognizer.recognitionTask(with: request) { result, error in
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
}

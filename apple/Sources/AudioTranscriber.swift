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

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        // 優先使用裝置端（On-Device）離線神經網路引擎，保障隱私與無網環境運作
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        isTranscribing = true
        defer { isTranscribing = false }

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

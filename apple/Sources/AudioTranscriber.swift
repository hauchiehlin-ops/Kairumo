//
//  AudioTranscriber.swift
//  Kairumo
//
//  基於 Apple Speech 框架的本機語音辨識與轉錄引擎
//  提供端側神經網路加速、離線優先、噪音與標點自動還原
//

import Foundation
import Speech

import UIKit

@MainActor
public final class AudioTranscriber: ObservableObject {
    public static let shared = AudioTranscriber()

    @Published public var isTranscribing: Bool = false
    @Published public var lastError: String? = nil
    @Published public var lastUsedOnDevice: Bool = false

    public enum OfflineStatus: Equatable {
        /// 本地神經網路離線語音模型已就緒
        case ready
        /// 系統支援但本地尚未下載離線模型（或需開啟聽寫）
        case needsDownload
        /// 當前語言或系統不支援離線辨識
        case unsupported
    }

    private init() {}

    /// 檢查當前指定語言之本機離線辨識支援與模型狀態
    public func checkOfflineStatus(languageCode: String? = nil) -> OfflineStatus {
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
            // 輸出語言以介面語系設定的語言為主
            locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
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

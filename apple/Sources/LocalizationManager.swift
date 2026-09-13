//
//  LocalizationManager.swift
//  Kairumo
//
//  跨平台語系管理中樞（支援 6 國語言同步切換）
//  支援：繁體中文 (zh-Hant)、English (en)、簡體中文 (zh-Hans)、日本語 (ja)、한국어 (ko)、ไทย (th)
//  嚴格對齊 Rust Core padnote-i18n 與各平台 UI
//

import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHant = "zh-Hant"
    case en = "en"
    case zhHans = "zh-Hans"
    case ja = "ja"
    case ko = "ko"
    case th = "th"

    public var id: String { rawValue }

    public var endonym: String {
        switch self {
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .th: return "ไทย"
        }
    }
}

@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    private let languageKey = "kairumo.app.language"

    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .en
        }
    }

    public func setLanguage(_ lang: AppLanguage) {
        self.currentLanguage = lang
    }

    public func localized(_ key: String) -> String {
        guard let dict = Self.generatedStrings[key] else { return key }
        return dict[currentLanguage] ?? dict[.en] ?? dict[.zhHant] ?? key
    }

    // MARK: - 介面字串
    //
    // 字串表本身在 LocalizationStrings.generated.swift，由 i18n/ui-strings.json
    // 產生（scripts/i18n_tool.py）。Android 端的 Kotlin 表出自同一份 catalog，
    // 所以兩個平台不會各自漂移。要改字串請改 catalog，不要改產生檔。
}

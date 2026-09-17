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

    /// 文件範本目錄（`templates/document-templates.json`）裡的語言鍵。
    ///
    /// 那份 JSON 用的是 `zhHant` 這種寫法，不是 BCP 47 的 `zh-Hant` ——
    /// 直接拿 `rawValue` 去查會每次都落空，然後**靜靜地**退回繁體中文，
    /// 英文使用者不會看到錯誤，只會覺得範本沒有英文版。
    public var catalogKey: String {
        switch self {
        case .zhHant: return "zhHant"
        case .en: return "en"
        case .zhHans: return "zhHans"
        case .ja: return "ja"
        case .ko: return "ko"
        case .th: return "th"
        }
    }

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
        // 先看跨裝置設定（G-04），再看本機記錄。
        //
        // 順序不能反：使用者在 iPad 上把語言改成日文之後，Mac 這台的本機
        // 記錄還是舊的；本機優先的話，同步過來的設定永遠不會生效 ——
        // 使用者會覺得「同步根本沒在動」。
        let synced = AccountSyncStore.shared.syncedLanguage.flatMap(AppLanguage.init(rawValue:))
        let local = UserDefaults.standard.string(forKey: languageKey).flatMap(AppLanguage.init(rawValue:))
        let resolved = synced ?? local ?? .en
        self.currentLanguage = resolved
        Self.snapshotLanguage = resolved
    }

    public func setLanguage(_ lang: AppLanguage) {
        self.currentLanguage = lang
        Self.snapshotLanguage = lang
        // 語言是**跨裝置**設定：在 iPad 上改，Mac 上也要跟著變（ADR-0011）。
        AccountSyncStore.shared.setSyncedLanguage(lang.rawValue)
    }

    /// 不受 actor 隔離的查表。
    ///
    /// 錯誤訊息會在背景執行緒組成（遷移、備份、同步都跑在背景），
    /// 而字串表是唯讀的靜態資料 —— 從哪個執行緒讀都一樣。目前語言是
    /// `@MainActor` 隔離的，所以這裡取一次快照。
    public nonisolated func localizedUnsafe(_ key: String) -> String {
        guard let dict = Self.generatedStrings[key] else { return key }
        let language = Self.snapshotLanguage
        return dict[language] ?? dict[.en] ?? dict[.zhHant] ?? key
    }

    /// 版面標籤的整張表（S-90）。
    ///
    /// 匯出 PDF 時交給核心：版面的幾何在核心，**文字不在** —— 語系鍵住在
    /// 兩端共用的 `ui-strings` 表裡，核心的 catalog 沒有那一份。一次交整組
    /// `guide_` 開頭的鍵，核心用得到哪幾個由那張紙決定。
    public nonisolated func guideLabelsUnsafe() -> [String: String] {
        var out: [String: String] = [:]
        for (key, _) in Self.generatedStrings where key.hasPrefix("guide_") {
            out[key] = localizedUnsafe(key)
        }
        return out
    }

    /// 目前語言的快照，供背景執行緒查表用。
    ///
    /// 用 `nonisolated(unsafe)` 是刻意的：它只被寫入一次（切換語言時），
    /// 而讀到舊值的後果只是一句錯誤訊息用了上一個語言 —— 不值得為此付
    /// 同步的代價。
    nonisolated(unsafe) static var snapshotLanguage: AppLanguage = .zhHant

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

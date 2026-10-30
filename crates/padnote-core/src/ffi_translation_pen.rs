//! 掃描翻譯筆（Translation Pen）跨平台核心邏輯。
//!
//! 將實體掃描翻譯筆的核心能力沉入 Rust Core，讓 Apple 與 Android 共用同一套：
//! 1. **語系設定與筆記本記憶預設值**（`translation_pen_languages`、`translation_pen_default_config`）
//! 2. **跨行連掃自動拼接與斷字修補**（`translation_pen_stitch_lines`：處理英文行尾連字號 `inter-\nnational` 與 CJK／拉丁語系空白規則）
//! 3. **單字／片語／整句智慧分流與詞根詞綴拆解**（`translation_pen_analyze_scan`）
//! 4. **轉為釘選註解時的標準化雙語卡片格式**（`translation_pen_format_pin_message`）

/// 掃描翻譯筆支援的語系資訊。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiTranslationLangInfo {
    /// BCP-47 語系代碼（如 `"en"`, `"zh-Hant"`, `"zh-Hans"`, `"ja"`, `"ko"`, `"th"`, `"fr"`, `"de"`, `"es"`）。
    pub tag: String,
    /// 母語顯示名稱（如 `"English"`, `"繁體中文"`）。
    pub endonym: String,
    /// 浮動膠囊上的簡短標籤（如 `"EN"`, `"繁中"`, `"簡中"`, `"日"`, `"韓"`, `"泰"`）。
    pub short_label: String,
    /// 供平台 TTS 語音合成器（`AVSpeechSynthesizer` / `TextToSpeech`）使用的標準語音區域碼。
    pub tts_locale: String,
}

/// 單本筆記本的掃描翻譯筆設定。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiTranslationPenConfig {
    /// 掃描目標語系（原文語系，如 `"en"`）。
    pub source_lang: String,
    /// 翻譯輸出語系（譯文語系，如 `"zh-Hant"`）。
    pub target_lang: String,
    /// 是否開啟「跨行連掃自動拼接」模式。
    pub multi_line_stitch: bool,
    /// 是否使用 0.75x 慢速跟讀發音。
    pub slow_tts: bool,
    /// 此筆記本是否已完成首次語系選擇。
    pub configured: bool,
}

/// 掃描文字的智慧分流類型（對應實體翻譯筆的「單字查詢卡 vs. 整句雙語對照卡」）。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiScanKind {
    /// 單一詞彙（英文單字或 1~4 字 CJK 詞語）—— 顯示詞形還原／詞根提示與系統字典按鈕。
    Word,
    /// 短片語（2~4 個單字或短詞組）。
    Phrase,
    /// 完整句子或段落 —— 顯示雙語上下對照與整句朗讀。
    Sentence,
}

/// 掃描內容經過正規化與智慧分流後的分析結果。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiScanAnalysis {
    /// 清理多餘換行與 OCR 雜訊後的文字。
    pub cleaned_text: String,
    /// 分流類型：單字、片語或整句。
    pub kind: FfiScanKind,
    /// 詞數（拉丁語系以空白分詞計數，CJK 以字元數計數）。
    pub word_count: u32,
    /// 詞形還原或詞根／詞綴提示（如 `"international → inter- + national"` 或 `"running → run + -ing"`）。
    pub phonetic_or_stem_hint: String,
    /// 對應 `ui-strings.json` 的詞性／語法提示語系鍵（若無則為空字串）。
    pub grammar_hint_key: String,
    /// 是否判定為目標文字模糊、雜訊過高或系統難以判斷（為 `true` 時前端應立即快顯說明，禁止送交翻譯引擎硬翻或胡亂編造輸出）。
    pub is_low_confidence: bool,
}

/// 掃描翻譯筆支援的語系清單。
#[uniffi::export]
pub fn translation_pen_languages() -> Vec<FfiTranslationLangInfo> {
    use padnote_i18n::Locale;
    vec![
        FfiTranslationLangInfo {
            tag: Locale::English.tag().to_string(),
            endonym: Locale::English.endonym().to_string(),
            short_label: Locale::English.short_label().to_string(),
            tts_locale: "en-US".to_string(),
        },
        FfiTranslationLangInfo {
            tag: Locale::TraditionalChinese.tag().to_string(),
            endonym: Locale::TraditionalChinese.endonym().to_string(),
            short_label: Locale::TraditionalChinese.short_label().to_string(),
            tts_locale: "zh-TW".to_string(),
        },
        FfiTranslationLangInfo {
            tag: Locale::SimplifiedChinese.tag().to_string(),
            endonym: Locale::SimplifiedChinese.endonym().to_string(),
            short_label: Locale::SimplifiedChinese.short_label().to_string(),
            tts_locale: "zh-CN".to_string(),
        },
        FfiTranslationLangInfo {
            tag: Locale::Japanese.tag().to_string(),
            endonym: Locale::Japanese.endonym().to_string(),
            short_label: Locale::Japanese.short_label().to_string(),
            tts_locale: "ja-JP".to_string(),
        },
        FfiTranslationLangInfo {
            tag: Locale::Korean.tag().to_string(),
            endonym: Locale::Korean.endonym().to_string(),
            short_label: Locale::Korean.short_label().to_string(),
            tts_locale: "ko-KR".to_string(),
        },
        FfiTranslationLangInfo {
            tag: Locale::Thai.tag().to_string(),
            endonym: Locale::Thai.endonym().to_string(),
            short_label: Locale::Thai.short_label().to_string(),
            tts_locale: "th-TH".to_string(),
        },
        FfiTranslationLangInfo {
            tag: "fr".to_string(),
            endonym: "Français".to_string(),
            short_label: "FR".to_string(),
            tts_locale: "fr-FR".to_string(),
        },
        FfiTranslationLangInfo {
            tag: "de".to_string(),
            endonym: "Deutsch".to_string(),
            short_label: "DE".to_string(),
            tts_locale: "de-DE".to_string(),
        },
        FfiTranslationLangInfo {
            tag: "es".to_string(),
            endonym: "Español".to_string(),
            short_label: "ES".to_string(),
            tts_locale: "es-ES".to_string(),
        },
    ]
}

/// 依據使用者目前的介面語言，給出筆記本首次啟用掃描翻譯筆時的預設語系配對。
///
/// 若介面語言為英文，預設「掃描繁體中文 → 輸出英文」；
/// 否則預設「掃描英文 → 輸出使用者介面語系」，且 `configured` 為 `false` 以觸發首次選擇視窗。
#[uniffi::export]
pub fn translation_pen_default_config(ui_language: String) -> FfiTranslationPenConfig {
    let trimmed = ui_language.trim();
    let normalized_ui = if trimmed.is_empty() {
        "zh-Hant"
    } else if trimmed.eq_ignore_ascii_case("zh-tw") || trimmed.eq_ignore_ascii_case("zh-hk") {
        "zh-Hant"
    } else if trimmed.eq_ignore_ascii_case("zh-cn") || trimmed.eq_ignore_ascii_case("zh-sg") {
        "zh-Hans"
    } else {
        trimmed
    };

    let (source_lang, target_lang) = if normalized_ui.starts_with("en") {
        ("zh-Hant".to_string(), "en".to_string())
    } else {
        ("en".to_string(), normalized_ui.to_string())
    };

    FfiTranslationPenConfig {
        source_lang,
        target_lang,
        multi_line_stitch: true,
        slow_tts: false,
        configured: false,
    }
}

fn is_cjk_or_thai_lang(lang_tag: &str) -> bool {
    let lower = lang_tag.trim().to_ascii_lowercase();
    lower.starts_with("zh")
        || lower.starts_with("ja")
        || lower.starts_with("ko")
        || lower.starts_with("th")
}

fn contains_cjk_or_thai_char(text: &str) -> bool {
    text.chars().any(|c| {
        let u = c as u32;
        (0x4E00..=0x9FFF).contains(&u)
            || (0x3400..=0x4DBF).contains(&u)
            || (0x3040..=0x30FF).contains(&u)
            || (0xAC00..=0xD7AF).contains(&u)
            || (0x0E00..=0x0E7F).contains(&u)
    })
}

/// 跨行連掃自動拼接：將前一次掃描的文字與新掃描的一行拼接為完整句子。
///
/// - 若前一段結尾是英文排版連字號（`-` 或 `‐`）且新一段以拉丁字母開頭，自動消去連字號並接合單字（如 `"inter-"` + `"national"` → `"international"`）。
/// - 若為中／日／泰等無空格語系，直接緊密接合；若為拉丁／韓文等分詞語系，自動補上單一空格。
#[uniffi::export]
pub fn translation_pen_stitch_lines(
    previous_text: String,
    new_text: String,
    source_lang: String,
) -> String {
    let prev = previous_text.trim();
    let next = new_text.trim();
    if prev.is_empty() {
        return next.to_string();
    }
    if next.is_empty() {
        return prev.to_string();
    }

    // 檢查行尾連字號（例如 PDF 跨行斷字 "trans-" + "lation" -> "translation"）
    if (prev.ends_with('-') || prev.ends_with('\u{2010}'))
        && next.chars().next().is_some_and(|c| c.is_ascii_alphabetic())
    {
        let stem = prev.trim_end_matches(['-', '\u{2010}']).trim_end();
        if stem.chars().last().is_some_and(|c| c.is_ascii_alphabetic()) {
            return format!("{stem}{next}");
        }
    }

    let cjk_mode = is_cjk_or_thai_lang(&source_lang)
        || (contains_cjk_or_thai_char(prev) && contains_cjk_or_thai_char(next));
    if cjk_mode && !source_lang.trim().to_ascii_lowercase().starts_with("ko") {
        format!("{prev}{next}")
    } else {
        format!("{prev} {next}")
    }
}

/// 智慧分析掃描到的文字：清理雜訊、判斷「單字／片語／整句」，並針對單字提供詞形與字首字尾拆解提示。
#[uniffi::export]
pub fn translation_pen_analyze_scan(text: String, source_lang: String) -> FfiScanAnalysis {
    // 壓縮多餘空白與換行（保留連字號斷字修復）
    let mut cleaned = String::new();
    for line in text.lines() {
        let piece = line.trim();
        if piece.is_empty() {
            continue;
        }
        cleaned = translation_pen_stitch_lines(cleaned, piece.to_string(), source_lang.clone());
    }
    let cleaned = cleaned.trim().to_string();
    if cleaned.is_empty() {
        return FfiScanAnalysis {
            cleaned_text: String::new(),
            kind: FfiScanKind::Word,
            word_count: 0,
            phonetic_or_stem_hint: String::new(),
            grammar_hint_key: String::new(),
            is_low_confidence: true,
        };
    }

    let low_conf = is_text_blurry_or_garbled(&cleaned);

    let cjk = contains_cjk_or_thai_char(&cleaned);
    let has_sentence_punct = cleaned.chars().any(|c| {
        matches!(
            c,
            '.' | '?' | '!' | ';' | '。' | '？' | '！' | '；' | '，' | ','
        )
    });

    if cjk {
        let char_count = cleaned.chars().filter(|c| !c.is_whitespace()).count() as u32;
        let kind = if char_count <= 4 && !has_sentence_punct {
            FfiScanKind::Word
        } else if char_count <= 10 && !has_sentence_punct {
            FfiScanKind::Phrase
        } else {
            FfiScanKind::Sentence
        };
        let hint = if kind == FfiScanKind::Word && !low_conf {
            let chars: Vec<char> = cleaned.chars().filter(|c| !c.is_whitespace()).collect();
            if chars.len() >= 2 {
                chars
                    .iter()
                    .map(|c| c.to_string())
                    .collect::<Vec<_>>()
                    .join(" · ")
            } else {
                cleaned.clone()
            }
        } else {
            String::new()
        };
        return FfiScanAnalysis {
            cleaned_text: cleaned,
            kind,
            word_count: char_count,
            phonetic_or_stem_hint: hint,
            grammar_hint_key: String::new(),
            is_low_confidence: low_conf,
        };
    }

    // 拉丁／空白分詞語系
    let words: Vec<&str> = cleaned.split_whitespace().collect();
    let word_count = words.len() as u32;

    if word_count == 1 {
        let raw_word = words[0].trim_matches(|c: char| !c.is_alphanumeric() && c != '-');
        let (stem_hint, grammar_key) = if low_conf {
            (String::new(), String::new())
        } else {
            analyze_english_morphology(raw_word)
        };
        let cleaned_word = if raw_word.is_empty() || low_conf {
            cleaned
        } else {
            raw_word.to_string()
        };
        return FfiScanAnalysis {
            cleaned_text: cleaned_word,
            kind: FfiScanKind::Word,
            word_count: 1,
            phonetic_or_stem_hint: stem_hint,
            grammar_hint_key: grammar_key,
            is_low_confidence: low_conf,
        };
    }

    let kind = if word_count <= 4 && !has_sentence_punct {
        FfiScanKind::Phrase
    } else {
        FfiScanKind::Sentence
    };

    FfiScanAnalysis {
        cleaned_text: cleaned,
        kind,
        word_count,
        phonetic_or_stem_hint: String::new(),
        grammar_hint_key: String::new(),
        is_low_confidence: low_conf,
    }
}

/// 檢查擷取或辨識出的文字是否因筆跡潦草、影像模糊或背景線條干擾而屬於無法可靠翻譯的雜訊。
fn is_text_blurry_or_garbled(cleaned: &str) -> bool {
    if cleaned.is_empty() || cleaned.contains('\u{FFFD}') {
        return true;
    }
    let non_ws: Vec<char> = cleaned.chars().filter(|c| !c.is_whitespace()).collect();
    if non_ws.is_empty() {
        return true;
    }

    let linguistic_count = non_ws
        .iter()
        .filter(|&&c| c.is_alphabetic() || contains_cjk_or_thai_char(&c.to_string()))
        .count();

    // 完全沒有任何語言文字（例如純符號 "---"、"..."、純數字或格線雜訊 "| / \\"）
    if linguistic_count == 0 {
        return true;
    }

    // 非語言字元（亂碼符號、數字夾雜等）佔比超過一半
    if linguistic_count * 2 < non_ws.len() {
        return true;
    }

    let cjk = contains_cjk_or_thai_char(cleaned);
    if !cjk {
        // 單一拉丁字母（OCR 掃到線條或雜點極易產生單一 "l", "I", "c", "o", "v", "x"）
        if linguistic_count <= 1 {
            return true;
        }

        let words: Vec<&str> = cleaned.split_whitespace().collect();
        let mut valid_words = 0usize;
        for w in &words {
            let trimmed = w.trim_matches(|c: char| !c.is_alphanumeric());
            if trimmed.is_empty() {
                continue;
            }
            // 單字內部同時夾雜字母與數字或管線符號（典型模糊 OCR 誤判，如 "h3llo", "l|1", "0O"）
            let has_alpha = trimmed.chars().any(|c| c.is_alphabetic());
            let has_digit = trimmed.chars().any(|c| c.is_ascii_digit());
            if has_alpha && has_digit {
                return true;
            }
            // 純英文字母達 4 字以上卻完全沒有母音（a, e, i, o, u, y），多為塗鴉誤辨識出的子音串
            if trimmed.len() >= 4 && trimmed.chars().all(|c| c.is_ascii_alphabetic()) {
                let has_vowel = trimmed
                    .chars()
                    .any(|c| matches!(c.to_ascii_lowercase(), 'a' | 'e' | 'i' | 'o' | 'u' | 'y'));
                if !has_vowel {
                    return true;
                }
            }
            if trimmed.chars().filter(|c| c.is_alphabetic()).count() >= 2 {
                valid_words += 1;
            }
        }
        if valid_words == 0 {
            return true;
        }
    }

    false
}

fn analyze_english_morphology(word: &str) -> (String, String) {
    let lower = word.to_ascii_lowercase();
    if lower.len() < 4 || !lower.chars().all(|c| c.is_ascii_alphabetic() || c == '-') {
        return (String::new(), String::new());
    }

    let mut parts: Vec<String> = Vec::new();
    let mut remainder = lower.as_str();
    let mut grammar_key = String::new();

    for prefix in [
        "inter", "trans", "super", "under", "over", "anti", "auto", "semi", "sub", "pre", "pro",
        "non", "dis", "mis", "re", "un", "in", "im",
    ] {
        if let Some(rest) = remainder.strip_prefix(prefix)
            && rest.len() >= 3
        {
            parts.push(format!("{prefix}-"));
            remainder = rest;
            grammar_key = "trans_pen_hint_prefix".to_string();
            break;
        }
    }

    let suffixes: &[(&str, &str)] = &[
        ("ation", "trans_pen_hint_tion"),
        ("ition", "trans_pen_hint_tion"),
        ("tion", "trans_pen_hint_tion"),
        ("sion", "trans_pen_hint_tion"),
        ("ment", "trans_pen_hint_tion"),
        ("ness", "trans_pen_hint_tion"),
        ("able", "trans_pen_hint_prefix"),
        ("ible", "trans_pen_hint_prefix"),
        ("ingly", "trans_pen_hint_ly"),
        ("edly", "trans_pen_hint_ly"),
        ("ly", "trans_pen_hint_ly"),
        ("ing", "trans_pen_hint_ing"),
        ("ed", "trans_pen_hint_ed"),
        ("es", "trans_pen_hint_plural"),
        ("s", "trans_pen_hint_plural"),
    ];

    let mut suffix_part: Option<String> = None;
    for &(sfx, key) in suffixes {
        if let Some(stem) = remainder.strip_suffix(sfx)
            && stem.len() >= 3
        {
            remainder = stem;
            suffix_part = Some(format!("-{sfx}"));
            if grammar_key.is_empty() {
                grammar_key = key.to_string();
            }
            break;
        }
    }

    if parts.is_empty() && suffix_part.is_none() {
        return (String::new(), String::new());
    }

    parts.push(remainder.to_string());
    if let Some(sfx) = suffix_part {
        parts.push(sfx);
    }
    (format!("{lower} → {}", parts.join(" + ")), grammar_key)
}

/// 將掃描原文、譯文與使用者編輯的筆記組合成圖釘（CommentPin）或文字框的標準化雙語內容。
#[uniffi::export]
pub fn translation_pen_format_pin_message(
    source_text: String,
    translated_text: String,
    note: String,
    source_lang: String,
    target_lang: String,
) -> String {
    let src = source_text.trim();
    let dst = translated_text.trim();
    let memo = note.trim();
    let src_tag = source_lang.trim();
    let dst_tag = target_lang.trim();

    let mut lines = Vec::new();
    if !src.is_empty() {
        if src_tag.is_empty() {
            lines.push(src.to_string());
        } else {
            lines.push(format!("[{src_tag}] {src}"));
        }
    }
    if !dst.is_empty() && dst != src {
        if dst_tag.is_empty() {
            lines.push(format!("→ {dst}"));
        } else {
            lines.push(format!("→ [{dst_tag}] {dst}"));
        }
    }
    if !memo.is_empty() {
        lines.push(format!("📝 {memo}"));
    }
    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn supported_languages_cover_all_six_app_locales_plus_european() {
        let langs = translation_pen_languages();
        assert!(langs.len() >= 6);
        for required in ["en", "zh-Hant", "zh-Hans", "ja", "ko", "th"] {
            assert!(
                langs.iter().any(|l| l.tag == required),
                "缺少語系 {required}"
            );
        }
    }

    #[test]
    fn default_config_adapts_to_ui_language_and_starts_unconfigured() {
        let zh = translation_pen_default_config("zh-Hant".to_string());
        assert_eq!(zh.source_lang, "en");
        assert_eq!(zh.target_lang, "zh-Hant");
        assert!(!zh.configured, "首次開啟必須為 false 以觸發語系選擇視窗");

        let en = translation_pen_default_config("en".to_string());
        assert_eq!(en.source_lang, "zh-Hant");
        assert_eq!(en.target_lang, "en");
        assert!(!en.configured);
    }

    #[test]
    fn stitch_lines_dehyphenates_english_line_breaks_and_respects_cjk() {
        let joined = translation_pen_stitch_lines(
            "inter-".to_string(),
            "national".to_string(),
            "en".to_string(),
        );
        assert_eq!(joined, "international");

        let sentence = translation_pen_stitch_lines(
            "Hello".to_string(),
            "world".to_string(),
            "en".to_string(),
        );
        assert_eq!(sentence, "Hello world");

        let cjk = translation_pen_stitch_lines(
            "人工智慧".to_string(),
            "光學辨識".to_string(),
            "zh-Hant".to_string(),
        );
        assert_eq!(cjk, "人工智慧光學辨識");
    }

    #[test]
    fn analyze_scan_distinguishes_words_phrases_and_sentences() {
        let word = translation_pen_analyze_scan("international.".to_string(), "en".to_string());
        assert_eq!(word.kind, FfiScanKind::Word);
        assert_eq!(word.cleaned_text, "international");
        assert!(word.phonetic_or_stem_hint.contains("inter-"));

        let phrase = translation_pen_analyze_scan("machine learning".to_string(), "en".to_string());
        assert_eq!(phrase.kind, FfiScanKind::Phrase);
        assert_eq!(phrase.word_count, 2);

        let sentence = translation_pen_analyze_scan(
            "Scan any sentence on the page to translate immediately.".to_string(),
            "en".to_string(),
        );
        assert_eq!(sentence.kind, FfiScanKind::Sentence);
        assert!(sentence.word_count >= 5);
        assert!(!sentence.is_low_confidence);
    }

    #[test]
    fn analyze_scan_flags_blurry_or_garbled_noise_as_low_confidence() {
        for noisy in [
            "", "   ", "---", "12345", "l", "| / \\", "h3ll0", "bcdfgh", "@#$%a",
        ] {
            let res = translation_pen_analyze_scan(noisy.to_string(), "en".to_string());
            assert!(
                res.is_low_confidence,
                "Expected '{noisy}' to be flagged as low confidence"
            );
        }

        let valid_en = translation_pen_analyze_scan("comprehension".to_string(), "en".to_string());
        assert!(!valid_en.is_low_confidence);

        let valid_zh =
            translation_pen_analyze_scan("光學字元辨識".to_string(), "zh-Hant".to_string());
        assert!(!valid_zh.is_low_confidence);
    }

    #[test]
    fn format_pin_message_includes_source_translation_and_note() {
        let msg = translation_pen_format_pin_message(
            "meticulous".to_string(),
            "一絲不苟的".to_string(),
            "常考形容詞".to_string(),
            "en".to_string(),
            "zh-Hant".to_string(),
        );
        assert!(msg.contains("[en] meticulous"));
        assert!(msg.contains("→ [zh-Hant] 一絲不苟的"));
        assert!(msg.contains("📝 常考形容詞"));
    }
}

//! 本機 LLM：摘要與待辦抽取（WP23 / S-20，決策 D5）。
//!
//! # 這個 crate 裡**沒有**模型
//!
//! 它只有三件事：**把文字切成模型吃得下的塊**、**組提示詞**、
//! **把模型吐出來的東西解析回結構**。真正產生 token 的是
//! [`LlmEngine`] 的實作 —— 桌機上是 llama.cpp，行動裝置上由平台提供
//! （見 `padnote-core::ffi_llm`）。
//!
//! 這樣切的理由與 `ffi_collab`、`FfiDriveHttp` 一致：**會把二進位撐大的
//! 東西留在平台層**。把 llama.cpp 連進核心會讓 `libpadnote_core.so` 多好幾
//! 十 MB，而那是每個使用者都要下載的，不管他用不用得到摘要。
//!
//! # 為什麼解析這件事值得一個 crate
//!
//! LLM 不會乖乖照格式回答。同一個提示詞會拿到
//! 「`1. 買牛奶`」、「`- [ ] 買牛奶`」、「`**待辦：**買牛奶`」、
//! 中間夾一句「好的，以下是我整理的待辦事項：」。
//!
//! 解析寫得鬆一點，使用者看到的是一份混著提示詞殘骸的待辦清單；
//! 寫得嚴一點，八成的回覆會被丟掉而畫面上空空如也。**兩種壞法都很難查**，
//! 因為它們取決於模型當下吐了什麼。所以這一段要有測試，而且測試要餵
//! 真的會出現的髒東西。
//!
//! # 兩個平台必須是同一份
//!
//! 摘要與待辦會寫進筆記本、跟著同步走。兩邊各解析一次的話，同一段錄音
//! 在 iPad 上抽出三條待辦、在 Android 上抽出五條，而使用者會認為是
//! 「其中一台壞了」。

use std::fmt;

/// 產生 token 的後端。
///
/// 只有一個方法：給提示詞、拿文字。刻意不暴露 token、溫度、取樣參數 ——
/// 那些由實作決定，而且不同後端（llama.cpp、平台內建模型）根本不一樣。
pub trait LlmEngine: Send + Sync + fmt::Debug {
    /// 跑一次生成。`max_tokens` 是**上限**，不是目標長度。
    fn generate(&self, prompt: &str, max_tokens: u32) -> Result<String, LlmError>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LlmError {
    /// 模型還沒下載或載入。
    ///
    /// 與「後端壞了」分開：前者要引導使用者去下載，後者只能請他重試。
    /// 混成一種的話，沒下載模型的人會看到「摘要失敗，請再試一次」，
    /// 而再試一百次也不會成功。
    ModelNotLoaded,
    /// 輸入是空的，或全是空白。
    EmptyInput,
    Backend(String),
}

impl fmt::Display for LlmError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ModelNotLoaded => write!(f, "模型尚未下載或載入"),
            Self::EmptyInput => write!(f, "沒有可以處理的文字"),
            Self::Backend(m) => write!(f, "後端錯誤：{m}"),
        }
    }
}

impl std::error::Error for LlmError {}

/// 一條待辦。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TodoItem {
    pub text: String,
    /// 模型有沒有把它標成已完成（`- [x]`）。
    pub done: bool,
}

/// 一段文字要切成幾塊、每塊多大。
///
/// 單位是**字元**而不是 token：真正的 token 數要載入 tokenizer 才算得出來，
/// 而這一層刻意不依賴任何模型。字元數乘一個保守係數就夠用 ——
/// 切太小只是多跑幾次，切太大會讓模型**靜靜截斷**，而截斷的症狀是
/// 「後半段的待辦完全不見」，看起來像模型漏掉而不是我們送太多。
pub const CHUNK_CHARS: usize = 3_000;

/// 把長文切塊。
///
/// **在段落邊界切**，不在字元數到了就硬切：切在句子中間的話，模型會把
/// 半句話當成完整輸入去理解，摘要出來的東西可能與原意相反。
///
/// 單一段落就超過上限時才硬切 —— 那時沒有更好的選擇，但至少只有那一段
/// 受影響。
pub fn chunk(text: &str, budget: usize) -> Vec<String> {
    let budget = budget.max(200);
    let mut out = Vec::new();
    let mut current = String::new();

    for para in text.split("\n\n") {
        let para = para.trim();
        if para.is_empty() {
            continue;
        }
        if para.chars().count() > budget {
            // 這一段自己就超過上限。先把手上的送出去，再硬切它。
            if !current.is_empty() {
                out.push(std::mem::take(&mut current));
            }
            let chars: Vec<char> = para.chars().collect();
            for piece in chars.chunks(budget) {
                out.push(piece.iter().collect());
            }
            continue;
        }
        // +2 是即將補上的空行。不算的話，剛好卡在邊界的那一塊會超出去。
        if !current.is_empty() && current.chars().count() + para.chars().count() + 2 > budget {
            out.push(std::mem::take(&mut current));
        }
        if !current.is_empty() {
            current.push_str("\n\n");
        }
        current.push_str(para);
    }
    if !current.is_empty() {
        out.push(current);
    }
    out
}

/// 摘要的提示詞。
///
/// `locale` 是 BCP-47（`zh-Hant`、`ja`…）。**一定要指定輸出語言**：
/// 不指定的話，模型會跟著輸入的語言走，而一份中英夾雜的會議記錄
/// 會拿到一半中文一半英文的摘要。
pub fn summary_prompt(text: &str, locale: &str) -> String {
    format!(
        "你是一個筆記助理。請用 {locale} 為下面的內容寫一段摘要。\n\
         規則：\n\
         - 只輸出摘要本身，不要任何開場白、結語或標題。\n\
         - 三到五句話。\n\
         - 只根據下面的內容，不要補充任何沒有提到的事。\n\n\
         內容：\n{text}"
    )
}

/// 待辦抽取的提示詞。
pub fn todo_prompt(text: &str, locale: &str) -> String {
    format!(
        "你是一個筆記助理。請從下面的內容找出待辦事項，用 {locale} 輸出。\n\
         規則：\n\
         - 每一行一條，格式是 `- [ ] 事項`，已經完成的用 `- [x] 事項`。\n\
         - 只輸出這些行，不要任何開場白、結語或編號。\n\
         - 只抽取內容裡真的提到的事，**沒有待辦就輸出空的**。\n\n\
         內容：\n{text}"
    )
}

/// 把模型的回覆清成一段摘要。
///
/// 做的事：丟掉常見的開場白、拆掉 markdown 的粗體與標題符號、
/// 把多餘的空行壓掉。
pub fn parse_summary(raw: &str) -> String {
    let mut lines: Vec<String> = Vec::new();
    for line in raw.lines() {
        let line = strip_markdown(line.trim());
        if line.is_empty() || is_preamble(&line) {
            continue;
        }
        lines.push(line);
    }
    lines.join("\n")
}

/// 把模型的回覆解析成待辦清單。
///
/// 容忍實際會看到的各種寫法：`- [ ] x`、`- x`、`* x`、`1. x`、`1) x`、
/// `• x`，以及前後的粗體與開場白。
///
/// **同樣的事只留一條**：切塊之後同一件事常常在相鄰兩塊裡各出現一次，
/// 不去重的話使用者會拿到一份重複的清單。比較時忽略大小寫與前後空白，
/// 但**保留第一次出現時的原樣**——把使用者的文字正規化掉是另一種錯。
pub fn parse_todos(raw: &str) -> Vec<TodoItem> {
    let mut out: Vec<TodoItem> = Vec::new();
    let mut seen: Vec<String> = Vec::new();

    for line in raw.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let Some((body, done)) = strip_bullet(line) else {
            continue;
        };
        let body = strip_markdown(&body);
        if body.is_empty() || is_preamble(&body) {
            continue;
        }
        let key = body.to_lowercase();
        if seen.contains(&key) {
            continue;
        }
        seen.push(key);
        out.push(TodoItem { text: body, done });
    }
    out
}

/// 拆掉行首的項目符號，回傳 (內容, 是否已完成)。
///
/// 回 `None` 表示這一行**不是**一條待辦 —— 沒有任何項目符號的散文
/// （模型的開場白、結語）會落在這裡，而把它們當成待辦是最常見的髒結果。
fn strip_bullet(line: &str) -> Option<(String, bool)> {
    let mut rest = line;

    // `- ` / `* ` / `• `
    let bulleted = ["- ", "* ", "• ", "－ "]
        .iter()
        .find_map(|p| rest.strip_prefix(p));

    // `1. ` / `1) `
    let numbered = || {
        let digits: String = rest.chars().take_while(char::is_ascii_digit).collect();
        if digits.is_empty() {
            return None;
        }
        let after = &rest[digits.len()..];
        after
            .strip_prefix(". ")
            .or_else(|| after.strip_prefix(") "))
            .or_else(|| after.strip_prefix("、"))
    };

    rest = match bulleted.or_else(numbered) {
        Some(r) => r,
        None => return None,
    };
    rest = rest.trim_start();

    // `[ ]` / `[x]` / `[X]`
    let done = if let Some(r) = rest.strip_prefix("[x]").or_else(|| rest.strip_prefix("[X]")) {
        rest = r;
        true
    } else if let Some(r) = rest.strip_prefix("[ ]").or_else(|| rest.strip_prefix("[]")) {
        rest = r;
        false
    } else {
        false
    };

    Some((rest.trim().to_string(), done))
}

/// 拆掉 markdown 的強調與標題符號，留下文字本身。
fn strip_markdown(text: &str) -> String {
    let mut out = text.trim().trim_start_matches('#').trim().to_string();
    for marker in ["**", "__", "*", "_", "`"] {
        while let Some(start) = out.find(marker) {
            out.replace_range(start..start + marker.len(), "");
        }
    }
    out.trim().to_string()
}

/// 這一行是不是模型的開場白／結語。
///
/// 只比對**結尾是冒號而且很短**的那一種（「好的，以下是待辦事項：」），
/// 不做關鍵字清單 —— 關鍵字清單永遠追不上模型的說法，而且會誤殺
/// 真的以冒號結尾的內容。
fn is_preamble(line: &str) -> bool {
    let trimmed = line.trim();
    trimmed.chars().count() <= 20 && (trimmed.ends_with('：') || trimmed.ends_with(':'))
}

/// 把一段文字做成摘要。切塊 → 逐塊摘要 → 合起來再摘一次。
///
/// 為什麼要再摘一次：三塊各自的摘要接起來仍然是三段各說各話的東西，
/// 而使用者要的是**一段**。只有一塊時就不必多跑一次 ——
/// 那一次沒有任何資訊增益，只是多等好幾秒。
pub fn summarize(
    engine: &dyn LlmEngine,
    text: &str,
    locale: &str,
    max_tokens: u32,
) -> Result<String, LlmError> {
    let pieces = chunk(text, CHUNK_CHARS);
    if pieces.is_empty() {
        return Err(LlmError::EmptyInput);
    }

    let mut partials = Vec::with_capacity(pieces.len());
    for piece in &pieces {
        let raw = engine.generate(&summary_prompt(piece, locale), max_tokens)?;
        let cleaned = parse_summary(&raw);
        if !cleaned.is_empty() {
            partials.push(cleaned);
        }
    }
    if partials.is_empty() {
        return Ok(String::new());
    }
    if partials.len() == 1 {
        return Ok(partials.remove(0));
    }

    let joined = partials.join("\n\n");
    let raw = engine.generate(&summary_prompt(&joined, locale), max_tokens)?;
    let merged = parse_summary(&raw);
    // 再摘一次失敗（模型回了空的）時退回接起來的版本 ——
    // 給使用者一份不夠漂亮的摘要，也好過給他一片空白。
    Ok(if merged.is_empty() { joined } else { merged })
}

/// 抽出待辦。切塊 → 逐塊抽 → 跨塊去重。
pub fn extract_todos(
    engine: &dyn LlmEngine,
    text: &str,
    locale: &str,
    max_tokens: u32,
) -> Result<Vec<TodoItem>, LlmError> {
    let pieces = chunk(text, CHUNK_CHARS);
    if pieces.is_empty() {
        return Err(LlmError::EmptyInput);
    }

    let mut all = Vec::new();
    let mut seen: Vec<String> = Vec::new();
    for piece in &pieces {
        let raw = engine.generate(&todo_prompt(piece, locale), max_tokens)?;
        for item in parse_todos(&raw) {
            let key = item.text.to_lowercase();
            if seen.contains(&key) {
                continue;
            }
            seen.push(key);
            all.push(item);
        }
    }
    Ok(all)
}

#[cfg(test)]
mod tests;

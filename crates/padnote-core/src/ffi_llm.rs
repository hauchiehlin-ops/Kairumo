//! 摘要與待辦抽取的平台介面（WP23 / S-20）。
//!
//! # 為什麼產生 token 的那一段留在平台層
//!
//! 與 [`crate::ffi_gdrive`] 的 HTTP、[`crate::ffi_collab`] 的 WebSocket 同一個
//! 理由：**會把二進位撐大的東西不進核心**。把 llama.cpp 連進
//! `libpadnote_core.so` 會多好幾十 MB，而那是每個使用者都要下載的，
//! 不管他用不用得到摘要。
//!
//! 而且兩個平台本來就有不同的好選擇：Apple 有 Foundation Models、
//! Android 有 MediaPipe LLM，桌機上可以直接用 llama.cpp
//! （`padnote-llm-llama`）。硬把其中一個塞進核心，等於逼另外兩邊也用它。
//!
//! # 留在核心的是「會出錯的那一半」
//!
//! 切塊、提示詞、**解析**都在 [`padnote_llm`]，而解析才是真正難的地方：
//! 模型不會乖乖照格式回答，同一個提示詞會拿到
//! 「`1. 買牛奶`」、「`- [ ] 買牛奶`」、「`**待辦：**買牛奶`」，
//! 中間還夾一句「好的，以下是我整理的待辦事項：」。
//!
//! 那一段在兩邊各寫一次的話，同一段錄音會在 iPad 上抽出三條待辦、
//! 在 Android 上抽出五條 —— 而摘要與待辦是會寫進筆記本、跟著同步走的。

use std::sync::Arc;

use padnote_llm::{LlmEngine, LlmError};

/// 產生 token 的後端，由平台提供。
///
/// 只有一個方法：給提示詞、拿文字。刻意不暴露 token、溫度、取樣參數 ——
/// 那些每個後端都不一樣，開出來只會變成一組沒有人能同時滿足的介面。
#[uniffi::export(with_foreign)]
pub trait FfiLlm: Send + Sync {
    /// 跑一次生成。`max_tokens` 是**上限**，不是目標長度。
    ///
    /// **這個方法會被同步呼叫而且可能很慢**（本機模型一次數秒到數十秒），
    /// 呼叫端一定要在背景執行緒。在主執行緒跑會讓畫面整個停住。
    fn generate(&self, prompt: String, max_tokens: u32) -> Result<String, FfiLlmError>;
}

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FfiLlmError {
    /// 模型還沒下載或載入。
    ///
    /// 與「後端壞了」分開：前者要引導使用者去下載，後者只能請他重試。
    /// 混成一種的話，沒下載模型的人會看到「摘要失敗，請再試一次」，
    /// 而再試一百次也不會成功。
    #[error("模型尚未下載或載入")]
    ModelNotLoaded,
    #[error("{detail}")]
    Backend { detail: String },
}

/// 把平台那一側包成核心看得懂的引擎。
#[derive(Debug)]
struct ForeignLlm(Arc<dyn FfiLlm>);

impl LlmEngine for ForeignLlm {
    fn generate(&self, prompt: &str, max_tokens: u32) -> Result<String, LlmError> {
        self.0
            .generate(prompt.to_string(), max_tokens)
            .map_err(|e| match e {
                FfiLlmError::ModelNotLoaded => LlmError::ModelNotLoaded,
                FfiLlmError::Backend { detail } => LlmError::Backend(detail),
            })
    }
}

impl std::fmt::Debug for dyn FfiLlm {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("FfiLlm")
    }
}

/// 一條待辦。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTodoItem {
    pub text: String,
    /// 模型有沒有把它標成已完成。
    pub done: bool,
}

/// 摘要或待辦抽取的結果。
///
/// 用「成功旗標 + 錯誤字串」而不是丟例外：這一路會被自動觸發
/// （錄音結束之後），而一個背景動作丟出來的例外在兩個平台上的處理方式
/// 差很多。回一個結構，呼叫端自己決定要不要顯示。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSummaryResult {
    pub ok: bool,
    pub summary: String,
    /// 失敗時的說明；`ok` 為 true 時是空字串。
    pub error: String,
    /// true 表示要引導使用者去下載模型，而不是請他重試。
    pub needs_model: bool,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTodoResult {
    pub ok: bool,
    pub todos: Vec<FfiTodoItem>,
    pub error: String,
    pub needs_model: bool,
}

/// 產生摘要。
///
/// `locale` 是 BCP-47（`zh-Hant`、`ja`…）。**一定要給**：不指定輸出語言的話，
/// 模型會跟著輸入的語言走，而一份中英夾雜的會議記錄會拿到一半中文、
/// 一半英文的摘要。
///
/// **這個函式會同步地等模型跑完，不要在主執行緒呼叫。**
#[uniffi::export]
pub fn llm_summarize(
    engine: Arc<dyn FfiLlm>,
    text: String,
    locale: String,
    max_tokens: u32,
) -> FfiSummaryResult {
    match padnote_llm::summarize(&ForeignLlm(engine), &text, &locale, max_tokens) {
        Ok(summary) => FfiSummaryResult {
            ok: true,
            summary,
            error: String::new(),
            needs_model: false,
        },
        Err(e) => FfiSummaryResult {
            ok: false,
            summary: String::new(),
            error: e.to_string(),
            needs_model: matches!(e, LlmError::ModelNotLoaded),
        },
    }
}

/// 抽出待辦事項。
///
/// **沒有待辦是正常的答案**，`ok` 仍然是 true、`todos` 是空的。
/// 當成錯誤的話，使用者每次對一段沒有待辦的筆記按下去都會看到紅字。
///
/// **這個函式會同步地等模型跑完，不要在主執行緒呼叫。**
#[uniffi::export]
pub fn llm_extract_todos(
    engine: Arc<dyn FfiLlm>,
    text: String,
    locale: String,
    max_tokens: u32,
) -> FfiTodoResult {
    match padnote_llm::extract_todos(&ForeignLlm(engine), &text, &locale, max_tokens) {
        Ok(todos) => FfiTodoResult {
            ok: true,
            todos: todos
                .into_iter()
                .map(|t| FfiTodoItem {
                    text: t.text,
                    done: t.done,
                })
                .collect(),
            error: String::new(),
            needs_model: false,
        },
        Err(e) => FfiTodoResult {
            ok: false,
            todos: Vec::new(),
            error: e.to_string(),
            needs_model: matches!(e, LlmError::ModelNotLoaded),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug)]
    struct Fake(&'static str);
    impl FfiLlm for Fake {
        fn generate(&self, _prompt: String, _max: u32) -> Result<String, FfiLlmError> {
            Ok(self.0.to_string())
        }
    }

    #[derive(Debug)]
    struct NoModel;
    impl FfiLlm for NoModel {
        fn generate(&self, _prompt: String, _max: u32) -> Result<String, FfiLlmError> {
            Err(FfiLlmError::ModelNotLoaded)
        }
    }

    #[test]
    fn a_summary_crosses_the_boundary() {
        let out = llm_summarize(
            Arc::new(Fake("好的，以下是摘要：\n會議決定了三件事。")),
            "有內容的一段。".into(),
            "zh-Hant".into(),
            256,
        );
        assert!(out.ok, "{}", out.error);
        assert_eq!(out.summary, "會議決定了三件事。", "開場白要在核心就被清掉");
    }

    #[test]
    fn todos_cross_the_boundary_with_their_done_flag() {
        let out = llm_extract_todos(
            Arc::new(Fake("- [ ] 買牛奶\n- [x] 寄合約")),
            "有內容的一段。".into(),
            "zh-Hant".into(),
            256,
        );
        assert!(out.ok);
        assert_eq!(out.todos.len(), 2);
        assert!(!out.todos[0].done);
        assert!(out.todos[1].done);
    }

    #[test]
    fn a_missing_model_is_flagged_so_the_ui_can_offer_the_download() {
        // 「請再試一次」對一個根本沒下載模型的人毫無幫助。
        let out = llm_summarize(Arc::new(NoModel), "有內容".into(), "zh-Hant".into(), 64);
        assert!(!out.ok);
        assert!(out.needs_model);
    }

    #[test]
    fn no_todos_is_success_not_failure() {
        let out = llm_extract_todos(
            Arc::new(Fake("這段內容沒有待辦事項。")),
            "有內容的一段。".into(),
            "zh-Hant".into(),
            64,
        );
        assert!(out.ok, "沒有待辦是正常答案，不是錯誤");
        assert!(out.todos.is_empty());
        assert!(!out.needs_model);
    }
}

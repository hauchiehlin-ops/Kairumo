//! llama.cpp 後端（WP23 / S-20）。
//!
//! # 這個 crate **不是** `padnote-core` 的相依
//!
//! 刻意的。把 llama.cpp 連進 `libpadnote_core.so` 會多好幾十 MB，而那是
//! 每個使用者都要下載的，不管他用不用得到摘要 —— 與 reqwest 那次的判斷
//! 一樣（`libpadnote_core.so` 8.1 MB → 13 MB，最後改用平台的 HTTP）。
//!
//! 行動端由平台提供後端（`padnote_core::ffi_llm::FfiLlm`）：Apple 有
//! Foundation Models、Android 有 MediaPipe LLM，兩邊都不需要我們帶一份
//! llama.cpp 進去。
//!
//! 這個 crate 服務的是**桌機與測試**：在開發機上跑得動一份真的模型，
//! 才驗得了提示詞與解析在真實輸出下站不站得住。
//!
//! # 模型沒下載時不能失敗得很難懂
//!
//! 模型是 2.4 GB 的 GGUF，預設不會有。[`LlamaEngine::load`] 在檔案不存在時
//! 回 [`LlmError::ModelNotLoaded`]，而不是一個 llama.cpp 的內部錯誤字串 ——
//! 上層要靠這個分辨「引導去下載」與「請重試」。

use std::num::NonZeroU32;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaModel};
use llama_cpp_2::sampling::LlamaSampler;

use padnote_llm::{LlmEngine, LlmError};

/// 一份載入好的 GGUF 模型。
///
/// 整個包在 `Mutex` 裡：llama.cpp 的 context **不是**執行緒安全的，
/// 而 [`LlmEngine`] 要求 `Sync`。摘要與待辦抽取本來就是一次跑一個，
/// 排隊的成本遠低於維護兩份 context 的記憶體（每份都是 GB 級）。
pub struct LlamaEngine {
    inner: Mutex<Inner>,
    path: PathBuf,
}

struct Inner {
    backend: LlamaBackend,
    model: LlamaModel,
}

impl std::fmt::Debug for LlamaEngine {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LlamaEngine")
            .field("path", &self.path)
            .finish()
    }
}

impl LlamaEngine {
    /// 載入一份 GGUF。
    ///
    /// `n_ctx` 是上下文長度。給太小的話，長輸入會被**靜靜截斷**，而症狀是
    /// 「後半段的待辦完全不見」—— 看起來像模型漏掉，不像我們送太多。
    /// `padnote_llm::CHUNK_CHARS` 是 3000 字元，配 4096 token 有餘裕。
    pub fn load(path: impl AsRef<Path>, n_ctx: u32) -> Result<Self, LlmError> {
        let path = path.as_ref().to_path_buf();
        if !path.exists() {
            // **不要讓它變成一個 llama.cpp 的內部錯誤字串。**
            // 上層要靠這個分辨「引導去下載」與「請重試」。
            return Err(LlmError::ModelNotLoaded);
        }
        let backend = LlamaBackend::init().map_err(|e| LlmError::Backend(e.to_string()))?;
        let model = LlamaModel::load_from_file(&backend, &path, &LlamaModelParams::default())
            .map_err(|e| LlmError::Backend(format!("載入模型失敗：{e}")))?;
        let _ = n_ctx; // 上下文長度在每次生成時設定，見 generate。
        Ok(Self {
            inner: Mutex::new(Inner { backend, model }),
            path,
        })
    }
}

impl LlmEngine for LlamaEngine {
    fn generate(&self, prompt: &str, max_tokens: u32) -> Result<String, LlmError> {
        let guard = self
            .inner
            .lock()
            .map_err(|_| LlmError::Backend("模型狀態已損毀".into()))?;
        let Inner { backend, model } = &*guard;

        let tokens = model
            .str_to_token(prompt, AddBos::Always)
            .map_err(|e| LlmError::Backend(format!("提示詞轉 token 失敗：{e}")))?;

        // 上下文要裝得下「提示詞 + 生成」。只給提示詞長度的話，
        // 第一個生成的 token 就會撞牆。
        let needed = (tokens.len() as u32 + max_tokens + 8).max(512);
        let params = LlamaContextParams::default().with_n_ctx(NonZeroU32::new(needed));
        let mut ctx = model
            .new_context(backend, params)
            .map_err(|e| LlmError::Backend(format!("建立 context 失敗：{e}")))?;

        let mut batch = LlamaBatch::new(needed as usize, 1);
        let last = tokens.len() as i32 - 1;
        for (i, token) in tokens.iter().enumerate() {
            // 只有最後一個 token 需要 logits —— 前面那些只是在鋪上下文。
            batch
                .add(*token, i as i32, &[0], i as i32 == last)
                .map_err(|e| LlmError::Backend(e.to_string()))?;
        }
        ctx.decode(&mut batch)
            .map_err(|e| LlmError::Backend(format!("decode 失敗：{e}")))?;

        // 貪婪取樣。摘要與待辦要的是**可重現**：同一份筆記按兩次應該得到
        // 同一份摘要，不然使用者會以為其中一次是壞的。
        let mut sampler = LlamaSampler::greedy();

        // **解碼器要跨 token 共用。**
        //
        // 模型吐的是 byte-level token：一個中文字會拆成好幾個 token，
        // 中間那幾個單獨看不是合法的 UTF-8。每個 token 各開一個解碼器的話，
        // 那些半截位元組會被當成無效字元換成「�」——
        // 症狀是「英文摘要正常、中文摘要全是問號」。
        let mut decoder = encoding_rs::UTF_8.new_decoder();
        let mut out = String::new();
        // `n_cur` 是**模型上下文裡的絕對位置**，不是迴圈次數 —— 它從
        // prompt 的長度開始算。clippy 會把它看成「手寫的計數器」，
        // 但改成 `for n_cur in (start..).take(n)` 讀起來更難懂，
        // 而且這個值要餵給 `batch.add`，語意上就是位置。
        let mut n_cur = batch.n_tokens();

        // lint 掛在迴圈上（它指的是這個 `for`），不是掛在變數上。
        #[allow(clippy::explicit_counter_loop)]
        for _ in 0..max_tokens {
            let token = sampler.sample(&ctx, batch.n_tokens() - 1);
            sampler.accept(token);
            if model.is_eog_token(token) {
                break;
            }
            out.push_str(
                &model
                    // `special = false`：特殊 token（`<|im_end|>` 之類）不要
                    // 進到輸出。進去的話，使用者的摘要結尾會掛著一串標記。
                    .token_to_piece(token, &mut decoder, false, None)
                    .map_err(|e| LlmError::Backend(e.to_string()))?,
            );
            batch.clear();
            batch
                .add(token, n_cur, &[0], true)
                .map_err(|e| LlmError::Backend(e.to_string()))?;
            n_cur += 1;
            ctx.decode(&mut batch)
                .map_err(|e| LlmError::Backend(format!("decode 失敗：{e}")))?;
        }
        Ok(out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_missing_model_is_model_not_loaded_not_a_backend_string() {
        // 這一條不需要真的模型，而且它守的正是最容易搞錯的地方：
        // 「沒下載」與「壞掉」必須分得開，否則使用者會看到
        // 「摘要失敗，請再試一次」而再試一百次也不會成功。
        let err = LlamaEngine::load("/tmp/padnote-there-is-no-such-model.gguf", 4096).unwrap_err();
        assert_eq!(err, LlmError::ModelNotLoaded);
    }
}

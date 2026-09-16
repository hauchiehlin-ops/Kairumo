//! 這一批測試餵的是**模型真的會吐出來的東西**，不是理想格式。
//!
//! 解析寫得鬆一點，使用者看到的是一份混著提示詞殘骸的待辦清單；
//! 寫得嚴一點，八成的回覆會被丟掉而畫面上空空如也。兩種壞法都只在
//! 特定模型、特定輸入下出現，光看程式碼看不出來。

use super::*;
use std::sync::Mutex;

/// 假的引擎：照劇本回答，並記下收到的每一個提示詞。
#[derive(Debug)]
struct ScriptedLlm {
    replies: Mutex<Vec<String>>,
    seen: Mutex<Vec<String>>,
}

impl ScriptedLlm {
    fn new(replies: &[&str]) -> Self {
        Self {
            replies: Mutex::new(replies.iter().rev().map(|s| s.to_string()).collect()),
            seen: Mutex::new(Vec::new()),
        }
    }
    fn calls(&self) -> usize {
        self.seen.lock().unwrap().len()
    }
}

impl LlmEngine for ScriptedLlm {
    fn generate(&self, prompt: &str, _max_tokens: u32) -> Result<String, LlmError> {
        self.seen.lock().unwrap().push(prompt.to_string());
        Ok(self.replies.lock().unwrap().pop().unwrap_or_default())
    }
}

#[derive(Debug)]
struct BrokenLlm;
impl LlmEngine for BrokenLlm {
    fn generate(&self, _: &str, _: u32) -> Result<String, LlmError> {
        Err(LlmError::ModelNotLoaded)
    }
}

// ---- 切塊 ----

#[test]
fn chunking_breaks_at_paragraphs_not_mid_sentence() {
    // 切在句子中間的話，模型會把半句話當成完整輸入去理解，
    // 摘要出來的東西可能與原意相反。
    // 預算用 200（`chunk` 的下限）。再小會被夾到 200，測試就測不到切割。
    let para = "這一段的內容。".repeat(20); // 約 140 字
    let text = format!("{para}\n\n{para}\n\n{para}");
    let pieces = chunk(&text, 200);
    assert!(pieces.len() > 1, "三段各 140 字、預算 200，應該要切開");
    for piece in &pieces {
        assert!(piece.ends_with('。'), "切在段落邊界：{piece:?}");
    }
}

#[test]
fn a_single_oversized_paragraph_is_split_but_only_that_one() {
    let long = "字".repeat(700);
    let text = format!("短的一段。\n\n{long}\n\n另一段短的。");
    let pieces = chunk(&text, 300);
    // 長的那一段被硬切，短的兩段不受影響。
    assert!(pieces.iter().any(|p| p == "短的一段。"));
    assert!(pieces.iter().any(|p| p == "另一段短的。"));
    assert!(pieces.iter().all(|p| p.chars().count() <= 300));
}

#[test]
fn chunking_nothing_yields_nothing() {
    assert!(chunk("", CHUNK_CHARS).is_empty());
    assert!(chunk("   \n\n  \n ", CHUNK_CHARS).is_empty());
}

// ---- 摘要解析 ----

#[test]
fn a_preamble_is_dropped_from_the_summary() {
    let raw = "好的，以下是摘要：\n這次會議決定了三件事。\n下週一交付。";
    assert_eq!(parse_summary(raw), "這次會議決定了三件事。\n下週一交付。");
}

#[test]
fn markdown_emphasis_is_stripped() {
    assert_eq!(parse_summary("**重點**是交期"), "重點是交期");
    assert_eq!(parse_summary("## 摘要\n內容在這"), "摘要\n內容在這");
}

#[test]
fn a_colon_ending_line_that_is_long_is_not_a_preamble() {
    // 只殺「很短而且以冒號結尾」的那一種。真的以冒號結尾的內容
    // 不該被當成開場白丟掉。
    let long = "這一段真的以冒號結尾而且它本身就是內容的一部分不是開場白：";
    assert_eq!(parse_summary(long), long);
}

// ---- 待辦解析 ----

#[test]
fn every_bullet_style_a_model_actually_emits_is_understood() {
    let raw = "\
- [ ] 買牛奶
- [x] 寄合約
* 打給廠商
1. 訂會議室
2) 準備投影片
• 確認預算
";
    let todos = parse_todos(raw);
    let texts: Vec<&str> = todos.iter().map(|t| t.text.as_str()).collect();
    assert_eq!(
        texts,
        vec![
            "買牛奶",
            "寄合約",
            "打給廠商",
            "訂會議室",
            "準備投影片",
            "確認預算"
        ]
    );
    assert!(!todos[0].done);
    assert!(todos[1].done, "`- [x]` 要認得出是已完成");
}

#[test]
fn prose_without_a_bullet_is_not_a_todo() {
    // **這一條是最重要的。** 模型的開場白與結語幾乎都是散文，
    // 沒有這道過濾，使用者的待辦清單第一條會是
    // 「好的，以下是我整理的待辦事項」。
    let raw = "\
好的，以下是我從會議記錄中整理出來的待辦事項：
- [ ] 買牛奶
希望這對你有幫助！
";
    let todos = parse_todos(raw);
    assert_eq!(todos.len(), 1);
    assert_eq!(todos[0].text, "買牛奶");
}

#[test]
fn the_same_todo_twice_is_kept_once_in_its_original_form() {
    // 切塊之後同一件事常常在相鄰兩塊裡各出現一次。
    // 去重時比較忽略大小寫，但**保留第一次出現時的原樣** ——
    // 把使用者的文字正規化掉是另一種錯。
    let raw = "- [ ] Call Vendor\n- [ ] call vendor\n- [ ] CALL VENDOR";
    let todos = parse_todos(raw);
    assert_eq!(todos.len(), 1);
    assert_eq!(todos[0].text, "Call Vendor");
}

#[test]
fn bold_inside_a_bullet_is_stripped() {
    let todos = parse_todos("- [ ] **買牛奶**（今天）");
    assert_eq!(todos[0].text, "買牛奶（今天）");
}

#[test]
fn an_empty_answer_means_no_todos_not_an_error() {
    // 「這段內容沒有待辦」是一個正常的答案。當成錯誤的話，
    // 使用者每次對一段沒有待辦的筆記按下去都會看到紅字。
    assert!(parse_todos("").is_empty());
    assert!(parse_todos("這段內容沒有待辦事項。").is_empty());
}

// ---- 端到端 ----

#[test]
fn one_chunk_does_not_pay_for_a_second_pass() {
    // 只有一塊時再摘一次沒有任何資訊增益，只是讓使用者多等好幾秒。
    let engine = ScriptedLlm::new(&["這是摘要。"]);
    let out = summarize(&engine, "短短一段。", "zh-Hant", 256).unwrap();
    assert_eq!(out, "這是摘要。");
    assert_eq!(engine.calls(), 1, "不該有第二次呼叫");
}

#[test]
fn several_chunks_are_merged_into_one_summary() {
    let engine = ScriptedLlm::new(&["前半的摘要。", "後半的摘要。", "合起來的摘要。"]);
    // 兩段都要超過 CHUNK_CHARS 的一半，合起來才會被切成兩塊。
    let text = format!("{}。\n\n{}。", "甲".repeat(2_000), "乙".repeat(2_000));
    let out = summarize(&engine, &text, "zh-Hant", 256).unwrap();
    assert_eq!(out, "合起來的摘要。");
    assert_eq!(engine.calls(), 3, "兩塊各一次，再加合併那一次");
}

#[test]
fn a_failed_merge_falls_back_to_the_pieces() {
    // 給一份不夠漂亮的摘要，好過給一片空白。
    let engine = ScriptedLlm::new(&["前半的摘要。", "後半的摘要。", ""]);
    let text = format!("{}。\n\n{}。", "甲".repeat(2_000), "乙".repeat(2_000));
    let out = summarize(&engine, &text, "zh-Hant", 256).unwrap();
    assert_eq!(out, "前半的摘要。\n\n後半的摘要。");
}

#[test]
fn todos_are_deduped_across_chunks() {
    let engine = ScriptedLlm::new(&["- [ ] 訂會議室\n- [ ] 買牛奶", "- [ ] 買牛奶\n- [ ] 寄合約"]);
    let text = format!("{}。\n\n{}。", "甲".repeat(2_000), "乙".repeat(2_000));
    let todos = extract_todos(&engine, &text, "zh-Hant", 256).unwrap();
    let texts: Vec<&str> = todos.iter().map(|t| t.text.as_str()).collect();
    assert_eq!(texts, vec!["訂會議室", "買牛奶", "寄合約"]);
}

#[test]
fn empty_input_is_its_own_error() {
    // 與「模型沒載入」分開：前者是使用者對一頁空白按了摘要，
    // 後者要引導他去下載模型。混成一種，兩邊的指引都會是錯的。
    let engine = ScriptedLlm::new(&[]);
    assert_eq!(
        summarize(&engine, "   ", "zh-Hant", 64),
        Err(LlmError::EmptyInput)
    );
    assert_eq!(
        extract_todos(&engine, "", "zh-Hant", 64),
        Err(LlmError::EmptyInput)
    );
    assert_eq!(engine.calls(), 0, "空輸入不該去麻煩模型");
}

#[test]
fn a_missing_model_surfaces_as_model_not_loaded() {
    assert_eq!(
        summarize(&BrokenLlm, "有內容", "zh-Hant", 64),
        Err(LlmError::ModelNotLoaded)
    );
}

#[test]
fn the_prompt_names_the_output_language() {
    // 不指定輸出語言的話，模型會跟著輸入走 —— 一份中英夾雜的會議記錄
    // 會拿到一半中文一半英文的摘要。
    assert!(summary_prompt("內容", "ja").contains("ja"));
    assert!(todo_prompt("內容", "zh-Hant").contains("zh-Hant"));
}

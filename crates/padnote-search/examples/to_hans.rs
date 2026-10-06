//! 繁體 → 簡體（整句、含詞彙轉換）。
//!
//! 維護工具：新增介面字串或核心訊息時，簡體中文那一欄用它先產生一版，再人工校對。
//! 用法：`printf '找不到頁面\n' | cargo run -q -p padnote-search --example to_hans`
use std::io::BufRead;

fn main() {
    for line in std::io::stdin().lock().lines() {
        let line = line.unwrap();
        println!("{}", zhconv::zhconv(&line, zhconv::Variant::ZhCN));
    }
}

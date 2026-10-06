//! 開發用：把一段文字用 `otl` 排成字形，印出「字形編號 x y」（原點座標，字型單位）。
//! 給 `scripts/verify-otl-coretext.py` 與 CoreText 的結果比對。
//!
//! 用法：cargo run -p padnote-export --example otl_dump -- <字型檔> <TTC 索引> <文字>
use padnote_export::otl::Font;
use std::borrow::Cow;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let [_, path, index, text] = args.as_slice() else {
        eprintln!("用法：otl_dump <字型檔> <TTC 索引> <文字>");
        std::process::exit(2);
    };
    let data = std::fs::read(path).expect("讀不到字型檔");
    let font =
        Font::parse_index(Cow::Owned(data), index.parse().unwrap_or(0)).expect("不是可解析的字型");
    println!("upm {}", font.units_per_em);
    let Some(glyphs) = font.shape(text) else {
        println!("unmapped");
        return;
    };
    let mut pen = 0;
    for g in glyphs {
        println!("{} {} {}", g.gid, pen + g.x_offset, g.y_offset);
        pen += g.x_advance;
    }
}

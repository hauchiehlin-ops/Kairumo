//! 把畫面規格倒成 JSON，給 `scripts/check-screen-parity.py` 用。
//!
//! 為什麼是一支獨立的程式而不是讓腳本去讀 Rust 原始碼：規格是**程式**
//! （有 optional、有平台範圍），用正規表示式去撈遲早撈錯，而撈錯的閘門
//! 比沒有閘門更糟 —— 它會在錯的地方變紅，然後被關掉。

fn main() {
    let mut out = String::from("{\n");
    let ids = padnote_core::ffi_screens::screen_ids();
    for (i, id) in ids.iter().enumerate() {
        let spec = padnote_core::ffi_screens::screen_spec(id.clone());
        out.push_str(&format!(
            "  \"{id}\": {{\n    \"title_key\": \"{}\",\n    \"controls\": [\n",
            spec.title_key
        ));
        let controls: Vec<_> = spec
            .sections
            .iter()
            .flat_map(|s| s.controls.iter().map(move |c| (s.id.clone(), c)))
            .collect();
        for (j, (section_id, c)) in controls.iter().enumerate() {
            let platforms = match c.platforms {
                padnote_core::ffi_screens::FfiPlatforms::Both => "both",
                padnote_core::ffi_screens::FfiPlatforms::AppleOnly => "apple",
                padnote_core::ffi_screens::FfiPlatforms::AndroidOnly => "android",
            };
            out.push_str(&format!(
                "      {{\"id\": \"{}\", \"section\": \"{}\", \"kind\": \"{:?}\", \"label_key\": \"{}\", \"platforms\": \"{}\", \"optional\": {}}}{}\n",
                c.id,
                section_id,
                c.kind,
                c.label_key,
                platforms,
                c.optional,
                if j + 1 == controls.len() { "" } else { "," }
            ));
        }
        out.push_str("    ]\n  }");
        out.push_str(if i + 1 == ids.len() { "\n" } else { ",\n" });
    }
    out.push_str("}\n");
    print!("{out}");
}

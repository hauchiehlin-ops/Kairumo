//! libpdfium 到底載不載得起來（docs/TODO.md H8）。
//!
//! # 為什麼需要一個獨立的探針
//!
//! `padnote-pdf-pdfium` 的測試在 libpdfium 不存在時會**自己跳過** ——
//! 那是對的（CI 上不該因為環境問題變紅），但代價是：整包測試在
//! 「函式庫根本不在」與「函式庫在而且能用」兩種情況下**都是綠的**。
//!
//! 所以要有一個會明確講出結果的東西：
//!
//! ```text
//! cargo run -p padnote-pdf-pdfium --example probe
//! # bound=false  → 沒抓到庫，先跑 ./scripts/fetch-pdfium.sh
//!
//! DYLD_LIBRARY_PATH=third_party/pdfium/pdfium-mac-arm64/lib \
//!   cargo run -p padnote-pdf-pdfium --example probe
//! # bound=true   → 這時候測試才真的走到實作
//! ```

fn main() {
    let ok = pdfium_render::prelude::Pdfium::bind_to_system_library().is_ok();
    println!("bound={ok}");
    if !ok {
        println!("找不到 libpdfium。先跑 ./scripts/fetch-pdfium.sh，");
        println!("再把它的 lib 目錄放進 DYLD_LIBRARY_PATH（macOS）或 LD_LIBRARY_PATH（Linux）。");
    }
}

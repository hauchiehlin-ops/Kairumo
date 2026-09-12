//! 產生各平台語言綁定。
//!
//! ```bash
//! cargo build -p padnote-core
//! cargo run -p padnote-core --bin uniffi-bindgen -- generate \
//!   --library target/debug/libpadnote_core.dylib \
//!   --language swift --out-dir apple/Generated
//! ```

fn main() {
    uniffi::uniffi_bindgen_main()
}

//! 跨語言互通測試：核心的 AES-256-GCM 與 Apple CryptoKit 必須逐位元組相容。
//!
//! 為什麼需要這個測試：Android 走核心、Apple 走 CryptoKit，兩邊要在同一個協同
//! 房間裡互相解得開。光靠「都叫 AES-256-GCM」是不夠的 —— nonce 長度、
//! 位元組排列、標籤位置任何一項不同都會安靜地失敗。
//!
//! 測試在有 Swift 工具鏈的機器上才會實際執行（macOS）；其餘平台自動跳過，
//! 以免 Linux CI 因為沒有 swiftc 就變紅。

use padnote_crypto::session::SessionKey;
use std::process::Command;

fn swift_available() -> bool {
    Command::new("swiftc")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// 用 CryptoKit 解開核心加密的內容，再由 CryptoKit 加密回來讓核心解。
fn run_swift_bridge(key_b64: &str, sealed_b64: &str, reply: &str) -> String {
    let src = r#"
import Foundation
import CryptoKit

let keyB64 = CommandLine.arguments[1]
let sealedB64 = CommandLine.arguments[2]
let reply = CommandLine.arguments[3]

let key = SymmetricKey(data: Data(base64Encoded: keyB64)!)

// 1. 解開 Rust 送來的密文
let box1 = try! AES.GCM.SealedBox(combined: Data(base64Encoded: sealedB64)!)
let opened = try! AES.GCM.open(box1, using: key)
FileHandle.standardOutput.write(("OPENED:" + String(data: opened, encoding: .utf8)! + "\n").data(using: .utf8)!)

// 2. 用 CryptoKit 加密，交給 Rust 解
let sealed = try! AES.GCM.seal(Data(reply.utf8), using: key)
FileHandle.standardOutput.write(("SEALED:" + sealed.combined!.base64EncodedString() + "\n").data(using: .utf8)!)
"#;
    let dir = std::env::temp_dir().join(format!("kairumo-interop-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let swift_file = dir.join("bridge.swift");
    std::fs::write(&swift_file, src).unwrap();

    let out = Command::new("swift")
        .arg(&swift_file)
        .arg(key_b64)
        .arg(sealed_b64)
        .arg(reply)
        .output()
        .expect("執行 swift 失敗");
    assert!(
        out.status.success(),
        "Swift 端失敗：{}",
        String::from_utf8_lossy(&out.stderr)
    );
    String::from_utf8_lossy(&out.stdout).to_string()
}

#[test]
fn rust_and_cryptokit_can_read_each_other() {
    if !swift_available() {
        eprintln!("跳過：這台機器沒有 Swift 工具鏈");
        return;
    }

    let key = SessionKey::generate().unwrap();
    let plaintext = "來自核心的協同訊息 / from the Rust core";
    let sealed_b64 = key.seal_to_base64(plaintext.as_bytes()).unwrap();

    let reply = "來自 CryptoKit 的回覆 / from CryptoKit";
    let output = run_swift_bridge(&key.to_base64(), &sealed_b64, reply);

    // 1. CryptoKit 解得開核心的密文
    let opened = output
        .lines()
        .find_map(|l| l.strip_prefix("OPENED:"))
        .expect("Swift 沒有回傳解密結果");
    assert_eq!(opened, plaintext, "CryptoKit 解出來的內容與原文不符");

    // 2. 核心解得開 CryptoKit 的密文
    let swift_sealed = output
        .lines()
        .find_map(|l| l.strip_prefix("SEALED:"))
        .expect("Swift 沒有回傳密文");
    let back = key.open_from_base64(swift_sealed).unwrap();
    assert_eq!(
        String::from_utf8(back).unwrap(),
        reply,
        "核心解不開 CryptoKit 的密文"
    );
}

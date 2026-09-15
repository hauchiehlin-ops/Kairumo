//! 協同編輯的共用規則：房間識別、邀請連結與端對端加密。
//!
//! # 為什麼只有這些在核心，WebSocket 不在
//!
//! 真正需要兩邊一模一樣的是**協定與密碼學**：房號怎麼產生、邀請連結長什麼樣、
//! 金鑰怎麼編碼、密文用哪一種模式與哪一種排列。這些各寫一份的話，
//! iPad 開的房間 Android 進不去 —— 而且失敗方式是「連上了但每一則訊息都解不開」，
//! 極難查。
//!
//! Socket 本身留在平台層（Apple 的 `URLSession`、Android 的 OkHttp）。
//! 把它搬進核心要帶進一整個 async runtime 與跨語言 callback，
//! 換來的只是少寫幾十行連線樣板，不划算。
//!
//! # 加密格式必須與 CryptoKit 相容
//!
//! Apple 端用 `AES.GCM.seal(...).combined`，也就是
//! `nonce(12) || ciphertext || tag(16)` 再 base64。這裡照著做 ——
//! 換一種排列（例如把 tag 放前面）不會有任何編譯錯誤，
//! 只會讓已經在 TestFlight 上的版本跟新版互相解不開。

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as B64;

/// `AES.GCM` 的 nonce 長度（位元組）。CryptoKit 用 12，換掉就不相容。
const NONCE_LEN: usize = 12;

/// 產生一把新的房間金鑰，回傳 base64。
///
/// 產不出亂數時回空字串而不是 panic —— 呼叫端會退回「不加密」，
/// 那比整個 App 掛掉好；UI 也看得到金鑰是空的。
#[uniffi::export]
pub fn collab_generate_room_key() -> String {
    let mut key = [0u8; 32];
    if getrandom::getrandom(&mut key).is_err() {
        return String::new();
    }
    B64.encode(key)
}

/// 檢查一把 base64 金鑰是否可用（解得開且剛好 32 位元組）。
#[uniffi::export]
pub fn collab_is_valid_room_key(key_base64: String) -> bool {
    decode_key(&key_base64).is_some()
}

fn decode_key(key_base64: &str) -> Option<[u8; 32]> {
    let raw = B64.decode(key_base64.trim()).ok()?;
    if raw.len() != 32 {
        return None;
    }
    let mut key = [0u8; 32];
    key.copy_from_slice(&raw);
    Some(key)
}

/// 加密一段 JSON。回傳 base64 的 `nonce || ciphertext || tag`。
///
/// 金鑰不合法或加密失敗時回**空字串**，呼叫端據此改送明文
/// （與 Apple 端 `encryptPayload` 回傳 `isEncrypted = false` 的行為一致）。
#[uniffi::export]
pub fn collab_encrypt(key_base64: String, plaintext: String) -> String {
    let Some(key) = decode_key(&key_base64) else {
        return String::new();
    };
    let mut nonce_bytes = [0u8; NONCE_LEN];
    if getrandom::getrandom(&mut nonce_bytes).is_err() {
        return String::new();
    }
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&key));
    let nonce = Nonce::from_slice(&nonce_bytes);
    match cipher.encrypt(
        nonce,
        Payload { msg: plaintext.as_bytes(), aad: &[] },
    ) {
        Ok(sealed) => {
            let mut combined = Vec::with_capacity(NONCE_LEN + sealed.len());
            combined.extend_from_slice(&nonce_bytes);
            combined.extend_from_slice(&sealed);
            B64.encode(combined)
        }
        Err(_) => String::new(),
    }
}

/// 解密。金鑰不符、密文被改過或格式不對時回空字串。
///
/// 解不開**不是**可以忽略的事：那代表對方用的是另一把金鑰，
/// 呼叫端應該丟掉那則訊息，不要把密文當成內容寫進筆記。
#[uniffi::export]
pub fn collab_decrypt(key_base64: String, ciphertext_base64: String) -> String {
    let Some(key) = decode_key(&key_base64) else {
        return String::new();
    };
    let Ok(combined) = B64.decode(ciphertext_base64.trim()) else {
        return String::new();
    };
    if combined.len() <= NONCE_LEN {
        return String::new();
    }
    let (nonce_bytes, sealed) = combined.split_at(NONCE_LEN);
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&key));
    match cipher.decrypt(
        Nonce::from_slice(nonce_bytes),
        Payload { msg: sealed, aad: &[] },
    ) {
        Ok(plain) => String::from_utf8(plain).unwrap_or_default(),
        Err(_) => String::new(),
    }
}

/// 產生新房號，形如 `kairumo-3f9a21`。
///
/// 亂數失敗時回空字串；呼叫端不該用空房號連線 —— 那會讓所有人擠進同一間。
#[uniffi::export]
pub fn collab_new_room_id() -> String {
    let mut raw = [0u8; 3];
    if getrandom::getrandom(&mut raw).is_err() {
        return String::new();
    }
    format!("kairumo-{:02x}{:02x}{:02x}", raw[0], raw[1], raw[2])
}

/// 邀請連結。金鑰放在 fragment（`#` 之後）——
/// fragment **不會**被瀏覽器或伺服器送出去，所以貼在網頁上時金鑰不會外洩。
#[uniffi::export]
pub fn collab_invite_link(room_id: String, key_base64: String) -> String {
    if room_id.is_empty() {
        return String::new();
    }
    if key_base64.is_empty() {
        format!("kairumo://collab?room={room_id}")
    } else {
        format!("kairumo://collab?room={room_id}#key={key_base64}")
    }
}

/// 從使用者貼上的字串解析出房號與金鑰。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiCollabInvite {
    pub room_id: String,
    /// 沒有帶金鑰時為空字串（表示這間房不加密）。
    pub key_base64: String,
}

/// 解析邀請。
///
/// 三種輸入都要吃得下，因為使用者三種都會貼：完整連結、
/// 連結加金鑰、或只有房號本身。解析不出房號時 `room_id` 為空。
#[uniffi::export]
pub fn collab_parse_invite(text: String) -> FfiCollabInvite {
    let cleaned = text.trim();
    let (room_part, key_part) = match cleaned.split_once('#') {
        Some((a, b)) => (a, b),
        None => (cleaned, ""),
    };
    let room_id = room_part
        .trim()
        .trim_start_matches("kairumo://collab?room=")
        .trim()
        .to_string();
    let key_base64 = key_part.trim().trim_start_matches("key=").trim().to_string();
    // 金鑰長度不對就當成沒有：拿一把壞金鑰連進去，會連上但每則訊息都解不開，
    // 那比明確地不加密更難查。
    let key_base64 = if decode_key(&key_base64).is_some() {
        key_base64
    } else {
        String::new()
    };
    FfiCollabInvite { room_id, key_base64 }
}

/// 位址是否指向本機（含沒填主機名的情況）。
///
/// 指向本機時平台層要**自己把中繼服務開起來** —— 少了這一步，
/// 預設的 `ws://127.0.0.1:9002` 後面根本沒有人在聽，畫面會永遠卡在
/// 「正在自動重新連線」。
#[uniffi::export]
pub fn collab_is_loopback_host(host: String) -> bool {
    let host = host.trim().to_lowercase();
    host.is_empty() || host == "127.0.0.1" || host == "localhost" || host == "::1" || host == "0.0.0.0"
}

/// 兩邊都要一樣的幾個時間與次數設定。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCollabTuning {
    /// 游標廣播的節流間隔（毫秒）。30Hz。
    ///
    /// 不節流的話，一次手寫會送出上千則訊息把中繼灌爆。
    pub presence_throttle_ms: u32,
    /// 心跳間隔（秒）。
    pub ping_interval_s: u32,
    /// 自動重連的最多次數。超過就停下來讓使用者決定。
    pub max_reconnect_attempts: u32,
    /// 預設中繼位址。
    pub default_server: String,
}

#[uniffi::export]
pub fn collab_tuning() -> FfiCollabTuning {
    FfiCollabTuning {
        presence_throttle_ms: 33,
        ping_interval_s: 20,
        max_reconnect_attempts: 5,
        default_server: "ws://127.0.0.1:9002".into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_generated_key_is_usable() {
        let key = collab_generate_room_key();
        assert!(collab_is_valid_room_key(key.clone()));
        // 32 位元組的 base64 是 44 個字元（含一個 `=`）。
        assert_eq!(key.len(), 44);
    }

    #[test]
    fn encryption_round_trips() {
        let key = collab_generate_room_key();
        let plain = r#"{"kind":"stroke","points":[1,2,3]}"#;
        let cipher = collab_encrypt(key.clone(), plain.into());
        assert!(!cipher.is_empty());
        assert_ne!(cipher, plain);
        assert_eq!(collab_decrypt(key, cipher), plain);
    }

    #[test]
    fn the_same_plaintext_encrypts_differently_every_time() {
        // nonce 要是隨機的。固定 nonce 的 GCM 會洩漏明文的異同，
        // 而那在測試裡看起來一切正常。
        let key = collab_generate_room_key();
        let a = collab_encrypt(key.clone(), "hello".into());
        let b = collab_encrypt(key, "hello".into());
        assert_ne!(a, b);
    }

    #[test]
    fn a_wrong_key_fails_instead_of_returning_garbage() {
        let key = collab_generate_room_key();
        let other = collab_generate_room_key();
        let cipher = collab_encrypt(key, "secret".into());
        assert!(collab_decrypt(other, cipher).is_empty());
    }

    #[test]
    fn tampered_ciphertext_is_rejected() {
        // GCM 是認證加密：改一個位元就該解不開。少了這個保證，
        // 中繼伺服器（或路上的任何人）可以偷改別人的筆記內容。
        let key = collab_generate_room_key();
        let cipher = collab_encrypt(key.clone(), "secret".into());
        let mut raw = B64.decode(&cipher).unwrap();
        let last = raw.len() - 1;
        raw[last] ^= 0x01;
        assert!(collab_decrypt(key, B64.encode(raw)).is_empty());
    }

    #[test]
    fn a_short_or_broken_key_is_rejected_not_padded() {
        assert!(!collab_is_valid_room_key(String::new()));
        assert!(!collab_is_valid_room_key("not base64 at all!!".into()));
        // 16 位元組的金鑰不能被默默補成 32 —— 那會讓加密強度悄悄減半。
        assert!(!collab_is_valid_room_key(B64.encode([7u8; 16])));
        assert!(collab_encrypt(B64.encode([7u8; 16]), "x".into()).is_empty());
    }

    #[test]
    fn room_ids_look_right_and_differ() {
        let a = collab_new_room_id();
        let b = collab_new_room_id();
        assert!(a.starts_with("kairumo-"));
        assert_eq!(a.len(), "kairumo-".len() + 6);
        assert_ne!(a, b);
    }

    #[test]
    fn invite_links_round_trip() {
        let key = collab_generate_room_key();
        let link = collab_invite_link("kairumo-abc123".into(), key.clone());
        let parsed = collab_parse_invite(link);
        assert_eq!(parsed.room_id, "kairumo-abc123");
        assert_eq!(parsed.key_base64, key);
    }

    #[test]
    fn a_bare_room_id_is_accepted() {
        // 使用者常常只把房號念給對方，而不是貼連結。
        let parsed = collab_parse_invite("  kairumo-abc123  ".into());
        assert_eq!(parsed.room_id, "kairumo-abc123");
        assert!(parsed.key_base64.is_empty());
    }

    #[test]
    fn a_link_without_a_key_parses_as_unencrypted() {
        let parsed = collab_parse_invite("kairumo://collab?room=kairumo-abc123".into());
        assert_eq!(parsed.room_id, "kairumo-abc123");
        assert!(parsed.key_base64.is_empty());
    }

    #[test]
    fn a_broken_key_in_a_link_is_dropped_not_used() {
        // 拿壞金鑰連進去會「連上但每則訊息都解不開」，比明確不加密更難查。
        let parsed = collab_parse_invite("kairumo://collab?room=r1#key=???".into());
        assert_eq!(parsed.room_id, "r1");
        assert!(parsed.key_base64.is_empty());
    }

    #[test]
    fn a_real_cryptokit_ciphertext_decrypts() {
        // **這個測試是整個模組存在的理由。**
        //
        // 下面這串是在這台 Mac 上用 Apple 的 CryptoKit（`AES.GCM.seal(...).combined`）
        // 實際產出來的。格式對不上時，程式照樣編得過、單元測試（自己加密自己解密）
        // 也照樣全綠 —— 只有真的拿 Apple 產出的密文來解，才驗得出相容性。
        //
        // 金鑰是 0x00..0x1F，明文是下面那段 JSON。
        let key = B64.encode((0u8..32).collect::<Vec<u8>>());
        let cipher = "Ni7UwQ5+vqq3o4U2qOXNimkn+iDdfJd5gE149LXpTuLyjdHAONkH5JQVOmKt1onqRIZykw==";
        assert_eq!(
            collab_decrypt(key, cipher.into()),
            r#"{"kind":"stroke","n":42}"#
        );
    }

    #[test]
    fn loopback_detection_covers_the_empty_host() {
        for host in ["127.0.0.1", "localhost", "::1", "0.0.0.0", "", "  "] {
            assert!(collab_is_loopback_host(host.into()), "{host} 應判為本機");
        }
        for host in ["relay.example.com", "192.168.1.20"] {
            assert!(!collab_is_loopback_host(host.into()), "{host} 不是本機");
        }
    }

    #[test]
    fn tuning_values_are_sane() {
        let t = collab_tuning();
        // 30Hz 左右。高太多會灌爆中繼，低太多游標會一格一格跳。
        assert!((20..=50).contains(&t.presence_throttle_ms));
        assert!(t.ping_interval_s > 0);
        assert!(t.max_reconnect_attempts > 0);
        assert!(t.default_server.starts_with("ws://"));
    }
}

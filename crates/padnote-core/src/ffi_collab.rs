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

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as B64;

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
///
/// # 實作在 `padnote_crypto::session`，不在這裡
///
/// 這兩個函式原本各自內嵌了一份 AES-256-GCM —— 與
/// `padnote_crypto::session::SessionKey` 是**同一套演算法、同一個位元組佈局**，
/// 只是複製了一份。而**跨語言互通測試（`tests/cryptokit_interop.rs`）
/// 釘的是 `padnote_crypto` 那一份**，不是實際在用的這一份。
///
/// 也就是說：有測試的那份沒人用，在用的那份沒有測試。兩份現在一樣，
/// 但沒有任何東西擋著它們分岔 —— 而分岔的症狀是「iOS 與 Android
/// 連得上、成員清單也對，但對方畫的東西永遠不出現」。
#[uniffi::export]
pub fn collab_encrypt(key_base64: String, plaintext: String) -> String {
    let Some(key) = session_key(&key_base64) else {
        return String::new();
    };
    key.seal_to_base64(plaintext.as_bytes()).unwrap_or_default()
}

/// 解密。金鑰不符、密文被改過或格式不對時回空字串。
///
/// 解不開**不是**可以忽略的事：那代表對方用的是另一把金鑰，
/// 呼叫端應該丟掉那則訊息，不要把密文當成內容寫進筆記。
#[uniffi::export]
pub fn collab_decrypt(key_base64: String, ciphertext_base64: String) -> String {
    let Some(key) = session_key(&key_base64) else {
        return String::new();
    };
    match key.open_from_base64(ciphertext_base64.trim()) {
        Ok(plain) => String::from_utf8(plain).unwrap_or_default(),
        Err(_) => String::new(),
    }
}

/// base64 金鑰 → `SessionKey`。長度不對或不是合法 base64 都回 `None`。
fn session_key(key_base64: &str) -> Option<padnote_crypto::session::SessionKey> {
    padnote_crypto::session::SessionKey::from_base64(key_base64.trim()).ok()
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

/// 一鍵協作的完整邀請（新版連結）。
///
/// 一個連結涵蓋所有連法：
/// - `servers`：依序嘗試的中繼位址（區網 → Tailscale → 遠端）。客端逐一試，連上就停
///   （每個最多 [`collab_connect_timeout_ms`]），使用者不必知道自己在哪個網路。
/// - `drive_folder`：房主分享的雲端資料夾 —— **跨網路的共同底稿**。有它就先把整本筆記
///   從雲端抓下來（頁面 id 與房主完全一致），中繼連不上也照樣能透過雲端協作。
/// - `notebook_id`：共享的是哪一本。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiCollabInviteFull {
    pub room_id: String,
    pub key_base64: String,
    pub servers: Vec<String>,
    pub drive_folder: String,
    pub notebook_id: String,
}

/// 每個中繼位址最多等多久（毫秒）。區網或 Tailscale 連得到的話通常幾十毫秒就握手完成；
/// 等太久的話，第一個位址不通時使用者會以為整個壞了。
#[uniffi::export]
pub fn collab_connect_timeout_ms() -> u32 {
    2500
}

fn encode_query_value(v: &str) -> String {
    let mut out = String::with_capacity(v.len());
    for b in v.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' | b':' | b'/' => {
                out.push(b as char)
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn decode_query_value(v: &str) -> String {
    let bytes = v.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        // 以位元組切片解碼：`%` 後面若是多位元組字元，用字串切片會切在字元中間而 panic。
        if bytes[i] == b'%'
            && i + 2 < bytes.len()
            && let Some(b) = std::str::from_utf8(&bytes[i + 1..i + 3])
                .ok()
                .and_then(|h| u8::from_str_radix(h, 16).ok())
        {
            out.push(b);
            i += 3;
            continue;
        }
        out.push(if bytes[i] == b'+' { b' ' } else { bytes[i] });
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// 產生完整邀請連結：`kairumo://collab?room=…&server=…&server=…&drive=…&nb=…#key=…`。
/// 舊版 App 只認 `room` 與第一個 `server`，仍然連得上（向下相容）。
#[uniffi::export]
pub fn collab_invite_link_full(
    room_id: String,
    key_base64: String,
    servers: Vec<String>,
    drive_folder: String,
    notebook_id: String,
) -> String {
    if room_id.is_empty() {
        return String::new();
    }
    let mut link = format!("kairumo://collab?room={}", encode_query_value(&room_id));
    let mut seen = std::collections::HashSet::new();
    for server in servers.iter().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        if seen.insert(server.to_string()) {
            link.push_str("&server=");
            link.push_str(&encode_query_value(server));
        }
    }
    if !drive_folder.trim().is_empty() {
        link.push_str("&drive=");
        link.push_str(&encode_query_value(drive_folder.trim()));
    }
    if !notebook_id.trim().is_empty() {
        link.push_str("&nb=");
        link.push_str(&encode_query_value(notebook_id.trim()));
    }
    if !key_base64.is_empty() {
        link.push_str("#key=");
        link.push_str(&key_base64);
    }
    link
}

/// 解析完整邀請連結（也吃舊版連結與純房號）。
#[uniffi::export]
pub fn collab_parse_invite_full(text: String) -> FfiCollabInviteFull {
    let basic = collab_parse_invite(text.clone());
    let cleaned = text.trim();
    let before_hash = cleaned.split('#').next().unwrap_or("");
    let query = before_hash.split_once('?').map(|(_, q)| q).unwrap_or("");
    let mut servers = Vec::new();
    let mut drive_folder = String::new();
    let mut notebook_id = String::new();
    for pair in query.split('&') {
        let Some((k, v)) = pair.split_once('=') else {
            continue;
        };
        let v = decode_query_value(v);
        match k {
            "server" if !v.is_empty() && !servers.contains(&v) => servers.push(v),
            "drive" => drive_folder = v,
            "nb" => notebook_id = v,
            _ => {}
        }
    }
    FfiCollabInviteFull {
        room_id: decode_query_value(&basic.room_id),
        key_base64: basic.key_base64,
        servers,
        drive_folder,
        notebook_id,
    }
}

/// 邀請連結的 QR Code：`size × size` 個模組，逐列由上而下、由左而右（`true` 是黑）。
///
/// 兩端畫同一份矩陣（I6）—— 各自用平台的產生器的話，版本、遮罩不同，
/// 一端掃得到、另一端掃不到時沒有辦法對照。文字太長編不進去時回 `size = 0`。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiQrCode {
    pub size: u32,
    pub modules: Vec<bool>,
}

#[uniffi::export]
pub fn collab_qr_code(text: String) -> FfiQrCode {
    use qrcodegen::{QrCode, QrCodeEcc};
    match QrCode::encode_text(&text, QrCodeEcc::Medium) {
        Ok(qr) => {
            let n = qr.size();
            let mut modules = Vec::with_capacity((n * n) as usize);
            for y in 0..n {
                for x in 0..n {
                    modules.push(qr.get_module(x, y));
                }
            }
            FfiQrCode {
                size: n as u32,
                modules,
            }
        }
        Err(_) => FfiQrCode {
            size: 0,
            modules: Vec::new(),
        },
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
    let mut raw_room = room_part.trim();
    if let Some(r) = raw_room.strip_prefix("kairumo://collab?room=") {
        raw_room = r;
    } else if let Some(r) = raw_room.strip_prefix("https://kairumo.app/collab?room=") {
        raw_room = r;
    } else if let Some(r) = raw_room.strip_prefix("http://kairumo.app/collab?room=") {
        raw_room = r;
    } else if let Some(r) = raw_room.strip_prefix("https://kairumo.app/collab/") {
        raw_room = r;
    } else if let Some(r) = raw_room.strip_prefix("http://kairumo.app/collab/") {
        raw_room = r;
    }
    let raw_room = raw_room.trim();
    let room_id = match raw_room.split_once('&') {
        Some((r, _)) => r.trim().to_string(),
        None => raw_room.to_string(),
    };
    let key_base64 = key_part
        .trim()
        .trim_start_matches("key=")
        .trim()
        .to_string();
    // 金鑰長度不對就當成沒有：拿一把壞金鑰連進去，會連上但每則訊息都解不開，
    // 那比明確地不加密更難查。
    let key_base64 = if decode_key(&key_base64).is_some() {
        key_base64
    } else {
        String::new()
    };
    FfiCollabInvite {
        room_id,
        key_base64,
    }
}

/// 位址是否指向本機（含沒填主機名的情況）。
///
/// 指向本機時平台層要**自己把中繼服務開起來** —— 少了這一步，
/// 預設的 `ws://127.0.0.1:9002` 後面根本沒有人在聽，畫面會永遠卡在
/// 「正在自動重新連線」。
#[uniffi::export]
pub fn collab_is_loopback_host(host: String) -> bool {
    let host = host.trim().to_lowercase();
    host.is_empty()
        || host == "127.0.0.1"
        || host == "localhost"
        || host == "::1"
        || host == "0.0.0.0"
}

/// 中繼位址檢查的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiServerCheck {
    /// 可以連。
    pub ok: bool,
    /// 不能連的理由鍵（語系鍵，平台層自己翻）。`ok` 為 true 時是空字串。
    pub reason_key: String,
}

/// 這個中繼位址能不能連。
///
/// # 為什麼要擋
///
/// 協同中繼原本接受任何 `ws://`。oplog 本身是端對端加密的，所以路上的人
/// 拿到的是密文 —— 但**房號、成員、連線時間與流量樣態全部是明文**，
/// 而且明文的 WebSocket 可以被中間人直接改寫或重導。
///
/// 區域網路與本機是另一回事：那是使用者自己的網段，而 `wss://` 在那裡
/// 需要一張沒有人會去簽的憑證。所以規則是：
///
/// - `wss://` —— 一律可以。
/// - `ws://` 指向**本機或私有網段**（RFC 1918、連結本地、`.local`）—— 可以。
/// - `ws://` 指向其他任何地方 —— **拒絕**，要求改用 `wss://`。
///
/// 放在核心而不是各平台各寫一次：兩邊判斷不一致的話，同一個位址在
/// iPad 上連得上、在 Android 上連不上，而那看起來會像 Android 壞掉。
#[uniffi::export]
pub fn collab_check_server(url: String) -> FfiServerCheck {
    let url = url.trim();
    let ok = |_: ()| FfiServerCheck {
        ok: true,
        reason_key: String::new(),
    };

    if url.is_empty() {
        return FfiServerCheck {
            ok: false,
            reason_key: "relay_url_empty".into(),
        };
    }
    if url.starts_with("wss://") {
        return ok(());
    }
    let Some(rest) = url.strip_prefix("ws://") else {
        return FfiServerCheck {
            ok: false,
            reason_key: "relay_url_scheme".into(),
        };
    };

    // 取出主機名：切掉路徑、查詢字串與連接埠。
    let host = rest
        .split(['/', '?', '#'])
        .next()
        .unwrap_or("")
        .rsplit_once(':')
        .map(|(h, _)| h)
        .unwrap_or_else(|| rest.split(['/', '?', '#']).next().unwrap_or(""))
        .trim_matches(['[', ']'])
        .to_lowercase();

    if is_private_host(&host) {
        ok(())
    } else {
        FfiServerCheck {
            ok: false,
            reason_key: "relay_needs_tls".into(),
        }
    }
}

/// 本機、區域網路或連結本地。
fn is_private_host(host: &str) -> bool {
    if collab_is_loopback_host(host.to_string()) {
        return true;
    }
    // mDNS 的區域名稱。
    if host.ends_with(".local") || host.ends_with(".home.arpa") {
        return true;
    }
    if let Ok(v6) = host.parse::<std::net::Ipv6Addr>() {
        // fc00::/7 唯一本地、fe80::/10 連結本地。
        let first = v6.octets()[0];
        return v6.is_loopback()
            || (first & 0xfe) == 0xfc
            || (first == 0xfe && (v6.octets()[1] & 0xc0) == 0x80);
    }
    let Ok(v4) = host.parse::<std::net::Ipv4Addr>() else {
        // 不是 IP 也不是 .local：那是一個公開網域名稱。
        return false;
    };
    let [a, b, ..] = v4.octets();
    v4.is_loopback()
        || a == 10
        || (a == 172 && (16..=31).contains(&b))
        || (a == 192 && b == 168)
        // 169.254/16 連結本地（含 Wi-Fi Direct 自動指派的位址）。
        || (a == 169 && b == 254)
        // 100.64/10 電信級 NAT —— 有些行動網路與 Tailscale 之類的覆蓋網路用它。
        || (a == 100 && (64..=127).contains(&b))
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

// =====================================================================
// Phase 1-4 進階功能 FFI 端口
// =====================================================================

#[uniffi::export]
pub fn collab_create_presence_event(device_id: u32, page_id: String, x: f32, y: f32) -> String {
    padnote_sync::presence::PresenceManager::create_cursor_event(device_id, &page_id, x, y)
}

#[uniffi::export]
pub fn collab_parse_presence_event(json: String) -> String {
    // 簡單回傳格式，供外層判定（實務上可回傳 Enum）
    json
}

#[uniffi::export]
pub fn collab_get_state_hash(oplog_paths: Vec<String>) -> u64 {
    let mut verifier = padnote_sync::state_verification::SyncStateVerifier::new();
    for p in oplog_paths {
        verifier.record_oplog(p);
    }
    verifier.compute_state_hash()
}

#[uniffi::export]
pub fn collab_lazy_sync_focus(page_ids: Vec<String>) {
    let mut manager = padnote_sync::lazy_sync::LazySyncManager::new();
    manager.focus_pages(page_ids);
}

#[uniffi::export]
pub fn collab_time_machine_contributors(block_id: String) -> std::collections::HashMap<u32, u32> {
    // 預留 FFI，回傳 index -> device_id
    let tm = padnote_sync::time_machine::TimeMachine::new();
    let map = tm.get_text_contributors(&block_id);
    let mut result = std::collections::HashMap::new();
    for (k, v) in map {
        result.insert(k as u32, v);
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plain_ws_to_the_public_internet_is_refused() {
        // oplog 是端對端加密的，但房號、成員與流量樣態全是明文，
        // 而且明文 WebSocket 可以被中間人直接改寫或重導。
        assert!(!collab_check_server("ws://relay.example.com:9002".into()).ok);
        assert!(!collab_check_server("ws://203.0.113.9:9002".into()).ok);
        assert_eq!(
            collab_check_server("ws://relay.example.com".into()).reason_key,
            "relay_needs_tls"
        );
    }

    #[test]
    fn the_local_network_may_stay_plain() {
        // 區域網路是使用者自己的網段，而 wss:// 在那裡需要一張
        // 沒有人會去簽的憑證。擋掉的話協同在區網上直接不能用。
        for url in [
            "ws://127.0.0.1:9002",
            "ws://localhost:9002",
            "ws://192.168.1.42:9002",
            "ws://10.0.0.7:9002",
            "ws://172.16.5.1:9002",
            "ws://169.254.3.4:9002",
            "ws://macbook.local:9002",
            "ws://[fe80::1]:9002",
        ] {
            assert!(collab_check_server(url.into()).ok, "{url} 該被放行");
        }
    }

    #[test]
    fn tls_is_always_fine_and_junk_is_not() {
        assert!(collab_check_server("wss://relay.example.com".into()).ok);
        assert_eq!(collab_check_server("".into()).reason_key, "relay_url_empty");
        assert_eq!(
            collab_check_server("http://relay.example.com".into()).reason_key,
            "relay_url_scheme"
        );
    }

    #[test]
    fn a_public_address_that_merely_starts_like_a_private_one_is_refused() {
        // 172.32 不在 172.16–31 裡；192.169 不是 192.168。
        // 用字串前綴比對的話這兩個會被放行。
        assert!(!collab_check_server("ws://172.32.0.1:9002".into()).ok);
        assert!(!collab_check_server("ws://192.169.1.1:9002".into()).ok);
        assert!(!collab_check_server("ws://10a.example.com".into()).ok);
    }

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
    fn a_link_with_server_query_parses_room_id_cleanly() {
        let link = "kairumo://collab?room=kairumo-123456&server=ws://192.168.1.50:9002#key=abc";
        let parsed = collab_parse_invite(link.into());
        assert_eq!(parsed.room_id, "kairumo-123456");
    }

    #[test]
    fn a_web_link_parses_room_id_and_key() {
        let link1 = "https://kairumo.app/collab?room=kairumo-web123&server=ws://100.80.1.2:9002";
        assert_eq!(collab_parse_invite(link1.into()).room_id, "kairumo-web123");
        let link2 = "https://kairumo.app/collab/kairumo-web456#key=AAA";
        assert_eq!(collab_parse_invite(link2.into()).room_id, "kairumo-web456");
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

    #[test]
    fn qr_code_encodes_an_invite() {
        let qr = collab_qr_code(collab_invite_link("ABC123".into(), "a2V5".into()));
        assert!(qr.size >= 21);
        assert_eq!(qr.modules.len(), (qr.size * qr.size) as usize);
        // 左上角的定位圖樣：外圈全黑。
        assert!(qr.modules[0] && qr.modules[6] && qr.modules[(6 * qr.size) as usize]);
        assert_eq!(collab_qr_code("x".repeat(8000)).size, 0);
    }

    #[test]
    fn full_invite_round_trips_every_route() {
        let key = "a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2U=".to_string();
        let link = collab_invite_link_full(
            "kairumo-db5a57".into(),
            key.clone(),
            vec![
                "ws://192.168.68.55:9002".into(),
                "ws://100.73.43.39:9002".into(),
                "ws://192.168.68.55:9002".into(),
            ],
            "1AbC_folder-Id".into(),
            "nb-123".into(),
        );
        assert!(
            link.starts_with("kairumo://collab?room=kairumo-db5a57&server=ws://192.168.68.55:9002")
        );
        let parsed = collab_parse_invite_full(link);
        assert_eq!(parsed.room_id, "kairumo-db5a57");
        assert_eq!(
            parsed.servers,
            vec!["ws://192.168.68.55:9002", "ws://100.73.43.39:9002"]
        );
        assert_eq!(parsed.drive_folder, "1AbC_folder-Id");
        assert_eq!(parsed.notebook_id, "nb-123");
        assert_eq!(
            parsed.key_base64,
            collab_parse_invite("x#key=".to_string() + &key).key_base64
        );
        // 舊版連結照樣讀得懂。
        let old = collab_parse_invite_full(
            "kairumo://collab?room=r1&server=ws%3A%2F%2F10.0.0.2%3A9002".into(),
        );
        assert_eq!(old.room_id, "r1");
        assert_eq!(old.servers, vec!["ws://10.0.0.2:9002"]);
        assert!(old.drive_folder.is_empty());
    }
}

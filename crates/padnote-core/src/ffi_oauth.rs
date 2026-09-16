//! Google OAuth 授權流程（G-01，ADR-0011）。
//!
//! # 為什麼整個流程在核心，只有「開瀏覽器」留給平台
//!
//! OAuth 的難處不在開視窗，而在**每一個參數都要對**：PKCE 的 challenge 怎麼算、
//! redirect URI 長什麼樣、交換權杖時要送哪些欄位。任何一項兩邊寫得不一樣，
//! Google 回的就是一句 `invalid_grant`，而那句話對「哪裡不一樣」毫無提示。
//!
//! 所以這裡負責組出所有的 URL 與請求內容，平台只做兩件它非做不可的事：
//! 把使用者丟進系統瀏覽器（`ASWebAuthenticationSession` / Custom Tabs），
//! 以及把權杖放進安全儲存區（Keychain / EncryptedSharedPreferences）。
//!
//! # 為什麼沒有 client secret
//!
//! Google 不發 client secret 給 iOS 與 Android 型別的 client —— 行動 App 藏不住
//! 任何東西，拆包就看得到。安全性改由 **PKCE** 與平台簽章驗證（bundle id /
//! 套件名 + 憑證指紋）提供。所以下面的 client id 可以進版控，它不是機密。
//!
//! # 權杖過期的兩種情況要分開
//!
//! - access token 過期（一小時）→ 用 refresh token 靜靜換一個新的，使用者無感。
//! - refresh token 失效（撤銷授權、密碼變更、或**專案還在 Testing 狀態時滿 7 天**）
//!   → 只能請使用者重新登入。
//!
//! 混在一起的話，第二種情況會變成無限重試的背景迴圈，而使用者只看到
//! 「同步失敗」卻不知道該去登入。

use base64::Engine as _;
use base64::engine::general_purpose::URL_SAFE_NO_PAD as B64URL;
use sha2::{Digest, Sha256};

/// 要授權的範圍。
///
/// `appdata` 是 Drive 裡專給 App 用的隱藏空間 —— 使用者在自己的雲端硬碟裡
/// **看不到**這些檔案，其他 App 也讀不到。這正是放同步狀態的地方（ADR-0011）。
pub const DRIVE_APPDATA_SCOPE: &str = "https://www.googleapis.com/auth/drive.appdata";

const AUTH_ENDPOINT: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_ENDPOINT: &str = "https://oauth2.googleapis.com/token";
const REVOKE_ENDPOINT: &str = "https://oauth2.googleapis.com/revoke";

/// 哪一個平台的 OAuth client。
///
/// Google 的 client 是**按平台**發的：iOS 型別驗 bundle id，Android 型別驗
/// 套件名加憑證指紋。用錯一邊會被拒絕。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiOAuthPlatform {
    /// iOS / iPadOS / macOS（Mac 版走 Catalyst，與 iOS 同一個 bundle id）。
    Apple,
    Android,
}

/// 這個平台的 client id。
///
/// **不是機密**（見模組說明），所以寫在這裡而不是另外弄一個設定檔 ——
/// 放在兩個平台各自的設定裡，遲早會有一邊改了另一邊沒改。
#[uniffi::export]
pub fn oauth_client_id(platform: FfiOAuthPlatform) -> String {
    match platform {
        FfiOAuthPlatform::Apple => {
            "155748821200-elecovdu3l4m1t17dpf6q1snb3coctld.apps.googleusercontent.com"
        }
        FfiOAuthPlatform::Android => {
            "155748821200-ff0a8ni2tsfdct1j2877t01kpjdiv5mi.apps.googleusercontent.com"
        }
    }
    .to_string()
}

/// 這個平台的 redirect URI。
///
/// Google 對 iOS/Android client 用的是**反轉的 client id** 當自訂 scheme。
/// 平台層必須把同一個 scheme 註冊進 App（Info.plist 的 CFBundleURLSchemes /
/// AndroidManifest 的 intent-filter），兩邊拼不一樣的話，使用者授權完會
/// 回不到 App —— 瀏覽器停在一個打不開的網址上。
#[uniffi::export]
pub fn oauth_redirect_uri(platform: FfiOAuthPlatform) -> String {
    format!("{}:/oauth2redirect", oauth_url_scheme(platform))
}

/// 要註冊進 App 的自訂 scheme（reversed client id）。
#[uniffi::export]
pub fn oauth_url_scheme(platform: FfiOAuthPlatform) -> String {
    let id = oauth_client_id(platform);
    let prefix = id
        .strip_suffix(".apps.googleusercontent.com")
        .unwrap_or(&id);
    format!("com.googleusercontent.apps.{prefix}")
}

/// 一次授權所需的一組隨機值。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPkcePair {
    /// 交換權杖時要送回去的原始值。**只留在本機記憶體，不要落盤。**
    pub verifier: String,
    /// 放進授權網址的雜湊值。
    pub challenge: String,
    /// 防 CSRF 用的隨機值。授權回來時要比對，不符就丟掉。
    pub state: String,
}

/// 產生 PKCE 與 state。
///
/// verifier 用 64 個位元組的亂數（規格允許 43–128 個字元，取上限附近）。
/// 亂數產不出來時回空字串 —— 呼叫端據此中止，不要用一組可預測的值去授權。
#[uniffi::export]
pub fn oauth_new_pkce() -> FfiPkcePair {
    let verifier = random_b64url(64);
    let state = random_b64url(16);
    if verifier.is_empty() || state.is_empty() {
        return FfiPkcePair {
            verifier: String::new(),
            challenge: String::new(),
            state: String::new(),
        };
    }
    let challenge = B64URL.encode(Sha256::digest(verifier.as_bytes()));
    FfiPkcePair {
        verifier,
        challenge,
        state,
    }
}

fn random_b64url(bytes: usize) -> String {
    let mut raw = vec![0u8; bytes];
    if getrandom::getrandom(&mut raw).is_err() {
        return String::new();
    }
    B64URL.encode(raw)
}

/// 把使用者丟去的授權網址。
///
/// `login_hint` 傳空字串表示不指定帳號。指定的話，Google 會直接用那個帳號 ——
/// 重新登入時很有用，使用者不必在一堆帳號裡找剛才那個。
#[uniffi::export]
pub fn oauth_authorize_url(
    platform: FfiOAuthPlatform,
    code_challenge: String,
    state: String,
    login_hint: String,
) -> String {
    let mut params = vec![
        ("client_id", oauth_client_id(platform)),
        ("redirect_uri", oauth_redirect_uri(platform)),
        ("response_type", "code".to_string()),
        ("scope", DRIVE_APPDATA_SCOPE.to_string()),
        ("code_challenge", code_challenge),
        ("code_challenge_method", "S256".to_string()),
        ("state", state),
        // 一定要 offline，否則拿不到 refresh token，使用者每小時都要重新登入。
        ("access_type", "offline".to_string()),
        // 不加的話，**第二次以後的授權不會再發 refresh token** ——
        // 使用者重裝 App 重新登入，結果只拿到一小時的 access token。
        ("prompt", "consent".to_string()),
    ];
    if !login_hint.is_empty() {
        params.push(("login_hint", login_hint));
    }
    format!("{AUTH_ENDPOINT}?{}", encode_form(&params))
}

/// 從 redirect 回來的網址裡取出授權碼。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiAuthCallback {
    /// 授權碼。失敗時為空字串。
    pub code: String,
    /// 回傳的 state，呼叫端要與自己發出去的比對。
    pub state: String,
    /// Google 回報的錯誤代碼（例如 `access_denied`）。成功時為空字串。
    pub error: String,
}

/// 解析授權完成後跳回來的網址。
///
/// **呼叫端一定要比對 state。** 不比對的話，別人可以誘導使用者的 App
/// 去交換一個攻擊者取得的授權碼，結果是資料同步到攻擊者的雲端硬碟。
#[uniffi::export]
pub fn oauth_parse_callback(url: String) -> FfiAuthCallback {
    let query = url.split_once('?').map(|(_, q)| q).unwrap_or("");
    let mut out = FfiAuthCallback {
        code: String::new(),
        state: String::new(),
        error: String::new(),
    };
    for pair in query.split('&') {
        let Some((k, v)) = pair.split_once('=') else {
            continue;
        };
        let value = percent_decode(v);
        match k {
            "code" => out.code = value,
            "state" => out.state = value,
            "error" => out.error = value,
            _ => {}
        }
    }
    out
}

/// 交換權杖用的 POST 內容（`application/x-www-form-urlencoded`）。
#[uniffi::export]
pub fn oauth_exchange_body(platform: FfiOAuthPlatform, code: String, verifier: String) -> String {
    encode_form(&[
        ("client_id", oauth_client_id(platform)),
        ("code", code),
        ("code_verifier", verifier),
        ("grant_type", "authorization_code".to_string()),
        ("redirect_uri", oauth_redirect_uri(platform)),
    ])
}

/// 更新權杖用的 POST 內容。
#[uniffi::export]
pub fn oauth_refresh_body(platform: FfiOAuthPlatform, refresh_token: String) -> String {
    encode_form(&[
        ("client_id", oauth_client_id(platform)),
        ("refresh_token", refresh_token),
        ("grant_type", "refresh_token".to_string()),
    ])
}

#[uniffi::export]
pub fn oauth_token_endpoint() -> String {
    TOKEN_ENDPOINT.to_string()
}

/// 撤銷授權的網址。登出時打它，才會真的從使用者的 Google 帳號移除授權。
#[uniffi::export]
pub fn oauth_revoke_url(token: String) -> String {
    format!("{REVOKE_ENDPOINT}?token={}", percent_encode(&token))
}

/// 權杖交換／更新的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTokenSet {
    pub access_token: String,
    /// 更新用的權杖。**更新回應裡通常沒有這一項**，此時要沿用舊的 ——
    /// 覆蓋成空字串的話，下一次就再也更新不了，使用者被迫重新登入。
    pub refresh_token: String,
    /// 這個 access token 何時過期（Unix 秒）。
    pub expires_at_s: u64,
    /// 失敗時 Google 給的錯誤代碼；成功時為空字串。
    pub error: String,
}

/// 解析權杖回應。
///
/// `now_s` 由平台傳入目前的 Unix 時間 —— 核心不讀時鐘，測試才驗得了過期邏輯。
#[uniffi::export]
pub fn oauth_parse_token_response(json: String, now_s: u64) -> FfiTokenSet {
    let value: serde_json::Value = serde_json::from_str(&json).unwrap_or_default();
    let error = value
        .get("error")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let expires_in = value
        .get("expires_in")
        .and_then(|v| v.as_u64())
        .unwrap_or(0);
    FfiTokenSet {
        access_token: str_field(&value, "access_token"),
        refresh_token: str_field(&value, "refresh_token"),
        // 提早 60 秒算過期：請求送到 Google 的路上也要花時間，
        // 掐著最後一秒去用，偶爾會拿到 401 而看起來像「同步隨機失敗」。
        expires_at_s: now_s.saturating_add(expires_in.saturating_sub(60)),
        error,
    }
}

fn str_field(value: &serde_json::Value, key: &str) -> String {
    value
        .get(key)
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string()
}

/// 這組權杖現在還能用嗎。
#[uniffi::export]
pub fn oauth_is_access_valid(tokens: FfiTokenSet, now_s: u64) -> bool {
    !tokens.access_token.is_empty() && now_s < tokens.expires_at_s
}

/// 這個錯誤代表 refresh token 已經失效，**只能請使用者重新登入**。
///
/// 與「網路壞了」分開：後者重試就好，前者重試一百次也一樣。
/// 混在一起的話會變成無限重試的背景迴圈，而使用者只看到「同步失敗」
/// 卻不知道該去登入。
#[uniffi::export]
pub fn oauth_needs_reauth(error: String) -> bool {
    matches!(
        error.as_str(),
        "invalid_grant" | "unauthorized_client" | "invalid_client"
    )
}

// ── 編碼小工具 ──────────────────────────────────────────────────────

fn encode_form(params: &[(&str, String)]) -> String {
    params
        .iter()
        .map(|(k, v)| format!("{}={}", percent_encode(k), percent_encode(v)))
        .collect::<Vec<_>>()
        .join("&")
}

/// `application/x-www-form-urlencoded` 的百分號編碼。
///
/// 自己寫是因為只需要這一點點，拉一個相依進來不划算 —— 但**未保留字元的
/// 集合要對**：漏掉 `~` 或把 `/` 當成安全字元，Google 會回 `invalid_request`，
/// 而錯誤訊息不會說是哪個參數。
fn percent_encode(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for byte in value.as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                out.push(*byte as char)
            }
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}

fn percent_decode(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'%' if i + 2 < bytes.len() => {
                let hex = std::str::from_utf8(&bytes[i + 1..i + 3]).unwrap_or("");
                match u8::from_str_radix(hex, 16) {
                    Ok(b) => {
                        out.push(b);
                        i += 3;
                    }
                    Err(_) => {
                        out.push(bytes[i]);
                        i += 1;
                    }
                }
            }
            b'+' => {
                out.push(b' ');
                i += 1;
            }
            b => {
                out.push(b);
                i += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_redirect_uri_is_the_reversed_client_id() {
        // 平台層要把同一個 scheme 註冊進 App。拼不一樣的話，使用者授權完
        // 回不到 App —— 瀏覽器停在一個打不開的網址上。
        let scheme = oauth_url_scheme(FfiOAuthPlatform::Apple);
        assert_eq!(
            scheme,
            "com.googleusercontent.apps.155748821200-elecovdu3l4m1t17dpf6q1snb3coctld"
        );
        assert_eq!(
            oauth_redirect_uri(FfiOAuthPlatform::Apple),
            format!("{scheme}:/oauth2redirect")
        );
    }

    #[test]
    fn the_two_platforms_use_different_clients() {
        // Google 的 client 是按平台發的：iOS 型別驗 bundle id、Android 型別驗
        // 套件名加指紋。用錯一邊會被拒絕。
        assert_ne!(
            oauth_client_id(FfiOAuthPlatform::Apple),
            oauth_client_id(FfiOAuthPlatform::Android)
        );
    }

    #[test]
    fn pkce_challenge_is_the_sha256_of_the_verifier() {
        let pair = oauth_new_pkce();
        assert!(!pair.verifier.is_empty());
        let expected = B64URL.encode(Sha256::digest(pair.verifier.as_bytes()));
        assert_eq!(pair.challenge, expected);
        // base64url 不可以有 padding 或 + /，否則 Google 會拒絕。
        assert!(!pair.challenge.contains('='));
        assert!(!pair.challenge.contains('+'));
        assert!(!pair.challenge.contains('/'));
    }

    #[test]
    fn every_authorization_is_a_fresh_one() {
        // verifier 或 state 被重複使用的話，PKCE 與 CSRF 防護都失效。
        let a = oauth_new_pkce();
        let b = oauth_new_pkce();
        assert_ne!(a.verifier, b.verifier);
        assert_ne!(a.state, b.state);
    }

    #[test]
    fn the_authorize_url_asks_for_a_refresh_token() {
        let url = oauth_authorize_url(
            FfiOAuthPlatform::Android,
            "challenge".into(),
            "state123".into(),
            String::new(),
        );
        // 少了 access_type=offline 就拿不到 refresh token，使用者每小時
        // 都要重新登入；少了 prompt=consent，第二次以後的授權不會再發。
        assert!(url.contains("access_type=offline"), "{url}");
        assert!(url.contains("prompt=consent"), "{url}");
        assert!(url.contains("code_challenge_method=S256"), "{url}");
        assert!(url.contains("state=state123"), "{url}");
        // scope 裡的 `/` 與 `:` 都要編碼過。
        assert!(url.contains("scope=https%3A%2F%2F"), "{url}");
        // 沒給 login_hint 時不要送一個空的。
        assert!(!url.contains("login_hint"), "{url}");
    }

    #[test]
    fn a_login_hint_is_included_when_given() {
        let url = oauth_authorize_url(
            FfiOAuthPlatform::Apple,
            "c".into(),
            "s".into(),
            "me@example.com".into(),
        );
        assert!(url.contains("login_hint=me%40example.com"), "{url}");
    }

    #[test]
    fn the_callback_is_parsed_and_errors_are_visible() {
        let ok = oauth_parse_callback(
            "com.googleusercontent.apps.x:/oauth2redirect?state=abc&code=4%2F0AY".into(),
        );
        assert_eq!(ok.code, "4/0AY");
        assert_eq!(ok.state, "abc");
        assert!(ok.error.is_empty());

        // 使用者按「取消」也會跳回來，那不是當機。
        let denied = oauth_parse_callback("x:/oauth2redirect?error=access_denied&state=abc".into());
        assert_eq!(denied.error, "access_denied");
        assert!(denied.code.is_empty());
    }

    #[test]
    fn token_expiry_leaves_a_margin() {
        // 掐著最後一秒去用，偶爾會拿到 401 —— 看起來像「同步隨機失敗」。
        let tokens = oauth_parse_token_response(
            r#"{"access_token":"at","refresh_token":"rt","expires_in":3600}"#.into(),
            1_000,
        );
        assert_eq!(tokens.access_token, "at");
        assert_eq!(tokens.refresh_token, "rt");
        assert_eq!(tokens.expires_at_s, 1_000 + 3600 - 60);
        assert!(oauth_is_access_valid(tokens.clone(), 1_000));
        assert!(!oauth_is_access_valid(tokens, 1_000 + 3600));
    }

    #[test]
    fn a_refresh_response_without_a_refresh_token_is_normal() {
        // 更新回應通常**沒有** refresh_token。呼叫端要沿用舊的；
        // 覆蓋成空字串的話下一次就再也更新不了，使用者被迫重新登入。
        let tokens =
            oauth_parse_token_response(r#"{"access_token":"new","expires_in":3600}"#.into(), 0);
        assert_eq!(tokens.access_token, "new");
        assert!(tokens.refresh_token.is_empty());
        assert!(tokens.error.is_empty());
    }

    #[test]
    fn expired_refresh_tokens_are_distinguished_from_network_trouble() {
        // 混在一起會變成無限重試的背景迴圈，而使用者只看到「同步失敗」
        // 卻不知道該去登入。Testing 狀態的專案七天就會踩到這個。
        let err = oauth_parse_token_response(r#"{"error":"invalid_grant"}"#.into(), 0);
        assert!(oauth_needs_reauth(err.error));
        assert!(!oauth_needs_reauth("network_unreachable".into()));
        assert!(!oauth_needs_reauth(String::new()));
    }

    #[test]
    fn a_garbage_response_does_not_panic() {
        let tokens = oauth_parse_token_response("not json".into(), 5);
        assert!(tokens.access_token.is_empty());
        assert!(!oauth_is_access_valid(tokens, 5));
    }

    #[test]
    fn form_bodies_are_encoded_the_way_google_expects() {
        let body = oauth_exchange_body(
            FfiOAuthPlatform::Apple,
            "4/0AY-code".into(),
            "verifier~value".into(),
        );
        assert!(body.contains("grant_type=authorization_code"), "{body}");
        assert!(body.contains("code=4%2F0AY-code"), "{body}");
        // `~` 是未保留字元，**不可以**被編碼 —— 編了 Google 會回
        // invalid_grant，而訊息不會說是哪個參數。
        assert!(body.contains("code_verifier=verifier~value"), "{body}");

        let refresh = oauth_refresh_body(FfiOAuthPlatform::Android, "rt".into());
        assert!(refresh.contains("grant_type=refresh_token"), "{refresh}");
        assert!(!refresh.contains("redirect_uri"), "更新不需要 redirect_uri");
    }

    #[test]
    fn revoking_encodes_the_token() {
        let url = oauth_revoke_url("a/b+c".into());
        assert!(url.starts_with("https://oauth2.googleapis.com/revoke?token="));
        assert!(url.contains("a%2Fb%2Bc"), "{url}");
    }
}

//! 雲端協作（共享資料夾）與一鍵連線。
//!
//! # 模型
//!
//! 房主把一本筆記放進自己雲端硬碟裡的一個**一般資料夾**（不是 `appDataFolder`，
//! 那裡在技術上無法分享），授予協作者「編輯者」權限。每位參與者的裝置把自己的
//! 事件檔（`notebooks/<id>/doc/ops/<lamport>-<device>.oplog`）寫進同一個資料夾 ——
//! 檔名含裝置 id、寫完不再修改，所以多人同時寫不會互相覆蓋，合併規則與一個人的
//! 多台裝置完全相同（I3、I5）。
//!
//! 這個資料夾是「共同的底稿與跨網路通道」；同一個網路時再自動加上區網中繼，
//! 提供即時筆跡與游標（混合模式）。兩條管道送來的同一筆操作 id 相同，冪等。
//!
//! # 權限：`drive.file`
//!
//! 非敏感權限，不需要 Google 安全審查。App 只看得到「這個使用者用這個 App 建立或
//! 打開過的檔案」—— 所以協作者第一次要透過 Google 的**桌面／行動版挑選器**
//! （授權網址帶 `trigger_onepick=true`）選取那個資料夾，見 [`oauth_collab_authorize_url`]。
//! 選取資料夾之後，資料夾裡**別人**建立的檔案是否也看得到，Google 文件沒有寫明；
//! 所以加入時一律做權限探測（[`collab_drive_probe`]），看不到就明講，不給一本空白筆記。
//!
//! # 延遲
//!
//! Drive 沒有不需要伺服器的推播，只能輪詢。降低延遲感靠三件事：
//! 1. **本機優先**：自己的操作立刻生效，不等雲端（本來就是）。
//! 2. **自適應輪詢**（[`collab_cloud_poll_ms`]）：有人在動時 2 秒一次，閒置時放慢，背景暫停。
//! 3. **在場檔**（[`FfiCloudPresence`]）：每人每幾秒寫一個小檔說「我在第幾頁、正在改哪個物件」，
//!    其他人看得到，自然分頁分物件作業，減少同時改同一個東西。

use std::sync::Arc;

use padnote_sync::gdrive::{DriveRoot, GDriveProvider};
use padnote_sync::provider::SyncError;

use crate::ffi_gdrive::{FfiDriveHttp, ForeignHttp};
use crate::ffi_oauth::{
    FfiOAuthPlatform, encode_form, oauth_client_id, oauth_redirect_uri, percent_decode,
};

/// 協作憑證的權限範圍。與主帳號同步用的 `drive.appdata` 分開存放、分開換證。
pub const DRIVE_FILE_SCOPE: &str = "https://www.googleapis.com/auth/drive.file";

// ---- 共用的結果型別 -----------------------------------------------------------

#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiDriveShareResult {
    pub ok: bool,
    /// 建立的資料夾 id 或 permission id。
    pub id: String,
    pub error: String,
    /// 權杖失效或權限不足，要重新授權。
    pub needs_reauth: bool,
}

fn share_ok(id: String) -> FfiDriveShareResult {
    FfiDriveShareResult {
        ok: true,
        id,
        error: String::new(),
        needs_reauth: false,
    }
}

fn share_err(e: SyncError) -> FfiDriveShareResult {
    FfiDriveShareResult {
        ok: false,
        id: String::new(),
        needs_reauth: matches!(e, SyncError::PermissionDenied(_)),
        error: e.to_string(),
    }
}

fn provider(http: Arc<dyn FfiDriveHttp>, folder_id: &str) -> GDriveProvider<ForeignHttp> {
    let root = if folder_id.is_empty() {
        DriveRoot::AppData
    } else {
        DriveRoot::Folder(folder_id.to_string())
    };
    GDriveProvider::with_root(ForeignHttp(http), root)
}

// ---- 資料夾與成員 --------------------------------------------------------------

/// 協作資料夾在房主雲端硬碟裡的名字。看得出是哪本筆記，也看得出是 Kairumo 建的。
#[uniffi::export]
pub fn collab_drive_folder_name(title: String) -> String {
    let clean: String = title
        .trim()
        .chars()
        .filter(|c| !c.is_control())
        .take(80)
        .collect();
    if clean.is_empty() {
        "Kairumo · Shared".to_string()
    } else {
        format!("Kairumo · {clean}")
    }
}

/// 建立協作筆記本的專屬資料夾：一律收納於「Kairumo Co.」主資料夾底下。
/// **同步等待 HTTP，不要在主執行緒呼叫。**
#[uniffi::export]
pub fn collab_drive_create_folder(
    http: Arc<dyn FfiDriveHttp>,
    title: String,
) -> FfiDriveShareResult {
    match provider(http, "").create_notebook_collab_folder(&title) {
        Ok(id) => share_ok(id),
        Err(e) => share_err(e),
    }
}

/// 把資料夾分享給一個 Email（編輯者）。Google 會寄通知信給對方。
#[uniffi::export]
pub fn collab_drive_grant(
    http: Arc<dyn FfiDriveHttp>,
    folder_id: String,
    email: String,
) -> FfiDriveShareResult {
    if !collab_email_looks_valid(email.clone()) {
        return FfiDriveShareResult {
            ok: false,
            id: String::new(),
            error: "invalid_email".into(),
            needs_reauth: false,
        };
    }
    match provider(http, &folder_id).grant(&folder_id, &email, "writer") {
        Ok(id) => share_ok(id),
        Err(e) => share_err(e),
    }
}

/// 「知道連結的人都能編輯」（一鍵邀請，不必輸入 Email）。
#[uniffi::export]
pub fn collab_drive_grant_link(
    http: Arc<dyn FfiDriveHttp>,
    folder_id: String,
) -> FfiDriveShareResult {
    match provider(http, &folder_id).grant_anyone_with_link(&folder_id) {
        Ok(id) => share_ok(id),
        Err(e) => share_err(e),
    }
}

/// 很鬆的 Email 檢查：有一個 `@`、兩邊都有東西、網域有點。真正的檢查交給 Google。
#[uniffi::export]
pub fn collab_email_looks_valid(email: String) -> bool {
    let e = email.trim();
    match e.split_once('@') {
        Some((user, domain)) => {
            !user.is_empty()
                && !domain.is_empty()
                && domain.contains('.')
                && !domain.starts_with('.')
                && !domain.ends_with('.')
                && !e.contains(char::is_whitespace)
                && e.matches('@').count() == 1
        }
        None => false,
    }
}

#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiDriveMember {
    pub permission_id: String,
    pub email: String,
    pub name: String,
    pub role: String,
}

#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiDriveMembers {
    pub ok: bool,
    pub members: Vec<FfiDriveMember>,
    pub error: String,
    pub needs_reauth: bool,
}

/// 資料夾的成員（含房主）。
#[uniffi::export]
pub fn collab_drive_members(http: Arc<dyn FfiDriveHttp>, folder_id: String) -> FfiDriveMembers {
    match provider(http, &folder_id).members(&folder_id) {
        Ok(list) => FfiDriveMembers {
            ok: true,
            members: list
                .into_iter()
                .map(|m| FfiDriveMember {
                    permission_id: m.permission_id,
                    email: m.email,
                    name: m.name,
                    role: m.role,
                })
                .collect(),
            error: String::new(),
            needs_reauth: false,
        },
        Err(e) => FfiDriveMembers {
            ok: false,
            members: Vec::new(),
            needs_reauth: matches!(e, SyncError::PermissionDenied(_)),
            error: e.to_string(),
        },
    }
}

/// 撤銷一位成員。對方保留最後一份本機副本，之後同步不到。
#[uniffi::export]
pub fn collab_drive_revoke(
    http: Arc<dyn FfiDriveHttp>,
    folder_id: String,
    permission_id: String,
) -> FfiDriveShareResult {
    match provider(http, &folder_id).revoke(&folder_id, &permission_id) {
        Ok(()) => share_ok(permission_id),
        Err(e) => share_err(e),
    }
}

/// 權限探測的結論。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiDriveAccess {
    /// 看得到、寫得進去，而且看得到房主的檔案。
    Ready,
    /// 資料夾不存在、被刪掉，或這個帳號沒有被分享。
    NotShared,
    /// 只有檢視權限，不能寫。
    ReadOnly,
    /// 看得到資料夾，但看不到裡面別人建立的檔案（`drive.file` 的限制）。
    ContentsHidden,
    /// 網路或其他暫時性錯誤，可以重試。
    Retry,
    /// 權杖失效，要重新授權。
    Reauth,
}

#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiDriveProbe {
    pub access: FfiDriveAccess,
    pub folder_name: String,
    pub visible_files: u32,
    /// 對應的語系鍵，平台直接拿去顯示。`Ready` 時為空字串。
    pub message_key: String,
}

/// 加入前的權限探測。`expected_min_files` 是邀請裡房主宣告的檔案數下限
/// （房主那時已經上傳了這本筆記，所以至少有那麼多個）；0 表示不檢查。
#[uniffi::export]
pub fn collab_drive_probe(
    http: Arc<dyn FfiDriveHttp>,
    folder_id: String,
    expected_min_files: u32,
) -> FfiDriveProbe {
    let verdict = |access: FfiDriveAccess, name: String, files: u32| FfiDriveProbe {
        access,
        folder_name: name,
        visible_files: files,
        message_key: match access {
            FfiDriveAccess::Ready => "",
            FfiDriveAccess::NotShared => "cloud_collab_err_not_shared",
            FfiDriveAccess::ReadOnly => "cloud_collab_err_read_only",
            FfiDriveAccess::ContentsHidden => "cloud_collab_err_contents_hidden",
            FfiDriveAccess::Retry => "cloud_collab_err_retry",
            FfiDriveAccess::Reauth => "cloud_collab_err_reauth",
        }
        .to_string(),
    };
    match provider(http, &folder_id).probe_folder(&folder_id) {
        Ok(p) => {
            let access = classify_probe(p.can_add_children, p.visible_files, expected_min_files);
            verdict(access, p.name, p.visible_files)
        }
        Err(SyncError::NotFound(_)) => verdict(FfiDriveAccess::NotShared, String::new(), 0),
        Err(SyncError::PermissionDenied(_)) => verdict(FfiDriveAccess::Reauth, String::new(), 0),
        Err(SyncError::Backend(detail)) if detail.contains("404") => {
            verdict(FfiDriveAccess::NotShared, String::new(), 0)
        }
        Err(_) => verdict(FfiDriveAccess::Retry, String::new(), 0),
    }
}

fn classify_probe(can_add: bool, visible: u32, expected_min: u32) -> FfiDriveAccess {
    if !can_add {
        FfiDriveAccess::ReadOnly
    } else if expected_min > 0 && visible < expected_min {
        FfiDriveAccess::ContentsHidden
    } else {
        FfiDriveAccess::Ready
    }
}

// ---- 協作憑證（drive.file）與挑選器 --------------------------------------------

/// 協作憑證的授權網址。
///
/// - `pick_folder_id` 為空：一般授權（房主建立資料夾用）。
/// - 有值：Google 的**桌面／行動版挑選器**（`trigger_onepick=true`），預選邀請裡的資料夾，
///   使用者在同一個畫面裡登入、同意、確認選取。回呼網址帶 `picked_file_ids`。
///
/// 挑選器的規定：只能要 `drive.file` 一個權限，所以這是**另一組憑證**，
/// 與主帳號的 `drive.appdata` 分開存放。
#[uniffi::export]
pub fn oauth_collab_authorize_url(
    platform: FfiOAuthPlatform,
    code_challenge: String,
    state: String,
    login_hint: String,
    pick_folder_id: String,
) -> String {
    let mut params = vec![
        ("client_id", oauth_client_id(platform)),
        ("redirect_uri", oauth_redirect_uri(platform)),
        ("response_type", "code".to_string()),
        ("scope", DRIVE_FILE_SCOPE.to_string()),
        ("code_challenge", code_challenge),
        ("code_challenge_method", "S256".to_string()),
        ("state", state),
        ("access_type", "offline".to_string()),
        ("prompt", "consent".to_string()),
    ];
    if !pick_folder_id.is_empty() {
        params.push(("trigger_onepick", "true".to_string()));
        params.push(("allow_folder_selection", "true".to_string()));
        params.push(("file_ids", pick_folder_id));
    }
    if !login_hint.is_empty() {
        params.push(("login_hint", login_hint));
    }
    format!(
        "https://accounts.google.com/o/oauth2/v2/auth?{}",
        encode_form(&params)
    )
}

/// 回呼網址裡挑選器選中的檔案 id（逗號分隔）。沒有就是空陣列。
#[uniffi::export]
pub fn oauth_parse_picked_ids(url: String) -> Vec<String> {
    let query = url.split_once('?').map(|(_, q)| q).unwrap_or("");
    let query = query.split('#').next().unwrap_or("");
    query
        .split('&')
        .filter_map(|pair| pair.split_once('='))
        .filter(|(k, _)| *k == "picked_file_ids")
        .flat_map(|(_, v)| {
            percent_decode(v)
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect::<Vec<_>>()
        })
        .collect()
}

// ---- 邀請連結 v2：一條連結涵蓋所有連線方式 ------------------------------------

#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiCollabInviteV2 {
    pub room_id: String,
    /// 端對端金鑰（base64）。也用來加密共享資料夾裡的事件檔。
    pub key_base64: String,
    /// 區網、Tailscale、自架中繼……依房主那邊的建議順序。客端會再依自己的網路重排。
    pub servers: Vec<String>,
    /// 共享的筆記本 id（雲端協作）。空字串＝只有即時協同、沒有雲端資料夾。
    pub notebook_id: String,
    /// 房主雲端硬碟裡的協作資料夾 id。
    pub drive_folder_id: String,
    /// 筆記本名稱（顯示用）。
    pub title: String,
    /// 房主宣告的檔案數下限，給權限探測用。
    pub min_files: u32,
}

fn query_escape(v: &str) -> String {
    let mut out = String::new();
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

/// 一條邀請連結：`kairumo://collab?room=…&server=…&server=…&nb=…&drive=…&title=…&n=…#key=…`。
///
/// 第一個 `server=` 與舊版相同位置，舊版 App 照樣讀得到（只是只會試那一個）。
#[uniffi::export]
pub fn collab_invite_link_v2(invite: FfiCollabInviteV2) -> String {
    if invite.room_id.is_empty() && invite.drive_folder_id.is_empty() {
        return String::new();
    }
    let mut q = vec![format!("room={}", query_escape(&invite.room_id))];
    for s in invite.servers.iter().filter(|s| !s.is_empty()) {
        q.push(format!("server={}", query_escape(s)));
    }
    if !invite.notebook_id.is_empty() {
        q.push(format!("nb={}", query_escape(&invite.notebook_id)));
    }
    if !invite.drive_folder_id.is_empty() {
        q.push(format!("drive={}", query_escape(&invite.drive_folder_id)));
    }
    if !invite.title.is_empty() {
        q.push(format!("title={}", query_escape(&invite.title)));
    }
    if invite.min_files > 0 {
        q.push(format!("n={}", invite.min_files));
    }
    let mut link = format!("kairumo://collab?{}", q.join("&"));
    if !invite.key_base64.is_empty() {
        link.push_str("#key=");
        link.push_str(&invite.key_base64);
    }
    link
}

/// 解析邀請連結（v1 與 v2 都認得）。認不得時 `room_id` 與 `drive_folder_id` 都是空的。
#[uniffi::export]
pub fn collab_parse_invite_v2(text: String) -> FfiCollabInviteV2 {
    let v1 = crate::ffi_collab::collab_parse_invite(text.clone());
    let cleaned = text.trim();
    let before_hash = cleaned.split('#').next().unwrap_or("");
    let query = before_hash.split_once('?').map(|(_, q)| q).unwrap_or("");
    let mut out = FfiCollabInviteV2 {
        room_id: String::new(),
        key_base64: v1.key_base64,
        servers: Vec::new(),
        notebook_id: String::new(),
        drive_folder_id: String::new(),
        title: String::new(),
        min_files: 0,
    };
    for (k, v) in query.split('&').filter_map(|p| p.split_once('=')) {
        let v = percent_decode(v);
        match k {
            "room" => out.room_id = v,
            "server" if !v.is_empty() && !out.servers.contains(&v) => out.servers.push(v),
            "nb" => out.notebook_id = v,
            "drive" => out.drive_folder_id = v,
            "title" => out.title = v,
            "n" => out.min_files = v.parse().unwrap_or(0),
            _ => {}
        }
    }
    if out.room_id.is_empty() && out.drive_folder_id.is_empty() {
        // 只有房號（舊版或手打的）：沿用 v1 的解析。
        out.room_id = v1.room_id;
    }
    out
}

/// 客端連線順序。同一個子網路（/24）的區網位址最先，其次其他區網、Tailscale（100.64/10），
/// 最後是自架的 `wss://`。每個位址最多等 [`COLLAB_CONNECT_TIMEOUT_MS`]，連上就停。
#[uniffi::export]
pub fn collab_order_servers(servers: Vec<String>, my_ipv4: Vec<String>) -> Vec<String> {
    fn host_of(url: &str) -> String {
        let rest = url.split("://").nth(1).unwrap_or(url);
        let host = rest.split(['/', '?', '#']).next().unwrap_or("");
        host.rsplit_once(':')
            .map(|(h, _)| h)
            .unwrap_or(host)
            .to_string()
    }
    fn prefix24(ip: &str) -> Option<String> {
        let parts: Vec<&str> = ip.split('.').collect();
        (parts.len() == 4).then(|| parts[..3].join("."))
    }
    let mine: Vec<String> = my_ipv4.iter().filter_map(|ip| prefix24(ip)).collect();
    let rank = |url: &str| -> u8 {
        let host = host_of(url);
        let octets: Vec<u8> = host.split('.').filter_map(|p| p.parse().ok()).collect();
        let is_v4 = octets.len() == 4;
        if is_v4 && prefix24(&host).is_some_and(|p| mine.contains(&p)) {
            0
        } else if is_v4
            && (octets[0] == 10
                || (octets[0] == 172 && (16..=31).contains(&octets[1]))
                || (octets[0] == 192 && octets[1] == 168))
        {
            1
        } else if is_v4 && octets[0] == 100 && (64..=127).contains(&octets[1]) {
            2
        } else if url.starts_with("wss://") {
            3
        } else {
            4
        }
    };
    let mut out: Vec<String> = Vec::new();
    for s in servers {
        if !s.is_empty() && !out.contains(&s) {
            out.push(s);
        }
    }
    out.sort_by_key(|s| rank(s));
    out
}

// ---- 自適應輪詢與合併送出 ------------------------------------------------------

/// 雲端協作的輪詢間隔（毫秒）。0 表示暫停。
///
/// - App 在背景：暫停（省電、省配額）。
/// - 區網中繼已連上：雲端只負責持久化，15 秒一次就夠。
/// - 最近 60 秒有人改過（遠端或本機）：2 秒。
/// - 5 分鐘內：5 秒。更久：20 秒。
#[uniffi::export]
pub fn collab_cloud_poll_ms(
    foreground: bool,
    relay_connected: bool,
    secs_since_remote_change: u32,
    secs_since_local_edit: u32,
) -> u32 {
    if !foreground {
        return 0;
    }
    if relay_connected {
        return 15_000;
    }
    let recent = secs_since_remote_change.min(secs_since_local_edit);
    match recent {
        0..=60 => 2_000,
        61..=300 => 5_000,
        _ => 20_000,
    }
}

/// 停筆後多久把累積的操作送上雲端（毫秒）。一筆一個檔的話，畫一段字就是幾十次上傳；
/// 停頓一下再送，一段落只要一兩個檔，對方也不會等太久。
#[uniffi::export]
pub fn collab_cloud_flush_delay_ms() -> u32 {
    600
}

// ---- 在場檔 --------------------------------------------------------------------

/// 一位參與者「現在在哪裡」。存在共享資料夾的 `presence/<device>.json`，每幾秒覆寫一次。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiCloudPresence {
    pub device_id: u32,
    pub user_name: String,
    pub color_hex: String,
    pub page_index: u32,
    /// 正在編輯的物件 id；沒有就是空字串。
    pub selected_id: String,
    pub updated_ms: u64,
}

/// 在場檔在資料夾裡的路徑。不在 `notebooks/` 底下，筆記同步不會碰到它。
#[uniffi::export]
pub fn collab_presence_path(device_id: u32) -> String {
    format!("presence/{device_id:08x}.json")
}

/// 多久寫一次在場檔（毫秒）。
#[uniffi::export]
pub fn collab_presence_interval_ms() -> u32 {
    5_000
}

/// 超過這麼久沒更新就當成離開（毫秒）。三個週期：漏一兩次上傳不會閃爍。
pub const PRESENCE_STALE_MS: u64 = 20_000;

#[uniffi::export]
pub fn collab_presence_encode(p: FfiCloudPresence) -> String {
    serde_json::json!({
        "v": 1,
        "device": p.device_id,
        "name": p.user_name,
        "color": p.color_hex,
        "page": p.page_index,
        "sel": p.selected_id,
        "t": p.updated_ms,
    })
    .to_string()
}

/// 解析一份在場檔。壞掉或過期（相對 `now_ms`）的回 `None`。
#[uniffi::export]
pub fn collab_presence_decode(json: String, now_ms: u64) -> Option<FfiCloudPresence> {
    let v: serde_json::Value = serde_json::from_str(&json).ok()?;
    let p = FfiCloudPresence {
        device_id: v.get("device")?.as_u64()? as u32,
        user_name: v
            .get("name")
            .and_then(|x| x.as_str())
            .unwrap_or_default()
            .to_string(),
        color_hex: v
            .get("color")
            .and_then(|x| x.as_str())
            .unwrap_or("#3478F6")
            .to_string(),
        page_index: v.get("page").and_then(|x| x.as_u64()).unwrap_or(0) as u32,
        selected_id: v
            .get("sel")
            .and_then(|x| x.as_str())
            .unwrap_or_default()
            .to_string(),
        updated_ms: v.get("t")?.as_u64()?,
    };
    (now_ms.saturating_sub(p.updated_ms) <= PRESENCE_STALE_MS).then_some(p)
}

// ---- 這台裝置上的共享筆記清單 --------------------------------------------------

/// 一本共享筆記在這台裝置上的記錄（平台把整份 JSON 存在設定檔範圍內）。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiSharedNotebook {
    pub notebook_id: String,
    pub folder_id: String,
    pub room_id: String,
    pub key_base64: String,
    /// `owner`（房主）或 `editor`（協作者）。
    pub role: String,
    pub title: String,
}

fn registry_from(json: &str) -> Vec<FfiSharedNotebook> {
    let v: serde_json::Value = serde_json::from_str(json).unwrap_or_default();
    v.as_array()
        .map(|list| {
            list.iter()
                .filter_map(|e| {
                    let s = |k: &str| {
                        e.get(k)
                            .and_then(|x| x.as_str())
                            .unwrap_or_default()
                            .to_string()
                    };
                    let nb = s("nb");
                    (!nb.is_empty()).then(|| FfiSharedNotebook {
                        notebook_id: nb,
                        folder_id: s("folder"),
                        room_id: s("room"),
                        key_base64: s("key"),
                        role: s("role"),
                        title: s("title"),
                    })
                })
                .collect()
        })
        .unwrap_or_default()
}

fn registry_to(list: &[FfiSharedNotebook]) -> String {
    serde_json::Value::Array(
        list.iter()
            .map(|e| {
                serde_json::json!({
                    "nb": e.notebook_id, "folder": e.folder_id, "room": e.room_id,
                    "key": e.key_base64, "role": e.role, "title": e.title,
                })
            })
            .collect(),
    )
    .to_string()
}

#[uniffi::export]
pub fn shared_registry_list(json: String) -> Vec<FfiSharedNotebook> {
    registry_from(&json)
}

/// 新增或更新（以筆記本 id 為鍵，不分大小寫）。回傳新的 JSON。
#[uniffi::export]
pub fn shared_registry_upsert(json: String, entry: FfiSharedNotebook) -> String {
    let mut list = registry_from(&json);
    let key = entry.notebook_id.to_lowercase();
    list.retain(|e| e.notebook_id.to_lowercase() != key);
    list.push(entry);
    registry_to(&list)
}

#[uniffi::export]
pub fn shared_registry_remove(json: String, notebook_id: String) -> String {
    let mut list = registry_from(&json);
    let key = notebook_id.to_lowercase();
    list.retain(|e| e.notebook_id.to_lowercase() != key);
    registry_to(&list)
}

#[uniffi::export]
pub fn shared_registry_find(json: String, notebook_id: String) -> Option<FfiSharedNotebook> {
    let key = notebook_id.to_lowercase();
    registry_from(&json)
        .into_iter()
        .find(|e| e.notebook_id.to_lowercase() == key)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> FfiCollabInviteV2 {
        FfiCollabInviteV2 {
            room_id: "kairumo-db5a57".into(),
            key_base64: "a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2V5a2U=".into(),
            servers: vec![
                "ws://100.73.43.39:9002".into(),
                "ws://192.168.68.55:9002".into(),
            ],
            notebook_id: "NB-1".into(),
            drive_folder_id: "1AbC_d-E".into(),
            title: "111 年度 員工 & 認股".into(),
            min_files: 12,
        }
    }

    #[test]
    fn invite_v2_round_trips_and_stays_v1_readable() {
        let link = collab_invite_link_v2(sample());
        let back = collab_parse_invite_v2(link.clone());
        assert_eq!(back.room_id, "kairumo-db5a57");
        assert_eq!(back.servers.len(), 2);
        assert_eq!(back.notebook_id, "NB-1");
        assert_eq!(back.drive_folder_id, "1AbC_d-E");
        assert_eq!(back.title, "111 年度 員工 & 認股");
        assert_eq!(back.min_files, 12);
        // 舊版只認 room 與 #key。
        let v1 = crate::ffi_collab::collab_parse_invite(link);
        assert_eq!(v1.room_id, "kairumo-db5a57");
    }

    #[test]
    fn plain_v1_links_still_parse() {
        let v = collab_parse_invite_v2("kairumo://collab?room=abc".into());
        assert_eq!(v.room_id, "abc");
        assert!(v.servers.is_empty());
        assert_eq!(collab_parse_invite_v2("abc".into()).room_id, "abc");
    }

    #[test]
    fn servers_are_ordered_by_reachability() {
        let order = collab_order_servers(
            vec![
                "wss://relay.example.com".into(),
                "ws://100.73.43.39:9002".into(),
                "ws://10.0.0.5:9002".into(),
                "ws://192.168.68.55:9002".into(),
            ],
            vec!["192.168.68.20".into()],
        );
        assert_eq!(order[0], "ws://192.168.68.55:9002");
        assert_eq!(order[1], "ws://10.0.0.5:9002");
        assert_eq!(order[2], "ws://100.73.43.39:9002");
        assert_eq!(order[3], "wss://relay.example.com");
    }

    #[test]
    fn polling_adapts_to_activity() {
        assert_eq!(collab_cloud_poll_ms(false, false, 0, 0), 0);
        assert_eq!(collab_cloud_poll_ms(true, true, 0, 0), 15_000);
        assert_eq!(collab_cloud_poll_ms(true, false, 10, 999), 2_000);
        assert_eq!(collab_cloud_poll_ms(true, false, 999, 120), 5_000);
        assert_eq!(collab_cloud_poll_ms(true, false, 999, 999), 20_000);
    }

    #[test]
    fn presence_expires() {
        let p = FfiCloudPresence {
            device_id: 0xabc,
            user_name: "A".into(),
            color_hex: "#FF0000".into(),
            page_index: 2,
            selected_id: "obj".into(),
            updated_ms: 1_000_000,
        };
        let json = collab_presence_encode(p.clone());
        assert_eq!(collab_presence_decode(json.clone(), 1_005_000), Some(p));
        assert_eq!(
            collab_presence_decode(json, 1_000_000 + PRESENCE_STALE_MS + 1),
            None
        );
        assert_eq!(collab_presence_path(0xabc), "presence/00000abc.json");
    }

    #[test]
    fn registry_upserts_by_notebook() {
        let e = |nb: &str, role: &str| FfiSharedNotebook {
            notebook_id: nb.into(),
            folder_id: "f".into(),
            room_id: "r".into(),
            key_base64: String::new(),
            role: role.into(),
            title: "t".into(),
        };
        let j = shared_registry_upsert(String::new(), e("A", "owner"));
        let j = shared_registry_upsert(j, e("a", "editor"));
        let j = shared_registry_upsert(j, e("B", "owner"));
        assert_eq!(shared_registry_list(j.clone()).len(), 2);
        assert_eq!(
            shared_registry_find(j.clone(), "A".into()).unwrap().role,
            "editor"
        );
        assert_eq!(
            shared_registry_list(shared_registry_remove(j, "b".into())).len(),
            1
        );
    }

    #[test]
    fn picker_url_and_callback() {
        let url = oauth_collab_authorize_url(
            FfiOAuthPlatform::Apple,
            "ch".into(),
            "st".into(),
            String::new(),
            "FOLDER1".into(),
        );
        assert!(url.contains("trigger_onepick=true"));
        assert!(url.contains("file_ids=FOLDER1"));
        assert!(url.contains("drive.file"));
        assert!(!url.contains("drive.appdata"));
        let ids = oauth_parse_picked_ids("app:/cb?code=x&picked_file_ids=a%2Cb&state=s".into());
        assert_eq!(ids, vec!["a".to_string(), "b".to_string()]);
    }

    #[test]
    fn probe_classification() {
        assert_eq!(classify_probe(false, 9, 1), FfiDriveAccess::ReadOnly);
        assert_eq!(classify_probe(true, 0, 5), FfiDriveAccess::ContentsHidden);
        assert_eq!(classify_probe(true, 5, 5), FfiDriveAccess::Ready);
        assert!(collab_email_looks_valid("a@b.co".into()));
        assert!(!collab_email_looks_valid("a@b".into()));
        assert!(!collab_email_looks_valid("a b@c.d".into()));
    }
}

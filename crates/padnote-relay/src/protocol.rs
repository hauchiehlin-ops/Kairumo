//! 即時協同中繼服務通訊協定（Phase 1）。

use serde::{Deserialize, Serialize};

/// 游標與筆尖即時狀態（純記憶體暫態，不寫入硬碟）。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CursorState {
    pub x: f32,
    pub y: f32,
    pub is_drawing: bool,
    pub tool: String,
}

/// 協同成員資訊。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PeerInfo {
    pub user_id: String,
    pub user_name: String,
    pub user_color: String,
    pub role: String,
}

/// 客戶端發送至中繼伺服器的訊息。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    /// 申請加入指定房間
    Join {
        room_id: String,
        user_id: String,
        user_name: String,
        user_color: String,
        role: String,
        #[serde(default)]
        passcode: Option<String>,
    },
    /// 廣播即時游標與懸停暫態（高頻率，每秒 30~60 次）
    Presence {
        room_id: String,
        user_id: String,
        cursor: CursorState,
        #[serde(default)]
        selected_id: Option<String>,
    },
    /// 廣播持久化 CRDT 操作（落筆完成之筆劃、卡片物件、刪除墓碑等）
    Oplog {
        room_id: String,
        user_id: String,
        lamport: u64,
        kind: String,
        #[serde(default)]
        encrypted: Option<bool>,
        payload: serde_json::Value,
    },
    /// 請求補發指定 Lamport 時鐘之後的遺漏 Oplog（斷線重連自我修復）
    Catchup {
        room_id: String,
        last_lamport: u64,
    },
    /// 離開房間
    Leave {
        room_id: String,
        user_id: String,
    },
    /// 房主關閉房間並結束協同會議
    CloseRoom {
        room_id: String,
        user_id: String,
    },
    /// 心跳 Ping
    Ping,
}

/// 中繼伺服器發送給客戶端的訊息。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    /// 加入成功確認，帶有目前在線成員清單
    Joined {
        room_id: String,
        user_id: String,
        role: String,
        peers: Vec<PeerInfo>,
    },
    /// 有新成員加入廣播
    PeerJoined {
        room_id: String,
        peer: PeerInfo,
    },
    /// 轉發成員的即時游標動態
    PeerPresence {
        room_id: String,
        user_id: String,
        cursor: CursorState,
        #[serde(default)]
        selected_id: Option<String>,
    },
    /// 轉發成員的 CRDT 筆劃 / 物件增量
    PeerOplog {
        room_id: String,
        user_id: String,
        lamport: u64,
        kind: String,
        #[serde(default)]
        encrypted: Option<bool>,
        payload: serde_json::Value,
    },
    /// 批次補發 Oplog（重連追趕）
    OplogBatch {
        room_id: String,
        oplogs: Vec<ServerMessage>,
    },
    /// 成員離開或斷線廣播
    PeerLeft {
        room_id: String,
        user_id: String,
    },
    /// 房間已被房主關閉
    RoomClosed {
        room_id: String,
        reason: String,
    },
    /// 錯誤提示
    Error {
        code: String,
        message: String,
    },
    /// 心跳 Pong
    Pong,
}

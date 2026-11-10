//! 房間與連線集線器（RoomHub）。
//!
//! 管理所有活躍的協同房間、在線成員連線通道與高頻廣播。

use crate::protocol::{ClientMessage, CursorState, PeerInfo, ServerMessage};
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;
use tokio::sync::{RwLock, mpsc};

/// 單一在線成員狀態。
#[derive(Debug)]
pub struct Peer {
    pub info: PeerInfo,
    pub sender: mpsc::UnboundedSender<ServerMessage>,
}

/// 單一協同房間。
#[derive(Debug)]
pub struct Room {
    pub id: String,
    pub owner_id: String,
    pub passcode: Option<String>,
    pub peers: HashMap<String, Peer>,
    pub recent_oplogs: VecDeque<ServerMessage>,
    /// 下一個要配發的序號。
    pub next_seq: u64,
    /// 暫存裡各操作的大約位元組數（與 `recent_oplogs` 一一對應），用來限制總量。
    recent_sizes: VecDeque<usize>,
    recent_bytes: usize,
}

/// 暫存上限：筆數與總位元組數，先到者為準。新圖片整張帶在操作裡，只限筆數的話
/// 幾十張照片就能把中繼的記憶體吃光。
pub const RECENT_MAX_COUNT: usize = 2000;
pub const RECENT_MAX_BYTES: usize = 32 * 1024 * 1024;

/// 只轉送、不暫存的操作種類：整份狀態的請求與回覆（設計 §7）—— 它們只對當下在線的人有意義，
/// 而且一份快照可能比整個暫存還大。
pub fn is_transient_kind(kind: &str) -> bool {
    // `live_`：書寫中的預覽點（`live_ink`），提筆後由正式筆畫取代；補發過時的預覽沒有意義。
    kind.starts_with("state_") || kind.starts_with("live_")
}

impl Room {
    pub fn new(id: String, owner_id: String, passcode: Option<String>) -> Self {
        Self {
            id,
            owner_id,
            passcode,
            peers: HashMap::new(),
            recent_oplogs: VecDeque::new(),
            next_seq: 1,
            recent_sizes: VecDeque::new(),
            recent_bytes: 0,
        }
    }

    /// 存進暫存，超過上限時從最舊的丟起。
    fn remember(&mut self, msg: ServerMessage, size: usize) {
        self.recent_oplogs.push_back(msg);
        self.recent_sizes.push_back(size);
        self.recent_bytes += size;
        while self.recent_oplogs.len() > RECENT_MAX_COUNT
            || (self.recent_bytes > RECENT_MAX_BYTES && self.recent_oplogs.len() > 1)
        {
            self.recent_oplogs.pop_front();
            if let Some(gone) = self.recent_sizes.pop_front() {
                self.recent_bytes -= gone;
            }
        }
    }

    /// 暫存裡最舊那一筆的序號（沒有就是下一個要配發的）。
    fn oldest_seq(&self) -> u64 {
        self.recent_oplogs
            .front()
            .and_then(|m| match m {
                ServerMessage::PeerOplog { seq, .. } => *seq,
                _ => None,
            })
            .unwrap_or(self.next_seq)
    }

    pub fn peer_infos(&self) -> Vec<PeerInfo> {
        self.peers.values().map(|p| p.info.clone()).collect()
    }
}

/// 房間人數已滿時 [`RoomHub::join`] 回的錯誤。連線層看到它就回 `ROOM_FULL` 代碼（App 依代碼顯示在地化提示）。
pub const ROOM_FULL_ERROR: &str = "這個房間的人數已達上限";

/// App 內建的本機中繼每間房的人數上限（與 Cloudflare 版的預設 `MAX_PEERS` 相同）。
pub const IN_APP_MAX_PEERS: usize = 50;

/// 公開中繼的防護設定。App 內建的本機中繼用 [`RelayLimits::default`]（不設上限，行為與以前相同）；
/// 放在公開網路上的中繼由 `main.rs` 依環境變數設定。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct RelayLimits {
    /// 同時存在的房間數上限。0 = 不限。
    pub max_rooms: usize,
    /// 每間房的人數上限。0 = 不限。
    pub max_peers_per_room: usize,
    /// 多久沒收到任何訊息就斷開（秒）。0 = 不限。客戶端每 20 秒送一次心跳。
    pub idle_timeout_secs: u64,
}

/// 集中式房間中繼集線器。
#[derive(Clone, Debug, Default)]
pub struct RoomHub {
    rooms: Arc<RwLock<HashMap<String, Room>>>,
    limits: RelayLimits,
}

impl RoomHub {
    pub fn new() -> Self {
        Self::with_limits(RelayLimits::default())
    }

    pub fn with_limits(limits: RelayLimits) -> Self {
        Self {
            rooms: Arc::new(RwLock::new(HashMap::new())),
            limits,
        }
    }

    pub fn limits(&self) -> RelayLimits {
        self.limits
    }

    /// 成員申請加入房間。若房間不存在，則第一位加入者自動成為房主 (Owner)。
    // 參數量由連線協定決定，包成 struct 只是把同樣的欄位換個地方寫，
    // 反而讓呼叫端與 protocol.rs 的對應變難追。
    #[allow(clippy::too_many_arguments)]
    pub async fn join(
        &self,
        room_id: String,
        user_id: String,
        user_name: String,
        user_color: String,
        requested_role: String,
        passcode: Option<String>,
        tx: mpsc::UnboundedSender<ServerMessage>,
    ) -> Result<ServerMessage, String> {
        let mut rooms = self.rooms.write().await;
        if self.limits.max_rooms > 0
            && !rooms.contains_key(&room_id)
            && rooms.len() >= self.limits.max_rooms
        {
            return Err("中繼的房間數已達上限，請稍後再試".to_string());
        }
        let room = rooms
            .entry(room_id.clone())
            .or_insert_with(|| Room::new(room_id.clone(), user_id.clone(), passcode.clone()));
        if self.limits.max_peers_per_room > 0
            && !room.peers.contains_key(&user_id)
            && room.peers.len() >= self.limits.max_peers_per_room
        {
            return Err(ROOM_FULL_ERROR.to_string());
        }

        // 密碼檢查（若有設置）
        if let Some(ref required_passcode) = room.passcode
            && passcode.as_ref() != Some(required_passcode)
            && room.owner_id != user_id
        {
            return Err("密碼錯誤，無法加入房間".to_string());
        }

        let actual_role = if room.owner_id == user_id {
            "owner".to_string()
        } else {
            requested_role
        };

        let peer_info = PeerInfo {
            user_id: user_id.clone(),
            user_name,
            user_color,
            role: actual_role.clone(),
        };

        // 廣播給其他房間成員
        let join_notify = ServerMessage::PeerJoined {
            room_id: room_id.clone(),
            peer: peer_info.clone(),
        };
        for (pid, peer) in &room.peers {
            if pid != &user_id {
                let _ = peer.sender.send(join_notify.clone());
            }
        }

        let existing_peers = room.peer_infos();
        room.peers.insert(
            user_id.clone(),
            Peer {
                info: peer_info,
                sender: tx,
            },
        );

        Ok(ServerMessage::Joined {
            room_id,
            user_id,
            role: actual_role,
            peers: existing_peers,
        })
    }

    /// 廣播高頻游標狀態（記憶體即時轉發）。
    pub async fn broadcast_presence(
        &self,
        room_id: &str,
        user_id: &str,
        cursor: CursorState,
        selected_id: Option<String>,
    ) {
        let rooms = self.rooms.read().await;
        if let Some(room) = rooms.get(room_id) {
            let msg = ServerMessage::PeerPresence {
                room_id: room_id.to_string(),
                user_id: user_id.to_string(),
                cursor,
                selected_id,
            };
            for (pid, peer) in &room.peers {
                if pid != user_id {
                    let _ = peer.sender.send(msg.clone());
                }
            }
        }
    }

    /// 廣播持久化 CRDT Oplog，並存入房間環形快取中以供斷線補發。
    pub async fn broadcast_oplog(
        &self,
        room_id: &str,
        user_id: &str,
        lamport: u64,
        kind: String,
        encrypted: Option<bool>,
        payload: serde_json::Value,
    ) {
        let mut rooms = self.rooms.write().await;
        if let Some(room) = rooms.get_mut(room_id) {
            let transient = is_transient_kind(&kind);
            let seq = if transient {
                None
            } else {
                let s = room.next_seq;
                room.next_seq += 1;
                Some(s)
            };
            let size = if transient {
                0
            } else {
                payload.to_string().len() + kind.len() + 64
            };
            let msg = ServerMessage::PeerOplog {
                room_id: room_id.to_string(),
                user_id: user_id.to_string(),
                lamport,
                kind,
                encrypted,
                payload,
                seq,
            };
            if !transient {
                room.remember(msg.clone(), size);
            }

            for (pid, peer) in &room.peers {
                if pid != user_id {
                    let _ = peer.sender.send(msg.clone());
                }
            }
        }
    }

    /// 補發序號 `last_seq` 之後的操作。回傳 `(操作, 是否不完整)` ——
    /// 要補的那一段已經被擠出暫存時「不完整」，客戶端要向其他成員要整份狀態。
    pub async fn catchup_since_seq(
        &self,
        room_id: &str,
        last_seq: u64,
    ) -> (Vec<ServerMessage>, bool) {
        let rooms = self.rooms.read().await;
        let Some(room) = rooms.get(room_id) else {
            // 房間不在了（所有人都離開過）：沒有東西可補，也沒有人能給快照。
            return (Vec::new(), false);
        };
        let missing = room
            .recent_oplogs
            .iter()
            .filter(|m| matches!(m, ServerMessage::PeerOplog { seq: Some(s), .. } if *s > last_seq))
            .cloned()
            .collect();
        (missing, room.oldest_seq() > last_seq + 1)
    }

    /// 取得指定房間在 last_lamport 之後的所有遺漏 Oplog（舊版客戶端的斷線追趕補發）
    pub async fn catchup(&self, room_id: &str, last_lamport: u64) -> Vec<ServerMessage> {
        let rooms = self.rooms.read().await;
        if let Some(room) = rooms.get(room_id) {
            room.recent_oplogs
                .iter()
                .filter(|msg| {
                    if let ServerMessage::PeerOplog { lamport, .. } = msg {
                        *lamport > last_lamport
                    } else {
                        false
                    }
                })
                .cloned()
                .collect()
        } else {
            Vec::new()
        }
    }

    /// 成員離開房間。若房間已無人，自動回收房間釋放記憶體。
    pub async fn leave(&self, room_id: &str, user_id: &str) {
        let mut rooms = self.rooms.write().await;
        if let Some(room) = rooms.get_mut(room_id) {
            room.peers.remove(user_id);
            let notify = ServerMessage::PeerLeft {
                room_id: room_id.to_string(),
                user_id: user_id.to_string(),
            };
            for peer in room.peers.values() {
                let _ = peer.sender.send(notify.clone());
            }

            if room.peers.is_empty() {
                rooms.remove(room_id);
            }
        }
    }

    /// 房主關閉房間。
    pub async fn close_room(&self, room_id: &str, user_id: &str) -> Result<(), String> {
        let mut rooms = self.rooms.write().await;
        if let Some(room) = rooms.get_mut(room_id) {
            if room.owner_id != user_id {
                return Err("僅房主有權關閉此房間".to_string());
            }

            let notify = ServerMessage::RoomClosed {
                room_id: room_id.to_string(),
                reason: "房主已結束本次線上協同會議".to_string(),
            };
            for peer in room.peers.values() {
                let _ = peer.sender.send(notify.clone());
            }
            rooms.remove(room_id);
            Ok(())
        } else {
            Err("房間不存在".to_string())
        }
    }

    /// 取得目前在線房間數。
    pub async fn room_count(&self) -> usize {
        self.rooms.read().await.len()
    }

    /// 取得指定房間在線人數。
    pub async fn peer_count(&self, room_id: &str) -> usize {
        self.rooms
            .read()
            .await
            .get(room_id)
            .map(|r| r.peers.len())
            .unwrap_or(0)
    }

    /// 處理接收到的單一客戶端訊息。
    pub async fn handle_message(
        &self,
        msg: ClientMessage,
        current_room: &mut Option<String>,
        current_user: &mut Option<String>,
        tx: &mpsc::UnboundedSender<ServerMessage>,
    ) -> Option<ServerMessage> {
        // 加入之後的每一則訊息都只能作用在**這條連線加入的那個房間、以那個身分**。
        // 以前直接信任訊息裡寫的房號與使用者 id：任何連線都能把訊息送進別的房間、冒用別人離開。
        // 內建在 App 裡的本機中繼只有區網的人連得到，公開中繼就不行。
        let bound = |room_id: &str, user_id: &str| {
            current_room.as_deref() == Some(room_id) && current_user.as_deref() == Some(user_id)
        };
        match &msg {
            ClientMessage::Presence {
                room_id, user_id, ..
            }
            | ClientMessage::Oplog {
                room_id, user_id, ..
            }
            | ClientMessage::Leave { room_id, user_id }
            | ClientMessage::CloseRoom { room_id, user_id }
                if !bound(room_id, user_id) =>
            {
                return None;
            }
            ClientMessage::Catchup { room_id, .. } if current_room.as_deref() != Some(room_id) => {
                return None;
            }
            _ => {}
        }
        match msg {
            ClientMessage::Join {
                room_id,
                user_id,
                user_name,
                user_color,
                role,
                passcode,
            } => {
                // 換房間：先離開原本那一間（同一條連線不會同時在兩個房間）。
                if let (Some(old_room), Some(old_user)) =
                    (current_room.clone(), current_user.clone())
                    && (old_room != room_id || old_user != user_id)
                {
                    self.leave(&old_room, &old_user).await;
                }
                *current_room = Some(room_id.clone());
                *current_user = Some(user_id.clone());
                match self
                    .join(
                        room_id,
                        user_id,
                        user_name,
                        user_color,
                        role,
                        passcode,
                        tx.clone(),
                    )
                    .await
                {
                    Ok(resp) => Some(resp),
                    Err(err) => {
                        // 沒加入成功：這條連線不屬於任何房間。
                        *current_room = None;
                        *current_user = None;
                        let code = if err == ROOM_FULL_ERROR {
                            "ROOM_FULL"
                        } else {
                            "JOIN_FAILED"
                        };
                        Some(ServerMessage::Error {
                            code: code.to_string(),
                            message: err,
                        })
                    }
                }
            }
            ClientMessage::Presence {
                room_id,
                user_id,
                cursor,
                selected_id,
            } => {
                self.broadcast_presence(&room_id, &user_id, cursor, selected_id)
                    .await;
                None
            }
            ClientMessage::Oplog {
                room_id,
                user_id,
                lamport,
                kind,
                encrypted,
                payload,
            } => {
                self.broadcast_oplog(&room_id, &user_id, lamport, kind, encrypted, payload)
                    .await;
                None
            }
            ClientMessage::Catchup {
                room_id,
                last_lamport,
                last_seq,
            } => match last_seq {
                Some(seq) => {
                    let (missing, truncated) = self.catchup_since_seq(&room_id, seq).await;
                    Some(ServerMessage::OplogBatch {
                        room_id,
                        oplogs: missing,
                        truncated: Some(truncated),
                    })
                }
                None => {
                    let missing = self.catchup(&room_id, last_lamport).await;
                    Some(ServerMessage::OplogBatch {
                        room_id,
                        oplogs: missing,
                        truncated: None,
                    })
                }
            },
            ClientMessage::Leave { room_id, user_id } => {
                self.leave(&room_id, &user_id).await;
                *current_room = None;
                *current_user = None;
                None
            }
            ClientMessage::CloseRoom { room_id, user_id } => {
                if let Err(err) = self.close_room(&room_id, &user_id).await {
                    Some(ServerMessage::Error {
                        code: "CLOSE_FAILED".to_string(),
                        message: err,
                    })
                } else {
                    *current_room = None;
                    *current_user = None;
                    None
                }
            }
            ClientMessage::Ping => Some(ServerMessage::Pong),
        }
    }
}

#[cfg(test)]
mod transient_tests {
    use super::*;

    #[test]
    fn live_and_state_kinds_are_not_replayed() {
        assert!(is_transient_kind("state_request"));
        assert!(is_transient_kind("live_ink"));
        assert!(!is_transient_kind("ink_add"));
        assert!(!is_transient_kind("obj_patch"));
    }

    fn join_msg(room: &str, user: &str) -> ClientMessage {
        ClientMessage::Join {
            room_id: room.into(),
            user_id: user.into(),
            user_name: user.into(),
            user_color: "#000".into(),
            role: "editor".into(),
            passcode: None,
        }
    }

    #[tokio::test]
    async fn messages_only_act_on_the_joined_room() {
        let hub = RoomHub::new();
        let (tx_a, _rx_a) = mpsc::unbounded_channel();
        let (tx_b, mut rx_b) = mpsc::unbounded_channel();
        let (mut room_a, mut user_a) = (None, None);
        let (mut room_b, mut user_b) = (None, None);
        hub.handle_message(join_msg("secret", "b"), &mut room_b, &mut user_b, &tx_b)
            .await;
        hub.handle_message(join_msg("other", "a"), &mut room_a, &mut user_a, &tx_a)
            .await;
        // a 沒加入 "secret"，送不進去。
        let forged = ClientMessage::Oplog {
            room_id: "secret".into(),
            user_id: "a".into(),
            lamport: 1,
            kind: "obj_patch".into(),
            encrypted: None,
            payload: serde_json::json!({}),
        };
        hub.handle_message(forged, &mut room_a, &mut user_a, &tx_a)
            .await;
        assert!(rx_b.try_recv().is_err(), "別的房間的連線送不進來");
        // 冒用 b 離開也不行。
        let leave = ClientMessage::Leave {
            room_id: "secret".into(),
            user_id: "b".into(),
        };
        hub.handle_message(leave, &mut room_a, &mut user_a, &tx_a)
            .await;
        assert_eq!(hub.peer_count("secret").await, 1);
    }

    #[tokio::test]
    async fn limits_cap_rooms_and_peers() {
        let hub = RoomHub::with_limits(RelayLimits {
            max_rooms: 1,
            max_peers_per_room: 2,
            idle_timeout_secs: 0,
        });
        let tx = || mpsc::unbounded_channel::<ServerMessage>().0;
        let join = |room: &str, user: &str| {
            hub.join(
                room.into(),
                user.into(),
                user.into(),
                "#000".into(),
                "editor".into(),
                None,
                tx(),
            )
        };
        assert!(join("r1", "u1").await.is_ok());
        assert!(join("r1", "u2").await.is_ok());
        assert!(join("r1", "u3").await.is_err(), "第三人超過每房上限");
        assert!(join("r1", "u2").await.is_ok(), "同一人重連不算新增");
        assert!(join("r2", "u4").await.is_err(), "房間數已達上限");
    }
}

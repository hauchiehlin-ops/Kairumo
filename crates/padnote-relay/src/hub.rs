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
    kind.starts_with("state_")
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

/// 集中式房間中繼集線器。
#[derive(Clone, Debug, Default)]
pub struct RoomHub {
    rooms: Arc<RwLock<HashMap<String, Room>>>,
}

impl RoomHub {
    pub fn new() -> Self {
        Self {
            rooms: Arc::new(RwLock::new(HashMap::new())),
        }
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
        let room = rooms
            .entry(room_id.clone())
            .or_insert_with(|| Room::new(room_id.clone(), user_id.clone(), passcode.clone()));

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
        match msg {
            ClientMessage::Join {
                room_id,
                user_id,
                user_name,
                user_color,
                role,
                passcode,
            } => {
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
                    Err(err) => Some(ServerMessage::Error {
                        code: "JOIN_FAILED".to_string(),
                        message: err,
                    }),
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

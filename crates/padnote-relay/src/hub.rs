//! 房間與連線集線器（RoomHub）。
//!
//! 管理所有活躍的協同房間、在線成員連線通道與高頻廣播。

use crate::protocol::{ClientMessage, CursorState, PeerInfo, ServerMessage};
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;
use tokio::sync::{mpsc, RwLock};

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
}

impl Room {
    pub fn new(id: String, owner_id: String, passcode: Option<String>) -> Self {
        Self {
            id,
            owner_id,
            passcode,
            peers: HashMap::new(),
            recent_oplogs: VecDeque::with_capacity(200),
        }
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
        let room = rooms.entry(room_id.clone()).or_insert_with(|| {
            Room::new(room_id.clone(), user_id.clone(), passcode.clone())
        });

        // 密碼檢查（若有設置）
        if let Some(ref required_passcode) = room.passcode {
            if passcode.as_ref() != Some(required_passcode) && room.owner_id != user_id {
                return Err("密碼錯誤，無法加入房間".to_string());
            }
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
            let msg = ServerMessage::PeerOplog {
                room_id: room_id.to_string(),
                user_id: user_id.to_string(),
                lamport,
                kind,
                encrypted,
                payload,
            };
            if room.recent_oplogs.len() >= 200 {
                room.recent_oplogs.pop_front();
            }
            room.recent_oplogs.push_back(msg.clone());

            for (pid, peer) in &room.peers {
                if pid != user_id {
                    let _ = peer.sender.send(msg.clone());
                }
            }
        }
    }

    /// 取得指定房間在 last_lamport 之後的所有遺漏 Oplog（斷線追趕補發）
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
            } => {
                let missing = self.catchup(&room_id, last_lamport).await;
                Some(ServerMessage::OplogBatch {
                    room_id,
                    oplogs: missing,
                })
            }
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

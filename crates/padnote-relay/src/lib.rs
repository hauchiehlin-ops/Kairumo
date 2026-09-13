//! Padnote 線上多人即時協同中繼核心函式庫。

pub mod hub;
pub mod protocol;
pub mod server;

pub use hub::RoomHub;
pub use protocol::{ClientMessage, CursorState, PeerInfo, ServerMessage};
pub use server::{bind, run_server, serve};

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::mpsc;

    #[tokio::test]
    async fn test_room_join_and_presence_flow() {
        let hub = RoomHub::new();
        let (tx1, mut rx1) = mpsc::unbounded_channel();
        let (tx2, _rx2) = mpsc::unbounded_channel();

        // 用戶 1 建立房間（自動成為 Owner）
        let resp1 = hub
            .join(
                "room-101".to_string(),
                "user-1".to_string(),
                "Alice".to_string(),
                "#FF0000".to_string(),
                "owner".to_string(),
                None,
                tx1,
            )
            .await
            .expect("Alice joins successfully");

        if let ServerMessage::Joined {
            room_id,
            user_id,
            role,
            peers,
        } = resp1
        {
            assert_eq!(room_id, "room-101");
            assert_eq!(user_id, "user-1");
            assert_eq!(role, "owner");
            assert!(peers.is_empty());
        } else {
            panic!("Expected Joined response");
        }

        // 用戶 2 加入房間
        let resp2 = hub
            .join(
                "room-101".to_string(),
                "user-2".to_string(),
                "Bob".to_string(),
                "#0000FF".to_string(),
                "editor".to_string(),
                None,
                tx2,
            )
            .await
            .expect("Bob joins successfully");

        if let ServerMessage::Joined { peers, .. } = resp2 {
            assert_eq!(peers.len(), 1);
            assert_eq!(peers[0].user_name, "Alice");
        } else {
            panic!("Expected Joined response with Alice as existing peer");
        }

        // 用戶 1 應收到 PeerJoined 廣播通知
        let notify1 = rx1.recv().await.expect("Alice receives notification");
        if let ServerMessage::PeerJoined { peer, .. } = notify1 {
            assert_eq!(peer.user_name, "Bob");
            assert_eq!(peer.role, "editor");
        } else {
            panic!("Expected PeerJoined notification");
        }

        // 用戶 2 廣播游標暫態
        hub.broadcast_presence(
            "room-101",
            "user-2",
            CursorState {
                x: 100.0,
                y: 200.0,
                is_drawing: true,
                tool: "pen".to_string(),
            },
            None,
        )
        .await;

        // 用戶 1 收到游標動態
        let presence1 = rx1.recv().await.expect("Alice receives presence");
        if let ServerMessage::PeerPresence {
            user_id, cursor, ..
        } = presence1
        {
            assert_eq!(user_id, "user-2");
            assert_eq!(cursor.x, 100.0);
            assert!(cursor.is_drawing);
        } else {
            panic!("Expected PeerPresence notification");
        }

        // 用戶 2 離開
        hub.leave("room-101", "user-2").await;
        let left_notify = rx1.recv().await.expect("Alice receives PeerLeft");
        if let ServerMessage::PeerLeft { user_id, .. } = left_notify {
            assert_eq!(user_id, "user-2");
        } else {
            panic!("Expected PeerLeft notification");
        }

        // 用戶 1 離開，房間自動銷毀
        hub.leave("room-101", "user-1").await;
        assert_eq!(hub.room_count().await, 0);
    }

    #[tokio::test]
    async fn test_owner_close_room() {
        let hub = RoomHub::new();
        let (tx1, _rx1) = mpsc::unbounded_channel();
        let (tx2, mut rx2) = mpsc::unbounded_channel();

        let _ = hub
            .join(
                "room-202".to_string(),
                "owner-1".to_string(),
                "Host".to_string(),
                "#00FF00".to_string(),
                "owner".to_string(),
                None,
                tx1,
            )
            .await
            .unwrap();

        let _ = hub
            .join(
                "room-202".to_string(),
                "guest-2".to_string(),
                "Guest".to_string(),
                "#FFAA00".to_string(),
                "editor".to_string(),
                None,
                tx2,
            )
            .await
            .unwrap();

        // 非房主試圖關閉應失敗
        let err = hub.close_room("room-202", "guest-2").await;
        assert!(err.is_err());

        // 房主關閉房間
        let ok = hub.close_room("room-202", "owner-1").await;
        assert!(ok.is_ok());

        // 訪客收到 RoomClosed 廣播
        let closed_notify = rx2.recv().await.expect("Guest receives RoomClosed");
        if let ServerMessage::RoomClosed { room_id, .. } = closed_notify {
            assert_eq!(room_id, "room-202");
        } else {
            panic!("Expected RoomClosed notification");
        }

        // 房間已被移除
        assert_eq!(hub.room_count().await, 0);
    }

    #[tokio::test]
    async fn test_oplog_history_and_catchup() {
        let hub = RoomHub::new();
        let (tx1, _rx1) = mpsc::unbounded_channel();
        let (tx2, _rx2) = mpsc::unbounded_channel();

        let _ = hub
            .join(
                "room-303".to_string(),
                "user-1".to_string(),
                "Alice".to_string(),
                "#FF0000".to_string(),
                "owner".to_string(),
                None,
                tx1,
            )
            .await
            .unwrap();

        // 用戶 1 廣播兩筆 Oplog (lamport = 1, 2)
        hub.broadcast_oplog(
            "room-303",
            "user-1",
            1,
            "attachment_upsert".to_string(),
            Some(true),
            serde_json::json!({"id": "item-1"}),
        )
        .await;

        hub.broadcast_oplog(
            "room-303",
            "user-1",
            2,
            "comment_upsert".to_string(),
            Some(false),
            serde_json::json!({"id": "pin-1"}),
        )
        .await;

        // 用戶 2 稍後加入房間
        let _ = hub
            .join(
                "room-303".to_string(),
                "user-2".to_string(),
                "Bob".to_string(),
                "#00FF00".to_string(),
                "editor".to_string(),
                None,
                tx2.clone(),
            )
            .await
            .unwrap();

        // 用戶 2 請求 catchup（已知 last_lamport = 1，期望取得 lamport > 1 的 oplog）
        let missing = hub.catchup("room-303", 1).await;
        assert_eq!(missing.len(), 1);
        if let ServerMessage::PeerOplog { lamport, kind, .. } = &missing[0] {
            assert_eq!(*lamport, 2);
            assert_eq!(kind, "comment_upsert");
        } else {
            panic!("Expected PeerOplog in catchup batch");
        }

        // 用戶 2 請求從頭 catchup (last_lamport = 0)
        let all = hub.catchup("room-303", 0).await;
        assert_eq!(all.len(), 2);
    }
}

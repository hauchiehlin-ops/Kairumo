//! 多人即時狀態與游標 (Presence & Live Cursors) - Ephemeral 廣播機制
//!
//! 與 Oplog 不同，這裡的事件是「轉瞬即逝」的（Ephemeral），不需要存入硬碟。
//! 這些事件透過 WebRTC DataChannel 或 WebSocket 廣播給所有連線中的設備，
//! 用來實作畫面上的游標移動、選取框高亮，以防止編輯衝突並增強協作感。

use serde::{Deserialize, Serialize};

/// 裝置/使用者的短暫狀態事件
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum PresenceEvent {
    /// 游標或畫面中心點移動
    CursorMove {
        device_id: u32,
        page_id: String,
        x: f32,
        y: f32,
    },
    /// 使用者聚焦於某個文字或物件區塊（UI 可繪製發光邊框）
    BlockFocus { device_id: u32, block_id: String },
    /// 裝置加入協作房間
    UserJoin {
        device_id: u32,
        color_hex: String, // 例如 "#FF5733"
    },
    /// 裝置離開協作房間
    UserLeave { device_id: u32 },
}

/// 狀態管理器：供 FFI 層將收到的網路廣播轉發給 UI 繪製
#[derive(Debug, Default)]
pub struct PresenceManager {
    // 預留：保存當前房間內各裝置的最新座標與顏色，供 UI 輪詢或訂閱
}

impl PresenceManager {
    pub fn new() -> Self {
        Self {}
    }

    /// 處理從網路層（WebRTC / WebSocket）收到的廣播事件
    pub fn handle_event(&self, event_json: &str) -> Result<PresenceEvent, String> {
        serde_json::from_str(event_json).map_err(|e| e.to_string())
    }

    /// 產生本機的廣播事件 JSON，準備發送給其他裝置
    pub fn create_cursor_event(device_id: u32, page_id: &str, x: f32, y: f32) -> String {
        let event = PresenceEvent::CursorMove {
            device_id,
            page_id: page_id.to_string(),
            x,
            y,
        };
        serde_json::to_string(&event).unwrap_or_default()
    }
}

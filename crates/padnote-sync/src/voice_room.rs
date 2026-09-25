//! 協作語音通話 (Collaborative Voice Room) - Phase 4 (進階 2)
//!
//! 在同一個筆記本內建立一個基於 WebRTC 的語音通話房間。
//! 利用我們現有的 WebRTC 信令 (Signaling) 骨架，額外協商 `audio: true` 的 MediaStream。
//! 
//! # 不破壞性設計
//! 這裡只負責「房間管理」與「語音狀態廣播」(靜音/發言中)。
//! 實際的音訊擷取與播放交由各平台的 WebRTC Native SDK 處理，不干擾現有的 `padnote-audio` 錄音。

use serde::{Serialize, Deserialize};
use std::collections::HashMap;

/// 房間內的語音狀態廣播
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum VoiceRoomEvent {
    /// 請求加入語音通話
    JoinVoice {
        device_id: u32,
    },
    /// 離開語音通話
    LeaveVoice {
        device_id: u32,
    },
    /// 變更麥克風狀態（例如靜音）
    MicrophoneState {
        device_id: u32,
        is_muted: bool,
    },
    /// VAD (Voice Activity Detection) 偵測到正在講話
    SpeakingState {
        device_id: u32,
        is_speaking: bool,
    }
}

pub struct VoiceRoomManager {
    /// 記錄當前在通話中的設備及其靜音狀態
    active_participants: HashMap<u32, bool>,
}

impl VoiceRoomManager {
    pub fn new() -> Self {
        Self {
            active_participants: HashMap::new(),
        }
    }

    /// 處理網路收到的語音房間事件
    pub fn handle_event(&mut self, event_json: &str) -> Result<VoiceRoomEvent, String> {
        let event: VoiceRoomEvent = serde_json::from_str(event_json).map_err(|e| e.to_string())?;
        
        match &event {
            VoiceRoomEvent::JoinVoice { device_id } => {
                self.active_participants.insert(*device_id, false);
            }
            VoiceRoomEvent::LeaveVoice { device_id } => {
                self.active_participants.remove(device_id);
            }
            VoiceRoomEvent::MicrophoneState { device_id, is_muted } => {
                if let Some(state) = self.active_participants.get_mut(device_id) {
                    *state = *is_muted;
                }
            }
            _ => {}
        }
        
        Ok(event)
    }
    
    pub fn get_participants(&self) -> Vec<u32> {
        self.active_participants.keys().copied().collect()
    }
}

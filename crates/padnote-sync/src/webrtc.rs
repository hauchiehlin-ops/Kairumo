//! WebRTC P2P 穿透與 Tailscale 輔助直連 (Phase 2)。
//!
//! 這是一個純 P2P 的 Oplog 傳輸層，不依賴 Google Drive 或 iCloud 的檔案輪詢。
//! 
//! # WebRTC 與 Tailscale 的互補
//! 
//! WebRTC 內建 ICE (Interactive Connectivity Establishment)，能透過 STUN 伺服器
//! 進行 NAT 穿透。但面對對稱型 NAT (Symmetric NAT) 時，傳統做法必須退而求其次
//! 使用 TURN 伺服器（需要我們架設中繼且消耗大量頻寬）。
//!
//! 為了維持真正的 Serverless 原則，我們強烈建議使用者安裝 **Tailscale**。
//! Tailscale 在作業系統層級建立了一個虛擬的私有網路 (100.x.y.z)，這使得
//! 兩台遠在天邊的裝置在 WebRTC 眼裡「**就處於同一個區網下**」。
//! 這樣 WebRTC 就能 100% 成功建立 Local Host Candidate 直連，
//! 徹底省去 TURN 伺服器的建置成本，同時享受端對端加密的極速傳輸。

use std::sync::Arc;

pub struct WebRTCSyncEngine {
    // 預留：libwebrtc bindings 或 WebRTC-rs 的 DataChannel
}

impl WebRTCSyncEngine {
    pub fn new() -> Self {
        Self {}
    }
    
    /// 開始發起連線或接聽。
    pub fn start(&self) {
        // TODO: 實作 ICE candidate 收集與 SDP 信令交換。
        // （在此我們可利用極輕量的 MQTT 或 Cloudflare Workers 作為 SDP 的交換信道）
    }
}

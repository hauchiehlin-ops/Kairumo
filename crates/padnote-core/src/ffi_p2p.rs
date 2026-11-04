//! 雲端協作的點對點直連（WebRTC 資料通道）。
//!
//! # 為什麼不需要伺服器
//!
//! WebRTC 要兩樣東西：交換連線資訊（SDP，「信令」）與穿越 NAT。
//! - **信令走共享雲端資料夾**：發起方把 offer 寫成 `signal/<from>-<to>.offer`，
//!   對方輪詢時看到就回 `…answer`。只在建立連線時花幾秒，之後不再經過雲端。
//! - **NAT 穿越用公共 STUN**（Google 提供，免費、不經手內容）。不架 TURN 中繼 ——
//!   專案決策是不營運後端。約一到兩成的網路（對稱型 NAT、部分公司網路）打不通，
//!   那時就停在雲端輪詢模式，資料正確性不受影響。
//!
//! 這裡不等待「trickle ICE」：建立 offer／answer 時先把候選位址收集完再交出去，
//! 信令只需要一來一回兩個檔。
//!
//! 通道上傳什麼見 [`crate::ffi_p2p_frames`]。內容與雲端上的事件檔相同（已經是
//! 套件格式），WebRTC 本身以 DTLS 加密傳輸。

use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;

use webrtc::api::APIBuilder;
use webrtc::data_channel::RTCDataChannel;
use webrtc::data_channel::data_channel_message::DataChannelMessage;
use webrtc::ice_transport::ice_server::RTCIceServer;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;

/// 預設的公共 STUN。
pub const DEFAULT_STUN: &[&str] = &["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"];

fn runtime() -> &'static tokio::runtime::Runtime {
    static RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .thread_name("kairumo-p2p")
            .enable_all()
            .build()
            .expect("p2p runtime")
    })
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiPeerState {
    Connecting,
    Connected,
    /// 打不通或斷了。平台退回雲端輪詢，稍後可以再試一次。
    Failed,
    Closed,
}

/// 平台實作：收到訊框、狀態改變。**在背景執行緒呼叫**，平台要自己切回主執行緒。
#[uniffi::export(with_foreign)]
pub trait FfiPeerListener: Send + Sync {
    fn on_frame(&self, frame: Vec<u8>);
    fn on_state(&self, state: FfiPeerState);
}

/// 信令檔在共享資料夾裡的路徑。`from`／`to` 是裝置 id。
#[uniffi::export]
pub fn p2p_signal_path(from_device: u32, to_device: u32, answer: bool) -> String {
    format!(
        "signal/{from_device:08x}-{to_device:08x}.{}",
        if answer { "answer" } else { "offer" }
    )
}

/// 誰發起：裝置 id 小的那一方發 offer（兩端算出同一個答案，不會兩邊同時發）。
#[uniffi::export]
pub fn p2p_should_offer(my_device: u32, peer_device: u32) -> bool {
    my_device < peer_device
}

#[derive(uniffi::Object)]
pub struct FfiPeerLink {
    pc: Arc<RTCPeerConnection>,
    channel: Arc<Mutex<Option<Arc<RTCDataChannel>>>>,
    listener: Arc<dyn FfiPeerListener>,
}

impl std::fmt::Debug for FfiPeerLink {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("FfiPeerLink").finish_non_exhaustive()
    }
}

fn wire_channel(
    dc: &Arc<RTCDataChannel>,
    slot: &Arc<Mutex<Option<Arc<RTCDataChannel>>>>,
    listener: &Arc<dyn FfiPeerListener>,
) {
    *slot.lock().unwrap() = Some(dc.clone());
    let l = listener.clone();
    dc.on_message(Box::new(move |msg: DataChannelMessage| {
        l.on_frame(msg.data.to_vec());
        Box::pin(async {})
    }));
    let l = listener.clone();
    dc.on_open(Box::new(move || {
        l.on_state(FfiPeerState::Connected);
        Box::pin(async {})
    }));
}

#[uniffi::export]
impl FfiPeerLink {
    /// 發起方：建立資料通道與 offer，等候選位址收集完（最多 `timeout_ms`）後回傳 SDP（JSON）。
    pub fn create_offer(&self, timeout_ms: u32) -> String {
        let pc = self.pc.clone();
        let slot = self.channel.clone();
        let listener = self.listener.clone();
        runtime().block_on(async move {
            let Ok(dc) = pc.create_data_channel("kairumo", None).await else {
                return String::new();
            };
            wire_channel(&dc, &slot, &listener);
            let Ok(offer) = pc.create_offer(None).await else {
                return String::new();
            };
            let mut gathered = pc.gathering_complete_promise().await;
            if pc.set_local_description(offer).await.is_err() {
                return String::new();
            }
            let _ = tokio::time::timeout(Duration::from_millis(timeout_ms as u64), gathered.recv()).await;
            local_sdp(&pc).await
        })
    }

    /// 回應方：收下 offer，回傳 answer（JSON）。
    pub fn accept_offer(&self, offer_json: String, timeout_ms: u32) -> String {
        let pc = self.pc.clone();
        runtime().block_on(async move {
            let Ok(offer) = serde_json::from_str::<RTCSessionDescription>(&offer_json) else {
                return String::new();
            };
            if pc.set_remote_description(offer).await.is_err() {
                return String::new();
            }
            let Ok(answer) = pc.create_answer(None).await else {
                return String::new();
            };
            let mut gathered = pc.gathering_complete_promise().await;
            if pc.set_local_description(answer).await.is_err() {
                return String::new();
            }
            let _ = tokio::time::timeout(Duration::from_millis(timeout_ms as u64), gathered.recv()).await;
            local_sdp(&pc).await
        })
    }

    /// 發起方：收下 answer。
    pub fn apply_answer(&self, answer_json: String) -> bool {
        let pc = self.pc.clone();
        runtime().block_on(async move {
            match serde_json::from_str::<RTCSessionDescription>(&answer_json) {
                Ok(answer) => pc.set_remote_description(answer).await.is_ok(),
                Err(_) => false,
            }
        })
    }

    /// 送一個訊框。通道還沒開或已經斷了回 false（平台照常走雲端）。
    pub fn send(&self, frame: Vec<u8>) -> bool {
        let Some(dc) = self.channel.lock().unwrap().clone() else {
            return false;
        };
        runtime().block_on(async move { dc.send(&bytes::Bytes::from(frame)).await.is_ok() })
    }

    pub fn disconnect(&self) {
        let pc = self.pc.clone();
        runtime().block_on(async move {
            let _ = pc.close().await;
        });
    }
}

impl FfiPeerLink {
    /// 建立一條（還沒連上的）連線。見 [`p2p_new_link`]。
    fn new(stun_urls: Vec<String>, listener: Arc<dyn FfiPeerListener>) -> Option<Arc<Self>> {
        let urls = if stun_urls.is_empty() {
            DEFAULT_STUN.iter().map(|s| s.to_string()).collect()
        } else {
            stun_urls
        };
        runtime().block_on(async move {
            let api = APIBuilder::new().build();
            let config = RTCConfiguration {
                ice_servers: vec![RTCIceServer { urls, ..Default::default() }],
                ..Default::default()
            };
            let pc = Arc::new(api.new_peer_connection(config).await.ok()?);
            let channel: Arc<Mutex<Option<Arc<RTCDataChannel>>>> = Arc::new(Mutex::new(None));

            let l = listener.clone();
            pc.on_peer_connection_state_change(Box::new(move |s: RTCPeerConnectionState| {
                let state = match s {
                    RTCPeerConnectionState::Connected => None, // 等資料通道 open 再報 Connected
                    RTCPeerConnectionState::Failed | RTCPeerConnectionState::Disconnected => {
                        Some(FfiPeerState::Failed)
                    }
                    RTCPeerConnectionState::Closed => Some(FfiPeerState::Closed),
                    _ => Some(FfiPeerState::Connecting),
                };
                if let Some(state) = state {
                    l.on_state(state);
                }
                Box::pin(async {})
            }));
            // 回應方：通道由發起方建立，這裡接住。
            let slot = channel.clone();
            let l = listener.clone();
            pc.on_data_channel(Box::new(move |dc: Arc<RTCDataChannel>| {
                wire_channel(&dc, &slot, &l);
                Box::pin(async {})
            }));
            Some(Arc::new(Self { pc, channel, listener }))
        })
    }

}

/// 建立一條（還沒連上的）連線。`stun_urls` 為空時用 [`DEFAULT_STUN`]。
/// 建不起來（極少見）回 `None`，平台照常走雲端。
#[uniffi::export]
pub fn p2p_new_link(stun_urls: Vec<String>, listener: Arc<dyn FfiPeerListener>) -> Option<Arc<FfiPeerLink>> {
    FfiPeerLink::new(stun_urls, listener)
}

async fn local_sdp(pc: &Arc<RTCPeerConnection>) -> String {
    match pc.local_description().await {
        Some(desc) => serde_json::to_string(&desc).unwrap_or_default(),
        None => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc;

    struct Probe {
        frames: Mutex<mpsc::Sender<Vec<u8>>>,
        states: Mutex<mpsc::Sender<FfiPeerState>>,
    }
    impl FfiPeerListener for Probe {
        fn on_frame(&self, frame: Vec<u8>) {
            let _ = self.frames.lock().unwrap().send(frame);
        }
        fn on_state(&self, state: FfiPeerState) {
            let _ = self.states.lock().unwrap().send(state);
        }
    }

    fn probe() -> (Arc<Probe>, mpsc::Receiver<Vec<u8>>, mpsc::Receiver<FfiPeerState>) {
        let (ft, fr) = mpsc::channel();
        let (st, sr) = mpsc::channel();
        (Arc::new(Probe { frames: Mutex::new(ft), states: Mutex::new(st) }), fr, sr)
    }

    fn wait_connected(rx: &mpsc::Receiver<FfiPeerState>) -> bool {
        let deadline = std::time::Instant::now() + Duration::from_secs(15);
        while std::time::Instant::now() < deadline {
            match rx.recv_timeout(Duration::from_millis(500)) {
                Ok(FfiPeerState::Connected) => return true,
                Ok(FfiPeerState::Failed) => return false,
                _ => {}
            }
        }
        false
    }

    /// 同一台機器上的兩端：只靠本機候選位址（不需要 STUN、不需要網路）。
    #[test]
    fn two_peers_connect_and_exchange_a_frame() {
        let (pa, _fa, sa) = probe();
        let (pb, fb, sb) = probe();
        // 用一個不存在的 STUN：候選收集只剩本機位址，測試不依賴外網。
        let none = vec!["stun:127.0.0.1:9".to_string()];
        let a = p2p_new_link(none.clone(), pa).expect("a");
        let b = p2p_new_link(none, pb).expect("b");
        let offer = a.create_offer(2_000);
        assert!(!offer.is_empty());
        let answer = b.accept_offer(offer, 2_000);
        assert!(!answer.is_empty());
        assert!(a.apply_answer(answer));
        assert!(wait_connected(&sa), "a never connected");
        assert!(wait_connected(&sb), "b never connected");
        let frame = crate::ffi_p2p_frames::p2p_encode_presence("{\"x\":1}".into());
        assert!(a.send(frame.clone()));
        assert_eq!(fb.recv_timeout(Duration::from_secs(5)).unwrap(), frame);
        a.disconnect();
        b.disconnect();
    }

    #[test]
    fn signalling_is_deterministic() {
        assert!(p2p_should_offer(1, 2));
        assert!(!p2p_should_offer(2, 1));
        assert_eq!(p2p_signal_path(1, 0xab, false), "signal/00000001-000000ab.offer");
    }
}

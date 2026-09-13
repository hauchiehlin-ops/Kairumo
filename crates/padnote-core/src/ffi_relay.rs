//! 內建協同中繼的 FFI 門面（工作包 WP3b）。
//!
//! # 為什麼是 feature、而且預設關閉
//!
//! Apple 版已經有自己的中繼實作（Swift + Network.framework）而且在使用者手上
//! 穩定運作。把 tokio 拉進 iOS 的二進位不但沒有好處，還會動到已經穩定的東西 ——
//! 硬前提是不影響現有 Apple 版。所以：Android 建置時開啟 `relay`，Apple 不開。
//!
//! 兩邊仍然共用 `padnote-relay` 的**同一份 JSON 協定**（join / presence / oplog /
//! catchup / leave / close_room / ping），所以 iOS 與 Android 能加入同一個房間。
//! 訊息內容的加密走 `padnote_crypto::session`，與 CryptoKit 逐位元組相容。

use crate::ffi::FfiError;
use padnote_relay::RoomHub;
use std::net::SocketAddr;
use std::sync::Mutex;
use tokio::runtime::Runtime;

struct RunningRelay {
    runtime: Runtime,
    shutdown: Option<tokio::sync::oneshot::Sender<()>>,
    port: u16,
}

/// 裝置內建的協同中繼。
///
/// 發起協同的那台裝置自己擔任中繼點 —— 這不違反 D5「不建後端伺服器」：
/// D5 說的是我們不營運雲端服務，不是裝置不能開房間。
#[derive(uniffi::Object)]
pub struct RelayServer {
    state: Mutex<Option<RunningRelay>>,
}

#[uniffi::export]
impl RelayServer {
    /// 建立一個尚未啟動的中繼。
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {
            state: Mutex::new(None),
        }
    }

    /// 啟動中繼並回傳**實際**綁定的埠。
    ///
    /// 傳 0 代表讓系統挑一個可用的埠 —— 回傳值就是要告訴隊友的那個號碼，
    /// 所以這裡一定要回報實際值，不能回報請求值。
    pub fn start(&self, port: u16) -> Result<u16, FfiError> {
        let mut guard = self.state.lock().map_err(|_| poisoned())?;
        if let Some(running) = guard.as_ref() {
            // 已經在跑就直接回報現況，重複呼叫不該是錯誤
            return Ok(running.port);
        }

        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .map_err(|e| FfiError::Failed(format!("無法建立執行緒池：{e}")))?;

        let addr: SocketAddr = format!("0.0.0.0:{port}")
            .parse()
            .map_err(|_| FfiError::Failed(format!("無效的埠號 {port}")))?;

        // 用同步的 std listener 先綁定，再交給 runtime。
        //
        // 不用 `runtime.block_on(...)`：呼叫端可能本身就在某個 async runtime 的
        // 執行緒上（測試、或未來把 FFI 包進協程的平台層），那樣會直接 panic
        // 「Cannot start a runtime from within a runtime」。同步綁定沒有這個問題，
        // 而且我們本來就需要在 spawn 之前拿到實際的埠號。
        let std_listener = std::net::TcpListener::bind(addr)
            .map_err(|e| FfiError::Failed(format!("無法綁定 {addr}：{e}")))?;
        let bound_port = std_listener
            .local_addr()
            .map_err(|e| FfiError::Failed(format!("取不到綁定的埠：{e}")))?
            .port();
        std_listener
            .set_nonblocking(true)
            .map_err(|e| FfiError::Failed(format!("設定非阻塞失敗：{e}")))?;

        let (tx, rx) = tokio::sync::oneshot::channel();
        runtime.spawn(async move {
            match tokio::net::TcpListener::from_std(std_listener) {
                Ok(listener) => padnote_relay::serve(listener, RoomHub::new(), rx).await,
                Err(e) => eprintln!("⚠️ 中繼無法接手 listener：{e}"),
            }
        });

        *guard = Some(RunningRelay {
            runtime,
            shutdown: Some(tx),
            port: bound_port,
        });
        Ok(bound_port)
    }

    /// 停止中繼。未啟動時呼叫不是錯誤。
    pub fn stop(&self) {
        let Ok(mut guard) = self.state.lock() else {
            return;
        };
        if let Some(mut running) = guard.take() {
            if let Some(tx) = running.shutdown.take() {
                let _ = tx.send(());
            }
            // 不要在這裡等背景工作跑完：呼叫端是 UI 執行緒。
            running.runtime.shutdown_background();
        }
    }

    /// 目前是否正在提供服務。
    pub fn is_running(&self) -> bool {
        self.state.lock().map(|g| g.is_some()).unwrap_or(false)
    }

    /// 目前綁定的埠（未啟動時為 0）。
    pub fn port(&self) -> u16 {
        self.state
            .lock()
            .map(|g| g.as_ref().map(|r| r.port).unwrap_or(0))
            .unwrap_or(0)
    }
}

impl Default for RelayServer {
    fn default() -> Self {
        Self::new()
    }
}

fn poisoned() -> FfiError {
    FfiError::Failed("中繼狀態鎖已毀損".to_string())
}

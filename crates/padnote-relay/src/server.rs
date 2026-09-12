//! WebSocket 伺服器傳輸服務。

use crate::hub::RoomHub;
use crate::protocol::{ClientMessage, ServerMessage};
use futures_util::{SinkExt, StreamExt};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio_tungstenite::tungstenite::Message;

/// 啟動中繼微服務監聽循環。
pub async fn run_server(addr: SocketAddr, hub: RoomHub) -> Result<(), Box<dyn std::error::Error>> {
    let listener = TcpListener::bind(addr).await?;
    println!("🚀 [Padnote Relay] WebSocket 中繼服務已啟動：ws://{}", addr);

    let hub = Arc::new(hub);

    while let Ok((stream, client_addr)) = listener.accept().await {
        let hub_clone = Arc::clone(&hub);
        tokio::spawn(async move {
            if let Err(e) = handle_connection(stream, client_addr, hub_clone).await {
                eprintln!("⚠️ 連線異常 [{}]: {}", client_addr, e);
            }
        });
    }

    Ok(())
}

/// 處理單一 WebSocket 客戶端連線。
async fn handle_connection(
    stream: TcpStream,
    _addr: SocketAddr,
    hub: Arc<RoomHub>,
) -> Result<(), Box<dyn std::error::Error>> {
    let ws_stream = tokio_tungstenite::accept_async(stream).await?;
    let (mut ws_sender, mut ws_receiver) = ws_stream.split();

    let (tx, mut rx) = mpsc::unbounded_channel::<ServerMessage>();

    // 轉發 channel 訊息至 WebSocket
    let send_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if let Ok(json_str) = serde_json::to_string(&msg) {
                if ws_sender.send(Message::text(json_str)).await.is_err() {
                    break;
                }
            }
        }
    });

    let mut current_room: Option<String> = None;
    let mut current_user: Option<String> = None;

    // 讀取客戶端 WebSocket 訊息
    while let Some(Ok(ws_msg)) = ws_receiver.next().await {
        match ws_msg {
            Message::Text(text) => {
                if let Ok(client_msg) = serde_json::from_str::<ClientMessage>(text.as_str()) {
                    if let Some(resp) = hub
                        .handle_message(client_msg, &mut current_room, &mut current_user, &tx)
                        .await
                    {
                        let _ = tx.send(resp);
                    }
                } else {
                    let _ = tx.send(ServerMessage::Error {
                        code: "INVALID_FORMAT".to_string(),
                        message: "無法解析之訊息格式".to_string(),
                    });
                }
            }
            Message::Close(_) => {
                break;
            }
            Message::Ping(_data) => {
                // 自動回覆 Pong
                let _ = tx.send(ServerMessage::Pong);
            }
            _ => {}
        }
    }

    // 斷線清理：若仍在房間內，自動觸發離線
    if let (Some(room_id), Some(user_id)) = (current_room, current_user) {
        hub.leave(&room_id, &user_id).await;
    }

    let _ = send_task.await;
    Ok(())
}

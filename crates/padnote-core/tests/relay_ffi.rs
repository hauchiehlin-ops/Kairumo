//! 內建中繼的端到端測試（工作包 WP3b）。
//!
//! 驗的是 FFI 這一層真的能起服務、能轉發 —— 而不只是 hub 的單元邏輯。
//! 沒有這層測試，Android 端要等到兩台裝置面對面才會發現中繼起不來。
#![cfg(feature = "relay")]

use futures_util::{SinkExt, StreamExt};
use padnote_core::ffi_relay::RelayServer;
use serde_json::{Value, json};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message;

async fn recv_json(
    ws: &mut tokio_tungstenite::WebSocketStream<
        tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
    >,
) -> Value {
    loop {
        let msg = tokio::time::timeout(std::time::Duration::from_secs(5), ws.next())
            .await
            .expect("等待訊息逾時")
            .expect("連線已關閉")
            .expect("讀取失敗");
        if let Message::Text(text) = msg {
            return serde_json::from_str(&text).expect("不是合法的 JSON");
        }
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn two_clients_can_join_the_same_room_and_relay() {
    // port 0：讓系統挑，回傳值必須是實際綁到的埠
    let relay = RelayServer::new();
    let port = relay.start(0).expect("中繼啟動失敗");
    assert!(port > 0, "應回報實際綁定的埠，而不是 0");
    assert!(relay.is_running());
    assert_eq!(relay.port(), port);

    let url = format!("ws://127.0.0.1:{port}");
    let (mut alice, _) = connect_async(&url).await.expect("Alice 連不上");
    alice
        .send(Message::text(
            json!({
                "type": "join", "room_id": "r1", "user_id": "u-alice",
                "user_name": "Alice", "user_color": "#f00", "role": "owner"
            })
            .to_string(),
        ))
        .await
        .unwrap();

    let joined = recv_json(&mut alice).await;
    assert_eq!(joined["type"], "joined");
    assert_eq!(joined["role"], "owner", "第一位加入者應成為房主");

    let (mut bob, _) = connect_async(&url).await.expect("Bob 連不上");
    bob.send(Message::text(
        json!({
            "type": "join", "room_id": "r1", "user_id": "u-bob",
            "user_name": "Bob", "user_color": "#00f", "role": "editor"
        })
        .to_string(),
    ))
    .await
    .unwrap();

    let bob_joined = recv_json(&mut bob).await;
    assert_eq!(bob_joined["type"], "joined");
    assert_eq!(
        bob_joined["peers"].as_array().unwrap().len(),
        1,
        "Bob 應看到既有的 Alice"
    );

    // Alice 應收到 peer_joined
    let notify = recv_json(&mut alice).await;
    assert_eq!(notify["type"], "peer_joined");
    assert_eq!(notify["peer"]["user_id"], "u-bob");

    // Alice 發 oplog，Bob 要收到轉發
    alice
        .send(Message::text(
            json!({
                "type": "oplog", "room_id": "r1", "user_id": "u-alice",
                "lamport": 7, "kind": "stroke_delta",
                "payload": {"ciphertext": "AAAA"}, "encrypted": true
            })
            .to_string(),
        ))
        .await
        .unwrap();

    let forwarded = recv_json(&mut bob).await;
    assert_eq!(forwarded["type"], "peer_oplog");
    assert_eq!(forwarded["lamport"], 7);
    assert_eq!(forwarded["payload"]["ciphertext"], "AAAA");

    relay.stop();
    assert!(!relay.is_running());
}

#[tokio::test(flavor = "multi_thread")]
async fn starting_twice_reports_the_same_port_instead_of_failing() {
    let relay = RelayServer::new();
    let first = relay.start(0).unwrap();
    let second = relay.start(0).unwrap();
    assert_eq!(first, second, "重複啟動應回報現況，而不是再綁一個埠");
    relay.stop();
}

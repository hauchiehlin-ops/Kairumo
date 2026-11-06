//! Padnote 線上多人協同中繼伺服器執行檔。

use padnote_relay::{RelayLimits, RoomHub, run_server};
use std::env;
use std::net::SocketAddr;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let port = env::var("PORT")
        .ok()
        .and_then(|p| p.parse::<u16>().ok())
        .unwrap_or(9002);

    let host = env::var("HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let addr: SocketAddr = format!("{}:{}", host, port).parse()?;

    println!("=======================================================");
    println!(
        "  Padnote Collaborative Relay Server v{}",
        env!("CARGO_PKG_VERSION")
    );
    println!("  輕量 WebSocket 房間中繼微服務已啟動");
    println!("  監聽位址: ws://{}", addr);
    println!("=======================================================");

    // 放在公開網路上（例如 Fly.io）時的防護；本機開發照舊不設限。
    let env_num = |key: &str| {
        env::var(key)
            .ok()
            .and_then(|v| v.parse::<u64>().ok())
            .unwrap_or(0)
    };
    let limits = RelayLimits {
        max_rooms: env_num("RELAY_MAX_ROOMS") as usize,
        max_peers_per_room: env_num("RELAY_MAX_PEERS") as usize,
        idle_timeout_secs: env_num("RELAY_IDLE_SECS"),
    };
    println!(
        "  上限: 房間 {} / 每房 {} 人 / 閒置 {} 秒（0 = 不限）",
        limits.max_rooms, limits.max_peers_per_room, limits.idle_timeout_secs
    );
    let hub = RoomHub::with_limits(limits);
    run_server(addr, hub).await?;

    Ok(())
}

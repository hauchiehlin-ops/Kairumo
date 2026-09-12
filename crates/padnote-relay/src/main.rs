//! Padnote 線上多人協同中繼伺服器執行檔。

use padnote_relay::{run_server, RoomHub};
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
    println!("  Padnote Collaborative Relay Server v{}", env!("CARGO_PKG_VERSION"));
    println!("  輕量 WebSocket 房間中繼微服務已啟動");
    println!("  監聽位址: ws://{}", addr);
    println!("=======================================================");

    let hub = RoomHub::new();
    run_server(addr, hub).await?;

    Ok(())
}

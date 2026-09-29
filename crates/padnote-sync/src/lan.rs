//! **區網直連**（秒同步的亞秒那一段）。
//!
//! # 這是什麼、不是什麼
//!
//! 同一個 Wi-Fi 底下的兩台裝置，把「使用者正開著的那一本」的新內容
//! **直接**傳給對方，不經過 Google Drive。Drive 路徑的下限是
//! 上傳 + 傳播 + 輪詢 ≈ 2–3 秒，而且那是**沒有後端**這個前提下的物理極限
//! （`changes.watch` 需要公開端點，違反 D5）；區網沒有這個限制。
//!
//! 它是**加法**，不是替代：
//!
//! * 傳的是同一份資料 —— 套件裡的 oplog 檔與筆跡檔，整檔、append-only。
//!   收到之後走跟 Drive 下載完全相同的寫入路徑，所以收斂規則一個字都沒變
//!   （每台只寫自己的檔、較長者是超集、CRDT 合併可交換且冪等）。
//! * 傳不到就沒事：離開區網、對方不在線、金鑰不符，全部**靜默退回** Drive。
//!   區網通道永遠不是資料的唯一副本 —— 兩端各自照舊把內容推上雲端。
//! * 只傳焦點筆記本的 oplog 與筆跡。媒體（錄音、照片）不走這裡，
//!   它們大、不急，Drive 那條路已經夠用。
//!
//! # 為什麼傳輸也在核心
//!
//! 只有**發現**（Bonjour / NSD）是平台的事 —— 它們只負責告訴核心
//! 「這個位址有一台同帳號的裝置」。協定、加密、去重、重連全部在這裡，
//! 用 `std::net`，兩個平台一份實作。各寫一份的話，第一個出現的不相容
//! 會是「iPad 看得到 Android、Android 看不到 iPad」。
//!
//! # 信任模型
//!
//! 同一個使用者的裝置共有一把 **區網金鑰**（32 位元組，存在使用者自己的
//! Drive `appDataFolder`，見 `ffi_lan`）。拿得到那把金鑰的人本來就拿得到
//! 全部同步資料，所以它不擴大任何信任面。
//!
//! ```text
//! 用戶端 ──  "KLN1" | 用戶端亂數(16) | 裝置 id | 金鑰標籤(8)        ──▶ 伺服端
//! 用戶端 ◀─  "KLN1" | 伺服端亂數(16) | 裝置 id ，加 一個加密的 Ready ── 伺服端
//! 用戶端 ──  一個加密的 Ready                                        ──▶ 伺服端
//! 之後每個訊框：AES-256-GCM，金鑰 = SHA-256(金鑰 ‖ 兩個亂數)
//! ```
//!
//! * **標籤**只是讓「同一個 Wi-Fi 上別人的 Kairumo」在第一個封包就被擋掉，
//!   不是認證；它是金鑰的單向雜湊，洩漏不了金鑰。
//! * **認證**靠加密的 `Ready`：解得開 = 有金鑰。兩邊都要先解開對方的
//!   第一個訊框才會處理任何內容。
//! * 每個連線的金鑰混入雙方亂數，訊框重放到別的連線會解不開。
//! * 訊框帶方向位元組，擋掉把我方訊框原樣丟回來的反射。
//!
//! # 資料流
//!
//! ```text
//! A 存檔 ─▶ announce(nb) ─▶ Have{nb, [檔名, 大小]…} ─▶ B
//!                                                      │ 逐檔比大小，較長者才要
//!           B ◀── Want{nb, 檔名} ◀─────────────────────┘
//! A ─▶ File{nb, 檔名} + 位元組 ─▶ B 寫進套件 ─▶ on_received
//! ```

use std::collections::{HashMap, HashSet};
use std::io::{self, Read, Write};
use std::net::{Shutdown, TcpListener, TcpStream, ToSocketAddrs};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use padnote_crypto::session::SessionKey;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// 區網金鑰在雲端的路徑。放在 `settings/` 底下，與 `global.json` 同一層 ——
/// 同樣是「跟筆記本無關的帳號層資料」，垃圾回收與稽核都不會碰它
/// （它不屬於任何 `notebooks/<id>/`）。
pub const LAN_KEY_PATH: &str = "settings/lan-key.json";

/// 協定識別。改協定就升這個數字 —— 舊版收到不認得的魔數會直接斷線，
/// 而不是把一個不相容的訊框當成內容處理。
const MAGIC: &[u8; 4] = b"KLN1";

/// 單一訊框上限。超過的檔案不走區網（Drive 那條路照常處理）。
pub const MAX_FRAME_BYTES: usize = 48 * 1024 * 1024;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(3);
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(5);
const WRITE_TIMEOUT: Duration = Duration::from_secs(10);
/// 沒有訊框時多久送一次心跳。
const PING_EVERY: Duration = Duration::from_secs(10);
/// 這麼久沒收到任何訊框就當對方走了。
const DEAD_AFTER: Duration = Duration::from_secs(35);

const DIR_CLIENT: u8 = 1;
const DIR_SERVER: u8 = 2;

/// 區網金鑰。
pub type LanKey = [u8; 32];

/// 檔案種類。對應套件裡的兩個目錄。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LanKind {
    /// `doc/ops/*`
    Ops,
    /// `ink/*.strokes`
    Ink,
}

/// 一個檔案的名字與大小。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LanFile {
    pub kind: LanKind,
    pub name: String,
    pub size: u64,
}

/// 區網通道要的本機儲存。
///
/// 抽成 trait 是為了兩件事：`padnote-sync` 不依賴 `padnote-storage`
/// （方向是 core → sync，反過來會成環），而且測試用記憶體版就能把整個
/// 協定跑一遍。
pub trait LanStore: Send + Sync {
    /// 使用者現在開著的筆記本。區網只主動推這一本。
    fn focused_notebook(&self) -> Option<String>;
    /// 本機這本筆記本有哪些檔案。**沒有這本筆記本就回 `None`** ——
    /// 區網不負責「建立整本筆記」，那是整庫同步的事。
    fn list(&self, notebook_id: &str) -> Option<Vec<LanFile>>;
    /// 這個檔案該不該向對方要。預設全要。
    ///
    /// 有兩種檔案**不能**要：自己這台裝置寫的（本機才是權威，對方手上的
    /// 只可能是舊版；要回來還會讓壓實吃掉的碎檔復活），以及已經被本機
    /// 壓實吃掉的碎檔（同步下來的話，壓實與下載會形成死循環）。
    /// 這些規則跟 Drive 下載路徑一致，由儲存層實作。
    fn accepts(&self, notebook_id: &str, kind: LanKind, name: &str) -> bool {
        let _ = (notebook_id, kind, name);
        true
    }
    /// 讀一個檔案的完整內容。
    fn read(&self, notebook_id: &str, kind: LanKind, name: &str) -> Option<Vec<u8>>;
    /// 寫一個收到的檔案。實作端要驗證檔名（來自網路，不可信）。
    /// 回傳有沒有真的寫入。
    fn write(&self, notebook_id: &str, kind: LanKind, name: &str, bytes: &[u8]) -> bool;
    /// 一批檔案收完了。`files` 是這一批真的寫進去幾個。
    /// 平台據此把套件匯入回畫面 —— 一批只通知一次，不是每個檔一次。
    fn on_received(&self, notebook_id: &str, files: u32);
    /// 連線的對端數量變了（給介面顯示「區網直連中」）。
    fn on_peers_changed(&self, count: u32) {
        let _ = count;
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "t", rename_all = "lowercase")]
enum Message {
    Ready {
        device: u32,
    },
    Ping,
    Have {
        nb: String,
        files: Vec<LanFile>,
    },
    Want {
        nb: String,
        kind: LanKind,
        name: String,
    },
    /// 位元組跟在標頭後面（見 `encode_frame`）。
    File {
        nb: String,
        kind: LanKind,
        name: String,
    },
    /// 對方沒有你要的東西（檔案剛被壓實掉之類）。要告訴對方，
    /// 否則它會一直等著一個永遠不來的檔案。
    Missing {
        nb: String,
    },
}

fn sha256(parts: &[&[u8]]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    for part in parts {
        hasher.update(part);
    }
    hasher.finalize().into()
}

/// 金鑰標籤：金鑰的單向雜湊前 8 位元組。
pub fn key_tag(key: &LanKey) -> [u8; 8] {
    let digest = sha256(&[b"kairumo-lan-tag-v1", key]);
    let mut tag = [0u8; 8];
    tag.copy_from_slice(&digest[..8]);
    tag
}

/// 標籤的十六進位字串，放進 Bonjour / NSD 的 TXT 記錄裡，讓不同帳號的
/// 裝置在**發現階段**就互相略過。
pub fn key_tag_hex(key: &LanKey) -> String {
    key_tag(key).iter().map(|b| format!("{b:02x}")).collect()
}

fn session_key(key: &LanKey, client_nonce: &[u8; 16], server_nonce: &[u8; 16]) -> SessionKey {
    SessionKey::from_bytes(sha256(&[
        b"kairumo-lan-session-v1",
        key,
        client_nonce,
        server_nonce,
    ]))
}

fn random16() -> io::Result<[u8; 16]> {
    let mut out = [0u8; 16];
    getrandom::getrandom(&mut out).map_err(|e| io::Error::other(e.to_string()))?;
    Ok(out)
}

/// 由誰主動連線：**裝置 id 較小的那一方**。
///
/// 兩邊都用 Bonjour 找到對方，如果都主動連就會有兩條連線，而各自「保留
/// 一條、關掉另一條」在雙方同時做的時候會挑到不同的那條，結果兩條都關了。
/// 用一個雙方都算得出來的規則打破對稱，就不需要協商。
pub fn should_initiate(my_device: u32, peer_device: u32) -> bool {
    my_device < peer_device
}

fn write_frame(stream: &mut TcpStream, sealed: &[u8]) -> io::Result<()> {
    let len = u32::try_from(sealed.len()).map_err(|_| io::Error::other("訊框太大"))?;
    stream.write_all(&len.to_be_bytes())?;
    stream.write_all(sealed)?;
    stream.flush()
}

fn read_frame(stream: &mut TcpStream) -> io::Result<Vec<u8>> {
    let mut len = [0u8; 4];
    stream.read_exact(&mut len)?;
    let len = u32::from_be_bytes(len) as usize;
    if len > MAX_FRAME_BYTES + 4096 {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "訊框超過上限"));
    }
    let mut buf = vec![0u8; len];
    stream.read_exact(&mut buf)?;
    Ok(buf)
}

/// 明文：`dir(1) | header_len(4) | header JSON | body`。
fn encode_plain(dir: u8, message: &Message, body: &[u8]) -> io::Result<Vec<u8>> {
    let header = serde_json::to_vec(message).map_err(io::Error::other)?;
    let mut out = Vec::with_capacity(5 + header.len() + body.len());
    out.push(dir);
    out.extend_from_slice(&(header.len() as u32).to_be_bytes());
    out.extend_from_slice(&header);
    out.extend_from_slice(body);
    Ok(out)
}

fn decode_plain(expected_dir: u8, plain: &[u8]) -> io::Result<(Message, Vec<u8>)> {
    let bad = |m: &'static str| io::Error::new(io::ErrorKind::InvalidData, m);
    if plain.len() < 5 {
        return Err(bad("訊框太短"));
    }
    if plain[0] != expected_dir {
        return Err(bad("方向不符（疑似反射）"));
    }
    let header_len = u32::from_be_bytes([plain[1], plain[2], plain[3], plain[4]]) as usize;
    let header = plain
        .get(5..5 + header_len)
        .ok_or_else(|| bad("標頭超出訊框"))?;
    let message = serde_json::from_slice(header).map_err(|_| bad("標頭不是合法訊息"))?;
    Ok((message, plain[5 + header_len..].to_vec()))
}

/// 一個已認證的連線的寫入端。讀取在自己的執行緒裡。
struct Peer {
    device: u32,
    writer: Mutex<TcpStream>,
    key: SessionKey,
    /// 我送出去的訊框用哪個方向位元組。
    send_dir: u8,
}

impl Peer {
    fn send(&self, message: &Message, body: &[u8]) -> io::Result<()> {
        let plain = encode_plain(self.send_dir, message, body)?;
        let sealed = self
            .key
            .seal(&plain)
            .map_err(|_| io::Error::other("加密失敗"))?;
        let mut stream = self
            .writer
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        write_frame(&mut stream, &sealed)
    }

    fn close(&self) {
        let stream = self
            .writer
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let _ = stream.shutdown(Shutdown::Both);
    }
}

struct Inner {
    key: LanKey,
    device_id: u32,
    store: Arc<dyn LanStore>,
    peers: Mutex<HashMap<u64, Arc<Peer>>>,
    /// 正在連線中的對端裝置，避免同一個對端被發現兩次就開兩條。
    connecting: Mutex<HashSet<u32>>,
    next_conn: AtomicU64,
    stopped: AtomicBool,
    port: u16,
}

/// 區網節點：監聽、被連、主動連、廣播「我有新東西」。
pub struct LanNode {
    inner: Arc<Inner>,
}

impl std::fmt::Debug for LanNode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LanNode")
            .field("device_id", &self.inner.device_id)
            .field("port", &self.inner.port)
            .finish()
    }
}

impl LanNode {
    /// 開始監聽（隨機埠）。平台要把 [`Self::port`] 註冊到 Bonjour / NSD。
    pub fn start(key: LanKey, device_id: u32, store: Arc<dyn LanStore>) -> io::Result<Self> {
        let listener = TcpListener::bind(("0.0.0.0", 0))?;
        let port = listener.local_addr()?.port();
        let inner = Arc::new(Inner {
            key,
            device_id,
            store,
            peers: Mutex::new(HashMap::new()),
            connecting: Mutex::new(HashSet::new()),
            next_conn: AtomicU64::new(1),
            stopped: AtomicBool::new(false),
            port,
        });
        let accept_inner = Arc::clone(&inner);
        thread::Builder::new()
            .name("kairumo-lan-accept".into())
            .spawn(move || accept_loop(accept_inner, listener))?;
        Ok(Self { inner })
    }

    pub fn port(&self) -> u16 {
        self.inner.port
    }

    pub fn device_id(&self) -> u32 {
        self.inner.device_id
    }

    pub fn tag_hex(&self) -> String {
        key_tag_hex(&self.inner.key)
    }

    pub fn peer_count(&self) -> u32 {
        self.inner.peers.lock().unwrap().len() as u32
    }

    pub fn is_connected_to(&self, device: u32) -> bool {
        self.inner
            .peers
            .lock()
            .unwrap()
            .values()
            .any(|p| p.device == device)
    }

    /// 平台發現了一台同帳號的裝置。**可以重複呼叫** —— Bonjour 會一直回報，
    /// 已經連著或正在連就直接略過。
    pub fn connect(&self, peer_device: u32, host: &str, port: u16) {
        if peer_device == self.inner.device_id
            || !should_initiate(self.inner.device_id, peer_device)
            || self.is_connected_to(peer_device)
        {
            return;
        }
        if !self.inner.connecting.lock().unwrap().insert(peer_device) {
            return;
        }
        let inner = Arc::clone(&self.inner);
        let host = host.to_string();
        let spawned = thread::Builder::new()
            .name("kairumo-lan-dial".into())
            .spawn(move || {
                let result = dial(&inner, peer_device, &host, port);
                inner.connecting.lock().unwrap().remove(&peer_device);
                // 連不上是常態（對方剛離線、位址過期）。安靜地放掉，
                // 下一次發現會再試。
                if let Ok((peer, stream)) = result {
                    run_connection(inner, peer, stream);
                }
            });
        if spawned.is_err() {
            self.inner.connecting.lock().unwrap().remove(&peer_device);
        }
    }

    /// 這本筆記本剛存檔完 —— 告訴所有對端「我現在有這些檔案」。
    ///
    /// 只送檔名與大小（幾百位元組）。對端自己比，需要什麼再要。
    /// 這樣即使對端已經有了，成本也只有一個小訊框。
    pub fn announce(&self, notebook_id: &str) {
        let Some(files) = self.inner.store.list(notebook_id) else {
            return;
        };
        let peers: Vec<Arc<Peer>> = self.inner.peers.lock().unwrap().values().cloned().collect();
        let message = Message::Have {
            nb: notebook_id.to_string(),
            files,
        };
        for peer in peers {
            if peer.send(&message, &[]).is_err() {
                peer.close();
            }
        }
    }

    /// 停止：關掉所有連線，不再接受新的。
    pub fn stop(&self) {
        self.inner.stopped.store(true, Ordering::SeqCst);
        // 喚醒卡在 accept 的執行緒。
        let _ = TcpStream::connect_timeout(
            &std::net::SocketAddr::from(([127, 0, 0, 1], self.inner.port)),
            Duration::from_millis(200),
        );
        let peers: Vec<Arc<Peer>> = self
            .inner
            .peers
            .lock()
            .unwrap()
            .drain()
            .map(|(_, p)| p)
            .collect();
        for peer in peers {
            peer.close();
        }
        self.inner.store.on_peers_changed(0);
    }
}

impl Drop for LanNode {
    fn drop(&mut self) {
        self.stop();
    }
}

fn accept_loop(inner: Arc<Inner>, listener: TcpListener) {
    for stream in listener.incoming() {
        if inner.stopped.load(Ordering::SeqCst) {
            return;
        }
        let Ok(stream) = stream else { continue };
        let inner = Arc::clone(&inner);
        let _ = thread::Builder::new()
            .name("kairumo-lan-conn".into())
            .spawn(move || {
                if let Ok((peer, stream)) = accept_handshake(&inner, stream) {
                    run_connection(inner, peer, stream);
                }
            });
    }
}

fn dial(
    inner: &Inner,
    peer_device: u32,
    host: &str,
    port: u16,
) -> io::Result<(Arc<Peer>, TcpStream)> {
    let addr = (host, port)
        .to_socket_addrs()?
        .next()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "解析不到位址"))?;
    let mut stream = TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT)?;
    stream.set_nodelay(true)?;
    stream.set_read_timeout(Some(HANDSHAKE_TIMEOUT))?;
    stream.set_write_timeout(Some(WRITE_TIMEOUT))?;

    let client_nonce = random16()?;
    let mut hello = Vec::with_capacity(4 + 16 + 4 + 8);
    hello.extend_from_slice(MAGIC);
    hello.extend_from_slice(&client_nonce);
    hello.extend_from_slice(&inner.device_id.to_be_bytes());
    hello.extend_from_slice(&key_tag(&inner.key));
    stream.write_all(&hello)?;

    let mut reply = [0u8; 4 + 16 + 4];
    stream.read_exact(&mut reply)?;
    if &reply[..4] != MAGIC {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "魔數不符"));
    }
    let mut server_nonce = [0u8; 16];
    server_nonce.copy_from_slice(&reply[4..20]);
    let announced = u32::from_be_bytes([reply[20], reply[21], reply[22], reply[23]]);
    if announced != peer_device {
        // Bonjour 說的是一個人，握手裡是另一個人 —— 位址過期或有人冒充。
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "對端裝置 id 不符",
        ));
    }
    let key = session_key(&inner.key, &client_nonce, &server_nonce);

    // 伺服端的第一個訊框必須解得開 —— 那是它有金鑰的證明。
    let plain = key
        .open(&read_frame(&mut stream)?)
        .map_err(|_| io::Error::new(io::ErrorKind::PermissionDenied, "金鑰不符"))?;
    match decode_plain(DIR_SERVER, &plain)?.0 {
        Message::Ready { device } if device == peer_device => {}
        _ => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "第一個訊框不是 Ready",
            ));
        }
    }

    let peer = Arc::new(Peer {
        device: peer_device,
        writer: Mutex::new(stream.try_clone()?),
        key,
        send_dir: DIR_CLIENT,
    });
    peer.send(
        &Message::Ready {
            device: inner.device_id,
        },
        &[],
    )?;
    Ok((peer, stream))
}

fn accept_handshake(inner: &Inner, mut stream: TcpStream) -> io::Result<(Arc<Peer>, TcpStream)> {
    stream.set_nodelay(true)?;
    stream.set_read_timeout(Some(HANDSHAKE_TIMEOUT))?;
    stream.set_write_timeout(Some(WRITE_TIMEOUT))?;

    let mut hello = [0u8; 4 + 16 + 4 + 8];
    stream.read_exact(&mut hello)?;
    if &hello[..4] != MAGIC {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "魔數不符"));
    }
    let mut client_nonce = [0u8; 16];
    client_nonce.copy_from_slice(&hello[4..20]);
    let client_device = u32::from_be_bytes([hello[20], hello[21], hello[22], hello[23]]);
    // 標籤不符就**不回任何東西**直接斷線：不讓別人的裝置知道這裡有人在聽。
    if hello[24..32] != key_tag(&inner.key) {
        return Err(io::Error::new(io::ErrorKind::PermissionDenied, "標籤不符"));
    }
    // 只接受「該由對方主動連我」的連線，與 `should_initiate` 對稱。
    if client_device == inner.device_id || !should_initiate(client_device, inner.device_id) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "不該由這一方連過來",
        ));
    }

    let server_nonce = random16()?;
    let mut reply = Vec::with_capacity(4 + 16 + 4);
    reply.extend_from_slice(MAGIC);
    reply.extend_from_slice(&server_nonce);
    reply.extend_from_slice(&inner.device_id.to_be_bytes());
    stream.write_all(&reply)?;
    let key = session_key(&inner.key, &client_nonce, &server_nonce);

    let peer = Arc::new(Peer {
        device: client_device,
        writer: Mutex::new(stream.try_clone()?),
        key,
        send_dir: DIR_SERVER,
    });
    peer.send(
        &Message::Ready {
            device: inner.device_id,
        },
        &[],
    )?;

    let plain = peer
        .key
        .open(&read_frame(&mut stream)?)
        .map_err(|_| io::Error::new(io::ErrorKind::PermissionDenied, "金鑰不符"))?;
    match decode_plain(DIR_CLIENT, &plain)?.0 {
        Message::Ready { device } if device == client_device => {}
        _ => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "第一個訊框不是 Ready",
            ));
        }
    }
    Ok((peer, stream))
}

/// 每個連線一條執行緒：登錄、先報一次我有什麼、然後讀到斷線為止。
fn run_connection(inner: Arc<Inner>, peer: Arc<Peer>, mut stream: TcpStream) {
    // 同一個裝置只留一條：已經有就丟掉這條新的。
    let conn_id = inner.next_conn.fetch_add(1, Ordering::SeqCst);
    {
        let mut peers = inner.peers.lock().unwrap();
        if peers.values().any(|p| p.device == peer.device) {
            drop(peers);
            peer.close();
            return;
        }
        peers.insert(conn_id, Arc::clone(&peer));
        inner.store.on_peers_changed(peers.len() as u32);
    }

    let _ = stream.set_read_timeout(Some(PING_EVERY));
    let recv_dir = if peer.send_dir == DIR_CLIENT {
        DIR_SERVER
    } else {
        DIR_CLIENT
    };

    // 剛連上就把焦點那一本報給對方：對方可能剛打開這本，
    // 而我這邊已經有它還沒看到的東西。
    if let Some(nb) = inner.store.focused_notebook()
        && let Some(files) = inner.store.list(&nb)
    {
        let _ = peer.send(&Message::Have { nb, files }, &[]);
    }

    let mut state = ReceiveState::default();
    let mut silent_for = Duration::ZERO;
    loop {
        if inner.stopped.load(Ordering::SeqCst) {
            break;
        }
        match read_frame(&mut stream) {
            Ok(sealed) => {
                silent_for = Duration::ZERO;
                let Ok(plain) = peer.key.open(&sealed) else {
                    break;
                };
                let Ok((message, body)) = decode_plain(recv_dir, &plain) else {
                    break;
                };
                if handle_message(&inner, &peer, &mut state, message, body).is_err() {
                    break;
                }
            }
            Err(e)
                if matches!(
                    e.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                silent_for += PING_EVERY;
                if silent_for >= DEAD_AFTER || peer.send(&Message::Ping, &[]).is_err() {
                    break;
                }
            }
            Err(_) => break,
        }
    }

    peer.close();
    let mut peers = inner.peers.lock().unwrap();
    peers.remove(&conn_id);
    inner.store.on_peers_changed(peers.len() as u32);
}

/// 這條連線上「我要了但還沒收完」的東西。收齊一批才通知平台一次。
#[derive(Default)]
struct ReceiveState {
    /// 筆記本 → (還在等幾個, 已經寫進去幾個)
    pending: HashMap<String, (u32, u32)>,
}

fn handle_message(
    inner: &Inner,
    peer: &Peer,
    state: &mut ReceiveState,
    message: Message,
    body: Vec<u8>,
) -> io::Result<()> {
    match message {
        Message::Ready { .. } | Message::Ping => Ok(()),
        Message::Have { nb, files } => {
            let Some(local) = inner.store.list(&nb) else {
                return Ok(());
            };
            let have: HashMap<(LanKind, &str), u64> = local
                .iter()
                .map(|f| ((f.kind, f.name.as_str()), f.size))
                .collect();
            let mut wanted = 0u32;
            for file in &files {
                if !is_safe_name(&file.name) || !inner.store.accepts(&nb, file.kind, &file.name) {
                    continue;
                }
                let mine = have
                    .get(&(file.kind, file.name.as_str()))
                    .copied()
                    .unwrap_or(0);
                // 只要**較長**的：append-only ⇒ 較長者是超集。
                if file.size > mine && (file.size as usize) <= MAX_FRAME_BYTES {
                    peer.send(
                        &Message::Want {
                            nb: nb.clone(),
                            kind: file.kind,
                            name: file.name.clone(),
                        },
                        &[],
                    )?;
                    wanted += 1;
                }
            }
            if wanted > 0 {
                let entry = state.pending.entry(nb).or_insert((0, 0));
                entry.0 += wanted;
            }
            Ok(())
        }
        Message::Want { nb, kind, name } => {
            if !is_safe_name(&name) {
                return Ok(());
            }
            match inner.store.read(&nb, kind, &name) {
                Some(bytes) if bytes.len() <= MAX_FRAME_BYTES => {
                    peer.send(&Message::File { nb, kind, name }, &bytes)
                }
                _ => peer.send(&Message::Missing { nb }, &[]),
            }
        }
        Message::File { nb, kind, name } => {
            let wrote = is_safe_name(&name) && inner.store.write(&nb, kind, &name, &body);
            settle(inner, state, &nb, u32::from(wrote));
            Ok(())
        }
        Message::Missing { nb } => {
            settle(inner, state, &nb, 0);
            Ok(())
        }
    }
}

/// 一個要的檔案有了結果（寫進去了、或對方沒有）。最後一個到的時候
/// 才通知平台，而且只在真的有寫入時。
fn settle(inner: &Inner, state: &mut ReceiveState, nb: &str, wrote: u32) {
    let Some(entry) = state.pending.get_mut(nb) else {
        // 沒要過的檔案也送來了：不理它。
        return;
    };
    entry.0 = entry.0.saturating_sub(1);
    entry.1 += wrote;
    if entry.0 == 0 {
        let total = entry.1;
        state.pending.remove(nb);
        if total > 0 {
            inner.store.on_received(nb, total);
        }
    }
}

/// 檔名來自網路，是不可信輸入。真正的路徑驗證在 `LanStore::write`
/// （它知道套件的佈局），這裡先擋最明顯的：路徑分隔、上層目錄、空字串。
fn is_safe_name(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= 200
        && !name.contains(['/', '\\', '\0'])
        && name != "."
        && name != ".."
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Condvar;
    use std::time::Instant;

    type Book = HashMap<(LanKind, String), Vec<u8>>;

    /// 記憶體版儲存：`筆記本 → (種類, 檔名) → 位元組`。
    #[derive(Default)]
    struct MemStore {
        focused: Mutex<Option<String>>,
        books: Mutex<HashMap<String, Book>>,
        received: Mutex<Vec<(String, u32)>>,
        peers: Mutex<u32>,
        signal: Condvar,
    }

    impl MemStore {
        fn new(focused: Option<&str>) -> Arc<Self> {
            let store = Arc::new(Self::default());
            *store.focused.lock().unwrap() = focused.map(str::to_string);
            store
        }

        fn put(&self, nb: &str, kind: LanKind, name: &str, bytes: &[u8]) {
            self.books
                .lock()
                .unwrap()
                .entry(nb.to_string())
                .or_default()
                .insert((kind, name.to_string()), bytes.to_vec());
        }

        fn get(&self, nb: &str, kind: LanKind, name: &str) -> Option<Vec<u8>> {
            self.books
                .lock()
                .unwrap()
                .get(nb)?
                .get(&(kind, name.to_string()))
                .cloned()
        }

        fn wait_until(&self, what: &str, mut ok: impl FnMut(&Self) -> bool) {
            let deadline = Instant::now() + Duration::from_secs(5);
            let guard = self.received.lock().unwrap();
            let mut guard = guard;
            while !ok(self) {
                let left = deadline.saturating_duration_since(Instant::now());
                assert!(!left.is_zero(), "等不到：{what}");
                guard = self
                    .signal
                    .wait_timeout(guard, left.min(Duration::from_millis(50)))
                    .unwrap()
                    .0;
            }
        }

        /// 等到接收完成回呼也已送達。
        ///
        /// 檔案寫入發生在 `on_received` 之前；只等檔案出現後立刻檢查
        /// `received` 仍有一個很小的競態窗口，CI 偶爾會看到空陣列。
        fn wait_received(&self, notebook_id: &str, files: u32) {
            let expected = (notebook_id.to_string(), files);
            let deadline = Instant::now() + Duration::from_secs(5);
            let mut received = self.received.lock().unwrap();
            while !received.contains(&expected) {
                let left = deadline.saturating_duration_since(Instant::now());
                assert!(!left.is_zero(), "等不到接收完成回呼：{notebook_id}");
                received = self
                    .signal
                    .wait_timeout(received, left.min(Duration::from_millis(50)))
                    .unwrap()
                    .0;
            }
        }
    }

    impl LanStore for MemStore {
        fn focused_notebook(&self) -> Option<String> {
            self.focused.lock().unwrap().clone()
        }
        fn list(&self, nb: &str) -> Option<Vec<LanFile>> {
            let books = self.books.lock().unwrap();
            let book = books.get(nb)?;
            let mut files: Vec<LanFile> = book
                .iter()
                .map(|((kind, name), bytes)| LanFile {
                    kind: *kind,
                    name: name.clone(),
                    size: bytes.len() as u64,
                })
                .collect();
            files.sort_by(|a, b| a.name.cmp(&b.name));
            Some(files)
        }
        fn read(&self, nb: &str, kind: LanKind, name: &str) -> Option<Vec<u8>> {
            self.get(nb, kind, name)
        }
        fn write(&self, nb: &str, kind: LanKind, name: &str, bytes: &[u8]) -> bool {
            let mut books = self.books.lock().unwrap();
            let Some(book) = books.get_mut(nb) else {
                return false;
            };
            let current = book.get(&(kind, name.to_string())).map_or(0, Vec::len);
            if bytes.len() <= current {
                return false;
            }
            book.insert((kind, name.to_string()), bytes.to_vec());
            true
        }
        fn on_received(&self, nb: &str, files: u32) {
            self.received.lock().unwrap().push((nb.to_string(), files));
            self.signal.notify_all();
        }
        fn on_peers_changed(&self, count: u32) {
            *self.peers.lock().unwrap() = count;
            self.signal.notify_all();
        }
    }

    const KEY: LanKey = [7u8; 32];

    /// 兩個節點：`a`（id 1，會主動連）與 `b`（id 2）。
    fn pair(
        key_a: LanKey,
        key_b: LanKey,
        focus_a: Option<&str>,
        focus_b: Option<&str>,
    ) -> (LanNode, Arc<MemStore>, LanNode, Arc<MemStore>) {
        let sa = MemStore::new(focus_a);
        let sb = MemStore::new(focus_b);
        let a = LanNode::start(key_a, 1, sa.clone()).unwrap();
        let b = LanNode::start(key_b, 2, sb.clone()).unwrap();
        (a, sa, b, sb)
    }

    fn connect(a: &LanNode, b: &LanNode) {
        a.connect(2, "127.0.0.1", b.port());
    }

    fn wait_connected(a: &LanNode, b: &LanNode, sa: &MemStore) {
        sa.wait_until("兩端都連上", |_| {
            a.peer_count() == 1 && b.peer_count() == 1
        });
    }

    #[test]
    fn the_smaller_device_id_dials() {
        assert!(should_initiate(1, 2));
        assert!(!should_initiate(2, 1));
        assert!(!should_initiate(3, 3));
    }

    #[test]
    fn an_announced_file_arrives_on_the_other_side() {
        let (a, sa, b, sb) = pair(KEY, KEY, Some("nb"), Some("nb"));
        sa.put("nb", LanKind::Ops, "0000000005-00000001.ops", b"hello");
        sb.put("nb", LanKind::Ops, "seed", b"x");
        connect(&a, &b);
        wait_connected(&a, &b, &sa);

        // 連上時 A 就報了焦點那本，B 該已經要走了那個檔。
        sb.wait_until("B 收到 A 的檔", |s| {
            s.get("nb", LanKind::Ops, "0000000005-00000001.ops")
                .is_some()
        });
        // `write` 完成後才呼叫 `on_received`。若不另外等回呼，下面的斷言
        // 偶爾會落在兩者之間，檔案已存在但事件陣列仍是空的。
        sb.wait_received("nb", 1);
        assert_eq!(
            sb.get("nb", LanKind::Ops, "0000000005-00000001.ops"),
            Some(b"hello".to_vec())
        );
        assert_eq!(
            sb.received.lock().unwrap().as_slice(),
            &[("nb".to_string(), 1)]
        );
    }

    #[test]
    fn a_later_edit_is_pushed_by_announce() {
        let (a, sa, b, sb) = pair(KEY, KEY, Some("nb"), Some("nb"));
        sa.put("nb", LanKind::Ink, "p0.strokes", b"one");
        sb.put("nb", LanKind::Ink, "seed", b"x");
        connect(&a, &b);
        wait_connected(&a, &b, &sa);
        sb.wait_until("第一版", |s| {
            s.get("nb", LanKind::Ink, "p0.strokes").is_some()
        });

        // 檔案變長（append-only）。
        sa.put("nb", LanKind::Ink, "p0.strokes", b"one-two");
        a.announce("nb");
        sb.wait_until("第二版", |s| {
            s.get("nb", LanKind::Ink, "p0.strokes") == Some(b"one-two".to_vec())
        });
    }

    #[test]
    fn a_pushed_edit_arrives_in_a_fraction_of_a_second() {
        // 區網存在的理由就是「比 Drive 快一個數量級」。Drive 的下限是 2–3 秒，
        // 這裡的預算是 1 秒（迴路上實際是幾毫秒；留寬是為了慢的 CI 機器）。
        let (a, sa, b, sb) = pair(KEY, KEY, Some("nb"), Some("nb"));
        sa.put("nb", LanKind::Ink, "p.strokes", b"first");
        sb.put("nb", LanKind::Ink, "seed", b"x");
        connect(&a, &b);
        wait_connected(&a, &b, &sa);
        sb.wait_until("初始同步", |s| {
            s.get("nb", LanKind::Ink, "p.strokes").is_some()
        });

        sa.put("nb", LanKind::Ink, "p.strokes", b"first-and-more");
        let started = Instant::now();
        a.announce("nb");
        sb.wait_until("增量到達", |s| {
            s.get("nb", LanKind::Ink, "p.strokes") == Some(b"first-and-more".to_vec())
        });
        let elapsed = started.elapsed();
        assert!(
            elapsed < Duration::from_secs(1),
            "區網一次更新花了 {elapsed:?}，不比 Drive 快就沒有存在的理由"
        );
    }

    #[test]
    fn data_flows_from_the_larger_id_to_the_smaller_too() {
        let (a, sa, b, sb) = pair(KEY, KEY, Some("nb"), Some("nb"));
        sa.put("nb", LanKind::Ops, "seed", b"x");
        connect(&a, &b);
        wait_connected(&a, &b, &sa);

        sb.put("nb", LanKind::Ops, "from-b", b"bbb");
        b.announce("nb");
        sa.wait_until("A 收到 B 的檔", |s| {
            s.get("nb", LanKind::Ops, "from-b").is_some()
        });
    }

    #[test]
    fn a_shorter_file_is_never_requested() {
        let (a, sa, b, sb) = pair(KEY, KEY, Some("nb"), Some("nb"));
        sa.put("nb", LanKind::Ops, "f", b"ab");
        sb.put("nb", LanKind::Ops, "f", b"abcdef");
        connect(&a, &b);
        wait_connected(&a, &b, &sa);
        a.announce("nb");
        std::thread::sleep(Duration::from_millis(300));
        assert_eq!(sb.get("nb", LanKind::Ops, "f"), Some(b"abcdef".to_vec()));
        assert!(sb.received.lock().unwrap().is_empty());
    }

    #[test]
    fn a_notebook_the_receiver_does_not_have_is_ignored() {
        let (a, sa, b, sb) = pair(KEY, KEY, Some("nb"), None);
        sa.put("nb", LanKind::Ops, "f", b"data");
        connect(&a, &b);
        wait_connected(&a, &b, &sa);
        a.announce("nb");
        std::thread::sleep(Duration::from_millis(300));
        assert!(
            sb.books.lock().unwrap().is_empty(),
            "區網不負責建立整本筆記"
        );
    }

    #[test]
    fn a_wrong_key_never_connects() {
        let (a, _sa, b, _sb) = pair(KEY, [9u8; 32], Some("nb"), Some("nb"));
        connect(&a, &b);
        std::thread::sleep(Duration::from_millis(500));
        assert_eq!(a.peer_count(), 0);
        assert_eq!(b.peer_count(), 0);
    }

    #[test]
    fn the_larger_id_does_not_dial() {
        let (a, _sa, b, _sb) = pair(KEY, KEY, None, None);
        b.connect(1, "127.0.0.1", a.port());
        std::thread::sleep(Duration::from_millis(300));
        assert_eq!(a.peer_count(), 0);
        assert_eq!(b.peer_count(), 0);
    }

    #[test]
    fn discovering_the_same_peer_twice_makes_one_connection() {
        let (a, sa, b, _sb) = pair(KEY, KEY, None, None);
        for _ in 0..5 {
            connect(&a, &b);
        }
        wait_connected(&a, &b, &sa);
        std::thread::sleep(Duration::from_millis(200));
        assert_eq!(a.peer_count(), 1);
        assert_eq!(b.peer_count(), 1);
    }

    #[test]
    fn a_claimed_id_that_does_not_match_discovery_is_refused() {
        let (a, _sa, b, _sb) = pair(KEY, KEY, None, None);
        // 發現階段說對方是 99，握手裡它自稱 2。
        a.connect(99, "127.0.0.1", b.port());
        std::thread::sleep(Duration::from_millis(400));
        assert_eq!(a.peer_count(), 0);
        assert_eq!(b.peer_count(), 0);
    }

    #[test]
    fn unsafe_names_from_the_network_are_never_written() {
        let (a, sa, b, sb) = pair(KEY, KEY, Some("nb"), Some("nb"));
        sa.put("nb", LanKind::Ops, "../evil", b"data");
        sa.put("nb", LanKind::Ops, "good", b"data");
        sb.put("nb", LanKind::Ops, "seed", b"x");
        connect(&a, &b);
        wait_connected(&a, &b, &sa);
        sb.wait_until("好檔案到了", |s| {
            s.get("nb", LanKind::Ops, "good").is_some()
        });
        assert!(sb.get("nb", LanKind::Ops, "../evil").is_none());
    }

    #[test]
    fn stopping_drops_the_connection_on_both_sides() {
        let (a, sa, b, sb) = pair(KEY, KEY, None, None);
        connect(&a, &b);
        wait_connected(&a, &b, &sa);
        a.stop();
        sb.wait_until("B 發現斷線", |_| b.peer_count() == 0);
    }

    #[test]
    fn frames_replayed_with_the_wrong_direction_are_rejected() {
        let plain = encode_plain(DIR_CLIENT, &Message::Ping, &[]).unwrap();
        assert!(decode_plain(DIR_CLIENT, &plain).is_ok());
        assert!(decode_plain(DIR_SERVER, &plain).is_err(), "反射要擋掉");
    }

    #[test]
    fn the_tag_does_not_reveal_the_key() {
        let tag = key_tag_hex(&KEY);
        assert_eq!(tag.len(), 16);
        assert!(!tag.contains("0707070707070707") || KEY.iter().all(|b| *b == 7));
        assert_ne!(key_tag(&KEY), key_tag(&[8u8; 32]));
    }

    #[test]
    fn safe_names() {
        assert!(is_safe_name("0000000005-00000001.ops"));
        assert!(!is_safe_name(""));
        assert!(!is_safe_name(".."));
        assert!(!is_safe_name("a/b"));
        assert!(!is_safe_name("a\\b"));
    }
}

// Kairumo 協同中繼 —— Cloudflare Workers + Durable Objects 版。
//
// 與 `crates/padnote-relay`（Rust，App 內建的本機中繼與自架用）**同一套線上協定**：
// 訊息格式見 `crates/padnote-relay/src/protocol.rs`，行為見 `hub.rs`。改協定時兩邊一起改。
//
// # 架構
//
// - 每個房間是一個 Durable Object（以房號命名）。客戶端連線網址帶 `?room=<房號>`，
//   Worker 依它把連線交給那個房間；之後 `join` 的房號必須與它相同。
// - 用 WebSocket Hibernation API（`ctx.acceptWebSocket`）：房間閒置時物件休眠、不計時長費用。
//   每條連線的身分存在連線本身（`serializeAttachment`），休眠醒來還在。
// - 補發暫存（斷線重連用）存在物件的 SQLite 裡，上限與 Rust 版相同（2000 筆／32 MB）。
//   書寫中預覽（`live_`）與整份狀態（`state_`）只轉送、不暫存。
// - 心跳 `{"type":"ping"}` 由平台自動回 `{"type":"pong"}`，不喚醒物件。
// - 內容是端對端加密的（房間金鑰只在參與者手上），中繼看不到筆跡與物件。

export interface Env {
  ROOMS: DurableObjectNamespace;
  MAX_PEERS?: string;
  LOCATION_HINT?: string;
}

const RECENT_MAX_COUNT = 2000;
const RECENT_MAX_BYTES = 32 * 1024 * 1024;

/** 只轉送、不暫存（見 Rust `is_transient_kind`）。 */
function isTransientKind(kind: string): boolean {
  return kind.startsWith("state_") || kind.startsWith("live_");
}

interface PeerInfo {
  user_id: string;
  user_name: string;
  user_color: string;
  role: string;
}

/** 存在每條連線上的身分。`replaced` = 同一個人從另一條連線重新加入了，這條不再代表他。 */
interface Attachment {
  joined: boolean;
  room: string;
  peer?: PeerInfo;
  replaced?: boolean;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("Kairumo relay\n", { status: 200 });
    }
    const room = url.searchParams.get("room")?.trim() ?? "";
    // 房號只在這裡決定房間；限制長度與字元，避免任意字串建出大量物件。
    if (!/^[A-Za-z0-9._-]{4,128}$/.test(room)) {
      return new Response("missing or invalid ?room=", { status: 400 });
    }
    // 房間物件第一次建立時落在哪個區域就一直在那裡。預設不指定：建在第一位使用者連到的
    // Cloudflare 機房附近。實測：台灣（HiNet）的免費方案流量被導到聖荷西（SJC）機房，
    // 這時指定亞太反而多繞一趟太平洋（單向約 150 ms → 320 ms）。真的需要時可用 `LOCATION_HINT`。
    const hint = env.LOCATION_HINT as DurableObjectLocationHint | undefined;
    const id = env.ROOMS.idFromName(room);
    const stub = hint ? env.ROOMS.get(id, { locationHint: hint }) : env.ROOMS.get(id);
    return stub.fetch(request);
  },
};

export class RelayRoom implements DurableObject {
  private readonly sql: SqlStorage;

  // 補發暫存的筆數、總位元組與下一個序號放在記憶體，不在每一筆都讀寫資料庫：
  // Cloudflare 免費方案按「讀到的列數／寫入的列數」計額度，`COUNT(*)` 會把整張表讀一遍
  // （最多 2000 列），每筆再寫兩列計數器，額度很快就用完。物件休眠醒來後記憶體是空的，
  // 第一次用到時從資料表重算一次（`loadCounters`）。
  private counted = false;
  private count = 0;
  private bytes = 0;
  private nextSeq = 1;

  constructor(private readonly ctx: DurableObjectState, private readonly env: Env) {
    this.sql = ctx.storage.sql;
    this.sql.exec(
      "CREATE TABLE IF NOT EXISTS ops (seq INTEGER PRIMARY KEY, lamport INTEGER NOT NULL, size INTEGER NOT NULL, msg TEXT NOT NULL)",
    );
    this.sql.exec("CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)");
    ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair('{"type":"ping"}', '{"type":"pong"}'),
    );
  }

  async fetch(request: Request): Promise<Response> {
    const room = new URL(request.url).searchParams.get("room") ?? "";
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ joined: false, room } satisfies Attachment);
    return new Response(null, { status: 101, webSocket: client });
  }

  // ---- 連線事件 ----

  async webSocketMessage(ws: WebSocket, data: string | ArrayBuffer): Promise<void> {
    const text = typeof data === "string" ? data : new TextDecoder().decode(data);
    let msg: any;
    try {
      msg = JSON.parse(text);
    } catch {
      this.send(ws, { type: "error", code: "INVALID_FORMAT", message: "無法解析之訊息格式" });
      return;
    }
    const me = this.attachment(ws);
    // 加入之後的每一則訊息只能作用在這條連線加入的房間、以那個身分（與 Rust 版相同）。
    const bound = (roomId: unknown, userId: unknown) =>
      me.joined && me.room === roomId && me.peer?.user_id === userId && !me.replaced;

    switch (msg?.type) {
      case "join":
        this.join(ws, me, msg);
        return;
      case "presence":
        if (!bound(msg.room_id, msg.user_id)) return;
        this.broadcast(me.peer!.user_id, {
          type: "peer_presence",
          room_id: me.room,
          user_id: me.peer!.user_id,
          cursor: msg.cursor,
          selected_id: msg.selected_id ?? null,
        });
        return;
      case "oplog":
        if (!bound(msg.room_id, msg.user_id)) return;
        this.oplog(me, msg);
        return;
      case "catchup":
        if (!me.joined || me.room !== msg.room_id) return;
        this.catchup(ws, me.room, msg);
        return;
      case "leave":
        if (!bound(msg.room_id, msg.user_id)) return;
        this.leave(ws, me);
        return;
      case "close_room":
        if (!bound(msg.room_id, msg.user_id)) return;
        this.closeRoom(ws, me);
        return;
      case "ping":
        this.send(ws, { type: "pong" });
        return;
      default:
        this.send(ws, { type: "error", code: "INVALID_FORMAT", message: "無法解析之訊息格式" });
    }
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    this.disconnected(ws);
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    this.disconnected(ws);
  }

  // ---- 協定 ----

  private join(ws: WebSocket, me: Attachment, msg: any): void {
    const roomId = String(msg.room_id ?? "");
    const userId = String(msg.user_id ?? "");
    if (roomId !== me.room || !userId) {
      this.send(ws, { type: "error", code: "JOIN_FAILED", message: "房號與連線網址不符" });
      return;
    }
    const others = this.joinedSockets().filter((s) => s !== ws);
    const sameUser = others.filter((s) => this.attachment(s).peer?.user_id === userId);
    const maxPeers = Number(this.env.MAX_PEERS ?? "16") || 16;
    if (sameUser.length === 0 && others.length >= maxPeers) {
      this.send(ws, { type: "error", code: "JOIN_FAILED", message: "這個房間的人數已達上限" });
      return;
    }

    // 第一位加入者成為房主；密碼（若有）由房主設定。
    let owner = this.meta("owner");
    if (owner === null) {
      owner = userId;
      this.setMeta("owner", owner);
      if (typeof msg.passcode === "string" && msg.passcode) this.setMeta("passcode", msg.passcode);
    }
    const passcode = this.meta("passcode");
    if (passcode !== null && msg.passcode !== passcode && owner !== userId) {
      this.send(ws, { type: "error", code: "JOIN_FAILED", message: "密碼錯誤，無法加入房間" });
      return;
    }

    // 同一個人重新加入（斷線重連）：舊連線不再代表他，關掉它但不廣播「離開」。
    for (const old of sameUser) {
      old.serializeAttachment({ ...this.attachment(old), replaced: true } satisfies Attachment);
      try {
        old.close(4000, "replaced");
      } catch {}
    }

    const role = owner === userId ? "owner" : String(msg.role ?? "editor");
    const peer: PeerInfo = {
      user_id: userId,
      user_name: String(msg.user_name ?? ""),
      user_color: String(msg.user_color ?? ""),
      role,
    };
    const existing = others
      .filter((s) => !sameUser.includes(s))
      .map((s) => this.attachment(s).peer!)
      .filter(Boolean);
    if (sameUser.length === 0) {
      this.broadcast(userId, { type: "peer_joined", room_id: roomId, peer });
    }
    ws.serializeAttachment({ joined: true, room: roomId, peer } satisfies Attachment);
    this.send(ws, { type: "joined", room_id: roomId, user_id: userId, role, peers: existing });
  }

  private oplog(me: Attachment, msg: any): void {
    const kind = String(msg.kind ?? "");
    const lamport = Number(msg.lamport ?? 0) || 0;
    const out: any = {
      type: "peer_oplog",
      room_id: me.room,
      user_id: me.peer!.user_id,
      lamport,
      kind,
      encrypted: msg.encrypted ?? null,
      payload: msg.payload ?? null,
    };
    if (!isTransientKind(kind)) {
      this.loadCounters();
      const seq = this.nextSeq;
      this.nextSeq += 1;
      out.seq = seq;
      const text = JSON.stringify(out);
      this.remember(seq, lamport, text);
      this.broadcastRaw(me.peer!.user_id, text);
      return;
    }
    this.broadcast(me.peer!.user_id, out);
  }

  /** 從資料表重算計數（物件剛醒來時）。 */
  private loadCounters(): void {
    if (this.counted) return;
    const row = this.sql.exec(
      "SELECT COUNT(*) AS n, COALESCE(SUM(size), 0) AS b, MAX(seq) AS m FROM ops",
    ).one();
    this.count = Number(row.n);
    this.bytes = Number(row.b);
    this.nextSeq = row.m === null ? 1 : Number(row.m) + 1;
    this.counted = true;
  }

  /** 存進補發暫存，超過上限時從最舊的丟起（與 Rust `Room::remember` 相同）。每筆只寫一列。 */
  private remember(seq: number, lamport: number, text: string): void {
    this.loadCounters();
    const size = text.length;
    this.sql.exec("INSERT INTO ops (seq, lamport, size, msg) VALUES (?, ?, ?, ?)", seq, lamport, size, text);
    this.count += 1;
    this.bytes += size;
    while (this.count > RECENT_MAX_COUNT || (this.bytes > RECENT_MAX_BYTES && this.count > 1)) {
      // 主鍵排序取最舊的一列：只讀一列（不是整表掃描）。
      const oldest = this.sql.exec("SELECT seq, size FROM ops ORDER BY seq ASC LIMIT 1").one();
      this.sql.exec("DELETE FROM ops WHERE seq = ?", oldest.seq);
      this.bytes -= Number(oldest.size);
      this.count -= 1;
    }
  }

  private catchup(ws: WebSocket, roomId: string, msg: any): void {
    const lastSeq = msg.last_seq;
    if (typeof lastSeq === "number") {
      const rows = this.sql.exec("SELECT msg FROM ops WHERE seq > ? ORDER BY seq ASC", lastSeq).toArray();
      this.loadCounters();
      const oldestRow = this.sql.exec("SELECT seq FROM ops ORDER BY seq ASC LIMIT 1").toArray()[0];
      const oldest = oldestRow ? Number(oldestRow.seq) : this.nextSeq;
      const truncated = oldest > lastSeq + 1;
      this.sendRaw(ws, `{"type":"oplog_batch","room_id":${JSON.stringify(roomId)},"oplogs":[${rows.map((r) => r.msg).join(",")}],"truncated":${truncated}}`);
      return;
    }
    const lastLamport = Number(msg.last_lamport ?? 0) || 0;
    const rows = this.sql.exec("SELECT msg FROM ops WHERE lamport > ? ORDER BY seq ASC", lastLamport).toArray();
    this.sendRaw(ws, `{"type":"oplog_batch","room_id":${JSON.stringify(roomId)},"oplogs":[${rows.map((r) => r.msg).join(",")}]}`);
  }

  private leave(ws: WebSocket, me: Attachment): void {
    ws.serializeAttachment({ joined: false, room: me.room } satisfies Attachment);
    this.broadcast(me.peer!.user_id, { type: "peer_left", room_id: me.room, user_id: me.peer!.user_id });
    this.cleanupIfEmpty();
  }

  private closeRoom(ws: WebSocket, me: Attachment): void {
    if (this.meta("owner") !== me.peer!.user_id) {
      this.send(ws, { type: "error", code: "CLOSE_FAILED", message: "僅房主有權關閉此房間" });
      return;
    }
    const notice = JSON.stringify({
      type: "room_closed",
      room_id: me.room,
      reason: "房主已結束本次線上協同會議",
    });
    for (const s of this.ctx.getWebSockets()) {
      if (s !== ws) this.sendRaw(s, notice);
      s.serializeAttachment({ joined: false, room: me.room } satisfies Attachment);
    }
    this.clearRoom();
  }

  private disconnected(ws: WebSocket): void {
    const me = this.attachment(ws);
    if (me.joined && me.peer && !me.replaced) {
      ws.serializeAttachment({ joined: false, room: me.room } satisfies Attachment);
      this.broadcast(me.peer.user_id, { type: "peer_left", room_id: me.room, user_id: me.peer.user_id });
    }
    this.cleanupIfEmpty(ws);
  }

  /** 房間沒有人了：清掉暫存與房主設定（與 Rust 版「最後一人離開即回收房間」相同）。 */
  private cleanupIfEmpty(closing?: WebSocket): void {
    const left = this.joinedSockets().filter((s) => s !== closing);
    if (left.length === 0) this.clearRoom();
  }

  private clearRoom(): void {
    this.sql.exec("DELETE FROM ops");
    this.sql.exec("DELETE FROM meta");
    this.counted = true;
    this.count = 0;
    this.bytes = 0;
    this.nextSeq = 1;
  }

  // ---- 小工具 ----

  private attachment(ws: WebSocket): Attachment {
    return (ws.deserializeAttachment() as Attachment | null) ?? { joined: false, room: "" };
  }

  private joinedSockets(): WebSocket[] {
    return this.ctx.getWebSockets().filter((s) => {
      const a = this.attachment(s);
      return a.joined && !a.replaced;
    });
  }

  private broadcast(fromUser: string, message: unknown): void {
    this.broadcastRaw(fromUser, JSON.stringify(message));
  }

  private broadcastRaw(fromUser: string, text: string): void {
    for (const s of this.joinedSockets()) {
      if (this.attachment(s).peer?.user_id !== fromUser) this.sendRaw(s, text);
    }
  }

  private send(ws: WebSocket, message: unknown): void {
    this.sendRaw(ws, JSON.stringify(message));
  }

  private sendRaw(ws: WebSocket, text: string): void {
    try {
      ws.send(text);
    } catch {
      // 對方已經斷了：關閉事件會接手清理。
    }
  }

  private meta(key: string): string | null {
    const row = this.sql.exec("SELECT v FROM meta WHERE k = ?", key).toArray()[0];
    return row ? String(row.v) : null;
  }

  private setMeta(key: string, value: string): void {
    this.sql.exec("INSERT INTO meta (k, v) VALUES (?, ?) ON CONFLICT(k) DO UPDATE SET v = excluded.v", key, value);
  }
}

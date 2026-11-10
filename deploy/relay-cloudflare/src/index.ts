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
// - **寄存的整份狀態**（`state_store`，只有這個中繼有；Rust 版不需要）：參與者定期把整本的狀態
//   （與回覆 `state_request` 同一個格式、同樣端對端加密）寄放在房間裡，不轉送給任何人。
//   新加入的人補發時先拿到它、再補它之後的操作 —— 房主不在線也拿得到完整內容。
// - **保存期限**：房間沒人了（大家都離開、斷線，或房主按「結束協同」）就排一個鬧鐘，
//   `RETENTION_HOURS`（預設 7 天）內沒有人再進來，整個房間（暫存、寄存、房主設定）刪除。
//   這段期間任何協作者都還能回來拿到最終版本；有人進來就取消鬧鐘。
// - 心跳 `{"type":"ping"}` 由平台自動回 `{"type":"pong"}`，不喚醒物件。
// - 內容是端對端加密的（房間金鑰只在參與者手上），中繼看不到筆跡與物件。

export interface Env {
  ROOMS: DurableObjectNamespace;
  MAX_PEERS?: string;
  LOCATION_HINT?: string;
  /** 房間沒人之後保留多久（小時）。預設 168（7 天）。 */
  RETENTION_HOURS?: string;
}

const DEFAULT_RETENTION_HOURS = 168;
/** 寄存的整份狀態一段的上限（字元）。SQLite 一列最多 2 MB；App 端每段約 400 KB。 */
const STORE_PART_MAX = 1_800_000;
/** 寄存的整份狀態最多幾段（≈ 256 × 400 KB ≈ 100 MB 內容）。 */
const STORE_PARTS_MAX = 256;
/** 預設每間房的人數上限（`MAX_PEERS` 沒設時）。 */
const DEFAULT_MAX_PEERS = 50;
/** 用到上限的幾成時先提出警告（暫存與寄存共用）。 */
const NEAR_LIMIT_RATIO = 0.8;

/** 補發時一則 `oplog_batch` 的大約上限（字元）。WebSocket 一則訊息的上限遠大於此，留足餘裕。 */
const BATCH_MAX = 900_000;

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
    this.ensureTables();
    ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair('{"type":"ping"}', '{"type":"pong"}'),
    );
  }

  /** 建表（冪等）。`deleteAll()` 連資料表一起刪，刪完要再建一次。 */
  private ensureTables(): void {
    this.sql.exec(
      "CREATE TABLE IF NOT EXISTS ops (seq INTEGER PRIMARY KEY, lamport INTEGER NOT NULL, size INTEGER NOT NULL, msg TEXT NOT NULL)",
    );
    this.sql.exec("CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)");
    // 寄存的整份狀態：同一個 `snap` 的各段收齊才算數，收齊後舊的那一份刪掉。
    this.sql.exec(
      "CREATE TABLE IF NOT EXISTS snap (snap TEXT NOT NULL, part INTEGER NOT NULL, parts INTEGER NOT NULL, seq INTEGER NOT NULL, msg TEXT NOT NULL, PRIMARY KEY (snap, part))",
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
        this.oplog(ws, me, msg);
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
    const maxPeers = Number(this.env.MAX_PEERS ?? String(DEFAULT_MAX_PEERS)) || DEFAULT_MAX_PEERS;
    if (sameUser.length === 0 && others.length >= maxPeers) {
      // 專用代碼：App 依它顯示在地化的「房間已滿」（舊版 App 照舊顯示 message）。
      this.send(ws, { type: "error", code: "ROOM_FULL", message: "這個房間的人數已達上限" });
      return;
    }

    // 第一位加入者成為房主；密碼（若有）由房主設定。
    let owner = this.meta("owner");
    if (owner === null) {
      owner = userId;
      this.setMeta("owner", owner);
      if (typeof msg.passcode === "string" && msg.passcode) this.setMeta("passcode", msg.passcode);
    } else if (msg.role === "owner" && owner !== userId && !others.some((s) => this.attachment(s).peer?.user_id === owner)) {
      // 房主重開 App 之後使用者 id 會換新（每次啟動隨機）。房間現在會保留好幾天，
      // 不接回來的話重開後的房主按不了「結束協同」。原房主還在線時不讓別人頂替。
      owner = userId;
      this.setMeta("owner", owner);
    }
    // 房主回來（例如重開 App 後沿用同一間房）：這場協同又開始了。
    if (owner === userId) this.sql.exec("DELETE FROM meta WHERE k = 'closed'");
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
    // 有人回來了：取消「沒人之後刪除」的鬧鐘。
    void this.ctx.storage.deleteAlarm();
    this.send(ws, {
      type: "joined", room_id: roomId, user_id: userId, role, peers: existing,
      // 房主已經結束過這場協同（資料在保存期限內還在）：App 可據此提示「這是最終版本」。
      closed: this.meta("closed") !== null,
    });
  }

  private oplog(ws: WebSocket, me: Attachment, msg: any): void {
    const kind = String(msg.kind ?? "");
    if (kind === "state_store") {
      this.storeState(ws, me, msg);
      return;
    }
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
      this.remember(me.room, seq, lamport, text);
      this.broadcastRaw(me.peer!.user_id, text);
      return;
    }
    this.broadcast(me.peer!.user_id, out);
  }

  /**
   * 寄存一段整份狀態（不轉送）。信封上的 `snap`（這一份的 id）、`part`／`parts`、`seq`
   * （寄存者已收到的最大序號）是明文；內容（`payload`）是端對端加密的，中繼看不到。
   * 收齊一份之後，序號不比現有的舊才換上，舊的刪掉。
   */
  private storeState(ws: WebSocket, me: Attachment, msg: any): void {
    const snap = String(msg.snap ?? "");
    const part = Number(msg.part);
    const parts = Number(msg.parts);
    const seq = Number(msg.seq ?? 0) || 0;
    if (!/^[A-Za-z0-9-]{8,64}$/.test(snap) || !Number.isInteger(part) || !Number.isInteger(parts)) return;
    if (parts < 1 || part < 0 || part >= parts) return;
    if (parts > STORE_PARTS_MAX) {
      // 整本超過寄存上限：存不下。只在第一段告訴寄存者一次（不是每段都通知）。
      // 原本寄存的那一份照舊留著（比什麼都沒有好）。
      if (part === 0) this.notice(ws, "store_too_large");
      return;
    }
    if (part === 0) {
      // 新的一份開始寄存：之前沒寄完就放棄的殘段（不是目前用的那一份）清掉，不讓它們一直佔空間。
      const current = this.meta("snap");
      this.sql.exec("DELETE FROM snap WHERE snap != ? AND snap != ?", snap, current ?? "");
      if (parts >= Math.ceil(STORE_PARTS_MAX * NEAR_LIMIT_RATIO)) this.notice(ws, "store_near_limit");
    }
    const text = JSON.stringify({
      type: "peer_oplog",
      room_id: me.room,
      user_id: me.peer!.user_id,
      lamport: Number(msg.lamport ?? 0) || 0,
      kind: "state_store",
      encrypted: msg.encrypted ?? null,
      payload: msg.payload ?? null,
    });
    if (text.length > STORE_PART_MAX) {
      this.notice(ws, "store_too_large");
      return;
    }
    this.sql.exec(
      "INSERT INTO snap (snap, part, parts, seq, msg) VALUES (?, ?, ?, ?, ?) ON CONFLICT(snap, part) DO UPDATE SET msg = excluded.msg",
      snap, part, parts, seq, text,
    );
    const got = Number(this.sql.exec("SELECT COUNT(*) AS n FROM snap WHERE snap = ?", snap).one().n);
    if (got < parts) return;
    const current = this.meta("snap");
    const currentSeq = Number(this.meta("snap_seq") ?? "-1");
    if (current !== null && current !== snap && seq < currentSeq) {
      // 比現有的舊（寄存者斷線很久才送出）：不換。
      this.sql.exec("DELETE FROM snap WHERE snap = ?", snap);
      return;
    }
    this.sql.exec("DELETE FROM snap WHERE snap != ?", snap);
    this.setMeta("snap", snap);
    this.setMeta("snap_seq", String(seq));
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
  private remember(roomId: string, seq: number, lamport: number, text: string): void {
    this.loadCounters();
    const size = text.length;
    this.sql.exec("INSERT INTO ops (seq, lamport, size, msg) VALUES (?, ?, ?, ?)", seq, lamport, size, text);
    this.count += 1;
    this.bytes += size;
    // 快滿了：先告訴房裡的人一次（較舊的操作接下來會自動清除；斷線很久的人回來改要整份狀態）。
    if (
      (this.count >= RECENT_MAX_COUNT * NEAR_LIMIT_RATIO || this.bytes >= RECENT_MAX_BYTES * NEAR_LIMIT_RATIO) &&
      this.meta("recent_warned") === null
    ) {
      this.setMeta("recent_warned", "1");
      this.broadcast("", { type: "relay_notice", room_id: roomId, code: "recent_near_limit" });
    }
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
    // 第一次進房（序號 0）而且有寄存的整份狀態：先給它，再補它之後的操作。
    // 寄存之前的操作也照補（暫存上限內）：合併規則冪等，重複套用無害，少一筆才是問題。
    const snap = lastSeq === 0 ? this.meta("snap") : null;
    if (snap !== null) {
      // 分成好幾則送：寄存的整份狀態（每段約 400 KB，加密後更大）加上暫存的操作塞進同一則，
      // 很容易超過 WebSocket 一則訊息的上限 —— 送不出去就整個沒到，剛加入的人什麼都拿不到。
      const parts = this.sql.exec("SELECT msg FROM snap WHERE snap = ? ORDER BY part ASC", snap).toArray();
      for (const row of parts) this.sendBatch(ws, roomId, [String(row.msg)], false, true);
      const ops = this.sql.exec("SELECT msg FROM ops ORDER BY seq ASC").toArray();
      this.sendBatches(ws, roomId, ops.map((r) => String(r.msg)), false);
      return;
    }
    if (typeof lastSeq === "number") {
      const rows = this.sql.exec("SELECT msg FROM ops WHERE seq > ? ORDER BY seq ASC", lastSeq).toArray();
      this.loadCounters();
      const oldestRow = this.sql.exec("SELECT seq FROM ops ORDER BY seq ASC LIMIT 1").toArray()[0];
      const oldest = oldestRow ? Number(oldestRow.seq) : this.nextSeq;
      const truncated = oldest > lastSeq + 1;
      this.sendBatches(ws, roomId, rows.map((r) => String(r.msg)), truncated);
      return;
    }
    const lastLamport = Number(msg.last_lamport ?? 0) || 0;
    const rows = this.sql.exec("SELECT msg FROM ops WHERE lamport > ? ORDER BY seq ASC", lastLamport).toArray();
    this.sendRaw(ws, `{"type":"oplog_batch","room_id":${JSON.stringify(roomId)},"oplogs":[${rows.map((r) => r.msg).join(",")}]}`);
  }

  /** 補發的操作依大小切成好幾則 `oplog_batch`（每則不超過 `BATCH_MAX`）。沒有操作也送一則空的（客戶端以它確認補發完成）。 */
  private sendBatches(ws: WebSocket, roomId: string, msgs: string[], truncated: boolean): void {
    let chunk: string[] = [];
    let size = 0;
    let sent = false;
    for (const m of msgs) {
      if (chunk.length > 0 && size + m.length > BATCH_MAX) {
        this.sendBatch(ws, roomId, chunk, truncated, false);
        sent = true;
        chunk = [];
        size = 0;
      }
      chunk.push(m);
      size += m.length + 1;
    }
    if (chunk.length > 0 || !sent) this.sendBatch(ws, roomId, chunk, truncated, false);
  }

  private sendBatch(ws: WebSocket, roomId: string, msgs: string[], truncated: boolean, storedState: boolean): void {
    const extra = storedState ? `,"stored_state":true` : "";
    this.sendRaw(ws, `{"type":"oplog_batch","room_id":${JSON.stringify(roomId)},"oplogs":[${msgs.join(",")}],"truncated":${truncated}${extra}}`);
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
    // 不立刻刪：離線中的協作者在保存期限內回來，還能補到最終版本（見 `scheduleExpiry`）。
    this.setMeta("closed", String(Date.now()));
    this.scheduleExpiry();
  }

  private disconnected(ws: WebSocket): void {
    const me = this.attachment(ws);
    if (me.joined && me.peer && !me.replaced) {
      ws.serializeAttachment({ joined: false, room: me.room } satisfies Attachment);
      this.broadcast(me.peer.user_id, { type: "peer_left", room_id: me.room, user_id: me.peer.user_id });
    }
    this.cleanupIfEmpty(ws);
  }

  /**
   * 房間沒有人了：排「保存期限到了就刪除」的鬧鐘。不再立刻清空 —— Rust 版（區網）是
   * 最後一人離開即回收，這裡要讓不在線的協作者回來時還拿得到最終版本。
   */
  private cleanupIfEmpty(closing?: WebSocket): void {
    const left = this.joinedSockets().filter((s) => s !== closing);
    if (left.length === 0) this.scheduleExpiry();
  }

  private retentionMs(): number {
    const hours = Number(this.env.RETENTION_HOURS ?? DEFAULT_RETENTION_HOURS);
    return (Number.isFinite(hours) && hours > 0 ? hours : DEFAULT_RETENTION_HOURS) * 3_600_000;
  }

  private scheduleExpiry(): void {
    void this.ctx.storage.setAlarm(Date.now() + this.retentionMs());
  }

  /** 保存期限到了：還是沒人的話，整個房間的資料刪掉（暫存、寄存、房主、密碼）。 */
  async alarm(): Promise<void> {
    if (this.joinedSockets().length > 0) return;
    await this.ctx.storage.deleteAll();
    this.ensureTables();
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

  /** 中繼給客戶端的提醒（不是錯誤：連線照常）。舊版 App 不認得這個類型，直接略過。 */
  private notice(ws: WebSocket, code: string): void {
    this.send(ws, { type: "relay_notice", room_id: this.attachment(ws).room, code });
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

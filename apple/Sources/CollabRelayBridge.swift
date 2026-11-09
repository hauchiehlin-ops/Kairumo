//
//  CollabRelayBridge.swift
//  Kairumo
//
//  同一間會議室同時開放「同一 Wi‑Fi」與「雲端共享（跨網路）」。
//
//  # 為什麼需要橋
//
//  房主同一時間只連得上一個中繼。以前會議室開在本機中繼（同一 Wi‑Fi）時，掃雲端 QR Code 的人
//  進到的是房主不在的雲端房間：拿得到寄存的整本內容，房主的在線成員卻看不到他、也無法一起編輯
//  （實機回報）。實際使用時協作者不一定在同一個 Wi‑Fi，兩種方式要能同時用。
//
//  # 做法：房主當橋，每位成員一條代理連線
//
//  雲端中繼把每條連線綁定到加入時的 user_id（`deploy/relay-cloudflare` 的 `bound()`），
//  所以不能用一條連線代轉別人的訊息。改成：
//
//  - 會議室開在房主這台的本機中繼上（房主自己的連線照舊）。
//  - Wi‑Fi 這邊的每個人（含房主）在雲端中繼各有一條代理連線，以他的 user_id 加入；
//    他送的操作由房主轉進雲端。
//  - 雲端那邊的每個人在本機中繼各有一條代理連線；他送的操作由房主轉進本機中繼。
//  - 雲端那邊的訊息從「房主在雲端的代理連線」收；其他代理連線只送不收。
//
//  內容原樣轉送：兩邊是同一間房（同房號、同一把金鑰），中繼本來就看不到內容。
//  兩邊的人都會出現在彼此的在線成員裡，換頁仲裁、即時筆跡、語音照常運作。
//  與 Android `CollabRelayBridge` 同一套。
//

import Foundation

@MainActor
final class CollabRelayBridge {
    struct Member {
        let userId: String
        var name: String
        var color: String
    }

    private final class Link {
        let userId: String
        let socket: CollabRelaySocket
        var alive = true
        init(userId: String, socket: CollabRelaySocket) {
            self.userId = userId
            self.socket = socket
        }
    }

    let cloudURL: String
    private let lanURL: String
    private let roomId: String
    private let host: Member

    /// Wi‑Fi 這邊的人（含房主）→ 他在雲端的代理連線。
    private var lanMembers: [String: Member] = [:]
    private var cloudLinks: [String: Link] = [:]
    /// 雲端那邊的人 → 他在本機中繼的代理連線。
    private var cloudMembers: [String: Member] = [:]
    private var lanLinks: [String: Link] = [:]
    private var pingTimer: Timer?
    private var stopped = false

    /// 目前經由橋接進來的雲端成員（停止橋接後交給下一座橋，免得把他們誤當成 Wi‑Fi 這邊的人）。
    var cloudUserIds: Set<String> { Set(cloudMembers.keys) }

    init(cloudURL: String, lanURL: String, roomId: String, host: Member) {
        self.cloudURL = cloudURL
        self.lanURL = lanURL
        self.roomId = roomId
        self.host = host
    }

    /// 開始橋接。`lanPeers`：房主目前在本機中繼看到的成員；`excluding`：前一座橋帶進來的雲端成員。
    func start(lanPeers: [Member], excluding: Set<String>) {
        lanMembers[host.userId] = host
        openCloudLink(for: host, role: "owner")
        for peer in lanPeers where !excluding.contains(peer.userId) {
            addLanMember(peer)
        }
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pingAll() }
        }
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        pingTimer?.invalidate()
        pingTimer = nil
        for link in Array(cloudLinks.values) + Array(lanLinks.values) {
            close(link)
        }
        cloudLinks.removeAll()
        lanLinks.removeAll()
    }

    // MARK: 房主在本機中繼的連線（Wi‑Fi 這邊）

    /// 房主自己的連線收到的每一則訊息（本機中繼）。
    func lanReceived(_ json: [String: Any]) {
        guard !stopped, let type = json["type"] as? String else { return }
        switch type {
        case "joined":
            for peer in (json["peers"] as? [[String: Any]]) ?? [] {
                if let member = Self.member(peer) { addLanMember(member) }
            }
        case "peer_joined":
            if let peer = json["peer"] as? [String: Any], let member = Self.member(peer) { addLanMember(member) }
        case "peer_left":
            if let uid = json["user_id"] as? String { removeLanMember(uid) }
        case "peer_oplog", "peer_presence":
            guard let uid = json["user_id"] as? String, uid != host.userId, lanMembers[uid] != nil else { return }
            if (json["kind"] as? String) == "state_store" { return }
            if let link = cloudLinks[uid] {
                send(Self.rewrap(json, as: type == "peer_oplog" ? "oplog" : "presence", roomId: roomId), on: link)
            }
        default:
            break
        }
    }

    /// 房主自己送出的訊息：操作與游標也送進雲端；結束會議也通知雲端。
    /// 寄存整份狀態（`state_store`）也送：雲端中繼才保留得到最新版給之後加入的人。
    func hostSent(_ dict: [String: Any]) {
        guard !stopped, let type = dict["type"] as? String,
              type == "oplog" || type == "presence" || type == "close_room",
              let link = cloudLinks[host.userId] else { return }
        var out = dict
        out["room_id"] = roomId
        send(out, on: link)
    }

    // MARK: 房主在雲端的代理連線（雲端那邊）

    private func cloudReceived(_ text: String) {
        guard !stopped, let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        switch type {
        case "joined":
            for peer in (json["peers"] as? [[String: Any]]) ?? [] {
                if let member = Self.member(peer) { addCloudMember(member) }
            }
        case "peer_joined":
            if let peer = json["peer"] as? [String: Any], let member = Self.member(peer) { addCloudMember(member) }
        case "peer_left":
            if let uid = json["user_id"] as? String { removeCloudMember(uid) }
        case "peer_oplog", "peer_presence":
            guard let uid = json["user_id"] as? String, uid != host.userId, lanMembers[uid] == nil else { return }
            if (json["kind"] as? String) == "state_store" { return }
            if cloudMembers[uid] == nil {
                addCloudMember(Member(userId: uid, name: String(uid.prefix(6)), color: "#4A90E2"))
            }
            if let link = lanLinks[uid] {
                send(Self.rewrap(json, as: type == "peer_oplog" ? "oplog" : "presence", roomId: roomId), on: link)
            }
        default:
            break
        }
    }

    // MARK: 成員

    private func addLanMember(_ member: Member) {
        guard member.userId != host.userId, cloudMembers[member.userId] == nil,
              lanMembers[member.userId] == nil else { return }
        lanMembers[member.userId] = member
        openCloudLink(for: member, role: "editor")
    }

    private func removeLanMember(_ uid: String) {
        guard uid != host.userId, lanMembers.removeValue(forKey: uid) != nil else { return }
        if let link = cloudLinks.removeValue(forKey: uid) { close(link) }
    }

    private func addCloudMember(_ member: Member) {
        guard member.userId != host.userId, lanMembers[member.userId] == nil,
              cloudMembers[member.userId] == nil else { return }
        // 先記下再開代理連線：房主自己的連線收到他的 `peer_joined` 時才認得出是雲端那邊的人。
        cloudMembers[member.userId] = member
        openLanLink(for: member)
    }

    private func removeCloudMember(_ uid: String) {
        guard cloudMembers.removeValue(forKey: uid) != nil else { return }
        if let link = lanLinks.removeValue(forKey: uid) { close(link) }
    }

    // MARK: 連線

    private func openCloudLink(for member: Member, role: String) {
        guard let link = open(cloudURL, member: member, role: role) else { return }
        cloudLinks[member.userId] = link
        let isHostLink = member.userId == host.userId
        listen(link, onText: isHostLink ? { [weak self] in self?.cloudReceived($0) } : nil) { [weak self] in
            guard let self, !self.stopped else { return }
            if isHostLink || self.lanMembers[member.userId] != nil {
                self.openCloudLink(for: self.lanMembers[member.userId] ?? member, role: role)
            }
        }
    }

    private func openLanLink(for member: Member) {
        guard let link = open(lanURL, member: member, role: "editor") else { return }
        lanLinks[member.userId] = link
        listen(link, onText: nil) { [weak self] in
            guard let self, !self.stopped, let current = self.cloudMembers[member.userId] else { return }
            self.openLanLink(for: current)
        }
    }

    private func open(_ address: String, member: Member, role: String) -> Link? {
        guard let url = CollaborationManager.relayURL(address, roomId: roomId) else { return nil }
        let link = Link(userId: member.userId, socket: CollabRelaySockets.open(url))
        send([
            "type": "join",
            "room_id": roomId,
            "user_id": member.userId,
            "user_name": member.name,
            "user_color": member.color,
            "role": role
        ], on: link)
        return link
    }

    /// 持續讀這條連線；斷了就 3 秒後以同一個身分重開（人還在的話）。
    private func listen(_ link: Link, onText: ((String) -> Void)?, reopen: @escaping () -> Void) {
        link.socket.receive { [weak self] text, _ in
            guard let self, link.alive else { return }
            if let text {
                if !text.isEmpty { onText?(text) }
                self.listen(link, onText: onText, reopen: reopen)
                return
            }
            link.alive = false
            link.socket.close()
            guard !self.stopped else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { reopen() }
        }
    }

    private func close(_ link: Link) {
        guard link.alive else { return }
        link.alive = false
        send(["type": "leave", "room_id": roomId, "user_id": link.userId], on: link, force: true)
        let socket = link.socket
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { socket.close() }
    }

    private func pingAll() {
        for link in Array(cloudLinks.values) + Array(lanLinks.values) {
            send(["type": "ping"], on: link)
        }
    }

    private func send(_ dict: [String: Any], on link: Link, force: Bool = false) {
        guard force || link.alive,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        link.socket.send(text)
    }

    // MARK: 格式

    private static func member(_ dict: [String: Any]) -> Member? {
        guard let uid = dict["user_id"] as? String, !uid.isEmpty else { return nil }
        return Member(userId: uid,
                      name: (dict["user_name"] as? String) ?? String(uid.prefix(6)),
                      color: (dict["user_color"] as? String) ?? "#4A90E2")
    }

    /// 中繼轉來的 `peer_oplog`／`peer_presence` 改回送出時的 `oplog`／`presence`（拿掉中繼加的序號）。
    private static func rewrap(_ json: [String: Any], as type: String, roomId: String) -> [String: Any] {
        var out = json
        out["type"] = type
        out["room_id"] = roomId
        out.removeValue(forKey: "seq")
        return out
    }
}

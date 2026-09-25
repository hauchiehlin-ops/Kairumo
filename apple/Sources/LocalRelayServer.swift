//
//  LocalRelayServer.swift
//  Kairumo
//
//  內建的 WebSocket 協同中繼服務（與 crates/padnote-relay 同協定）。
//
//  為什麼要內建：協同原本只連 `ws://127.0.0.1:9002`，那是 Rust 版
//  `padnote-relay` 監聽的位址 —— 但 App 自己不會去啟動那支程式，
//  使用者手上也沒有後端可連，於是永遠停在「連線中斷，正在自動重新連線」。
//  D5 說「不建後端伺服器」指的是我們不營運雲端服務，不是不能在使用者
//  自己的裝置上開一個房間；所以由發起協同的那台裝置直接當中繼點。
//

import Foundation
import Network

/// 裝置內建的房間中繼服務。與 `padnote-relay` 的 hub.rs 行為一致：
/// 第一位加入者即房主、presence/oplog 轉發給房內其他人、oplog 保留最近
/// 200 筆供斷線追趕、房空自動回收。
public final class LocalRelayServer {
    public static let shared = LocalRelayServer()

    /// 單一在線成員
    private final class PeerConnection {
        let connection: NWConnection
        var userId: String?
        var roomId: String?
        var info: [String: Any] = [:]

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    /// 單一協同房間
    private final class Room {
        let id: String
        let ownerId: String
        var peers: [String: PeerConnection] = [:]
        /// 最近的 oplog 環形快取（上限 200，與 Rust 版一致）
        var recentOplogs: [[String: Any]] = []

        init(id: String, ownerId: String) {
            self.id = id
            self.ownerId = ownerId
        }
    }

    /// 監聽器**真正**的狀態。
    ///
    /// `start()` 同步回傳的成功只代表「`NWListener` 建得起來」——
    /// 真正能不能聽是**非同步**在 `stateUpdateHandler` 才知道的。
    /// 少了這條回報，上層會樂觀地說「正在擔任中繼」，而其實什麼都沒聽到：
    /// 使用者看到的是「連線中斷，正在自動重新連線」無限轉圈。
    ///
    /// 在 macOS 沙盒下，缺少 `com.apple.security.network.server` 權限
    /// 就是走這條路失敗的。
    public enum RelayState {
        case ready(port: UInt16)
        case failed(String)
    }

    /// 狀態變化的回報。**在主執行緒呼叫**，可以直接改 UI 狀態。
    public var onStateChange: ((RelayState) -> Void)?

    private func report(_ state: RelayState) {
        let handler = onStateChange
        DispatchQueue.main.async { handler?(state) }
    }

    private let queue = DispatchQueue(label: "com.kairumo.relay", qos: .userInitiated)
    private var listener: NWListener?
    private var rooms: [String: Room] = [:]
    private var connections: [ObjectIdentifier: PeerConnection] = [:]

    private var runningPort: UInt16?

    /// 目前是否已在本機提供中繼服務
    public var isRunning: Bool {
        queue.sync { listener != nil }
    }

    /// 目前監聽的埠號
    public var activePort: UInt16? {
        queue.sync { runningPort }
    }

    private init() {}

    // MARK: - 生命週期

    /// 啟動本機中繼服務。已在相同埠號執行時直接回傳成功。
    @discardableResult
    public func start(port: UInt16) -> Result<UInt16, Error> {
        var outcome: Result<UInt16, Error> = .success(port)
        queue.sync {
            if listener != nil, runningPort == port {
                outcome = .success(port)
                return
            }
            if listener != nil {
                stopLocked()
            }

            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                outcome = .failure(RelayError.invalidPort(port))
                return
            }

            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let wsOptions = NWProtocolWebSocket.Options()
            wsOptions.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

            do {
                let newListener = try NWListener(using: parameters, on: nwPort)
                // 廣播 mDNS 服務，讓區網內的其他裝置能自動發現（跨裝置即時同步）
                newListener.service = NWListener.Service(name: "Kairumo_\(UUID().uuidString.prefix(8))", type: "_kairumosync._tcp", domain: "local.")
                newListener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                newListener.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .waiting(let error):
                        // `waiting` 多半是埠被佔用而且還在等它釋放。
                        // 不當成失敗，但也**不能**讓上層繼續宣稱自己在聽。
                        self?.report(.failed(error.localizedDescription))
                    case .failed(let error):
                        // 這個 handler 已經在 queue 上執行，不能再 queue.sync 進去
                        self?.stopLocked()
                        self?.report(.failed(error.localizedDescription))
                    case .ready:
                        self?.report(.ready(port: port))
                    default:
                        break
                    }
                }
                newListener.start(queue: queue)
                self.listener = newListener
                self.runningPort = port
                outcome = .success(port)
            } catch {
                outcome = .failure(error)
            }
        }
        return outcome
    }

    /// 關閉中繼服務並中斷所有連線
    public func stop() {
        queue.sync { stopLocked() }
    }

    private func stopLocked() {
        for peer in connections.values {
            peer.connection.cancel()
        }
        connections.removeAll()
        rooms.removeAll()
        listener?.cancel()
        listener = nil
        runningPort = nil
    }

    // MARK: - 連線處理

    private func accept(_ connection: NWConnection) {
        let peer = PeerConnection(connection: connection)
        connections[ObjectIdentifier(connection)] = peer

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.handleDisconnect(connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self = self else { return }

            if let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                as? NWProtocolWebSocket.Metadata, metadata.opcode == .close {
                connection.cancel()
                return
            }

            if let error = error {
                print("⚠️ [Kairumo Relay] 連線中斷：\(error.localizedDescription)")
                connection.cancel()
                return
            }

            if let data = data, !data.isEmpty {
                self.handleClientMessage(data, from: connection)
            }
            self.receive(on: connection)
        }
    }

    private func handleDisconnect(_ connection: NWConnection) {
        guard let peer = connections.removeValue(forKey: ObjectIdentifier(connection)) else { return }
        if let roomId = peer.roomId, let userId = peer.userId {
            leave(roomId: roomId, userId: userId)
        }
    }

    // MARK: - 訊息轉發（對齊 padnote-relay/src/hub.rs）

    private func handleClientMessage(_ data: Data, from connection: NWConnection) {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = json["type"] as? String else {
            send(["type": "error", "code": "INVALID_FORMAT", "message": "無法解析之訊息格式"], to: connection)
            return
        }
        guard let peer = connections[ObjectIdentifier(connection)] else { return }

        switch type {
        case "join":
            handleJoin(json, peer: peer)

        case "presence":
            guard let roomId = json["room_id"] as? String,
                  let userId = json["user_id"] as? String else { return }
            var forward = json
            forward["type"] = "peer_presence"
            broadcast(forward, in: roomId, except: userId)

        case "oplog":
            guard let roomId = json["room_id"] as? String,
                  let userId = json["user_id"] as? String else { return }
            var forward = json
            forward["type"] = "peer_oplog"
            if let room = rooms[roomId] {
                room.recentOplogs.append(forward)
                if room.recentOplogs.count > 200 {
                    room.recentOplogs.removeFirst(room.recentOplogs.count - 200)
                }
            }
            broadcast(forward, in: roomId, except: userId)

        case "catchup":
            guard let roomId = json["room_id"] as? String else { return }
            let lastLamport = ((json["last_lamport"] as? NSNumber)?.uint64Value) ?? 0
            let missing = (rooms[roomId]?.recentOplogs ?? []).filter {
                (($0["lamport"] as? NSNumber)?.uint64Value ?? 0) > lastLamport
            }
            send(["type": "oplog_batch", "room_id": roomId, "oplogs": missing], to: connection)

        case "leave":
            if let roomId = json["room_id"] as? String, let userId = json["user_id"] as? String {
                leave(roomId: roomId, userId: userId)
            }
            peer.roomId = nil
            peer.userId = nil

        case "close_room":
            guard let roomId = json["room_id"] as? String,
                  let userId = json["user_id"] as? String else { return }
            guard let room = rooms[roomId] else {
                send(["type": "error", "code": "CLOSE_FAILED", "message": "房間不存在"], to: connection)
                return
            }
            guard room.ownerId == userId else {
                send(["type": "error", "code": "CLOSE_FAILED", "message": "僅房主有權關閉此房間"], to: connection)
                return
            }
            broadcast([
                "type": "room_closed",
                "room_id": roomId,
                "reason": "房主已結束本次線上協同會議"
            ], in: roomId, except: nil)
            rooms.removeValue(forKey: roomId)

        case "ping":
            send(["type": "pong"], to: connection)

        default:
            break
        }
    }

    private func handleJoin(_ json: [String: Any], peer: PeerConnection) {
        guard let roomId = json["room_id"] as? String,
              let userId = json["user_id"] as? String else { return }

        let room: Room
        if let existing = rooms[roomId] {
            room = existing
        } else {
            // 房間不存在時，第一位加入者自動成為房主（與 Rust 版一致）
            room = Room(id: roomId, ownerId: userId)
            rooms[roomId] = room
        }

        let actualRole = (room.ownerId == userId) ? "owner" : ((json["role"] as? String) ?? "editor")
        let peerInfo: [String: Any] = [
            "user_id": userId,
            "user_name": (json["user_name"] as? String) ?? "",
            "user_color": (json["user_color"] as? String) ?? "#3478F6",
            "role": actualRole
        ]

        // 先把既有成員清單拍下來，再把自己放進房間 —— 順序反了會把自己
        // 也列進「其他人」，隊友面板上就會多出一個自己。
        let existingPeers = room.peers.values.map { $0.info }

        broadcast(["type": "peer_joined", "room_id": roomId, "peer": peerInfo], in: roomId, except: userId)

        peer.userId = userId
        peer.roomId = roomId
        peer.info = peerInfo
        room.peers[userId] = peer

        send([
            "type": "joined",
            "room_id": roomId,
            "user_id": userId,
            "role": actualRole,
            "peers": existingPeers
        ], to: peer.connection)
    }

    private func leave(roomId: String, userId: String) {
        guard let room = rooms[roomId] else { return }
        room.peers.removeValue(forKey: userId)
        broadcast(["type": "peer_left", "room_id": roomId, "user_id": userId], in: roomId, except: nil)
        if room.peers.isEmpty {
            rooms.removeValue(forKey: roomId)
        }
    }

    // MARK: - 傳送

    private func broadcast(_ message: [String: Any], in roomId: String, except userId: String?) {
        guard let room = rooms[roomId] else { return }
        for (pid, peer) in room.peers where pid != userId {
            send(message, to: peer.connection)
        }
    }

    private func send(_ message: [String: Any], to connection: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "relay", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
            if let error = error {
                print("⚠️ [Kairumo Relay] 傳送失敗：\(error.localizedDescription)")
            }
        })
    }

    // MARK: - 位址輔助

    public enum RelayError: LocalizedError {
        case invalidPort(UInt16)

        public var errorDescription: String? {
            switch self {
            case .invalidPort(let p): return "無效的埠號 \(p)"
            }
        }
    }

    /// 取得本機在區域網路上的 IPv4 位址，供隊友輸入連線（沒有則回 nil）。
    public static func lanIPv4Address() -> String? {
        var address: String?
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // en0 = Wi-Fi / 有線；其餘（lo0、awdl0、utun*）不是隊友連得到的位址
                if name == "en0" || name == "en1" {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(interface.ifa_addr,
                                   socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostBuffer,
                                   socklen_t(hostBuffer.count),
                                   nil,
                                   0,
                                   NI_NUMERICHOST) == 0 {
                        address = String(cString: hostBuffer)
                    }
                }
            }
            pointer = interface.ifa_next
        }
        return address
    }
}
import Foundation
import Network
import Combine

/// 局域網同步自動發現（mDNS / Bonjour）。
/// 用於尋找同一 Wi-Fi 下廣播 `_kairumosync._tcp` 的其他裝置，並建立 WebSocket 捷徑。
public final class LocalSyncDiscovery: ObservableObject {
    public static let shared = LocalSyncDiscovery()
    
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.kairumo.sync.discovery")
    
    @Published public var discoveredEndpoints: [NWEndpoint] = []
    
    private init() {}
    
    public func startBrowsing() {
        guard browser == nil else { return }
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_kairumosync._tcp", domain: "local."), using: parameters)
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            let endpoints = results.map { $0.endpoint }
            DispatchQueue.main.async {
                self?.discoveredEndpoints = endpoints
            }
        }
        
        browser.start(queue: queue)
        self.browser = browser
    }
    
    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        DispatchQueue.main.async {
            self.discoveredEndpoints.removeAll()
        }
    }
    
    /// 向掃描到的局域網裝置發起 WebSocket 直連 (Phase 1 實作)
    public func connectToP2P(endpoint: NWEndpoint) {
        let parameters = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        let connection = NWConnection(to: endpoint, using: parameters)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ [P2P] 成功與區網設備建立 WebRTC/WebSocket 直連！")
                // TODO: 這裡接上 padnote-sync 的 FFI 介面，開始雙向交換 Oplog 檔案。
            case .failed(let error):
                print("❌ [P2P] 直連失敗：\(error)")
            default:
                break
            }
        }
        connection.start(queue: queue)
        // 注意：需在全域保存 connection 實體以避免被釋放
    }
}

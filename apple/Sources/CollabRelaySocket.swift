//
//  CollabRelaySocket.swift
//  Kairumo
//
//  協同中繼的 WebSocket 連線。
//
//  # 為什麼明文 `ws://` 不走 URLSession
//
//  App Transport Security 只放行區網私有網段（192.168.x、10.x…）的明文連線。
//  Tailscale 的位址是 100.64.0.0/10（電信級 NAT 網段），不算私有網段 —— iPhone 掃
//  Tailscale QR Code 會直接被擋：「App Transport Security policy requires the use of a
//  secure connection」。ATS 的例外只能寫網域、不能寫 IP 範圍；全面關掉（NSAllowsArbitraryLoads）
//  又會讓整個 App 的網路都失去保護。
//
//  ATS 只管 URLSession。Network.framework 的 `NWConnection` 不受它約束，所以明文的中繼
//  改走 `NWConnection`（內容本來就是端對端加密，見 `CollaborationManager.encryptPayload`；
//  哪些位址允許明文由核心的 `collabCheckServer` 把關，與 Android 同一份規則）。
//  順帶可以關掉 Nagle（`noDelay`）：協同送的是一則則很小的訊息。
//
//  加密的 `wss://` 照舊走 URLSession。

import Foundation
import Network

/// 一條協同中繼連線。回呼都在主執行緒。
@MainActor
protocol CollabRelaySocket: AnyObject {
    func send(_ text: String)
    /// 收下一則訊息。`nil` 文字＋錯誤＝連線斷了。
    func receive(_ handler: @escaping @MainActor (String?, Error?) -> Void)
    func close()
}

@MainActor
enum CollabRelaySockets {
    static func open(_ url: URL) -> CollabRelaySocket {
        if url.scheme?.lowercased() == "ws" { return NWRelaySocket(url: url) }
        return URLSessionRelaySocket(url: url)
    }
}

// MARK: - wss://：URLSession

@MainActor
final class URLSessionRelaySocket: CollabRelaySocket {
    private let task: URLSessionWebSocketTask

    init(url: URL) {
        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        // 預設上限 1 MB：一張照片（base64 後）就超過，整條連線會被斷掉。與中繼的 64 MB 一致。
        task.maximumMessageSize = 64 * 1024 * 1024
        task.resume()
    }

    func send(_ text: String) {
        task.send(.string(text)) { error in
            if let error { print("⚠️ WebSocket 傳送失敗: \(error.localizedDescription)") }
        }
    }

    func receive(_ handler: @escaping @MainActor (String?, Error?) -> Void) {
        task.receive { result in
            Task { @MainActor in
                switch result {
                case .success(.string(let text)): handler(text, nil)
                case .success(.data(let data)): handler(String(data: data, encoding: .utf8) ?? "", nil)
                case .success: handler("", nil)
                case .failure(let error): handler(nil, error)
                }
            }
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

// MARK: - ws://：Network.framework（不受 ATS 限制）

@MainActor
final class NWRelaySocket: CollabRelaySocket {
    private let connection: NWConnection
    private static let queue = DispatchQueue(label: "kairumo.collab.relay-socket", qos: .userInitiated)

    init(url: URL) {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 8
        let parameters = NWParameters(tls: nil, tcp: tcp)
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        ws.maximumMessageSize = 64 * 1024 * 1024
        parameters.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
        connection = NWConnection(to: .url(url), using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            let failure: Error?
            switch state {
            case .failed(let error): failure = error
            // 連不上（位址不對、對方沒開）時 NWConnection 會停在 waiting 一直重試，
            // 不會讓等著收訊息的那一邊失敗 —— 當成斷線，交給協同自己的重連（有次數上限與提示）。
            case .waiting(let error): failure = error
            default: failure = nil
            }
            guard let failure else { return }
            Task { @MainActor [weak self] in self?.fail(failure) }
        }
        connection.start(queue: Self.queue)
    }

    private var pending: (@MainActor (String?, Error?) -> Void)?

    private func fail(_ error: Error) {
        connection.cancel()
        let handler = pending
        pending = nil
        handler?(nil, error)
    }

    func send(_ text: String) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: Data(text.utf8), contentContext: context, isComplete: true,
                        completion: .contentProcessed { error in
            if let error { print("⚠️ WebSocket 傳送失敗: \(error.localizedDescription)") }
        })
    }

    func receive(_ handler: @escaping @MainActor (String?, Error?) -> Void) {
        pending = handler
        connection.receiveMessage { [weak self] data, context, _, error in
            let text = data.flatMap { String(data: $0, encoding: .utf8) }
            let isClose = (context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                as? NWProtocolWebSocket.Metadata)?.opcode == .close
            Task { @MainActor [weak self] in
                // 已經因為連線失敗回報過了，不要再回報一次（會排兩次重連）。
                guard let self, self.pending != nil else { return }
                self.pending = nil
                if let error {
                    handler(nil, error)
                } else if isClose {
                    handler(nil, URLError(.networkConnectionLost))
                } else if data == nil {
                    // 沒有內容也沒有錯誤：對方關掉了連線。
                    handler(nil, URLError(.networkConnectionLost))
                } else {
                    handler(text ?? "", nil)
                }
            }
        }
    }

    func close() {
        pending = nil
        connection.cancel()
    }
}

//
//  TailscaleDetector.swift
//  Kairumo
//
//  偵測系統是否運行 Tailscale 虛擬私有網路 (100.64.0.0/10 或 fd7a:115c:a1e0::/48)
//

import Darwin
import Foundation
import SwiftUI

public enum TailscaleDetector {
    public struct Status: Equatable {
        public let isConnected: Bool
        public let ipAddress: String?
        public let interfaceName: String?

        public static let disconnected = Status(isConnected: false, ipAddress: nil, interfaceName: nil)
    }

    /// 透過 POSIX getifaddrs 檢查系統中是否有正在運行之 Tailscale 介面
    public static func check() -> Status {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return .disconnected
        }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let flags = Int32(interface.ifa_flags)
            // 介面必須已啟動且正在運行
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING) else { continue }
            guard let addr = interface.ifa_addr else { continue }

            let interfaceName = String(cString: interface.ifa_name)

            // 檢查 IPv4 (AF_INET)
            if addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    addr, socklen_t(addr.pointee.sa_len),
                    &hostname, socklen_t(hostname.count),
                    nil, 0, NI_NUMERICHOST
                ) == 0 {
                    let ip = String(cString: hostname)
                    // Tailscale 的 IPv4 CGNAT 地址範圍是 100.64.0.0/10 (100.64.0.0 ~ 100.127.255.255)
                    if ip.starts(with: "100.") {
                        let parts = ip.split(separator: ".")
                        if parts.count == 4, let second = Int(parts[1]), second >= 64, second <= 127 {
                            return Status(isConnected: true, ipAddress: ip, interfaceName: interfaceName)
                        }
                    }
                }
            }
        }
        return .disconnected
    }
}

/// 全局 Tailscale 連線狀態監聽器（提供 SwiftUI 響應式更新）
@MainActor
public final class TailscaleMonitor: ObservableObject {
    public static let shared = TailscaleMonitor()

    @Published public private(set) var status: TailscaleDetector.Status = TailscaleDetector.check()

    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    public func refresh() {
        let current = TailscaleDetector.check()
        if status != current {
            status = current
        }
    }
}

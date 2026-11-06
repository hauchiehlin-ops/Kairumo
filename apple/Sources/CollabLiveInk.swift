//
//  CollabLiveInk.swift
//  Kairumo
//
//  協同：書寫中即時串流筆畫（`live_ink`）。
//
//  # 為什麼
//
//  正式的筆畫（`ink_add`）要等提筆才送 —— 對方看到的是「一整筆突然出現」，
//  寫一個字要等好幾筆、每筆都晚一拍，不像在一起寫。這裡在書寫**途中**每 ~33 ms
//  送一次新增的點，對方先畫一條預覽線；提筆後正式筆畫照舊由 `ink_add` 送達，
//  預覽線隨即收掉。
//
//  # 不碰筆跡真相（ADR-0015）
//
//  預覽線只存在記憶體、只畫在浮層上：不寫進畫布、不寫進套件、中繼不留存
//  （種類以 `live_` 開頭，中繼視為暫態、不進補發暫存）。漏收、亂序都無妨 ——
//  最後一定以 `ink_add` 為準。
//
//  # 不拖慢本機書寫
//
//  只在 PencilKit 的手勢回呼裡記點（陣列追加），送出節流在 30 Hz、在主執行緒以
//  一次 WebSocket 傳送完成，不做任何磁碟 I/O 或筆跡運算。

import PencilKit
import SwiftUI
import UIKit

/// 這一筆的外觀與所在頁（由編輯器提供；回 `nil` 表示現在不串流）。
struct LiveInkContext {
    let pageId: String
    let rgbaHex: String
    let width: CGFloat
}

/// 掛在一個畫布的繪圖手勢上，把書寫中的點送出去。
@MainActor
final class LiveInkSender: NSObject {
    // profile-scope: device 只當 objc 關聯物件的位址鍵用，不存任何資料
    private static var key: UInt8 = 0
    private weak var canvas: PKCanvasView?
    private var context: () -> LiveInkContext? = { nil }

    private var strokeId: String?
    private var current: LiveInkContext?
    private var pending: [Double] = []
    private var lastSentAt: CFTimeInterval = 0
    private var seq = 0

    /// 每次 `canvasRef` 回呼都叫：第一次掛上手勢，之後只更新外觀來源（SwiftUI 的狀態是值，要拿最新的）。
    static func attach(to canvas: PKCanvasView, context: @escaping () -> LiveInkContext?) {
        if let existing = objc_getAssociatedObject(canvas, &key) as? LiveInkSender {
            existing.context = context
            return
        }
        let sender = LiveInkSender()
        sender.canvas = canvas
        sender.context = context
        canvas.drawingGestureRecognizer.addTarget(sender, action: #selector(handle(_:)))
        objc_setAssociatedObject(canvas, &key, sender, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc private func handle(_ gr: UIGestureRecognizer) {
        guard let canvas else { return }
        switch gr.state {
        case .began:
            guard let ctx = context(), CollaborationManager.shared.isLiveInkReady else {
                strokeId = nil
                return
            }
            strokeId = UUID().uuidString
            current = ctx
            pending = []
            seq = 0
            lastSentAt = 0
            append(gr, in: canvas)
        case .changed:
            guard strokeId != nil else { return }
            append(gr, in: canvas)
            let now = CACurrentMediaTime()
            if now - lastSentAt >= CollaborationManager.liveInkInterval { flush(end: false) }
        case .ended, .cancelled, .failed:
            guard strokeId != nil else { return }
            flush(end: true)
            strokeId = nil
            current = nil
        default:
            break
        }
    }

    private func append(_ gr: UIGestureRecognizer, in canvas: PKCanvasView) {
        // 手勢位置在捲動視圖的內容座標（含縮放）；筆畫座標是未縮放的頁面座標。
        let p = gr.location(in: canvas)
        let zoom = max(canvas.zoomScale, 0.0001)
        pending.append(Double(p.x / zoom))
        pending.append(Double(p.y / zoom))
    }

    private func flush(end: Bool) {
        guard let sid = strokeId, let ctx = current else { return }
        lastSentAt = CACurrentMediaTime()
        guard !pending.isEmpty || end else { return }
        CollaborationManager.shared.sendLiveInk([
            "page": ctx.pageId, "sid": sid, "seq": seq,
            "rgba": ctx.rgbaHex, "w": Double(ctx.width),
            "p": pending, "end": end,
        ])
        seq += 1
        pending = []
    }

    static func hex(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: .current).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> String { String(format: "%02X", Int((min(max(v, 0), 1) * 255).rounded())) }
        return "#" + byte(r) + byte(g) + byte(b) + byte(a)
    }
}

/// 別人書寫中的預覽線。
struct LiveInkStroke: Identifiable {
    let id: String
    let pageId: String
    let color: Color
    let width: CGFloat
    var points: [CGPoint]
    var lastSeq: Int
    var updatedAt: Date
    var ended: Bool
}

@MainActor
final class LiveInkStore: ObservableObject {
    // profile-scope: device 只存活在一場協同的記憶體裡，離開房間即清空（見 `clear()`）
    static let shared = LiveInkStore()
    @Published private(set) var strokes: [String: LiveInkStroke] = [:]
    private var sweeper: Timer?

    /// 收到一段。`seq` 比已收到的舊就丟掉（中繼不保證跨連線順序）。
    func receive(userId: String, payload: [String: Any]) {
        guard let sid = payload["sid"] as? String, let page = payload["page"] as? String else { return }
        let key = userId + "/" + sid
        let seq = (payload["seq"] as? NSNumber)?.intValue ?? 0
        let flat = (payload["p"] as? [NSNumber]) ?? []
        var pts: [CGPoint] = []
        pts.reserveCapacity(flat.count / 2)
        var i = 0
        while i + 1 < flat.count {
            pts.append(CGPoint(x: flat[i].doubleValue, y: flat[i + 1].doubleValue))
            i += 2
        }
        let end = (payload["end"] as? Bool) ?? false
        if var s = strokes[key] {
            guard seq > s.lastSeq else { return }
            s.points += pts
            s.lastSeq = seq
            s.updatedAt = Date()
            s.ended = s.ended || end
            strokes[key] = s
        } else {
            let color = UIColor(hexString: (payload["rgba"] as? String) ?? "").map { Color(uiColor: $0) } ?? .accentColor
            let width = CGFloat((payload["w"] as? NSNumber)?.doubleValue ?? 3)
            strokes[key] = LiveInkStroke(id: key, pageId: page, color: color, width: max(1, width),
                                         points: pts, lastSeq: seq, updatedAt: Date(), ended: end)
        }
        scheduleSweep()
    }

    /// 正式筆畫到了：那個人提筆前的預覽線都收掉。
    func settle(userId: String) {
        let prefix = userId + "/"
        let done = strokes.filter { $0.key.hasPrefix(prefix) && $0.value.ended }.map(\.key)
        guard !done.isEmpty else { return }
        for k in done { strokes.removeValue(forKey: k) }
    }

    func clear() {
        sweeper?.invalidate()
        sweeper = nil
        if !strokes.isEmpty { strokes = [:] }
    }

    /// 正式筆畫沒來（被收回、網路掉了）也不能讓預覽線一直掛著。
    private func scheduleSweep() {
        guard sweeper == nil else { return }
        sweeper = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sweep() }
        }
    }

    private func sweep() {
        let now = Date()
        let stale = strokes.filter {
            now.timeIntervalSince($0.value.updatedAt) > ($0.value.ended ? 1.5 : 3)
        }.map(\.key)
        for k in stale { strokes.removeValue(forKey: k) }
        if strokes.isEmpty {
            sweeper?.invalidate()
            sweeper = nil
        }
    }
}

/// 在頁面座標上畫出別人書寫中的預覽線（與 `RemoteCursorsOverlay` 同一個座標空間）。
struct RemoteLiveInkOverlay: View {
    let pageId: String?
    @ObservedObject var store = LiveInkStore.shared

    var body: some View {
        Canvas { context, _ in
            for stroke in store.strokes.values where stroke.pageId == pageId && stroke.points.count > 0 {
                var path = Path()
                path.move(to: stroke.points[0])
                for p in stroke.points.dropFirst() { path.addLine(to: p) }
                if stroke.points.count == 1 { path.addLine(to: stroke.points[0]) }
                context.stroke(path, with: .color(stroke.color.opacity(0.85)),
                               style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

//
//  CollabLiveInk.swift
//  Kairumo
//
//  協同：書寫中即時串流筆畫（`live_ink`）。
//
//  # 為什麼
//
//  正式的筆畫（`ink_add`）要等提筆才送 —— 對方看到的是「一整筆突然出現」，
//  寫一個字要等好幾筆、每筆都晚一拍，不像在一起寫。這裡在書寫**途中**每 ~50 ms
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

import SwiftUI
import UIKit

/// 把自繪引擎書寫中的點送出去（掛在 `ProInkCollab.liveHandler` 上）。
///
/// 所有筆刷都由自繪引擎收筆（ADR-0015 階段 5），PencilKit 的落筆手勢是關著的 ——
/// 點要從自繪引擎拿，不能掛在 PencilKit 的手勢上。
@MainActor
final class LiveInkSender {
    // profile-scope: device 只在協同房間開著時有作用，離開房間即 uninstall
    static let shared = LiveInkSender()

    /// 頁碼 → 協同頁面 id；回 `nil` 表示現在不串流（不在協同、或那一頁還沒有 id）。
    private var pageIdFor: (_ notebookId: String, _ page: Int) -> String? = { _, _ in nil }

    private var strokeId: String?
    private var pageId: String?
    private var rgbaHex = "#000000FF"
    private var width: Double = 3
    private var pending: [Double] = []
    private var lastSentAt: CFTimeInterval = 0
    private var seq = 0

    /// 進入協同時由編輯器呼叫；`pageIdFor` 每次都取最新的頁面清單。
    func install(pageIdFor: @escaping (_ notebookId: String, _ page: Int) -> String?) {
        self.pageIdFor = pageIdFor
        ProInkCollab.liveHandler = { notebookId, page, phase, stroke, points in
            LiveInkSender.shared.handle(notebookId: notebookId, page: page, phase: phase,
                                        stroke: stroke, points: points)
        }
    }

    func uninstall() {
        ProInkCollab.liveHandler = nil
        pageIdFor = { _, _ in nil }
        strokeId = nil
    }

    private func handle(notebookId: String, page: Int, phase: Int, stroke: ProStroke?, points: [ProPoint]) {
        switch phase {
        case 0:
            guard let stroke, CollaborationManager.shared.isLiveInkReady,
                  let pid = pageIdFor(notebookId, page) else {
                strokeId = nil
                return
            }
            strokeId = UUID().uuidString
            pageId = pid
            rgbaHex = "#" + stroke.colorRGBA.prefix(4).map { String(format: "%02X", $0) }.joined()
            width = Double(stroke.baseWidth)
            pending = []
            seq = 0
            lastSentAt = 0
            append(points)
        case 1:
            guard strokeId != nil else { return }
            append(points)
            if CACurrentMediaTime() - lastSentAt >= CollaborationManager.liveInkInterval { flush(end: false) }
        default:
            guard strokeId != nil else { return }
            flush(end: true)
            strokeId = nil
        }
    }

    private func append(_ points: [ProPoint]) {
        for p in points {
            pending.append(Double(p.x))
            pending.append(Double(p.y))
        }
    }

    private func flush(end: Bool) {
        guard let sid = strokeId, let pid = pageId else { return }
        lastSentAt = CACurrentMediaTime()
        guard !pending.isEmpty || end else { return }
        CollaborationManager.shared.sendLiveInk([
            "page": pid, "sid": sid, "seq": seq,
            "rgba": rgbaHex, "w": width,
            "p": pending, "end": end,
        ])
        seq += 1
        pending = []
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

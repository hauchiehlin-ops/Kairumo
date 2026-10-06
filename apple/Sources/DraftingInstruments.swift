import UIKit

/// 頁面上的一把虛擬尺規：種類、大小、位置與轉角。形狀（外框、刻度、靠邊）全由核心給（`draft_instrument_geometry`）。
///
/// 座標：核心給的幾何以尺的左上角為原點；這裡用 `origin`（頁面座標）加繞幾何中心的 `angle`（弧度）變到頁面上。
struct InstrumentModel {
    let kind: String
    let sizeMm: Double
    let geometry: FfiInstrumentGeometry
    private(set) var origin: CGPoint
    private(set) var angle: CGFloat = 0

    init?(kind: String, sizeMm: Double, pageWidth: CGFloat, center: CGPoint) {
        guard let g = draftInstrumentGeometry(kind: kind, sizeMm: Float(sizeMm), pageWidth: Float(pageWidth)) else { return nil }
        self.kind = kind
        self.sizeMm = sizeMm
        geometry = g
        // 丁字尺貼著頁面左緣，只能上下滑。
        origin = g.verticalOnly
            ? CGPoint(x: 0, y: center.y - CGFloat(g.height) / 2)
            : CGPoint(x: center.x - CGFloat(g.width) / 2, y: center.y - CGFloat(g.height) / 2)
    }

    var verticalOnly: Bool { geometry.verticalOnly }

    private var pivot: CGPoint { CGPoint(x: CGFloat(geometry.width) / 2, y: CGFloat(geometry.height) / 2) }

    /// 尺本身的座標 → 頁面座標。
    func toPage(_ p: FfiPoint) -> CGPoint {
        let dx = CGFloat(p.x) - pivot.x, dy = CGFloat(p.y) - pivot.y
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: origin.x + pivot.x + dx * c - dy * s, y: origin.y + pivot.y + dx * s + dy * c)
    }

    func toLocal(_ q: CGPoint) -> CGPoint {
        let dx = q.x - origin.x - pivot.x, dy = q.y - origin.y - pivot.y
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: pivot.x + dx * c + dy * s, y: pivot.y - dx * s + dy * c)
    }

    /// 靠著畫線的邊（頁面座標）。
    var pageEdges: [(CGPoint, CGPoint)] {
        geometry.edges.map { (toPage($0.a), toPage($0.b)) }
    }

    var pageOutline: [[CGPoint]] { geometry.outline.map { $0.map(toPage) } }

    mutating func move(by delta: CGSize) {
        origin.y += delta.height
        if !verticalOnly { origin.x += delta.width }
    }

    mutating func rotate(by degrees: Double) {
        guard !verticalOnly else { return }
        angle += CGFloat(degrees * .pi / 180)
    }

    var angleDegrees: Double { Double(angle) * 180 / .pi }

    /// 點在尺的身體上（外框內）。
    func containsBody(_ q: CGPoint) -> Bool {
        let l = toLocal(q)
        return CGRect(x: 0, y: 0, width: CGFloat(geometry.width), height: CGFloat(geometry.height)).contains(l)
    }

    /// 離哪一條邊最近（`band` 之內）：回邊的起點、終點與 `q` 投影在那條邊所在直線上的點。
    func nearestEdge(to q: CGPoint, band: CGFloat) -> (a: CGPoint, b: CGPoint, foot: CGPoint)? {
        var best: (CGPoint, CGPoint, CGPoint, CGFloat)?
        for (a, b) in pageEdges {
            let foot = Self.footOnLine(q, a, b)
            let d = hypot(foot.x - q.x, foot.y - q.y)
            // 必須落在邊的範圍附近（沿邊方向超出太多不算靠著）。
            let along = Self.alongFraction(q, a, b)
            guard d <= band, along > -0.05, along < 1.05 else { continue }
            if d < (best?.3 ?? .greatestFiniteMagnitude) { best = (a, b, foot, d) }
        }
        return best.map { ($0.0, $0.1, $0.2) }
    }

    static func footOnLine(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let vx = b.x - a.x, vy = b.y - a.y
        let len2 = vx * vx + vy * vy
        guard len2 > 1e-9 else { return a }
        let t = ((p.x - a.x) * vx + (p.y - a.y) * vy) / len2
        return CGPoint(x: a.x + vx * t, y: a.y + vy * t)
    }

    private static func alongFraction(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let vx = b.x - a.x, vy = b.y - a.y
        let len2 = vx * vx + vy * vy
        return len2 > 1e-9 ? ((p.x - a.x) * vx + (p.y - a.y) * vy) / len2 : 0
    }

    /// 把尺畫進 `ctx`：半透明身體、外框、刻度與數字。
    func draw(in ctx: CGContext, dark: Bool) {
        let ink = dark ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.12, alpha: 1)
        ctx.saveGState()
        for ring in pageOutline where ring.count >= 3 {
            ctx.beginPath()
            ctx.move(to: ring[0])
            for p in ring.dropFirst() { ctx.addLine(to: p) }
            ctx.closePath()
            ctx.setFillColor(UIColor.systemTeal.withAlphaComponent(0.16).cgColor)
            ctx.setStrokeColor(UIColor.systemTeal.withAlphaComponent(0.85).cgColor)
            ctx.setLineWidth(1.4)
            ctx.drawPath(using: .fillStroke)
        }
        ctx.setStrokeColor(ink.withAlphaComponent(0.8).cgColor)
        for tick in geometry.ticks {
            ctx.setLineWidth(tick.weight == 2 ? 1.1 : 0.7)
            ctx.beginPath()
            ctx.move(to: toPage(tick.a))
            ctx.addLine(to: toPage(tick.b))
            ctx.strokePath()
            if let label = tick.label {
                let at = toPage(tick.labelAt)
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: ink]
                let size = (label as NSString).size(withAttributes: attrs)
                UIGraphicsPushContext(ctx)
                (label as NSString).draw(at: CGPoint(x: at.x - size.width / 2, y: at.y - size.height / 2), withAttributes: attrs)
                UIGraphicsPopContext()
            }
        }
        // 靠邊畫線的那一邊加粗，看得出哪裡可以靠。
        ctx.setStrokeColor(UIColor.systemTeal.cgColor)
        ctx.setLineWidth(2)
        for (a, b) in pageEdges {
            ctx.beginPath()
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// 包含整把尺的範圍（重畫用）。
    var bounds: CGRect {
        pageOutline.flatMap { $0 }.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
            .insetBy(dx: -24, dy: -24)
    }
}

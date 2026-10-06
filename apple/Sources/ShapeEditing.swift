//
//  ShapeEditing.swift
//  Kairumo
//
//  畫布上的形狀與連接線：顯示、選取、縮放、旋轉、端點編修、連線與樣式面板。
//
//  # 設計目標：Office 等級的流程圖編修
//
//  - 形狀：八個縮放把手（對面那條邊在畫布上釘住，轉過角度也成立）、
//    旋轉把手、四個連接點「+」（拖到另一個形狀就連線）、編修面板
//    （文字、填色、線條、虛實、圓角、位置與大小、種類替換、複製、層級）。
//  - 線／箭頭／雙箭頭：兩個端點各自可拖，任何角度、任何長度
//    （存成既有的「外框＋旋轉」兩個欄位，見 `ShapeFrameMath.lineFrame`）。
//  - 連接線：可選取、可改走線（直線／直角）、兩端的端點樣式、出入位置、
//    顏色、粗細、虛實、標籤，也能反轉方向。
//
//  幾何一律來自核心（`shapeOutline`／`connectionPath`／`shapeAnchorPoint`），
//  這裡只做「手指到數字」的換算；換算的算術在 `ShapeFrameMath`，由單元測試釘住。

import SwiftUI

// MARK: - 名稱

enum ShapeKindLabel {
    /// 形狀的顯示名稱。
    ///
    /// 走語系表而不是 `NoteShapeAttachment.name(of:)` —— 後者是**持久化用的
    /// 識別字**（小寫的列舉名），拿來顯示的話，中文介面裡會出現
    /// 「arrowblockright」。
    @MainActor
    static func text(for kind: FfiShapeKind) -> String {
        let key = "shape_kind_\(NoteShapeAttachment.name(of: kind))"
        let localized = LocalizationManager.shared.localized(key)
        // 語系表裡沒有的（核心新增了形狀但字串還沒補）退回識別字，
        // 而不是顯示一個空白的格子。
        return localized == key ? NoteShapeAttachment.name(of: kind) : localized
    }
}

// MARK: - 形狀本體

/// 畫布上的一個形狀。
///
/// 外框照核心算好的頂點畫 —— 這一層不做任何幾何。自己畫一個「差不多的菱形」
/// 的話，同一張流程圖在 Android 上的頂點位置會不一樣，連接線的落點也就跟著錯。
///
/// 收進來的 `shape` 已經帶著拖曳中的即時外框（見 `ShapeAttachmentItemView`），
/// 所以輪廓永遠是照**畫出來的尺寸**算的。
struct NoteShapeView: View {
    let shape: NoteShapeAttachment
    var isSelected: Bool

    /// 畫布比外框多出來的邊。箭頭、粗線、虛線端點都會超出 bounds，
    /// 沒有這圈邊的話線狀形狀的端點會被裁掉。
    static let overflow: CGFloat = 24

    var body: some View {
        ZStack {
            Canvas { context, _ in draw(into: &context) }
                .frame(width: shape.width + Self.overflow * 2,
                       height: shape.height + Self.overflow * 2)
                .allowsHitTesting(false)

            if shape.acceptsText && !shape.label.isEmpty {
                Text(shape.label)
                    .font(.system(size: shape.fontSize ?? 14,
                                  weight: (shape.isBold ?? false) ? .bold : .regular))
                    .italic(shape.isItalic ?? false)
                    .foregroundColor(shape.textColorHex.flatMap(Color.init(hex:)) ?? .primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(6)
                    .frame(width: shape.width, height: shape.height)
                    .allowsHitTesting(false)
            }
        }
        .opacity(shape.opacity ?? 1)
        .frame(width: shape.width, height: shape.height)
        .overlay(
            Rectangle()
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.7) : .clear,
                              style: StrokeStyle(lineWidth: 1, dash: shape.isLinear ? [] : [4, 3]))
                .opacity(shape.isLinear ? 0 : 1)
        )
    }

    private func draw(into context: inout GraphicsContext) {
        let points = shape.outline()
        guard points.count >= 2 else { return }
        let o = Self.overflow
        func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - shape.x + o, y: p.y - shape.y + o) }

        var path = Path()
        path.move(to: local(points[0]))
        for point in points.dropFirst() { path.addLine(to: local(point)) }
        // 線狀形狀（線／箭頭／雙箭頭）只有兩個點，不能收尾也不能填色。
        if !shape.isLinear {
            path.closeSubpath()
            if shape.drawsOutline, let fill = fillColor { context.fill(path, with: .color(fill)) }
        }
        // 平行模式與註解：輪廓只是點擊範圍，畫出來的是內部的線。
        if shape.drawsOutline {
            context.stroke(path, with: .color(strokeColor),
                           style: shape.dash.strokeStyle(lineWidth: shape.lineWidth))
        }
        drawDetails(into: &context, local: local)

        for head in shape.arrowHeads() where head.count >= 3 {
            var tri = Path()
            tri.move(to: local(head[0]))
            for point in head.dropFirst() { tri.addLine(to: local(point)) }
            tri.closeSubpath()
            context.fill(tri, with: .color(strokeColor))
        }
    }

    /// 立體圖的面（明暗）與稜線、流程圖符號裡的線。幾何來自核心，與 Android 同一份。
    private func drawDetails(into context: inout GraphicsContext, local: (CGPoint) -> CGPoint) {
        for detail in shape.details() where detail.points.count >= 2 {
            var path = Path()
            path.move(to: local(CGPoint(x: CGFloat(detail.points[0].x), y: CGFloat(detail.points[0].y))))
            for p in detail.points.dropFirst() {
                path.addLine(to: local(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))))
            }
            if detail.closed {
                path.closeSubpath()
                if detail.tone != 0 {
                    // 面的明暗疊在形狀自己的填色上：亮面疊白、暗面疊黑。
                    let overlay: Color = detail.tone > 0
                        ? Color.white.opacity(Double(detail.tone))
                        : Color.black.opacity(Double(-detail.tone))
                    context.fill(path, with: .color(overlay))
                }
            }
            let style = detail.dashed
                ? StrokeStyle(lineWidth: max(1, shape.lineWidth * 0.8), lineCap: .butt, lineJoin: .round,
                              dash: [shape.lineWidth * 3, shape.lineWidth * 2.5])
                : shape.dash.strokeStyle(lineWidth: shape.lineWidth)
            context.stroke(path, with: .color(strokeColor), style: style)
        }
    }

    private var strokeColor: Color {
        shape.strokeColorHex.flatMap(Color.init(hex:)) ?? .primary
    }

    private var fillColor: Color? {
        guard let hex = shape.fillColorHex else { return nil }
        // "clear" 是哨符不是顏色 —— 走顏色轉換會變成黑色。
        return hex == "clear" ? nil : Color(hex: hex)
    }
}

/// 線狀形狀的點擊區：沿著線兩側各 14pt。
///
/// 線狀形狀的外框只有 2pt 高，拿外框當點擊區的話根本點不到。
private struct LineHitShape: Shape {
    let start: CGPoint
    let end: CGPoint
    var width: CGFloat = 28

    // unused-param-ok: `Shape` 協定規定的簽章。端點是形狀自己的本地座標，不依賴視圖的矩形。
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        return p.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

// MARK: - 畫布上的形狀物件

/// 畫布上的形狀物件：選取、拖曳、八向縮放、旋轉、線段端點、連接點。
struct ShapeAttachmentItemView: View {
    @Binding var shape: NoteShapeAttachment
    /// 選取狀態由外面管 —— 群組要整組一起亮起來，各自為政的話做不到。
    let isSelected: Bool
    /// 只選了這一個。連接點與端點把手只在單選時出現 ——
    /// 多選時拖一個點是要搬整批，不是要拉線。
    var isSoleSelection: Bool = true
    let onSelect: () -> Void
    /// 拖曳的位移。同一組的其他成員要跟著走，那是呼叫端的事。
    let onMove: (CGSize) -> Void
    let onDelete: () -> Void
    var onEdit: () -> Void = {}
    /// 從連接點拉線。`finished == false` 是拖曳中（畫預覽線），
    /// `true` 是放開（由呼叫端決定連到誰）。座標是畫布座標。
    var onConnectDrag: (ShapeAnchorName, CGPoint, CGPoint, Bool) -> Void = { _, _, _, _ in }

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var dragOffset: CGSize = .zero
    @State private var isEditingLabel: Bool = false

    /// 縮放／端點拖曳中的即時外框與角度。
    ///
    /// 拖曳每一幀都寫回 `shape` 的話，整份筆記會跟著每一幀存檔；
    /// 只在手勢結束時提交一次。
    @State private var liveFrame: CGRect? = nil
    @State private var liveRotation: Double? = nil
    @State private var resizeBase: CGRect? = nil
    @State private var endpointBase: (start: CGPoint, end: CGPoint)? = nil

    private var frame: CGRect {
        liveFrame ?? CGRect(x: shape.x, y: shape.y, width: shape.width, height: shape.height)
    }
    private var rotation: Double { liveRotation ?? shape.canvasRotation }

    /// 帶著即時外框與角度的形狀副本，輪廓、箭頭、連接點都由它算。
    private var display: NoteShapeAttachment {
        var probe = shape
        probe.x = frame.minX; probe.y = frame.minY
        probe.width = frame.width; probe.height = frame.height
        probe.canvasRotation = rotation
        return probe
    }

    var body: some View {
        let shown = display
        let currentX = frame.minX + dragOffset.width
        let currentY = frame.minY + dragOffset.height

        ZStack {
            rotatedBody(shown)
            if isSelected {
                if shown.isLinear {
                    if isSoleSelection { endpointHandles(shown) }
                } else {
                    rotationHandle(shown)
                }
                actionButtons
                if isSoleSelection && !shown.isLinear { connectHandles(shown) }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .objectProbe("shape")
        .position(x: currentX + frame.width / 2, y: currentY + frame.height / 2)
        .animation(nil, value: dragOffset)
        .alert(
            localizationManager.localized("shape_label"),
            isPresented: $isEditingLabel
        ) {
            TextField(localizationManager.localized("shape_label"), text: $shape.label)
            Button(localizationManager.localized("done")) { isEditingLabel = false }
        }
    }

    // MARK: 本體（會跟著旋轉的那一層）

    private func rotatedBody(_ shown: NoteShapeAttachment) -> some View {
        ZStack {
            NoteShapeView(shape: shown, isSelected: isSelected)
                .contentShape(hitShape(shown))
                // 單擊選取。**一定要有這一行**：下面的拖曳手勢最小距離是 5pt，
                // 單純點一下它根本不會觸發，原本「點一下就選取」寫在拖曳的
                // `onEnded` 裡（位移 < 4 的分支）—— 那條路徑永遠走不到，
                // 結果是形狀完全選不起來，縮放、旋轉、樣式把手也就都出不來。
                .onTapGesture(count: 2) {
                    if shown.acceptsText { isEditingLabel = true } else { onEdit() }
                }
                .onTapGesture { onSelect() }
                .gesture(moveGesture)

            // 縮放把手掛在旋轉那一層裡面 —— 它們要貼著轉過的邊。
            // 位移的換算（畫布 → 本地軸）在 `ShapeFrameMath.resized`。
            if isSelected && isSoleSelection && !shown.isLinear {
                ForEach(ShapeHandle.allCases) { handle in
                    resizeHandle(handle, shown)
                }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .rotationEffect(.degrees(rotation))
        .contextMenu {
            Button { onEdit() } label: {
                Label(localizationManager.localized("edit"), systemImage: "slider.horizontal.3")
            }
            ObjectOrderMenu(id: shape.id)
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(localizationManager.localized("delete"), systemImage: "trash")
            }
        }
    }

    private func hitShape(_ shown: NoteShapeAttachment) -> AnyShape {
        if shown.isLinear {
            // 端點換成本地座標（未旋轉的外框座標系）：線在本地就是對角線。
            return AnyShape(LineHitShape(
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: shown.width, y: shown.height)))
        }
        return AnyShape(Rectangle())
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onChanged { value in
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) { dragOffset = value.translation }
            }
            .onEnded { value in
                if hypot(value.translation.width, value.translation.height) < 4 {
                    onSelect()
                } else {
                    onMove(dragOffset)
                }
                dragOffset = .zero
            }
    }

    // MARK: 縮放把手

    private func resizeHandle(_ handle: ShapeHandle, _ shown: NoteShapeAttachment) -> some View {
        let w = shown.width, h = shown.height
        return Circle()
            .fill(Color(uiColor: .systemBackground))
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: 11, height: 11)
            // 視覺 11pt，點擊區 30pt：手指碰不到更小的東西。
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel(localizationManager.localized("resize"))
            .accessibilityAddTraits(.isButton)
            .position(x: w / 2 + handle.sx * w / 2, y: h / 2 + handle.sy * h / 2)
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        let base = resizeBase
                            ?? CGRect(x: shape.x, y: shape.y, width: shape.width, height: shape.height)
                        if resizeBase == nil { resizeBase = base }
                        liveFrame = ShapeFrameMath.resized(
                            base, rotation: shape.canvasRotation,
                            handle: handle, translation: value.translation)
                    }
                    .onEnded { _ in
                        if let f = liveFrame {
                            shape.x = f.minX; shape.y = f.minY
                            shape.width = f.width; shape.height = f.height
                        }
                        resizeBase = nil
                        liveFrame = nil
                    }
            )
            .accessibilityLabel(localizationManager.localized("resize_shape"))
    }

    // MARK: 旋轉

    private func rotationHandle(_ shown: NoteShapeAttachment) -> some View {
        ObjectRotationHandle(
            degrees: Binding(
                get: { liveRotation ?? shape.canvasRotation },
                set: { liveRotation = $0 }),
            size: CGSize(width: shown.width, height: shown.height)
        ) {
            if let r = liveRotation { shape.canvasRotation = r }
            liveRotation = nil
        }
    }

    // MARK: 線段端點

    private func endpointHandles(_ shown: NoteShapeAttachment) -> some View {
        let ends = shown.lineEndpoints
        let origin = CGPoint(x: shown.x, y: shown.y)
        return ZStack {
            endpointHandle(ends.start, origin: origin, isStart: true)
            endpointHandle(ends.end, origin: origin, isStart: false)
        }
    }

    private func endpointHandle(_ point: CGPoint, origin: CGPoint, isStart: Bool) -> some View {
        Circle()
            .fill(Color.accentColor)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .frame(width: 14, height: 14)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .position(x: point.x - origin.x, y: point.y - origin.y)
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        let base = endpointBase ?? shape.lineEndpoints
                        if endpointBase == nil { endpointBase = base }
                        let moved = CGPoint(
                            x: (isStart ? base.start : base.end).x + value.translation.width,
                            y: (isStart ? base.start : base.end).y + value.translation.height)
                        let a = isStart ? moved : base.start
                        let b = isStart ? base.end : moved
                        let result = ShapeFrameMath.lineFrame(from: a, to: b)
                        liveFrame = result.frame
                        liveRotation = result.rotation
                    }
                    .onEnded { _ in
                        if let f = liveFrame, let r = liveRotation {
                            shape.x = f.minX; shape.y = f.minY
                            shape.width = f.width; shape.height = f.height
                            shape.canvasRotation = r
                        }
                        endpointBase = nil
                        liveFrame = nil
                        liveRotation = nil
                    }
            )
            .accessibilityLabel(localizationManager.localized("line_endpoint_handle"))
    }

    // MARK: 連接點

    private func connectHandles(_ shown: NoteShapeAttachment) -> some View {
        let origin = CGPoint(x: shown.x, y: shown.y)
        return ZStack {
            ForEach(ShapeAnchorName.allCases) { anchor in
                connectHandle(anchor, shown: shown, origin: origin)
            }
        }
    }

    private func connectHandle(
        _ anchor: ShapeAnchorName, shown: NoteShapeAttachment, origin: CGPoint
    ) -> some View {
        let edge = shown.anchorPoint(anchor)
        // 往外推 18pt（沿旋轉後的法線），不要壓在縮放把手上。
        let normal: CGPoint = {
            switch anchor {
            case .top: return CGPoint(x: 0, y: -1)
            case .right: return CGPoint(x: 1, y: 0)
            case .bottom: return CGPoint(x: 0, y: 1)
            case .left: return CGPoint(x: -1, y: 0)
            }
        }()
        let r = ShapeFrameMath.rotate(normal, about: .zero, degrees: shown.canvasRotation)
        let spot = CGPoint(x: edge.x + r.x * 18 - origin.x, y: edge.y + r.y * 18 - origin.y)

        return Image(systemName: "plus")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(Circle().fill(Color.green))
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .position(x: spot.x, y: spot.y)
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        onConnectDrag(anchor, edge, value.location, false)
                    }
                    .onEnded { value in
                        onConnectDrag(anchor, edge, value.location, true)
                    }
            )
            .accessibilityLabel(localizationManager.localized("connection_handle"))
    }

    // MARK: 動作列

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: onEdit) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("edit"))

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("action_delete"))
        }
        .position(x: frame.width + 4, y: -14)
    }
}

// MARK: - 連接線

/// 兩個形狀之間的連接線。路徑與箭頭都來自核心。
struct ConnectionLineView: View {
    let connection: NoteConnectionAttachment
    let geometry: ShapeGeometry.Connection
    var isSelected: Bool = false
    var onSelect: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        ZStack {
            Canvas { context, _ in draw(into: &context) }
                .allowsHitTesting(false)

            if isSelected {
                HStack(spacing: 6) {
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .position(x: geometry.midpoint.x, y: geometry.midpoint.y - 22)
            }

            if !connection.label.isEmpty {
                Text(connection.label)
                    .font(.system(size: 12))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(uiColor: .systemBackground).opacity(0.9))
                    .cornerRadius(4)
                    .position(geometry.midpoint)
                    .allowsHitTesting(false)
            }
        }
        // 點擊區沿著路徑兩側各 12pt —— 線只有 2pt 寬，點不中。
        .contentShape(HitPath(points: geometry.path))
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onEdit() }
    }

    private func draw(into context: inout GraphicsContext) {
        var path = Path()
        path.move(to: geometry.path[0])
        for point in geometry.path.dropFirst() { path.addLine(to: point) }
        if isSelected {
            context.stroke(path, with: .color(Color.accentColor.opacity(0.28)),
                           style: StrokeStyle(lineWidth: connection.lineWidth + 8, lineCap: .round, lineJoin: .round))
        }
        context.stroke(path, with: .color(color),
                       style: connection.dash.strokeStyle(lineWidth: connection.lineWidth))

        for cap in [geometry.startCap, geometry.endCap].compactMap({ $0 }) {
            draw(cap, into: &context)
        }
        if isSelected {
            for p in [geometry.path.first, geometry.path.last].compactMap({ $0 }) {
                let dot = Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
                context.fill(dot, with: .color(.white))
                context.stroke(dot, with: .color(.accentColor), lineWidth: 2)
            }
        }
    }

    private func draw(_ cap: ShapeGeometry.Cap, into context: inout GraphicsContext) {
        switch cap.kind {
        case .none:
            break
        case .arrow, .diamond:
            guard cap.points.count >= 3 else { return }
            var p = Path()
            p.move(to: cap.points[0])
            for point in cap.points.dropFirst() { p.addLine(to: point) }
            p.closeSubpath()
            context.fill(p, with: .color(color))
        case .hollow:
            guard cap.points.count >= 3 else { return }
            var p = Path()
            p.move(to: cap.points[0])
            for point in cap.points.dropFirst() { p.addLine(to: point) }
            p.closeSubpath()
            // 空心 = 底色填滿再描邊，這樣線不會從箭頭裡穿出來。
            context.fill(p, with: .color(Color(uiColor: .systemBackground)))
            context.stroke(p, with: .color(color), lineWidth: connection.lineWidth)
        case .circle:
            let c = cap.center, r = cap.radius
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(color))
        }
    }

    private var color: Color {
        connection.colorHex.flatMap(Color.init(hex:)) ?? .primary
    }
}

private struct HitPath: Shape {
    let points: [CGPoint]
    // unused-param-ok: `Shape` 協定規定的簽章。路徑在畫布座標裡，不依賴視圖的矩形。
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for point in points.dropFirst() { p.addLine(to: point) }
        return p.strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
    }
}

/// 拖曳連線時的預覽線。
struct ConnectionDraftView: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        Canvas { context, _ in
            var p = Path()
            p.move(to: from)
            p.addLine(to: to)
            context.stroke(p, with: .color(.green),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
            let dot = Path(ellipseIn: CGRect(x: to.x - 5, y: to.y - 5, width: 10, height: 10))
            context.fill(dot, with: .color(.green))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 編修面板

/// 一排顏色格。與文字方塊邊框用同一組顏色 —— 同一份筆記裡兩種物件的可選色不同，
/// 使用者會以為是兩套系統。來源是核心的 `borderPalette()`。
struct ColorSwatchRow: View {
    let selected: String?
    var includeClear: Bool = false
    let set: (String?) -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var palette: [String] { borderPalette().map(\.hex) }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 6)],
                  alignment: .leading, spacing: 6) {
            if includeClear {
                Button { set("clear") } label: {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.001))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(
                                selected == "clear" ? Color.accentColor : Color.secondary.opacity(0.4),
                                lineWidth: selected == "clear" ? 2.5 : 1))
                        // 透明畫一條斜線 —— 不畫的話它跟白色長得一樣。
                        Path { p in
                            p.move(to: CGPoint(x: 5, y: 19))
                            p.addLine(to: CGPoint(x: 19, y: 5))
                        }
                        .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
                .accessibilityLabel(localizationManager.localized("color_transparent"))
            }
            ForEach(palette, id: \.self) { hex in
                Button { set(hex) } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(
                            selected == hex ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: selected == hex ? 2.5 : 1))
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
        }
    }
}

/// 面板裡的一個小節標題。
private struct PanelSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

/// 形狀編修面板（浮動面板的內容）。
struct ShapeEditPanel: View {
    @Binding var shape: NoteShapeAttachment
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared

    private func t(_ key: String) -> String { localizationManager.localized(key) }

    /// 替換種類時只列同一類的：線換成方塊，兩點的對角線會變成一個零面積的方塊。
    private var swappableKinds: [FfiShapeKind] {
        allShapeKinds().filter { shapeIsLinear(kind: $0) == shape.isLinear }
    }

    private var hasCornerRadius: Bool {
        ["roundedrectangle", "terminator", "alternateprocess"].contains(shape.kindName.lowercased())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ObjectOrderBar(id: shape.id)

            PanelSection(title: t("shape_change_kind")) {
                Menu {
                    ForEach(swappableKinds, id: \.self) { kind in
                        Button(ShapeKindLabel.text(for: kind)) {
                            shape.apply(kind: kind)
                        }
                    }
                } label: {
                    HStack {
                        Text(ShapeKindLabel.text(for: shape.kind))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
                }
            }

            if shape.acceptsText { textSection }

            if !shape.isLinear {
                PanelSection(title: t("fill_color")) {
                    ColorSwatchRow(selected: shape.fillColorHex, includeClear: true) {
                        shape.fillColorHex = $0
                    }
                }
            }

            PanelSection(title: t("stroke_color")) {
                ColorSwatchRow(selected: shape.strokeColorHex) { shape.strokeColorHex = $0 }
            }

            PanelSection(title: t("line_width")) {
                HStack {
                    Slider(value: Binding(
                        get: { Double(shape.lineWidth) },
                        set: { shape.lineWidth = CGFloat($0) }), in: 0.5...12, step: 0.5)
                    Text(String(format: "%.1f", shape.lineWidth))
                        .font(.caption).monospacedDigit().frame(width: 32, alignment: .trailing)
                }
            }

            PanelSection(title: t("shape_line_style")) {
                Picker("", selection: Binding(
                    get: { shape.dash },
                    set: { shape.dashStyle = $0 == .solid ? nil : $0.rawValue })) {
                    ForEach(ShapeDash.allCases) { Text(t($0.labelKey)).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if hasCornerRadius {
                PanelSection(title: t("shape_corner")) {
                    Slider(value: Binding(
                        get: { Double(shape.cornerRadius) },
                        set: { shape.cornerRadius = CGFloat($0) }),
                           in: 0...Double(max(1, min(shape.width, shape.height) / 2)))
                }
            }

            if shape.isSolid {
                // 立體圖的深度：`cornerRadius` 就是核心用的深度，核心會夾在短邊的 10%–50%。
                PanelSection(title: t("shape_depth")) {
                    let m = max(1, min(shape.width, shape.height))
                    Slider(value: Binding(
                        get: { Double(min(max(shape.cornerRadius, m * 0.1), m * 0.5)) },
                        set: { shape.cornerRadius = CGFloat($0) }),
                           in: Double(m * 0.1)...Double(m * 0.5))
                }
            }

            PanelSection(title: t("opacity")) {
                Slider(value: Binding(
                    get: { shape.opacity ?? 1 },
                    set: { shape.opacity = $0 >= 0.999 ? nil : $0 }), in: 0.1...1)
            }

            PanelSection(title: t("shape_rotation")) {
                ObjectRotationDial(degrees: $shape.canvasRotation)
            }

            if !shape.isLinear { sizeSection }

            HStack {
                Button(action: onDuplicate) {
                    Label(t("shape_duplicate"), systemImage: "plus.square.on.square")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label(t("delete"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)

            if !shape.isLinear {
                Text(t("shape_flowchart_hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var textSection: some View {
        PanelSection(title: t("shape_text_section")) {
            TextField(t("shape_label"), text: $shape.label, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Stepper(value: Binding(
                    get: { shape.fontSize ?? 14 },
                    set: { shape.fontSize = $0 == 14 ? nil : $0 }), in: 8...64, step: 1) {
                    Text("\(Int(shape.fontSize ?? 14)) pt").font(.caption).monospacedDigit()
                }
                toggleButton("bold", on: shape.isBold ?? false, key: "font_bold") {
                    shape.isBold = $0 ? true : nil
                }
                toggleButton("italic", on: shape.isItalic ?? false, key: "font_italic") {
                    shape.isItalic = $0 ? true : nil
                }
            }
            ColorSwatchRow(selected: shape.textColorHex) { shape.textColorHex = $0 }
        }
    }

    private func toggleButton(
        _ symbol: String, on: Bool, key: String, set: @escaping (Bool) -> Void
    ) -> some View {
        Button { set(!on) } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 28)
                .foregroundColor(on ? .white : .primary)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(on ? Color.accentColor : Color.secondary.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t(key))
    }

    private var sizeSection: some View {
        PanelSection(title: t("shape_geometry_section")) {
            HStack(spacing: 10) {
                numberField(t("shape_width"), value: Binding(
                    get: { shape.width }, set: { shape.width = max(ShapeFrameMath.minSide, $0) }))
                numberField(t("shape_height"), value: Binding(
                    get: { shape.height }, set: { shape.height = max(ShapeFrameMath.minSide, $0) }))
            }
        }
    }

    private func numberField(_ title: String, value: Binding<CGFloat>) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("", value: Binding(
                get: { Double(value.wrappedValue.rounded()) },
                set: { value.wrappedValue = CGFloat($0) }), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
                .frame(width: 64)
        }
    }
}

/// 連接線編修面板。
struct ConnectionEditPanel: View {
    @Binding var connection: NoteConnectionAttachment
    let onDelete: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    private func t(_ key: String) -> String { localizationManager.localized(key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ObjectOrderBar(id: connection.id)

            PanelSection(title: t("connection_route")) {
                Picker("", selection: Binding(
                    get: { connection.routeName ?? .orthogonal },
                    set: { connection.route = $0.rawValue })) {
                    ForEach(ConnectionRouteName.allCases) { Text(t($0.labelKey)).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            PanelSection(title: t("connection_start_cap")) { capPicker(isStart: true) }
            PanelSection(title: t("connection_end_cap")) { capPicker(isStart: false) }

            HStack(spacing: 10) {
                anchorMenu(t("connection_from_anchor"), selection: $connection.fromAnchor)
                anchorMenu(t("connection_to_anchor"), selection: $connection.toAnchor)
            }

            PanelSection(title: t("shape_label")) {
                TextField(t("shape_label"), text: $connection.label)
                    .textFieldStyle(.roundedBorder)
            }

            PanelSection(title: t("stroke_color")) {
                ColorSwatchRow(selected: connection.colorHex) { connection.colorHex = $0 }
            }

            PanelSection(title: t("line_width")) {
                HStack {
                    Slider(value: Binding(
                        get: { Double(connection.lineWidth) },
                        set: { connection.lineWidth = CGFloat($0) }), in: 0.5...10, step: 0.5)
                    Text(String(format: "%.1f", connection.lineWidth))
                        .font(.caption).monospacedDigit().frame(width: 32, alignment: .trailing)
                }
            }

            PanelSection(title: t("shape_line_style")) {
                Picker("", selection: Binding(
                    get: { connection.dash },
                    set: { connection.dashStyle = $0 == .solid ? nil : $0.rawValue })) {
                    ForEach(ShapeDash.allCases) { Text(t($0.labelKey)).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Button { connection.reverse() } label: {
                    Label(t("connection_reverse"), systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label(t("delete"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
    }

    private func capPicker(isStart: Bool) -> some View {
        let current = isStart ? connection.startCapName : connection.endCapName
        return Menu {
            ForEach(ConnectionCapName.allCases) { cap in
                Button(t(cap.labelKey)) {
                    // 預設值（起點無、終點箭頭）存成 nil，保持檔案乾淨。
                    let isDefault = isStart ? cap == .none : cap == .arrow
                    if isStart { connection.startCap = isDefault ? nil : cap.rawValue }
                    else { connection.endCap = isDefault ? nil : cap.rawValue }
                }
            }
        } label: {
            HStack {
                Text(t(current.labelKey))
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
        }
    }

    private func anchorMenu(_ title: String, selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Menu {
                Button(t("anchor_auto")) { selection.wrappedValue = nil }
                ForEach(ShapeAnchorName.allCases) { anchor in
                    Button(t(anchor.labelKey)) { selection.wrappedValue = anchor.rawValue }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.flatMap(ShapeAnchorName.init(rawValue:)).map { t($0.labelKey) }
                         ?? t("anchor_auto"))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

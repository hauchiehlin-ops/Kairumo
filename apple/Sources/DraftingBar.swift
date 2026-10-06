import SwiftUI

/// 圖學的浮動工具列：製圖筆組、圖層（顯示／鎖定／目標）、吸附與角度鎖定、改圖層。
///
/// 浮在畫布上方，只在選了「圖學」工具時出現。所有狀態在 `DraftingState`，
/// 這裡只是畫面；畫布那邊（`CanvasRepresentable.applyProInk`）讀同一份狀態落筆。
struct DraftingBar: View {
    var onOpenSolidStudio: () -> Void = {}
    var onOpenToolbox: () -> Void = {}
    @ObservedObject var state = DraftingState.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showTips = false

    /// 手機寬度預設收合；使用者按過收合／展開之後就以他的選擇為準。
    private var compact: Bool { state.compactChoice ?? (sizeClass == .compact || typeSize.isAccessibilitySize) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if compact {
                compactRow
            } else {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 8) {
                        penRow
                        Divider()
                        layerRow
                        Divider()
                        optionRow
                    }
                    barButtons
                }
            }
        }
        .padding(10)
        .overlay(alignment: .bottom) { toolHint }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .frame(maxWidth: 560)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("draft.bar")
        // 第一次使用自動跳出，按「知道了」之後不再自動出現；之後由 ? 叫回。
        .onAppear { if !state.tipsSeen { showTips = true } }
        .alert(localizationManager.localized("draft_tip_title"), isPresented: $showTips) {
            Button(localizationManager.localized("draft_tip_dismiss")) { state.tipsSeen = true }
        } message: {
            Text(tipsMessage)
        }
    }

    /// 圖學工具在等什麼（浮在製圖列下緣，不撐開列的高度）。
    @ViewBuilder private var toolHint: some View {
        if let hint = state.toolHint, state.tool != .none {
            Text(hint)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.accentColor, in: Capsule())
                .foregroundColor(.white)
                .offset(y: 30)
                .accessibilityIdentifier("draft.tool.hint")
                .allowsHitTesting(false)
        }
    }

    // MARK: 精簡列與提示

    /// 收合時只剩：目前的筆、目前的目標圖層、說明、展開。
    private var compactRow: some View {
        let pen = state.activePen
        let layer = state.layers.first { $0.id == state.activeLayerId }
        return HStack(spacing: 10) {
            DraftLinePreview(pen: pen, selected: true).frame(width: 54, height: 14)
            Text(localizationManager.localized(pen.nameKey))
                .font(.caption.weight(.semibold)).lineLimit(1)
            if let layer {
                HStack(spacing: 4) {
                    Circle().fill(state.layerColor(layer.id)).frame(width: 10, height: 10)
                    Text(localizationManager.localized(layer.nameKey)).font(.caption).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            barButtons
        }
        .accessibilityElement(children: .contain)
    }

    /// 說明＋收合／展開。
    private var barButtons: some View {
        HStack(spacing: 2) {
            Button { showTips.toggle() } label: {
                Image(systemName: "questionmark.circle").font(.body).frame(width: 32, height: 32)
            }
            .accessibilityLabel(localizationManager.localized("draft_help"))
            .accessibilityIdentifier("draft.help")
            Button { state.compactChoice = !compact } label: {
                Image(systemName: compact ? "chevron.down.circle" : "chevron.up.circle")
                    .font(.body).frame(width: 32, height: 32)
            }
            .accessibilityLabel(localizationManager.localized(compact ? "draft_bar_expand" : "draft_bar_collapse"))
            .accessibilityIdentifier("draft.collapse")
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
    }

    /// 四則提示的內文。
    private var tipsMessage: String {
        (1...4).map { "\($0). " + localizationManager.localized("draft_tip_\($0)") }.joined(separator: "\n\n")
    }

    // MARK: 製圖筆

    private var penRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(state.pens, id: \.id) { pen in
                    let selected = pen.id == state.activePenId
                    Button {
                        state.activePenId = pen.id
                        // 換筆就回到「跟著筆走」的圖層，不然上一支筆的圖層設定會莫名其妙留著。
                        state.layerOverride = nil
                    } label: {
                        VStack(spacing: 3) {
                            DraftLinePreview(pen: pen, selected: selected)
                                .frame(width: 54, height: 14)
                            Text(localizationManager.localized(pen.nameKey))
                                .font(.caption2.weight(selected ? .semibold : .regular))
                                .foregroundColor(selected ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(selected ? Color.accentColor.opacity(0.16) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("draft.pen.\(pen.id)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: 圖層

    private var layerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(state.layers.reversed(), id: \.id) { layer in layerChip(layer) }
            }
        }
    }

    private func layerChip(_ layer: FfiDraftLayer) -> some View {
        let nb = state.notebookId
        let hidden = state.isHidden(layer: layer.id, notebookId: nb)
        let locked = state.isLocked(layer: layer.id, notebookId: nb)
        let target = state.activeLayerId == layer.id
        return HStack(spacing: 6) {
            // 點色塊＋名字：把這一層設成畫圖的目標。
            Button {
                state.layerOverride = state.layerOverride == layer.id ? nil : layer.id
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(state.layerColor(layer.id)).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.primary.opacity(0.35), lineWidth: 1))
                        .overlay(Circle().stroke(Color.primary.opacity(target ? 0.9 : 0), lineWidth: 2).padding(-3))
                    Text(localizationManager.localized(layer.nameKey))
                        .font(.caption.weight(target ? .semibold : .regular))
                        .foregroundColor(hidden ? .secondary : .primary)
                        .strikethrough(hidden)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("draft_draw_on_layer"))
            .accessibilityIdentifier("draft.layer.\(layer.id).target")
            .accessibilityAddTraits(target ? .isSelected : [])

            Button { state.setHidden(!hidden, layer: layer.id) } label: {
                Image(systemName: hidden ? "eye.slash" : "eye").font(.footnote)
                    .foregroundColor(hidden ? .secondary : .accentColor)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(localizationManager.localized(hidden ? "draft_show_layer" : "draft_hide_layer")) \(localizationManager.localized(layer.nameKey))")
            .accessibilityIdentifier("draft.layer.\(layer.id).visible")

            Button { state.setLocked(!locked, layer: layer.id) } label: {
                Image(systemName: locked ? "lock.fill" : "lock.open").font(.footnote)
                    .foregroundColor(locked ? .orange : .secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(localizationManager.localized(locked ? "draft_unlock_layer" : "draft_lock_layer")) \(localizationManager.localized(layer.nameKey))")
            .accessibilityIdentifier("draft.layer.\(layer.id).lock")
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(target ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 9))
    }

    // MARK: 吸附、角度、改圖層

    private var optionRow: some View {
        WrapLayout(spacing: 10, lineSpacing: 6) {
            Group {
                Toggle(isOn: $state.snapEnabled) {
                    Label(localizationManager.localized("draft_snap"), systemImage: "scope")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .accessibilityIdentifier("draft.snap")

                Menu {
                    ForEach(DraftingState.angleChoices, id: \.self) { deg in
                        Button {
                            state.angleStep = deg
                        } label: {
                            if state.angleStep == deg { Label(angleTitle(deg), systemImage: "checkmark") } else { Text(angleTitle(deg)) }
                        }
                    }
                } label: {
                    Label("\(localizationManager.localized("draft_angle_lock")) \(angleTitle(state.angleStep))",
                          systemImage: "angle")
                        .font(.caption)
                }
                .accessibilityIdentifier("draft.angle")

                Toggle(isOn: $state.reassignMode) {
                    Label(localizationManager.localized("draft_reassign"), systemImage: "square.3.layers.3d.down.right")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .accessibilityIdentifier("draft.reassign")

                // 步驟編號：開著時點頁面就放一個 ①②③…（中層，跟輔助線一起隱藏）。
                Toggle(isOn: $state.markerMode) {
                    Label("\(localizationManager.localized("draft_step_marker")) \(state.stepNumber)",
                          systemImage: "number.circle")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .accessibilityIdentifier("draft.marker")
                if state.markerMode {
                    Button { state.stepNumber = max(1, state.stepNumber - 1) } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel(localizationManager.localized("draft_step_prev"))
                        .accessibilityIdentifier("draft.marker.minus")
                    Button { state.stepNumber = min(99, state.stepNumber + 1) } label: { Image(systemName: "plus.circle") }
                        .accessibilityLabel(localizationManager.localized("draft_step_next"))
                        .accessibilityIdentifier("draft.marker.plus")
                    Button(localizationManager.localized("draft_step_reset")) { state.stepNumber = 1 }
                        .font(.caption)
                        .accessibilityIdentifier("draft.marker.reset")
                }

                // 圖學工具：尺寸標註、符號、圖框（見 DraftingTools.swift）。
                Button(action: onOpenToolbox) {
                    Label(localizationManager.localized("draft_tools"), systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("draft.tools")
                if state.tool != .none {
                    // 目前的工具：點一下結束；下面一行寫它在等什麼。
                    Button {
                        state.tool = .none
                        DraftToolController.shared.reset(layer: nil)
                    } label: {
                        Label(localizationManager.localized(state.tool.nameKey), systemImage: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(localizationManager.localized("draft_tool_close"))
                    .accessibilityIdentifier("draft.tool.close")
                }

                // 立體輔助：草圖拉伸、三視圖、等角圖、剖面。
                Button(action: onOpenSolidStudio) {
                    Label(localizationManager.localized("solid_studio"), systemImage: "cube.transparent")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("draft.solidStudio")
            }
        }
    }

    private func angleTitle(_ deg: Int) -> String {
        deg == 0 ? localizationManager.localized("draft_angle_free") : "\(deg)°"
    }
}

/// 製圖筆的線樣：依核心的線型圖樣畫出實線／隱藏線／中心線／假想線，粗細也照筆組。
struct DraftLinePreview: View {
    let pen: FfiDraftPen
    let selected: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 2, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - 2, y: size.height / 2))
            let pattern = draftLinePattern(lineType: pen.lineType).map { CGFloat($0) * 0.9 }
            var color = DraftingState.rgba(fromHex: pen.colorHex)
            // 深色模式：近黑的線（頂／底層）在深色底上看不見，提亮。
            if scheme == .dark, 0.299 * Double(color[0]) + 0.587 * Double(color[1]) + 0.114 * Double(color[2]) < 90 {
                color = [255 - color[0], 255 - color[1], 255 - color[2], color[3]]
            }
            ctx.stroke(
                path,
                with: .color(Color(red: Double(color[0]) / 255, green: Double(color[1]) / 255, blue: Double(color[2]) / 255)),
                style: StrokeStyle(lineWidth: CGFloat(pen.width) * 1.3, lineCap: .butt, dash: pattern))
        }
    }
}

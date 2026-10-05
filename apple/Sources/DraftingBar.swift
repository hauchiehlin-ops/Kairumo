import SwiftUI

/// 圖學的浮動工具列：製圖筆組、圖層（顯示／鎖定／目標）、吸附與角度鎖定、改圖層。
///
/// 浮在畫布上方，只在選了「圖學」工具時出現。所有狀態在 `DraftingState`，
/// 這裡只是畫面；畫布那邊（`CanvasRepresentable.applyProInk`）讀同一份狀態落筆。
struct DraftingBar: View {
    var onOpenSolidStudio: () -> Void = {}
    @ObservedObject var state = DraftingState.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            penRow
            Divider()
            layerRow
            Divider()
            optionRow
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .frame(maxWidth: 560)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("draft.bar")
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
                                .font(.system(size: 10, weight: selected ? .semibold : .regular))
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
                        .overlay(Circle().stroke(Color.primary.opacity(target ? 0.9 : 0), lineWidth: 2).padding(-3))
                    Text(localizationManager.localized(layer.nameKey))
                        .font(.system(size: 12, weight: target ? .semibold : .regular))
                        .foregroundColor(hidden ? .secondary : .primary)
                        .strikethrough(hidden)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("draft_draw_on_layer"))
            .accessibilityIdentifier("draft.layer.\(layer.id).target")
            .accessibilityAddTraits(target ? .isSelected : [])

            Button { state.setHidden(!hidden, layer: layer.id) } label: {
                Image(systemName: hidden ? "eye.slash" : "eye").font(.system(size: 13))
                    .foregroundColor(hidden ? .secondary : .accentColor)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized(hidden ? "draft_show_layer" : "draft_hide_layer"))
            .accessibilityIdentifier("draft.layer.\(layer.id).visible")

            Button { state.setLocked(!locked, layer: layer.id) } label: {
                Image(systemName: locked ? "lock.fill" : "lock.open").font(.system(size: 13))
                    .foregroundColor(locked ? .orange : .secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized(locked ? "draft_unlock_layer" : "draft_lock_layer"))
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
                        .font(.system(size: 12))
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
                        .font(.system(size: 12))
                }
                .accessibilityIdentifier("draft.angle")

                Toggle(isOn: $state.reassignMode) {
                    Label(localizationManager.localized("draft_reassign"), systemImage: "square.3.layers.3d.down.right")
                        .font(.system(size: 12))
                }
                .toggleStyle(.button)
                .accessibilityIdentifier("draft.reassign")

                // 步驟編號：開著時點頁面就放一個 ①②③…（中層，跟輔助線一起隱藏）。
                Toggle(isOn: $state.markerMode) {
                    Label("\(localizationManager.localized("draft_step_marker")) \(state.stepNumber)",
                          systemImage: "number.circle")
                        .font(.system(size: 12))
                }
                .toggleStyle(.button)
                .accessibilityIdentifier("draft.marker")
                if state.markerMode {
                    Button { state.stepNumber = max(1, state.stepNumber - 1) } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel(localizationManager.localized("draft_step_next"))
                        .accessibilityIdentifier("draft.marker.minus")
                    Button { state.stepNumber = min(99, state.stepNumber + 1) } label: { Image(systemName: "plus.circle") }
                        .accessibilityIdentifier("draft.marker.plus")
                    Button(localizationManager.localized("draft_step_reset")) { state.stepNumber = 1 }
                        .font(.system(size: 12))
                        .accessibilityIdentifier("draft.marker.reset")
                }

                // 立體輔助：草圖拉伸、三視圖、等角圖、剖面。
                Button(action: onOpenSolidStudio) {
                    Label(localizationManager.localized("solid_studio"), systemImage: "cube.transparent")
                        .font(.system(size: 12))
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

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 2, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - 2, y: size.height / 2))
            let pattern = draftLinePattern(lineType: pen.lineType).map { CGFloat($0) * 0.9 }
            let color = DraftingState.rgba(fromHex: pen.colorHex)
            ctx.stroke(
                path,
                with: .color(Color(red: Double(color[0]) / 255, green: Double(color[1]) / 255, blue: Double(color[2]) / 255)),
                style: StrokeStyle(lineWidth: CGFloat(pen.width) * 1.3, lineCap: .butt, dash: pattern))
        }
    }
}

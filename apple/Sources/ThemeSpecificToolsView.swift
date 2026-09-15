//
//  ThemeSpecificToolsView.swift
//  Kairumo
//
//  三大主題專屬加速輔助工具面板（美學視覺、工程製程、數位體驗）
//  包含：
//  1. 美學視覺：Pantone/Morandi 色票卡生成器、黃金螺旋構圖 HUD
//  2. 工程製程：工程尺寸引線、公差標註、材料規格清單卡 (SUS304 / AL6061)
//  3. 數位體驗：UI Wireframe 常用元件、手勢箭頭流程跳轉
//

import SwiftUI

public enum ActiveThemeTab: String, CaseIterable, Identifiable {
    case aesthetic = "aesthetic"
    case engineering = "engineering"
    case digital = "digital"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .aesthetic: return "paintpalette.fill"
        case .engineering: return "ruler.fill"
        case .digital: return "macwindow"
        }
    }

    public var localizationKey: String {
        switch self {
        case .aesthetic: return "theme_aesthetic"
        case .engineering: return "theme_engineering"
        case .digital: return "theme_digital"
        }
    }
}

public struct ThemeSpecificToolsView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @Binding var currentBrushColor: Color
    @Binding var isGoldenSpiralActive: Bool
    @Binding var isRuleOfThirdsActive: Bool

    var onInsertCardImage: (UIImage) -> Void
    var onInsertTextCard: (String) -> Void

    @State private var activeTab: ActiveThemeTab = .aesthetic

    public init(
        currentBrushColor: Binding<Color>,
        isGoldenSpiralActive: Binding<Bool>,
        isRuleOfThirdsActive: Binding<Bool>,
        onInsertCardImage: @escaping (UIImage) -> Void,
        onInsertTextCard: @escaping (String) -> Void
    ) {
        self._currentBrushColor = currentBrushColor
        self._isGoldenSpiralActive = isGoldenSpiralActive
        self._isRuleOfThirdsActive = isRuleOfThirdsActive
        self.onInsertCardImage = onInsertCardImage
        self.onInsertTextCard = onInsertTextCard
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 主題分類分段切換
                Picker("", selection: $activeTab) {
                    ForEach(ActiveThemeTab.allCases) { tab in
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                            Text(localizationManager.localized(tab.localizationKey))
                        }
                        .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                ScrollView {
                    VStack(spacing: 18) {
                        switch activeTab {
                        case .aesthetic:
                            aestheticSuiteView
                        case .engineering:
                            engineeringSuiteView
                        case .digital:
                            digitalExperienceSuiteView
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localizationManager.localized("theme_tools"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 1. 美學視覺輔助工具 (Aesthetic Suite)
    private var aestheticSuiteView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 構圖輔助線切換開關
            VStack(alignment: .leading, spacing: 10) {
                Text(localizationManager.localized("composition_overlay"))
                    .font(.headline)

                Toggle(isOn: $isGoldenSpiralActive) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.metering.center.weighted")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizationManager.localized("golden_spiral_ref"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(localizationManager.localized("golden_spiral_desc"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                Toggle(isOn: $isRuleOfThirdsActive) {
                    HStack(spacing: 8) {
                        Image(systemName: "grid")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizationManager.localized("rule_of_thirds_ref"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(localizationManager.localized("rule_of_thirds_desc"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            // 經典專業色卡庫
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localizationManager.localized("palette_swatches"))
                        .font(.headline)
                    Spacer()
                    Text(localizationManager.localized("palette_tip"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                ForEach(colorPalettes, id: \.name) { pal in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(pal.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Spacer()
                            Button {
                                let img = renderPaletteCard(name: pal.name, colors: pal.colors, hexes: pal.hexes)
                                onInsertCardImage(img)
                                dismiss()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus.rectangle.fill")
                                    Text(localizationManager.localized("insert_swatch"))
                                }
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        // 色塊橫排
                        HStack(spacing: 6) {
                            ForEach(0..<pal.colors.count, id: \.self) { idx in
                                Button {
                                    // 點選該色票即吸取該顏色至目前工具筆刷
                                    currentBrushColor = pal.colors[idx]
                                } label: {
                                    VStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(pal.colors[idx])
                                            .frame(height: 36)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                            )
                                        Text(pal.hexes[idx])
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(localizationManager.localized("palette_tip"))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - 2. 工程製程輔助工具 (Engineering Suite)
    private var engineeringSuiteView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 工程尺寸引線快速插入
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localizationManager.localized("dimension_callout"))
                        .font(.headline)
                    Spacer()
                    Text(localizationManager.localized("engineering_dim_tip"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 標註清單來自核心 `themeDimensionCallouts()`，Android 讀的是同一份。
                // 標題走字串表 —— 原本寫死繁體中文，日文或英文使用者
                // 在一個已經翻成六國語系的面板裡看到一格中文。
                let callouts = themeDimensionCallouts()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(callouts, id: \.titleKey) { item in
                        Button {
                            // 插入成**文字方塊**，不是算繪好的圖片。
                            //
                            // 原本走「算繪成徽章圖片」那條路，得到的是一張點陣圖：
                            // 120.0 改不了、公差改不了、
                            // 字級顏色改不了 —— 一張標註不能改數字，等於沒有用。
                            // 文字方塊本來就能就地編輯、換字級、縮放、旋轉。
                            onInsertTextCard(item.symbol)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizationManager.localized(item.titleKey))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(item.symbol)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.accentColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            // 材料與工藝清單卡 (Material Specs Sheet)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localizationManager.localized("material_specs_card"))
                        .font(.headline)
                    Spacer()
                    Text(localizationManager.localized("material_specs_tip"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 材料清單來自核心 `themeMaterials()`。牌號（SUS304…）不翻譯 ——
                // 那是國際通用代號，翻了工程師反而認不出來；特性與工藝指標走語系鍵。
                let materials = themeMaterials().map { m in
                    (
                        name: m.designation,
                        tag: localizationManager.localized(m.traitKey),
                        specs: localizationManager.localized(m.specKey)
                    )
                }

                ForEach(materials, id: \.name) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(m.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(m.tag)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(4)
                            }
                            Text(m.specs)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            // 卡片上的標籤也要在地化：原本是寫死的「【材料規格】特性 工藝指標」。
                            let textContent = """
                            【\(localizationManager.localized("material_card_title"))】\(m.name)
                            \(localizationManager.localized("material_card_trait"))：\(m.tag)
                            \(localizationManager.localized("material_card_process"))：\(m.specs)
                            """
                            onInsertTextCard(textContent)
                            dismiss()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.badge.plus")
                                Text(localizationManager.localized("insert"))
                            }
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.accentColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - 3. 數位體驗輔助工具 (Digital UX Suite)
    private var digitalExperienceSuiteView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // UI Wireframe 元件快速插入
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localizationManager.localized("wireframe_kit"))
                        .font(.headline)
                    Spacer()
                    Text(localizationManager.localized("ui_wireframe_tip"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 元件清單來自核心 `themeWireframes()`；名稱走語系鍵。
                // 圖示是 SF Symbol，那是 Apple 專屬的，留在平台層。
                let icons = [
                    "navbar": "menubar.rectangle", "tabbar": "dock.rectangle",
                    "button": "button.programmable", "input": "character.textbox",
                    "card": "rectangle.portrait", "modal": "bubble.left.and.bubble.right"
                ]
                let wireframes = themeWireframes().map { w in
                    (
                        title: localizationManager.localized(w.titleKey),
                        icon: icons[w.symbol] ?? "square.dashed",
                        code: w.symbol
                    )
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(wireframes, id: \.title) { w in
                        Button {
                            let img = renderWireframeComponent(code: w.code, title: w.title)
                            onInsertCardImage(img)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: w.icon)
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                    .frame(width: 28)
                                Text(w.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            // UX 手勢跳轉與流程標籤
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localizationManager.localized("interaction_arrow"))
                        .font(.headline)
                    Spacer()
                    Text(localizationManager.localized("interaction_flow_tip"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 流程標籤來自核心 `themeGestures()`：emoji 與語言無關，
                // 文字查表 —— 原本整串是寫死的中英夾雜字面值。
                let gestures = themeGestures().map { g in
                    "\(g.symbol) \(localizationManager.localized(g.titleKey))"
                }

                ForEach(gestures, id: \.self) { g in
                    Button {
                        onInsertTextCard(g)
                        dismiss()
                    } label: {
                        HStack {
                            Text(g)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - 輔助繪圖與卡片渲染函式
    private func renderPaletteCard(name: String, colors: [Color], hexes: [String]) -> UIImage {
        let size = CGSize(width: 320, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            let cardRect = CGRect(origin: .zero, size: size)
            cg.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 10).cgPath)
            cg.fillPath()

            // 標題
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            (name as NSString).draw(at: CGPoint(x: 14, y: 12), withAttributes: titleAttrs)

            // 五色方塊
            let boxWidth: CGFloat = 52
            let boxHeight: CGFloat = 46
            var x: CGFloat = 14
            for i in 0..<colors.count {
                cg.setFillColor(UIColor(colors[i]).cgColor)
                let r = CGRect(x: x, y: 38, width: boxWidth, height: boxHeight)
                cg.addPath(UIBezierPath(roundedRect: r, cornerRadius: 4).cgPath)
                cg.fillPath()

                let hexAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 8, weight: .semibold),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                (hexes[i] as NSString).draw(at: CGPoint(x: x + 4, y: 90), withAttributes: hexAttrs)
                x += boxWidth + 8
            }
        }
    }

    private func renderWireframeComponent(code: String, title: String) -> UIImage {
        let size = CGSize(width: 320, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
            let rect = CGRect(origin: .zero, size: size)
            cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 10).cgPath)
            cg.fillPath()

            cg.setStrokeColor(UIColor.systemGray4.cgColor)
            cg.setLineWidth(1.5)
            cg.addPath(UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 9).cgPath)
            cg.strokePath()

            // 元件示意
            cg.setStrokeColor(UIColor.systemPurple.cgColor)
            cg.setLineWidth(2.0)
            if code == "navbar" {
                cg.stroke(CGRect(x: 15, y: 20, width: 290, height: 44))
                cg.strokeEllipse(in: CGRect(x: 25, y: 32, width: 20, height: 20))
                cg.stroke(CGRect(x: 265, y: 32, width: 20, height: 20))
            } else if code == "button" {
                let btnRect = CGRect(x: 30, y: 50, width: 260, height: 48)
                cg.addPath(UIBezierPath(roundedRect: btnRect, cornerRadius: 8).cgPath)
                cg.strokePath()
            } else {
                let cardR = CGRect(x: 20, y: 20, width: 280, height: 110)
                cg.addPath(UIBezierPath(roundedRect: cardR, cornerRadius: 8).cgPath)
                cg.strokePath()
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.systemPurple
            ]
            ("[Wireframe] \(title)" as NSString).draw(at: CGPoint(x: 16, y: 135), withAttributes: attrs)
        }
    }

    // 經典調色盤資料 —— **來自核心** `themePalettes()`。
    //
    // 原本這裡是一份寫死的陣列，名稱還是繁體中文字面值；Android 沒有對應品。
    // 下沉之後兩個平台的配色與順序必然一致，名稱也走語系鍵。
    private var colorPalettes: [(name: String, colors: [Color], hexes: [String])] {
        themePalettes().map { pal in
            (
                name: localizationManager.localized(pal.nameKey),
                colors: pal.hexes.map { Color(hex: $0) ?? .gray },
                hexes: pal.hexes
            )
        }
    }
}

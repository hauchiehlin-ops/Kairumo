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

                let callouts: [(title: String, symbol: String, desc: String)] = [
                    ("線性長度標註", "↔ 120.0 ±0.05 mm", "雙向精密尺寸箭頭"),
                    ("外徑圓標註", "Ø 48.0 H7 mm", "基準直徑與配合公差"),
                    ("圓弧半徑標註", "R 12.5 mm", "倒圓角半徑引線"),
                    ("平面度公差", "⏥ 0.02 A", "形位幾何公差基準"),
                    ("零件球標 ①", "① 軸承套筒", "裝配圖零件序號引線"),
                    ("零件球標 ②", "② 傳動正齒輪", "裝配圖零件序號引線")
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(callouts, id: \.title) { item in
                        Button {
                            let img = renderDimensionBadge(text: item.symbol, desc: item.desc)
                            onInsertCardImage(img)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
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

                let materials: [(name: String, tag: String, specs: String)] = [
                    ("SUS304 不鏽鋼", "奧氏體防蝕", "抗拉強度 ≥520 MPa / 表面拉絲鈍化處理"),
                    ("AL6061-T6 鋁合金", "航空高剛性", "抗拉強度 ≥290 MPa / 12μm 硬質陽極氧化"),
                    ("PC+ABS 工程合金", "阻燃抗衝擊", "UL94 V0 耐燃 / 模具咬花皮紋表面"),
                    ("POM 聚甲醛賽鋼", "耐磨自潤滑", "摩擦係數 0.25 / 齒輪與軸承滑塊專用"),
                    ("SKD11 模具工具鋼", "極高耐磨性", "淬火回火硬度 HRC 58-62 / 精密沖壓沖頭")
                ]

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
                            let textContent = "【材料規格】\(m.name)\n特性：\(m.tag)\n工藝指標：\(m.specs)"
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

                let wireframes: [(title: String, icon: String, code: String)] = [
                    ("行動端頂部導航列", "menubar.rectangle", "navbar"),
                    ("底部五分頁 TabBar", "dock.rectangle", "tabbar"),
                    ("主要行動按鈕 (CTA)", "button.programmable", "button"),
                    ("搜尋輸入文字框", "character.textbox", "input"),
                    ("內容資訊卡片", "rectangle.portrait", "card"),
                    ("對話框彈窗 (Modal)", "bubble.left.and.bubble.right", "modal")
                ]

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

                let gestures = [
                    "👉 點擊跳轉 (Tap → Next)",
                    "👈 左右滑動切換 (Swipe)",
                    "⏱️ 長按觸發選單 (Long Press)",
                    "◇ 條件判斷分支 (Decision If/Else)",
                    "↻ 載入更新狀態 (Loading/Refresh)",
                    "✅ 成功驗證回饋 (Success Banner)"
                ]

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

    private func renderDimensionBadge(text: String, desc: String) -> UIImage {
        let size = CGSize(width: 260, height: 75)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 0.95).cgColor)
            let box = CGRect(origin: .zero, size: size)
            cg.addPath(UIBezierPath(roundedRect: box, cornerRadius: 8).cgPath)
            cg.fillPath()

            cg.setStrokeColor(UIColor.systemBlue.cgColor)
            cg.setLineWidth(1.5)
            cg.addPath(UIBezierPath(roundedRect: box.insetBy(dx: 1, dy: 1), cornerRadius: 7).cgPath)
            cg.strokePath()

            let symbolAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold),
                .foregroundColor: UIColor.systemBlue
            ]
            (text as NSString).draw(at: CGPoint(x: 14, y: 16), withAttributes: symbolAttrs)

            let descAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            (desc as NSString).draw(at: CGPoint(x: 14, y: 44), withAttributes: descAttrs)
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

    // 經典調色盤資料
    private var colorPalettes: [(name: String, colors: [Color], hexes: [String])] = [
        (
            name: "Pantone 季節潮流色 (Trend Palette)",
            colors: [
                Color(red: 0.97, green: 0.58, blue: 0.47),
                Color(red: 0.43, green: 0.65, blue: 0.82),
                Color(red: 0.95, green: 0.77, blue: 0.45),
                Color(red: 0.38, green: 0.62, blue: 0.54),
                Color(red: 0.32, green: 0.33, blue: 0.45)
            ],
            hexes: ["#F79477", "#6EA6D1", "#F2C473", "#619E8A", "#525473"]
        ),
        (
            name: "莫蘭迪高級灰 (Morandi Serene)",
            colors: [
                Color(red: 0.78, green: 0.76, blue: 0.74),
                Color(red: 0.68, green: 0.67, blue: 0.62),
                Color(red: 0.58, green: 0.63, blue: 0.62),
                Color(red: 0.72, green: 0.66, blue: 0.65),
                Color(red: 0.49, green: 0.48, blue: 0.46)
            ],
            hexes: ["#C7C2BD", "#AEAB9E", "#94A19E", "#B8A8A6", "#7D7B75"]
        ),
        (
            name: "包浩斯復古工業 (Bauhaus Industrial)",
            colors: [
                Color(red: 0.85, green: 0.20, blue: 0.18),
                Color(red: 0.12, green: 0.35, blue: 0.68),
                Color(red: 0.96, green: 0.76, blue: 0.15),
                Color(red: 0.18, green: 0.18, blue: 0.18),
                Color(red: 0.92, green: 0.90, blue: 0.85)
            ],
            hexes: ["#D9332E", "#1F59AD", "#F5C226", "#2E2E2E", "#EBE6D9"]
        ),
        (
            name: "Cyberpunk 賽博霓虹 (Cyberpunk Neon)",
            colors: [
                Color(red: 1.00, green: 0.00, blue: 0.48),
                Color(red: 0.00, green: 0.96, blue: 1.00),
                Color(red: 0.55, green: 0.12, blue: 0.95),
                Color(red: 0.99, green: 0.91, blue: 0.00),
                Color(red: 0.07, green: 0.05, blue: 0.15)
            ],
            hexes: ["#FF007A", "#00F5FF", "#8C1FF2", "#FCE800", "#120D26"]
        )
    ]
}

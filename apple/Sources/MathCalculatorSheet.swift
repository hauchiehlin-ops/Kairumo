//
//  MathCalculatorSheet.swift
//  Kairumo
//
//  算式計算與結果生成面板
//  支援實時求值、工程科學計算機、微積分與工數快捷範本、數學特殊符號庫、
//  常用常數，以及可編輯文字方塊與卡片插入雙模式。
//

import SwiftUI

public struct MathCalculatorSheet: View {
    var onInsertFormula: (String, UIImage) -> Void
    var onInsertEditableText: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    @State private var formulaInput: String = "125 * 8 + 45"
    @State private var currentResult: MathResult? = nil
    @State private var errorMessage: String? = nil
    @State private var keepCardBorder: Bool = true
    @State private var selectedTab: PanelTab = .calculator

    // 分頁標籤索引
    private enum PanelTab: Int, CaseIterable {
        case calculator = 0
        case calculus = 1
        case symbols = 2
        case units = 3
    }

    // 科學計算機按鍵佈局
    private let calcKeyRows: [[String]] = [
        ["sin(", "cos(", "tan(", "ln(", "log("],
        ["asin(", "acos(", "atan(", "exp(", "sqrt("],
        ["sinh(", "cosh(", "tanh(", "pow(", "cbrt("],
        ["deg(", "rad(", "fact(", "ncr(", "npr("],
        ["(", ")", "^", "!", "%"],
        ["7", "8", "9", "÷", "gcd("],
        ["4", "5", "6", "×", "lcm("],
        ["1", "2", "3", "-", "abs("],
        ["0", ".", "=", "+", "π"]
    ]

    // 微積分與工程數學常見算式模板
    private let calculusTemplates: [(name: String, expr: String)] = [
        ("微積分 - 多項式導數表列", "d/dx(3x^2 + 5x - 4) = 6x + 5"),
        ("微積分 - 定積分求值", "∫(0 to 2) (3x^2) dx = 8"),
        ("微積分 - 瑕積分", "∫(0 to ∞) e^(-x) dx = 1"),
        ("工數 - 傅立葉級數表列", "f(x) = a0/2 + ∑(an cos(nx) + bn sin(nx))"),
        ("工數 - 拉普拉斯轉換", "L{e^(at)} = 1 / (s - a)"),
        ("工數 - 二階常微分ODE", "y'' + 4y' + 13y = 0"),
        ("向量分析 - 梯度運算", "∇f = ∂f/∂x i + ∂f/∂y j + ∂f/∂z k"),
        ("向量分析 - 散度運算", "∇·F = ∂P/∂x + ∂Q/∂y + ∂R/∂z"),
        ("向量分析 - 旋度運算", "∇×F = det |i j k; ∂x ∂y ∂z; P Q R|"),
        ("線性代數 - 特徵方程式", "det(A - λI) = 0"),
        ("複變數 - 歐拉公式", "e^(iθ) = cos(θ) + i sin(θ)"),
        ("高斯積分", "∫(-∞ to ∞) e^(-x^2) dx = √π"),
        ("泰勒展開式", "f(x) = ∑ (f^(n)(a)/n!) (x - a)^n"),
        ("工數 - 熱傳導方程式", "∂u/∂t = α ∇²u"),
        ("工數 - 波動方程式", "∂²u/∂t² = c² ∇²u")
    ]

    // 常用科學常數
    private let scientificConstants: [(name: String, symbol: String, valueDesc: String)] = [
        ("圓周率 π", "pi", "3.14159265..."),
        ("自然常數 e", "e", "2.71828182..."),
        ("黃金比例 φ", "phi", "1.61803398..."),
        ("光速 c", "c", "299,792,458 m/s"),
        ("重力加速度 g", "g", "9.80665 m/s²"),
        ("普朗克常數 h", "h", "6.62607e-34 J·s"),
        ("波茲曼常數 k", "k", "1.38065e-23 J/K"),
        ("亞佛加厥常數 Na", "na", "6.02214e23 mol⁻¹")
    ]

    // 完整的數學特殊符號分類清單（涵蓋微積分、工數、幾何、集合、希臘字母）
    private let mathSymbolSections: [(title: String, symbols: [String])] = [
        ("微積分與微分方程", [
            "∫", "∬", "∭", "∮", "∯", "∰", "∂", "∇", "∆", "d", "dx", "dy", "dz", "dt", "′", "″"
        ]),
        ("工數、向量與場論", [
            "×", "·", "⊗", "⊕", "⊙", "⊥", "∥", "∠", "∢", "°", "∇·", "∇×", "∇²", "‖", "⟨", "⟩"
        ]),
        ("運算子與關係", [
            "±", "∓", "≠", "≈", "≡", "≤", "≥", "≪", "≫", "∝", "∞", "√", "∛", "∜", "∑", "∏"
        ]),
        ("集合與邏輯", [
            "∈", "∉", "⊂", "⊃", "⊆", "⊇", "∪", "∩", "∅", "∀", "∃", "∄", "∴", "∵", "⇒", "⇔"
        ]),
        ("希臘字母 (小寫)", [
            "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ", "ν", "ξ", "π", "ρ", "σ", "τ", "υ", "φ", "χ", "ψ", "ω"
        ]),
        ("希臘字母 (大寫)", [
            "Α", "Β", "Γ", "Δ", "Ε", "Ζ", "Η", "Θ", "Ι", "Κ", "Λ", "Μ", "Ν", "Ξ", "Π", "Ρ", "Σ", "Τ", "Υ", "Φ", "Χ", "Ψ", "Ω"
        ]),
        ("括號與矩陣符號", [
            "(", ")", "[", "]", "{", "}", "⌈", "⌉", "⌊", "⌋", "|", "‖"
        ])
    ]

    public init(
        onInsertFormula: @escaping (String, UIImage) -> Void,
        onInsertEditableText: ((String) -> Void)? = nil
    ) {
        self.onInsertFormula = onInsertFormula
        self.onInsertEditableText = onInsertEditableText
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 算式輸入與求值狀態區
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(localizationManager.localized("math_expression"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { formulaInput = "" }) {
                            Text(localizationManager.localized("math_clear"))
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }

                    HStack(spacing: 8) {
                        TextField(localizationManager.localized("math_placeholder"), text: $formulaInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit {
                                evaluateFormula()
                            }

                        Button(action: {
                            if !formulaInput.isEmpty {
                                formulaInput.removeLast()
                                evaluateFormula()
                            }
                        }) {
                            Image(systemName: "delete.left")
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(localizationManager.localized("math_backspace"))
                        .help(localizationManager.localized("math_backspace"))

                        Button(localizationManager.localized("math_calculate")) {
                            evaluateFormula()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    // 求值結果即時顯示卡片
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

                        if let res = currentResult {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(res.displayText)
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)

                                    Text("\(localizationManager.localized("math_value_prefix")): \(res.formattedResult)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        } else if let err = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        } else {
                            Text(localizationManager.localized("math_input_hint"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(12)
                        }
                    }
                    .frame(minHeight: 54)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                // 2. 分頁選單列
                Picker("", selection: $selectedTab) {
                    Text(localizationManager.localized("math_tab_calc")).tag(PanelTab.calculator)
                    Text(localizationManager.localized("math_tab_calculus")).tag(PanelTab.calculus)
                    Text(localizationManager.localized("math_tab_symbols")).tag(PanelTab.symbols)
                    Text(localizationManager.localized("math_tab_units")).tag(PanelTab.units)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // 3. 分頁主要工具面盤
                TabView(selection: $selectedTab) {
                    // 分頁 1: 科學工程計算機按鍵盤
                    calculatorKeypadView
                        .tag(PanelTab.calculator)

                    // 分頁 2: 微積分與工程數學快捷範本
                    calculusTemplatesView
                        .tag(PanelTab.calculus)

                    // 分頁 3: 數學與特殊符號點選庫
                    symbolsPaletteView
                        .tag(PanelTab.symbols)

                    // 分頁 4: 常用常數與單位
                    constantsView
                        .tag(PanelTab.units)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Divider()

                // 4. 插入選項與動作底欄
                VStack(spacing: 8) {
                    Toggle(isOn: $keepCardBorder) {
                        HStack(spacing: 6) {
                            Image(systemName: keepCardBorder ? "rectangle.inset.filled" : "rectangle")
                                .foregroundColor(.accentColor)
                            Text(localizationManager.localized("math_card_border"))
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        // 按鈕 A: 插入為可二次編輯的文字方塊（滿足修改、縮放、字型等編輯要求）
                        Button {
                            let textToInsert = currentResult?.displayText ?? formulaInput
                            if let onInsertEditable = onInsertEditableText {
                                onInsertEditable(textToInsert)
                            } else if let cardImg = renderResultCardToImage(currentResult ?? MathResult(original: formulaInput, normalized: formulaInput, value: 0, formatted: "")) {
                                onInsertFormula(textToInsert, cardImg)
                            }
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "character.cursor.ibeam")
                                Text(localizationManager.localized("math_insert_editable"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        // 按鈕 B: 插入為便簽風格算式卡片
                        Button {
                            let targetRes = currentResult ?? MathResult(original: formulaInput, normalized: formulaInput, value: 0, formatted: "")
                            if let cardImg = renderResultCardToImage(targetRes) {
                                onInsertFormula(targetRes.displayText, cardImg)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.richtext")
                                Text(localizationManager.localized("math_insert_card"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(.bar)
            }
            .navigationTitle(localizationManager.localized("math_calc"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("math.close")
                }
            }
            .onAppear {
                evaluateFormula()
            }
        }
    }

    // MARK: - 分頁 1: 科學計算機按鍵盤
    private var calculatorKeypadView: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(0..<calcKeyRows.count, id: \.self) { rowIndex in
                    HStack(spacing: 6) {
                        ForEach(calcKeyRows[rowIndex], id: \.self) { key in
                            Button(action: {
                                appendInput(key)
                            }) {
                                Text(key)
                                    .font(.system(size: isSpecialKey(key) ? 12 : 16, weight: .medium, design: .monospaced))
                                    .frame(maxWidth: .infinity, minHeight: 38)
                                    .background(keyBackgroundColor(key))
                                    .foregroundColor(keyForegroundColor(key))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 分頁 2: 微積分與工程數學模板
    private var calculusTemplatesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(calculusTemplates, id: \.name) { template in
                    Button(action: {
                        formulaInput = template.expr
                        evaluateFormula()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.caption.bold())
                                .foregroundColor(.accentColor)
                            Text(template.expr)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 分頁 3: 數學與特殊符號庫
    private var symbolsPaletteView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(mathSymbolSections, id: \.title) { sec in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sec.title)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 42))], spacing: 8) {
                            ForEach(sec.symbols, id: \.self) { sym in
                                Button(action: {
                                    appendInput(sym)
                                }) {
                                    Text(sym)
                                        .font(.system(size: 17, weight: .medium))
                                        .frame(width: 42, height: 38)
                                        .background(Color.secondary.opacity(0.12))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 分頁 4: 常用常數與單位
    private var constantsView: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(scientificConstants, id: \.symbol) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.bold())
                            Text(item.valueDesc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            appendInput(item.symbol)
                        }) {
                            Text(item.symbol)
                                .font(.system(.body, design: .monospaced).bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(8)
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 輔助方法
    private func appendInput(_ str: String) {
        if str == "=" {
            evaluateFormula()
        } else {
            formulaInput += str
            evaluateFormula()
        }
    }

    private func isSpecialKey(_ key: String) -> Bool {
        return key.count > 2 || key.contains("(")
    }

    private func keyBackgroundColor(_ key: String) -> Color {
        if key == "=" {
            return Color.accentColor
        } else if ["+", "-", "×", "÷"].contains(key) {
            return Color.orange.opacity(0.18)
        } else if isSpecialKey(key) {
            return Color.secondary.opacity(0.12)
        } else {
            return Color.secondary.opacity(0.18)
        }
    }

    private func keyForegroundColor(_ key: String) -> Color {
        if key == "=" {
            return .white
        } else if ["+", "-", "×", "÷"].contains(key) {
            return .orange
        } else {
            return .primary
        }
    }

    private func evaluateFormula() {
        let trimmed = formulaInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.currentResult = nil
            self.errorMessage = nil
            return
        }
        let result = MathEngine.evaluate(trimmed)
        switch result {
        case .success(let mathRes):
            self.currentResult = mathRes
            self.errorMessage = nil
        case .failure(let error):
            self.currentResult = nil
            self.errorMessage = "\(localizationManager.localized("math_error")): \(error.localizedDescription)"
        }
    }

    @MainActor
    private func renderResultCardToImage(_ result: MathResult) -> UIImage? {
        let renderer = ImageRenderer(content:
            HStack(spacing: 12) {
                Image(systemName: "function")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text(result.displayText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(14)
            .overlay(
                Group {
                    if keepCardBorder {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                    }
                }
            )
            .shadow(color: Color.black.opacity(keepCardBorder ? 0.08 : 0.04), radius: 6, y: 3)
            .padding(10)
        )
        renderer.scale = 2.0
        return renderer.uiImage
    }
}

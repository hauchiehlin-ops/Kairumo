//
//  MathCalculatorSheet.swift
//  Kairumo
//
//  算式計算與結果卡片生成面板
//  支援實時求值、四則運算、平方根、百分比與一鍵貼入畫布
//

import SwiftUI

public struct MathCalculatorSheet: View {
    var onInsertFormula: (String, UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    @State private var formulaInput: String = "125 * 8 + 45"
    @State private var currentResult: MathResult? = nil
    @State private var errorMessage: String? = nil
    @State private var keepCardBorder: Bool = true

    private let quickFormulas = [
        "125 * 8 + 45",
        "1200 * (1 - 0.15)",
        "sqrt(144) + 2^4",
        "(350 + 420 + 290) / 3",
        "5000 * 3.5%",
        "30 * 1.5 + 40 * 2"
    ]

    public init(onInsertFormula: @escaping (String, UIImage) -> Void) {
        self.onInsertFormula = onInsertFormula
    }

    public var body: some View {
        NavigationStack {
            // 內容要能捲。
            //
            // 原本是一個固定高度的 `VStack` + `Spacer()` + 底部按鈕，
            // 外面再套 `.frame(minHeight: 420)`。視窗一矮（或 sheet 開在
            // 半高），**被切掉的正好是最下面那顆「貼入畫布」** ——
            // 這張表存在的理由就是那顆按鈕。
            //
            // 現在主要動作固定在底部安全區，上面的內容自己捲。
            ScrollView {
                VStack(spacing: 20) {
                    // 1. 算式輸入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizationManager.localized("math_expression"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField(localizationManager.localized("math_placeholder"), text: $formulaInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .onSubmit {
                                    evaluateFormula()
                                }

                            Button(localizationManager.localized("math_calculate")) {
                                evaluateFormula()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)

                    // 2. 常用算式範本
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickFormulas, id: \.self) { sample in
                                Button(sample) {
                                    formulaInput = sample
                                    evaluateFormula()
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // 3. 計算結果呈現卡片
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)

                        if let res = currentResult {
                            VStack(spacing: 12) {
                                Text(res.displayText)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                Text("\(localizationManager.localized("math_value_prefix")): \(res.formattedResult)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(24)
                        } else if let err = errorMessage {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(24)
                        } else {
                            Text(localizationManager.localized("math_input_hint"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(24)
                        }
                    }
                    .frame(maxHeight: 180)
                    .padding(.horizontal)

                    // 3.5 邊框選項
                    if currentResult != nil {
                        Toggle(isOn: $keepCardBorder) {
                            HStack(spacing: 6) {
                                Image(systemName: keepCardBorder ? "rectangle.inset.filled" : "rectangle")
                                    .foregroundColor(.accentColor)
                                Text(localizationManager.localized("math_card_border"))
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                    }

                }
                .padding(.top)
                .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .bottom) {
                // 4. 貼入畫布按鈕 —— 釘在底部，永遠看得到也點得到。
                if let res = currentResult {
                    Button {
                        if let cardImg = renderResultCardToImage(res) {
                            onInsertFormula(res.displayText, cardImg)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                            Text(localizationManager.localized("math_insert"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.bar)
                }
            }
            .navigationTitle(localizationManager.localized("math_calc"))
            // 大標題在這裡只是把「取消」擠到標題上面、又把輸入框推到摺線下 ——
            // 這張表沒有長到需要標題隨捲動縮小。
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                    // 稽核與無障礙都要認得這張表 —— 在此之前這四張
                    // 插入面板**一個識別碼都沒有**，所以從來沒被檢查過。
                    .accessibilityIdentifier("math.close")
                }
            }
            .onAppear {
                evaluateFormula()
            }
        }
    }

    private func evaluateFormula() {
        let result = MathEngine.evaluate(formulaInput)
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

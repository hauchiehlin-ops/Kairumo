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
            VStack(spacing: 20) {
                // 1. 算式輸入框
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localized("math_expression"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("例如: 125 * 8 + 45", text: $formulaInput)
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

                            Text("數值: \(res.formattedResult)")
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
                        Text("請在上方輸入算式後點擊「計算求解」")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(24)
                    }
                }
                .frame(maxHeight: 180)
                .padding(.horizontal)

                Spacer()

                // 4. 貼入畫布按鈕
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
                    .padding(.bottom)
                }
            }
            .padding(.top)
            .navigationTitle(localizationManager.localized("math_calc"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                evaluateFormula()
            }
        }
        .frame(minWidth: 480, minHeight: 420)
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
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
            .padding(10)
        )
        renderer.scale = 2.0
        return renderer.uiImage
    }
}

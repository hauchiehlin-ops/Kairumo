//
//  ExportPreviewSheet.swift
//  Kairumo
//
//  匯出預覽（工作項 S-100）。
//
//  # 預覽的是**真的那份資料**，不是另外畫一次
//
//  匯出流程先把位元組產生出來（`buildNotebookPdf()` / `pngData()`），
//  這裡再把那份位元組開起來 —— PDF 走 PDFKit、PNG 走 UIImage。
//  所以畫面上看到的與送出去的是同一份東西。
//
//  另外畫一份「大概長這樣」的預覽是行不通的：這個專案已經踩過一次，
//  匯出若在平台層另外算繪，畫出來的東西遲早會跟畫布上的不一樣
//  （那次是匯出的 PDF 完全沒有版面，畫布上是康乃爾、匯出來是空白紙）。
//  預覽如果也走那條路，它會變成一個**看起來沒問題、但不保證等於結果**
//  的畫面，那比沒有預覽更糟。
//

import PDFKit
import SwiftUI
import UIKit

struct ExportPreviewSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    let data: Data
    let fileExtension: String
    /// 使用者確認要送出。呼叫端接著叫系統分享面板。
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch fileExtension.lowercased() {
                case "pdf":
                    if let document = PDFDocument(data: data) {
                        PdfPreview(document: document)
                    } else {
                        unavailable
                    }
                case "png", "jpg", "jpeg":
                    if let image = UIImage(data: data) {
                        ScrollView {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    } else {
                        unavailable
                    }
                default:
                    ScrollView {
                        Text(String(data: data, encoding: .utf8) ?? "")
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .navigationTitle(localizationManager.localized("export_preview"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text(localizationManager.localized("export_preview_hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("export_now")) {
                        // 只留下意願，真正的分享由呼叫端在這個 sheet
                        // 收乾淨之後才開 —— 兩個 sheet 疊在一起的話，
                        // 後面那個會被 SwiftUI 吞掉。
                        onExport()
                        dismiss()
                    }
                }
            }
        }
    }

    /// 預覽算不出來**不等於匯出失敗**，所以這裡仍然讓使用者送出。
    private var unavailable: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text(localizationManager.localized("export_preview_unavailable"))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
    }
}

/// PDFKit 的檢視器。翻頁、縮放、捲動都由它處理 ——
/// 自己用 `UIImage` 逐頁算繪一次只會多一份會漂移的程式碼。
private struct PdfPreview: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}

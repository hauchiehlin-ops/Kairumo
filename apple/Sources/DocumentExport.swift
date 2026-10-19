//
//  DocumentExport.swift
//  Kairumo
//
//  操作手冊與隱私權政策的「分享、匯出或列印」。
//
//  文件是 WKWebView 裡的 HTML。匯出與列印都走網頁的**列印格式器**（`viewPrintFormatter`），
//  它會把整份文件分頁排版 —— 而不是只截下目前看得到的那一屏。
//

import SwiftUI
import UIKit
import WebKit

/// 讓工具列拿得到目前的 WKWebView（它是 UIViewRepresentable 裡建立的，SwiftUI 這一層摸不到）。
@MainActor
final class DocumentWebHandle: ObservableObject {
    weak var webView: WKWebView?

    /// 排成 A4 的多頁 PDF。文件還沒載入就回 nil。
    func makePDF() -> Data? {
        guard let webView else { return nil }
        return Self.pdfData(from: webView.viewPrintFormatter())
    }

    func printDocument(jobName: String) {
        guard let webView else { return }
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printFormatter = webView.viewPrintFormatter()
        controller.showsNumberOfCopies = true
        if UIDevice.current.userInterfaceIdiom == .pad {
            let rect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 0, height: 0)
            controller.present(from: rect, in: webView, animated: true, completionHandler: nil)
        } else {
            controller.present(animated: true, completionHandler: nil)
        }
    }

    /// 以 A4（72 dpi 下 595 × 842）排版，四周留 36 點邊界。
    static func pdfData(from formatter: UIViewPrintFormatter) -> Data? {
        let paper = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let printable = paper.insetBy(dx: 36, dy: 36)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        // 這兩個屬性在 UIKit 裡是唯讀的，只能用 KVC 設定（排版 PDF 的標準作法）。
        renderer.setValue(NSValue(cgRect: paper), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")
        let pages = renderer.numberOfPages
        guard pages > 0 else { return nil }
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paper, nil)
        for index in 0..<pages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: index, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

/// 工具列上的「分享、匯出或列印」選單。
struct DocumentExportMenu: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    let document: BundledDocument
    @ObservedObject var handle: DocumentWebHandle
    @State private var sharedFile: SharedFile?
    @State private var failed = false

    var body: some View {
        Menu {
            Button {
                exportPDF()
            } label: {
                Label(localizationManager.localized("doc_export_pdf"), systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("document.export.pdf")
            Button {
                handle.printDocument(jobName: title)
            } label: {
                Label(localizationManager.localized("doc_print"), systemImage: "printer")
            }
            .accessibilityIdentifier("document.print")
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help(localizationManager.localized("doc_share_or_print"))
        .accessibilityLabel(localizationManager.localized("doc_share_or_print"))
        .accessibilityIdentifier("document.share.menu")
        .sheet(item: $sharedFile) { file in
            ShareItemsSheet(items: [file.url])
        }
        .alert(localizationManager.localized("doc_export_failed"), isPresented: $failed) {
            Button(localizationManager.localized("done"), role: .cancel) {}
        }
    }

    private var title: String { localizationManager.localized(document.titleKey) }

    private func exportPDF() {
        guard let data = handle.makePDF() else { failed = true; return }
        let name = "Kairumo-\(document.rawValue).pdf"
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do {
            try data.write(to: url, options: .atomic)
            sharedFile = SharedFile(url: url)
        } catch {
            failed = true
        }
    }
}

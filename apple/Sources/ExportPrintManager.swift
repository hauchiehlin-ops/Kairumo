import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import PDFKit
#endif

/// Apple 平台匯出與列印整合管理員（工作項 S-18, S-43, S-55）。
///
/// 串接 Rust core 的 `exportPdf`、`exportPagePdf`、`exportPagePng` 與 `printData`，
/// 負責呈現平台原生 Share Sheet 與系統列印對話框。
@MainActor
public final class ExportPrintManager {

    public static let shared = ExportPrintManager()

    private init() {}

    /// 匯出指定頁面為單頁 PDF 資料。
    public func exportPagePdf(session: PadnoteSession, pageId: String) throws -> Data {
        return try session.exportPagePdf(pageId: pageId)
    }

    /// 匯出指定頁面為 PNG 圖片資料。
    ///
    /// 走 `PageImageRenderer` 而不是核心的 `exportPagePng`：後者把文字畫成
    /// 灰條，匯出的圖上看不到字（工作項 S-60）。
    /// - Parameters:
    ///   - scale: 縮放倍率（例如 2.0 代表 @2x Retina 高解析度）。
    public func exportPagePng(session: PadnoteSession, pageId: String, scale: Float = 2.0) throws -> Data {
        return try PageImageRenderer.renderPng(session: session, pageId: pageId, scale: scale)
    }

    // MARK: - 系統分享面板 (Share Sheet)

    #if canImport(UIKit)
    /// 彈出 iOS 系統分享面板（可儲存至「檔案」、AirDrop、通訊軟體等）。
    public func presentShareSheet(
        data: Data,
        filename: String,
        from viewController: UIViewController,
        sourceView: UIView? = nil
    ) {
        let tempUrl = FileManager.default.temporaryDirectory.appending(path: filename)
        do {
            try data.write(to: tempUrl, options: .atomic)
        } catch {
            print("[ExportPrintManager] 寫入暫存檔失敗：\(error)")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tempUrl], applicationActivities: nil)

        // iPad 必備 popoverPresentationController 錨點，否則會 crash
        if let popover = activityVC.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }

        viewController.present(activityVC, animated: true)
    }
    #endif

    // MARK: - 系統列印 (System Print Flow - 工作項 S-55)

    #if canImport(UIKit)
    /// 透過 iOS `UIPrintInteractionController` 開啟系統列印對話框。
    /// - Parameters:
    ///   - pageId: 若為 `nil` 則列印整份筆記本；指定 ID 則列印該單頁。
    ///   - jobTitle: 列印任務名稱（顯示於印表機排程或佇列中）。
    // unused-param-ok: iPad 上的列印面板要錨在某個東西上，而這裡錨的是
    // `sourceView`。`viewController` 是 iPhone 那條路留下的，兩條路合併
    // 之後就沒人讀它了 —— 但簽章是公開 API，拿掉會動到呼叫端。
    public func printNotebook(
        session: PadnoteSession,
        pageId: String? = nil,
        jobTitle: String = "Padnote Document",
        from viewController: UIViewController,
        sourceView: UIView? = nil,
        completion: ((UIPrintInteractionController, Bool, Error?) -> Void)? = nil
    ) throws {
        // 取得列印專用之 PDF 二進位資料
        let printPdfData = try session.printData(pageId: pageId)

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = jobTitle
        printInfo.duplex = .longEdge

        printController.printInfo = printInfo
        printController.printingItem = printPdfData
        printController.showsNumberOfCopies = true
        printController.showsPaperSelectionForLoadedPapers = true

        let completionHandler: UIPrintInteractionController.CompletionHandler = { controller, completed, error in
            if let error = error {
                print("[ExportPrintManager] 列印失敗：\(error)")
            } else if completed {
                print("[ExportPrintManager] 列印任務已成功送出")
            }
            completion?(controller, completed, error)
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            if let sourceView = sourceView {
                printController.present(from: sourceView.bounds, in: sourceView, animated: true, completionHandler: completionHandler)
            } else {
                printController.present(animated: true, completionHandler: completionHandler)
            }
        } else {
            printController.present(animated: true, completionHandler: completionHandler)
        }
    }
    #elseif canImport(AppKit)
    /// 透過 macOS `NSPrintOperation` 啟動列印。
    public func printNotebook(
        session: PadnoteSession,
        pageId: String? = nil,
        jobTitle: String = "Padnote Document"
    ) throws {
        let printPdfData = try session.printData(pageId: pageId)
        guard let pdfDoc = PDFDocument(data: printPdfData) else {
            throw NSError(domain: "ExportPrintManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法解析 PDF 資料"])
        }
        guard let printOperation = pdfDoc.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true) else {
            throw NSError(domain: "ExportPrintManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "建立列印操作失敗"])
        }
        printOperation.jobTitle = jobTitle
        printOperation.run()
    }
    #endif
}

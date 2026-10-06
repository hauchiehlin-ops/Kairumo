import QuickLook
import SwiftUI

/// 讓 `.sheet(item:)` 認得一個要分享或預覽的檔案。
struct SharedFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// 系統分享表（存到檔案、AirDrop、傳給別的 App）。
struct ShareItemsSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

/// Quick Look 預覽。USDZ 在支援 AR 的 iPhone、iPad 上會出現「AR」模式，可以把模型放到桌上看。
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_: QLPreviewController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        // orphan-ok: QLPreviewControllerDataSource 的方法，由系統呼叫。
        func numberOfPreviewItems(in _: QLPreviewController) -> Int { 1 }
        // orphan-ok: QLPreviewControllerDataSource 的方法，由系統呼叫。
        func previewController(_: QLPreviewController, previewItemAt _: Int) -> QLPreviewItem { url as NSURL }
    }
}

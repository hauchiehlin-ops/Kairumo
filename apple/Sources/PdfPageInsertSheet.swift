import SwiftUI
import PDFKit

/// 挑一份 PDF 的哪一頁插進筆記。
///
/// # 為什麼要問「第幾頁」
///
/// 只插第一頁的話，一份五十頁的講義使用者就拿不到第四十頁 —— 而那通常
/// 正是他想標註的那一頁。這張表就是為了不讓這個功能只做一半。
///
/// # 插進去之後它是什麼
///
/// **一張圖**，走的是既有的圖片附件那條路。不是一種新的物件型別 ——
/// 那會要一套新的同步欄位、一套新的畫布算繪、兩端各一份，而使用者要的
/// 「可以移動、縮放、疊層、刪除」圖片全部都已經會了。
///
/// 代價是插進去之後不能再選取裡面的文字。對「把一頁講義放進筆記再手寫
/// 標註」這件事來說，那不是使用者會察覺的差別。
@MainActor
struct PdfPageInsertSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 已經收進附件目錄的那份 PDF。
    let fileURL: URL
    /// 算繪好的那一頁。位置與頁次由呼叫端決定。
    let onPick: (UIImage) -> Void

    @State private var pageNumber: Int = 1
    @State private var pageCount: Int = 0
    @State private var preview: UIImage? = nil
    @State private var errorKey: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(Color.secondary.opacity(0.3))
                        .accessibilityIdentifier("pdf_insert.preview")
                } else {
                    // 沒有預覽時也要佔住位置 —— 不然選頁的時候整張表會跳。
                    Color.secondary.opacity(0.08)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if !errorKey.isEmpty {
                                Text(localizationManager.localized(errorKey))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ProgressView()
                            }
                        }
                }

                if pageCount > 1 {
                    Stepper(
                        value: $pageNumber, in: 1...max(1, pageCount)
                    ) {
                        Text("\(pageNumber) / \(pageCount)")
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("pdf_insert.page")
                }

                Text(String(
                    format: localizationManager.localized("pdf_page_range"),
                    "\(max(1, pageCount))"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .navigationTitle(localizationManager.localized("pdf_choose_page"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                        .accessibilityIdentifier("pdf_insert.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("confirm")) {
                        if let image = preview {
                            onPick(image)
                            dismiss()
                        }
                    }
                    .disabled(preview == nil)
                    .accessibilityIdentifier("pdf_insert.confirm")
                }
            }
        }
        .onAppear { load() }
        .onChange(of: pageNumber) { _ in load() }
    }

    /// 算繪目前這一頁。
    ///
    /// 預覽與真正插進去的是**同一張圖** —— 分成兩次算的話，使用者看到的
    /// 與插進去的可能不一樣（倍率、底色），而那種差別沒有人會想到要查。
    private func load() {
        errorKey = ""
        pageCount = PdfPageRenderer.pageCount(url: fileURL)
        guard let image = PdfPageRenderer.render(url: fileURL, pageIndex: pageNumber - 1) else {
            preview = nil
            errorKey = "pdf_render_failed"
            return
        }
        preview = image
    }
}

/// 把一份**外來** PDF 的某一頁畫成圖。
///
/// 抽出來是為了測得到：整條路上每一步都是系統 API（PDFKit），編得過完全
/// 不代表畫得出東西 —— 而它的失敗方式**不會丟例外**，是畫出一張全白的圖。
/// 使用者看到的是「插進去了，可是是空白的」，沒有任何錯誤訊息可以查。
///
/// Android 端的對應物是 `PageImageRenderer.renderPdfPage`。
@MainActor
enum PdfPageRenderer {

    /// 相對於頁面點數的倍率。原尺寸插進來的話，在畫布上放大一點就糊掉了。
    /// 2.0 與頁面縮圖同一個倍率（Retina 級）。
    static let scale: CGFloat = 2

    /// 頁數。讀不出來（壞檔、加密）回 0。
    static func pageCount(url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }

    /// 算繪某一頁。`pageIndex` 從 0 起算，超出範圍回 `nil`。
    ///
    /// **超出範圍不會悄悄退回第一頁** —— 那樣使用者會拿到一頁他沒有選的
    /// 東西，而且看不出哪裡不對。
    static func render(url: URL, pageIndex: Int) -> UIImage? {
        guard let doc = PDFDocument(url: url),
              pageIndex >= 0, pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex) else { return nil }

        let box = page.bounds(for: .mediaBox)
        let size = CGSize(width: box.width * scale, height: box.height * scale)
        guard size.width > 0, size.height > 0 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // **底色一定要填白。** PDF 的頁面背景不是繪製指令的一部分，
            // 不填的話會是透明的，在淺色介面上看起來像插了一張空白頁。
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            // mediaBox 的原點不保證在 (0, 0)。
            ctx.cgContext.translateBy(x: -box.origin.x, y: -box.origin.y)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

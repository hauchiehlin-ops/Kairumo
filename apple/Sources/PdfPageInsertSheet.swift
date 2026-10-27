import SwiftUI
import PDFKit

/// 插入 PDF：整份匯入成筆記內頁（預設），或只把某一頁插成一張圖。
///
/// # 整份匯入
///
/// 每一頁 PDF 成為一頁筆記內頁，等比縮放到整個內頁（位置由核心的 `pdfPagePlacement`
/// 決定，Android 同一支）。插進去的是**一張圖**，走既有的圖片物件那條路 —— 不是
/// 一種新的物件型別：那會要一套新的同步欄位、一套新的畫布算繪、兩端各一份。
/// 依核心的圖層規則，圖片在筆跡**下方**，所以在 PDF 上寫字、畫螢光筆都看得到。
///
/// # 為什麼一切都在背景做
///
/// 原本按下確定之後，主執行緒上做了兩次整頁 PNG 編碼（存檔一次、給已經停用的協作
/// 廣播又一次），而算繪大小是「PDF 宣稱的頁面點數 × 2」—— 掃描器輸出的 PDF 常把
/// mediaBox 寫成像素，一頁就是 4960×7016。iPad 模擬器實測主執行緒卡了好幾秒、
/// 記憶體多出 245 MB；整份匯入時每一頁再來一次，就是「匯入之後整個 App 停住」。
///
/// 現在：算繪大小夾在上限內（核心決定），算繪與 PNG 編碼在背景執行緒一頁一頁做、
/// 每頁做完就放掉點陣圖，主執行緒只在最後收一次結果、寫一次筆記。
@MainActor
struct PdfPageInsertSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 已經收進附件目錄的那份 PDF。
    let fileURL: URL
    /// 筆記內頁的大小（點）。整份匯入時每一頁 PDF 依它縮放。
    let pageSize: CGSize
    /// 算繪好的頁面直接寫進這裡（附件目錄），主執行緒不碰點陣圖。
    let attachmentsDirectory: URL
    /// 整份匯入完成：每一頁的檔名與位置，以及畫不出來而略過的頁數。
    let onImportAll: (_ pages: [PdfImportedPage], _ skipped: Int) -> Void
    /// 只插入目前這一頁（當成一張圖放在目前的內頁上）。
    let onPickSingle: (UIImage) -> Void

    @State private var pageNumber: Int = 1
    @State private var pageCount: Int = 0
    @State private var preview: UIImage? = nil
    @State private var errorKey: String = ""
    @State private var importedSoFar: Int = 0
    @State private var importTask: Task<Void, Never>? = nil
    @State private var previewTask: Task<Void, Never>? = nil

    private var isImporting: Bool { importTask != nil }

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

                if isImporting {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(importedSoFar), total: Double(max(1, pageCount)))
                        Text(String(
                            format: localizationManager.localized("pdf_import_progress"),
                            "\(min(pageCount, importedSoFar + 1))", "\(pageCount)"))
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("pdf_insert.progress")
                } else {
                    if pageCount > 1 {
                        Stepper(
                            value: $pageNumber, in: 1...max(1, pageCount)
                        ) {
                            Text("\(pageNumber) / \(pageCount)")
                                .monospacedDigit()
                        }
                        .accessibilityIdentifier("pdf_insert.page")
                    }

                    Button {
                        insertCurrentPageOnly()
                    } label: {
                        Text(localizationManager.localized("pdf_import_this_page_only"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(preview == nil)
                    .accessibilityIdentifier("pdf_insert.single")

                    Text(localizationManager.localized("pdf_import_hint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .navigationTitle(localizationManager.localized("pdf_import_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { cancel() }
                        .accessibilityIdentifier("pdf_insert.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(
                        format: localizationManager.localized("pdf_import_all_pages"), "\(max(1, pageCount))")) {
                        importAllPages()
                    }
                    .disabled(pageCount == 0 || isImporting)
                    .accessibilityIdentifier("pdf_insert.confirm")
                }
            }
        }
        // 匯入到一半被往下滑掉的話，背景還在寫檔、結果卻沒有地方收。
        .interactiveDismissDisabled(isImporting)
        .onAppear { loadPreview() }
        .onChange(of: pageNumber) { _ in loadPreview() }
        .onDisappear {
            previewTask?.cancel()
            importTask?.cancel()
        }
    }

    /// 在背景算繪目前這一頁的預覽。主執行緒只接結果。
    private func loadPreview() {
        errorKey = ""
        previewTask?.cancel()
        let url = fileURL
        let index = pageNumber - 1
        previewTask = Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (Int, UIImage?) in
                (PdfPageRenderer.pageCount(url: url), PdfPageRenderer.render(url: url, pageIndex: index))
            }.value
            guard !Task.isCancelled else { return }
            pageCount = result.0
            preview = result.1
            if result.1 == nil { errorKey = "pdf_render_failed" }
        }
    }

    private func insertCurrentPageOnly() {
        guard let image = preview else { return }
        onPickSingle(image)
        dismiss()
    }

    private func importAllPages() {
        guard importTask == nil, pageCount > 0 else { return }
        let url = fileURL
        let size = pageSize
        let directory = attachmentsDirectory
        let total = pageCount
        importedSoFar = 0
        let report: @MainActor @Sendable (Int) -> Void = { importedSoFar = $0 }
        let finish: @MainActor @Sendable ([PdfImportedPage], Int) -> Void = { pages, skipped in
            importTask = nil
            onImportAll(pages, skipped)
            dismiss()
        }
        // 整個迴圈在同一個背景工作裡：PDFDocument 不是 Sendable，只在這一條執行緒上用。
        // 每頁算繪、編碼、落盤，做完就放掉點陣圖（autoreleasepool），記憶體不會隨頁數累積。
        importTask = Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: url) else {
                await finish([], total)
                return
            }
            var pages: [PdfImportedPage] = []
            var skipped = 0
            for index in 0 ..< total {
                if Task.isCancelled {
                    PdfPageRenderer.discard(pages, in: directory)
                    return
                }
                let page = autoreleasepool {
                    PdfPageRenderer.importPage(document: document, index: index, pageSize: size, into: directory)
                }
                if let page { pages.append(page) } else { skipped += 1 }
                await report(index + 1)
            }
            if Task.isCancelled {
                PdfPageRenderer.discard(pages, in: directory)
                return
            }
            await finish(pages, skipped)
        }
    }

    private func cancel() {
        importTask?.cancel()
        importTask = nil
        dismiss()
    }
}

/// 整份匯入時，一頁 PDF 算繪好、寫進附件目錄之後的結果。
struct PdfImportedPage: Sendable, Equatable {
    /// 附件目錄裡的檔名。
    let fileName: String
    /// 在內頁上的位置（內頁座標，點）。
    let frame: CGRect
}

/// 把一份**外來** PDF 的某一頁畫成圖。
///
/// 抽出來是為了測得到：整條路上每一步都是系統 API（PDFKit），編得過完全
/// 不代表畫得出東西 —— 而它的失敗方式**不會丟例外**，是畫出一張全白的圖。
///
/// 全部 `nonisolated`：要在背景執行緒呼叫（見 `PdfPageInsertSheet`）。
/// Android 端的對應物是 `PageImageRenderer.renderPdfPage`。
enum PdfPageRenderer {

    /// 相對於顯示大小的倍率（Retina 級）。實際像素還會被核心的上限夾住。
    static let scale: Float = 2

    /// 頁數。讀不出來（壞檔、加密）回 0。
    nonisolated static func pageCount(url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }

    /// 算繪某一頁（以它自己的大小為準，給預覽與「只插入這一頁」）。`pageIndex` 從 0 起算，超出範圍回 `nil`。
    ///
    /// **超出範圍不會悄悄退回第一頁** —— 那樣使用者會拿到一頁他沒有選的
    /// 東西，而且看不出哪裡不對。
    nonisolated static func render(url: URL, pageIndex: Int) -> UIImage? {
        guard let doc = PDFDocument(url: url),
              pageIndex >= 0, pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex) else { return nil }
        let box = page.bounds(for: .mediaBox)
        guard let placement = pdfPagePlacement(
            sourceWidth: Float(box.width), sourceHeight: Float(box.height),
            pageWidth: Float(box.width), pageHeight: Float(box.height), renderScale: scale)
        else { return nil }
        return render(page: page, pixelWidth: Int(placement.pixelWidth), pixelHeight: Int(placement.pixelHeight))
    }

    /// 算繪一頁並寫進 `directory`，回傳檔名與它在內頁上的位置。
    nonisolated static func importPage(
        document: PDFDocument, index: Int, pageSize: CGSize, into directory: URL
    ) -> PdfImportedPage? {
        guard index >= 0, index < document.pageCount, let page = document.page(at: index) else { return nil }
        let box = page.bounds(for: .mediaBox)
        guard let placement = pdfPagePlacement(
            sourceWidth: Float(box.width), sourceHeight: Float(box.height),
            pageWidth: Float(pageSize.width), pageHeight: Float(pageSize.height), renderScale: scale),
            let image = render(page: page, pixelWidth: Int(placement.pixelWidth),
                               pixelHeight: Int(placement.pixelHeight)),
            let data = image.pngData()
        else { return nil }
        let fileName = "att_\(UUID().uuidString).png"
        do {
            try data.write(to: directory.appending(path: fileName), options: .atomic)
        } catch {
            return nil
        }
        return PdfImportedPage(
            fileName: fileName,
            frame: CGRect(x: CGFloat(placement.x), y: CGFloat(placement.y),
                          width: CGFloat(placement.width), height: CGFloat(placement.height)))
    }

    /// 匯入被取消：已經寫出去的頁面刪掉，不留沒有人引用的附件。
    nonisolated static func discard(_ pages: [PdfImportedPage], in directory: URL) {
        for page in pages {
            try? FileManager.default.removeItem(at: directory.appending(path: page.fileName))
        }
    }

    /// 把一頁畫成指定像素大小的圖（scale 1：一個點就是一個像素，大小完全由呼叫端決定）。
    nonisolated static func render(page: PDFPage, pixelWidth: Int, pixelHeight: Int) -> UIImage? {
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        let box = page.bounds(for: .mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let size = CGSize(width: pixelWidth, height: pixelHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            // **底色一定要填白。** PDF 的頁面背景不是繪製指令的一部分，
            // 不填的話會是透明的，在淺色介面上看起來像插了一張空白頁。
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: size.width / box.width, y: -size.height / box.height)
            // mediaBox 的原點不保證在 (0, 0)。
            ctx.cgContext.translateBy(x: -box.origin.x, y: -box.origin.y)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

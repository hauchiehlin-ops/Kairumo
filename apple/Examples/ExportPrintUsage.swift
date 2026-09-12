import SwiftUI

/// 筆記本匯出與列印 UI 範例（工作項 S-18, S-43, S-55）。
///
/// 示範在 SwiftUI 工具列或導覽列中加入：
/// 1. 「匯出完整 PDF」（包含手寫標註與底紋）
/// 2. 「匯出單頁圖片 (PNG)」（支援 Retina 高解析度）
/// 3. 「系統列印」（呼叫 iOS/macOS 系統列印面板）
struct NotebookExportMenu: View {
    let session: PadnoteSession
    let currentPageId: String?

    @State private var isExporting: Bool = false
    @State private var errorMessage: String?
    @State private var showShareSheet: Bool = false
    @State private var shareData: Data?
    @State private var shareFilename: String = ""

    var body: some View {
        Menu {
            Section(header: Text("匯出選項")) {
                Button {
                    exportFullPdf()
                } label: {
                    Label("匯出筆記本為 PDF", systemImage: "doc.text.fill")
                }

                if let pageId = currentPageId {
                    Button {
                        exportCurrentPagePdf(pageId: pageId)
                    } label: {
                        Label("匯出此頁為 PDF", systemImage: "doc.badge.plus")
                    }

                    Button {
                        exportCurrentPagePng(pageId: pageId)
                    } label: {
                        Label("匯出此頁為圖片 (PNG)", systemImage: "photo.fill")
                    }
                }
            }

            Section(header: Text("列印")) {
                Button {
                    printDocument(pageId: nil)
                } label: {
                    Label("列印整份筆記本…", systemImage: "printer.fill")
                }

                if let pageId = currentPageId {
                    Button {
                        printDocument(pageId: pageId)
                    } label: {
                        Label("列印此頁…", systemImage: "printer")
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .accessibilityLabel("匯出與列印")
        }
        .disabled(isExporting)
        .alert("錯誤", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("確定", role: .cancel) {}
        } message: {
            if let msg = errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - 操作函式

    private func exportFullPdf() {
        isExporting = true
        Task.detached {
            do {
                let data = try session.exportPdf()
                await MainActor.run {
                    self.isExporting = false
                    self.share(data: data, filename: "\(session.title()).pdf")
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = "PDF 匯出失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func exportCurrentPagePdf(pageId: String) {
        isExporting = true
        Task.detached {
            do {
                let data = try session.exportPagePdf(pageId: pageId)
                await MainActor.run {
                    self.isExporting = false
                    self.share(data: data, filename: "\(session.title())-page.pdf")
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = "單頁 PDF 匯出失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func exportCurrentPagePng(pageId: String) {
        isExporting = true
        Task.detached {
            do {
                let data = try session.exportPagePng(pageId: pageId, scale: 2.0)
                await MainActor.run {
                    self.isExporting = false
                    self.share(data: data, filename: "\(session.title())-page.png")
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = "圖片匯出失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func printDocument(pageId: String?) {
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            self.errorMessage = "找不到根視圖控制器以顯示列印面板"
            return
        }

        do {
            try ExportPrintManager.shared.printNotebook(
                session: session,
                pageId: pageId,
                jobTitle: session.title(),
                from: rootVC
            )
        } catch {
            self.errorMessage = "啟動列印失敗：\(error.localizedDescription)"
        }
        #elseif canImport(AppKit)
        do {
            try ExportPrintManager.shared.printNotebook(
                session: session,
                pageId: pageId,
                jobTitle: session.title()
            )
        } catch {
            self.errorMessage = "啟動列印失敗：\(error.localizedDescription)"
        }
        #endif
    }

    private func share(data: Data, filename: String) {
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        ExportPrintManager.shared.presentShareSheet(data: data, filename: filename, from: rootVC)
        #endif
    }
}

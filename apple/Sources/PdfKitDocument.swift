//
//  PdfKitDocument.swift
//  Kairumo
//
//  PDF 的讀取與算繪（Apple）。用系統的 PDFKit。
//
//  # 為什麼不是 PDFium（決策 D-11b，2026-09-16）
//
//  核心有一份 `padnote-pdf-pdfium`，而 PDFium 需要一份**預建的原生庫**。
//  問題出在 Mac：公開發佈的 mac 版是 **平台 1（macOS）**，不是
//  **平台 6（MACCATALYST）** —— Catalyst 的建置根本不會去選它。要讓
//  Mac 版有 PDF，就得自己用 depot_tools + gn + ninja 建一份 Catalyst 的
//  PDFium，而那是一個要長期維護的東西。
//
//  而 PDFKit 在 iOS、iPadOS、macOS 與 Catalyst 上**全都有**，
//  `ExportPrintManager` 早就在用它列印。與其為了四個平台裡的一個去自建
//  PDFium，不如讓 Apple 整條線都走系統那一套：
//
//  - 少 6 MB × 2 的二進位（App 體積）
//  - 少一個第三方供應鏈（不必追它的版本與 CVE）
//  - 少一個「系統更新之後可能壞掉、而我們沒有能力修」的東西
//
//  Android 那一側仍然用 libpdfium（`jniLibs/<abi>/libpdfium.so`），因為
//  Android 沒有系統級的 PDF 算繪 API 能做到同一件事（`PdfRenderer` 只能
//  算繪，讀不到文字層）。**兩邊的後端不同，但介面與座標約定同一份。**
//
//  # 座標系
//
//  PDF 的原點在**左下**，頁面座標的原點在**左上**。兩者 Y 軸相反，
//  標註位置偏移的 bug 幾乎都出在這裡。這裡的轉換與核心
//  `padnote_pdf::PdfPage` 的 `pdf_to_page` / `page_to_pdf` 完全一致 ——
//  有一項不一致，同一份標註在兩個平台上就會落在不同的位置。
//

import Foundation
import PDFKit

/// 一頁的幾何。欄位與核心的 `padnote_pdf::PdfPage` 對齊。
struct PdfPageInfo: Equatable {
    let index: Int
    /// 頁面尺寸（point），**未**套用旋轉。
    let size: CGSize
    /// 0 / 90 / 180 / 270。
    let rotation: Int

    /// 套用旋轉之後的顯示尺寸。
    ///
    /// 90/270 度時寬高互換 —— 忘記這件事會讓橫向掃描件顯示成被壓扁的直式。
    var displaySize: CGSize {
        switch rotation {
        case 90, 270: return CGSize(width: size.height, height: size.width)
        default: return size
        }
    }

    /// PDF 座標（原點左下）→ 頁面座標（原點左上）。
    func pdfToPage(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }

    /// 頁面座標（原點左上）→ PDF 座標（原點左下）。
    func pageToPdf(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }
}

/// PDF 裡的一段文字及其位置。
///
/// 有真正的文字層才做得到**選取與 highlight**。用畫線模擬螢光筆的話，
/// 選不到字也搜不到 —— 那不算 PDF 標註。
struct PdfTextSpan: Equatable {
    let text: String
    /// PDF 座標系（原點左下，單位 point）。
    let rect: CGRect
}

enum PdfKitError: LocalizedError, Equatable {
    case notAPdf
    case passwordRequired
    case pageOutOfRange(requested: Int, total: Int)

    var errorDescription: String? {
        // `localizedUnsafe`：這個型別會在背景執行緒被丟出（算繪不在主執行緒），
        // 而 `localized` 是 @MainActor 的。
        let l = LocalizationManager.shared.localizedUnsafe
        switch self {
        case .notAPdf:
            return l("pdf_not_a_pdf")
        case .passwordRequired:
            // 「PDF 壞了」對使用者沒有用，「需要密碼」才指得出下一步。
            return l("pdf_password_required")
        case .pageOutOfRange(let requested, let total):
            return l("pdf_page_out_of_range")
                .replacingOccurrences(of: "%1@", with: "\(requested)")
                .replacingOccurrences(of: "%2@", with: "\(total)")
        }
    }
}

/// 一份 PDF。
///
/// **持有位元組而不是只持有 `PDFDocument`**：`PDFDocument` 不是 `Sendable`，
/// 而算繪要放到背景執行緒做（一頁 A4 在 2x 下是 1190×1684 像素）。
/// 每次操作重開一份的成本遠低於算繪本身，而且完全避開跨執行緒共用的問題。
struct PdfKitDocument {

    private let data: Data
    private let password: String?
    let pageCount: Int

    init(data: Data, password: String? = nil) throws {
        guard let document = PDFDocument(data: data) else {
            throw PdfKitError.notAPdf
        }
        if document.isLocked {
            // 密碼錯或沒給，兩者都走這裡。`unlock` 回 false 時仍然是鎖著的。
            guard let password, document.unlock(withPassword: password) else {
                throw PdfKitError.passwordRequired
            }
        }
        self.data = data
        self.password = password
        self.pageCount = document.pageCount
    }

    /// 某一頁的幾何。
    func page(at index: Int) throws -> PdfPageInfo {
        let page = try pdfPage(at: index)
        let bounds = page.bounds(for: .mediaBox)
        return PdfPageInfo(
            index: index,
            size: bounds.size,
            // PDFKit 的 rotation 可能是負數或超過 360（例如 -90、450）。
            // 正規化成 0/90/180/270，否則 displaySize 的 switch 會漏掉。
            rotation: ((page.rotation % 360) + 360) % 360
        )
    }

    /// 取出文字層。掃描件沒有文字層時回**空陣列**，那不是錯誤 ——
    /// 那是 OCR 要處理的事。
    func textSpans(at index: Int) throws -> [PdfTextSpan] {
        let page = try pdfPage(at: index)
        guard let content = page.string, !content.isEmpty else { return [] }

        var spans: [PdfTextSpan] = []
        // 逐「行」取範圍。逐字元的話一頁會有上萬個 span，跨邊界傳輸與
        // 命中測試都會變慢，而使用者要選的單位本來就是行或詞。
        let characters = page.numberOfCharacters
        guard characters > 0 else { return [] }

        var start = 0
        for line in content.components(separatedBy: .newlines) {
            let length = line.count
            defer { start += length + 1 }   // +1 是換行本身
            guard length > 0, start + length <= characters else { continue }
            guard let selection = page.selection(
                for: NSRange(location: start, length: length)
            ) else { continue }
            spans.append(
                PdfTextSpan(text: line, rect: selection.bounds(for: page))
            )
        }
        return spans
    }

    /// 算繪一頁成 PNG。`scale` 是相對原始尺寸的倍率。
    ///
    /// **不要在主執行緒呼叫。** 一頁 A4 在 2x 下是 1190×1684 像素，
    /// 在主執行緒算會讓畫面整個停住。
    func renderPNG(at index: Int, scale: CGFloat) throws -> Data {
        let page = try pdfPage(at: index)
        // 用 `bounds(for: .mediaBox)` 加上 PDFKit 自己的旋轉處理：
        // `thumbnail(of:for:)` 會套用旋轉，所以這裡要的是**顯示尺寸**。
        let info = try self.page(at: index)
        let clamped = max(0.25, min(scale, 8.0))
        let target = CGSize(
            width: max(1, (info.displaySize.width * clamped).rounded()),
            height: max(1, (info.displaySize.height * clamped).rounded())
        )
        let image = page.thumbnail(of: target, for: .mediaBox)
        guard let png = image.pngData() else {
            throw PdfKitError.notAPdf
        }
        return png
    }

    // MARK: - 內部

    private func pdfPage(at index: Int) throws -> PDFPage {
        // **邊界檢查在這裡做完**，不要讓越界索引進到 PDFKit ——
        // `page(at:)` 越界時回 nil，而 nil 在上層看起來像「這一頁是空的」。
        guard index >= 0, index < pageCount else {
            throw PdfKitError.pageOutOfRange(requested: index, total: pageCount)
        }
        guard let document = PDFDocument(data: data) else {
            throw PdfKitError.notAPdf
        }
        if document.isLocked, let password {
            _ = document.unlock(withPassword: password)
        }
        guard let page = document.page(at: index) else {
            throw PdfKitError.pageOutOfRange(requested: index, total: pageCount)
        }
        return page
    }
}

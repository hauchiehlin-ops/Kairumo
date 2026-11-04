import XCTest

@testable import Kairumo

/// 文件範本目錄（工作項 S-61）。
///
/// 這組測試守的是**目錄真的打包進 App 了**，以及套用之後頁面上真的有東西。
/// 兩者都是「在我機器上好好的」最容易漏掉的那一類 —— 資源沒進 bundle 時，
/// 目錄會安靜地變成空陣列，畫面上只是少一個區塊，不會報錯。
@MainActor
final class DocumentTemplateTests: XCTestCase {

    func testPageScaleDoesNotChangeWhenOnlyViewportHeightChanges() {
        let portrait = PageViewportLayout.scale(availableWidth: 368, pageWidth: 800)
        let keyboardVisible = PageViewportLayout.scale(availableWidth: 368, pageWidth: 800)

        XCTAssertEqual(portrait, keyboardVisible, accuracy: 0.0001)
        XCTAssertEqual(portrait, 0.46, accuracy: 0.0001)
        XCTAssertEqual(
            PageViewportLayout.scale(availableWidth: 1_200, pageWidth: 800),
            1.5,
            "視窗比紙張寬時要放大填滿，不留灰邊讓畫布看起來被框住")
        XCTAssertEqual(
            PageViewportLayout.scale(availableWidth: 4_000, pageWidth: 800),
            PageViewportLayout.maxFitScale,
            "放大有上限，否則筆跡會糊")
    }

    func testTheCatalogIsActuallyBundled() {
        XCTAssertFalse(
            DocumentTemplateCatalog.themes.isEmpty,
            "目錄是空的 —— 多半是 Resources/Templates 沒有進 bundle，"
                + "而那不會報錯，只會讓範本清單整個消失")
    }

    func testEveryTemplateHasBothVariantsAndSixLanguageNames() {
        for theme in DocumentTemplateCatalog.themes {
            for category in theme.categories {
                for tmpl in category.templates {
                    // 兩個版本都要在：只有完整案例的話，想要空白表格的人沒東西可用。
                    for kind in DocumentTemplateCatalog.Variantkind.allCases {
                        let variant = DocumentTemplateCatalog.variant(
                            tmpl, kind: kind, language: "zhHant")
                        XCTAssertNotNil(variant, "\(tmpl.id) 缺 \(kind.rawValue) 版本")
                        XCTAssertFalse(
                            variant?.blocks.isEmpty ?? true,
                            "\(tmpl.id) 的 \(kind.rawValue) 版本沒有任何內容")
                    }
                    // 介面上看得到的字要六個語系都在，否則那個語系的使用者
                    // 會看到別種語言的名稱夾在清單中間。
                    for lang in ["zhHant", "en", "zhHans", "ja", "ko", "th"] {
                        XCTAssertFalse(
                            DocumentTemplateCatalog.localized(tmpl.name, language: lang).isEmpty,
                            "\(tmpl.id) 缺 \(lang) 的名稱")
                    }
                }
            }
        }
    }

    func testBlocksStayInsideThePage() {
        // 版面是產生器算的。算錯的話文字會掉到紙外面 —— 畫面上看不出來，
        // 但列印或匯出時那一段就是不見了。
        for theme in DocumentTemplateCatalog.themes {
            for category in theme.categories {
                for tmpl in category.templates {
                    for kind in DocumentTemplateCatalog.Variantkind.allCases {
                        guard let variant = DocumentTemplateCatalog.variant(
                            tmpl, kind: kind, language: "zhHant") else { continue }
                        for block in variant.blocks {
                            XCTAssertGreaterThanOrEqual(block.x, 0, "\(tmpl.id) 區塊跑到紙左邊外面")
                            XCTAssertLessThanOrEqual(
                                block.x + block.width, PageGeometry.width,
                                "\(tmpl.id) 區塊超出紙張右緣")
                            XCTAssertLessThanOrEqual(
                                block.y + block.height, PageGeometry.height,
                                "\(tmpl.id) 的 \(kind.rawValue) 區塊超出紙張下緣")
                            XCTAssertLessThan(
                                block.page, variant.pageCount,
                                "\(tmpl.id) 區塊指到不存在的頁")
                        }
                    }
                }
            }
        }
    }

    func testApplyingATemplatePutsContentOnThePage() throws {
        let tmpl = try XCTUnwrap(DocumentTemplateCatalog.template(id: "meeting_minutes"))
        var doc = NotebookDocument(title: "測試", pageCount: 1)
        DocumentTemplateCatalog.apply(tmpl, kind: .example, language: "zhHant", to: &doc)

        XCTAssertFalse(doc.textAttachments?.isEmpty ?? true, "套用後應該有文字區塊")
        XCTAssertFalse(doc.tableAttachments?.isEmpty ?? true, "會議紀錄應該有表格")
        // 頁數要跟著長，不然第二頁的內容會掛在一本只有一頁的筆記上。
        let maxPage = (doc.textAttachments ?? []).map(\.pageIndex).max() ?? 0
        XCTAssertGreaterThan(doc.pageCount, maxPage, "頁數不足以放下所有區塊")
        XCTAssertGreaterThanOrEqual(doc.pagesData.count, doc.pageCount)
    }

    func testApplyingPaperTemplateNeverOverlapsTextBlocks() throws {
        // 紙張樣板（黃金比例、情緒板、工程藍圖等）套用完整案例時，
        // 絕對不得因為 snapToRules 重算而發生文字區塊相互疊合的現象。
        for paperId in ["golden_ratio", "moodboard", "blueprint", "cornell", "mobile_wireframe"] {
            guard let paper = DocumentTemplateCatalog.paperTemplate(paperId: paperId) else { continue }
            for kind in DocumentTemplateCatalog.Variantkind.allCases {
                var doc = NotebookDocument(title: "測試-\(paperId)", pageCount: 1)
                doc.template = NoteTemplate(paperId: paperId) ?? .blank
                DocumentTemplateCatalog.apply(paper, kind: kind, language: "zhHant", to: &doc)

                let texts = doc.textAttachments ?? []
                let tables = doc.tableAttachments ?? []
                var items: [(page: Int, y: CGFloat, height: CGFloat, name: String)] = []
                for t in texts { items.append((t.pageIndex, t.y, t.height, t.text)) }
                for t in tables { items.append((t.pageIndex, t.y, t.resolvedLayout().height, "table")) }

                let byPage = Dictionary(grouping: items, by: \.page)
                for (page, pageItems) in byPage {
                    let sorted = pageItems.sorted { $0.y < $1.y }
                    for i in 0 ..< sorted.count - 1 {
                        let current = sorted[i]
                        let next = sorted[i + 1]
                        XCTAssertLessThanOrEqual(
                            current.y + current.height, next.y + 0.5,
                            "\(paperId) 的 \(kind.rawValue) 版本在第 \(page) 頁文字重疊：'\(current.name.prefix(10))' (bottom: \(current.y + current.height)) 壓到 '\(next.name.prefix(10))' (top: \(next.y))"
                        )
                    }
                }
            }
        }
    }

    func testApplyingDocumentTemplateOnLinedPaperNeverOverlaps() throws {
        let tmpl = try XCTUnwrap(DocumentTemplateCatalog.template(id: "meeting_minutes"))
        var doc = NotebookDocument(title: "會議紀錄", pageCount: 1)
        doc.template = .lined
        DocumentTemplateCatalog.apply(tmpl, kind: .example, language: "zhHant", to: &doc)

        let texts = doc.textAttachments ?? []
        let tables = doc.tableAttachments ?? []
        var items: [(page: Int, y: CGFloat, height: CGFloat, name: String)] = []
        for t in texts { items.append((t.pageIndex, t.y, t.height, t.text)) }
        for t in tables { items.append((t.pageIndex, t.y, t.resolvedLayout().height, "table")) }

        let byPage = Dictionary(grouping: items, by: \.page)
        for (page, pageItems) in byPage {
            let sorted = pageItems.sorted { $0.y < $1.y }
            for i in 0 ..< sorted.count - 1 {
                let current = sorted[i]
                let next = sorted[i + 1]
                XCTAssertLessThanOrEqual(
                    current.y + current.height, next.y + 0.5,
                    "會議紀錄在第 \(page) 頁文字重疊：'\(current.name.prefix(10))' 壓到 '\(next.name.prefix(10))'"
                )
            }
        }
    }

    func testTableCellCountMatchesItsShape() {
        // cells 的長度必須剛好是 rows × cols —— 少一格的話核心的版面計算
        // 會讀到越界的索引。
        for theme in DocumentTemplateCatalog.themes {
            for category in theme.categories {
                for tmpl in category.templates {
                    for kind in DocumentTemplateCatalog.Variantkind.allCases {
                        guard let variant = DocumentTemplateCatalog.variant(
                            tmpl, kind: kind, language: "zhHant") else { continue }
                        for block in variant.blocks where block.kind == "table" {
                            XCTAssertEqual(
                                block.cells.count, block.rows * block.cols,
                                "\(tmpl.id) 的表格格數與列欄數對不上")
                        }
                    }
                }
            }
        }
    }
}

final class PageZoomTargetTests: XCTestCase {
    private let page = CGSize(width: 800, height: 1132)

    func testFitPageUsesTheTighterDimension() {
        // 視窗又寬又矮：高度是限制
        let wide = PageViewportLayout.zoomScale(for: .fitPage, viewport: CGSize(width: 1_600, height: 566), page: page)
        XCTAssertEqual(wide, 0.5, accuracy: 0.001)
        // 視窗又窄又高：寬度是限制
        let narrow = PageViewportLayout.zoomScale(for: .fitPage, viewport: CGSize(width: 400, height: 3_000), page: page)
        XCTAssertEqual(narrow, 0.5, accuracy: 0.001)
    }

    func testFitWidthIgnoresHeight() {
        let scale = PageViewportLayout.zoomScale(for: .fitWidth, viewport: CGSize(width: 400, height: 100), page: page)
        XCTAssertEqual(scale, 0.5, accuracy: 0.001)
    }

    func testRatioIsClampedToTheAllowedRange() {
        let tooBig = PageViewportLayout.zoomScale(for: .ratio(50), viewport: CGSize(width: 800, height: 600), page: page, range: 0.5...3)
        XCTAssertEqual(tooBig, 3)
        let tooSmall = PageViewportLayout.zoomScale(for: .ratio(0.01), viewport: CGSize(width: 800, height: 600), page: page, range: 0.5...3)
        XCTAssertEqual(tooSmall, 0.5)
    }

    func testDegenerateViewportFallsBackToActualSize() {
        XCTAssertEqual(PageViewportLayout.zoomScale(for: .fitPage, viewport: .zero, page: page), 1)
    }
}

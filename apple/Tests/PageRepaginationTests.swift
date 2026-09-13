//
//  PageRepaginationTests.swift
//  KairumoTests
//
//  把舊版的可延長頁面切成固定高度的頁。
//
//  這一批測試釘的是**內容不能在重新分頁的過程中消失或錯位**。
//  頁次算錯一頁不會當掉、不會有錯誤訊息，只會讓使用者發現「我的圖跑到別頁了」。
//

import XCTest
import PencilKit
@testable import Kairumo

final class PageRepaginationTests: XCTestCase {

    private func stroke(atY y: CGFloat) -> PKStroke {
        var points: [PKStrokePoint] = []
        for i in 0..<6 {
            points.append(PKStrokePoint(
                location: CGPoint(x: 100 + CGFloat(i) * 5, y: y + CGFloat(i)),
                timeOffset: Double(i) * 0.008,
                size: CGSize(width: 4, height: 4),
                opacity: 1, force: 1, azimuth: 1, altitude: 1.2))
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
    }

    /// 一本舊版筆記：第一頁被拉長到三頁高。
    private func longNotebook() -> (NotebookDocument, [PKDrawing]) {
        var doc = NotebookDocument(
            id: "long", title: "舊版長頁", pageCount: 1,
            textAttachments: [
                NoteTextAttachment(pageIndex: 0, text: "第一頁", x: 50, y: 100),
                NoteTextAttachment(pageIndex: 0, text: "第二頁", x: 50, y: PageGeometry.height + 200),
                NoteTextAttachment(pageIndex: 0, text: "第三頁", x: 50, y: PageGeometry.height * 2 + 300)
            ]
        )
        doc.pageHeights = [PageGeometry.height * 3]

        let drawing = PKDrawing(strokes: [
            stroke(atY: 100),
            stroke(atY: PageGeometry.height + 200),
            stroke(atY: PageGeometry.height * 2 + 300)
        ])
        return (doc, [drawing])
    }

    // MARK: - 判斷

    func testAFittingNotebookIsLeftAlone() {
        let doc = NotebookDocument(id: "fine", title: "正常", pageCount: 2)
        XCTAssertFalse(PageRepagination.needsRepagination(doc))
    }

    func testALongPageIsDetected() {
        XCTAssertTrue(PageRepagination.needsRepagination(longNotebook().0))
    }

    func testSplitCountRoundsUp() {
        var doc = NotebookDocument(id: "x", title: "x", pageCount: 1)
        doc.pageHeights = [PageGeometry.height * 2 + 10]   // 略超過兩頁
        XCTAssertEqual(PageRepagination.splitCount(forPage: 0, in: doc), 3,
                       "多出來的 10pt 也要有自己的一頁，否則那部分內容會被丟掉")
    }

    func testPageOffsetsAreComputedUpFront() {
        // 邊搬邊算的話，後面的頁次會被前面剛插入的頁影響，錯位一頁就整本亂掉。
        var doc = NotebookDocument(id: "x", title: "x", pageCount: 3)
        doc.pageHeights = [PageGeometry.height * 2, PageGeometry.height, PageGeometry.height * 3]
        XCTAssertEqual(PageRepagination.pageOffsets(in: doc), [0, 2, 3])
    }

    // MARK: - 內容不能消失

    func testEveryStrokeSurvives() {
        let (doc, drawings) = longNotebook()
        let before = drawings.reduce(0) { $0 + $1.strokes.count }
        let result = PageRepagination.repaginate(doc, drawings: drawings)
        let after = result.drawings.reduce(0) { $0 + $1.strokes.count }
        XCTAssertEqual(after, before, "重新分頁不能弄丟筆畫")
    }

    func testEveryObjectSurvives() {
        let (doc, drawings) = longNotebook()
        let result = PageRepagination.repaginate(doc, drawings: drawings)
        XCTAssertEqual(
            PageRepagination.objectCount(result.document),
            PageRepagination.objectCount(doc))
    }

    // MARK: - 位置要對

    func testObjectsLandOnTheRightPage() {
        let (doc, drawings) = longNotebook()
        let result = PageRepagination.repaginate(doc, drawings: drawings)
        let texts = result.document.textAttachments!.sorted { $0.pageIndex < $1.pageIndex }

        XCTAssertEqual(texts.map(\.pageIndex), [0, 1, 2])
        XCTAssertEqual(texts[0].text, "第一頁")
        XCTAssertEqual(texts[1].text, "第二頁")
        XCTAssertEqual(texts[2].text, "第三頁")
    }

    func testObjectYIsRelativeToItsNewPage() {
        // 沒有把 y 減掉整頁高度的話，物件會落在新頁面的下方很遠處 ——
        // 也就是頁面之外，使用者看起來就是「不見了」。
        let (doc, drawings) = longNotebook()
        let result = PageRepagination.repaginate(doc, drawings: drawings)
        for text in result.document.textAttachments! {
            XCTAssertLessThan(text.y, PageGeometry.height, "\(text.text) 的 y 超出頁面")
            XCTAssertGreaterThanOrEqual(text.y, 0)
        }
        XCTAssertEqual(result.document.textAttachments![1].y, 200, accuracy: 0.5)
    }

    func testStrokesLandOnTheRightPage() {
        let (doc, drawings) = longNotebook()
        let result = PageRepagination.repaginate(doc, drawings: drawings)
        XCTAssertEqual(result.drawings.count, 3)
        for (index, page) in result.drawings.enumerated() {
            XCTAssertEqual(page.strokes.count, 1, "第 \(index + 1) 頁應該正好有一筆")
        }
    }

    func testStrokeCoordinatesAreRelativeToTheNewPage() {
        let (doc, drawings) = longNotebook()
        let result = PageRepagination.repaginate(doc, drawings: drawings)
        for (index, page) in result.drawings.enumerated() {
            let minY = page.strokes.first!.renderBounds.minY
            XCTAssertLessThan(minY, PageGeometry.height, "第 \(index + 1) 頁的筆畫超出頁面")
            XCTAssertGreaterThanOrEqual(minY, -10)
        }
    }

    // MARK: - 頁數

    func testPageCountAndHeightsAreRewritten() {
        let (doc, drawings) = longNotebook()
        let result = PageRepagination.repaginate(doc, drawings: drawings)
        XCTAssertEqual(result.document.pageCount, 3)
        XCTAssertEqual(result.document.pageHeights, Array(repeating: PageGeometry.height, count: 3))
    }

    func testLaterPagesShiftDown() {
        // 第一頁被切成三頁之後，原本的第二頁要變成第四頁。漏掉這個平移，
        // 兩頁的內容會疊在一起。
        var doc = NotebookDocument(
            id: "shift", title: "位移", pageCount: 2,
            textAttachments: [NoteTextAttachment(pageIndex: 1, text: "原本的第二頁", x: 10, y: 50)]
        )
        doc.pageHeights = [PageGeometry.height * 3, PageGeometry.height]

        let result = PageRepagination.repaginate(doc, drawings: [PKDrawing(), PKDrawing()])
        XCTAssertEqual(result.document.textAttachments!.first!.pageIndex, 3)
        XCTAssertEqual(result.document.pageCount, 4)
    }

    // MARK: - 可重入

    func testRepaginatingTwiceChangesNothingTheSecondTime() {
        let (doc, drawings) = longNotebook()
        let once = PageRepagination.repaginate(doc, drawings: drawings)
        XCTAssertFalse(PageRepagination.needsRepagination(once.document),
                       "重新分頁完就不該再需要重新分頁")
    }
}

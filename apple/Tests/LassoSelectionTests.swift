//
//  LassoSelectionTests.swift
//  KairumoTests
//
//  套索：圈選、再製／貼上後選著新的一份、剪下原位貼回、露出圈外的筆畫也拖得到。
//

import PencilKit
import XCTest
@testable import Kairumo

@MainActor
final class LassoSelectionTests: XCTestCase {

    private func line(from a: CGPoint, to b: CGPoint) -> PKStroke {
        let points = (0...10).map { i -> PKStrokePoint in
            let t = CGFloat(i) / 10
            return PKStrokePoint(
                location: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t),
                timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: 3, height: 3),
                opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    /// 以 (x0,y0)-(x1,y1) 為範圍圈一圈。
    private func lassoRect(_ lasso: LassoSelection, _ r: CGRect, in drawing: PKDrawing) {
        lasso.begin(at: CGPoint(x: r.minX, y: r.minY))
        lasso.extend(to: CGPoint(x: r.maxX, y: r.minY))
        lasso.extend(to: CGPoint(x: r.maxX, y: r.maxY))
        lasso.extend(to: CGPoint(x: r.minX, y: r.maxY))
        lasso.finish(in: drawing)
    }

    private func sampleDrawing() -> PKDrawing {
        PKDrawing(strokes: [
            line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 100)),
            line(from: CGPoint(x: 500, y: 500), to: CGPoint(x: 600, y: 500)),
        ])
    }

    func testDuplicateSelectsTheNewCopy() throws {
        let lasso = LassoSelection()
        let drawing = sampleDrawing()
        lassoRect(lasso, CGRect(x: 80, y: 80, width: 140, height: 40), in: drawing)
        XCTAssertEqual(lasso.selected, IndexSet(integer: 0))

        let updated = try XCTUnwrap(lasso.duplicateSelected(in: drawing))
        XCTAssertEqual(updated.strokes.count, 3)
        // 選著再製出來的那一份，而不是清空選取。
        XCTAssertEqual(lasso.selected, IndexSet(integer: 2))
        let box = try XCTUnwrap(lasso.boundingRect)
        XCTAssertTrue(box.contains(updated.strokes[2].renderBounds.center))

        // 馬上就能拖：在選取框內落下就是拖曳，不是重新圈。
        lasso.begin(at: box.center)
        XCTAssertTrue(lasso.isDraggingSelection)
    }

    func testCutThenPasteRestoresInPlaceAndSelects() throws {
        let lasso = LassoSelection()
        let drawing = sampleDrawing()
        lassoRect(lasso, CGRect(x: 80, y: 80, width: 140, height: 40), in: drawing)
        let original = drawing.strokes[0].renderBounds

        let afterCut = try XCTUnwrap(lasso.cutSelected(from: drawing))
        XCTAssertEqual(afterCut.strokes.count, 1)
        XCTAssertFalse(lasso.hasSelection)
        XCTAssertTrue(lasso.canPaste, "剪下後要有東西可貼")

        let afterPaste = try XCTUnwrap(lasso.paste(into: afterCut))
        XCTAssertEqual(afterPaste.strokes.count, 2)
        XCTAssertEqual(afterPaste.strokes[1].renderBounds.minX, original.minX, accuracy: 0.5)
        XCTAssertEqual(lasso.selected, IndexSet(integer: 1))
    }

    func testCopyThenPasteIsOffsetAndSelected() throws {
        let lasso = LassoSelection()
        let drawing = sampleDrawing()
        lassoRect(lasso, CGRect(x: 80, y: 80, width: 140, height: 40), in: drawing)
        lasso.copySelected(from: drawing)
        let pasted = try XCTUnwrap(lasso.paste(into: drawing))
        XCTAssertEqual(pasted.strokes.count, 3)
        XCTAssertGreaterThan(pasted.strokes[2].renderBounds.minX, drawing.strokes[0].renderBounds.minX)
        XCTAssertEqual(lasso.selected, IndexSet(integer: 2))
    }

    func testStrokePokingOutOfLoopIsDraggable() throws {
        let lasso = LassoSelection()
        // 一條長線，圈只圈到大半段。
        let drawing = PKDrawing(strokes: [line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 100))])
        lassoRect(lasso, CGRect(x: 90, y: 80, width: 160, height: 40), in: drawing)
        XCTAssertTrue(lasso.hasSelection)
        // 在圈外、但在筆畫上的那一段落下 → 要是拖曳，不是重圈（以前會把選取清掉）。
        lasso.begin(at: CGPoint(x: 295, y: 100))
        XCTAssertTrue(lasso.isDraggingSelection)
    }

    func testMoveSelectedBakesTranslationAndUpdatesStrokeDelta() throws {
        let lasso = LassoSelection()
        let drawing = sampleDrawing()
        lassoRect(lasso, CGRect(x: 80, y: 80, width: 140, height: 40), in: drawing)
        XCTAssertEqual(lasso.selected, IndexSet(integer: 0))

        let originalFirst = drawing.strokes[0]
        let originalIdentity = StrokeDelta.Identity(originalFirst)

        let movedDrawing = try XCTUnwrap(lasso.moveSelected(in: drawing, by: CGSize(width: 50, height: 80)))
        XCTAssertEqual(movedDrawing.strokes.count, 2)

        let movedFirst = movedDrawing.strokes[0]
        let movedIdentity = StrokeDelta.Identity(movedFirst)

        // 1. 移動後筆畫之路徑點與 renderBounds 應確實位移
        XCTAssertEqual(movedFirst.renderBounds.minX, originalFirst.renderBounds.minX + 50, accuracy: 1.0)
        XCTAssertEqual(movedFirst.renderBounds.minY, originalFirst.renderBounds.minY + 80, accuracy: 1.0)
        XCTAssertEqual(movedFirst.transform, .identity, "位移應直接烘焙至 controlPoints 形成新 PKStrokePath")

        // 2. StrokeDelta.Identity 必須反映位移，不可因忽略 transform 或未烘焙而重複
        XCTAssertNotEqual(movedIdentity, originalIdentity, "位移後的身分識別值必須不同")

        // 3. StrokeDelta 比對：原筆畫應被視為 removed，位移後筆畫應被視為 added
        let added = StrokeDelta.added(in: movedDrawing, since: drawing)
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added[0].renderBounds.minX, movedFirst.renderBounds.minX, accuracy: 0.5)

        let removed = StrokeDelta.removed(in: movedDrawing, since: drawing)
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed[0].renderBounds.minX, originalFirst.renderBounds.minX, accuracy: 0.5)

        // 4. InkMerge 三方合併：以移動前原稿為 base，位移後筆畫應被保留，原位筆畫被移除
        let diskWithOnlyUnmoved = drawing
        let merged = InkMerge.merged(disk: diskWithOnlyUnmoved, local: movedDrawing, base: drawing)
        XCTAssertEqual(merged.strokes.count, 2)
        XCTAssertTrue(merged.strokes.contains(where: { abs($0.renderBounds.minX - movedFirst.renderBounds.minX) < 1.0 }),
                      "合併後必須包含位移後的筆畫")
        XCTAssertFalse(merged.strokes.contains(where: { abs($0.renderBounds.minX - originalFirst.renderBounds.minX) < 1.0 }),
                       "合併後不可保留位移前的原筆畫")

        // 5. 驗證防消失機制：若本地畫了新字，即使 base 樂觀超前設為 local，未落盤之新筆畫仍應完整保留而不被舊 disk 吞噬
        let newStroke = line(from: CGPoint(x: 300, y: 300), to: CGPoint(x: 400, y: 300))
        let drawingWithNew = PKDrawing(strokes: drawing.strokes + [newStroke])
        let mergedNew = InkMerge.merged(disk: drawing, local: drawingWithNew, base: drawingWithNew)
        XCTAssertEqual(mergedNew.strokes.count, 3, "本地新寫的筆畫絕不可被舊 disk 吞噬")
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

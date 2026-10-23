//
//  CanvasHistoryTests.swift
//  KairumoTests
//
//  全域復原：物件操作與筆跡在同一條時間軸上，照發生順序退回。
//

import XCTest
@testable import Kairumo

final class CanvasHistoryTests: XCTestCase {

    private var doc = NotebookDocument(title: "t")
    private var history = CanvasObjectHistory()
    private var manager = UndoManager()

    override func setUp() {
        super.setUp()
        doc = NotebookDocument(title: "t")
        doc.attachments = [NoteImageAttachment(fileName: "a.png", pageIndex: 0, x: 10, y: 10, width: 100, height: 100)]
        doc.textAttachments = [NoteTextAttachment(id: "t1", pageIndex: 0, text: "", x: 0, y: 0)]
        history = CanvasObjectHistory()
        manager = UndoManager()
        manager.groupsByEvent = false
        history.reset(to: doc)
    }

    /// 模擬編輯器的 `commitNotebook()`：一次使用者動作一個復原群組。
    private func commit(_ change: (inout NotebookDocument) -> Void) {
        change(&doc)
        manager.beginUndoGrouping()
        history.record(doc, manager: manager) { [unowned self] state in state.apply(to: &self.doc) }
        manager.endUndoGrouping()
    }

    private var imageX: CGFloat { doc.attachments?.first?.x ?? -1 }

    /// 與編輯器的 `stepHistory` 相同：跳過沒有效果的項目（空群組）。
    /// 這裡每次 commit 都明確開關一個群組；被合併的那幾次會留下空群組 ——
    /// App 裡 UIKit 只在有登記時才開群組，但編輯器的復原同樣會跳過它們。
    private func stepUndo() {
        for _ in 0..<12 where manager.canUndo {
            let applied = history.appliedCount
            manager.undo()
            if history.appliedCount != applied { return }
        }
    }

    func testMovingAnImageIsUndoableAndRedoable() {
        commit { $0.attachments?[0].x = 200 }
        XCTAssertTrue(manager.canUndo)
        manager.undo()
        XCTAssertEqual(imageX, 10, "復原要把圖搬回原位")
        manager.redo()
        XCTAssertEqual(imageX, 200, "重做要再搬過去")
    }

    func testDeletingAndAddingObjectsAreUndoable() {
        commit { $0.tableAttachments = [NoteTableAttachment(pageIndex: 0, x: 0, y: 0, rows: 2, cols: 2)] }
        commit { $0.attachments = [] }
        manager.undo()
        XCTAssertEqual(doc.attachments?.count, 1, "刪掉的圖要回來")
        manager.undo()
        XCTAssertTrue(doc.tableAttachments?.isEmpty ?? true, "新增的表格要拿掉")
    }

    func testTypingInOneBoxBecomesOneStep() {
        // 打一句話不能要按幾十次復原。
        for text in ["H", "He", "Hel", "Hell", "Hello"] {
            commit { $0.textAttachments?[0].text = text }
        }
        stepUndo()
        XCTAssertEqual(doc.textAttachments?[0].text, "", "一次復原退回打字前")
        let before = doc.textAttachments?[0].text
        stepUndo()
        XCTAssertEqual(doc.textAttachments?[0].text, before, "沒有更早的步驟了")
    }

    func testChangesToDifferentObjectsAreSeparateSteps() {
        commit { $0.textAttachments?[0].text = "A" }
        commit { $0.attachments?[0].x = 50 }
        manager.undo()
        XCTAssertEqual(imageX, 10)
        XCTAssertEqual(doc.textAttachments?[0].text, "A", "只退一步")
    }

    func testAnExplicitNewActionIsNotMergedIntoTheLastOne() {
        commit { $0.attachments?[0].x = 20 }
        history.breakCoalescing()
        commit { $0.attachments?[0].x = 30 }
        manager.undo()
        XCTAssertEqual(imageX, 20)
    }

    func testObjectAndInkStepsUndoInTheOrderTheyHappened() {
        // 筆跡（PencilKit）登記在同一個 manager 上；這裡用一個假的筆跡項目代表。
        var strokes = 0
        func drawStroke() {
            strokes += 1
            history.breakCoalescing() // 編輯器在筆跡變動時會這樣通知
            manager.beginUndoGrouping()
            manager.registerUndo(withTarget: self) { _ in strokes -= 1 }
            manager.endUndoGrouping()
        }
        drawStroke()
        commit { $0.attachments?[0].x = 99 }
        drawStroke()

        manager.undo()
        XCTAssertEqual(strokes, 1, "第一次復原退掉最後一筆")
        XCTAssertEqual(imageX, 99)
        manager.undo()
        XCTAssertEqual(imageX, 10, "第二次復原退掉搬圖")
        XCTAssertEqual(strokes, 1)
        manager.undo()
        XCTAssertEqual(strokes, 0, "第三次復原退掉第一筆")
    }

    func testObjectStepsAreNamedSoInkCleanupCanTellThemApart() {
        commit { $0.attachments?[0].x = 1 }
        XCTAssertEqual(manager.undoActionName, CanvasObjectHistory.actionName)
    }

    func testRemoteChangesAreNotRecorded() {
        // 別台送來的修改不是這台使用者的動作 —— 按復原不能把別人的修改退掉。
        history.withoutRecording {
            doc.attachments?[0].x = 500
            history.record(doc, manager: manager) { _ in }
        }
        XCTAssertFalse(manager.canUndo)
        commit { $0.attachments?[0].y = 70 }
        manager.undo()
        XCTAssertEqual(imageX, 500, "復原只退本機的那一步，別台的位置保留")
    }

    func testPageStructureChangesDropObjectSteps() {
        // 頁面增刪之後，舊紀錄裡的頁次對不上：復原會把物件放回不存在的頁。
        commit { $0.attachments?[0].x = 42 }
        commit {
            $0.pageCount += 1
            $0.pagesData.append(Data())
        }
        // UndoManager 會留下空群組（canUndo 仍為真），編輯器的復原會跳過它；
        // 這裡要確認的是：照實復原也不會把圖搬回去。
        // 有上限：作廢後留下的空群組會讓 canUndo 一直是真（編輯器的復原同樣有上限）。
        for _ in 0..<20 where manager.canUndo { manager.undo() }
        XCTAssertEqual(imageX, 42)
    }

    func testUndoClearsTheRedoTrailOnANewChange() {
        commit { $0.attachments?[0].x = 1 }
        manager.undo()
        commit { $0.attachments?[0].y = 2 }
        XCTAssertFalse(manager.canRedo)
    }
    // MARK: - 鎖定在畫布上

    func testObjectLockIsGlobalLookupAndUnlockClearsEveryPage() {
        var d = NotebookDocument(title: "lock")
        d.setLockedObjectIds(["b", "a"], forPage: 2)
        d.setLockedObjectIds(["x"], forPage: 0)
        XCTAssertEqual(d.lockedObjectIdsByPage?["2"], ["a", "b"], "排序寫出，與 Android 同一份內容")
        XCTAssertEqual(d.allLockedObjectIds, ["a", "b", "x"])
        d.setLockedObjectIds([], forPage: 0)
        XCTAssertNil(d.lockedObjectIdsByPage?["0"], "空的那一頁要拿掉")
        d.setLockedObjectIds([], forPage: 2)
        XCTAssertNil(d.lockedObjectIdsByPage, "全部解除之後跟沒鎖過一樣")
    }

    func testObjectLockRoundTripsThroughPackageMeta() {
        var d = NotebookDocument(title: "lock")
        d.setLockedObjectIds(["t1"], forPage: 0)
        var restored = NotebookDocument(title: "lock")
        NotebookMeta.decode(from: NotebookMeta(from: d).encodedJSON())?.apply(to: &restored)
        XCTAssertEqual(restored.allLockedObjectIds, ["t1"])
        XCTAssertTrue(NotebookMeta(from: d).encodedJSON().contains("\"lockedObjectIdsByPage\""),
                      "鍵名要與 Android NotebookMeta.KEY_LOCKED_BY_PAGE 一致")
    }

    func testLockingIsOneUndoStep() {
        commit { $0.setLockedObjectIds(["t1"], forPage: 0) }
        XCTAssertEqual(doc.allLockedObjectIds, ["t1"])
        stepUndo()
        XCTAssertTrue(doc.allLockedObjectIds.isEmpty, "復原要能把鎖定退回")
    }

}

/// 框選的選取規則：一般／連續框選、點選切換、最上層命中。與 Android 端 `MarqueeSelectionTest` 對應。
final class MarqueeSelectionTests: XCTestCase {

    func testANewMarqueeReplacesTheSelectionByDefault() {
        XCTAssertEqual(ObjectMarquee.combined(["a"], with: ["b"], additive: false), ["b"])
    }

    func testContinuousMarqueeAccumulates() {
        XCTAssertEqual(ObjectMarquee.combined(["a"], with: ["b"], additive: true), ["a", "b"])
    }

    func testTappingTogglesInContinuousMode() {
        XCTAssertEqual(ObjectMarquee.tapped("b", existing: ["a"], additive: true), ["a", "b"])
        XCTAssertEqual(ObjectMarquee.tapped("b", existing: ["a", "b"], additive: true), ["a"])
    }

    func testTappingSelectsOnlyThatObjectNormally() {
        XCTAssertEqual(ObjectMarquee.tapped("b", existing: ["a"], additive: false), ["b"])
    }

    func testTappingBlankClearsNormallyButKeepsAccumulatedSelection() {
        XCTAssertEqual(ObjectMarquee.tapped(nil, existing: ["a"], additive: false), [])
        XCTAssertEqual(ObjectMarquee.tapped(nil, existing: ["a"], additive: true), ["a"])
    }

    func testTopmostHitPrefersTheObjectOnTop() {
        let below = MarqueeHit(id: "below", kind: .image, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let above = MarqueeHit(id: "above", kind: .text, frame: CGRect(x: 50, y: 50, width: 100, height: 100))
        XCTAssertEqual(ObjectMarquee.topmostHit(at: CGPoint(x: 60, y: 60), among: [below, above]), "above")
        XCTAssertEqual(ObjectMarquee.topmostHit(at: CGPoint(x: 10, y: 10), among: [below, above]), "below")
        XCTAssertNil(ObjectMarquee.topmostHit(at: CGPoint(x: 500, y: 500), among: [below, above]))
    }

    func testPasteOriginsDefaultOffsetAndArbitraryTargetPoint() {
        let f1 = CGRect(x: 100, y: 120, width: 160, height: 80)
        let f2 = CGRect(x: 300, y: 200, width: 140, height: 100)

        let defaultOrigins = ObjectMarquee.pasteOrigins(frames: [f1, f2], targetPoint: nil)
        XCTAssertEqual(defaultOrigins.count, 2)
        XCTAssertEqual(defaultOrigins[0], CGPoint(x: 124, y: 144))
        XCTAssertEqual(defaultOrigins[1], CGPoint(x: 324, y: 224))

        // 單一物件貼到任意座標 (400, 600)：中心對齊 (400, 600) → 左上角 (320, 560)
        let singleAtTarget = ObjectMarquee.pasteOrigins(frames: [f1], targetPoint: CGPoint(x: 400, y: 600))
        XCTAssertEqual(singleAtTarget, [CGPoint(x: 320, y: 560)])

        // 多物件整組貼到任意座標 (420, 510)：聯集 (100..440, 120..300) 中心為 (270, 210)，平移 (+150, +300)
        let groupAtTarget = ObjectMarquee.pasteOrigins(frames: [f1, f2], targetPoint: CGPoint(x: 420, y: 510))
        XCTAssertEqual(groupAtTarget[0], CGPoint(x: 250, y: 420))
        XCTAssertEqual(groupAtTarget[1], CGPoint(x: 450, y: 500))
    }

    func testPastedInstantiatesAcrossPagesAndPreservesAllFields() {
        var text = NoteTextAttachment(
            id: "orig-text",
            pageIndex: 0,
            text: "跨頁貼上測試",
            fontSize: 20,
            isBold: true,
            isItalic: true,
            x: 80,
            y: 100,
            width: 200,
            height: 80
        )
        text.fontFamily = "Georgia"
        text.rotationDegrees = 15

        var shape = NoteShapeAttachment(
            id: "orig-shape",
            pageIndex: 0,
            kindName: "decision",
            x: 120,
            y: 260,
            width: 140,
            height: 90,
            label: "流程",
            strokeColorHex: "#FF5722",
            fillColorHex: "#FFF3E0",
            lineWidth: 3,
            groupId: "g1"
        )
        shape.dashStyle = "dashed"
        shape.opacity = 0.8

        let pasted = ObjectMarquee.pasted(
            [.text(text), .shape(shape)],
            onPage: 2,
            at: CGPoint(x: 400, y: 500)
        )
        XCTAssertEqual(pasted.count, 2)
        guard case .text(let pastedText) = pasted[0],
              case .shape(let pastedShape) = pasted[1] else {
            return XCTFail("Expected text and shape")
        }
        XCTAssertNotEqual(pastedText.id, text.id)
        XCTAssertEqual(pastedText.pageIndex, 2)
        XCTAssertEqual(pastedText.text, "跨頁貼上測試")
        XCTAssertEqual(pastedText.fontFamily, "Georgia")
        XCTAssertEqual(pastedText.rotationDegrees, 15)

        XCTAssertNotEqual(pastedShape.id, shape.id)
        XCTAssertEqual(pastedShape.pageIndex, 2)
        XCTAssertEqual(pastedShape.kindName, "decision")
        XCTAssertEqual(pastedShape.dashStyle, "dashed")
        XCTAssertEqual(pastedShape.opacity, 0.8)
        XCTAssertNil(pastedShape.groupId)
    }
}

//
//  EditorStateMachineTests.swift
//  KairumoTests
//
//  Created for Kairumo Architecture Enhancement Plan (Phase 3).
//  模式狀態機與轉場協調器單元測試：釘住編輯模式切換、Apple Pencil 守衛規則、表格與文字編輯焦點。
//

import XCTest
@testable import Kairumo

@MainActor
final class EditorStateMachineTests: XCTestCase {

    func testInitialStateIsDraw() {
        let sm = EditorStateMachine()
        XCTAssertEqual(sm.currentMode, .draw)
        XCTAssertEqual(sm.phase, .drawing)
        XCTAssertTrue(sm.isInkDrawingAllowed)
        XCTAssertFalse(sm.isCanvasTapCreatesText)
    }

    func testSwitchToTypeMode() {
        let sm = EditorStateMachine()
        let didSwitch = sm.setMode(.type)
        XCTAssertTrue(didSwitch)
        XCTAssertEqual(sm.currentMode, .type)
        XCTAssertFalse(sm.isInkDrawingAllowed)
        XCTAssertTrue(sm.isCanvasTapCreatesText)
    }

    func testInlineInkBlockTemporarilyEnablesCanvasWhileMainModeStaysType() {
        XCTAssertEqual(
            EditorCanvasInputPolicy.effectiveMode(
                mainMode: .type, isInlineInkEditing: true),
            .draw
        )
        XCTAssertTrue(
            EditorCanvasInputPolicy.acceptsInk(
                mainMode: .type, isInlineInkEditing: true)
        )
    }

    func testPlainTypeModeStillLocksCanvasInk() {
        XCTAssertEqual(
            EditorCanvasInputPolicy.effectiveMode(
                mainMode: .type, isInlineInkEditing: false),
            .type
        )
        XCTAssertFalse(
            EditorCanvasInputPolicy.acceptsInk(
                mainMode: .type, isInlineInkEditing: false)
        )
    }

    func testFusionInputPolicyInvariants() {
        // 任何模式下繪圖手勢皆保持啟用，杜絕切換第一筆遺失問題
        XCTAssertTrue(EditorCanvasInputPolicy.drawingGestureEnabled(effectiveMode: .draw))
        XCTAssertTrue(EditorCanvasInputPolicy.drawingGestureEnabled(effectiveMode: .type))

        // 打字模式下手指不可繪圖（交由物件選取/捲動）
        XCTAssertEqual(EditorCanvasInputPolicy.fingerMayDraw(effectiveMode: .type), false)
        XCTAssertNil(EditorCanvasInputPolicy.fingerMayDraw(effectiveMode: .draw))

        // 打字模式下延遲判定 Apple Pencil 意圖（區分點擊與書寫筆劃）
        XCTAssertTrue(EditorCanvasInputPolicy.defersPencilIntent(effectiveMode: .type))
        XCTAssertFalse(EditorCanvasInputPolicy.defersPencilIntent(effectiveMode: .draw))

        // 判定 Pencil 輕點 vs 筆畫
        let tap = EditorCanvasInputPolicy.classifyPencil(distance: 2, duration: 0.1)
        XCTAssertEqual(tap, .tap)

        let strokeByDistance = EditorCanvasInputPolicy.classifyPencil(distance: 12, duration: 0.1)
        XCTAssertEqual(strokeByDistance, .stroke)

        let strokeByDuration = EditorCanvasInputPolicy.classifyPencil(distance: 2, duration: 0.6)
        XCTAssertEqual(strokeByDuration, .stroke)
    }

    func testPencilTouchGuardInTypeMode() {
        let sm = EditorStateMachine()
        sm.setMode(.type)

        // 核心守衛：在打字模式下，Pencil 碰觸畫布絕不能作為手寫筆跡（不能自動跳回 .draw）
        let shouldDraw = sm.handlePencilTouch()
        XCTAssertFalse(shouldDraw, "打字模式下 Pencil 觸碰應回傳 false，不可繪製筆跡")
        XCTAssertEqual(sm.currentMode, .type, "模式必須維持在 .type，不可被靜默篡改")
    }

    func testPencilTouchAllowedInDrawMode() {
        let sm = EditorStateMachine()
        XCTAssertEqual(sm.currentMode, .draw)

        let shouldDraw = sm.handlePencilTouch()
        XCTAssertTrue(shouldDraw, "手繪模式下 Pencil 觸碰應回傳 true")
        XCTAssertEqual(sm.currentMode, .draw)
    }

    func testTextEditingLifecycle() {
        let sm = EditorStateMachine()
        let testId = UUID()

        sm.beginTextEditing(id: testId)
        XCTAssertEqual(sm.currentMode, .type, "開始文字編輯應自動確保處於 .type 模式")
        XCTAssertEqual(sm.activeTextId, testId)
        XCTAssertEqual(sm.phase, .typing(activeTextId: testId))

        sm.endTextEditing()
        XCTAssertNil(sm.activeTextId)
        XCTAssertEqual(sm.phase, .typing(activeTextId: nil))
    }

    func testSwitchingFromTypeToDrawClearsActiveSelection() {
        let sm = EditorStateMachine()
        let testId = UUID()

        sm.beginTextEditing(id: testId)
        XCTAssertEqual(sm.activeTextId, testId)

        sm.setMode(.draw)
        XCTAssertNil(sm.activeTextId, "切換回手繪模式時應自動清除文字焦點")
        XCTAssertEqual(sm.currentMode, .draw)
        XCTAssertEqual(sm.phase, .drawing)
    }

    func testTableCellSelectionLifecycle() {
        let sm = EditorStateMachine()
        sm.selectTableCell(row: 1, col: 2)

        XCTAssertEqual(sm.activeTableCell, TableCellCoordinate(row: 1, col: 2))
        XCTAssertEqual(sm.phase, .selecting)

        sm.clearAllSelection()
        XCTAssertNil(sm.activeTableCell)
        XCTAssertEqual(sm.phase, .drawing)
    }

    func testModalStudioDisablesInkDrawing() {
        let sm = EditorStateMachine()
        XCTAssertTrue(sm.isInkDrawingAllowed)

        sm.isModalActive = true
        XCTAssertFalse(sm.isInkDrawingAllowed, "次級視窗開啟時應鎖定畫布墨水繪製")
        XCTAssertEqual(sm.phase, .modalStudio)

        sm.isModalActive = false
        XCTAssertTrue(sm.isInkDrawingAllowed)
        XCTAssertEqual(sm.phase, .drawing)
    }

    func testToggleMode() {
        let sm = EditorStateMachine()
        XCTAssertEqual(sm.currentMode, .draw)

        sm.toggleMode()
        XCTAssertEqual(sm.currentMode, .type)

        sm.toggleMode()
        XCTAssertEqual(sm.currentMode, .draw)
    }

    func testTextAndTableFocusMutualExclusion() {
        let sm = EditorStateMachine()
        let testTextId = UUID()

        // 1. 開始文字輸入
        sm.beginTextEditing(id: testTextId)
        XCTAssertEqual(sm.activeTextId, testTextId)
        XCTAssertNil(sm.activeTableCell)

        // 2. 點選表格儲存格：文字焦點必須被自動清除，不發生焦點競爭
        sm.selectTableCell(row: 0, col: 1)
        XCTAssertNil(sm.activeTextId, "選取表格儲存格時，既有文字框焦點必須清除")
        XCTAssertEqual(sm.activeTableCell, TableCellCoordinate(row: 0, col: 1))

        // 3. 再次點選文字框：表格焦點必須被清除
        sm.beginTextEditing(id: testTextId)
        XCTAssertNil(sm.activeTableCell, "選取文字框時，既有表格儲存格焦點必須清除")
        XCTAssertEqual(sm.activeTextId, testTextId)
    }
}

@MainActor
final class SheetCoordinatorTests: XCTestCase {

    func testAllSheetDestinationsHaveUniqueIds() {
        let destinations: [SheetDestination] = [
            .assetLibrary,
            .stickerLibrary,
            .audioPicker,
            .photoPicker,
            .mathCalculator,
            .chartStudio,
            .tableStudio,
            .shapeStudio,
            .studio3D,
            .themeTools,
            .palmThreshold,
            .advancedPenSettings,
            .toolbarCustomization,
            .collaboration,
            .noteIntelligence,
            .exportPdf,
            .exportImage,
            .printNote
        ]

        let ids = destinations.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "所有 SheetDestination 必須具備唯一識別碼")
    }

    func testDirectPresentationAndDismissal() {
        let coordinator = SheetCoordinator()
        XCTAssertNil(coordinator.activeSheet)

        coordinator.presentDirectly(.tableStudio)
        XCTAssertEqual(coordinator.activeSheet, .tableStudio)

        coordinator.dismissAll()
        XCTAssertNil(coordinator.activeSheet)
        XCTAssertNil(coordinator.activeImportSlot)
        XCTAssertFalse(coordinator.isTransitioning)
    }

    func testTriggerFileImportFromMenu() {
        let coordinator = SheetCoordinator()
        coordinator.triggerFileImportFromMenu(.audio)
        XCTAssertTrue(coordinator.isTransitioning)
    }

    func testPresentFromMenuSetsTransitioning() {
        let coordinator = SheetCoordinator()
        coordinator.presentFromMenu(.mathCalculator)
        XCTAssertTrue(coordinator.isTransitioning)
    }

    func testSheetCoordinatorMultiPresentationSequencing() {
        let coordinator = SheetCoordinator()
        coordinator.presentDirectly(.tableStudio)
        XCTAssertEqual(coordinator.activeSheet, .tableStudio)

        // 重新直接開啟另一工作坊時，舊工作坊應立即替換
        coordinator.presentDirectly(.shapeStudio)
        XCTAssertEqual(coordinator.activeSheet, .shapeStudio)

        coordinator.dismissAll()
        XCTAssertNil(coordinator.activeSheet)
    }
}

extension EditorStateMachineTests {
    func testCrossPlatformInvariantsAcrossModes() {
        let sm = EditorStateMachine()

        // Draw 模式不變式
        XCTAssertTrue(sm.isInkDrawingAllowed)
        XCTAssertFalse(sm.isCanvasTapCreatesText)
        XCTAssertFalse(sm.isObjectDirectSelectionAllowed)

        // Type 模式不變式
        sm.setMode(.type)
        XCTAssertFalse(sm.isInkDrawingAllowed)
        XCTAssertTrue(sm.isCanvasTapCreatesText)
        XCTAssertTrue(sm.isObjectDirectSelectionAllowed)

        // 模態彈窗中不變式
        sm.isModalActive = true
        XCTAssertFalse(sm.isInkDrawingAllowed)
        XCTAssertFalse(sm.isCanvasTapCreatesText)
    }

    func testRapidModeTogglingPreservesStateConsistency() {
        let sm = EditorStateMachine()
        for i in 0..<20 {
            sm.toggleMode()
            if i % 2 == 0 {
                XCTAssertEqual(sm.currentMode, .type)
                XCTAssertFalse(sm.isInkDrawingAllowed)
            } else {
                XCTAssertEqual(sm.currentMode, .draw)
                XCTAssertTrue(sm.isInkDrawingAllowed)
            }
        }
    }
}


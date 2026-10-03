//
//  EditorStateMachine.swift
//  Kairumo
//
//  Created for Kairumo Architecture Enhancement Plan (Phase 1).
//  統一編輯器全域狀態機：解決手勢衝突、模式互搶、打字與手繪邊界模糊的根本架構元件。
//

import SwiftUI
import Combine

/// 筆記編輯主模式（手繪手寫 vs 鍵盤打字排版）
public enum EditorMode: String, CaseIterable, Identifiable, Sendable {
    case draw = "draw"
    case type = "type"

    public var id: String { rawValue }

    public var isDraw: Bool { self == .draw }
    public var isType: Bool { self == .type }
}

/// 主模式與情境式編輯共同決定畫布真正接收哪一種輸入。
///
/// 「手繪區塊」是打字文件中的局部手繪情境：頂層模式仍是 `.type`，但畫布
/// 必須暫時以 `.draw` 運作。把這條規則集中在這裡，避免工具列已經顯示手繪、
/// PencilKit 卻仍被打字模式鎖住的半套狀態。
enum EditorCanvasInputPolicy {
    static func effectiveMode(
        mainMode: EditorMode,
        isInlineInkEditing: Bool
    ) -> EditorMode {
        isInlineInkEditing ? .draw : mainMode
    }

    static func acceptsInk(
        mainMode: EditorMode,
        isInlineInkEditing: Bool
    ) -> Bool {
        effectiveMode(mainMode: mainMode, isInlineInkEditing: isInlineInkEditing) == .draw
    }

    // MARK: - 融合輸入規則（工作項 F1）
    //
    // 「模式」不是鎖，而是由手上拿的東西推斷出來的情境：
    // Apple Pencil 在**任何**模式都直接寫；打字模式只決定手指與鍵盤的行為。
    // 過去打字模式把 PencilKit 的落筆手勢整個關掉，落筆時才切回手繪 ——
    // 但進行中的觸控不會被中途啟用的手勢接手，於是**第一筆永遠遺失**。

    /// 畫布在這個模式下要不要開著落筆手勢。答案永遠是「要」：
    /// 打字模式靠 `fingerMayDraw == false` 擋住手指，而不是關掉整個手勢。
    // unused-param-ok: 融合輸入規格規定任何模式皆啟用落筆手勢，保留 effectiveMode 參數供簽名對齊與調試
    static func drawingGestureEnabled(effectiveMode: EditorMode) -> Bool { true }

    /// 手指能不能畫。打字模式下手指負責點選、捲動與物件操作，**絕對不畫**；
    /// 手繪模式交給掌拒協調器決定（`nil` 代表沿用協調器的判斷）。
    static func fingerMayDraw(effectiveMode: EditorMode) -> Bool? {
        effectiveMode == .type ? false : nil
    }

    /// 打字模式下 Pencil 的意圖要不要延後判定。
    ///
    /// 打字模式中，Pencil 輕點一下的意思是「放游標／開文字框」，畫下去才是「寫」。
    /// 落筆當下還分不出來，所以先讓墨水照常收，等筆離開時再決定：
    /// 是輕點就收回那顆墨點並照打字模式處理；是筆畫就把情境切到手繪。
    /// 切換一律在**筆畫結束後**才做 —— 筆畫進行中改畫布設定會讓這一筆被取消。
    static func defersPencilIntent(effectiveMode: EditorMode) -> Bool {
        effectiveMode == .type
    }

    enum PencilGesture: Equatable { case tap, stroke }

    /// 輕點的判準：移動距離小於 6pt、且停留不到 0.35 秒。
    static let pencilTapMaxDistance: CGFloat = 6
    static let pencilTapMaxDuration: TimeInterval = 0.35

    static func classifyPencil(distance: CGFloat, duration: TimeInterval) -> PencilGesture {
        (distance < pencilTapMaxDistance && duration < pencilTapMaxDuration) ? .tap : .stroke
    }
}

/// 編輯器互動階段（遵循標準單一職責模式設計）
public enum EditorInteractionPhase: Equatable, Sendable {
    /// 手寫中（PencilKit 啟用、筆跡預測活躍、畫布點擊不產生文字框）
    case drawing
    /// 打字排版中（PencilKit 全域鎖定、畫布點擊聚焦/建立文字框、Pencil 僅供隨手寫或選取）
    case typing(activeTextId: UUID?)
    /// 物件選取或調整中（選取邊框活躍、手柄可拖曳）
    case selecting
    /// 次級工作坊開啟中（次級 Modal 優先，主畫布手勢凍結）
    case modalStudio
}

/// 編輯器全域權威狀態機（權限集中、互斥守衛、零回退保障）
@MainActor
public final class EditorStateMachine: ObservableObject {
    // MARK: - Published Properties

    /// 當前主模式（手寫 vs 打字）
    @Published public private(set) var currentMode: EditorMode = .draw

    /// 當前互動階段
    @Published public private(set) var phase: EditorInteractionPhase = .drawing

    /// 當前行內編輯中的文字方塊 ID（打字模式下）
    @Published public var activeTextId: UUID? {
        didSet {
            updatePhase()
        }
    }

    /// 當前選取或行內編輯的表格儲存格座標
    @Published public var activeTableCell: TableCellCoordinate?

    /// 次級視窗或工作坊是否正在展示
    @Published public var isModalActive: Bool = false {
        didSet {
            updatePhase()
        }
    }

    // MARK: - Computed Invariants (狀態守衛保證)

    /// PencilKit 畫布是否允許繪製墨水
    /// 守衛規則：僅在手寫模式（.draw）且無次級工作坊時啟用，文字模式下 100% 關閉
    public var isInkDrawingAllowed: Bool {
        guard !isModalActive else { return false }
        return currentMode == .draw
    }

    /// 畫布空白處點擊是否應建立或聚焦文字方塊
    /// 守衛規則：僅在打字模式（.type）下啟用
    public var isCanvasTapCreatesText: Bool {
        guard !isModalActive else { return false }
        return currentMode == .type
    }

    /// 畫布上的物件（表格、便利貼、圖表）是否允許直接選取或拖曳
    /// 守衛規則：在打字模式（.type）下啟用；手寫模式（.draw）下不攔截觸控，讓筆墨直達畫布
    public var isObjectDirectSelectionAllowed: Bool {
        guard !isModalActive else { return false }
        return currentMode == .type
    }

    // MARK: - Initializer

    public init(initialMode: EditorMode = .draw) {
        self.currentMode = initialMode
        self.phase = initialMode == .draw ? .drawing : .typing(activeTextId: nil)
    }

    // MARK: - State Transitions (模式切換與守衛)

    /// 請求切換主編輯模式
    /// - Parameter targetMode: 目標模式（.draw 或 .type）
    /// - Returns: 切換是否成功
    @discardableResult
    public func setMode(_ targetMode: EditorMode) -> Bool {
        guard currentMode != targetMode else { return false }

        // 離開打字模式時，自動收合未儲存的輸入焦點
        if currentMode == .type && targetMode == .draw {
            activeTextId = nil
            activeTableCell = nil
        }

        currentMode = targetMode
        updatePhase()
        return true
    }

    /// 切換模式（快捷鍵或切換鈕）
    public func toggleMode() {
        setMode(currentMode == .draw ? .type : .draw)
    }

    /// Apple Pencil 觸碰畫布時的回呼
    /// - Returns: true 表示此觸碰應作為筆跡處理；false 表示應作為點擊/游標指針處理（不可切換模式）
    public func handlePencilTouch() -> Bool {
        // 核心守衛：若當前為打字模式，絕對不允許 Pencil 觸碰自動切換回 .draw
        guard currentMode == .draw else {
            return false
        }
        return true
    }

    /// 點選文字方塊進行行內編輯
    public func beginTextEditing(id: UUID) {
        // 全自動意圖感知：點擊文字方塊時，自動平滑切換至打字排版模式
        if currentMode != .type {
            setMode(.type)
        }
        activeTextId = id
        activeTableCell = nil
        updatePhase()
    }

    /// 結束文字方塊編輯
    public func endTextEditing() {
        activeTextId = nil
        updatePhase()
    }

    /// 點選表格儲存格進行行內編輯
    public func selectTableCell(row: Int, col: Int) {
        activeTableCell = TableCellCoordinate(row: row, col: col)
        activeTextId = nil
        updatePhase()
    }

    /// 清空所有物件選取與行內編輯焦點
    public func clearAllSelection() {
        activeTextId = nil
        activeTableCell = nil
        updatePhase()
    }

    // MARK: - Private Helpers

    private func updatePhase() {
        if isModalActive {
            phase = .modalStudio
        } else if activeTableCell != nil {
            phase = .selecting
        } else if currentMode == .type {
            phase = .typing(activeTextId: activeTextId)
        } else {
            phase = .drawing
        }
    }
}

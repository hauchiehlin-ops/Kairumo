//
//  EditorToolType.swift
//  Kairumo
//
//  繪圖工具模式列舉（架構模組化 P2）。
//

import Foundation

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 繪圖工具模式
public enum EditorToolType: String, CaseIterable, Identifiable {
    // 順序依「書寫／繪畫／標記」三族排列（核心 `BrushFamily`），與核心的工具清單一致。
    case pen = "pen"
    case ballpoint = "ballpoint"
    case fineliner = "fineliner"
    case brush = "brush"
    case calligraphy = "calligraphy"
    case pencil = "pencil"
    case charcoal = "charcoal"
    case crayon = "crayon"
    case airbrush = "airbrush"
    case oilpaint = "oilpaint"
    case watercolor = "watercolor"
    case marker = "marker"
    case highlighter = "highlighter"
    case eraser = "eraser"
    case lasso = "lasso"
    case maskingTape = "masking_tape"
    case translationPen = "translation_pen"
    /// 圖學：製圖筆組、圖層、線型與吸附（見 Drafting.swift）。
    case drafting = "drafting"

    public var id: String { rawValue }

    /// 這個工具是不是「筆」。
    ///
    /// 橡皮擦與套索不是筆：一個是擦掉、一個是選取，兩者都不沾墨，也不吃
    /// 顏色與粗細。工具列把九個圖示排成沒有斷點的一長列時，使用者得靠
    /// 記圖案來分辨 —— 分組之後，形狀就說明了用途（工作項 S-62）。
    public var isBrush: Bool {
        switch self {
        case .eraser, .lasso, .maskingTape, .translationPen, .drafting: return false
        default: return true
        }
    }

    /// ⌘1…⌘0 對應的工具，依**原本**的順序。
    ///
    /// 工具列改成「書寫／繪畫／標記」三族排列之後，`allCases` 的順序變了；
    /// 快捷鍵是肌肉記憶，不能跟著工具列重排 —— 用 ⌘3 叫出毛筆的人，升級之後不該拿到針筆。
    public static let shortcutOrder: [EditorToolType] = [
        .pen, .ballpoint, .brush, .marker, .highlighter, .pencil, .watercolor, .eraser, .lasso, .maskingTape,
    ]

    /// 筆刷所屬的族。不是筆刷的工具為 `nil`。與核心 `Tool::family` 一致（有測試對帳）。
    public var family: FfiBrushFamily? {
        switch self {
        case .pen, .ballpoint, .fineliner, .brush, .calligraphy, .pencil: return .writing
        case .charcoal, .crayon, .airbrush, .oilpaint, .watercolor: return .painting
        case .marker, .highlighter: return .marking
        case .eraser, .lasso, .maskingTape, .translationPen, .drafting: return nil
        }
    }

    /// 由自繪引擎算繪的筆刷（見 ProInk.swift）。其餘走 PencilKit。
    public var proToolKind: ToolKind? {
        switch self {
        case .brush: return .brush
        case .fineliner: return .fineliner
        case .charcoal: return .charcoal
        case .crayon: return .crayon
        case .airbrush: return .airbrush
        case .oilpaint: return .oilPaint
        case .calligraphy: return .calligraphy
        default: return nil
        }
    }

    public var iconName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .fineliner: return "pencil.line"
        case .calligraphy: return "pencil.tip.crop.circle"
        case .charcoal: return "scribble"
        case .crayon: return "pencil.and.scribble"
        case .airbrush: return "sparkle"
        case .oilpaint: return "paintbrush.pointed"
        case .ballpoint: return "pencil.line"
        case .brush: return "paintbrush.pointed.fill"
        case .marker: return "pencil.and.outline"
        case .highlighter: return "highlighter"
        case .pencil: return "pencil"
        case .watercolor: return "paintbrush.fill"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .maskingTape: return "bandage.fill"
        case .translationPen: return "character.book.closed.fill"
        case .drafting: return "ruler"
        }
    }

    /// 跨平台對照閘門用的識別字（核心 `ffi_screens` 的 `editor.inktools`）。
    ///
    /// 寫成 switch 而不是 `"editor.ink.\(rawValue)"`：閘門掃的是原始碼裡的
    /// 字串字面值，插值組出來的識別字它看不見 —— 那樣工具少一個也不會紅。
    public var parityIdentifier: String {
        switch self {
        case .pen: return "editor.ink.pen"
        case .fineliner: return "editor.ink.fineliner"
        case .calligraphy: return "editor.ink.calligraphy"
        case .charcoal: return "editor.ink.charcoal"
        case .crayon: return "editor.ink.crayon"
        case .airbrush: return "editor.ink.airbrush"
        case .oilpaint: return "editor.ink.oilpaint"
        case .ballpoint: return "editor.ink.ballpoint"
        case .brush: return "editor.ink.brush"
        case .marker: return "editor.ink.marker"
        case .highlighter: return "editor.ink.highlighter"
        case .pencil: return "editor.ink.pencil"
        case .watercolor: return "editor.ink.watercolor"
        case .eraser: return "editor.ink.eraser"
        case .lasso: return "editor.ink.lasso"
        case .maskingTape: return "editor.ink.maskingTape"
        case .translationPen: return "editor.ink.translationPen"
        case .drafting: return "editor.ink.drafting"
        }
    }

    public var localizationKey: String {
        switch self {
        case .pen: return "tool_pen"
        case .fineliner: return "tool_fineliner"
        case .calligraphy: return "tool_calligraphy"
        case .charcoal: return "tool_charcoal"
        case .crayon: return "tool_crayon"
        case .airbrush: return "tool_airbrush"
        case .oilpaint: return "tool_oilpaint"
        case .ballpoint: return "tool_ballpoint"
        case .brush: return "tool_brush"
        case .marker: return "tool_marker"
        case .highlighter: return "tool_highlighter"
        case .pencil: return "tool_pencil"
        case .watercolor: return "tool_watercolor"
        case .eraser: return "tool_eraser"
        case .lasso: return "tool_lasso"
        case .maskingTape: return "tool_masking_tape"
        case .translationPen: return "tool_translation_pen"
        case .drafting: return "tool_drafting"
        }
    }
}

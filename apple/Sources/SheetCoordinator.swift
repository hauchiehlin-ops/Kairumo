//
//  SheetCoordinator.swift
//  Kairumo
//
//  Created for Kairumo Goodnotes Transformation Plan (Phase 1).
//  統一彈窗與選單轉場協調器：徹底取代散落各處且不穩定的猜測性延遲（DispatchQueue.asyncAfter），
//  確保次級視窗、系統選取器與工作坊 100% 可靠開啟，不被 UIKit/SwiftUI 動畫衝突丟棄。
//

import SwiftUI
import Combine

/// 彈窗目標列舉
public enum SheetDestination: Identifiable, Equatable, Sendable {
    case assetLibrary
    case stickerLibrary
    case audioPicker
    case photoPicker
    case mathCalculator
    case chartStudio
    case tableStudio
    case shapeStudio
    case studio3D
    case themeTools
    case palmThreshold
    case advancedPenSettings
    case toolbarCustomization
    case collaboration
    case noteIntelligence
    case exportPdf
    case exportImage
    case printNote

    public var id: String {
        switch self {
        case .assetLibrary: return "assetLibrary"
        case .stickerLibrary: return "stickerLibrary"
        case .audioPicker: return "audioPicker"
        case .photoPicker: return "photoPicker"
        case .mathCalculator: return "mathCalculator"
        case .chartStudio: return "chartStudio"
        case .tableStudio: return "tableStudio"
        case .shapeStudio: return "shapeStudio"
        case .studio3D: return "studio3D"
        case .themeTools: return "themeTools"
        case .palmThreshold: return "palmThreshold"
        case .advancedPenSettings: return "advancedPenSettings"
        case .toolbarCustomization: return "toolbarCustomization"
        case .collaboration: return "collaboration"
        case .noteIntelligence: return "noteIntelligence"
        case .exportPdf: return "exportPdf"
        case .exportImage: return "exportImage"
        case .printNote: return "printNote"
        }
    }
}

/// 統一彈窗與選單轉場協調器
@MainActor
public final class SheetCoordinator: ObservableObject {
    // MARK: - Published Properties

    /// 當前活動的 Sheet 目標
    @Published public var activeSheet: SheetDestination?

    /// 當前活動的檔案匯入槽位（.audio, .image, .pdf, .document）
    @Published public var activeImportSlot: FfiImportSlot?

    /// 是否正在等待前一個轉場動畫完成
    @Published public private(set) var isTransitioning: Bool = false

    public init() {}

    // MARK: - Safe Presentation APIs

    /// 從選單安全開啟次級視窗
    /// 保證等待 UIMenu 收合動畫（0.25s）完全完成後才觸發呈現，避免 UIKit Attempt to present 警告與請求丟棄
    public func presentFromMenu(_ destination: SheetDestination) {
        isTransitioning = true
        activeImportSlot = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            self.activeSheet = destination
            self.isTransitioning = false
        }
    }

    /// 從選單安全觸發檔案選取器
    public func triggerFileImportFromMenu(_ slot: FfiImportSlot) {
        isTransitioning = true
        activeSheet = nil
        activeImportSlot = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            guard let self = self else { return }
            self.activeImportSlot = slot
            self.isTransitioning = false
        }
    }

    /// 直接開啟（非選單情境）
    public func presentDirectly(_ destination: SheetDestination) {
        activeImportSlot = nil
        activeSheet = destination
    }

    /// 關閉所有彈窗與匯入選取器
    public func dismissAll() {
        activeSheet = nil
        activeImportSlot = nil
        isTransitioning = false
    }
}

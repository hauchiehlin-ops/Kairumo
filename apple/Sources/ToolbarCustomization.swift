//
//  ToolbarCustomization.swift
//  Kairumo
//
//  自訂工具列（工作項 S-261）。
//
//  # 為什麼不是各平台各寫一份
//
//  哪些工具存在、分幾組、關掉正在用的那一支之後該換成哪一支 —— 全部在核心
//  （`padnote-toolbar`）。這裡只做三件事：畫開關、存下來、把結果餵回工具列。
//
//  設定本身走 `AccountSyncStore` 的 `toolbarJson` 欄位，所以**會跟著帳號跑**。
//  在 iPad 上關掉的水彩筆，Mac 打開就已經是關的。那條管線（核心欄位、兩端的
//  讀寫）其實早就鋪好了，只是一直沒有人讀寫它。
//

import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 工具列設定的單一真相來源。
///
/// `FfiToolbar` 是核心物件（內含 `Mutex`），本身沒有 `objectWillChange`，
/// 所以這裡持有它並在每次改動後自己發布 —— 畫面才會更新。
@MainActor
public final class ToolbarSettings: ObservableObject {

    public static let shared = ToolbarSettings()

    /// 目前隱藏的工具，以**跨平台識別字**表示（`editor.ink.pen`…）。
    ///
    /// 存識別字而不是 `FfiTool`：編輯器那邊的 `EditorToolType` 早就掛著同一個
    /// 字串當無障礙識別字，用它對照就不必再維護一張「哪個 enum 對哪個 enum」
    /// 的表。那種表漏一格不會有人發現 —— 症狀只是某支筆關不掉。
    @Published public private(set) var hiddenIdentifiers: Set<String> = []

    private var core: FfiToolbar

    private init() {
        let locale = ToolbarSettings.coreLocale()
        if let saved = AccountSyncStore.shared.syncedToolbarJSON {
            core = FfiToolbar.fromJson(locale: locale, json: saved)
        } else {
            core = FfiToolbar(locale: locale)
        }
        refresh()
    }

    private static func coreLocale() -> FfiLocale {
        localeForTag(tag: LocalizationManager.shared.currentLanguage.rawValue)
    }

    /// 全部工具，依分組排列 —— 設定畫面要的就是這份。
    public func groups() -> [FfiToolGroupInfo] {
        core.setLocale(locale: ToolbarSettings.coreLocale())
        return core.allGroups()
    }

    public func isVisible(_ identifier: String) -> Bool {
        !hiddenIdentifiers.contains(identifier)
    }

    public func setVisible(_ tool: FfiTool, _ visible: Bool) {
        core.setVisible(tool: tool, visible: visible)
        persist()
    }

    /// 工具列擺哪裡（S-261b）。
    ///
    /// 可移動是刻意的：Goodnotes 的工具列頂部固定，**左撇子與橫向書寫時
    /// 會擋手**。這個設定與「哪些工具顯示」一樣同步得動。
    @Published public private(set) var placement: FfiPlacement = .bottom

    /// 顯示文字標籤還是只有圖示。
    ///
    /// 泰文與日文的字串常比英文長 30–50%，那些語言預設只有圖示 ——
    /// 預設值由核心依語言決定，這裡只負責讓使用者改。
    @Published public private(set) var showLabels: Bool = false

    public func setPlacement(_ next: FfiPlacement) {
        core.setPlacement(placement: next)
        persist()
    }

    public func setShowLabels(_ next: Bool) {
        core.setShowLabels(show: next)
        persist()
    }

    /// 回到出廠設定。**使用者改壞了要回得去。**
    public func reset() {
        core.reset()
        persist()
    }

    /// 藏起某支工具之後，目前選中的該換成哪一支（兩者都用識別字表示）。
    ///
    /// 規則在核心，Android 走同一條 —— 兩端對這件事給出不同答案的話，
    /// 同一個帳號在兩台裝置上會停在不同的筆上。
    ///
    /// 認不得的識別字原樣回傳：編輯器有一天多一支核心還不知道的筆時，
    /// 該讓它繼續用，而不是把使用者踢回鋼筆。
    public func identifierAfterHiding(_ identifier: String) -> String {
        let all = core.allGroups().flatMap(\.tools)
        guard let current = all.first(where: { $0.identifier == identifier }) else {
            return identifier
        }
        let next = core.toolAfterHiding(current: current.tool)
        return all.first(where: { $0.tool == next })?.identifier ?? identifier
    }

    private func persist() {
        refresh()
        AccountSyncStore.shared.setSyncedToolbarJSON(core.toJson())
    }

    private func refresh() {
        placement = core.placement()
        showLabels = core.showLabels()
        hiddenIdentifiers = Set(
            core.allGroups()
                .flatMap(\.tools)
                .filter { !$0.visible }
                .map(\.identifier))
    }
}

/// 「自訂工具列」設定畫面。
public struct ToolbarCustomizationView: View {

    @ObservedObject private var settings = ToolbarSettings.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private func L(_ key: String) -> String { localizationManager.localized(key) }

    public var body: some View {
        List {
            Section {
                Text(settings.hiddenIdentifiers.count == allToolCount
                     ? L("toolbar_all_hidden")
                     : L("toolbar_customize_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("toolbar.hint")

                Button(role: .destructive) {
                    settings.reset()
                } label: {
                    Text(L("toolbar_reset"))
                }
                .accessibilityIdentifier("toolbar.reset")
            }

            // 用序號當 id 而不是 `\.group`：UniFFI 產生的列舉沒有
            // `Hashable`，而分組順序本來就是核心決定的固定順序。
            // 位置與文字標籤（S-261b）。
            //
            // 這兩個設定原本只存在核心裡、也同步得動，但**兩端都沒有 UI** ——
            // 理由是「只做得動一邊的設定比沒有更糟」。現在兩端都能真的移動
            // 工具列，所以開關才有意義。
            Section(L("toolbar_placement")) {
                Picker(L("toolbar_placement"), selection: Binding(
                    get: { settings.placement },
                    set: { settings.setPlacement($0) }
                )) {
                    Text(L("toolbar_place_top")).tag(FfiPlacement.top)
                    Text(L("toolbar_place_bottom")).tag(FfiPlacement.bottom)
                    Text(L("toolbar_place_left")).tag(FfiPlacement.left)
                    Text(L("toolbar_place_right")).tag(FfiPlacement.right)
                    Text(L("toolbar_place_collapsed")).tag(FfiPlacement.collapsed)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("toolbar.placement")

                Text(settings.placement == .collapsed
                     ? L("toolbar_collapsed_hint")
                     : L("toolbar_placement_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle(isOn: Binding(
                    get: { settings.showLabels },
                    set: { settings.setShowLabels($0) }
                )) {
                    Text(L("toolbar_show_labels"))
                }
                .accessibilityIdentifier("toolbar.show_labels")

                Text(L("toolbar_labels_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(settings.groups().enumerated()), id: \.offset) { _, group in
                Section(group.label) {
                    ForEach(group.tools, id: \.identifier) { info in
                        Toggle(isOn: Binding(
                            get: { settings.isVisible(info.identifier) },
                            set: { settings.setVisible(info.tool, $0) }
                        )) {
                            Text(L(ToolbarCustomizationView.uiLabelKey(info.identifier)))
                        }
                        // 識別字掛在 Toggle 本身而不是裡面的 Text ——
                        // 掛在子元素上時，VoiceOver 與 UI 測試按到的是那行字，
                        // 而開關在別的地方（S-263 踩過這個坑）。
                        .accessibilityIdentifier(settingsIdentifier(for: info.identifier))
                    }
                }
            }
        }
        .navigationTitle(L("customize_toolbar"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var allToolCount: Int {
        settings.groups().reduce(0) { $0 + $1.tools.count }
    }

    /// 編輯器的 `editor.ink.pen` → 設定畫面的 `toolbar.tool.pen`。
    ///
    /// 寫成 `switch` 而不是 `"toolbar.tool.\(suffix)"`：跨平台對照閘門掃的是
    /// 原始碼裡的**字串字面值**，插值組出來的識別字它看不見 —— 那樣某支工具
    /// 在設定畫面上漏掉一個開關，閘門也不會紅。這件事在
    /// `EditorToolType.parityIdentifier` 已經踩過一次。
    private func settingsIdentifier(for editorIdentifier: String) -> String {
        switch editorIdentifier {
        case "editor.ink.pen": return "toolbar.tool.pen"
        case "editor.ink.ballpoint": return "toolbar.tool.ballpoint"
        case "editor.ink.brush": return "toolbar.tool.brush"
        case "editor.ink.marker": return "toolbar.tool.marker"
        case "editor.ink.highlighter": return "toolbar.tool.highlighter"
        case "editor.ink.pencil": return "toolbar.tool.pencil"
        case "editor.ink.watercolor": return "toolbar.tool.watercolor"
        case "editor.ink.eraser": return "toolbar.tool.eraser"
        case "editor.ink.lasso": return "toolbar.tool.lasso"
        case "editor.ink.maskingTape": return "toolbar.tool.maskingTape"
        case "editor.ink.undo": return "toolbar.tool.undo"
        case "editor.ink.redo": return "toolbar.tool.redo"
        case "editor.ink.clear": return "toolbar.tool.clear"
        default: return editorIdentifier
        }
    }

    /// 設定畫面上的字必須與編輯器工具列上的字**逐字相同** ——
    /// 使用者要靠那行字認出自己在關哪一顆按鈕。所以這裡用的是介面字串表的鍵，
    /// 不是核心自己那張表（`FfiToolInfo.label`）。
    static func uiLabelKey(_ identifier: String) -> String {
        switch identifier {
        case "editor.ink.pen": return "tool_pen"
        case "editor.ink.ballpoint": return "tool_ballpoint"
        case "editor.ink.brush": return "tool_brush"
        case "editor.ink.marker": return "tool_marker"
        case "editor.ink.highlighter": return "tool_highlighter"
        case "editor.ink.pencil": return "tool_pencil"
        case "editor.ink.watercolor": return "tool_watercolor"
        case "editor.ink.eraser": return "tool_eraser"
        case "editor.ink.lasso": return "tool_lasso"
        case "editor.ink.maskingTape": return "tool_masking_tape"
        case "editor.ink.undo": return "undo"
        case "editor.ink.redo": return "redo"
        case "editor.ink.clear": return "clear_page"
        default: return identifier
        }
    }
}

//
//  NotebookEditorView.swift
//  Kairumo
//
//  全功能專業手寫筆記編輯器與畫布視圖
//  內建實體手繪工具列（鋼筆、原子筆、螢光筆、鉛筆、橡皮擦、套索、色彩盤與粗細切換）
//  支援即時自動儲存、尺規量測導引、多頁切換、實體錄音與高解析度 PDF 導出
//

import SwiftUI
import PencilKit
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

#if canImport(PadnoteCore)
import PadnoteCore
#endif


/// 筆記編輯器全螢幕視圖
public struct NotebookEditorView: View {
    @Binding var notebook: NotebookDocument
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var audioManager = AudioRecorderManager.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    /// 使用者自訂的工具列（S-261）。關掉的工具不畫出來。
    @ObservedObject var toolbarSettings = ToolbarSettings.shared
    func L(_ key: String) -> String { localizationManager.localized(key) }

    // 頁面狀態
    @State var currentPageIndex: Int = 0

    public static var isTabletOrDesktopDevice: Bool {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac
        #endif
    }

    /// 頁面顯示模式。平板與桌機預設連續模式；手機預設整頁；使用者切過之後記住他的選擇。
    ///
    /// 存在 AppStorage 而不是筆記裡：它是「怎麼看」而不是「內容是什麼」，
    /// 跟著人走比跟著筆記走合理 —— 跟著筆記的話，同一個人在不同本筆記裡
    /// 會拿到不同的捲動方式。
    @AppStorage(ProfileContext.scopedKey("kairumo.editor.pageDisplayMode"))
    var pageDisplayModeRaw: String = (NotebookEditorView.isTabletOrDesktopDevice ? PageDisplayMode.continuous : PageDisplayMode.single).rawValue
    var pageDisplayMode: PageDisplayMode {
        PageDisplayMode(rawValue: pageDisplayModeRaw) ?? (Self.isTabletOrDesktopDevice ? .continuous : .single)
    }
    @State var currentDrawing: PKDrawing = PKDrawing()
    /// 筆跡改動後「把這本筆記標記為剛改過」的去抖動計時器。
    ///
    /// 筆畫本身是**每次變動就落盤**的（見 `onDrawingChanged` 裡的
    /// `store.saveDrawing`），但那只寫 `.drawing` 檔，不會動到筆記本身。
    /// 少了這一步的後果有兩個，而且都看起來像「筆跡沒有被儲存」：
    ///
    /// 1. 首頁卡片上的修改時間停在上一次插入物件的時刻 —— 使用者寫了
    ///    一整頁字，清單上那本筆記卻沒有往上移，時間也沒變。
    /// 2. **雲端同步不會被觸發**。自動同步掛在 `persistData()` 上，
    ///    而只寫 `.drawing` 檔不會經過它 —— 於是手寫內容要等到使用者
    ///    換頁或離開編輯器才會上雲。
    ///
    /// 為什麼要去抖動：`onDrawingChanged` 在**一筆畫的途中**就會被叫很多次，
    /// 每次都寫 `notebooks.json` 並觸發整棵畫面重算的話，寫字會頓。
    @State var inkTouchWork: DispatchWorkItem? = nil
    /// 每一頁「最後一次與磁碟一致」的筆跡（讀進來的、或寫出去的）。同步重讀時用它分辨
    /// 哪些筆畫是這台還沒寫出去的（見 `mergedWithDisk`）。放在參照型別裡：每一筆都會更新，
    /// 寫 `@State` 的話整個編輯器每一筆重算一次。
    @State var inkDiskBaselines = InkDiskBaselines()
    /// 連續模式「只重讀筆跡、不重建畫布」的世代（別台同步進來時加一）。
    /// `continuousReloadGeneration` 會整個重建每一頁的畫布 —— 只留給還原、頁面結構改變這種真的要重來的情況。
    @State var continuousInkReloadGeneration = 0
    /// 連續模式「只重建物件層」的世代（刪除、調整物件圖層之後）。
    @State var continuousObjectGeneration = 0
    @State var continuousZoomTarget: PageViewportLayout.ZoomTarget? = nil
    @State var continuousPinchBaseZoom: CGFloat? = nil
    @State var pencilModeSwitchAt: Date? = nil
    @State var continuousScrollRequest: Int = 0
    @State var continuousDragPage: Int? = nil
    @State var continuousScale: CGFloat = 1
    @State var continuousViewportHeight: CGFloat = 800
    @State var continuousReportedPage: Int = -1
    @State var continuousCanvases = ContinuousCanvasRegistry()
    @State var proInkDirty = false
    @State var continuousReloadGeneration = 0
    @State var thumbnailRevision = 0
    @State var continuousProgrammaticScrollUntil: Date = .distantPast
    /// 筆跡單一擁有者（架構審視 P1）：以 pageId 識別，消除多份副本與空白覆蓋。
    var activeInkStore: PageInkStore {
        PageInkStore.store(for: notebook, store: store)
    }
    @State var coreInkWork: DispatchWorkItem? = nil
    /// 這一批待寫筆畫最早的那一筆的時間。見 `scheduleCoreInkFlush` 的上限說明。
    @State var coreInkFirstPendingAt: Date? = nil
    @State var canvasView: PKCanvasView? = nil
    @State var currentPageHeight: CGFloat = PageGeometry.height
    /// 掌拒（工作項 S-45）。判定規則走核心，與 Android 同一份。
    @State var palmRejection = PalmRejectionCoordinator()
    @State var showToolbarCustomization = false
    @State var showPalmThresholdSheet = false
    @State var showAdvancedPenSettingsSheet = false
    @State var showExportPreview = false
    @State private var wantsShareAfterPreview = false
    @StateObject var lasso = LassoSelection()
    var hasLassoSelection: Bool {
        lasso.hasSelection
    }
    @State var lassoDragStartPage: Int? = nil
    @State var lassoDragInitialDrawing: PKDrawing? = nil
    @State var showExtendedBanner: Bool = false

    @State var canvasZoomScale: CGFloat = 1.0
    @State var canvasContentOffset: CGPoint = .zero

    // 實體工具列狀態
    @State var selectedTool: EditorToolType = .pen
    /// 自訂頁面尺寸的輸入畫面。
    @State var showCustomPageSize = false
    /// 立體輔助（草圖拉伸、三視圖、剖面）。
    @State var showSolidStudio = false
    @State var showDraftingToolbox = false
    @State var draftExportShare: SharedFile?
    @State var previousTool: EditorToolType?
    @State private var lastObservedTool: EditorToolType = .pen

    /// 有東西正懸在畫布上等著放下（工作項 S-68）。
    ///
    /// 一定要有這個回饋：拖放看不見目標的話，使用者不知道放開會發生什麼事，
    /// 也分不出「這裡不能放」與「放了但沒反應」。
    @State var isCanvasDropTargeted: Bool = false

    /// 按著側鍵之前選的是哪一支。放開時回到它。
    ///
    /// `nil` 表示「這一次的橡皮擦不是側鍵切出來的」—— 使用者自己在工具列
    /// 選的橡皮擦，不能因為他碰了一下側鍵就被換掉。
    @State var penHeldTool: EditorToolType? = nil

    /// 最後用過的**筆刷**。筆身動作要切回來的就是它（工作項 S-67）。
    ///
    /// 由 `.onChange(of: selectedTool)` 維護，不是 `didSet` ——
    /// `@State` 的 `didSet` 在透過 binding（`$selectedTool`）改值時不會觸發，
    /// 那會變成「用某些 UI 換筆會記到、用另一些不會」。
    ///
    /// 記「最後用過的筆刷」而不是「上一個工具」：後者在連按兩次之後會在
    /// 橡皮擦與套索之間跳，而使用者按第二次想回到的是他原本那支筆。
    @State var lastBrushTool: EditorToolType = .pen
    @State var selectedColor: Color = .primary
    @State var strokeWidth: CGFloat = 3.5
    @State var isRulerActive: Bool = false
    @State private var rulerAngleGuide: Double = 0.0
    @State var isInsertSpaceActive: Bool = false
    @State var insertSpaceDividerY: CGFloat = 300.0
    @State var insertSpaceDragAccum: CGFloat = 0.0
    
    @State var eraserMode: EraserMode = .stroke
    @State var pixelEraserWidth: CGFloat = 20.0
    
    @State private var showLassoColorPicker: Bool = false

    // 彈窗與輔助狀態
    @State var showRenameAlert: Bool = false
    @State var renameText: String = ""
    @State var showShareSheet: Bool = false
    /// 匯出之後要開的是**儲存對話框**（而不是分享面板）。
    @State var showSaveDialog: Bool = false
    @State var showClearConfirmAlert: Bool = false
    @State var exportPdfData: Data? = nil
    /// 這一次匯出的副檔名。
    ///
    /// 原本分享表一律叫 `<標題>.pdf` —— 選「匯出圖片」拿到的是一個
    /// **副檔名寫著 pdf、內容卻是 PNG** 的檔案，收到的人打不開，
    /// 使用者看到的是「我選了圖片，它給我 PDF」（實機回報過）。
    @State var exportFileExtension: String = "pdf"

    // 圖片、算式、圖表、文字與連結狀態
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State var showPhotoPicker: Bool = false
    /// 統一管理自檔案匯入的插槽，避免 SwiftUI 多個 .fileImporter 競爭互斥
    @State var activeImportSlot: FfiImportSlot? = nil
    /// 已經收進來、正在讓使用者挑頁的那份 PDF。
    @State private var pdfToInsert: URL? = nil
    /// 匯入失敗的語系鍵。非空就跳提示。
    @State var importErrorKey: String = ""
    @State var showStickerLibrary: Bool = false
    @State var pendingStickerPlacement: PendingStickerPlacement? = nil
    @State var showMathCalculator: Bool = false
    @State var showChartStudio: Bool = false
    @State var showTableStudio: Bool = false
    @State var showShapeStudio: Bool = false
    @State var showLayerPanel: Bool = false
    /// 畫布中單一選取物件的唯一識別碼（互斥單選：同一時間最多只有一個物件處於編輯/選取狀態）
    @State var activeSelectedObjectId: String? = nil
    /// 正在顯示「解除鎖定」鈕的鎖定物件（點了鎖頭或點了鎖定的物件）。見 `lockedObjectPrompt`。
    @State var lockPromptId: String? = nil
    /// 一鍵恢復初始狀態（捨棄進入編輯器後的所有修改）
    @State var initialNotebookSnapshot: NotebookDocument? = nil
    /// 範例有改動、使用者要離開時：問要存檔、另存還是放棄（見 `requestLeave`）。
    @State var showSampleLeaveDialog = false
    /// 使用者選完之後要做的事（回首頁或切換到另一本）。
    @State var afterSampleLeave: (() -> Void)?
    /// 每一頁第一次載入時的專業筆畫（圖學筆畫、專業筆刷）與「已擦除」名單 ——
    /// 「恢復初始狀態」要連它們一起還原，不然圖學筆記本裡畫的線一條都不會少。
    @State var initialPageInk: [Int: InitialPageInk] = [:]

    struct InitialPageInk {
        var own: [ProStroke]
        var foreign: [ProStroke]
        var suppressed: Set<String>
        var erasedPencilKit: Set<String>
    }
    /// 「目前第幾頁原本是第幾頁」（`nil` = 這次新增的頁）。第一次調整頁面結構時才建立 ——
    /// 在那之前頁碼就是原本的頁碼。還原到初始狀態要靠它把頁序與逐頁檔案排回去：
    /// 原本照頁碼還原，搬過、刪過、插過頁之後，還原寫回去的內容落在別頁上。
    @State var pageOrigins: [Int?]? = nil
    @State var showRevertConfirmAlert: Bool = false
    /// 圖層面板裡選取的形狀。多選才群組得起來。
    @State var selectedShapeIds: Set<String> = []
    /// 被選取的連接線（連接線不在 `selectedShapeIds` 裡 —— 它不是形狀，沒有群組與對齊）。
    @State var selectedConnectionId: String? = nil
    @State var editingShapeId: String? = nil
    @State var editingConnectionId: String? = nil
    /// 拖曳連接點拉線時的預覽。
    @State var connectionDraft: (page: Int, start: CGPoint, current: CGPoint)? = nil
    /// 正在重新編修的表格。
    @State var editingTable: NoteTableAttachment? = nil
    @State var editingAttachmentId: String? = nil
    /// 正在重新編修的圖表。帶著規格一起，`sheet(item:)` 才有東西可以開。
    @State var editingChartAttachmentId: ChartEditTarget? = nil
    /// 正在重新編修的算式卡片。
    @State var editingMathAttachmentId: MathEditTarget? = nil

    // Word 文字排版、網址預覽與專業調色狀態
    @State var showWordStudio: Bool = false
    /// 摘要與待辦（工作項 S-20）。
    @State var showNoteIntelligence: Bool = false
    @State var editingTextId: String? = nil
    /// 隨點隨打就地輸入狀態（連動 TextAttachmentItemView 的焦點與鍵盤）
    @State var inlineEditingTextId: String? = nil
    /// 打字工具列「正在格式化哪一個方塊」。
    ///
    /// 只靠 `inlineEditingTextId` 不夠：Mac 上一按工具列的按鈕，文字欄位在
    /// 滑鼠按下那一刻就交出焦點 → 就地編輯結束 → `inlineEditingTextId` 變 nil，
    /// 等到按鈕的動作真正執行時，目標已經不見了。以前的退路是「這一頁第一個
    /// 文字方塊」—— 所以字級、清單符號時好時壞，而且常常改到頁首的標題方塊。
    /// 這個值只在使用者明確換目標（點別的物件、點空白處、換頁、換模式）時才清掉。
    @State var textFormatTargetId: String? = nil
    /// 焦點是「被工具列搶走」而不是使用者主動結束：格式套用完要把游標還回去。
    @State var suspendedInlineTextId: String? = nil
    /// 就地編輯的選取範圍。用 `@State` 持有參考而**不訂閱** —— 游標每動一下都會發布，
    /// 整個編輯器跟著重算會很卡；只有工具列訂閱它。
    @State var textSelectionTracker = TextSelectionTracker()
    /// 沒有任何文字方塊可套用時，工具列改的是下一個新方塊的樣式
    /// （Word 的「插入點格式」），而不是憑空在頁面上生出一個方塊。
    @State var pendingTypingStyle = NoteTextAttachment(
        id: "pending-typing-style", text: "", backgroundColorHex: "clear", hasBorder: false)
    @State var lastAddedTextId: String? = nil
    // 文字復原/重做堆疊（供文字模式與文字框使用）
    /// 畫布物件（圖片、文字方塊、形狀、表格…）的復原紀錄，與筆跡登記在同一個 `UndoManager`
    /// 上 —— 一次復原就照發生的先後退回，不分是筆跡還是物件（見 `CanvasHistory.swift`）。
    @State var objectHistory = CanvasObjectHistory()
    /// 即時協同的物件合併（欄位層級 LWW，見 `CollabSync.swift`）。參考型別、不訂閱。
    @State var collabSync = CollabObjectSync()
    /// 每一頁已經同步過的筆畫 id（逐筆增刪的比對基準）。
    @State var collabInkLedger = CollabInkLedger()
    /// 文字方塊內容的字元 CRDT（兩人同時在同一個方塊打字，設計 §8.3）。
    @State var collabTextHub = CollabTextHub()
    /// 加入房間、補發不完整時的整份狀態往來（設計 §7）。
    @State var collabStateSync = CollabStateSync()
    /// 畫布還沒掛上視窗時的備用（正常情況下用畫布的 `undoManager`）。
    @State var fallbackUndoManager = UndoManager()
    @ObservedObject var watchdog = InteractionWatchdog.shared


    // 單頁模式排版與縮放狀態（全頁 vs 適寬，支援手動放大縮小與捲動）
    enum SinglePageFitMode: String {
        case fitWidth
        case fitPage
    }
    @State var singlePageFitMode: SinglePageFitMode = .fitWidth
    @State var singlePageManualZoom: CGFloat = 1.0
    @State var singlePagePinchBaseZoom: CGFloat? = nil

    @State var snapToGrid: Bool = true
    @State var newTextDraft: NoteTextAttachment = NoteTextAttachment()
    @State var showLinkPreviewSheet: Bool = false
    @State var showProColorPicker: Bool = false
    @State var showProColorWheel: Bool = false

    // 🌟 次世代雙模核心狀態（動態傳送門、防抖修正、對稱尺規、極簡收折、局部畫布、徑向飛輪）
    @State var activeInlineInkBlockId: String? = nil
    @State var strokeStabilizer: Double = 0.0
    @State var isSymmetryActive: Bool = false
    @State var isMinimalistCanvasActive: Bool = false
    @State private var isFloatingPillExpanded: Bool = false
    @State var showRadialMenu: Bool = false
    /// 飛梭工具盤的落點（window 座標）。`nil` = 從工具列按鈕叫出，放在畫面中央。
    @State var radialMenuAnchor: CGPoint? = nil
    @State var magneticGuideActive: Bool = false
    @State var magneticGuideStart: CGPoint = .zero
    @State var magneticGuideEnd: CGPoint = .zero

    // 草圖智慧修飾狀態 (幾何識別、平滑化、一鍵修飾/重做/恢復)
    @State var showSketchRefineBar: Bool = false
    @State var refineIntensity: CGFloat = 0.85
    @State var originalSketchBackup: PKDrawing? = nil
    @State var refinedSketchCache: PKDrawing? = nil

    // 3D 模型狀態
    @State var show3DStudio: Bool = false

    // 三大主題專屬加速輔助工具與素材圖庫狀態
    @State var showThemeToolsSheet: Bool = false
    @State var showAssetLibrarySheet: Bool = false
    /// 「插入錄音」的挑選面板。
    @State var showAudioPicker: Bool = false

    // MARK: - 框選
    //
    // 見 ObjectMarquee 開頭的說明：框選是一個**明確的模式**，不是
    // 「在空白處拖曳」—— 那會跟搬物件與捲畫布互相搶。
    @State var isMarqueeActive: Bool = false
    @State var marqueeStart: CGPoint? = nil
    @State var marqueeCurrent: CGPoint? = nil
    /// 連續框選：新框到的、點到的物件加進選取，不取代原本的（見 `ObjectMarquee.combined`）。
    @State var marqueeAdditive: Bool = false
    @State var selectedObjectIds: Set<String> = []
    /// 已知的物件 id，用來認出「剛插入的」。`nil` 代表尚未建立基準（開啟筆記當下）。
    @State var knownObjectIds: Set<String>? = nil
    /// 整組拖曳時的即時位移。每一幀都寫回筆記的話，拖一次會存幾十次檔。
    @State var groupDragOffset: CGSize = .zero
    @State var objectClipboard: [ClipboardObject] = []
    /// 點選位置貼上模式：開啟後，在任一模式（手繪／打字）、任一頁面型態（單頁／連續）點一下任意頁面的任意位置，即把 `objectClipboard` 貼到該處。
    @State var isPlacingPasteObject: Bool = false
    /// 剛透過 `pasteTargetLayer` 完成點選貼上的時間戳，避免底層 `directSingleTap` 在同一拍重複觸發。
    @State var lastPastePlacementAt: Date = .distantPast
    /// 手寫辨識的結果或錯誤，顯示在浮動提示上。
    @State var recognitionMessage: String?
    /// 辨識手寫剛被按下 —— 只給提示用。
    ///
    /// 其他三個功能本身就是布林模式，辨識手寫不是（它跑完就結束），
    /// 所以要一個獨立的旗標才跳得出提示。
    @State var isRecognisingHandwriting = false
    @State var isGoldenSpiralOverlay: Bool = false
    @State var isRuleOfThirdsOverlay: Bool = false

    // 線上多人即時協同狀態
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @State var showCollaborationSheet: Bool = false
    @State var isApplyingRemoteUpdate: Bool = false
    @State var lastStrokeCount: Int = 0
    // 第二階段協同防護與討論狀態
    @State var isPlacingCommentPin: Bool = false
    @State var selectedCommentPinId: String? = nil
    @State var deletedAttachmentBackup: (type: String, data: Any)? = nil

    var isCollaborating: Bool {
        collaborationManager.status != .disconnected || !collaborationManager.currentRoomId.isEmpty
    }


    // 筆記主模式：手繪 (Draw) vs 鍵盤打字 (Type)
    @State var editorMode: EditorMode = .draw
    /// 軟體鍵盤避讓高度（Word 級打字流暢滾動視窗，避免畫面跳動或文字被遮擋）
    @State var keyboardHeight: CGFloat = 0
    /// 模式徽章是不是正顯示著。切換模式時亮起，過幾秒自己淡掉。
    ///
    /// **不常駐**（工作項 S-62）：它原本一直蓋在畫布右上角，330pt 寬，
    /// 等於永遠有一塊紙面被說明文字佔著。模式本身在工具列的切換器上看得到，
    /// 徽章要說的是「這個模式下手勢會怎樣」—— 那是切換當下才需要的提示。
    @State var modeBadgeVisible: Bool = false
    /// 用來取消上一次的淡出排程：連續切換兩次時，第一次的排程不該把
    /// 第二次剛亮起的徽章關掉。
    @State var modeBadgeToken: Int = 0

    /// 工具切換快顯提示：點擊任一筆刷或工具時在工具列緊鄰處彈出提示工具名稱
    @State var activeToolToast: (name: String, icon: String)? = nil
    @State var toolToastToken: Int = 0

    /// 畫布上的提示（例如「超出可列印範圍」）。nil 代表沒有要說的話。
    @State var canvasNotice: String?
    @State var canvasNoticeToken: Int = 0

    public enum SidebarTabMode: String, CaseIterable, Identifiable {
        case pages = "pages"
        case folders = "folders"
        public var id: String { rawValue }
    }

    // 筆記結構欄（側邊頁面縮圖大綱目錄欄）
    // 平板與桌機開啟筆記時預設展開，且預設顯示「頁面結構」。
    @State var showStructureSidebar: Bool = NotebookEditorView.isTabletOrDesktopDevice
    /// 畫布目前的實際內容寬度。縮圖要用同一個寬度算，物件位置與比例才會對得上。
    @State var canvasContentWidth: CGFloat = PageThumbnailRenderer.minPageWidth
    // 自訂捲軸狀態：iOS 原生捲動指示器不接受互動，Mac 上使用者會想用游標拖它
    @State var canvasVisibleFraction: CGFloat = 1
    @State var canvasScrollFraction: CGFloat = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var didAutoOpenSidebar: Bool = false
    @AppStorage(ProfileContext.scopedKey("kairumo_editor_sidebar_tab")) var sidebarTabRaw: String = SidebarTabMode.pages.rawValue

    var sidebarTab: SidebarTabMode {
        get { SidebarTabMode(rawValue: sidebarTabRaw) ?? .pages }
        nonmutating set { sidebarTabRaw = newValue.rawValue }
    }

    var sidebarTabBinding: Binding<SidebarTabMode> {
        Binding(
            get: { SidebarTabMode(rawValue: sidebarTabRaw) ?? .pages },
            set: { sidebarTabRaw = $0.rawValue }
        )
    }

    // 資料夾管理狀態
    @State var showRenameRootFolderAlert: Bool = false
    @State var rootFolderRenameText: String = ""
    @State var showNewFolderAlert: Bool = false
    @State var newFolderNameText: String = ""
    @State var newFolderParentId: String? = nil
    @State var folderToRename: FolderItem? = nil
    @State var folderRenameText: String = ""
    @State var showMoveNotebookSheet: Bool = false
    @State var notebookToMoveId: String? = nil
    @State var expandedFolderIds: Set<String> = []
    /// 目前被拖曳懸停的資料夾（nil 代表「未分類」區）
    @State var dropTargetFolderId: String? = nil
    @State var isUnfiledDropTargeted: Bool = false
    /// `dropTargetFolderId` 用 nil 代表「沒有任何東西懸停」，所以「懸停在
    /// 未分類區」需要另一個值，不能也用 nil。
    let unfiledDropKey = "__kairumo_unfiled__" 
    /// 拖曳中的筆記本落在「根目錄」上。根目錄那一列一直都在，
    /// 而「未分類檔案」那一段在沒有未分類筆記時整段不存在 ——
    /// 於是把最後一本筆記歸檔之後，就再也沒有地方可以把它拖回來。
    @State var isRootDropTargeted: Bool = false

    // MARK: - 頁面結構欄的拖曳與縮放
    /// 拖曳懸停中的頁碼（畫插入指示線用）。
    @State var dropTargetPageIndex: Int? = nil
    /// 多選模式下已選取的頁碼。
    @State var pageSelection: Set<Int> = []
    @State var isSelectingPages: Bool = false
    /// 目的筆記本選擇器：nil 代表沒開；true 是複製、false 是搬移。
    @State var transferIsCopy: Bool? = nil
    /// 使用者要的縮圖寬度（pt）。落盤。
    @AppStorage(ProfileContext.scopedKey("kairumo_editor_page_thumb_width")) var pageThumbnailWidth: Double = 240
    /// 編輯工作區目前可用的總寬度。夾側欄寬度要用到它。
    @State var editorAvailableWidth: CGFloat = 1024
    /// 使用者拖動界線之後的側欄寬度。落盤 —— 每次開筆記都要重調一次的設定
    /// 不算設定，只是每次都要做一遍的事。
    @AppStorage(ProfileContext.scopedKey("kairumo_editor_sidebar_width")) var storedSidebarWidth: Double = 280
    /// 拖曳界線期間的暫時寬度。放開才落盤，拖曳中每一格都寫 UserDefaults
    /// 會在拖動時卡頓。
    @State var draggingSidebarWidth: CGFloat? = nil

    // 次世代 UI/UX Phase 5: 折疊立起雙屏模式 (Tabletop Mode / Stage Manager Posture)
    @State var isTabletopMode: Bool = false
    // 次世代 UI/UX Phase 4: 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap)
    @State var isMagneticSnapActive: Bool = false

    // 頁面刪除警告
    @State var pageToDeleteIndex: Int? = nil
    @State var showDeletePageAlert: Bool = false

    // 常用色彩盤
    /// 常用墨色。**來源是核心的 `inkPalette()`**（工作項 S-63）。
    ///
    /// 這一組原本寫死在這個檔案裡，Android 端也寫死在 `InkToolbar`。
    /// S-62 把 Apple 這邊從八個純飽和原色換成六個「照真筆調」的墨色之後，
    /// Android 仍然是它自己那套 —— 同一支「藍筆」在兩台裝置上是兩個顏色。
    ///
    /// 筆畫顏色是**落盤的資料**：每一筆手寫都帶著 hex 存進筆記。所以它和
    /// 卡片底色一樣下沉到核心，兩邊不可能再分岔。
    // compactMap：`Color(hex:)` 是可失敗的初始化。core 給的 hex 一定合法
    // （核心有測試釘住格式），但用 `map` 會得到 `[Color?]` 而編不過。
    let colorPalette: [Color] = inkPalette().compactMap { Color(hex: $0.hex) }

    /// 某個墨色的語系名稱，給無障礙標籤用。
    ///
    /// 用 hex 反查而不是靠索引：色票的順序將來可能會變，靠索引對的話
    /// 名字會悄悄錯位 —— 而那種錯誤只有開著 VoiceOver 才聽得出來。
    func inkColorName(for color: Color) -> String {
        let target = inkPalette().first { Color(hex: $0.hex) == color }
        guard let key = target?.key else {
            return localizationManager.localized("custom_color")
        }
        return localizationManager.localized(key)
    }

    /// 要求外層改綁到另一則筆記。
    ///
    /// 不能自己 `self.notebook = target` —— `notebook` 是
    /// `$store.notebooks[index]` 的 Binding，寫進去等於把「目前這則筆記」
    /// 在陣列裡的那一格覆蓋成目標筆記：原本那則的紀錄直接消失，
    /// 陣列還會出現兩筆相同 id，畫面隨即整片空白。
    public var onRequestSwitch: ((NotebookDocument) -> Void)?

    public init(
        notebook: Binding<NotebookDocument>,
        onRequestSwitch: ((NotebookDocument) -> Void)? = nil
    ) {
        self._notebook = notebook
        self.onRequestSwitch = onRequestSwitch
        var initialPage = 0
        if let targetPageStr = ProcessInfo.processInfo.environment["KAIRUMO_AUTO_OPEN_PAGE"],
           let targetPage = Int(targetPageStr), targetPage >= 0 && targetPage < notebook.wrappedValue.pageCount {
            initialPage = targetPage
        }
        let initialDrawing = NotebookStore.shared.loadDrawing(notebookId: notebook.wrappedValue.id, pageIndex: initialPage)
        self._currentDrawing = State(initialValue: initialDrawing)
        self._currentPageIndex = State(initialValue: initialPage)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 設定檔即將切換：這一刻 `ProfileContext` 還是舊的，存下去的位置才對（見 `ProfileManager`）。
            // 放在這裡而不是接在下面那串修飾子後面：那一串已經長到再加一個編譯器就放棄型別推論。
            ProfileWillSwitchSaver { saveCurrentPageDrawing() }

            // 1. 頂部自訂主工作列（返回首頁、筆記結構、打字/手繪切換、標題、頁面切換、匯出與列印）
            editorTopBar

            // 2. 🌟 實體模式專屬工具列（手繪模式 vs 打字文書處理模式）
            //
            // **只有「上」這個位置畫在這裡**（S-261b）。左／右／下由
            // `canvasWithToolbar` 貼在畫布旁邊，收合則完全不畫 ——
            // 那時只剩浮動的工具丸。
            //
            // 可移動是刻意的：工具列頂部固定時，**左撇子與橫向書寫會擋手**。
            if effectiveToolbarMode == .draw {
                if !isMinimalistCanvasActive && toolbarSettings.placement == .top {
                    drawingToolbar
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                            removal: .opacity
                        ))
                }
            } else {
                wordModeToolbar
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity
                    ))
            }

            // 3. 尺規旋轉與量測輔助列（若尺規開啟時顯示）
            if isRulerActive {
                rulerControlBar
            }

            // 4. 若目前筆記有已錄音音檔，顯示音訊播放控制條
            if notebook.hasRecording, let audioPath = notebook.recordingAudioPath {
                audioPlaybackBar(fileName: audioPath)
            }

            // 5. 若目前正在進行或暫停錄音，顯示即時錄音波形橫條
            if audioManager.status == .recording || audioManager.status == .paused {
                liveRecordingBar
            }

            // 5b. 套索貼上膠囊與物件剪下／複製／貼上工具列：
            // 排在頂部工具列下方、畫布滾動視圖上方，不覆蓋畫布頂端內容，也避免觸控被底層 PKCanvasView 攔截。
            lassoPastePill
            objectPastePill

            // 6. 核心編輯工作區（包含左側筆記結構欄與右側畫布區）
            GeometryReader { geo in
                let metrics = layoutMetrics(width: Float(geo.size.width))
                if isTabletopMode {
                    // 立起雙屏模式：上方顯示主要畫布／預覽區，下方為沉浸式觸控工具盤
                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            canvasWorkArea

                            HStack(spacing: 6) {
                                Image(systemName: "laptopcomputer.and.ipad")
                                    .font(.system(size: 11, weight: .bold))
                                Text(L("posture_tabletop_mode"))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .systemBackground).opacity(0.85))
                            .cornerRadius(12)
                            .padding(8)
                        }
                        .frame(height: max(geo.size.height * 0.55, 180))

                        Divider()

                        tabletopControlDeck
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .secondarySystemBackground))
                    }
                } else {
                    HStack(spacing: 0) {
                        if showStructureSidebar && metrics.sidebarIsInline {
                            let width = resolvedSidebarWidth(total: geo.size.width)
                            notebookStructureSidebar
                                .frame(width: width)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            sidebarResizeHandle(total: geo.size.width, current: width)
                        }

                        // 手寫與打字**共用同一塊畫布**：紙張樣板、置中、可用區域框線、
                        // 文字方塊與其他物件都在這裡。
                        //
                        // **打字模式不可以換成 `WordDocumentEditorView`。** 那條路換掉的
                        // 是整塊工作區，結果：
                        //   1. 樣板消失 —— 選了「橫線筆記」，切到文字卻是全白頁
                        //   2. 頁面不置中（固定 760pt 寬、可橫向捲動），可用區域框線也沒了
                        //   3. 畫布上的文字方塊物件層不在樹裡，切回手繪後那些方塊
                        //      點不動、拖不動
                        // 這三個問題在 22fbc58 修過一次（撤掉 Word 模式），e479503 又把它
                        // 「恢復」回來，同樣的症狀原封不動地回來。
                        //
                        // 文書排版的工具（`WordToolbarView`）仍在工具列上，操作的是
                        // 這塊畫布上的文字方塊。
                        //
                        // 寬度要**釘在剩下的空間**：A3 橫式這類大頁面的畫布理想寬度比螢幕大，
                        // 不釘的話整塊工作區（連同工具列）被撐寬、右邊的工具被切到螢幕外。
                        canvasWorkArea
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .clipped()
                            // 「頁面置中」指的是置中在**這一塊**（側欄右邊剩下的空間），
                            // 不是整個視窗 —— 介面測試要量得到它。
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("editor.workspace")
                    }
                    .onAppear {
                        DispatchQueue.main.async { editorAvailableWidth = geo.size.width }
                    }
                    .onChange(of: geo.size.width) { newValue in
                        DispatchQueue.main.async { editorAvailableWidth = newValue }
                    }
                    .sheet(isPresented: Binding(
                        get: { showStructureSidebar && !metrics.sidebarIsInline },
                        set: { if !$0 { showStructureSidebar = false } }
                    )) {
                        resizableSheet { notebookStructureSidebar }
                    }
                }
            }
            .background { editorKeyboardShortcuts }
            // 實體鍵盤快捷鍵（見 AppCommands.swift）。
            .onReceive(NotificationCenter.default.publisher(for: AppCommand.toggleEditorMode)) { _ in
                transitionToMode((editorMode == .draw) ? .type : .draw)
            }
            .onReceive(NotificationCenter.default.publisher(for: AppCommand.selectTool)) { note in
                guard let index = note.object as? Int,
                      EditorToolType.shortcutOrder.indices.contains(index) else { return }
                selectEditorTool(EditorToolType.shortcutOrder[index])
            }
            .onReceive(NotificationCenter.default.publisher(for: AppCommand.textFormat)) { note in
                guard let command = note.object as? TextFormatCommand else { return }
                handleTextFormatCommand(command)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // 🌟 響應式極簡畫布模式：單一懸浮點 / 快捷氣泡（掛在最外層視窗，不受畫布縮放與單頁/連續模式影響）
            if effectiveToolbarMode == .draw && isMinimalistCanvasActive {
                FloatingToolPill(
                    isExpanded: $isFloatingPillExpanded,
                    currentToolIcon: selectedTool.iconName,
                    currentColorHex: selectedColor.toHex() ?? "#000000",
                    currentStrokeWidth: strokeWidth,
                    toolboxTitle: localizationManager.localized("minimal_toolbox"),
                    expandLabel: localizationManager.localized("expand_minimal_toolbox"),
                    collapseLabel: localizationManager.localized("collapse_minimal_toolbox"),
                    exitMinimalLabel: localizationManager.localized("exit_canvas_minimal_mode"),
                    onRestore: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            isMinimalistCanvasActive = false
                            isFloatingPillExpanded = true
                        }
                    }
                ) {
                    AnyView(minimalToolboxContent)
                }
                .padding(20)
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let guidance = watchdog.activeGuidance {
                ContextGuidanceHUDView(
                    item: guidance,
                    onPerformAction: {
                        guidance.action?()
                    },
                    onDismiss: {
                        guidance.onDismiss?()
                        watchdog.dismissGuidance()
                    }
                )
                .padding(.top, 54)
                .zIndex(99999)
            }
        }
        .onChange(of: editorMode) { newMode in
            watchdog.notifyModeSwitch(to: newMode)
        }
        .background {
            // 實體鍵盤 Esc 鍵支援一鍵退出畫布極簡模式
            if isMinimalistCanvasActive {
                Button("") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        isMinimalistCanvasActive = false
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .allowsHitTesting(false)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        // 軟體鍵盤應覆蓋視窗底部，而不是重新排版整個編輯器。否則鍵盤每次
        // 出現／消失都會改變 GeometryReader 高度，畫布和物件跟著跳動。
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        // Apple Pencil 雙擊要切回「最後用過的筆刷」（工作項 S-67），
        // 所以每次換工具都要把筆刷記下來。橡皮擦與套索不算筆刷。
        .onChange(of: selectedTool) { tool in
            DispatchQueue.main.async {
                if tool == .lasso, lastObservedTool != .lasso {
                    previousTool = lastObservedTool
                }
                if tool.isBrush { lastBrushTool = tool }
                lastObservedTool = tool
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppCommand.proInkDidChange), perform: handleProInkDidChange)
        .onReceive(NotificationCenter.default.publisher(for: AppCommand.notebookPackageChanged), perform: handleNotebookPackageChanged)
        // 範例有改動、使用者要離開（見 `requestLeave`）。
        .alert(
            localizationManager.localized("sample_leave_title"),
            isPresented: $showSampleLeaveDialog
        ) {
            Button(localizationManager.localized("sample_leave_keep")) { finishSampleLeave(.keep) }
            Button(localizationManager.localized("sample_leave_copy")) { finishSampleLeave(.saveCopy) }
            Button(localizationManager.localized("sample_leave_discard"), role: .destructive) { finishSampleLeave(.discard) }
            Button(localizationManager.localized("cancel"), role: .cancel) { afterSampleLeave = nil }
        } message: {
            Text(localizationManager.localized("sample_leave_message"))
        }
        .onChange(of: notebook.id) { _ in
            DispatchQueue.main.async {
                // 外層換綁之後才會走到這裡，這時 notebook 已經是新的那一則。
                currentPageIndex = 0 // state-entry: 初始開啟筆記正門
                // 換到的這一本若是範例，同樣先備份到暫存區。
                store.beginSampleSession(notebook.id)
                MainThreadStallMonitor.shared.breadcrumb("open notebook \(notebook.id.prefix(8))")
                FocusSyncController.shared.setFocus(notebook.id)
                activeInkStore.clearAllCoreBaselines()
                activeInkStore.clearAllPendingCoreFlush()
                continuousCanvases.invalidateCachedDrawings()
                coreInkWork?.cancel()
                coreInkWork = nil
                loadCurrentPage()
                sanitizeUnderInkObjects()
                initialNotebookSnapshot = notebook
                initialPageInk.removeAll()
                pageOrigins = nil
                captureInitialPageState(page: 0, drawing: currentDrawing)
                PageThumbnailRenderer.invalidateAll()
            }
        }
        .background(
            // 用實際量到的寬度決定要不要展開結構欄。
            // 原本看 horizontalSizeClass，但在 fullScreenCover 剛推上來的那一瞬間
            // 它可能還回報 compact，於是 iPad 上時開時不開。
            GeometryReader { geo in
                Color.clear.onAppear {
                    DispatchQueue.main.async { autoOpenSidebarIfWideEnough(width: geo.size.width) }
                }
            }
        )
        .onAppear {
            configureLassoCallbacks(forPage: currentPageIndex)
            sanitizeTextAttachments()
            sanitizeUnderInkObjects()
            // 舊版同步留下的錯位名單（堆疊順序、鎖定記在別頁的頁碼下）就地修好；
            // 放置貼紙時跨頁拖曳未換頁留下的超出邊界幽靈物件自動歸入實際頁面。
            let realigned = notebook.realignPageKeyedObjectLists()
            let repaired = notebook.repairOutOfBoundsObjects()
            if realigned || repaired { commitNotebook() }
            // 範例：打開時的內容先備份到暫存區，改動等離開時再決定（見 `requestLeave`）。
            // 在上面的整理之後（整理不算使用者的改動）、設焦點之前（暫存期間不走焦點通道）。
            store.beginSampleSession(notebook.id)
            // 開著的這一本走焦點通道（秒同步）與區網直連。
            store.activeNotebookId = notebook.id
            if let targetPageStr = ProcessInfo.processInfo.environment["KAIRUMO_AUTO_OPEN_PAGE"],
               let targetPage = Int(targetPageStr), targetPage >= 0 && targetPage < notebook.pageCount {
                currentPageIndex = targetPage // state-entry: 模式切換保持頁碼 // state-entry: 外部跳頁初始化正門
            }
            loadCurrentPage()
            objectHistory.reset(to: notebook)
            if isCollaborating { ensureCollabPageIds() }
            collabSync.reset(to: notebook)
            // 製圖用的紙（三視圖、等角、作圖步驟…）一打開就選好「圖學」筆組。
            if paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex)) {
                applyEditorTool(.drafting)
            }
            MacWindowTitle.apply()
            // 擷取剛打開筆記本時的初始狀態（提供一鍵恢復初始狀態功能）
            if initialNotebookSnapshot == nil {
                initialNotebookSnapshot = notebook
                captureInitialPageState(page: currentPageIndex, drawing: currentDrawing)
            }
            // 進到編輯器時也亮一次：第一次開的人要知道自己在哪個模式。
            flashModeBadge()
        }
        .onDisappear {
            // **先存檔、再放掉焦點。** 顛倒的話，存檔通知到達時已經沒有焦點筆記本，
            // 離開前最後一筆編輯不會被焦點通道推出去。
            saveCurrentPageDrawing()
            // **不在主執行緒上等寫入做完。** 原本這裡 `coreInkQueue.sync {}` —— 套件寫入慢的時候
            // （文件庫在 iCloud 資料夾、筆跡多）主執行緒整個卡住（卡頓記錄：停在 flushPendingCoreInk 之後）。
            // 改成排在寫入佇列後面：前面的寫入一定先做完，焦點通道才放掉這一本（它接著會把套件推上雲端）。
            let leavingId = notebook.id
            afterCoreInkWrites {
                if store.activeNotebookId == leavingId {
                    store.activeNotebookId = nil
                    FocusSyncController.shared.setFocus(nil)
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                saveCurrentPageDrawing()
                // 進背景：向系統要一點時間讓寫入佇列做完，而不是在主執行緒上等（同上）。
                finishCoreInkInBackground()
            } else if phase == .active {
                // 從背景切回前景時，檢查同步是否已更新這本筆記
                activeInkStore.clearAllCoreBaselines()
                loadCurrentPage()
                PageThumbnailRenderer.invalidateAll()
            }
        }
        .sheet(isPresented: $showShareSheet) { erasedView {
            if let data = exportPdfData {
                ShareActivityView(
                    data: data,
                    filename: "\(notebook.displayTitle()).\(exportFileExtension)")
            }
        } }
        .sheet(isPresented: $showSaveDialog) { erasedView {
            if let data = exportPdfData {
                SaveToFilesView(
                    data: data,
                    filename: "\(notebook.displayTitle()).\(exportFileExtension)")
            }
        } }
        .sheet(isPresented: $showStickerLibrary) { resizableSheet {
            StickerLibraryView { drawing in
                // 拿不到畫布或 UI 測試模擬無畫布時提示使用者
                let noCanvas = ProcessInfo.processInfo
                    .environment["KAIRUMO_UITEST_NO_CANVAS"] == "1"
                guard !noCanvas else {
                    showCanvasNotice(localizationManager.localized("insert_needs_canvas"))
                    return
                }

                // 放置貼紙的浮層（拖曳、縮放、旋轉、確認）畫在物件層裡，而**手寫模式下
                // 物件層不吃觸控**（見 `objectLayer(forPage:)`）。原本這裡切到手寫模式，
                // 於是浮層上的「放置」按鈕根本按不到 —— 點下去變成在畫布上畫了一個點。
                // 要切就切到打字模式，浮層才碰得到；確認後貼紙也是物件，同樣要在這個模式下才能動。
                transitionToMode(.type)

                // 計算貼紙置中位置：若拿得到 canvasView 則以可視區為準，否則以紙張中心為準
                let targetCenter: CGPoint
                if let canvas = canvasView, canvas.bounds.width > 50, canvas.bounds.height > 50 {
                    targetCenter = CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY)
                } else {
                    targetCenter = CGPoint(x: PageGeometry.width / 2.0, y: PageGeometry.height / 2.0)
                }

                let b = drawing.bounds
                let baseW = max(70, min(b.width > 0 ? b.width : 160, 260))
                let baseH = max(70, min(b.height > 0 ? b.height : 160, 260))

                // 若為自動化測試環境，直接蓋印以相容非互動 headless 測試流程
                if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                    insertStickerObject(PendingStickerPlacement(
                        drawing: drawing,
                        center: targetCenter,
                        size: CGSize(width: baseW, height: baseH)))
                } else {
                    // 進入互動式貼圖放置模式：使用者可全畫面自由拖曳定位、縮放大小、旋轉角度，滿意後再確認蓋印
                    self.pendingStickerPlacement = PendingStickerPlacement(
                        drawing: drawing,
                        center: targetCenter,
                        size: CGSize(width: baseW, height: baseH),
                        scale: 1.0,
                        rotationDegrees: 0
                    )
                }
            }
        } }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        // 三個修飾詞收在一個 `ViewModifier` 裡。
        //
        // **不是為了好看**：這條鏈已經長到編譯器會放棄的程度 ——
        // 直接把三個攤在這裡，`body` 就會撞上
        // 「unable to type-check this expression in reasonable time」，
        // 而錯誤指的是整條鏈的開頭，看不出是哪一個加上去的。
        .modifier(ImportPickersModifier(
            activeImportSlot: $activeImportSlot,
            importErrorKey: $importErrorKey,
            onImage: { outcome in
                // 存進附件目錄之後再讀回來解碼。先解碼再存的話，一個看起來
                // 像圖但其實壞掉的檔會在畫布上變成一個永遠空白的方塊。
                let url = store.importedFileURL(fileName: outcome.storedName)
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else {
                    importErrorKey = "import_failed_read"
                    return
                }
                insertImageAttachment(image)
            },
            onAudio: { outcome in insertImportedAudio(outcome) },
            onPdf: { outcome in
                pdfToInsert = store.importedFileURL(fileName: outcome.storedName)
            },
            onDocument: { outcome in importDocumentOutcome(outcome) }
        ))
        .sheet(item: Binding(
            get: { pdfToInsert.map(IdentifiedURL.init) },
            set: { if $0 == nil { pdfToInsert = nil } })
        ) { wrapped in
            resizableSheet {
                PdfPageInsertSheet(
                    fileURL: wrapped.url,
                    pageSize: notebook.pageSize,
                    attachmentsDirectory: store.attachmentsDirectory,
                    onImportAll: { pages, skipped in insertPdfPagesAsNotebookPages(pages, skipped: skipped) },
                    onPickSingle: { image in insertImageAttachment(image) }
                )
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let item = newItem,
                   let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        insertImageAttachment(img)
                        selectedPhotoItem = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showMathCalculator) { resizableSheet {
            MathCalculatorSheet(
                onInsertFormula: { exprText, cardImage in
                    insertImageAttachment(cardImage, mathFormula: exprText)
                },
                onInsertEditableText: { formulaText in
                    insertFormulaText(formulaText)
                }
            )
        } }
        .sheet(isPresented: $showShapeStudio) { resizableSheet {
            ShapeStudioView { shapes, connections in
                if notebook.shapeAttachments == nil { notebook.shapeAttachments = [] }
                if notebook.connectionAttachments == nil { notebook.connectionAttachments = [] }
                for shape in shapes {
                    var placed = shape
                    placed.pageIndex = currentPageIndex
                    notebook.shapeAttachments?.append(placed)
                    if let data = try? JSONEncoder().encode(placed),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "shape", itemDict: dict)
                    }
                }
                for connection in connections {
                    var placed = connection
                    placed.pageIndex = currentPageIndex
                    notebook.connectionAttachments?.append(placed)
                    if let data = try? JSONEncoder().encode(placed),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "connection", itemDict: dict)
                    }
                }
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        } }
        .sheet(isPresented: $showTableStudio) { resizableSheet {
            TableStudioView { created in
                var table = created
                table.pageIndex = currentPageIndex
                let targetX = max(PageGeometry.printableInset, (PageGeometry.width - table.width) / 2)
                let baseOffsetY = max(PageGeometry.printableInset, canvasContentOffset.y + 120)
                let existingCount = notebook.tableAttachments?.filter { $0.pageIndex == currentPageIndex }.count ?? 0
                table.x = targetX
                table.y = min(PageGeometry.height - 200, baseOffsetY + CGFloat(existingCount * 40))
                if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                notebook.tableAttachments?.append(table)
                activeSelectedObjectId = table.id
                selectedObjectIds = [table.id]
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(table),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
            }
            .frame(minWidth: 540)
        } }
        .sheet(item: $editingTable) { target in resizableSheet {
            TableStudioView(editing: target) { updated in
                guard let index = notebook.tableAttachments?
                    .firstIndex(where: { $0.id == updated.id }) else { return }
                // 位置原地保留：使用者只是改了裡面的內容。
                var table = updated
                table.x = notebook.tableAttachments?[index].x ?? table.x
                table.y = notebook.tableAttachments?[index].y ?? table.y
                notebook.tableAttachments?[index] = table
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(table),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
            }
            .frame(minWidth: 540)
        } }
        .sheet(isPresented: $showChartStudio) { resizableSheet {
            ChartStudioView { chartSpec, chartImage in
                insertImageAttachment(chartImage, chartSpecJSON: chartSpec.encodedJSON())
            }
        } }
        // 重新編修既有的圖表。帶著原本的規格進去，使用者看到的是自己當初
        // 輸入的數字 —— 而不是一張只能刪掉重做的圖。
        .sheet(item: $editingChartAttachmentId) { identifier in resizableSheet {
            ChartStudioView(editing: identifier.spec) { updatedSpec, updatedImage in
                replaceChartAttachment(id: identifier.id, spec: updatedSpec, image: updatedImage)
            }
        } }
        // 重新編修算式卡片：回到原生的計算視窗，帶入原始輸入的算式
        .sheet(item: $editingMathAttachmentId) { target in resizableSheet {
            MathCalculatorSheet(
                initialFormula: target.formula,
                onInsertFormula: { exprText, cardImage in
                    replaceMathAttachment(id: target.id, formula: exprText, image: cardImage)
                },
                onInsertEditableText: { formulaText in
                    replaceMathAttachment(id: target.id, formula: formulaText, image: nil)
                    insertFormulaText(formulaText)
                }
            )
        } }
        .sheet(isPresented: $showNoteIntelligence) { resizableSheet {
            NoteIntelligenceSheet(
                // 走核心的 markdown 匯出：打字內容、表格、轉錄文字都在裡面，
                // 而且與匯出看到的是同一份文字 —— 另外湊一份「給模型看的」
                // 文字的話，摘要會講到使用者匯出時看不到的東西。
                text: notebook.plainText(),
                onInsert: { text in insertQuickTextSnippet(text) }
            )
        } }
        .sheet(isPresented: $showWordStudio) { resizableSheet {
            WordTextStudioView(attachment: $newTextDraft) { created in
                if notebook.textAttachments == nil {
                    notebook.textAttachments = []
                }
                if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == created.id }) {
                    notebook.textAttachments?[idx] = created
                } else {
                    notebook.textAttachments?.append(created)
                }
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(created),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                }
            }
        } }
        .sheet(isPresented: $showLinkPreviewSheet) { resizableSheet {
            LinkPreviewSheet { linkItem in
                if notebook.linkAttachments == nil {
                    notebook.linkAttachments = []
                }
                // 頁次要在這裡補。少了它，連結卡片一律落在第 1 頁 ——
                // 在第 5 頁按「插入連結」，畫面上什麼也不會出現。
                // 其他插入路徑（圖片、表格、形狀、3D）都有這一行，只有連結漏了。
                var placed = linkItem
                placed.pageIndex = currentPageIndex
                notebook.linkAttachments?.append(placed)
                commitNotebook()
                if let data = try? JSONEncoder().encode(placed),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "link", itemDict: dict)
                }
            }
        } }
        .sheet(isPresented: $showProColorPicker) { resizableSheet {
            ProColorPickerSheet(selectedColor: $selectedColor)
        } }
        .sheet(isPresented: $show3DStudio) { resizableSheet {
            Model3DStudioView { new3DAttachment in
                if notebook.model3DAttachments == nil {
                    notebook.model3DAttachments = []
                }
                var att = new3DAttachment
                att.pageIndex = currentPageIndex
                notebook.model3DAttachments?.append(att)
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(att),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                }
            }
        } }
        .sheet(isPresented: $showAssetLibrarySheet) { resizableSheet {
            AssetLibraryView { image, _ in
                insertImageAttachment(image)
            }
        } }
        .sheet(isPresented: $showAudioPicker) { resizableSheet {
            AudioInsertPickerSheet { recording in
                insertAudioAttachment(recording)
            }
        } }
        .sheet(isPresented: $showCollaborationSheet) { resizableSheet {
            CollaborationSheet(notebookId: notebook.id)
        } }
        // 分享面板要等預覽**收乾淨之後**再開。
        //
        // 在預覽還在收起的時候直接 `showShareSheet = true`，SwiftUI 會把
        // 第二個 sheet 吞掉 —— 使用者按了「匯出」，畫面關掉，然後什麼都沒發生。
        // 所以預覽只留下一個意願旗標，真正的呈現放在 `onDismiss`。
        .sheet(
            isPresented: $showExportPreview,
            onDismiss: {
                if wantsShareAfterPreview {
                    wantsShareAfterPreview = false
                    showShareSheet = true
                }
            }
        ) {
            ExportPreviewSheet(
                data: exportPdfData ?? Data(),
                fileExtension: exportFileExtension,
                onExport: { wantsShareAfterPreview = true })
        }
        // 四個「按下去之後還要再做一個動作」的功能，第一次用時給一則提示
        // （使用者回報：不知道該怎麼操作）。內容與 id 都來自核心，
        // 兩端同一份 —— 鍵不一樣的話，在一台裝置上關掉的提示會在另一台冒出來。
        .featureHint("hint.comment_pin", trigger: isPlacingCommentPin)
        .featureHint("hint.refine_sketch", trigger: showSketchRefineBar)
        .featureHint("hint.tabletop", trigger: isTabletopMode)
        .featureHint("hint.recognize", trigger: isRecognisingHandwriting)
        .sheet(isPresented: $showToolbarCustomization) {
            NavigationStack { ToolbarCustomizationView() }
        }
        .sheet(isPresented: $showPalmThresholdSheet) {
            // 改完立刻套進仲裁器。存了卻要重開筆記本才生效的話，
            // 使用者會以為設定沒有存到，然後再調一次。
            PalmThresholdSheet { palmRejection.applyStoredThresholds() }
        }
        .sheet(isPresented: $showAdvancedPenSettingsSheet) {
            AdvancedPenSettingsSheet()
        }
        .onReceive(collaborationManager.oplogReceived) { event in
            handleRemoteOplog(event)
        }
        // 協同的事件掛在一個透明視圖上：直接接在這條修飾鏈後面，型別檢查會超時。
        .background(collabEventSink)
        .sheet(isPresented: $showThemeToolsSheet) { resizableSheet {
            ThemeSpecificToolsView(
                currentBrushColor: $selectedColor,
                isGoldenSpiralActive: $isGoldenSpiralOverlay,
                isRuleOfThirdsActive: $isRuleOfThirdsOverlay,
                onInsertCardImage: { image in
                    insertImageAttachment(image)
                },
                onInsertTextCard: { text in
                    insertQuickTextSnippet(text)
                }
            )
        } }
        .alert(localizationManager.localized("rename_note"), isPresented: $showRenameAlert) {
            TextField(localizationManager.localized("note_title"), text: $renameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                if !renameText.isEmpty {
                    store.renameNotebook(id: notebook.id, newTitle: renameText)
                    if let updated = store.notebooks.first(where: { $0.id.caseInsensitiveCompare(notebook.id) == .orderedSame }) {
                        notebook = updated
                    }
                }
            }
        }
        // 確認視窗掛在自己的隱藏載體上（見 `revertAlertHost`）。
        .background(revertAlertHost)
        .background(Color.clear.alert(localizationManager.localized("clear_page"), isPresented: $showClearConfirmAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("clear_confirm"), role: .destructive) {
                currentDrawing = PKDrawing()
                let pid = (notebook.pageIds != nil && currentPageIndex < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[currentPageIndex] : nil
                activeInkStore.forceSetDrawing(currentDrawing, for: currentPageIndex, pageId: pid)
                store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
                // 專業筆刷的筆畫另存，一起清掉。
                ProInkStore.save([], in: store.drawingsDirectory, notebookId: notebook.id, page: currentPageIndex)
                (canvasView as? AdaptiveCanvasView)?.proLayer?.reload()
            }
        } message: {
            Text(localizationManager.localized("clear_page_confirm"))
        })
        .background(Color.clear.alert(localizationManager.localized("mic_permission_title"), isPresented: $audioManager.showPermissionAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {
                audioManager.showPermissionAlert = false
            }
            Button(localizationManager.localized("open_settings")) {
                audioManager.openSystemSettings()
            }
        } message: {
            Text(localizationManager.localized("mic_permission_msg"))
        })
        .background(Color.clear.alert(localizationManager.localized("delete_page"), isPresented: $showDeletePageAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("delete_page"), role: .destructive) {
                if let idx = pageToDeleteIndex {
                    deletePage(at: idx)
                }
            }
        } message: {
            Text(String(format: localizationManager.localized("delete_page_confirm_msg"), (pageToDeleteIndex ?? 0) + 1))
        })
        .background(Color.clear.alert(localizationManager.localized("edit_root_folder"), isPresented: $showRenameRootFolderAlert) {
            TextField(localizationManager.localized("root_folder"), text: $rootFolderRenameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                store.renameRootFolder(newName: rootFolderRenameText)
            }
        })
        .background(Color.clear.alert(localizationManager.localized("new_subfolder"), isPresented: $showNewFolderAlert) {
            TextField(localizationManager.localized("folder_name"), text: $newFolderNameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {
                newFolderParentId = nil
            }
            Button(localizationManager.localized("confirm")) {
                _ = store.createFolder(name: newFolderNameText, parentId: newFolderParentId)
                newFolderNameText = ""
                newFolderParentId = nil
            }
        })
        .alert(localizationManager.localized("rename_folder"), isPresented: Binding(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField(localizationManager.localized("folder_name"), text: $folderRenameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {
                folderToRename = nil
            }
            Button(localizationManager.localized("confirm")) {
                if let f = folderToRename {
                    store.renameFolder(id: f.id, newName: folderRenameText)
                }
                folderToRename = nil
            }
        }
        .sheet(isPresented: $showMoveNotebookSheet) {
            moveNotebookSheetContent
        }
    }

    private func handleProInkDidChange(_ note: Notification) {
        guard (note.object as? String) == notebook.id.lowercased() else { return }
        objectHistory.breakCoalescing()
        proInkDirty = true
        thumbnailRevision += 1
        noteInkEdited()
    }

    private func handleNotebookPackageChanged(_ note: Notification) {
        let changedId = note.object as? String
        guard changedId == nil || changedId?.caseInsensitiveCompare(notebook.id) == .orderedSame else { return }
        // 排好但還沒開始的寫入先停下：它手上的是同步之前的筆跡，現在寫出去會把剛匯入的合併結果蓋掉
        // （別台的筆畫還會被當成「這台擦掉的」記進帳本）。等已經在背景佇列裡跑的寫入做完、
        // 磁碟定下來，再合併重讀。
        coreInkWork?.cancel()
        coreInkWork = nil
        afterCoreInkWrites { reloadAfterExternalChange() }
    }

    /// 別台同步進來之後重讀，**但不丟掉這台還沒寫出去的筆跡**。
    ///
    /// 原本直接 `loadCurrentPage()`：磁碟上是匯入當下的樣子，使用者在那之前零點幾秒寫的字還在
    /// 待寫名單裡 —— 畫面先被換成沒有那幾筆的版本（字消失），待寫名單接著把舊版寫回磁碟，
    /// 下一輪同步再讀回來（字又出現），別台剛同步過來的筆畫反而被蓋掉。連續模式更糟：
    /// 每一頁的畫布整個重建，整片空白一下、寫到一半的那一筆直接不見。
    private func reloadAfterExternalChange() {
        activeInkStore.clearAllCoreBaselines()
        inkDiskBaselines.removeAll()
        continuousCanvases.invalidateCachedDrawings()
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        PageGeometry.use(format: notebook.pageFormatId)
        // 還沒寫出去的頁：以磁碟（已含別台的內容）為底，補回這台寫的、拿掉這台擦的。
        for item in activeInkStore.pendingCoreFlushJobs(notebook: notebook) {
            if pageDisplayMode == .single && item.pageIndex == currentPageIndex { continue }
            _ = mergedWithDisk(page: item.pageIndex, local: item.drawing, updateBaseline: false)
        }
        if pageDisplayMode == .single {
            // 畫布上的才是最新的 —— 但只在它顯示的**就是這一頁**時。剛換頁（新增頁、翻頁）那一瞬間
            // 畫布可能還是上一頁：拿它來合併，上一頁的字會被當成這一頁「還沒寫出去的筆畫」寫進這一頁。
            let live = canvasShowsCurrentPage ? (canvasView?.drawing ?? currentDrawing) : currentDrawing
            let merged = mergedWithDisk(page: currentPageIndex, local: live, updateBaseline: true)
            // 只換綁定：畫布由 `updateUIView` 換上（正在寫的話等抬筆，並補上那一筆）。
            currentDrawing = merged
            lastStrokeCount = merged.strokes.count
            currentPageHeight = notebook.height(forPage: currentPageIndex)
            (canvasView as? AdaptiveCanvasView)?.whenInkIdle { [weak canvas = canvasView as? AdaptiveCanvasView] in
                canvas?.proLayer?.reload()
            }
        }
        if activeInkStore.hasPendingCoreFlush { scheduleCoreInkFlush() }
        // 整份從套件重新讀進來（別台同步）：以新內容為復原基準，不登記成這台的一步；
        // 也不是這台的修改，不能當成協同修改送出去。
        objectHistory.reset(to: notebook)
        collabSync.refreshShadow(from: notebook)
        continuousInkReloadGeneration += 1
        continuousObjectGeneration += 1
        thumbnailRevision += 1
        PageThumbnailRenderer.invalidateAll()
    }

    /// 目前的畫布顯示的是不是 `currentPageIndex` 那一頁（畫布換頁要等下一輪 `updateUIView`）。
    var canvasShowsCurrentPage: Bool {
        guard let coordinator = canvasView?.delegate as? CanvasRepresentable.Coordinator else { return false }
        return coordinator.parent.proInk?.pageIndex == currentPageIndex
    }

    /// 磁碟上的這一頁，加上 `local` 比基準多寫的、減去 `local` 比基準少的（這台寫了／擦了、還沒寫出去的）。
    ///
    /// 結果與磁碟不同時登記成待寫，讓合併結果落盤並追加進套件。`updateBaseline` 為 true 時把基準推到
    /// 這一次讀到的磁碟內容；同一頁在同一輪會被算兩次的（連續模式：先算待寫、頁面自己再算一次畫面）
    /// 第一次不要推，兩次才會用同一個基準、得到同一個結果。
    func mergedWithDisk(page: Int, local: PKDrawing, updateBaseline: Bool) -> PKDrawing {
        let disk = store.loadDrawing(notebookId: notebook.id, pageIndex: page)
        let merged = InkMerge.merged(disk: disk, local: local, base: inkDiskBaselines[page])
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        if updateBaseline { inkDiskBaselines[page] = disk }
        if merged != disk {
            if updateBaseline || activeInkStore.isPendingCoreFlush(for: page, pageId: pid) {
                activeInkStore.updateDrawing(merged, for: page, pageId: pid)
                activeInkStore.markPendingCoreFlush(for: page, pageId: pid)
            }
        } else if activeInkStore.isPendingCoreFlush(for: page, pageId: pid) {
            activeInkStore.clearPendingCoreFlush(for: page, pageId: pid)
        }
        return merged
    }

    @ViewBuilder
    private var moveNotebookSheetContent: some View {
        resizableSheet {
            MoveNotebookSheet(notebookId: notebookToMoveId ?? notebook.id)
        }
    }

    /// 「一鍵恢復初始狀態」的確認視窗載體。
    ///
    /// 每個 `.alert` 要各掛在自己的 view 上：同一個 view 上疊多個 `.alert` 時只有一個會出現，
    /// 其餘的永遠不跳 —— 按了「恢復初始狀態」沒反應、確認視窗根本沒出現就是這樣。
    /// 抽成獨立屬性也讓 `body` 的型別推導不至於過長。
    private var revertAlertHost: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert(localizationManager.localized("revert_to_initial_state"), isPresented: $showRevertConfirmAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("revert_confirm_action"), role: .destructive) {
                    // 丟掉還沒寫的筆跡，並等背景佇列裡已排的寫入做完 —— 不然它們在還原之後才落盤，
                    // 把還原好的頁又蓋回編輯過的樣子。
                    coreInkWork?.cancel()
                    coreInkWork = nil
                    activeInkStore.clearAllPendingCoreFlush()
                    afterCoreInkWrites { revertToInitialState() }
                }
            } message: {
                Text(localizationManager.localized("revert_to_initial_state_confirm"))
            }
    }

    /// 還原到剛打開這本筆記時的樣子（頁序、每一頁的內容與物件）。
    private func revertToInitialState() {
                    if var snapshot = initialNotebookSnapshot {
                        if let origins = pageOrigins {
                            // 調整過頁面結構：先把逐頁檔案（筆跡、專業筆畫、同步記帳）排回原本的頁碼，
                            // 這次新增的頁拿掉；刪掉的頁由下面的初始狀態寫回。
                            let current = notebook
                            let padded = origins + [Int?](repeating: nil, count: max(0, current.pageCount - origins.count))
                            store.restorePageFiles(notebookId: current.id, origins: padded)
                            // 頁面 id 跟著頁走：還在的頁沿用目前的 id；被刪過又還原的頁換新 id ——
                            // 刪除可能已經同步出去（`RemovePage` 寫了就撤不回），沿用舊 id 會再被刪一次。
                            if let currentIds = current.pageIds {
                                snapshot.pageIds = (0..<snapshot.pageCount).map { original in
                                    padded.firstIndex(of: original).flatMap { $0 < currentIds.count ? currentIds[$0] : nil }
                                        ?? UUID().uuidString.lowercased()
                                }
                                // 這次新增的頁：同步那邊可能已經有它了，記成刪除。
                                SyncDeletedPages.record(
                                    padded.indices.filter { padded[$0] == nil && $0 < currentIds.count }.map { currentIds[$0] },
                                    current.id)
                            }
                            pageOrigins = nil
                            objectHistory.pageStructureChanged(snapshot, manager: historyUndoManager)
                        }
                        currentPageIndex = min(currentPageIndex, max(0, snapshot.pageCount - 1)) // state-entry: 恢復快照頁碼修正
                        activeInkStore.clearAllCoreBaselines()
                        continuousCanvases.invalidateCachedDrawings()
                        notebook = snapshot
                        restoreInitialPages()
                        let pid = (notebook.pageIds != nil && currentPageIndex < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[currentPageIndex] : nil
                        currentDrawing = activeInkStore.drawing(for: currentPageIndex, pageId: pid)
                        if let canvas = canvasView {
                            // 程式指派 drawing 會讓復原堆疊裡的項目全部失效：整個清掉，
                            // 免得按復原吃掉點擊、什麼都沒發生。
                            canvas.drawing = currentDrawing
                            canvas.undoManager?.removeAllActions()
                            (canvas as? AdaptiveCanvasView)?.proLayer?.reload()
                        }
                        commitNotebook()
                        continuousReloadGeneration += 1
                        thumbnailRevision += 1
                        showCanvasNotice(localizationManager.localized("revert_done"))
                        activeSelectedObjectId = nil
                        inlineEditingTextId = nil
                        editingTextId = nil
                        selectedShapeIds = []
                        selectedConnectionId = nil
                        selectedObjectIds = []
                        PageThumbnailRenderer.invalidateAll()
                    }
    }

    /// 寬度足夠時自動展開結構欄（只做一次，之後尊重使用者自己的開關）。
    /// iPhone 這種窄寬度維持收合 —— 280pt 的側欄會把畫布擠到不能用。
    private func autoOpenSidebarIfWideEnough(width: CGFloat) {
        guard !didAutoOpenSidebar else { return }
        didAutoOpenSidebar = true
        if width >= 700 || Self.isTabletOrDesktopDevice {
            showStructureSidebar = true
        }
    }

    /// 畫布內容寬度與 `CanvasRepresentable` 的 `max(bounds.width, 800)` 保持一致。
    func updateCanvasContentWidth(_ viewWidth: CGFloat) {
        // 與 AdaptiveCanvasView 一致：畫布內容寬度就是視圖寬度
        let width = max(viewWidth, 320)
        guard abs(width - canvasContentWidth) > 0.5 else { return }
        DispatchQueue.main.async {
            self.canvasContentWidth = width
        }
    }

    // MARK: - 次世代動態模式傳送門 (The Dynamic Mode Portal)
    /// 原本收一個 `compact` 旗標，而 `DynamicPortalIsland` **根本沒有緊湊
    /// 變體**，所以呼叫端傳 true 或 false 畫出來完全一樣。拿掉假旗標讓
    /// 「沒有緊湊版面」這件事看得見 —— 真要做的時候會是一次刻意的改動。
    func editorModeSwitcher() -> some View {
        DynamicPortalIsland(
            editorMode: $editorMode,
            contextualState: contextualPortalState,
            onModeChange: { mode in
                let targetPage = currentPageIndex
                continuousProgrammaticScrollUntil = Date().addingTimeInterval(0.8)
                transitionToMode(mode)
                currentPageIndex = targetPage // state-entry: 模式切換保持頁碼
                continuousReportedPage = targetPage
            },
            onExitContextual: {
                endTextFormatSession()
                withAnimation(.easeInOut(duration: 0.18)) {
                    inlineEditingTextId = nil
                    activeInlineInkBlockId = nil
                }
            }
        )
        // **`children: .contain` 不是裝飾。**
        //
        // 只掛識別字的話，這座島會變成一個「單一無障礙元素」，裡面那兩顆
        // 藥丸（`portal.draw` / `portal.type`）就**整個從無障礙樹上消失**
        // —— 實測：編輯器上掃得到 `editor.mode`（而且有兩個），一個
        // `portal.*` 都沒有。
        //
        // 那不只是測試找不到按鈕：VoiceOver 的使用者也點不到「手寫／打字」
        // 這兩顆，他只會聽到一個沒有作用的容器。
        //
        // `.contain` 讓這一層仍然是可定位的群組（規格要 `editor.mode`），
        // 同時保留子元素。首頁那四個容器踩過同一件事（S-263）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.mode")
    }

    /// 就地編輯只是被工具列暫時借走焦點（方塊還在這一頁）。
    var isInlineEditingSuspendedOnThisPage: Bool {
        guard let id = suspendedInlineTextId else { return false }
        return notebook.textAttachments?.contains(where: { $0.id == id && $0.pageIndex == currentPageIndex }) == true
    }

    /// 手機寬度（核心的版面級別，與 Android 同一條規則）。工具列在這個寬度下改成單列捲動。
    var isCompactEditorWidth: Bool {
        layoutMetrics(width: Float(editorAvailableWidth)).sizeClass == .compact
    }

    var effectiveToolbarMode: EditorMode {
        if editorMode == .draw {
            if inlineEditingTextId != nil || isInlineEditingSuspendedOnThisPage {
                return .type
            }
            return .draw
        } else {
            if activeInlineInkBlockId != nil {
                return .draw
            }
            return .type
        }
    }

    /// 打字模式中的手繪區塊仍使用同一張頁面畫布，只是暫時把輸入權交給墨跡層。
    var isInlineInkEditing: Bool {
        editorMode == .type && activeInlineInkBlockId != nil
    }

    var effectiveCanvasMode: EditorMode {
        EditorCanvasInputPolicy.effectiveMode(
            mainMode: editorMode,
            isInlineInkEditing: isInlineInkEditing)
    }

    var isCanvasInkActive: Bool {
        EditorCanvasInputPolicy.acceptsInk(
            mainMode: editorMode,
            isInlineInkEditing: isInlineInkEditing)
    }

    private var contextualPortalState: DynamicPortalIsland.ContextualPortalState? {
        if editorMode == .draw && inlineEditingTextId != nil {
            return .editingTextInDrawMode(title: "\(localizationManager.localized("tool_text")) • \(localizationManager.localized("edit"))")
        } else if editorMode == .type && activeInlineInkBlockId != nil {
            return .drawingInTextMode(title: "\(localizationManager.localized("handwriting_mode")) • \(localizationManager.localized("edit"))")
        }
        return nil
    }

    /// 物件層當前是否處於可互動或活躍狀態（對齊 Android EditorStateManager 之統一職責守衛）。
    var isObjectInteractionActive: Bool {
        guard !isInlineInkEditing else { return false }
        if editorMode == .type { return true }
        return inlineEditingTextId != nil
            || editingTextId != nil
            || activeSelectedObjectId != nil
            || !selectedObjectIds.isEmpty
            || !selectedShapeIds.isEmpty
            || isPlacingPasteObject
            || lockPromptId != nil
    }

    /// 統一編輯器主模式切換狀態機（對齊 Android EditorStateManager 零回退守衛）。
    func transitionToMode(_ targetMode: EditorMode, animated: Bool = true) {
        guard editorMode != targetMode else { return }
        saveCurrentPageDrawing()
        if targetMode == .type {
            canvasView?.resignFirstResponder()
        } else {
            // 切換回手繪模式時，自動收合打字與物件焦點（對齊 Android EditorStateManager 零回退守衛）
            inlineEditingTextId = nil
            activeInlineInkBlockId = nil
            editingTextId = nil
            activeSelectedObjectId = nil
            selectedObjectIds.removeAll()
            selectedShapeIds.removeAll()
            selectedConnectionId = nil
        }
        endTextFormatSession()
        if animated {
            withAnimation(.easeInOut(duration: 0.18)) {
                editorMode = targetMode // state-entry: 切換模式的唯一正門
            }
        } else {
            editorMode = targetMode // state-entry: 切換模式的唯一正門
        }
        flashModeBadge()
    }

    /// 統一頁面切換正門：存上一頁筆跡、邊界檢查、切換狀態、載入新頁筆跡、檢查製圖紙筆組。
    func switchToPage(_ targetPage: Int) {
        let bounded = min(max(0, targetPage), max(0, notebook.pageCount - 1))
        guard bounded != currentPageIndex else { return }
        saveCurrentPageDrawing()
        currentPageIndex = bounded // state-entry: 切換頁面的唯一正門
        loadCurrentPage()
        if paperUsesDrafting(paperId: notebook.paperId(forPage: bounded)) {
            applyEditorTool(.drafting)
        }
    }

}

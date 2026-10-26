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
    /// 最近一次真的寫進磁碟的筆跡（頁次 + 內容）。切換模式時用來判斷「這一頁其實沒變」，
    /// 不必每次都同步序列化整頁筆跡（筆跡多的頁面，那一下就是點物件時的卡頓）。
    @State var lastPersistedInk: (page: Int, drawing: PKDrawing)? = nil
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
    @State private var inkTouchWork: DispatchWorkItem? = nil
    /// 已經寫進核心 `.padnote` 的筆跡基準線，依頁次保存。
    ///
    /// `PKCanvasView` 在一筆畫尚未離筆時就會連續回報 drawing 變更。核心的 ink log
    /// 是 append-only；若每次回報都 append，會把同一筆的半成品寫成好幾筆。
    /// 因此畫布仍即時寫 `.drawing`，核心套件則停筆後用這個基準線只補新增筆畫。
    @State var coreInkBaselines: [Int: PKDrawing] = [:]
    /// 每一頁「最後一次與磁碟一致」的筆跡（讀進來的、或寫出去的）。同步重讀時用它分辨
    /// 哪些筆畫是這台還沒寫出去的（見 `mergedWithDisk`）。放在參照型別裡：每一筆都會更新，
    /// 寫 `@State` 的話整個編輯器每一筆重算一次。
    @State private var inkDiskBaselines = InkDiskBaselines()
    /// 連續模式「只重讀筆跡、不重建畫布」的世代（別台同步進來時加一）。
    /// `continuousReloadGeneration` 會整個重建每一頁的畫布 —— 只留給還原、頁面結構改變這種真的要重來的情況。
    @State private var continuousInkReloadGeneration = 0
    /// 連續模式「只重建物件層」的世代（刪除、調整物件圖層之後）。
    @State private var continuousObjectGeneration = 0
    @State var pendingCoreInk: [Int: PKDrawing] = [:]
    /// 筆跡單一擁有者（架構審視 P1）：以 pageId 識別，消除多份副本與空白覆蓋。
    @State private var inkStore: PageInkStore? = nil
    private var activeInkStore: PageInkStore {
        if let inkStore, inkStore.notebookId == notebook.id {
            return inkStore
        }
        let created = PageInkStore(notebookId: notebook.id, store: store)
        created.primeAllPages(notebook: notebook)
        inkStore = created
        return created
    }
    @State private var coreInkWork: DispatchWorkItem? = nil
    /// 這一批待寫筆畫最早的那一筆的時間。見 `scheduleCoreInkFlush` 的上限說明。
    @State private var coreInkFirstPendingAt: Date? = nil
    @State var canvasView: PKCanvasView? = nil
    @State var currentPageHeight: CGFloat = PageGeometry.height
    /// 掌拒（工作項 S-45）。判定規則走核心，與 Android 同一份。
    @State private var palmRejection = PalmRejectionCoordinator()
    @State var showToolbarCustomization = false
    @State var showPalmThresholdSheet = false
    @State var showAdvancedPenSettingsSheet = false
    @State private var showExportPreview = false
    @State private var wantsShareAfterPreview = false
    @StateObject var lasso = LassoSelection()
    var hasLassoSelection: Bool {
        lasso.hasSelection
    }
    @State private var showExtendedBanner: Bool = false

    @State private var canvasZoomScale: CGFloat = 1.0
    @State var canvasContentOffset: CGPoint = .zero

    // 實體工具列狀態
    @State var selectedTool: EditorToolType = .pen
    /// 自訂頁面尺寸的輸入畫面。
    @State private var showCustomPageSize = false
    /// 立體輔助（草圖拉伸、三視圖、剖面）。
    @State private var showSolidStudio = false
    @State private var showDraftingToolbox = false
    @State private var draftExportShare: SharedFile?
    @State var previousTool: EditorToolType?
    @State private var lastObservedTool: EditorToolType = .pen

    /// 有東西正懸在畫布上等著放下（工作項 S-68）。
    ///
    /// 一定要有這個回饋：拖放看不見目標的話，使用者不知道放開會發生什麼事，
    /// 也分不出「這裡不能放」與「放了但沒反應」。
    @State private var isCanvasDropTargeted: Bool = false

    /// 按著側鍵之前選的是哪一支。放開時回到它。
    ///
    /// `nil` 表示「這一次的橡皮擦不是側鍵切出來的」—— 使用者自己在工具列
    /// 選的橡皮擦，不能因為他碰了一下側鍵就被換掉。
    @State private var penHeldTool: EditorToolType? = nil

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
    @State private var insertSpaceDragAccum: CGFloat = 0.0
    
    @State var eraserMode: EraserMode = .stroke
    @State var pixelEraserWidth: CGFloat = 20.0
    
    @State private var showLassoColorPicker: Bool = false

    // 彈窗與輔助狀態
    @State var showRenameAlert: Bool = false
    @State var renameText: String = ""
    @State private var showShareSheet: Bool = false
    /// 匯出之後要開的是**儲存對話框**（而不是分享面板）。
    @State private var showSaveDialog: Bool = false
    @State var showClearConfirmAlert: Bool = false
    @State private var exportPdfData: Data? = nil
    /// 這一次匯出的副檔名。
    ///
    /// 原本分享表一律叫 `<標題>.pdf` —— 選「匯出圖片」拿到的是一個
    /// **副檔名寫著 pdf、內容卻是 PNG** 的檔案，收到的人打不開，
    /// 使用者看到的是「我選了圖片，它給我 PDF」（實機回報過）。
    @State private var exportFileExtension: String = "pdf"

    // 圖片、算式、圖表、文字與連結狀態
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State var showPhotoPicker: Bool = false
    /// 統一管理自檔案匯入的插槽，避免 SwiftUI 多個 .fileImporter 競爭互斥
    @State var activeImportSlot: FfiImportSlot? = nil
    /// 已經收進來、正在讓使用者挑頁的那份 PDF。
    @State private var pdfToInsert: URL? = nil
    /// 匯入失敗的語系鍵。非空就跳提示。
    @State private var importErrorKey: String = ""
    @State var showStickerLibrary: Bool = false
    @State private var pendingStickerPlacement: PendingStickerPlacement? = nil
    @State var showMathCalculator: Bool = false
    @State var showChartStudio: Bool = false
    @State var showTableStudio: Bool = false
    @State var showShapeStudio: Bool = false
    @State private var showLayerPanel: Bool = false
    /// 畫布中單一選取物件的唯一識別碼（互斥單選：同一時間最多只有一個物件處於編輯/選取狀態）
    @State var activeSelectedObjectId: String? = nil
    /// 正在顯示「解除鎖定」鈕的鎖定物件（點了鎖頭或點了鎖定的物件）。見 `lockedObjectPrompt`。
    @State private var lockPromptId: String? = nil
    /// 一鍵恢復初始狀態（捨棄進入編輯器後的所有修改）
    @State var initialNotebookSnapshot: NotebookDocument? = nil
    /// 範例有改動、使用者要離開時：問要存檔、另存還是放棄（見 `requestLeave`）。
    @State private var showSampleLeaveDialog = false
    /// 使用者選完之後要做的事（回首頁或切換到另一本）。
    @State private var afterSampleLeave: (() -> Void)?
    @State var initialPageDrawings: [Int: PKDrawing] = [:]
    /// 每一頁第一次載入時的專業筆畫（圖學筆畫、專業筆刷）與「已擦除」名單 ——
    /// 「恢復初始狀態」要連它們一起還原，不然圖學筆記本裡畫的線一條都不會少。
    @State private var initialPageInk: [Int: InitialPageInk] = [:]

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
    @State private var selectedShapeIds: Set<String> = []
    /// 被選取的連接線（連接線不在 `selectedShapeIds` 裡 —— 它不是形狀，沒有群組與對齊）。
    @State private var selectedConnectionId: String? = nil
    @State private var editingShapeId: String? = nil
    @State private var editingConnectionId: String? = nil
    /// 拖曳連接點拉線時的預覽。
    @State private var connectionDraft: (page: Int, start: CGPoint, current: CGPoint)? = nil
    /// 正在重新編修的表格。
    @State private var editingTable: NoteTableAttachment? = nil
    @State private var editingAttachmentId: String? = nil
    /// 正在重新編修的圖表。帶著規格一起，`sheet(item:)` 才有東西可以開。
    @State private var editingChartAttachmentId: ChartEditTarget? = nil
    /// 正在重新編修的算式卡片。
    @State private var editingMathAttachmentId: MathEditTarget? = nil

    // Word 文字排版、網址預覽與專業調色狀態
    @State var showWordStudio: Bool = false
    /// 摘要與待辦（工作項 S-20）。
    @State var showNoteIntelligence: Bool = false
    @State private var editingTextId: String? = nil
    /// 隨點隨打就地輸入狀態（連動 TextAttachmentItemView 的焦點與鍵盤）
    @State var inlineEditingTextId: String? = nil
    /// 打字工具列「正在格式化哪一個方塊」。
    ///
    /// 只靠 `inlineEditingTextId` 不夠：Mac 上一按工具列的按鈕，文字欄位在
    /// 滑鼠按下那一刻就交出焦點 → 就地編輯結束 → `inlineEditingTextId` 變 nil，
    /// 等到按鈕的動作真正執行時，目標已經不見了。以前的退路是「這一頁第一個
    /// 文字方塊」—— 所以字級、清單符號時好時壞，而且常常改到頁首的標題方塊。
    /// 這個值只在使用者明確換目標（點別的物件、點空白處、換頁、換模式）時才清掉。
    @State private var textFormatTargetId: String? = nil
    /// 焦點是「被工具列搶走」而不是使用者主動結束：格式套用完要把游標還回去。
    @State var suspendedInlineTextId: String? = nil
    /// 就地編輯的選取範圍。用 `@State` 持有參考而**不訂閱** —— 游標每動一下都會發布，
    /// 整個編輯器跟著重算會很卡；只有工具列訂閱它。
    @State var textSelectionTracker = TextSelectionTracker()
    /// 沒有任何文字方塊可套用時，工具列改的是下一個新方塊的樣式
    /// （Word 的「插入點格式」），而不是憑空在頁面上生出一個方塊。
    @State private var pendingTypingStyle = NoteTextAttachment(
        id: "pending-typing-style", text: "", backgroundColorHex: "clear", hasBorder: false)
    @State private var lastAddedTextId: String? = nil
    // 文字復原/重做堆疊（供文字模式與文字框使用）
    /// 畫布物件（圖片、文字方塊、形狀、表格…）的復原紀錄，與筆跡登記在同一個 `UndoManager`
    /// 上 —— 一次復原就照發生的先後退回，不分是筆跡還是物件（見 `CanvasHistory.swift`）。
    @State var objectHistory = CanvasObjectHistory()
    /// 即時協同的物件合併（欄位層級 LWW，見 `CollabSync.swift`）。參考型別、不訂閱。
    @State private var collabSync = CollabObjectSync()
    /// 每一頁已經同步過的筆畫 id（逐筆增刪的比對基準）。
    @State private var collabInkLedger = CollabInkLedger()
    /// 文字方塊內容的字元 CRDT（兩人同時在同一個方塊打字，設計 §8.3）。
    @State private var collabTextHub = CollabTextHub()
    /// 加入房間、補發不完整時的整份狀態往來（設計 §7）。
    @State private var collabStateSync = CollabStateSync()
    /// 畫布還沒掛上視窗時的備用（正常情況下用畫布的 `undoManager`）。
    @State private var fallbackUndoManager = UndoManager()
    @ObservedObject var watchdog = InteractionWatchdog.shared


    // 單頁模式排版與縮放狀態（全頁 vs 適寬，支援手動放大縮小與捲動）
    enum SinglePageFitMode: String {
        case fitWidth
        case fitPage
    }
    @State private var singlePageFitMode: SinglePageFitMode = .fitWidth
    @State private var singlePageManualZoom: CGFloat = 1.0
    @State private var singlePagePinchBaseZoom: CGFloat? = nil

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
    @State private var magneticGuideActive: Bool = false
    @State private var magneticGuideStart: CGPoint = .zero
    @State private var magneticGuideEnd: CGPoint = .zero

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
    @State private var marqueeStart: CGPoint? = nil
    @State private var marqueeCurrent: CGPoint? = nil
    /// 連續框選：新框到的、點到的物件加進選取，不取代原本的（見 `ObjectMarquee.combined`）。
    @State private var marqueeAdditive: Bool = false
    @State var selectedObjectIds: Set<String> = []
    /// 已知的物件 id，用來認出「剛插入的」。`nil` 代表尚未建立基準（開啟筆記當下）。
    @State private var knownObjectIds: Set<String>? = nil
    /// 整組拖曳時的即時位移。每一幀都寫回筆記的話，拖一次會存幾十次檔。
    @State private var groupDragOffset: CGSize = .zero
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
    @State private var isGoldenSpiralOverlay: Bool = false
    @State private var isRuleOfThirdsOverlay: Bool = false

    // 線上多人即時協同狀態
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @State var showCollaborationSheet: Bool = false
    @State private var isApplyingRemoteUpdate: Bool = false
    @State private var lastStrokeCount: Int = 0
    // 第二階段協同防護與討論狀態
    @State var isPlacingCommentPin: Bool = false
    @State private var selectedCommentPinId: String? = nil
    @State private var deletedAttachmentBackup: (type: String, data: Any)? = nil

    var isCollaborating: Bool {
        collaborationManager.status != .disconnected || !collaborationManager.currentRoomId.isEmpty
    }


    // 筆記主模式：手繪 (Draw) vs 鍵盤打字 (Type)
    @State var editorMode: EditorMode = .draw
    /// 軟體鍵盤避讓高度（Word 級打字流暢滾動視窗，避免畫面跳動或文字被遮擋）
    @State private var keyboardHeight: CGFloat = 0
    /// 模式徽章是不是正顯示著。切換模式時亮起，過幾秒自己淡掉。
    ///
    /// **不常駐**（工作項 S-62）：它原本一直蓋在畫布右上角，330pt 寬，
    /// 等於永遠有一塊紙面被說明文字佔著。模式本身在工具列的切換器上看得到，
    /// 徽章要說的是「這個模式下手勢會怎樣」—— 那是切換當下才需要的提示。
    @State private var modeBadgeVisible: Bool = false
    /// 用來取消上一次的淡出排程：連續切換兩次時，第一次的排程不該把
    /// 第二次剛亮起的徽章關掉。
    @State private var modeBadgeToken: Int = 0

    /// 工具切換快顯提示：點擊任一筆刷或工具時在工具列緊鄰處彈出提示工具名稱
    @State var activeToolToast: (name: String, icon: String)? = nil
    @State var toolToastToken: Int = 0

    /// 畫布上的提示（例如「超出可列印範圍」）。nil 代表沒有要說的話。
    @State private var canvasNotice: String?
    @State private var canvasNoticeToken: Int = 0

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
    @State private var isMagneticSnapActive: Bool = false

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
                    .onAppear { editorAvailableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { newValue in
                        editorAvailableWidth = newValue
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
            if tool == .lasso, lastObservedTool != .lasso {
                previousTool = lastObservedTool
            }
            if tool.isBrush { lastBrushTool = tool }
            lastObservedTool = tool
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
            // 外層換綁之後才會走到這裡，這時 notebook 已經是新的那一則。
            currentPageIndex = 0
            // 換到的這一本若是範例，同樣先備份到暫存區。
            store.beginSampleSession(notebook.id)
            MainThreadStallMonitor.shared.breadcrumb("open notebook \(notebook.id.prefix(8))")
            FocusSyncController.shared.setFocus(notebook.id)
            coreInkBaselines.removeAll()
            pendingCoreInk.removeAll()
            continuousCanvases.invalidateCachedDrawings()
            coreInkWork?.cancel()
            coreInkWork = nil
            loadCurrentPage()
            sanitizeUnderInkObjects()
            initialNotebookSnapshot = notebook
            initialPageDrawings.removeAll()
            initialPageInk.removeAll()
            pageOrigins = nil
            captureInitialPageState(page: 0, drawing: currentDrawing)
            PageThumbnailRenderer.invalidateAll()
        }
        .background(
            // 用實際量到的寬度決定要不要展開結構欄。
            // 原本看 horizontalSizeClass，但在 fullScreenCover 剛推上來的那一瞬間
            // 它可能還回報 compact，於是 iPad 上時開時不開。
            GeometryReader { geo in
                Color.clear.onAppear { autoOpenSidebarIfWideEnough(width: geo.size.width) }
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
                currentPageIndex = targetPage
            }
            loadCurrentPage()
            objectHistory.reset(to: notebook)
            if isCollaborating { ensureCollabPageIds() }
            collabSync.reset(to: notebook)
            // 製圖用的紙（三視圖、等角、作圖步驟…）一打開就選好「圖學」筆組。
            if paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex)) {
                selectedTool = .drafting
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
                coreInkBaselines.removeAll()
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
                PdfPageInsertSheet(fileURL: wrapped.url) { image in
                    insertImageAttachment(image)
                }
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
        coreInkBaselines.removeAll()
        inkDiskBaselines.removeAll()
        continuousCanvases.invalidateCachedDrawings()
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        PageGeometry.use(format: notebook.pageFormatId)
        // 還沒寫出去的頁：以磁碟（已含別台的內容）為底，補回這台寫的、拿掉這台擦的。
        for (page, pending) in pendingCoreInk {
            if pageDisplayMode == .single && page == currentPageIndex { continue }
            _ = mergedWithDisk(page: page, local: pending, updateBaseline: false)
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
        if !pendingCoreInk.isEmpty { scheduleCoreInkFlush() }
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
    private var canvasShowsCurrentPage: Bool {
        guard let coordinator = canvasView?.delegate as? CanvasRepresentable.Coordinator else { return false }
        return coordinator.parent.proInk?.pageIndex == currentPageIndex
    }

    /// 磁碟上的這一頁，加上 `local` 比基準多寫的、減去 `local` 比基準少的（這台寫了／擦了、還沒寫出去的）。
    ///
    /// 結果與磁碟不同時登記成待寫，讓合併結果落盤並追加進套件。`updateBaseline` 為 true 時把基準推到
    /// 這一次讀到的磁碟內容；同一頁在同一輪會被算兩次的（連續模式：先算待寫、頁面自己再算一次畫面）
    /// 第一次不要推，兩次才會用同一個基準、得到同一個結果。
    private func mergedWithDisk(page: Int, local: PKDrawing, updateBaseline: Bool) -> PKDrawing {
        let disk = store.loadDrawing(notebookId: notebook.id, pageIndex: page)
        let merged = InkMerge.merged(disk: disk, local: local, base: inkDiskBaselines[page])
        if updateBaseline { inkDiskBaselines[page] = disk }
        if merged != disk {
            if updateBaseline || pendingCoreInk[page] != nil {
                pendingCoreInk[page] = merged
            }
        } else if pendingCoreInk[page] != nil {
            pendingCoreInk[page] = nil
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
                    pendingCoreInk.removeAll()
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
                        currentPageIndex = min(currentPageIndex, max(0, snapshot.pageCount - 1))
                        coreInkBaselines.removeAll()
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
    private func updateCanvasContentWidth(_ viewWidth: CGFloat) {
        // 與 AdaptiveCanvasView 一致：畫布內容寬度就是視圖寬度
        let width = max(viewWidth, 320)
        guard abs(width - canvasContentWidth) > 0.5 else { return }
        canvasContentWidth = width
    }

    // MARK: - 3-1. 🌟 Office Word / Google Docs 居中標準文件紙張編輯區
    private var wordDocumentArea: AnyView {
        AnyView(wordDocumentAreaContent)
    }

    private var wordDocumentAreaContent: some View {
        WordDocumentEditorView(
            notebook: $notebook,
            pageIndex: currentPageIndex,
            activeTextDraft: Binding(
                get: { activeTextAttachment ?? NoteTextAttachment(pageIndex: currentPageIndex) },
                set: { updated in
                    if notebook.textAttachments == nil { notebook.textAttachments = [] }
                    if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == updated.id }) {
                        notebook.textAttachments?[idx] = updated
                    } else {
                        notebook.textAttachments?.append(updated)
                    }
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                }
            ),
            activeInlineInkBlockId: $activeInlineInkBlockId,
            onCommit: {
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            },
            onInsertTable: {
                let table = NoteTableAttachment(pageIndex: currentPageIndex, x: 40, y: 120, rows: 3, cols: 3)
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
            },
            onInsertImage: { showPhotoPicker = true },
            onInsertImageFile: { triggerFileImport(.image) },
            onPasteClipboardImage: { pasteScreenshotOrClipboardImage() }
        )
    }

    /// 飛梭工具盤的中心：長按叫出的放在落點（往內收，整圈都要在畫面裡），
    /// 工具列按鈕叫出的放在畫面中央。
    private func radialMenuCenter(in geo: GeometryProxy) -> CGPoint {
        let size = geo.size
        guard let anchor = radialMenuAnchor else {
            return CGPoint(x: size.width / 2, y: min(size.height / 2, max(170, size.height * 0.42)))
        }
        let frame = geo.frame(in: .global)
        let margin: CGFloat = 160  // 半徑 118 + 按鈕半徑 36 + 一點邊
        let local = CGPoint(x: anchor.x - frame.minX, y: anchor.y - frame.minY)
        return CGPoint(
            x: min(max(local.x, margin), max(margin, size.width - margin)),
            y: min(max(local.y, margin), max(margin, size.height - margin)))
    }

    /// 畫布上長按（筆尖或單指落下停住不動）叫出飛梭工具盤。
    ///
    /// 飛梭的意義就在「不用把手移到工具列」：手在哪裡，工具盤就開在哪裡。
    /// 正在拖曳套索選取、打字或行內編輯時不攔，讓原本的操作繼續。
    private func openRadialMenuFromPress(at windowPoint: CGPoint) -> Bool {
        guard isCanvasInkActive, editorMode == .draw, !showRadialMenu else { return false }
        if selectedTool == .lasso && (lasso.isDraggingSelection || lasso.hasSelection) { return false }
        if selectedTool == .maskingTape { return false }
        radialMenuAnchor = windowPoint
        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            showRadialMenu = true
        }
        return true
    }

    /// 徑向飛輪快捷工具盤（螢幕座標，不隨頁面縮放，蓋在畫布之上）。
    @ViewBuilder
    private var radialMenuLayer: some View {
        if showRadialMenu {
            GeometryReader { geo in
                RadialMarkMenuView(
                    isPresented: $showRadialMenu,
                    centerPoint: radialMenuCenter(in: geo),
                    items: [
                        RadialMenuItem(id: "pen", icon: "pencil.tip", labelKey: "tool_pen", color: .accentColor) {
                            selectedTool = .pen
                        },
                        RadialMenuItem(id: "highlighter", icon: "highlighter", labelKey: "tool_highlighter", color: .orange) {
                            selectedTool = .highlighter
                        },
                        RadialMenuItem(id: "eraser", icon: "eraser", labelKey: "tool_eraser", color: .red) {
                            selectedTool = .eraser
                        },
                        RadialMenuItem(id: "lasso", icon: "lasso", labelKey: "tool_lasso", color: .purple) {
                            selectedTool = .lasso
                        },
                        RadialMenuItem(id: "undo", icon: "arrow.uturn.backward", labelKey: "undo", color: .blue) {
                            performUndo()
                        },
                        RadialMenuItem(id: "redo", icon: "arrow.uturn.forward", labelKey: "redo", color: .blue) {
                            performRedo()
                        },
                        RadialMenuItem(id: "color", icon: "paintpalette.fill", labelKey: "pro_color", color: .pink) {
                            // 色相環是掛在工具列按鈕上的 popover，從這裡開不一定有錨點；改開完整調色面板。
                            showProColorPicker = true
                        },
                        RadialMenuItem(id: "stabilizer", icon: "waveform.path.ecg", labelKey: "stab_title", color: .green) {
                            strokeStabilizer = (strokeStabilizer > 0) ? 0.0 : 0.5
                        }
                    ]
                )
            }
            .transition(.opacity)
        }
    }

    /// 畫布工作區。抽出來並加上 AnyView 邊界 —— 這一塊（畫布 + 附件圖層 +
    /// 圖釘 + 浮動列）原本整棵樹的型別都被編進 body 的 mangled 名稱裡。
    private var canvasWorkArea: AnyView {
        // 兩條完全獨立的路。連續模式不碰整頁模式的任何一行 ——
        // 那一段綁著存檔、協同、掌拒與套索，是最沒本錢壞掉的地方。
        let canvas: AnyView = switch pageDisplayMode {
        case .single:     AnyView(singlePageWorkArea)
        case .continuous: AnyView(continuousPagesContent)
        }
        // **提示條掛在兩種模式共用的這一層。**
        //
        // 它原本只長在 `singlePageWorkArea` 裡，於是連續模式下
        // `showCanvasNotice(...)` 等於什麼都沒做 —— 而那正是它要補的那個洞
        // （失敗時沒有任何回饋）。「有時候會提示、有時候不會」比一直沒提示
        // 更難查。
        return AnyView(
            ZStack(alignment: .bottom) {
                placed(canvas)
                if let notice = canvasNotice {
                    canvasNoticeBanner(notice)
                }
            }
            .overlay { objectEditPanels }
            .overlay { radialMenuLayer }
            .overlay(alignment: .top) {
                // 🌟 草圖智慧修飾浮動控制面板（兩種頁面模式共用）
                if showSketchRefineBar {
                    sketchRefineFloatingBar
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            .sheet(isPresented: $showDraftingToolbox) {
                DraftingToolbox(
                    notebookId: notebook.id,
                    frameSupported: frameSupportedForCurrentPage,
                    onPickTool: { tool in
                        // 鏡射、陣列要處理套索選的那批線：在離開套索之前把它帶過來。
                        if tool.needsSelection {
                            guard !lasso.proIds.isEmpty else {
                                showCanvasNotice(localizationManager.localized("draft_edit_need_selection"))
                                return
                            }
                            DraftingState.shared.editSelection = lasso.proIds
                        }
                        selectedTool = .drafting
                        DraftingState.shared.tool = tool
                        DraftToolController.shared.reset(layer: (canvasView as? AdaptiveCanvasView)?.proLayer)
                        DraftToolController.shared.refreshHint()
                    },
                    onInsertSymbol: { insertDraftKit($0) },
                    onInsertFrame: { insertDraftFrame(thirdAngle: $0) },
                    onPlaceInstrument: { kind in
                        selectedTool = .drafting
                        let center = draftViewportCenter()
                        DraftingState.shared.placeInstrument(kind: kind, center: center, pageWidth: PageGeometry.size.width)
                    },
                    onRectArray: { rows, cols, dx, dy in applyRectArray(rows: rows, cols: cols, dxMm: dx, dyMm: dy) },
                    onStartPractice: { startPractice(kind: $0) },
                    onExport: { exportDrafting(format: $0) })
            }
            .sheet(item: $draftExportShare) { item in
                ShareItemsSheet(items: [item.url])
            }
            .sheet(isPresented: $showSolidStudio) {
                SolidStudioSheet(
                    pageSize: PageGeometry.size,
                    sketchPolylines: { solidSketchPolylines() },
                    onInsert: { insertSolidSheet($0) })
            }
            .overlay(alignment: .bottomLeading) {
                // 練習題進行中：題目、選項、批改結果（見 DraftingPractice.swift）。
                let isDraftingPaper = paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex))
                if editorMode == .draw && (selectedTool == .drafting || isDraftingPaper) {
                    PracticeCard(
                        layer: { (canvasView as? AdaptiveCanvasView)?.proLayer },
                        onNew: {
                            if let kind = PracticeSession.shared.problem?.kind { startPractice(kind: kind) }
                        })
                        .padding(12)
                }
            }
            // 圖學：製圖筆組、圖層、吸附（見 DraftingBar.swift）。
            //
            // **佔用版面，不是浮在畫布上。** 原本是 `.overlay`，列疊在頁面最上方，
            // 蓋住頁首標題與題目文字（圖學頁一開頭就是標題）。改成 `safeAreaInset`：
            // 畫布整個往下讓出位置，收合或展開都不會壓到頁面內容。
            // 在圖學專用紙張中保持列位穩定，切換一般畫筆寫筆記時不會突然收合引發整個畫布抖動重繪與觸控延遲。
            .safeAreaInset(edge: .top, spacing: 0) {
                let isDraftingPaper = paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex))
                if editorMode == .draw && (selectedTool == .drafting || isDraftingPaper) {
                    DraftingBar(onOpenSolidStudio: { showSolidStudio = true },
                                onOpenToolbox: { showDraftingToolbox = true },
                                onMarkAngle: { markProtractorReading() })
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .onAppear { if knownObjectIds == nil { knownObjectIds = Set(allObjectIds) } }
            .onChange(of: allObjectIds.count) { _ in placeNewObjectsOnTop() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                if let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = frame.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
        )
    }

    /// 把工具列貼到畫布的哪一邊（S-261b）。
    ///
    /// 「上」由 `body` 的 VStack 畫（它要排在頂部工作列底下），
    /// 這裡只處理左／右／下與收合。分兩處看起來不漂亮，但合併的代價是
    /// 把整個頂部區塊搬進畫布層 —— 那會動到尺規列、播放列與錄音列的順序。
    ///
    /// 收合（`.collapsed`）時完全不畫：那時使用者要的就是只剩浮動工具丸。
    @ViewBuilder
    private func placed(_ canvas: AnyView) -> some View {
        if effectiveToolbarMode != .draw || isMinimalistCanvasActive {
            canvas
        } else {
            switch toolbarSettings.placement {
            case .top, .collapsed:
                canvas
            case .bottom:
                VStack(spacing: 0) {
                    canvas
                    drawingToolbar
                }
            case .left:
                HStack(spacing: 0) {
                    // 直向工具列要能捲 —— 十三顆按鈕在 iPhone 橫放時
                    // 高度不夠，不給捲的話下面幾顆永遠點不到。
                    ScrollView(.vertical) { drawingToolbar }
                        .frame(maxWidth: 96)
                    canvas
                }
            case .right:
                HStack(spacing: 0) {
                    canvas
                    ScrollView(.vertical) { drawingToolbar }
                        .frame(maxWidth: 96)
                }
            }
        }
    }

    /// 整頁模式：**一頁完整顯示，而且置中。**
    ///
    /// # 原本是什麼樣子
    ///
    /// 畫布直接把可用寬度吃滿（`AdaptiveCanvasView.syncContentSize` 用的是
    /// `bounds.width`），而頁面本身只有 800pt。於是右邊多出一塊空白 ——
    /// 那塊空白**在頁面框線之外**，寫上去的東西不會出現在列印結果裡。
    /// 把左側資料夾欄收起來之後那塊空白更大，看起來像畫布破了一個洞。
    ///
    /// 連續模式一直是「縮到剛好放得下」，整頁模式沒跟上。現在兩邊同一套：
    /// 放不下就等比縮小，放得下就放大填滿（有上限）並置中。
    ///
    /// 視窗寬就放大到填滿可用寬度（上限見 `PageViewportLayout.maxFitScale`）。
    private var singlePageWorkArea: some View {
        GeometryReader { outer in
            let availableWidth = max(outer.size.width - 32, 1)
            let availableHeight = max(outer.size.height - 32, 1)
            let widthScale = PageViewportLayout.scale(
                availableWidth: availableWidth,
                pageWidth: PageGeometry.width
            )
            let fitPageScale = min(widthScale, availableHeight / PageGeometry.height)
            let baseScale = (singlePageFitMode == .fitPage) ? fitPageScale : widthScale
            let effectiveScale = max(0.3, min(4.0, baseScale * singlePageManualZoom))
            let scaledW = PageGeometry.width * effectiveScale
            let scaledH = PageGeometry.height * effectiveScale

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                ScaledPageLayout(scale: effectiveScale, unscaledSize: CGSize(width: PageGeometry.width, height: PageGeometry.height)) {
                    canvasWorkAreaContent
                        .frame(width: PageGeometry.width, height: PageGeometry.height)
                        .scaleEffect(effectiveScale, anchor: .topLeading)
                }
                .padding(.bottom, inlineEditingTextId != nil ? keyboardHeight : 0)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("editor.canvas")
                .frame(
                    minWidth: outer.size.width,
                    minHeight: outer.size.height,
                    alignment: .top
                )
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { mag in
                        let base = singlePagePinchBaseZoom ?? singlePageManualZoom
                        if singlePagePinchBaseZoom == nil { singlePagePinchBaseZoom = base }
                        singlePageManualZoom = max(0.3, min(4.0, base * mag))
                    }
                    .onEnded { _ in
                        singlePagePinchBaseZoom = nil
                    }
            )
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            singlePageManualZoom = max(0.4, singlePageManualZoom - 0.15)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            singlePageManualZoom = 1.0
                            singlePageFitMode = (singlePageFitMode == .fitPage) ? .fitWidth : .fitPage
                        }
                    } label: {
                        Text(localizationManager.localized(
                            singlePageFitMode == .fitPage ? "zoom_fit_page" : "zoom_fit_width"))
                            .font(.system(size: 11, weight: .bold))
                            .frame(minWidth: 28)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            singlePageManualZoom = min(3.0, singlePageManualZoom + 0.15)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // 次世代 UI/UX Phase 5: 立起模式觸控工作盤 (Tabletop Studio Control Deck)
    private var tabletopControlDeck: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // 1. 頂部狀態標題與收折按鈕
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "laptopcomputer.and.ipad")
                            .foregroundColor(.accentColor)
                        Text(L("posture_tabletop_mode"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isTabletopMode = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // 2. 常用工具快速點選盤 (Pen / Highlighter / Eraser / Lasso / Radial / Magnetic / Sticky)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                    // 鋼筆
                    Button {
                        selectEditorTool(.pen)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 20))
                            Text(L("tool_pen"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .pen ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .pen ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 螢光筆
                    Button {
                        selectEditorTool(.highlighter)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "highlighter")
                                .font(.system(size: 20))
                            Text(L("tool_highlighter"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .highlighter ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .highlighter ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 橡皮擦
                    Button {
                        selectEditorTool(.eraser)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "eraser")
                                .font(.system(size: 20))
                            Text(L("tool_eraser"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .eraser ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .eraser ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 套索工具
                    Button {
                        selectEditorTool(.lasso)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: selectedTool == .lasso ? "xmark.circle.fill" : "lasso")
                                .font(.system(size: 20))
                            Text(L("tool_lasso"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .lasso ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .lasso ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 徑向飛輪工具盤喚醒 (Radial Menu)
                    Button {
                        radialMenuAnchor = nil
                        showRadialMenu = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "circle.grid.cross")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                            Text(L10n.t("tool_radial_short"))
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // 幾何角度磁吸開關 (Magnetic Snap)
                    Button {
                        isMagneticSnapActive.toggle()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: isMagneticSnapActive ? "magnet.fill" : "magnet")
                                .font(.system(size: 20))
                                .foregroundColor(isMagneticSnapActive ? .blue : .secondary)
                            Text(L("magnetic_snap_ruler"))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(isMagneticSnapActive ? Color.blue.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // 筆跡文字流式錨定 (Sticky Anchor)
                    Button {
                        anchorSelectedStrokesToNearestText()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            Text(L("sticky_anchor_ink"))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // 3. 常用顏色調色板與復原/重做/翻頁
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach([Color.black, Color.blue, Color.red, Color.green, Color.orange, Color.purple], id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Button { performUndo() } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button { performRedo() } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button { addNewPage() } label: {
                            Image(systemName: "plus.square.dashed")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(width: 36, height: 36)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
    }

    /// 畫布底部的提示條。
    ///
    /// 用浮動提示而不是 alert：使用者正在寫字，跳一個要按確定的對話框
    /// 會把筆打斷，而這件事沒有嚴重到值得打斷。
    private func canvasNoticeBanner(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.accentColor)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
        // 測試要認得這條提示 —— 「失敗時有沒有出聲」本身就是要守的行為。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.notice")
    }

    /// 連續頁面模式的工作區。
    private var continuousPagesContent: some View {
        GeometryReader { outer in
            // 頁面是固定的 800 × 1132（P-01），視窗不是。縮到剛好放得下，
            // 不縮的話側欄一開，頁面右半邊就被切掉 —— 而使用者看不出那是
            // 「超出去」還是「畫布壞了」。
            //
            // 視窗比紙張寬就放大到填滿（上限見 `PageViewportLayout.maxFitScale`），
            // 不留兩片灰邊讓畫布看起來被框住。
            let available = max(outer.size.width - 32, 1)
            let fitWidth = PageViewportLayout.scale(
                availableWidth: available, pageWidth: PageGeometry.width)
            let viewport = CGSize(width: available, height: max(outer.size.height - 40, 1))
            let pageSize = CGSize(width: PageGeometry.width, height: currentPageHeight)
            let scale = continuousZoomTarget.map { target -> CGFloat in
                if case .ratio(let value) = target {
                    // 與單頁模式一致：倍率相對於「整頁剛好放進視窗」。
                    let whole = PageViewportLayout.zoomScale(for: .fitPage, viewport: viewport, page: pageSize)
                    return min(max(whole * value, 0.3), 4)
                }
                return PageViewportLayout.zoomScale(for: target, viewport: viewport, page: pageSize)
            } ?? fitWidth
            continuousPages(scale: scale)
                .onAppear { continuousScale = scale }
                .onChange(of: scale) { continuousScale = $0 }
        }
    }

    /// 連續模式的縮放設定。預設貼合頁寬（依視窗寬度響應式縮放，放大上限 200%）。
    @State private var continuousZoomTarget: PageViewportLayout.ZoomTarget? = nil
    @State private var continuousPinchBaseZoom: CGFloat? = nil

    /// 整頁的顯示比例。單頁模式沿用既有的 `singlePageFitMode` / `singlePageManualZoom`（畫布右下角的 −／全頁／＋
    /// 也是它們），連續模式用 `continuousZoomTarget`。倍率一律**相對於「整頁剛好放進視窗」**：100% = 全頁。
    /// 捏合縮放（看某個區域）是另一件事，這裡一併歸位，才不會「選了全頁卻還停在放大的位置」。
    private func applyEditorZoom(_ target: PageViewportLayout.ZoomTarget) {
        if pageDisplayMode == .continuous {
            continuousZoomTarget = target
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            switch target {
            case .fitPage:
                singlePageFitMode = .fitPage
                singlePageManualZoom = 1
            case .fitWidth:
                singlePageFitMode = .fitWidth
                singlePageManualZoom = 1
            case .ratio(let value):
                singlePageFitMode = .fitPage
                singlePageManualZoom = min(max(value, 0.4), 3)
            }
        }
        (canvasView as? AdaptiveCanvasView)?.applyPageZoom(.ratio(1))
    }

    /// 畫布區的「顯示比例」選單：顯示全頁、符合頁寬、實際大小與常用倍率。
    var zoomMenu: some View {
        Menu {
            Button {
                applyEditorZoom(.fitPage)
            } label: {
                Label(localizationManager.localized("zoom_fit_page"), systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .accessibilityIdentifier("editor.zoom.fit_page")
            Button {
                applyEditorZoom(.fitWidth)
            } label: {
                Label(localizationManager.localized("zoom_fit_width"), systemImage: "arrow.left.and.right")
            }
            .accessibilityIdentifier("editor.zoom.fit_width")
            Divider()
            ForEach([50, 75, 125, 150, 200], id: \.self) { percent in
                Button("\(percent)%") { applyEditorZoom(.ratio(CGFloat(percent) / 100)) }
            }
        } label: {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: EditorToolbarMetrics.icon - 3))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 28)
        }
        .help(localizationManager.localized("zoom_menu"))
        .accessibilityLabel(localizationManager.localized("zoom_menu"))
        .accessibilityIdentifier("editor.zoom.menu")
    }

    /// 連續模式：由捲動算出來的焦點頁（`updateFocusedPage` 寫入）。
    ///
    /// 用來分辨 `currentPageIndex` 的變動是「捲動帶來的」還是「程式叫它跳頁」
    /// （點側欄縮圖、上一頁／下一頁、新增頁面…）。後者才要捲過去；
    /// 前者再捲一次會跟使用者的手指打架。
    @State private var continuousReportedPage: Int = -1
    /// 連續模式下已建立的各頁畫布參照與快取，供套索與存檔即時存取焦點頁畫布（Class 包裝避免視圖更新中改 @State 失效）
    @State var continuousCanvases = ContinuousCanvasRegistry()
    /// Pencil 落筆把打字模式切成手繪的時間（那一次切換不捲動，見 `onChange(of: editorMode)`）。
    @State private var pencilModeSwitchAt: Date?
    /// 專業筆畫有未標記的變動（見 `AppCommand.proInkDidChange`）。存檔時不能當成「沒變」略過。
    @State private var proInkDirty = false
    /// 「恢復初始狀態」之後遞增，讓連續模式的每一頁重讀磁碟（見 `ContinuousPageView.reloadGeneration`）。
    @State var continuousReloadGeneration = 0
    /// 側欄縮圖的重繪計數：專業筆畫的變動不在任何 @State 裡，要靠它讓側欄重新算繪。
    @State var thumbnailRevision = 0
    /// 要求連續模式再捲一次到目前頁（頁碼沒變但使用者點了同一頁的縮圖）。
    @State var continuousScrollRequest: Int = 0
    /// 程式捲動進行中。這段時間內捲動中途經過的頁面不算焦點，否則
    /// 「點縮圖跳到第 3 頁」會在途中被第 7 頁的焦點判定打斷，最後停在半路。
    @State var continuousProgrammaticScrollUntil: Date = .distantPast
    /// 連續模式：正在拖曳物件的那一頁。這一頁畫在相鄰頁之上 —— 物件拖過頁界時
    /// 才不會被下一頁的紙蓋住、看起來像消失了。
    @State private var continuousDragPage: Int?
    /// 連續模式目前的縮放。頁與頁之間的間隔（螢幕上 `continuousPageSpacing` 點）
    /// 換算成頁面座標要用它，物件換頁時才落在手指放開的地方。
    @State private var continuousScale: CGFloat = 1
    private static let continuousPageSpacing: CGFloat = 20

    @ViewBuilder
    private func continuousPages(scale: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: Self.continuousPageSpacing) {
                    ForEach(0..<max(1, notebook.pageCount), id: \.self) { index in
                        ScaledPageLayout(scale: scale, unscaledSize: CGSize(width: PageGeometry.width, height: PageGeometry.height)) {
                            ContinuousPageView(
                                pageIndex: index,
                                notebookId: notebook.id,
                                paperId: notebook.paperId(forPage: index),
                                paletteId: notebook.guidePaletteId,
                                store: store,
                                selectedTool: selectedTool,
                                selectedColor: selectedColor,
                                strokeWidth: strokeWidth,
                                isRulerActive: isRulerActive,
                                editorMode: editorMode,
                                eraserMode: eraserMode,
                                pixelEraserWidth: pixelEraserWidth,
                                palmRejection: palmRejection,
                                isObjectActive: isObjectInteractionActive,
                                isFocused: index == currentPageIndex,
                                objectLayer: { objectLayer(forPage: index) },
                                underInkObjectLayer: { AnyView(objectLayer(forPage: index, filter: .underInkOnly)) },
                                overInkObjectLayer: { AnyView(objectLayer(forPage: index, filter: .overInkOnly)) },
                                isUnderInkPointPassThrough: { point, page, event in
                                    isUnderInkPointPassThrough(point: point, page: page, event: event)
                                },
                                onDrawingChanged: { page, updated in
                                    objectHistory.breakCoalescing()
                                    recordDrawingEdit(page: page, drawing: updated)
                                    broadcastDrawingChange(page: page, drawing: updated)
                                },
                                onSelectionChanged: { if !$0 { lasso.clear() } },
                                onReachedPageBottom: { ensureNextPageExists() },
                                // LazyVStack 會建立多頁畫布；不能讓最後建立的頁面覆蓋
                                // `canvasView`，否則貼紙可能蓋到別頁且存檔頁碼也錯。
                                canvasRef: { ref in
                                    continuousCanvases[index] = ref
                                    if index == currentPageIndex {
                                        continuousCanvases.activeCanvas = ref
                                    }
                                    // 同上：不在畫面更新途中改 @State，且只在真的換了才寫。
                                    guard index == currentPageIndex, canvasView !== ref else { return }
                                    DispatchQueue.main.async { canvasView = ref }
                                },
                                onCanvasTap: { location in
                                    focusContinuousPage(index)
                                    handleCanvasDirectTap(at: location, page: index)
                                },
                                onCanvasDoubleTap: { location in
                                    focusContinuousPage(index)
                                    handleCanvasDirectDoubleTap(at: location, page: index)
                                },
                                onPencilTouchBegan: {
                                    focusContinuousPage(index)
                                    handlePencilTouchBegan()
                                },
                                onPenControl: applyPenControl,
                                onImageDropped: { page, providers, location in
                                    acceptImageDrop(providers, at: location, page: page)
                                },
                                onInitialLoaded: { page, loaded in
                                    if pendingCoreInk[page] == nil { inkDiskBaselines[page] = loaded }
                                    captureInitialPageState(page: page, drawing: loaded)
                                },
                                reloadGeneration: continuousReloadGeneration,
                                inkReloadGeneration: continuousInkReloadGeneration,
                                objectGeneration: continuousObjectGeneration,
                                mergeReloaded: { page, live in
                                    let merged = mergedWithDisk(page: page, local: live, updateBaseline: true)
                                    if !pendingCoreInk.isEmpty { scheduleCoreInkFlush() }
                                    return merged
                                },
                                initialDrawing: { page in
                                    let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
                                    return activeInkStore.drawing(for: page, pageId: pid)
                                },
                                notebook: $notebook,
                                onNotebookChanged: {
                                    commitNotebook()
                                    PageThumbnailRenderer.invalidateAll()
                                },
                                onLassoBegan: { pt in
                                    // 在非焦點頁圈：先把焦點（與 currentDrawing）切到這一頁，
                                    // 選取的索引才會對到這一頁的筆畫。
                                    if currentPageIndex != index {
                                        lasso.clear()
                                        focusContinuousPage(index)
                                    } else {
                                        syncDrawingFromCanvas()
                                    }
                                    configureLassoCallbacks(forPage: index)
                                    lasso.begin(at: pt)
                                },
                                onLassoMoved: { pt in
                                    guard index == currentPageIndex else { return }
                                    if lasso.isDraggingSelection {
                                        let lastPt = lasso.dragPoint ?? pt
                                        let delta = CGSize(width: pt.x - lastPt.x, height: pt.y - lastPt.y)
                                        lasso.updateDragPoint(pt)
                                        if let updated = lasso.moveSelected(in: currentDrawing, by: delta) {
                                            currentDrawing = updated
                                            showLassoEdit(updated)
                                        }
                                    } else {
                                        lasso.extend(to: pt)
                                    }
                                },
                                onLassoEnded: {
                                    guard index == currentPageIndex else { return }
                                    let wasDragging = lasso.isDraggingSelection
                                    lasso.finish(in: currentDrawing)
                                    if wasDragging {
                                        recordDrawingEdit(page: index, drawing: currentDrawing)
                                        broadcastDrawingChange(page: index, drawing: currentDrawing)
                                        PageThumbnailRenderer.invalidateAll()
                                    }
                                },
                                onPressAndHold: { point in
                                    guard openRadialMenuFromPress(at: point) else { return false }
                                    focusContinuousPage(index)
                                    return true
                                },
                                lassoDecoration: {
                                    AnyView(lassoSelectionDecoration(
                                        zoom: 1, offset: .zero,
                                        viewSize: CGSize(width: PageGeometry.width, height: PageGeometry.height),
                                        barScale: 1 / max(scale, 0.01)))
                                }
                            )
                            .frame(width: PageGeometry.width, height: PageGeometry.height)
                            .scaleEffect(scale, anchor: .topLeading)
                            // 連續模式的物件可以拖到相鄰的頁（單頁模式照舊夾在本頁）。
                            .environment(\.pageCrossing, pageCrossing(for: index))
                        }
                        .id(index)
                        .zIndex(continuousDragPage == index ? 1 : 0)
                        .background(
                            // 哪一頁在畫面中央，哪一頁就是焦點頁。
                            // 插入物件要落在使用者正在看的那一頁，不是他上次
                            // 按過上一頁／下一頁的那一頁。
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: PageFocusPreferenceKey.self,
                                    value: [index: geo.frame(in: .named(ContinuousPagesSpace.name)).midY]
                                )
                            }
                        )
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: ContinuousPagesSpace.name)
            .environment(\.objectReorder, { id, op in reorderObject(id, op) })
            .environment(\.objectLock, objectLockActions)
            .environment(\.objectClipboard, objectClipboardActions)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { mag in
                        let currentRatio: CGFloat
                        if let target = continuousZoomTarget, case .ratio(let val) = target {
                            currentRatio = val
                        } else {
                            currentRatio = 1.0
                        }
                        let base = continuousPinchBaseZoom ?? currentRatio
                        if continuousPinchBaseZoom == nil { continuousPinchBaseZoom = base }
                        let newRatio = max(0.4, min(3.0, base * mag))
                        continuousZoomTarget = .ratio(newRatio)
                    }
                    .onEnded { _ in
                        continuousPinchBaseZoom = nil
                    }
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { continuousViewportHeight = geo.size.height }
                        .onChange(of: geo.size.height) { h in continuousViewportHeight = h }
                }
            )
            .onPreferenceChange(PageFocusPreferenceKey.self) { mids in
                updateFocusedPage(from: mids)
            }
            .onChange(of: currentPageIndex) { page in
                // 捲動自己帶來的變動不用再捲。
                guard page != continuousReportedPage else { return }
                continuousReportedPage = page
                scrollContinuous(to: page, proxy: proxy, animated: true)
            }
            .onChange(of: continuousScrollRequest) { _ in
                scrollContinuous(to: currentPageIndex, proxy: proxy, animated: true)
            }
            .onChange(of: notebook.pageCount) { _ in
                // 新增／刪除頁面之後頁碼可能沒變但內容換了，確保焦點頁在畫面上。
                scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
            }
            .onChange(of: editorMode) { _ in
                // 切換手繪/打字模式時維持使用者原本的捲動位置與閱讀視角，不強制捲動頁面。
            }
            .onAppear {
                // 從整頁模式切過來時，停在原本那一頁而不是回到第 1 頁。
                // LazyVStack 第一輪排版還沒完成時 scrollTo 會落空，所以下一輪與稍後再各補一次。
                continuousReportedPage = currentPageIndex
                scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
                }
            }
        }
    }

    /// 連續模式：使用者在某一頁上落筆／點擊，焦點換到那一頁。
    ///
    /// **不捲動。** 改 `currentPageIndex` 會觸發「捲到焦點頁頂端」（給翻頁鈕、縮圖用的）——
    /// 在半露出來的下一頁落筆，整個畫面就帶著動畫滑走，筆尖底下的紙換了位置，
    /// 使用者看到的是「一碰就跳、空白一下」。先把回報頁設成同一頁，捲動那邊就知道不必動。
    /// 也只在真的換頁時才讀那一頁的筆跡：每一次落筆都讀檔解碼，筆尖一碰就卡一下。
    /// 第 `page` 頁的物件層拿到的跨頁資訊。只有連續模式才有。
    private func pageCrossing(for page: Int) -> PageCrossing? {
        guard pageDisplayMode == .continuous else { return nil }
        return PageCrossing(
            page: page,
            pageCount: max(1, notebook.pageCount),
            gap: Self.continuousPageSpacing / max(continuousScale, 0.01),
            began: {
                continuousDragPage = page
                focusContinuousPage(page)
            },
            ended: { id, to in finishPageCrossing(ids: id.map { [$0] } ?? [], to: to) })
    }

    /// 拖曳結束。物件換了頁（`pageIndex` 已經寫好）的話，以頁碼為鍵的名單跟著搬、焦點換到新頁。
    private func finishPageCrossing(ids: [String], to page: Int?) {
        continuousDragPage = nil
        guard let page, !ids.isEmpty else { return }
        notebook.realignPageKeyedObjectLists()
        focusContinuousPage(page)
        commitNotebook()
        continuousObjectGeneration += 1
        thumbnailRevision += 1
    }

    /// 編輯器自己搬的物件（形狀、表格、多選）在連續模式下的落點：`frame` 整組的外框，
    /// 在第 `page` 頁的座標裡。回傳 `nil` 表示不換頁（單頁模式、或中心還在本頁）。
    private func crossingLanding(for frame: CGRect, page: Int) -> (page: Int, offset: CGSize)? {
        guard let crossing = pageCrossing(for: page) else { return nil }
        let landed = PrintableArea.land(
            x: frame.minX, y: frame.minY, width: frame.width, height: frame.height, crossing: crossing)
        guard let target = landed.page else { return nil }
        return (target, CGSize(width: landed.origin.x - frame.minX, height: landed.origin.y - frame.minY))
    }

    func focusContinuousPage(_ index: Int) {
        guard index != currentPageIndex else { return }
        continuousReportedPage = index
        currentPageIndex = index
        if let canvas = continuousCanvases[index] {
            continuousCanvases.activeCanvas = canvas
            canvasView = canvas
        }
        currentDrawing = drawingForPage(index)
        configureLassoCallbacks(forPage: index)
    }

    private func scrollContinuous(to page: Int, proxy: ScrollViewProxy, animated: Bool) {
        let target = min(max(0, page), max(0, notebook.pageCount - 1))
        continuousProgrammaticScrollUntil = Date().addingTimeInterval(animated ? 0.8 : 0.4)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(target, anchor: .top) }
            } else {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    /// 連續模式下捲動容器的高度。焦點判定要拿它算中線。
    @State private var continuousViewportHeight: CGFloat = 800

    /// 把某一頁的筆跡變動廣播出去（協同）。
    ///
    /// 與整頁模式走同一組 oplog 事件與同一個 `page_index` —— 兩邊各發一種
    /// 事件的話，對方會在不同的模式下收到不同的東西。
    /// 筆跡的變動以「加入哪幾筆、移除哪幾筆」送出（設計 §4.3）。
    ///
    /// 不再送整頁：整頁取代會把對方同一瞬間畫的筆畫蓋掉。這一頁還沒同步過時，
    /// 第一次會把整頁的筆畫當成加入送出 —— 加入是冪等的，對方已有的不會重複。
    private func broadcastDrawingChange(page: Int, drawing: PKDrawing) {
        guard !isApplyingRemoteUpdate, isCollaborating else { return }
        ensureCollabPageIds()
        guard let ids = notebook.pageIds, page >= 0, page < ids.count else { return }
        let pageId = ids[page]
        let current = drawing.strokes.map { (collabInkLedger.wireId(for: $0), $0) }
        let currentIds = Set(current.map(\.0))
        let known = collabInkLedger.known[pageId] ?? []
        let added = current.filter { !known.contains($0.0) }
        let removed = known.subtracting(currentIds)
        collabInkLedger.known[pageId] = currentIds
        if !added.isEmpty {
            collabInkLedger.added(page: pageId, wires: added.map(\.0))
            collaborationManager.broadcastOplog(kind: "ink_add", payload: [
                "proto": Self.collabProto, "page": pageId,
                "strokes": added.map { CollabStroke.encode($0.1, id: $0.0) }
            ])
        }
        if !removed.isEmpty {
            collabInkLedger.removed(page: pageId, wires: removed)
            collaborationManager.broadcastOplog(kind: "ink_remove", payload: [
                "proto": Self.collabProto, "page": pageId, "ids": Array(removed)
            ])
        }
    }

    /// 取畫面中央最近的那一頁當焦點頁。
    private func updateFocusedPage(from mids: [Int: CGFloat]) {
        guard !mids.isEmpty else { return }
        // 程式捲動進行中不判焦點（理由見 `continuousProgrammaticScrollUntil`）。
        guard Date() >= continuousProgrammaticScrollUntil else { return }
        // 若當前頁碼大於 0，但 mids 尚未包含當前頁且數量不足，防止 LazyVStack 重排初始暫態奪走焦點覆蓋為第 0 頁
        if currentPageIndex > 0 && !mids.keys.contains(currentPageIndex) && mids.count < min(2, notebook.pageCount) {
            return
        }
        // 視窗中央的 y。用固定的頁高估一個中線就夠 —— 這裡只要挑出
        // 「最接近中央的那一頁」，不需要精準的可見面積。
        let viewportCenter = continuousViewportHeight / 2
        let nearest = mids.min {
            abs($0.value - viewportCenter) < abs($1.value - viewportCenter)
        }
        guard let page = nearest?.key, page != currentPageIndex else { return }
        continuousReportedPage = page
        currentPageIndex = page
        if let canvas = continuousCanvases[page] {
            continuousCanvases.activeCanvas = canvas
            canvasView = canvas
        }
        currentDrawing = drawingForPage(page)
        configureLassoCallbacks(forPage: page)
    }


    /// 某一頁的插入物件層（圖片、形狀、表格、文字、連結、3D、討論圖釘）。
    ///
    /// 抽成帶頁碼的方法，是為了讓連續頁面模式能對每一頁各叫一次 ——
    /// 原本這一整段寫死在畫布工作區裡、只認 `currentPageIndex`，
    /// 連續模式下就只有一頁有物件，其餘頁面是空的。
    enum ObjectInkLayerFilter {
        case all
        case underInkOnly
        case overInkOnly
    }

    private func shouldIncludeInInkLayer(id: String, filter: ObjectInkLayerFilter, underInkSet: Set<String>) -> Bool {
        switch filter {
        case .all: return true
        case .underInkOnly:
            return underInkSet.contains(id)
        case .overInkOnly:
            return !underInkSet.contains(id)
        }
    }

    /// 某一頁的插入物件層（圖片、形狀、表格、文字、連結、3D、討論圖釘）。
    ///
    /// 支援依筆跡上下圖層進行過濾：
    /// - `.underInkOnly`: 移至筆跡下方的物件（置於 PKCanvasView 底層）
    /// - `.overInkOnly`: 筆跡上方的物件（置於 PKCanvasView 頂層）
    /// - `.all`: 完整物件層（連續頁面等情境）
    @ViewBuilder
    private func objectLayer(forPage page: Int, filter: ObjectInkLayerFilter = .all) -> some View {
        let underInkSet = notebook.underInkObjectIds(forPage: page)
        // 鎖定在畫布上的物件：不接收觸控（見 `canvasLocked`）。不分頁查：物件 id 全域唯一，
        // 頁面搬移、插頁之後頁次鍵對不上也不會鎖錯或漏鎖。
        let lockedSet = notebook.allLockedObjectIds
        // 堆疊順序的索引表：一次算繪只建一次，不要每個物件各掃一遍
        // （見 `ObjectStacking.Lookup`）。
        let stacking = ObjectStacking.Lookup(order: notebook.objectOrder(forPage: page))
        ZStack(alignment: .topLeading) {
            ForEach(notebook.attachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        AttachmentItemView(
                            attachment: binding(for: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            isTypeMode: editorMode == .type,
                            onSelect: { selectSingleObject(item.id) },
                            onEdit: {
                                if let formula = item.mathFormula {
                                    self.editingMathAttachmentId = MathEditTarget(id: item.id, formula: formula)
                                } else if let spec = item.chartSpec {
                                    self.editingChartAttachmentId = ChartEditTarget(id: item.id, spec: spec)
                                } else {
                                    self.editingAttachmentId = item.id
                                }
                            },
                            onDelete: {
                                deletedAttachmentBackup = (type: "image", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "image")
                                notebook.attachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                                collaborationManager.broadcastSelection(selectedId: nil)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))

                        .zIndex(stacking.zIndex(for: item.id, kind: .image))
                    }
                }

                // 連接線先畫 —— 畫在形狀之上的話，線會壓過方塊的邊，看起來像穿幫。
                ForEach(notebook.connectionAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet),
                       let from = notebook.shapeAttachments?.first(where: { $0.id == item.fromShapeId }),
                       let to = notebook.shapeAttachments?.first(where: { $0.id == item.toShapeId }),
                       let geometry = ShapeGeometry.connection(item, from: from, to: to) {
                        ConnectionLineView(
                            connection: item,
                            geometry: geometry,
                            isSelected: selectedConnectionId == item.id,
                            onSelect: {
                                selectedShapeIds = []
                                selectedConnectionId = (selectedConnectionId == item.id) ? nil : item.id
                            },
                            onEdit: {
                                selectedConnectionId = item.id
                                editingConnectionId = item.id
                                editingShapeId = nil
                            },
                            onDelete: { deleteConnection(item.id) }
                        )
                        // 線畫在它連著的兩個形狀的**下面**（見上面的說明），
                        // 但仍然在更低層的其他物件之上。
                        .zIndex(min(
                            stacking.zIndex(for: from.id, kind: .shape),
                            stacking.zIndex(for: to.id, kind: .shape)) - 0.1)
                    }
                }

                // 形狀。
                ForEach(notebook.shapeAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        ShapeAttachmentItemView(
                            shape: shapeBinding(for: item.id),
                            isSelected: selectedShapeIds.contains(item.id),
                            isSoleSelection: selectedShapeIds.count <= 1,
                            onSelect: {
                                selectedConnectionId = nil
                                toggleShapeSelection(item.id)
                            },
                            onMove: { delta in moveShapeGroup(item.id, by: delta) },
                            onDelete: { deleteShape(item.id) },
                            onEdit: {
                                selectedShapeIds = [item.id]
                                selectedConnectionId = nil
                                editingShapeId = item.id
                                editingConnectionId = nil
                            },
                            onConnectDrag: { anchor, start, current, finished in
                                handleConnectDrag(
                                    from: item.id, anchor: anchor, start: start,
                                    current: current, finished: finished)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))

                        .zIndex(stacking.zIndex(for: item.id, kind: .shape))
                    }
                }

                // 拉線預覽。
                if let draft = connectionDraft, draft.page == page {
                    ConnectionDraftView(from: draft.start, to: draft.current)
                        .zIndex(9000)
                }

                // 互動式貼圖定位與放置浮層（工作項：允許自由拖曳、縮放與旋轉貼圖位置）
                if page == currentPageIndex, let placement = pendingStickerPlacement {
                    StickerPlacementOverlayView(
                        placement: Binding(
                            get: { self.pendingStickerPlacement ?? placement },
                            set: { self.pendingStickerPlacement = $0 }
                        ),
                        onCommit: {
                            if let p = self.pendingStickerPlacement {
                                insertStickerObject(p)
                                self.pendingStickerPlacement = nil
                                // 手寫模式下物件不吃觸控，貼紙放完卻點不動等於又回到
                                // 原本的問題。圖片拖放後也是切到打字模式。
                                transitionToMode(.type)
                                showCanvasNotice(localizationManager.localized("sticker_placed_hint"))
                            }
                        },
                        onCancel: {
                            self.pendingStickerPlacement = nil
                        }
                    )
                    .zIndex(9999)
                }

                // 表格。
                ForEach(notebook.tableAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        TableAttachmentItemView(
                            table: tableBinding(for: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: {
                                let wasControlled = (activeSelectedObjectId == item.id)
                                selectSingleObject(item.id)
                                if selectedTool == .eraser {
                                    watchdog.notifyEraserUsedOnNonInk(targetType: .table) {
                                        let id = item.id
                                        notebook.tableAttachments?.removeAll { $0.id == id }
                                        commitNotebook()
                                        PageThumbnailRenderer.invalidateAll()
                                    }
                                } else {
                                    watchdog.notifyObjectTapped(
                                        targetId: item.id,
                                        targetType: .table,
                                        isControlled: wasControlled,
                                        onControlObject: {
                                            selectSingleObject(item.id)
                                        }
                                    )
                                }
                            },
                            onMove: { delta in moveTable(item.id, by: delta) },
                            onEdit: { editingTable = item },
                            onDelete: {
                                let id = item.id
                                notebook.tableAttachments?.removeAll { $0.id == id }
                                commitNotebook()
                                PageThumbnailRenderer.invalidateAll()
                                collaborationManager.broadcastAttachmentDelete(id: id, type: "table")
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))

                        .zIndex(stacking.zIndex(for: item.id, kind: .table))
                    }
                }

                // 🌟 筆記內嵌 Word 級文字方塊（支援段落對齊、特殊符號與便利貼卡片底色）
                ForEach(Array((notebook.textAttachments ?? []).enumerated()), id: \.element.id) { position, item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        TextAttachmentItemView(
                            textItem: binding(forTextId: item.id, hint: position),
                            isEditingInline: Binding(
                                get: { inlineEditingTextId == item.id },
                                set: { editing in
                                    if editing {
                                        recordTextUndoState()
                                        textFormatTargetId = item.id
                                        suspendedInlineTextId = nil
                                        inlineEditingTextId = item.id
                                    } else if inlineEditingTextId == item.id {
                                        // 失焦（多半是按了工具列）：記住目標，格式套用後再把游標還回來。
                                        textFormatTargetId = item.id
                                        suspendedInlineTextId = item.id
                                        inlineEditingTextId = nil
                                    }
                                }
                            ),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            isTypeMode: editorMode == .type,
                            isUnderInk: underInkSet.contains(item.id),
                            snapToGrid: snapToGrid,
                            snapY: { y in snapYToGuideLine(at: y) },
                            onEdit: {
                                recordTextUndoState()
                                self.editingTextId = item.id
                            },
                            onDelete: {
                                if inlineEditingTextId == item.id { inlineEditingTextId = nil }
                                recordTextUndoState()
                                deletedAttachmentBackup = (type: "text", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "text")
                                notebook.textAttachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                                collaborationManager.broadcastSelection(selectedId: nil)
                                PageThumbnailRenderer.invalidateAll()
                            },
                            onMoved: { delta in
                                moveAnchoredStrokes(forTextId: item.id, delta: delta)
                            },
                            onAnchorInk: {
                                anchorOverlappingInkToText(textItem: item)
                            },
                            selectionTracker: textSelectionTracker
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))

                        .zIndex(stacking.zIndex(for: item.id, kind: .text))
                    }
                }

                // 🌟 筆記內嵌網址 Rich Link 預覽卡片（支援點擊跳轉瀏覽器與自由平移）
                ForEach(notebook.linkAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        LinkAttachmentItemView(
                            linkItem: binding(forLinkId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            onDelete: {
                                notebook.linkAttachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))

                        .zIndex(stacking.zIndex(for: item.id, kind: .link))
                    }
                }

                // 🌟 頁面上的錄音卡片（可播放、可搬移、可縮放、可旋轉、可改名、音訊轉文字）
                ForEach(notebook.audioAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        AudioAttachmentItemView(
                            item: binding(forAudioId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            notebookId: notebook.id,
                            onDelete: {
                                notebook.audioAttachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                            },
                            onTranscribe: { transcribedText in
                                insertTranscriptText(transcribedText, for: item)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))

                        .zIndex(stacking.zIndex(for: item.id, kind: .audio))
                    }
                }

                // 🌟 筆記內嵌 3D 幾何模型展示層（支援 360° 空間旋轉、9大材質 PBR 物理反射、縮放與文字標題）
                ForEach(notebook.model3DAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        Model3DCanvasItemView(
                            item: binding(forModel3DId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            onDelete: {
                                deletedAttachmentBackup = (type: "3d", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "3d")
                                notebook.model3DAttachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                                collaborationManager.broadcastSelection(selectedId: nil)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))

                        .zIndex(stacking.zIndex(for: item.id, kind: .model3D))
                    }
                }

                // 🌟 筆記內嵌討論圖釘展示層（支援多方訊息留言串、已解決標記與即時推播）
                ForEach(notebook.commentPins ?? []) { pin in
                    if pin.pageIndex == page && filter != .underInkOnly {
                        CommentPinMarkerView(
                            pin: pin,
                            isSelected: selectedCommentPinId == pin.id,
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    if selectedCommentPinId == pin.id {
                                        selectedCommentPinId = nil
                                        collaborationManager.broadcastSelection(selectedId: nil)
                                    } else {
                                        activeSelectedObjectId = nil
                                        selectedShapeIds = []
                                        selectedConnectionId = nil
                                        selectedObjectIds = []
                                        if inlineEditingTextId != nil { inlineEditingTextId = nil }
                                        selectedCommentPinId = pin.id
                                        collaborationManager.broadcastSelection(selectedId: pin.id)
                                    }
                                }
                            }
                        )
                        .position(x: pin.x, y: pin.y)
                        .canvasLocked(lockedSet.contains(pin.id.lowercased()))

                        .zIndex(stacking.zIndex(for: pin.id, kind: .pin))
                    }
                }

                // 🌟 特殊樣板智慧互動元件層（核取清單 Checkbox、選項切換與進度管控）
                if filter != .underInkOnly {
                    lockedObjectBadges(forPage: page)
                    lockedObjectPrompt(forPage: page)

                    ForEach(interactiveGuideCheckboxes(forPage: page)) { item in
                        InteractiveGuideCheckboxView(
                            isChecked: notebook.checkedGuideItems?[item.key] ?? false,
                            size: CGSize(width: CGFloat(item.guide.w), height: CGFloat(item.guide.h)),
                            onToggle: {
                                toggleGuideCheckbox(key: item.key)
                            },
                            onStrikethroughRow: {
                                toggleRowStrikethrough(y: CGFloat(item.guide.y), page: page)
                            },
                            onClearRowText: {
                                clearRowText(y: CGFloat(item.guide.y), page: page)
                            },
                            onResetPage: {
                                resetPageCheckboxes(page: page)
                            }
                        )
                        .position(
                            x: CGFloat(item.guide.x) + CGFloat(item.guide.w) / 2,
                            y: CGFloat(item.guide.y) + CGFloat(item.guide.h) / 2
                        )
                        .zIndex(10)
                    }
                    if pageDisplayMode == .continuous {
                        if isMarqueeActive && editorMode == .type {
                            marqueeLayer(forPage: page)
                                .zIndex(1000)
                        }
                        if isPlacingPasteObject && !objectClipboard.isEmpty {
                            pasteTargetLayer(forPage: page)
                                .zIndex(1001)
                        }
                    }
                }

        }
        .environment(\.objectReorder, { id, op in reorderObject(id, op) })
        .environment(\.objectLock, objectLockActions)
        .environment(\.objectClipboard, objectClipboardActions)
        .coordinateSpace(name: CanvasCoordinateSpace.name)
    }

    private var canvasWorkAreaContent: some View {
        ZStack(alignment: .topTrailing) {
            PageBackgroundRepresentable(
                paperId: notebook.paperId(forPage: currentPageIndex),
                paletteId: notebook.guidePaletteId,
                pageIndex: currentPageIndex,
                checkedGuideItems: notebook.checkedGuideItems
            )
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(false)
                .zIndex(0)

            // 筆跡下方層（Background / Under-ink objects）：在 CanvasRepresentable 之下，zIndex 1
            objectLayer(forPage: currentPageIndex, filter: .underInkOnly)
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(isObjectInteractionActive)
                .zIndex(1)

            CanvasRepresentable(
                drawing: $currentDrawing,
                proInk: ProInkBinding(
                    directory: store.drawingsDirectory, notebookId: notebook.id, pageIndex: currentPageIndex),
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                strokeWidth: strokeWidth,
                eraserMode: eraserMode,
                pixelEraserWidth: pixelEraserWidth,
                isRulerActive: isRulerActive,
                paperId: notebook.paperId(forPage: currentPageIndex),
                paletteId: notebook.guidePaletteId,
                pageHeight: currentPageHeight,
                editorMode: effectiveCanvasMode,
                hitPassThroughCheck: { point, event in
                    isUnderInkPointPassThrough(point: point, page: currentPageIndex, event: event)
                },
                isScrollEnabled: false,
                onDrawingChanged: { rawDrawing -> PKDrawing? in
                    // 筆跡登記了自己的復原項：之後的物件變更不能併進前一個物件步驟。
                    objectHistory.breakCoalescing()
                    // **頁面框線就是編輯區域。**
                    var processedDrawing = enforcePrintableArea(rawDrawing)
                    if strokeStabilizer > 0.05 {
                        processedDrawing = applyStabilizer(to: processedDrawing)
                    }
                    if isSymmetryActive {
                        processedDrawing = applySymmetry(to: processedDrawing)
                    }
                    let newDrawing = processedDrawing
                    recordDrawingEdit(page: currentPageIndex, drawing: newDrawing)

                    // 🌟 智慧意圖感知：手繪筆劃覆蓋於文字方塊上方
                    if let latestStroke = newDrawing.strokes.last, newDrawing.strokes.count > lastStrokeCount {
                        let strokeRect = latestStroke.renderBounds
                        if let overlapped = (notebook.textAttachments ?? []).first(where: {
                            $0.pageIndex == currentPageIndex && strokeRect.intersects(CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height))
                        }) {
                            watchdog.notifyStrokeDrawnOverText(
                                strokeBounds: strokeRect,
                                textBoxId: overlapped.id,
                                textBoxBounds: CGRect(x: overlapped.x, y: overlapped.y, width: overlapped.width, height: overlapped.height),
                                onAnchor: {
                                    anchorSelectedStrokesToNearestText()
                                }
                            )
                        }
                    }

                    if !isApplyingRemoteUpdate && isCollaborating {
                        let count = newDrawing.strokes.count
                        // 逐筆增刪（設計 §4.3）。以前是「多了就送尾巴幾筆、少了就送整頁取代」：
                        // 套索搬動（筆數不變）不會送；擦掉一筆時送整頁，對方整頁被取代，
                        // 同一瞬間對方畫的那一筆就沒了。
                        broadcastDrawingChange(page: currentPageIndex, drawing: newDrawing)
                        lastStrokeCount = count
                    } else if !isApplyingRemoteUpdate {
                        lastStrokeCount = newDrawing.strokes.count
                    }
                    
                    // 🌟 自動流式錨定：若落筆於既有文字方塊上方（圈註、畫底線、旁註），自動建立關聯錨定
                    if !isApplyingRemoteUpdate && newDrawing.strokes.count > 0 {
                        autoAnchorNewStrokesToOverlappingText(drawing: newDrawing)
                    }
                    
                    return newDrawing.strokes.count == rawDrawing.strokes.count
                        ? nil
                        : newDrawing
                },
                onReachedPageBottom: {
                    ensureNextPageExists()
                },
                onSelectionChanged: { hasSel in
                    if !hasSel { lasso.clear() }
                },
                onLassoBegan: { pt in
                    syncDrawingFromCanvas()
                    configureLassoCallbacks(forPage: currentPageIndex)
                    lasso.begin(at: pt)
                },
                onLassoMoved: { pt in
                    if lasso.isDraggingSelection {
                        let lastPt = lasso.dragPoint ?? pt
                        let delta = CGSize(width: pt.x - lastPt.x, height: pt.y - lastPt.y)
                        lasso.updateDragPoint(pt)
                        if let updated = lasso.moveSelected(in: currentDrawing, by: delta) {
                            currentDrawing = updated
                            showLassoEdit(updated)
                        }
                    } else {
                        lasso.extend(to: pt)
                    }
                },
                onLassoEnded: {
                    let wasDragging = lasso.isDraggingSelection
                    lasso.finish(in: currentDrawing)
                    if wasDragging {
                        recordDrawingEdit(page: currentPageIndex, drawing: currentDrawing)
                        broadcastDrawingChange(page: currentPageIndex, drawing: currentDrawing)
                        PageThumbnailRenderer.invalidateAll()
                    }
                },
                canvasRef: { ref in
                    continuousCanvases.activeCanvas = ref
                    // `updateUIView` 每次更新都會叫到這裡；直接寫 @State 就是在畫面更新途中改狀態
                    // （SwiftUI 的 runtime issue「Modifying state during view update」，每個工作階段
                    // 好幾十次），而且同一個物件重複指派也會再觸發一輪更新。
                    // 只在真的換了才寫，並且挪到這一輪更新之後。
                    guard self.canvasView !== ref else { return }
                    DispatchQueue.main.async { 
                        self.canvasView = ref 
                        if let adaptive = ref as? AdaptiveCanvasView, self.currentDrawing.strokes.count > 0 {
                            adaptive.forceDisplayRefresh(with: self.currentDrawing)
                        }
                    }
                },
                onScrollMetrics: { visible, fraction in
                    canvasVisibleFraction = visible
                    canvasScrollFraction = fraction
                },
                onTransformChanged: { scale, offset in
                    canvasZoomScale = scale
                    canvasContentOffset = offset
                },
                palmRejection: palmRejection,
                onRetractStrokes: { landedAt in
                    guard palmRejection.drawingPolicy(now: landedAt) != .pencilOnly else { return }
                    if let adaptive = canvasView as? AdaptiveCanvasView, adaptive.activeTouchesCount > 0 {
                        adaptive.pendingRetractDate = landedAt
                        return
                    }
                    let cleaned = PalmRejectionCoordinator.retracting(
                        currentDrawing, landedAt: landedAt)
                    guard cleaned.strokes.count != currentDrawing.strokes.count else { return }
                    let removed = currentDrawing.strokes.count - cleaned.strokes.count
                    currentDrawing = cleaned
                    canvasView?.drawing = cleaned
                    (canvasView as? AdaptiveCanvasView)?.dropDeadUndoEntries(max: removed)
                    saveCurrentPageDrawing()
                },
                onPenControl: applyPenControl,
                onPrevPage: {
                    if currentPageIndex > 0 {
                        saveCurrentPageDrawing()
                        currentPageIndex -= 1
                        loadCurrentPage()
                    }
                },
                onNextPage: {
                    if currentPageIndex < notebook.pageCount - 1 {
                        saveCurrentPageDrawing()
                        currentPageIndex += 1
                        loadCurrentPage()
                    }
                },
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                magneticSnapEnabled: isMagneticSnapActive,
                onMagneticSnap: { start, end in
                    magneticGuideStart = start
                    magneticGuideEnd = end
                    magneticGuideActive = true
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        magneticGuideActive = false
                    }
                },
                onPencilTouchBegan: { handlePencilTouchBegan() },
                onCanvasDirectTap: { location in
                    guard !isInlineInkEditing else { return }
                    handleCanvasDirectTap(at: location)
                },
                onCanvasDirectDoubleTap: { location in
                    guard !isInlineInkEditing else { return }
                    handleCanvasDirectDoubleTap(at: location)
                },
                onPencilTapInTypeMode: { location in
                    guard !isInlineInkEditing else { return }
                    handlePencilTapInTypeMode(at: location)
                },
                onPressAndHold: { openRadialMenuFromPress(at: $0) }
            )
            .accessibilityIdentifier("editor.canvas")
            .overlay(alignment: .topLeading) {
                // 套索的圈、選取框與快顯工具列。套索點是頁面座標，畫在這一層要換回
                // 畫布可視範圍的座標（乘縮放、扣捲動）。
                GeometryReader { geo in
                    lassoSelectionDecoration(
                        zoom: canvasZoomScale, offset: canvasContentOffset, viewSize: geo.size)
                }
            }
            // 從別的 App 把圖拖進來（工作項 S-68）。
            //
            // 掛在畫布上而不是整個編輯器：落點要能換算成頁面座標，
            // 掛在外層的話拖到工具列上也會插進去，而且位置會偏掉。
            .onDrop(of: [.image], isTargeted: $isCanvasDropTargeted) { providers, location in
                acceptImageDrop(providers, at: location, page: currentPageIndex)
            }
            .overlay { canvasDropHighlight(isCanvasDropTargeted) }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { updateCanvasContentWidth(geo.size.width) }
                        .onChange(of: geo.size.width) { newWidth in
                            updateCanvasContentWidth(newWidth)
                        }
                }
            )
            .zIndex(2)

            modeBadge
                .padding(.top, DS.Space.s)
                .padding(.trailing, DS.Space.m)
                .opacity(modeBadgeVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.22), value: modeBadgeVisible)
            MaskingTapeOverlayView(
                notebook: $notebook,
                pageIndex: currentPageIndex,
                isActive: selectedTool == .maskingTape,
                selectedColor: selectedColor,
                onTapesChanged: {
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                }
            )
            .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
            .scaleEffect(canvasZoomScale, anchor: .topLeading)
            .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
            .allowsHitTesting(selectedTool == .maskingTape || (editorMode != .draw && !(notebook.tapeAttachments?.filter { $0.pageIndex == currentPageIndex }.isEmpty ?? true)))
            .zIndex(selectedTool == .maskingTape ? 4 : 2.5)

            // 筆跡上方層（Foreground / Over-ink objects）：在 CanvasRepresentable 之上，zIndex 3
            objectLayer(forPage: currentPageIndex, filter: .overInkOnly)
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(isObjectInteractionActive)
                .zIndex(3)

            // 🌟 專業鏡像對稱尺規視覺參考線
            if isSymmetryActive && editorMode == .draw {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundColor(Color.accentColor.opacity(0.6))
                    .frame(width: 1)
                    .overlay(alignment: .top) {
                        Text(localizationManager.localized("ed_symmetry_axis"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .systemBackground).opacity(0.85))
                            .cornerRadius(4)
                            .offset(y: 8)
                    }
                    .position(x: 400, y: currentPageHeight / 2)
                    .allowsHitTesting(false)
            }

            // 🌟 插入垂直空間分隔導引器（GoodNotes 風格空間插入條）
            if isInsertSpaceActive {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.and.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text(localizationManager.localized("insert_vertical_space"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isInsertSpaceActive = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 4, y: 2))
                    .offset(x: 20)
                }
                .frame(width: PageGeometry.width, height: 32)
                .position(x: PageGeometry.width / 2, y: insertSpaceDividerY)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .zIndex(5)
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            let delta = val.translation.height - insertSpaceDragAccum
                            insertSpaceDragAccum = val.translation.height
                            let targetY = max(50, min(currentPageHeight + 200, insertSpaceDividerY + delta))
                            insertSpaceDividerY = targetY
                            if abs(delta) > 0.5 {
                                applyVerticalSpaceInsertion(splitY: insertSpaceDividerY, deltaY: delta)
                            }
                        }
                        .onEnded { _ in
                            insertSpaceDragAccum = 0.0
                        }
                )
            }


            // 框選層。只有在框選模式下才存在 —— 平常掛一層可命中的
            // 透明視圖，底下的物件就全部點不到了。
            if isMarqueeActive && editorMode == .type {
                marqueeLayer(forPage: currentPageIndex)
                    .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                    .scaleEffect(canvasZoomScale, anchor: .topLeading)
                    .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                    .coordinateSpace(name: CanvasCoordinateSpace.name)
                    .zIndex(4)
            }

            if isPlacingPasteObject && !objectClipboard.isEmpty {
                pasteTargetLayer(forPage: currentPageIndex)
                    .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                    .scaleEffect(canvasZoomScale, anchor: .topLeading)
                    .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                    .coordinateSpace(name: CanvasCoordinateSpace.name)
                    .zIndex(4)
            }

            // 展開的討論圖釘詳細對話框
            if let pinId = selectedCommentPinId,
               let pin = (notebook.commentPins ?? []).first(where: { $0.id == pinId }),
               pin.pageIndex == currentPageIndex {
                CommentThreadDialog(
                    pin: pin,
                    currentUserId: collaborationManager.currentUserId,
                    currentUserName: AccountManager.shared.profile.displayName,
                    currentUserColor: collaborationManager.myColorHex,
                    onReply: { pId, text in
                        addCommentReply(pinId: pId, text: text)
                    },
                    onToggleResolve: { pId in
                        toggleCommentResolve(pinId: pId)
                    },
                    onDelete: { pId in
                        deleteCommentPin(pinId: pId)
                    },
                    onDeleteMessage: { pId, mId in
                        deleteCommentMessage(pinId: pId, messageId: mId)
                    },
                    onClose: {
                        withAnimation {
                            selectedCommentPinId = nil
                            collaborationManager.broadcastSelection(selectedId: nil)
                        }
                    }
                )
                .position(
                    x: min(max(170, pin.x), 650),
                    y: min(max(150, pin.y - 120), currentPageHeight - 120)
                )
                // **與圖釘的點擊層同一個問題**：沒有 zIndex 就預設為 0，
                // 整個討論串面板都被壓在畫布（1）與物件層（2）底下。
                // 面板畫得出來，但只要它的按鈕和頁面上的物件重疊，
                // 點下去就會打到物件 —— 症狀是「收合」與「關閉」按了沒反應，
                // 而使用者只會覺得這個對話框關不掉。
                //
                // 4 在圖釘放置層（3）之上：它是面板，本來就該蓋住一切。
                .zIndex(4)
            }

            // 放置討論圖釘模式互動層。
            //
            // **`zIndex` 不能省。** 這一層原本沒有設，於是預設為 0 ——
            // 而畫布是 `.zIndex(1)`、物件層是 `.zIndex(2)`，它就被壓在最底下，
            // 點擊永遠到不了它。症狀是「加入討論圖釘」按下去之後，橫幅叫你
            // 點畫布，點下去卻是在畫線（手繪模式）或插入文字游標（打字模式），
            // 圖釘**一個都放不上去**。這個功能等於完全不能用。
            //
            // 2026-09-22 拍操作手冊截圖時發現：橫幅出現了，圖釘卻怎麼點都不出現。
            if isPlacingCommentPin {
                GeometryReader { geo in
                    Color.blue.opacity(0.001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let newPin = NoteCommentPin(
                                pageIndex: currentPageIndex,
                                x: location.x,
                                y: location.y,
                                authorId: collaborationManager.currentUserId,
                                authorName: AccountManager.shared.profile.displayName,
                                authorColor: collaborationManager.myColorHex,
                                messages: [
                                    NoteCommentMessage(
                                        authorId: collaborationManager.currentUserId,
                                        authorName: AccountManager.shared.profile.displayName,
                                        authorColor: collaborationManager.myColorHex,
                                        text: localizationManager.localized("add_comment_pin")
                                    )
                                ]
                            )
                            if notebook.commentPins == nil {
                                notebook.commentPins = []
                            }
                            notebook.commentPins?.append(newPin)
                            commitNotebook()
                            selectedCommentPinId = newPin.id
                            isPlacingCommentPin = false
                            broadcastCommentPinUpsert(newPin)
                            collaborationManager.broadcastSelection(selectedId: newPin.id)
                        }
                }
                .zIndex(3)

                // 放置圖釘模式頂部提示條
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                    Text(localizationManager.localized("tap_to_place_pin"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Button(action: { isPlacingCommentPin = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
                .padding(.top, 14)
                .padding(.leading, 20)
            }

            // 🌟 美學構圖輔助 HUD 疊層（黃金螺旋與三分構圖）
            if isGoldenSpiralOverlay {
                GoldenSpiralOverlayView()
                    .allowsHitTesting(false)
                    .frame(height: currentPageHeight)
            }
            if isRuleOfThirdsOverlay {
                RuleOfThirdsOverlayView()
                    .allowsHitTesting(false)
                    .frame(height: currentPageHeight)
            }

            // 🌟 即時浮動錄音圖示徽章（筆記錄音完成後立即在已開啟筆記中呈現！）
            if notebook.hasRecording, let audioPath = notebook.recordingAudioPath {
                floatingAudioBadge(fileName: audioPath)
                    .padding(16)
                    .transition(.scale.combined(with: .opacity))
            }

            // 🌟 畫布底部浮動延伸膠囊按鈕（保留彈性：讓使用者隨時可向下延伸本頁）
            VStack {
                Spacer()
                HStack {
                    if showExtendedBanner {
                        Text(localizationManager.localized("page_extended_hint"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer()

                    // ＋ 新增下一頁
                    Button {
                        addNewPage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.square.dashed")
                                .font(.subheadline)
                            Text(localizationManager.localized("add_next_page"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("add_next_page"))
                    .help(localizationManager.localized("add_next_page"))

                    // 「延長本頁」已移除：頁面高度固定（PageGeometry），
                    // 寫到頁尾會自動準備下一頁。
                }
                .padding(14)
            }

            // 🌟 線上多人即時彩色游標與筆尖浮層
            RemoteCursorsOverlay()

            // 文字／圖片編修面板與圖層面板已移到 `objectEditPanels`，掛在
            // 兩種頁面模式共用的 `canvasWorkArea` 上 —— 原本掛在這裡，
            // 層級低於畫布與文字輸入層（觸控被它們吃掉，面板關不掉），
            // 而且連續模式根本不會走到這一段。

            // 🌟 聲筆動態同步與波形卡拉 OK 高亮 (Audio-Ink Karaoke Sync)
            if audioManager.isPlaying && !currentDrawing.strokes.isEmpty {
                Canvas { context, size in
                    let total = currentDrawing.strokes.count
                    if total > 0 {
                        let activeIdx = min(total - 1, max(0, Int(Double(total) * audioManager.playbackProgress)))
                        let start = max(0, activeIdx - 1)
                        let end = min(total - 1, activeIdx + 1)
                        for i in start...end {
                            let rect = currentDrawing.strokes[i].renderBounds
                            context.fill(
                                Path(roundedRect: rect.insetBy(dx: -6, dy: -6), cornerRadius: 8),
                                with: .color(Color.yellow.opacity(0.35))
                            )
                            context.stroke(
                                Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 6),
                                with: .color(Color.orange.opacity(0.8)),
                                lineWidth: 2.5
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // 🌟 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap Laser Guide)
            if isMagneticSnapActive && editorMode == .draw && magneticGuideActive {
                Canvas { context, size in
                    var path = Path()
                    path.move(to: magneticGuideStart)
                    path.addLine(to: magneticGuideEnd)
                    context.stroke(
                        path,
                        with: .color(Color.cyan.opacity(0.85)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // 徑向飛輪快捷工具盤不放在這裡：見 `canvasWorkArea` 的 `radialMenuLayer`。
            // 這一層會跟著頁面縮放，而且沒有 zIndex（預設 0）—— 被畫布（zIndex 2）壓住，
            // 點按鈕其實都點到畫布上變成筆跡，工具盤完全沒反應。
        }
        .frame(width: PageGeometry.width, height: currentPageHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            // 可用游標拖曳的捲軸（iOS 原生指示器不接受互動）
            CanvasScrollbar(
                visibleFraction: canvasVisibleFraction,
                scrollFraction: canvasScrollFraction
            ) { fraction in
                guard let canvas = canvasView else { return }
                let scrollable = max(canvas.contentSize.height - canvas.bounds.height, 0)
                canvas.setContentOffset(CGPoint(x: canvas.contentOffset.x, y: scrollable * fraction), animated: false)
                canvasScrollFraction = fraction
            }
            .padding(.trailing, 4)
            .padding(.vertical, 10)
        }
        .coordinateSpace(name: CanvasCoordinateSpace.name)
        .onContinuousHover { phase in
            guard isCollaborating else { return }
            switch phase {
            case .active(let location):
                collaborationManager.broadcastCursor(
                    x: location.x,
                    y: location.y,
                    isDrawing: false,
                    tool: selectedTool.rawValue
                )
            case .ended:
                break
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// 套索操作按鈕：圖示 + 可選文字標籤 + 說明提示
    func lassoActionButton(
        _ icon: String,
        _ titleKey: String,
        _ hintKey: String,
        showLabel: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                if showLabel {
                    Text(localizationManager.localized(titleKey))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, showLabel ? 8 : 6)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        // help 是補充說明（hint），標籤要用按鈕本身的名字。
        .accessibilityLabel(localizationManager.localized(titleKey))
        .help(localizationManager.localized(hintKey))
    }


    /// 版本標示（v2.2.0 這種）。點一下可複製，回報問題時直接貼上。
    // 版本號**不放在編輯器工具列**（工作項 S-62）。
    //
    // 原本這裡有一個等寬字體的 `v3.9.0` 標籤，理由是「Mac 上跑的 iOS 版由
    // 系統決定視窗標題，畫在自己的工具列裡最可靠」。那個理由本身沒錯，
    // 但結論放錯地方了：使用者每天盯著的編輯畫面不該常駐一個版本號 ——
    // 那是開發用的東西出現在出貨的介面上。
    //
    // 版本號在兩個地方仍然看得到：首頁頁尾，以及快捷選單裡的系統診斷。

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
                currentPageIndex = targetPage
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

    private var effectiveToolbarMode: EditorMode {
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

    private var effectiveCanvasMode: EditorMode {
        EditorCanvasInputPolicy.effectiveMode(
            mainMode: editorMode,
            isInlineInkEditing: isInlineInkEditing)
    }

    private var isCanvasInkActive: Bool {
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
    private var isObjectInteractionActive: Bool {
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
                editorMode = targetMode
            }
        } else {
            editorMode = targetMode
        }
        flashModeBadge()
    }

    // MARK: - 儲存、延伸與套索編輯核心
    /// 這一頁第一次載入時的狀態（只記一次）：筆畫、專業筆畫與已擦除名單。
    /// 第一次載入一定早於這頁的任何編輯，所以它就是「初始狀態」。
    func captureInitialPageState(page: Int, drawing: PKDrawing) {
        // 調整過頁面結構之後頁碼不再是原本的頁碼；所有頁的初始狀態在那之前已經整批記好了。
        guard pageOrigins == nil else { return }
        if initialPageDrawings[page] == nil { initialPageDrawings[page] = drawing }
        if initialPageInk[page] == nil {
            let dir = store.drawingsDirectory
            initialPageInk[page] = InitialPageInk(
                own: ProInkStore.load(in: dir, notebookId: notebook.id, page: page),
                foreign: ProInkStore.load(in: dir, notebookId: notebook.id, page: page, foreign: true),
                suppressed: ProInkStore.loadSuppressed(in: dir, notebookId: notebook.id, page: page),
                erasedPencilKit: ErasedInkLedger.load(
                    in: store.syncBaselineDirectory, notebookId: notebook.id, page: page))
        }
    }

    /// 把所有頁面還原成第一次載入時的樣子（架構審視 P1：由 PageInkStore 統一回復全本快照）。
    private func restoreInitialPages() {
        let dir = store.drawingsDirectory
        let baselineDir = store.syncBaselineDirectory
        activeInkStore.revertAllPagesToInitialSnapshot(notebook: notebook)
        let count = max(1, notebook.pageCount)
        for page in 0..<count {
            let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
            guard let initial = activeInkStore.initialSnapshot(for: page, pageId: pid) ?? initialPageDrawings[page] else { continue }
            // 這一頁現在的筆畫 → 被還原拿掉的要記進「已擦除」名單，不然同步會把雲端的舊檔帶回來。
            let now = store.loadDrawing(notebookId: notebook.id, pageIndex: page)
            let state = initialPageInk[page]
            var erased = ErasedInkLedger.load(in: baselineDir, notebookId: notebook.id, page: page)
            erased.formUnion(StrokeDelta.removed(in: initial, since: now).map { StrokeDelta.Identity($0).key })
            erased.subtract(initial.strokes.map { StrokeDelta.Identity($0).key })
            ErasedInkLedger.save(erased, in: baselineDir, notebookId: notebook.id, page: page)

            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: initial)
            coreInkBaselines[page] = initial
            if let state {
                ProInkStore.save(state.own, in: dir, notebookId: notebook.id, page: page)
                ProInkStore.save(state.foreign, in: dir, notebookId: notebook.id, page: page, foreign: true)
                ProInkStore.saveSuppressed(state.suppressed, in: dir, notebookId: notebook.id, page: page)
            }
        }
        pendingCoreInk.removeAll()
    }

    func loadCurrentPage() {
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        // 這一本用的是哪一種紙。畫布、分頁、縮圖與匯出都讀這個值 ——
        // 忘了設的話，換到另一本不同規格的筆記時會沿用上一本的尺寸。
        PageGeometry.use(format: notebook.pageFormatId)
        let pid = (notebook.pageIds != nil && currentPageIndex < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[currentPageIndex] : nil
        let loaded = activeInkStore.drawing(for: currentPageIndex, pageId: pid)
        if pendingCoreInk[currentPageIndex] == nil { inkDiskBaselines[currentPageIndex] = loaded }
        self.currentDrawing = loaded
        if pageDisplayMode == .single {
            if let canvas = canvasView as? AdaptiveCanvasView {
                canvas.initialLoadedStrokeCount = loaded.strokes.count
                canvas.forceDisplayRefresh(with: loaded)
                if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                    canvas.accessibilityValue = CanvasRepresentable.testReadout(canvas)
                }
            }
        }
        captureInitialPageState(page: currentPageIndex, drawing: loaded)
        self.lastStrokeCount = loaded.strokes.count
        self.currentPageHeight = notebook.height(forPage: currentPageIndex)
        self.lasso.clear()
        configureLassoCallbacks(forPage: currentPageIndex)
        sanitizeUnderInkObjects()
        self.originalSketchBackup = nil
        self.refinedSketchCache = nil
    }

    /// 把對方傳來的筆跡落到本機。
    ///
    /// # 為什麼不是「有畫布才做」
    ///
    /// 這裡原本整段包在 `if let canvas = canvasView` 裡：畫布還沒建立的那
    /// 一瞬間（剛進編輯器、剛換頁、連續模式下那一頁還沒捲到），對方的筆畫
    /// **連存都不會存** —— 訊息收到了、解密成功了、然後靜靜地被丟掉。
    /// 實機上看到的就是「兩台都顯示已連線，畫下去對面什麼都沒有」，
    /// 而且完全沒有任何錯誤可查。
    ///
    /// 落盤與畫面是兩件事：先無條件落盤，畫布有沒有在都不影響資料。
    private func applyRemoteDrawing(page: Int, remote: PKDrawing, replace: Bool) {
        let isCurrent = (page == currentPageIndex)
        let base: PKDrawing = isCurrent
            ? (canvasView?.drawing ?? currentDrawing)
            : store.loadDrawing(notebookId: notebook.id, pageIndex: page)
        let merged = replace ? remote : base.appending(remote)

        store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: merged)
        guard isCurrent else { return }

        isApplyingRemoteUpdate = true
        currentDrawing = merged
        canvasView?.drawing = merged
        if let adaptive = canvasView as? AdaptiveCanvasView {
            adaptive.forceDisplayRefresh(with: merged)
        }
        lastStrokeCount = merged.strokes.count
        DispatchQueue.main.async {
            isApplyingRemoteUpdate = false
        }
    }

    /// 協同事件：租約搶輸、換房間、舊版參與者。
    private var collabEventSink: AnyView {
        AnyView(Color.clear
            .onReceive(collaborationManager.leaseLost) { lost in
                // 兩人同時選了同一個物件、對方勝出：本機放手（設計 §5.3）。
                if activeSelectedObjectId == lost.id { activeSelectedObjectId = nil }
                if inlineEditingTextId == lost.id { inlineEditingTextId = nil }
                if editingTextId == lost.id { editingTextId = nil }
                selectedObjectIds.remove(lost.id)
                collaborationManager.broadcastSelection(selectedId: nil)
                showCanvasNotice(String(format: localizationManager.localized("collab_object_locked"), lost.holder))
            }
            .onChange(of: collaborationManager.currentRoomId) { _ in
                // 進入（或換）房間：以目前的內容為大家共同的起點。斷線重連不算 ——
                // 那段期間的本機修改還要送出去。
                ensureCollabPageIds()
                collabSync.reset(to: notebook)
                collabInkLedger.reset()
                collabTextHub.reset()
                collabStateSync.reset()
                // 已有的筆畫算「大家都有」—— 否則第一次在某一頁下筆，整頁舊筆畫會被當成新的再送一次，
                // 而對方（尤其是 Android，筆畫 id 不同）會多出一份。
                for (index, id) in (notebook.pageIds ?? []).enumerated() {
                    collabInkLedger.known[id] = Set(CollabInk.ids(of: drawingForCollab(page: index)))
                }
                // 這台的檔案可能比房間裡的舊：向房間裡的人要整份狀態（設計 §7）。只有自己就不必。
                if !collaborationManager.currentRoomId.isEmpty, !collaborationManager.peers.isEmpty {
                    requestCollabState()
                }
            }
            .onReceive(collaborationManager.stateSyncNeeded) { _ in
                // 中繼補不回漏掉的那一段：向其他成員要整份狀態（剛要過就不重複）。
                if Date().timeIntervalSince(collabStateSync.lastRequest) > 5 { requestCollabState() }
            }
            .onChange(of: collaborationManager.outdatedPeerIds) { ids in
                guard !ids.isEmpty else { return }
                showCanvasNotice(localizationManager.localized("collab_peer_outdated"))
            }
        )
    }

    /// 套用別人的物件修改（欄位層級 LWW，設計 §4.1）。
    private func applyRemotePatches(_ patches: [ObjectPatch], stamp: LamportStamp) {
        guard !patches.isEmpty else { return }
        ensureCollabPageIds()
        var doc = notebook
        var changed = false
        var pagesChanged = false
        var anchored: [(id: String, anchors: [[String]])] = []
        for var patch in patches {
            if let b64 = patch.fields.removeValue(forKey: CollabObjectSync.blobField) as? String {
                storeIncomingBlob(b64, fileName: (patch.fields["a.image.fileName"] as? String)
                    ?? (collabSync.shadow[patch.key]?["a.image.fileName"] as? String),
                    hash: patch.fields["blob"] as? String, fallbackId: patch.id)
            }
            if let anchors = patch.fields.removeValue(forKey: CollabObjectSync.anchorField) as? [[String]],
               patch.type == "text", patch.fields["a.runs"] != nil {
                anchored.append((patch.id, anchors))
            }
            if collabSync.apply(patch, stamp: stamp, to: &doc) {
                changed = true
                if patch.type == "page" { pagesChanged = true }
            }
        }
        guard changed else { return }
        collabSync.isApplyingRemote = true
        notebook = doc
        if pagesChanged {
            store.updateNotebook(notebook)
            reconcilePagesWithCollab()
        }
        var withDeferred = notebook
        collabSync.retryDeferred(into: &withDeferred)
        let stacking = collabSync.desiredStacking()
        CollabCanonical.writeStacking(orders: stacking.orders, under: stacking.under, locked: stacking.locked, into: &withDeferred)
        for item in anchored { resolveRunAnchors(id: item.id, anchors: item.anchors, in: &withDeferred) }
        notebook = withDeferred
        // 寫回後的編碼要成為新的同步基準，否則下一次本機修改會把這些欄位當成「我改的」再送一次。
        collabSync.refreshShadow(from: notebook)
        commitNotebook()
        collabSync.isApplyingRemote = false
        PageThumbnailRenderer.invalidateAll()
        // 對方刪掉的物件，本機的選取與編輯狀態要清掉。
        let alive = CanvasObjectState(notebook).allObjectIds
        if let id = inlineEditingTextId, !alive.contains(id) { inlineEditingTextId = nil }
        if let id = editingTextId, !alive.contains(id) { editingTextId = nil }
        if let id = activeSelectedObjectId, !alive.contains(id) { activeSelectedObjectId = nil }
        selectedObjectIds = selectedObjectIds.filter { alive.contains($0) }
    }

    /// 收到新圖片的位元組：存成檔案（已經有就不動），記下它的雜湊。
    private func storeIncomingBlob(_ b64: String, fileName: String?, hash: String?, fallbackId: String) {
        guard let data = Data(base64Encoded: b64) else { return }
        let name = fileName.flatMap { $0.isEmpty ? nil : $0 } ?? "\(hash ?? fallbackId).png"
        let url = store.attachmentsDirectory.appending(path: name)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url, options: .atomic)
        }
        if let hash { CollabCanonical.rememberBlob(fileName: name, hash: hash) }
        _ = store.loadAttachmentImage(fileName: name)
    }

    /// 別人送來的逐字格式：以字的 id 換回這邊現在的位置（設計 §8.3）。
    private func resolveRunAnchors(id: String, anchors: [[String]], in doc: inout NotebookDocument) {
        guard let index = doc.textAttachments?.firstIndex(where: { CollabCanonical.canonicalId($0.id) == id }),
              var item = doc.textAttachments?[index], let runs = item.runs, runs.count == anchors.count else { return }
        let replica = collabTextHub.replica(for: id, base: item.text, site: collaborationManager.currentUserId)
        guard replica.text == item.text else { return }
        let resolved = CollabRunAnchors.resolve(anchors, in: replica)
        var adjusted = runs
        for (i, span) in resolved.enumerated() {
            if let span { adjusted[i].start = span.start; adjusted[i].length = span.length }
        }
        guard adjusted != runs else { return }
        item.runs = adjusted
        doc.textAttachments?[index] = item
    }

    /// 依合併後的頁序調整本機的頁面：補上缺的、刪掉被刪的、搬到對的位置（設計 §8.4）。
    private func reconcilePagesWithCollab() {
        let desired = collabSync.desiredPageOrder()
        guard !desired.isEmpty else { return }
        func reload() {
            if let updated = store.notebooks.first(where: { $0.id == notebook.id }) { notebook = updated }
        }
        // 與本機的頁面操作同一條路：等背景寫入落盤、頁碼暫存照頁面 id 重新對齊、畫布重載。
        changePageStructure {
            var current = notebook.pageIds ?? []
            let wanted = Set(desired)
            let focusedId = currentPageIndex < current.count ? current[currentPageIndex] : nil
            var landing = currentPageIndex
            for (index, id) in current.enumerated().reversed() where !wanted.contains(id) && notebook.pageCount > 1 {
                landing = store.deletePage(notebookId: notebook.id, pageIndex: index, currentIndex: landing)
                reload()
            }
            current = notebook.pageIds ?? []
            for (target, id) in desired.enumerated() where !current.contains(id) {
                let paper = collabSync.shadow["page:\(id)"]?["paper"] as? String
                _ = store.insertPage(notebookId: notebook.id, afterIndex: min(target, current.count) - 1,
                                     paperId: paper, pageId: id)
                reload()
                current = notebook.pageIds ?? []
            }
            for (target, id) in desired.enumerated() {
                guard let from = current.firstIndex(of: id), from != target, target < current.count else { continue }
                _ = store.movePage(notebookId: notebook.id, from: from, to: target)
                reload()
                current = notebook.pageIds ?? []
            }
            // 停在同一頁的內容上（照頁面 id 找）；那一頁被刪掉了才退回刪除後的頁碼。
            return focusedId.flatMap { current.firstIndex(of: $0) } ?? landing
        }
    }

    /// 套用別人在同一個文字方塊打的字（設計 §8.3）。
    private func applyRemoteTextOps(_ payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              let list = payload["ops"] as? [[String: Any]],
              let fullText = payload["text"] as? String,
              let index = notebook.textAttachments?.firstIndex(where: { CollabCanonical.canonicalId($0.id) == id })
        else { return }
        let me = collaborationManager.currentUserId
        let current = notebook.textAttachments?[index].text ?? ""
        let base = (collabSync.shadow["text:\(id)"]?["text"] as? String) ?? current
        let replica = collabTextHub.replica(for: id, base: base, site: me)
        var newText: String
        if let theirBase = payload["base"] as? String, theirBase != replica.baseHash, replica.text == base {
            // 兩邊的基準對不上（協同開始前就不一致）：以對方的全文為準並重建基準 —— 結果仍一致。
            collabTextHub.rebase(id, text: fullText, site: me)
            newText = fullText
        } else {
            for json in list { if let op = CollabText.Op(json: json) { replica.apply(op) } }
            newText = replica.text
        }
        guard newText != current else { return }
        collabSync.isApplyingRemote = true
        replaceCollabText(at: index, with: newText, in: &notebook)
        collabSync.refreshShadow(from: notebook)
        commitNotebook()
        collabSync.isApplyingRemote = false
        PageThumbnailRenderer.invalidateAll()
    }

    /// 把某個方塊的內容換成別人的（格式區段跟著平移、方塊長高），不送出。
    private func replaceCollabText(at index: Int, with newText: String, in doc: inout NotebookDocument) {
        guard var item = doc.textAttachments?[index], item.text != newText else { return }
        let old = item.text
        item.text = newText
        RichText.adjustRuns(of: &item, from: old)
        item.height = max(item.height, RichText.boxHeight(for: item))
        doc.textAttachments?[index] = item
    }

    /// 別人加的筆畫：已經有的（同 id）不重複加。
    private func applyRemoteInkAdd(pageId: String, strokes list: [[String: Any]]) {
        guard let pageIdx = notebook.pageIds?.firstIndex(of: pageId) else { return }
        let known = collabInkLedger.known[pageId] ?? []
        let decoded = list.compactMap(CollabStroke.decode).filter { !known.contains($0.id) }
        guard !decoded.isEmpty else { return }
        for item in decoded { collabInkLedger.remember(wire: item.id, local: CollabInk.strokeId(item.stroke)) }
        let base = drawingForCollab(page: pageIdx)
        let merged = CollabInk.adding(decoded.map(\.stroke), to: base)
        collabInkLedger.known[pageId, default: []].formUnion(decoded.map(\.id))
        collabInkLedger.added(page: pageId, wires: decoded.map(\.id))
        if merged.strokes.count != base.strokes.count {
            applyRemoteDrawing(page: pageIdx, remote: merged, replace: true)
        }
    }

    /// 別人擦掉的筆畫：只移除這幾筆，別人同時畫的不受影響。
    private func applyRemoteInkRemove(pageId: String, wires: [String]) {
        guard let pageIdx = notebook.pageIds?.firstIndex(of: pageId), !wires.isEmpty else { return }
        let base = drawingForCollab(page: pageIdx)
        let merged = CollabInk.removing(Set(wires.map(collabInkLedger.localId(forWire:))), from: base)
        collabInkLedger.known[pageId, default: []].subtract(wires)
        collabInkLedger.removed(page: pageId, wires: wires)
        if merged.strokes.count != base.strokes.count {
            applyRemoteDrawing(page: pageIdx, remote: merged, replace: true)
        }
    }

    // MARK: 整份狀態（設計 §7）

    /// 向房間要整份狀態（加入房間、或中繼的暫存已經補不回漏掉的那一段）。
    /// 附上自己已有的圖片：回覆的人只需帶我沒有的圖檔。
    private func requestCollabState() {
        guard isCollaborating else { return }
        let req = collabStateSync.begin()
        let blobs = Set(collabSync.shadow.values.compactMap { $0["blob"] as? String })
        collaborationManager.broadcastOplog(kind: "state_request", payload: [
            "proto": Self.collabProto, "req": req, "blobs": Array(blobs)
        ])
    }

    /// 回覆一份整份狀態給 `to`，分段送。
    private func answerCollabState(req: String, to: String, blobs: Set<String>) {
        collabStateSync.remember(req)
        func size(_ json: [String: Any]) -> Int { (try? JSONSerialization.data(withJSONObject: json))?.count ?? 0 }
        var items: [(ink: Bool, json: [String: Any])] = []
        for entry in collabSync.snapshot() {
            var json = entry.json
            if entry.type == "image",
               let hash = entry.groups.lazy.compactMap({ $0.fields["blob"] as? String }).first, !blobs.contains(hash),
               let fileName = collabSync.shadow[entry.key]?["a.image.fileName"] as? String, !fileName.isEmpty,
               let data = try? Data(contentsOf: store.attachmentsDirectory.appending(path: fileName)) {
                json["b64"] = data.base64EncodedString()
            }
            items.append((false, json))
        }
        // 筆跡：只帶這次協同期間加入與擦掉的 —— 之前就有的兩邊都有（設計 §8.1）。
        let pages = Set(collabInkLedger.sessionAdded.keys).union(collabInkLedger.sessionRemoved.keys)
        for page in pages {
            let wanted = collabInkLedger.sessionAdded[page] ?? []
            var strokes: [[String: Any]] = []
            if !wanted.isEmpty, let index = notebook.pageIds?.firstIndex(of: page) {
                for stroke in drawingForCollab(page: index).strokes {
                    let wire = collabInkLedger.wireId(for: stroke)
                    if wanted.contains(wire) { strokes.append(CollabStroke.encode(stroke, id: wire)) }
                }
            }
            items.append((true, ["page": page, "strokes": strokes,
                                 "removed": Array(collabInkLedger.sessionRemoved[page] ?? [])]))
        }
        var parts: [(objects: [[String: Any]], ink: [[String: Any]])] = [([], [])]
        var bytes = 0
        for item in items {
            let length = size(item.json)
            if bytes > 0, bytes + length > CollabStateSync.partBytes {
                parts.append(([], []))
                bytes = 0
            }
            if item.ink { parts[parts.count - 1].ink.append(item.json) } else { parts[parts.count - 1].objects.append(item.json) }
            bytes += length
        }
        for (index, part) in parts.enumerated() {
            collaborationManager.broadcastOplog(kind: "state_snapshot", payload: [
                "proto": Self.collabProto, "req": req, "to": to, "part": index, "parts": parts.count,
                "objects": part.objects, "ink": part.ink
            ])
        }
    }

    /// 收到整份狀態的一段。全部收齊後，「只有自己有」的物件補給房間。
    private func applyCollabStateSnapshot(_ payload: [String: Any]) {
        let req = (payload["req"] as? String) ?? ""
        collabStateSync.remember(req)
        guard req == collabStateSync.pendingRequest,
              payload["to"] as? String == collaborationManager.currentUserId,
              let part = (payload["part"] as? NSNumber)?.intValue,
              collabStateSync.receivedParts.insert(part).inserted else { return }
        let parts = (payload["parts"] as? NSNumber)?.intValue ?? 1
        ensureCollabPageIds()
        var entries: [SnapshotEntry] = []
        for json in (payload["objects"] as? [[String: Any]]) ?? [] {
            guard let entry = SnapshotEntry(json: json) else { continue }
            if let b64 = json["b64"] as? String {
                let fields = entry.groups.reduce(into: [String: Any]()) { $0.merge($1.fields) { a, _ in a } }
                storeIncomingBlob(b64, fileName: fields["a.image.fileName"] as? String,
                                  hash: fields["blob"] as? String, fallbackId: entry.id)
            }
            entries.append(entry)
        }
        collabStateSync.snapshotKeys.formUnion(entries.map(\.key))
        let me = collaborationManager.currentUserId
        collabSync.isApplyingRemote = true
        var doc = notebook
        let result = collabSync.applySnapshot(entries, to: &doc)
        notebook = doc
        if entries.contains(where: { $0.type == "page" }) {
            store.updateNotebook(notebook)
            reconcilePagesWithCollab()
        }
        var withDeferred = notebook
        collabSync.retryDeferred(into: &withDeferred)
        let stacking = collabSync.desiredStacking()
        CollabCanonical.writeStacking(orders: stacking.orders, under: stacking.under, locked: stacking.locked, into: &withDeferred)
        for override in result.textOverrides {
            collabTextHub.rebase(override.id, text: override.text, site: me)
            if let index = withDeferred.textAttachments?.firstIndex(where: { CollabCanonical.canonicalId($0.id) == override.id }) {
                replaceCollabText(at: index, with: override.text, in: &withDeferred)
            }
        }
        notebook = withDeferred
        collabSync.refreshShadow(from: notebook)
        commitNotebook()
        collabSync.isApplyingRemote = false
        for pageInk in (payload["ink"] as? [[String: Any]]) ?? [] {
            guard let page = pageInk["page"] as? String else { continue }
            if let strokes = pageInk["strokes"] as? [[String: Any]] { applyRemoteInkAdd(pageId: page, strokes: strokes) }
            if let removed = pageInk["removed"] as? [String] { applyRemoteInkRemove(pageId: page, wires: removed) }
        }
        PageThumbnailRenderer.invalidateAll()
        guard collabStateSync.receivedParts.count >= parts else { return }
        collabStateSync.finish()
        // 只有自己有的物件（例如離線時新增的）：忘掉它們，下一次送出就會當成新的補給房間。
        let localOnly = collabSync.liveKeys.subtracting(collabStateSync.snapshotKeys).filter { !$0.hasPrefix("meta:") }
        guard !localOnly.isEmpty else { return }
        collabSync.forget(localOnly)
        publishCollabChanges()
    }

    /// 協同套用筆跡時的基準：目前頁取畫面上的，其他頁取存檔的。
    private func drawingForCollab(page: Int) -> PKDrawing {
        page == currentPageIndex
            ? (canvasView?.drawing ?? currentDrawing)
            : store.loadDrawing(notebookId: notebook.id, pageIndex: page)
    }

    /// 處理協同遠端廣播操作（CRDT Oplog 合併）
    /// 別台送來的變更不算這台使用者的動作：不登記復原（否則按復原會把別人的修改退掉）。
    private func handleRemoteOplog(_ event: RemoteOplogEvent) {
        objectHistory.withoutRecording { applyRemoteOplog(event) }
    }

    private func applyRemoteOplog(_ event: RemoteOplogEvent) {
        switch event.kind {
        case "obj_patch":
            guard let list = event.payload["patches"] as? [[String: Any]] else { return }
            applyRemotePatches(list.compactMap(ObjectPatch.init(payload:)),
                               stamp: LamportStamp(lamport: event.lamport, user: event.userId))

        case "ink_add":
            guard let pageId = event.payload["page"] as? String,
                  let list = event.payload["strokes"] as? [[String: Any]] else { return }
            applyRemoteInkAdd(pageId: pageId, strokes: list)

        case "ink_remove":
            guard let pageId = event.payload["page"] as? String,
                  let ids = event.payload["ids"] as? [String] else { return }
            applyRemoteInkRemove(pageId: pageId, wires: ids)

        case "state_request":
            guard let req = event.payload["req"] as? String else { return }
            // 排名：除了請求者以外，依使用者 id 排序。第一名立刻回，其餘的人依序多等一下。
            let everyone = (collaborationManager.peers.map(\.userId) + [collaborationManager.currentUserId])
                .filter { $0 != event.userId }.sorted()
            let rank = everyone.firstIndex(of: collaborationManager.currentUserId) ?? 0
            let blobs = Set((event.payload["blobs"] as? [String]) ?? [])
            let requester = event.userId
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(rank) * CollabStateSync.answerStagger) {
                guard isCollaborating, !collabStateSync.wasAnswered(req) else { return }
                answerCollabState(req: req, to: requester, blobs: blobs)
            }

        case "state_snapshot":
            applyCollabStateSnapshot(event.payload)

        case "text_ops":
            applyRemoteTextOps(event.payload)

        case "stroke_delta", "drawing_replace":
            // 舊版送來的筆跡：一律當成「加入缺少的筆畫」，**不刪任何東西** ——
            // 舊的整頁取代會把本機同時畫的筆畫蓋掉。
            guard let pageIdx = event.payload["page_index"] as? Int,
                  let b64 = event.payload["drawing_base64"] as? String,
                  let data = Data(base64Encoded: b64),
                  let remoteDrawing = try? PKDrawing(data: data) else { return }
            let base = drawingForCollab(page: pageIdx)
            let merged = CollabInk.adding(remoteDrawing.strokes, to: base)
            if merged.strokes.count != base.strokes.count {
                applyRemoteDrawing(page: pageIdx, remote: merged, replace: true)
            }

        case "attachment_delete":
            // 舊版的刪除：當成一筆帶時鐘的刪除修改，與新版走同一套合併。
            guard let attId = event.payload["id"] as? String,
                  let attType = event.payload["attachment_type"] as? String else { return }
            applyRemotePatches([ObjectPatch(type: attType, id: attId, fields: [ObjectPatch.deletedField: true])],
                               stamp: LamportStamp(lamport: event.lamport, user: event.userId))

        case "attachment_upsert":
            // 舊版的整個物件：當成「所有欄位」的修改，以它的時鐘參與合併。
            guard let attType = event.payload["attachment_type"] as? String,
                  var itemDict = event.payload["item"] as? [String: Any],
                  let itemId = itemDict["id"] as? String else { return }
            if let b64 = itemDict.removeValue(forKey: "image_base64") as? String {
                itemDict[CollabObjectSync.blobField] = b64
            }
            itemDict[ObjectPatch.deletedField] = false
            applyRemotePatches([ObjectPatch(type: attType, id: itemId, fields: itemDict)],
                               stamp: LamportStamp(lamport: event.lamport, user: event.userId))

        case "comment_upsert":
            guard let pinDict = event.payload["pin"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: pinDict),
                  let pin = try? JSONDecoder().decode(NoteCommentPin.self, from: jsonData) else { return }

            if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pin.id }) {
                notebook.commentPins?[idx] = pin
            } else {
                if notebook.commentPins == nil { notebook.commentPins = [] }
                notebook.commentPins?.append(pin)
            }
            commitNotebook()

        case "comment_resolve":
            guard let pinId = event.payload["pin_id"] as? String,
                  let isResolved = event.payload["is_resolved"] as? Bool else { return }

            if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
                notebook.commentPins?[idx].isResolved = isResolved
                commitNotebook()
            }

        case "comment_delete":
            guard let pinId = event.payload["pin_id"] as? String else { return }
            notebook.commentPins?.removeAll { $0.id == pinId }
            if selectedCommentPinId == pinId {
                selectedCommentPinId = nil
            }
            commitNotebook()

        default:
            break
        }
    }

    private func broadcastCommentPinUpsert(_ pin: NoteCommentPin) {
        guard let data = try? JSONEncoder().encode(pin),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        collaborationManager.broadcastCommentUpsert(pinDict: dict)
    }

    private func addCommentReply(pinId: String, text: String) {
        let msg = NoteCommentMessage(
            authorId: collaborationManager.currentUserId,
            authorName: AccountManager.shared.profile.displayName,
            authorColor: collaborationManager.myColorHex,
            text: text
        )
        if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
            notebook.commentPins?[idx].messages.append(msg)
            commitNotebook()
            if let pin = notebook.commentPins?[idx] {
                broadcastCommentPinUpsert(pin)
            }
        }
    }

    private func toggleCommentResolve(pinId: String) {
        if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
            notebook.commentPins?[idx].isResolved.toggle()
            let state = notebook.commentPins?[idx].isResolved ?? false
            commitNotebook()
            collaborationManager.broadcastCommentResolve(pinId: pinId, isResolved: state)
        }
    }

    /// 刪除討論串中的單一則留言。
    /// 只剩最後一則時不刪 —— 沒有任何訊息的圖釘在畫布上等於一個看不出用途的點，
    /// 要整個移除請用圖釘上的垃圾桶。
    private func deleteCommentMessage(pinId: String, messageId: String) {
        guard let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }),
              let count = notebook.commentPins?[idx].messages.count,
              count > 1 else { return }
        notebook.commentPins?[idx].messages.removeAll { $0.id == messageId }
        commitNotebook()
        if let pin = notebook.commentPins?[idx] {
            broadcastCommentPinUpsert(pin)
        }
    }

    private func deleteCommentPin(pinId: String) {
        notebook.commentPins?.removeAll { $0.id == pinId }
        commitNotebook()
        selectedCommentPinId = nil
        collaborationManager.broadcastCommentDelete(pinId: pinId)
        collaborationManager.broadcastSelection(selectedId: nil)
    }

    /// 使用者明確開始了一個新動作（開始編輯、刪除、拖曳…）：下一個變更另起一步，
    /// 不跟前一個連續變動合併。
    private func recordTextUndoState() {
        objectHistory.breakCoalescing()
    }

    /// 全域復原用的 manager：畫布的（與 PencilKit、專業筆畫共用）。
    var historyUndoManager: UndoManager {
        canvasView?.undoManager ?? fallbackUndoManager
    }

    /// 編輯器寫回筆記本的唯一入口：先讓物件復原紀錄比對這一次的變更，再存檔。
    func commitNotebook() {
        objectHistory.record(notebook, manager: historyUndoManager) { state in
            applyHistoryState(state)
        }
        store.updateNotebook(notebook)
        publishCollabChanges()
    }

    /// 本機的物件修改即時送給協同的每一個人（設計 §2.1）。
    ///
    /// **所有修改都經過這裡**（`commitNotebook` 與復原／重做），所以框選搬移、圖層、核取方塊、
    /// 紙張、復原…不會再有「這一種忘了廣播」。一次寫回的所有變動放在同一個操作裡，對方一次套用。
    private func publishCollabChanges() {
        guard isCollaborating, !collabSync.isApplyingRemote else { return }
        ensureCollabPageIds()
        let me = collaborationManager.currentUserId
        let lamport = collaborationManager.nextLamport()
        let outgoing = collabSync.outgoing(for: notebook, stamp: LamportStamp(lamport: lamport, user: me))
        guard !outgoing.isEmpty else { return }

        // 文字內容先送：對方先有了新的字，後面帶格式錨點的修改才認得那些字的 id（設計 §8.3）。
        for edit in outgoing.textEdits {
            let replica = collabTextHub.replica(for: edit.id, base: edit.old, site: me)
            let ops = replica.localEdit(from: edit.old, to: edit.new)
            guard !ops.isEmpty else { continue }
            collaborationManager.broadcastOplog(kind: "text_ops", payload: [
                "proto": Self.collabProto, "id": edit.id, "base": replica.baseHash, "text": edit.new,
                "ops": ops.map(\.json)
            ])
        }
        if !outgoing.patches.isEmpty {
            var patches = outgoing.patches
            for index in patches.indices where patches[index].type == "text" {
                if let anchors = runAnchors(for: patches[index]) { patches[index].fields[CollabObjectSync.anchorField] = anchors }
            }
            for index in patches.indices where (patches[index].fields[ObjectPatch.deletedField] as? Bool) == false {
                // 新的圖片要連檔案一起送，否則對方只收到一個空框。
                if patches[index].type == "image",
                   let fileName = collabSync.shadow[patches[index].key]?["a.image.fileName"] as? String,
                   let data = try? Data(contentsOf: store.attachmentsDirectory.appending(path: fileName)) {
                    patches[index].fields[CollabObjectSync.blobField] = data.base64EncodedString()
                }
            }
            collaborationManager.broadcastOplog(
                kind: "obj_patch", payload: ["proto": Self.collabProto, "patches": patches.map(\.payload)], lamport: lamport)
            // 新增（或複製出來）的頁面：上面已有的筆畫也要送，否則對方只看到一張空白頁。
            for patch in patches where patch.type == "page"
                && (patch.fields[ObjectPatch.deletedField] as? Bool) == false {
                if let index = notebook.pageIds?.firstIndex(of: patch.id) {
                    broadcastDrawingChange(page: index, drawing: drawingForCollab(page: index))
                }
            }
        }
    }

    /// 協定版本（設計 §8）。4：堆疊順序是物件欄位、格式錨點、整份狀態。
    static let collabProto = 4

    /// 這次修改帶了逐字格式：把每段的頭尾換成字的 id（設計 §8.3）。
    private func runAnchors(for patch: ObjectPatch) -> [[String]]? {
        guard let runs = patch.fields["a.runs"] as? [[String: Any]],
              let text = collabSync.shadow[patch.key]?["text"] as? String else { return nil }
        let replica = collabTextHub.replica(for: patch.id, base: text, site: collaborationManager.currentUserId)
        guard replica.text == text else { return nil }
        let spans = runs.map { ((($0["start"] as? NSNumber)?.intValue) ?? 0, (($0["length"] as? NSNumber)?.intValue) ?? 0) }
        return CollabRunAnchors.anchors(spans.map { (start: $0.0, length: $0.1) }, in: replica)
    }

    /// 協同要以頁面 id 指稱頁面（設計 §8.1）：還沒有的話沿用套件裡的那一批。
    private func ensureCollabPageIds() {
        CollabCanonical.attachmentsDirectory = store.attachmentsDirectory
        let ids = NotebookPackageBridge.resolvedPageIds(for: notebook, packagesDirectory: store.syncPackagesDirectory)
        guard notebook.pageIds != ids else { return }
        notebook.pageIds = ids
        store.updateNotebook(notebook)
    }

    /// 套上復原／重做的物件狀態。筆跡不動（它由 PencilKit 自己復原）。
    private func applyHistoryState(_ state: CanvasObjectState) {
        var doc = notebook
        state.apply(to: &doc)
        // 協同中：別人在我之後改過的欄位保留別人的值（設計 §6）。復原只退自己的動作。
        if isCollaborating,
           collabSync.protectRemoteEdits(target: &doc, current: notebook, me: collaborationManager.currentUserId) {
            objectHistory.reset(to: doc)
            showCanvasNotice(localizationManager.localized("collab_undo_partial"))
        }
        notebook = doc
        store.updateNotebook(notebook)
        publishCollabChanges()
        PageThumbnailRenderer.invalidateAll()
        thumbnailRevision += 1
        // 指向已經不存在的物件的選取與編輯狀態要清掉，否則工具列對著一個空殼。
        let alive = state.allObjectIds
        if let id = inlineEditingTextId, !alive.contains(id) { inlineEditingTextId = nil }
        if let id = editingTextId, !alive.contains(id) { editingTextId = nil }
        if let id = activeSelectedObjectId, !alive.contains(id) { activeSelectedObjectId = nil }
        if let id = textFormatTargetId, !alive.contains(id) { endTextFormatSession() }
        selectedObjectIds = selectedObjectIds.filter { alive.contains($0) }
        selectedShapeIds = selectedShapeIds.filter { alive.contains($0) }
    }

    /// 復原：筆跡、專業筆畫、物件的任何操作，照發生順序退一步。
    func performUndo() { stepHistory(undo: true) }

    /// 重做（協同時只重做自己的操作）。
    func performRedo() { stepHistory(undo: false) }

    /// 退一步／進一步，**跳過沒有效果的項目**。
    ///
    /// 堆疊裡會有空的或已經失效的項目：作廢物件紀錄後留下的空群組、程式替換筆畫後
    /// PencilKit 指向不存在筆畫的那一項。照實執行的話使用者按一次復原什麼都沒發生，
    /// 以為功能壞了。所以一直退到畫面真的有變（物件、筆跡或專業筆畫）為止。
    private func stepHistory(undo: Bool) {
        let manager = historyUndoManager
        for _ in 0..<12 {
            guard undo ? manager.canUndo : manager.canRedo else {
                CanvasDiag.log(undo ? "復原：沒有可復原的項目" : "重做：沒有可重做的項目")
                return
            }
            let canvas = canvasView as? AdaptiveCanvasView
            let drawingBefore = canvasView?.drawing
            let proBefore = canvas?.proLayer?.ownStrokes.map(\.id)
            let appliedBefore = objectHistory.appliedCount
            var proChanged = false
            let token = NotificationCenter.default.addObserver(
                forName: AppCommand.proInkDidChange, object: nil, queue: nil) { _ in proChanged = true }
            if undo { manager.undo() } else { manager.redo() }
            NotificationCenter.default.removeObserver(token)

            if objectHistory.appliedCount != appliedBefore {
                CanvasDiag.log(undo ? "復原：物件" : "重做：物件")
                return
            }
            if canvasView?.drawing != drawingBefore || proChanged
                || canvas?.proLayer?.ownStrokes.map(\.id) != proBefore {
                CanvasDiag.log(undo ? "復原：筆畫" : "重做：筆畫")
                return
            }
            CanvasDiag.log(undo ? "復原：略過一個沒有效果的項目" : "重做：略過一個沒有效果的項目")
        }
    }

    /// 接住拖進畫布的圖片（工作項 S-68）。
    ///
    /// 回傳值是**同步**的「我要不要接這一批」—— 圖片是非同步載進來的，
    /// 等載完再回答的話系統早就把拖放取消掉了。所以這裡看的是「有沒有
    /// 任何一個來源給得出圖」，真正的插入在回呼裡做。
    private func acceptImageDrop(
        _ providers: [NSItemProvider], at location: CGPoint, page: Int
    ) -> Bool {
        guard providers.contains(where: { $0.canLoadObject(ofClass: UIImage.self) }) else {
            return false
        }
        ImageDropLoader.firstImage(from: providers) { image in
            guard let image else { return }
            insertImageAttachment(image, at: location, page: page)
            // 插進來之後切到打字模式：手寫模式下物件不吃觸控，使用者剛拖
            // 進來的圖會拖不動，看起來像插壞了。Android 端也是這樣做。
            transitionToMode(.type)
        }
        return true
    }

    /// 拖放時的落點提示。
    @ViewBuilder
    private func canvasDropHighlight(_ targeted: Bool) -> some View {
        if targeted {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .background(Color.accentColor.opacity(0.08))

                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text(L("multi_window_drop_hint"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(20)
                .shadow(radius: 6)
            }
            .allowsHitTesting(false)
        }
    }

    /// 筆身上的動作（雙擊、擠壓、側鍵、反向筆頭）發生了。
    ///
    /// **規則不在這裡。** 「這個動作要做什麼」整張表在核心
    /// （`padnote-input::pen`），與 Android 共用同一份 —— 各寫一套的話，
    /// 同一支筆在兩台裝置上行為會不同。這裡只負責把核心回的結果換成
    /// 這個 App 的工具。
    ///
    /// 打字模式下不理會：那時候畫布根本不收筆畫，換工具只會讓使用者切回
    /// 手寫時發現筆莫名其妙變了。
    private func applyPenControl(_ control: FfiPenControl, pressed: Bool) {
        guard isCanvasInkActive else { return }

        let settings = PenHardwareSettings.shared
        // 按著的控制項（側鍵、反向筆頭）放開時，只還原**我們自己切過去的
        // 那一次**。使用者自己在工具列上選了橡皮擦、然後碰了一下側鍵，
        // 放開時把他的橡皮擦換掉是錯的。
        if settings.isMomentary(control) {
            if pressed {
                penHeldTool = selectedTool
            } else if penHeldTool == nil {
                return
            }
        }

        let outcome = settings.controls.outcome(
            control: control,
            pressed: pressed,
            erasing: selectedTool == .eraser,
            lassoing: selectedTool == .lasso)

        switch outcome {
        case .nothing:
            return
        case .useEraser:
            selectedTool = .eraser
        case .useLastBrush:
            // 放開時回到按下去之前那支，而不是「最後用過的筆刷」——
            // 兩者通常一樣，但使用者若在按著側鍵的期間又換過筆，
            // 他要的是回到他剛剛選的那一支。
            selectedTool = penHeldTool ?? lastBrushTool
        case .useLasso:
            selectedTool = .lasso
        case .showInkAttributes:
            showProColorPicker = true
        case .undo:
            performUndo()
        case .redo:
            performRedo()
        case .toggleRuler:
            isRulerActive.toggle()
        }

        if settings.isMomentary(control) && !pressed {
            penHeldTool = nil
        }
        // 筆身的動作是看不見的 —— 使用者當下正看著筆尖，一下短回饋讓他
        // 知道剛剛那下有收到，不必抬頭確認工具列。
        PenHaptics.penControlFired(in: canvasView)
    }

    /// 筆跡動過了。去抖動之後把筆記標記成剛改過並落盤。
    ///
    /// 1.2 秒與同步排程器的去抖動（1.5 秒）刻意錯開：先把本機狀態定下來，
    /// 再讓同步那一輪去看已經穩定的內容。反過來的話，同步會拿到寫到一半的
    /// 那個瞬間，然後下一輪再傳一次。
    private func noteInkEdited() {
        inkTouchWork?.cancel()
        let work = DispatchWorkItem {
            // `updateNotebook` 自己會蓋上現在的時間，並在 `persistData()`
            // 裡通知自動同步。這裡不碰 `AccountSyncStore` —— 內容改動不是
            // 中繼資料改動，把時戳往前推會讓這台裝置永遠贏過另一台對同一本
            // 筆記的改名，而那次改名其實比較晚。
            commitNotebook()
        }
        inkTouchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func corePackageURL() -> URL {
        store.corePackagesDirectory.appending(path: "\(notebook.id.lowercased()).padnote")
    }

    /// 取得指定頁面的手寫筆跡（統一自 PageInkStore 讀取，單一真相）
    func drawingForPage(_ page: Int) -> PKDrawing {
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        return activeInkStore.drawing(for: page, pageId: pid)
    }

    private func recordDrawingEdit(page: Int, drawing: PKDrawing) {
        if page == currentPageIndex {
            currentDrawing = drawing
        }
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        activeInkStore.updateDrawing(drawing, for: page, pageId: pid)
        continuousCanvases.setCachedDrawing(drawing, forPage: page)
        pendingCoreInk[page] = drawing
        scheduleCoreInkFlush()
        noteInkEdited()
    }

    /// 落筆之後多久把增量寫進套件。
    ///
    /// 原本是 1.2 秒，那是「另一台看得到」之前**必經的第一段** —— 再加上同步排程器
    /// 的去抖動，一筆畫要兩秒多之後才開始往外送。這一步只是把增量追加進套件
    /// （一個小檔案的 append）與寫 `.drawing`，並不昂貴；真正昂貴的
    /// `updateNotebook()`（寫 `notebooks.json`、整棵畫面重算）仍由 `noteInkEdited()`
    /// 的 1.2 秒去抖動負責，沒有動。
    ///
    /// 純去抖動有個缺點：一直不停手就一直不寫。所以有上限 ——
    /// 這一批待寫的筆畫最早的那一筆起算，超過 `inkFlushMaxHold` 就不再等。
    private static let inkFlushDelay: TimeInterval = 0.4
    private static let inkFlushMaxHold: TimeInterval = 1.5

    private func scheduleCoreInkFlush() {
        coreInkWork?.cancel()
        let now = Date()
        let firstPending = coreInkFirstPendingAt ?? now
        coreInkFirstPendingAt = firstPending
        let remainingHold = Self.inkFlushMaxHold - now.timeIntervalSince(firstPending)
        let delay = max(0, min(Self.inkFlushDelay, remainingHold))
        let work = DispatchWorkItem {
            flushPendingCoreInk()
        }
        coreInkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// 把筆跡增量寫進核心套件的**背景序列佇列**。同一個套件的寫入必須排隊（順序就是筆畫的順序）。
    private static let coreInkQueue = DispatchQueue(label: "kairumo.editor.core-ink", qos: .utility)

    /// 等背景佇列把已排進去的寫入做完，再在主執行緒上做 `work`。**不阻塞主執行緒。**
    /// 佇列是序列的，所以排在它後面就保證前面的寫入都完成了。
    func afterCoreInkWrites(_ work: @escaping @MainActor () -> Void) {
        Self.coreInkQueue.async {
            Task { @MainActor in work() }
        }
    }

    /// 進背景時讓寫入佇列做完：向系統要背景時間，佇列空了就交還。主執行緒不等。
    private func finishCoreInkInBackground() {
        #if os(iOS)
        final class TaskBox: @unchecked Sendable { var id = UIBackgroundTaskIdentifier.invalid }
        let box = TaskBox()
        func end() {
            guard box.id != .invalid else { return }
            UIApplication.shared.endBackgroundTask(box.id)
            box.id = .invalid
        }
        box.id = UIApplication.shared.beginBackgroundTask(withName: "kairumo.core-ink") { end() }
        Self.coreInkQueue.async {
            Task { @MainActor in end() }
        }
        #endif
    }

    /// 把待寫的筆跡存起來，並把「新增的筆畫」追加進核心套件。
    ///
    /// 套件寫入與 `.drawing` 序列化／落盤都在背景序列佇列執行。它們要開檔、重播、序列化並寫好幾個檔，
    /// 在檔案系統慢的裝置上（例如文件庫放在 iCloud 資料夾的 iPad）一次可以卡主執行緒十幾秒 —— 使用者看到的是換畫筆之後
    /// 整條工具列點不動。卡頓記錄的堆疊樣本與存檔標記就是停在這一步。
    ///
    /// 基準先**樂觀地**設成這一版：後面再來的存檔是跟這一版比。背景佇列是序列的，所以第一個工作
    /// （從套件讀基準）一定先於第二個。寫入失敗的在主執行緒補回待寫名單、把基準清掉，下一輪從套件重算。
    private func flushPendingCoreInk() {
        MainThreadStallMonitor.shared.breadcrumb("flushPendingCoreInk(\(notebook.id.prefix(8)))")
        coreInkWork?.cancel()
        coreInkWork = nil
        coreInkFirstPendingAt = nil
        let pending = pendingCoreInk
        pendingCoreInk.removeAll()
        guard !pending.isEmpty else { return }

        var jobs: [CoreInkFlush.Job] = []
        for (page, drawing) in pending {
            MainThreadStallMonitor.shared.breadcrumb("flush p\(page) saveDrawing (\(drawing.strokes.count) strokes)")
            let drawingURL = store.drawingsDirectory.appending(path: "\(notebook.id)_p\(page).drawing")
            // 僅先更新記憶體快取，實際序列化與磁碟寫入統一交由背景 coreInkQueue 的 CoreInkFlush.apply 執行，
            // 避免切換模式或落筆存檔時在主執行緒上同步阻塞。
            NotebookStore.primeDrawingCache(drawing, for: drawingURL)
            continuousCanvases.setCachedDrawing(drawing, forPage: page)
            jobs.append(CoreInkFlush.Job(
                page: page, drawing: drawing, drawingFileURL: drawingURL,
                cachedBaseline: coreInkBaselines[page]))
            coreInkBaselines[page] = drawing
            inkDiskBaselines[page] = drawing
        }

        let document = notebook
        let package = corePackageURL()
        let baselineDirectory = store.syncBaselineDirectory
        let deviceId = NotebookMigration.deviceId
        nonisolated(unsafe) let jobsCopy = jobs
        Self.coreInkQueue.async {
            let failed = CoreInkFlush.apply(
                jobsCopy, document: document, package: package,
                baselineDirectory: baselineDirectory, deviceId: deviceId)
            nonisolated(unsafe) let failedCopy = failed
            DispatchQueue.main.async {
                // 保留下一輪再試；不要因為核心套件暫時寫不進去而丟掉 Apple 端的即時 `.drawing` 自動存檔。
                for item in failedCopy {
                    pendingCoreInk[item.page] = item.drawing
                    coreInkBaselines[item.page] = nil
                }
                // 增量寫進套件**之後**才通知焦點通道 —— 先通知的話，它可能推到還沒寫完的檔案。
                FocusSyncController.shared.noteLocalEdit()
            }
        }
    }

    func saveCurrentPageDrawing() {
        // 明確存檔就把待辦的去抖動取消掉 —— 留著的話 1.2 秒後會再寫一次
        // 一模一樣的內容。
        inkTouchWork?.cancel()
        inkTouchWork = nil
        if pageDisplayMode == .continuous {
            let hadPendingInk = !pendingCoreInk.isEmpty
            flushPendingCoreInk()
            // 沒有待寫的墨跡、文件也跟 store 裡一樣，就不要「碰」這本筆記。
            // 每次碰都會把修改時間往前推並通知同步「本機有編輯」，於是只是切換模式、
            // 點縮圖跳頁，同步就匯出重建一次套件、下載、再觸發編輯器重載 ——
            // 同步日誌裡那串首尾相接、每一輪都「匯出 1 本、下載 4」的迴圈就是這樣來的。
            if !hadPendingInk && !proInkDirty && store.notebookMatchesStored(notebook) { return }
            proInkDirty = false
            notebook.lastModifiedDate = Date()
            commitNotebook()
            return
        }
        // 模式切換會立即觸發 SwiftUI 更新；`@Binding` 的最後一次回寫有可能還
        // 排在同一個 run loop 後面。此時若拿 `currentDrawing` 存檔並回灌 UI，
        // 會把畫布上剛完成的多筆筆跡換成較舊的快照，看起來像切到打字模式後
        // 大部分筆跡消失。可見的 PKCanvasView 才是切換瞬間的權威快照。
        // 但只在它顯示的就是這一頁時：剛換頁那一瞬間畫布還是上一頁，拿它存會把上一頁的字存進這一頁。
        if canvasShowsCurrentPage, let liveDrawing = canvasView?.drawing, liveDrawing != currentDrawing {
            currentDrawing = liveDrawing
        }
        // 筆跡沒變就不重寫：模式切換、點物件前後都會呼叫這裡，而序列化＋寫檔＋推進核心是整頁的成本。
        let unchanged = lastPersistedInk.map { $0.page == currentPageIndex && $0.drawing == currentDrawing } ?? false
        if !unchanged {
            let pid = (notebook.pageIds != nil && currentPageIndex < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[currentPageIndex] : nil
            activeInkStore.updateDrawing(currentDrawing, for: currentPageIndex, pageId: pid)
            // 透過 pendingCoreInk + flushPendingCoreInk 先更新記憶體快取並排入 coreInkQueue 背景寫檔，
            // 不在主執行緒重複執行同步 store.saveDrawing，消除切換「手繪／打字」模式時的卡頓。
            pendingCoreInk[currentPageIndex] = currentDrawing
            flushPendingCoreInk()
            lastPersistedInk = (currentPageIndex, currentDrawing)
        }
        // 同上：筆跡沒變、文件也與 store 一致就不碰。
        if unchanged && !proInkDirty && store.notebookMatchesStored(notebook) { return }
        proInkDirty = false
        notebook.lastModifiedDate = Date()
        commitNotebook()
    }

    /// 內容寫到頁尾時，確保後面有一頁可以接下去。
    ///
    /// 只在目前是最後一頁時才新增 —— 否則在中間的頁面寫到底，會憑空多出
    /// 一堆空白頁。
    private func ensureNextPageExists() {
        guard currentPageIndex == notebook.pageCount - 1 else { return }
        notebook.pageCount += 1
        commitNotebook()

        withAnimation {
            showExtendedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showExtendedBanner = false
            }
        }

        if let canvas = canvasView {
            let targetY = max(0, canvas.contentSize.height - canvas.bounds.height)
            canvas.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
        }
    }

    /// 套索以畫布上**看得到的那一份**為準。`currentDrawing` 是經 delegate 回寫的副本，
    /// 剛落下的筆畫、別的路徑換過的筆跡可能還沒寫回來；拿舊副本算出的選取索引
    /// 對不到畫面上的筆畫 —— 有的拖得動、有的拖不動。
    private func syncDrawingFromCanvas() {
        let targetCanvas = (pageDisplayMode == .continuous ? continuousCanvases[currentPageIndex] : nil)
            ?? continuousCanvases.activeCanvas
            ?? canvasView
        // 連續模式剛換焦點頁時 `canvasView` 可能還是上一頁的畫布（非同步才換過來），不能拿它當這一頁。
        if let coordinator = targetCanvas?.delegate as? CanvasRepresentable.Coordinator,
           let page = coordinator.parent.proInk?.pageIndex, page != currentPageIndex {
            return
        }
        if let live = targetCanvas?.drawing, live != currentDrawing {
            currentDrawing = live
        }
    }

    /// 把套索改過的筆跡換上目前的畫布（不經 delegate，見 `showEditedDrawing`）。
    private func showLassoEdit(_ newDrawing: PKDrawing) {
        currentDrawing = newDrawing
        continuousCanvases.setCachedDrawing(newDrawing, forPage: currentPageIndex)
        let targetCanvas = (pageDisplayMode == .continuous ? continuousCanvases[currentPageIndex] : nil)
            ?? continuousCanvases.activeCanvas
            ?? canvasView
        if let adaptive = targetCanvas as? AdaptiveCanvasView {
            adaptive.showEditedDrawing(newDrawing)
        } else {
            targetCanvas?.drawing = newDrawing
        }
    }

    /// 綁定套索與當前頁面之專業筆畫層（`ProInkLayerView`）及畫布插入物件（貼紙、形狀、圖片、文字方塊等），
    /// 使套索圈選與拖曳能同時選取並移動 PencilKit 筆畫、專業筆畫與未鎖定的頁面物件。
    private func configureLassoCallbacks(forPage page: Int) {
        let registry = continuousCanvases
        let isContinuous = (pageDisplayMode == .continuous)
        lasso.proHost = {
            let target = (isContinuous ? registry[page] : nil) ?? registry.activeCanvas ?? canvasView
            return (target as? AdaptiveCanvasView)?.proLayer
        }
        lasso.objectCandidates = {
            marqueeCandidates(forPage: page).map { (id: $0.id, frame: $0.frame) }
        }
        lasso.onMoveObjects = { ids, delta in
            guard !ids.isEmpty, delta != .zero else { return }
            for id in ids {
                if let frame = frameOfObject(id: id) {
                    moveObject(id: id, to: CGPoint(x: frame.minX + delta.width, y: frame.minY + delta.height))
                }
            }
            if isContinuous {
                continuousObjectGeneration += 1
            }
        }
        lasso.onCommitMoveObjects = { ids in
            guard !ids.isEmpty else { return }
            commitNotebook()
            if isContinuous {
                continuousObjectGeneration += 1
            }
            PageThumbnailRenderer.invalidateAll()
            thumbnailRevision += 1
        }
        lasso.onDeleteObjects = { ids in
            guard !ids.isEmpty else { return }
            deleteObjects(ids: ids)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            PageThumbnailRenderer.invalidateAll()
            thumbnailRevision += 1
        }
        lasso.onCopyObjects = { ids in
            guard !ids.isEmpty else { return }
            objectClipboard = ids.compactMap(clipboardObject(forId:))
            isPlacingPasteObject = false
        }
        lasso.onCutObjects = { ids in
            guard !ids.isEmpty else { return }
            objectClipboard = ids.compactMap(clipboardObject(forId:))
            isPlacingPasteObject = false
            deleteObjects(ids: ids)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            PageThumbnailRenderer.invalidateAll()
            thumbnailRevision += 1
        }
        lasso.onDuplicateObjects = { ids in
            let copies = ids.compactMap(clipboardObject(forId:))
            guard !copies.isEmpty else { return [] }
            paste(copies, onPage: page, at: nil)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            return selectedObjectIds
        }
        lasso.onPasteObjects = {
            guard !objectClipboard.isEmpty else { return [] }
            paste(objectClipboard, onPage: page, at: nil)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            return selectedObjectIds
        }
    }

    func applyLassoResult(_ newDrawing: PKDrawing) {
        showLassoEdit(newDrawing)
        recordDrawingEdit(page: currentPageIndex, drawing: newDrawing)
        broadcastDrawingChange(page: currentPageIndex, drawing: newDrawing)
        saveCurrentPageDrawing()
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    func deleteSelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.deleteSelected(from: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    func cutSelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.cutSelected(from: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    // MARK: - 🌟 次世代專業筆刷與手寫轉換 (CSP 防抖、對稱尺規、套索 OCR 轉文字)
    func recognizeHandwritingToTextBox() {
        // 與刪除／剪下一樣先以畫布上看得到的那一份為準：選取索引是對著它算的。
        syncDrawingFromCanvas()
        let fullDrawing = currentDrawing
        let hasSelection = lasso.hasSelection
        let pkStrokes = hasSelection ? lasso.extractSelectedStrokes(from: fullDrawing) : fullDrawing.strokes
        // 專業筆刷（炭筆、蠟筆、書法筆…）寫的字不在 PKDrawing 裡；轉成 PencilKit 筆畫一起送辨識。
        let proStrokes = hasSelection ? lasso.extractSelectedProStrokes() : []
        let selectedStrokes = pkStrokes + proStrokes.compactMap(Self.recognitionStroke(from:))
        guard !selectedStrokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_recognize_select_first"))
            return
        }
        
        // 計算筆跡包圍盒與平均色彩（原地轉化：沿用位置、寬度、筆色）
        var strokeBounds: CGRect = .null
        var strokeColorHex: String = "#000000"
        for stroke in pkStrokes {
            strokeBounds = strokeBounds.union(stroke.renderBounds)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if stroke.ink.color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                strokeColorHex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
            }
        }
        for stroke in proStrokes {
            strokeBounds = strokeBounds.union(stroke.bounds)
            let c = stroke.colorRGBA
            if c.count >= 3 {
                strokeColorHex = String(format: "#%02X%02X%02X", Int(c[0]), Int(c[1]), Int(c[2]))
            }
        }
        if strokeBounds.isNull || !strokeBounds.width.isFinite || !strokeBounds.height.isFinite {
            strokeBounds = CGRect(x: 160, y: 200, width: 340, height: 140)
        }
        
        let language = localizationManager.currentLanguage.rawValue
        showCanvasNotice(localizationManager.localized("recognizing"))

        Task { @MainActor in
            switch await HandwritingRecognizer.recognize(strokes: selectedStrokes, languageTag: language) {
            case .success(let recognizedText):
                let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    showCanvasNotice(localizationManager.localized("lasso_recognize_none"))
                    return
                }
                
                // 原地取代：產生對準原筆劃位置之 NoteTextAttachment
                let pad: CGFloat = 8
                let draft = NoteTextAttachment(
                    id: UUID().uuidString,
                    pageIndex: currentPageIndex,
                    text: trimmed,
                    fontSize: max(16, min(32, strokeBounds.height * 0.7)),
                    textColorHex: strokeColorHex,
                    backgroundColorHex: "#FFFFFF",
                    hasBorder: false,
                    x: max(PageGeometry.printableInset, strokeBounds.minX - pad),
                    y: max(PageGeometry.printableInset, strokeBounds.minY - pad),
                    width: max(120, strokeBounds.width + pad * 2),
                    height: max(44, strokeBounds.height + pad * 2)
                )
                
                if notebook.textAttachments == nil { notebook.textAttachments = [] }
                notebook.textAttachments?.append(draft)
                
                // 清除選中的筆劃（若有套索選取則只刪被選筆劃，否則清空整頁）
                // 辨識是非同步的：等待期間選取可能已被清掉，這時只保留原筆跡，絕不能退回「清空整頁」。
                if hasSelection {
                    if let updated = lasso.deleteSelected(from: currentDrawing) {
                        applyLassoResult(updated)
                    }
                } else {
                    currentDrawing = PKDrawing()
                    canvasView?.drawing = PKDrawing()
                    saveCurrentPageDrawing()
                }
                
                transitionToMode(.type)
                inlineEditingTextId = draft.id
                editingTextId = nil
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
                showCanvasNotice(localizationManager.localized("lasso_recognize_done"))
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            case .failure(let failure):
                // 說出真正的原因（語言不支援、系統沒有辨識能力…）—— 「辨識失敗」幫不了使用者。
                let detail: String
                switch failure {
                case .unsupported(let d), .noModel(let d), .recognitionFailed(let d): detail = d
                }
                showCanvasNotice(localizationManager.localized("err_hwr_failed")
                    .replacingOccurrences(of: "%@", with: detail))
            }
        }
    }

    /// 專業筆畫只取路徑給辨識用（辨識只看形狀，不看筆刷質感）。少於兩點的不算一筆。
    private static func recognitionStroke(from pro: ProStroke) -> PKStroke? {
        guard pro.points.count >= 2 else { return nil }
        let width = CGFloat(max(1, pro.baseWidth))
        let points = pro.points.map { p in
            PKStrokePoint(
                location: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)),
                timeOffset: 0,
                size: CGSize(width: width, height: width),
                opacity: 1,
                force: CGFloat(max(0.1, p.pressure)),
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    // MARK: - 🌟 文字與手寫動態流式錨定系統 (Fluid Sticky Annotations)
    private func moveAnchoredStrokes(forTextId textId: String, delta: CGSize) {
        guard let anchors = notebook.stickyAnchors, !anchors.isEmpty else { return }
        let matched = anchors.filter { $0.targetId == textId && $0.pageIndex == currentPageIndex }
        guard !matched.isEmpty else { return }

        let drawing = currentDrawing
        var strokes = drawing.strokes
        var modified = false

        for anchor in matched {
            if let indices = anchor.strokeIndices {
                for idx in indices where strokes.indices.contains(idx) {
                    var copy = strokes[idx]
                    copy.transform = copy.transform.translatedBy(x: delta.width, y: delta.height)
                    strokes[idx] = copy
                    modified = true
                }
            }
        }

        if modified {
            let newDrawing = PKDrawing(strokes: strokes)
            self.currentDrawing = newDrawing
            self.canvasView?.drawing = newDrawing
            self.saveCurrentPageDrawing()
            for i in 0..<(notebook.stickyAnchors?.count ?? 0) {
                if notebook.stickyAnchors?[i].targetId == textId {
                    notebook.stickyAnchors?[i].anchorOriginX += Float(delta.width)
                    notebook.stickyAnchors?[i].anchorOriginY += Float(delta.height)
                }
            }
            commitNotebook()
        }
    }

    func anchorSelectedStrokesToNearestText() {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else {
            showCanvasNotice("目前頁面沒有手寫筆劃可供錨定")
            return
        }

        let pageTexts = (notebook.textAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
        guard !pageTexts.isEmpty else {
            showCanvasNotice("頁面上尚無文字方塊。請先新增文字方塊並使手寫筆劃相鄰，即可建立動態連動錨定")
            return
        }

        let candidateIndices = lasso.hasSelection ? Array(lasso.selected) : Array(drawing.strokes.indices)
        for target in pageTexts {
            let textRect = CGRect(x: target.x, y: target.y, width: target.width, height: target.height)
            var matchedIndices: [Int] = []
            for idx in candidateIndices where drawing.strokes.indices.contains(idx) {
                let stroke = drawing.strokes[idx]
                if textRect.intersects(stroke.renderBounds) {
                    matchedIndices.append(idx)
                }
            }
            if !matchedIndices.isEmpty {
                let anchor = StickyAnnotationAnchor(
                    pageIndex: currentPageIndex,
                    targetId: target.id,
                    strokeIndices: matchedIndices,
                    anchorOriginX: Float(target.x),
                    anchorOriginY: Float(target.y)
                )
                if notebook.stickyAnchors == nil { notebook.stickyAnchors = [] }
                notebook.stickyAnchors?.removeAll { $0.targetId == target.id }
                notebook.stickyAnchors?.append(anchor)
                commitNotebook()
                lasso.clear()
                showCanvasNotice("手寫筆劃已成功錨定至文字方塊！移動該文字方塊時，筆跡將隨之連動")
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                return
            }
        }
        if let firstText = pageTexts.first {
            anchorOverlappingInkToText(textItem: firstText)
        } else {
            showCanvasNotice("未找到與所選筆劃相鄰的文字方塊；請圈選與文字方塊相重疊或相鄰的筆劃")
        }
    }

    private func anchorOverlappingInkToText(textItem: NoteTextAttachment) {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else { return }
        let textRect = CGRect(x: textItem.x, y: textItem.y, width: textItem.width, height: textItem.height)

        var matchedIndices: [Int] = []
        for (idx, stroke) in drawing.strokes.enumerated() {
            if textRect.intersects(stroke.renderBounds) {
                matchedIndices.append(idx)
            }
        }

        guard !matchedIndices.isEmpty else {
            showCanvasNotice("未找到與所選筆劃相鄰的文字方塊；請圈選與文字方塊相重疊或相鄰的筆劃")
            return
        }
        let anchor = StickyAnnotationAnchor(
            pageIndex: currentPageIndex,
            targetId: textItem.id,
            strokeIndices: matchedIndices,
            anchorOriginX: Float(textItem.x),
            anchorOriginY: Float(textItem.y)
        )
        if notebook.stickyAnchors == nil { notebook.stickyAnchors = [] }
        notebook.stickyAnchors?.removeAll { $0.targetId == textItem.id }
        notebook.stickyAnchors?.append(anchor)
        commitNotebook()
        showCanvasNotice("手寫筆劃已成功錨定至文字方塊！移動該文字方塊時，筆跡將隨之連動")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 自動判定新落筆跡是否與既有文字方塊高度重疊（> 40%），若是則自動關聯錨定（工作項 F4 v1）
    private func autoAnchorNewStrokesToOverlappingText(drawing: PKDrawing) {
        let pageTexts = (notebook.textAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
        guard !pageTexts.isEmpty else { return }

        var updatedAnchors = notebook.stickyAnchors ?? []
        var hasChanges = false

        for textItem in pageTexts {
            let textRect = CGRect(x: textItem.x, y: textItem.y, width: textItem.width, height: textItem.height)
            var matchedIndices: [Int] = []
            
            for (idx, stroke) in drawing.strokes.enumerated() {
                let strokeBounds = stroke.renderBounds
                if textRect.intersects(strokeBounds) {
                    let intersection = textRect.intersection(strokeBounds)
                    let strokeArea = max(1.0, strokeBounds.width * strokeBounds.height)
                    let intersectArea = intersection.width * intersection.height
                    // 重疊面積或相交比例足夠視為對文字之圈註／劃線／旁註
                    if intersectArea / strokeArea > 0.3 || textRect.contains(strokeBounds) {
                        matchedIndices.append(idx)
                    }
                }
            }

            if !matchedIndices.isEmpty {
                let anchor = StickyAnnotationAnchor(
                    pageIndex: currentPageIndex,
                    targetId: textItem.id,
                    strokeIndices: matchedIndices,
                    anchorOriginX: Float(textItem.x),
                    anchorOriginY: Float(textItem.y)
                )
                updatedAnchors.removeAll { $0.targetId == textItem.id && $0.pageIndex == currentPageIndex }
                updatedAnchors.append(anchor)
                hasChanges = true
            }
        }

        if hasChanges {
            notebook.stickyAnchors = updatedAnchors
            commitNotebook()
        }
    }

    private func applyStabilizer(to drawing: PKDrawing) -> PKDrawing {
        guard strokeStabilizer > 0.05, let lastStroke = drawing.strokes.last else {
            return drawing
        }
        var ffiPoints: [FfiPoint] = []
        for i in 0..<lastStroke.path.count {
            let p = lastStroke.path[i]
            ffiPoints.append(FfiPoint(x: Float(p.location.x), y: Float(p.location.y)))
        }
        let refined = sketchRefineStroke(points: ffiPoints, intensity: Float(strokeStabilizer))
        guard refined.points.count == lastStroke.path.count else {
            return drawing
        }
        var newStrokePoints: [PKStrokePoint] = []
        for i in 0..<lastStroke.path.count {
            let orig = lastStroke.path[i]
            let newLoc = CGPoint(x: CGFloat(refined.points[i].x), y: CGFloat(refined.points[i].y))
            let pt = PKStrokePoint(
                location: newLoc,
                timeOffset: orig.timeOffset,
                size: orig.size,
                opacity: orig.opacity,
                force: orig.force,
                azimuth: orig.azimuth,
                altitude: orig.altitude
            )
            newStrokePoints.append(pt)
        }
        let newPath = PKStrokePath(controlPoints: newStrokePoints, creationDate: lastStroke.path.creationDate)
        let newStroke = PKStroke(ink: lastStroke.ink, path: newPath, transform: lastStroke.transform, mask: lastStroke.mask)
        var allStrokes = Array(drawing.strokes.dropLast())
        allStrokes.append(newStroke)
        return PKDrawing(strokes: allStrokes)
    }

    private func applySymmetry(to drawing: PKDrawing, axisX: CGFloat = 400) -> PKDrawing {
        guard isSymmetryActive, let lastStroke = drawing.strokes.last else {
            return drawing
        }
        var mirroredPoints: [PKStrokePoint] = []
        for i in 0..<lastStroke.path.count {
            let orig = lastStroke.path[i]
            let mirroredX = 2 * axisX - orig.location.x
            let pt = PKStrokePoint(
                location: CGPoint(x: mirroredX, y: orig.location.y),
                timeOffset: orig.timeOffset,
                size: orig.size,
                opacity: orig.opacity,
                force: orig.force,
                azimuth: -orig.azimuth,
                altitude: orig.altitude
            )
            mirroredPoints.append(pt)
        }
        let mirroredPath = PKStrokePath(controlPoints: mirroredPoints, creationDate: Date())
        let mirroredStroke = PKStroke(ink: lastStroke.ink, path: mirroredPath, transform: lastStroke.transform, mask: lastStroke.mask)
        var allStrokes = drawing.strokes
        allStrokes.append(mirroredStroke)
        return PKDrawing(strokes: allStrokes)
    }

    /// 貼上剪貼簿中的筆劃。
    func pasteStrokes() {
        syncDrawingFromCanvas()
        guard lasso.canPaste else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.paste(into: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    /// 就地複製選取的筆劃並稍微偏移（不經過剪貼簿）—— 這就是「再製」與「複製」的差別：
    /// 「複製」把東西放進剪貼簿等你貼上，「再製」直接在旁邊多一份。
    func duplicateSelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.duplicateSelected(in: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    func saveSelectedAsSticker() {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        let extractedStrokes = lasso.extractSelectedStrokes(from: currentDrawing)
        guard !extractedStrokes.isEmpty else { return }
        
        let tempDrawing = PKDrawing(strokes: extractedStrokes)
        let bounds = tempDrawing.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        // 筆畫座標正規化至正數象限（預留 16pt 邊距），防止 PKDrawing.image 負值邊界造成算繪空白或截斷
        let padding: CGFloat = 16
        let transform = CGAffineTransform(translationX: -bounds.minX + padding, y: -bounds.minY + padding)
        let normalizedStrokes = extractedStrokes.map {
            PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
        }
        let stickerDrawing = PKDrawing(strokes: normalizedStrokes)
        StickerManager.shared.saveSticker(stickerDrawing)
        
        lasso.clear()
        selectedTool = previousTool ?? lastBrushTool
        showCanvasNotice("已儲存為貼紙！可於頂端「插入 > 貼紙 > 我的貼紙」中選用")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 把確認放置的貼紙變成**頁面上的物件**，不是烘進筆跡。
    ///
    /// # 為什麼不再烘成筆跡
    ///
    /// 原本確認之後貼紙被拆成一堆 `PKStroke` 混進手寫內容，於是它跟隨手寫的字
    /// 沒有任何分別：點它沒有反應、沒有把手、沒有刪除鈕，只有切到套索再精準
    /// 圈住才搬得動 —— 而使用者根本不知道要這麼做，回報的就是「確認後就無法
    /// 移動、編輯或刪除」。
    ///
    /// 現在貼紙以透明底圖片物件進頁面，跟圖片同一套：點選出把手、拖曳搬移、
    /// 縮放、旋轉、刪除、調圖層、框選、同步與匯出全部現成。放置時選的大小與
    /// 角度原樣帶過去。
    private func insertStickerObject(_ placement: PendingStickerPlacement) {
        let b = placement.drawing.bounds
        guard b.width > 0, b.height > 0 else { return }
        // 與 `StickerRenderView` 同一個規則：在 (寬 × 縮放, 高 × 縮放) 的框裡等比置中。
        let boxW = max(50, placement.size.width) * max(0.2, min(5, placement.scale))
        let boxH = max(50, placement.size.height) * max(0.2, min(5, placement.scale))
        let fit = min(boxW / b.width, boxH / b.height)
        let size = CGSize(width: b.width * fit, height: b.height * fit)

        // 3 倍像素：貼紙是向量，但存成圖片後放大會糊，預留縮放的餘裕。
        let image = placement.drawing.image(from: b, scale: 3 * max(1, fit))
        guard let fileName = store.saveAttachmentImage(image) else { return }

        // 連續模式下若將貼圖放置浮層拖曳至其他頁面確認，自動換算落點頁碼與頁內座標（S-85）。
        let rawX = placement.center.x - size.width / 2
        let rawY = placement.center.y - size.height / 2
        let crossing = (pageDisplayMode == .continuous) ? pageCrossing(for: currentPageIndex) : nil
        let landed = PrintableArea.land(
            x: rawX, y: rawY, width: size.width, height: size.height, crossing: crossing)
        let finalPage = landed.page ?? currentPageIndex
        let finalX = landed.origin.x
        let finalY = landed.origin.y

        let attachment = NoteImageAttachment(
            fileName: fileName,
            pageIndex: finalPage,
            x: finalX,
            y: finalY,
            width: size.width,
            height: size.height,
            rotationDegrees: placement.rotationDegrees,
            cornerRadius: 0,
            hasShadow: false,
            hasBorder: false,
            filterStyle: .original,
            chartSpecJSON: nil
        )
        if notebook.attachments == nil { notebook.attachments = [] }
        notebook.attachments?.append(attachment)
        commitNotebook()
        if finalPage != currentPageIndex {
            finishPageCrossing(ids: [attachment.id], to: finalPage)
        }
        if var dict = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(attachment))) as? [String: Any] {
            if let imgData = image.pngData() {
                dict["image_base64"] = imgData.base64EncodedString()
            }
            collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
        }
        PageThumbnailRenderer.invalidateAll()
    }

    func copySelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        lasso.copySelected(from: currentDrawing)
        showCanvasNotice(localizationManager.localized("copy_selected_hint"))
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    func stopAndSaveRecording() {
        if let result = audioManager.stopRecording() {
            let fileName = result.url.lastPathComponent
            notebook.hasRecording = true
            notebook.recordingAudioPath = fileName
            commitNotebook()
            let rec = store.addRecording(
                title: NotebookStore.defaultRecordingTitle(),
                durationSeconds: AudioRecorderManager.displaySeconds(of: result.url, fallback: result.duration),
                fileName: fileName,
                linkedNotebookId: notebook.id
            )
            insertAudioAttachment(rec)
        }
    }

    /// 每一頁完整算繪成一張圖，再組成 PDF。
    ///
    /// 舊版寫死 612×792（信紙尺寸）並且只畫 `PKDrawing` —— 但畫布座標是
    /// 「視圖寬度 × 頁面高度」，通常遠大於這個框，所以只截到左上角一小塊，
    /// 匯出檔看起來就是空白；文字方塊、圖片、3D、圖釘也全都沒畫進去。
    /// 把某一頁算繪成圖（與縮圖、PNG 匯出是同一份繪圖程式碼）。
    private func composedPageImage(_ index: Int, scale: CGFloat) -> UIImage {
        PageThumbnailRenderer.renderFullPage(
            notebook: notebook,
            pageIndex: index,
            drawing: drawingForPage(index),
            store: store,
            canvasWidth: max(canvasContentWidth, PageThumbnailRenderer.minPageWidth),
            scale: scale
        )
    }

    /// 匯出 PDF（也是列印走的路）。
    ///
    /// # 為什麼是點陣而不是核心的向量匯出
    ///
    /// 「所見即所得」是底線。核心的向量匯出器把每一筆畫成**等寬折線**：PencilKit 的壓感粗細、鉛筆與麥克筆的
    /// 紋理、螢光筆的疊色、專業筆刷的筆點全都不見；圖片的濾鏡與材質、物件的堆疊順序、形狀、圖表、連結卡片也不在它
    /// 的文件模型裡。結果是「畫布上是一個樣子，PDF 是另一個樣子」。
    /// 這裡每一頁用**縮圖與 PNG 匯出同一份繪圖程式碼**算繪，三者逐像素一致。
    /// 代價：PDF 裡的文字不能選取、筆畫不是可編輯的標註 —— 要向量與標註請用 `.padnote` 或「製圖輸出（SVG／DXF）」。
    private func buildNotebookPdf(scale: CGFloat = 2.0) -> Data {
        saveCurrentPageDrawing()
        return buildRasterPdf(scale: scale)
    }

    /// 逐頁算繪、逐頁寫進 PDF：不先把所有頁面的點陣圖都留在記憶體裡（頁數多的筆記本會吃掉幾百 MB）。
    private func buildRasterPdf(scale: CGFloat = 2.0) -> Data {
        let count = max(1, notebook.pageCount)
        let first = composedPageImage(0, scale: scale)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: first.size))
        return renderer.pdfData { context in
            for i in 0..<count {
                // 圖的大小就是頁面大小（點），每一頁用自己的尺寸開頁（頁面高度可以不同）。
                let image = i == 0 ? first : composedPageImage(i, scale: scale)
                context.beginPage(withBounds: CGRect(origin: .zero, size: image.size), pageInfo: [:])
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
    }

    func exportAsPdf() {
        self.exportPdfData = buildNotebookPdf()
        self.exportFileExtension = "pdf"
        // 先給預覽（S-100）。分享面板由預覽上的「匯出」再叫出來 ——
        // 使用者要確認的是「版面對不對」，而那件事只有看到結果才答得出來。
        self.showExportPreview = true
    }

    func printCurrentNotebook() {
        let pdfData = buildNotebookPdf()

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = notebook.title
        printController.printInfo = printInfo
        printController.printingItem = pdfData
        if UIDevice.current.userInterfaceIdiom == .pad {
            let targetView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController?.view
            if let view = targetView {
                let rect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                printController.present(from: rect, in: view, animated: true, completionHandler: nil)
            } else {
                printController.present(animated: true, completionHandler: nil)
            }
        } else {
            printController.present(animated: true, completionHandler: nil)
        }
    }

    func exportAsPngImage() {
        saveCurrentPageDrawing()
        let img = composedPageImage(currentPageIndex, scale: 2.0)
        if let pngData = img.pngData() {
            self.exportPdfData = pngData
            self.exportFileExtension = "png"
            self.showExportPreview = true
        }
    }

    /// 把整本筆記打包成 `.padnote`，然後開**儲存對話框**。
    ///
    /// 與 `shareNotebookFile()` 只差在最後開哪一個面板 —— 打包那一段一模
    /// 一樣，所以共用，不要再抄一份（抄漏的那一次會是「存出來的檔案少了
    /// 圖片」，而那要等使用者在另一台裝置打開才發現）。
    func saveNotebookFile() {
        shareNotebookFile(asSaveDialog: true)
    }

    func shareNotebookFile(asSaveDialog: Bool = false) {
        saveCurrentPageDrawing()
        let tempDir = FileManager.default.temporaryDirectory.appending(path: "share_\(UUID().uuidString)")
        let pkgDir = tempDir.appending(path: "\(notebook.id).padnote")
        let zipUrl = tempDir.appending(path: "\(notebook.displayTitle()).padnote")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            var drawings: [PKDrawing] = []
            for p in 0..<notebook.pageCount {
                drawings.append(store.loadDrawing(notebookId: notebook.id, pageIndex: p))
            }
            var imageMap: [String: Data] = [:]
            for att in notebook.attachments ?? [] {
                let fileUrl = store.attachmentsDirectory.appending(path: att.fileName)
                if let data = try? Data(contentsOf: fileUrl) {
                    imageMap[att.fileName] = data
                }
            }
            // 專業筆刷與製圖線不在 PKDrawing 裡：原本分享出去的 `.padnote` **完全沒有它們** ——
            // 在別台打開，畫的三視圖整個不見。自己的與別台同步來的都要帶，**隱藏的圖層也要**
            // （隱藏只是這台的顯示設定，不是刪除；收到的人打開圖層面板可以打開）。
            let dir = store.drawingsDirectory
            let pro = (0..<max(notebook.pageCount, 1)).map { page in
                ProInkStore.load(in: dir, notebookId: notebook.id, page: page, foreign: true)
                    + ProInkStore.load(in: dir, notebookId: notebook.id, page: page)
            }
            try NotebookPackageBridge.export(
                document: notebook,
                drawings: drawings,
                imageData: imageMap,
                to: pkgDir,
                deviceId: 0x4150,
                proStrokes: pro
            )
            try archiveNotebook(packageDir: pkgDir.path, outFile: zipUrl.path)
            let zipData = try Data(contentsOf: zipUrl)
            self.exportPdfData = zipData
            self.exportFileExtension = "padnote"
            if asSaveDialog {
                self.showSaveDialog = true
            } else {
                self.showShareSheet = true
            }
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            print("[ShareNotebook] Failed to package notebook: \(error)")
            exportAsPdf()
        }
    }

    func addNewPage() {
        let paperId = notebook.paperId(forPage: currentPageIndex)
        changePageStructure(pageMap: { $0 }) {
            store.addPage(notebookId: notebook.id, paperId: paperId)
        }
    }

    /// 在某一頁後面插入新的一頁。
    ///
    /// `paperId` 為 nil 時沿用整本的樣板；指定時這一頁自己用那一種
    /// （見 `NotebookDocument.pagePaperIds`）。
    func insertPageAfter(_ index: Int, paperId: String? = nil) {
        let insertIndex = min(max(0, index + 1), max(1, notebook.pageCount))
        changePageStructure(pageMap: { $0 >= insertIndex ? $0 + 1 : $0 }) {
            store.insertPage(notebookId: notebook.id, afterIndex: index, paperId: paperId)
        }
        if let paperId, let paper = NoteTemplate(paperId: paperId) {
            showCanvasNotice(localizationManager.localized(paper.localizationKey))
        }
    }

    func duplicatePage(at index: Int) {
        changePageStructure(pageMap: { $0 > index ? $0 + 1 : $0 }) {
            store.duplicatePage(notebookId: notebook.id, pageIndex: index)
        }
    }

    func deletePage(at index: Int) {
        guard notebook.pageCount > 1 else { return }
        // 原本刪除前不存檔：目前這一頁剛寫的字還在記憶體裡，稍後的去抖動存檔把它寫到
        // 刪除前的頁碼 —— 也就是現在的下一頁。
        changePageStructure(pageMap: { page in
            page == index ? nil : (page > index ? page - 1 : page)
        }) {
            guard notebook.pageCount > 1 else { return nil }
            return store.deletePage(notebookId: notebook.id, pageIndex: index, currentIndex: currentPageIndex)
        }
    }

    func switchToNotebook(_ target: NotebookDocument) {
        guard target.id != notebook.id else { return }
        // 由外層換掉 Binding 指向的索引；這裡自己寫會覆蓋掉目前這則筆記。
        requestLeave { onRequestSwitch?(target) }
    }

    /// 離開這本筆記（回首頁或切換到另一本）。
    ///
    /// 範例且內容真的有改：先問使用者要存檔（保留在此範例）、另存可編輯副本，還是放棄修改；
    /// 沒改或不是範例：直接離開（範例的暫存跟著收掉）。
    func requestLeave(_ leave: @escaping () -> Void) {
        saveCurrentPageDrawing()
        let id = notebook.id
        guard store.hasSampleSession(id) else { leave(); return }
        // 筆跡在背景佇列寫入：等寫完再比對，最後一筆才算得進去。
        afterCoreInkWrites {
            if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                store.finishSampleSession(id, choice: .keep)
                leave()
            } else if store.sampleSessionHasChanges(id) {
                afterSampleLeave = leave
                showSampleLeaveDialog = true
            } else {
                store.finishSampleSession(id, choice: .keep)
                leave()
            }
        }
    }

    private func finishSampleLeave(_ choice: SampleLeaveChoice) {
        store.finishSampleSession(notebook.id, choice: choice)
        let leave = afterSampleLeave
        afterSampleLeave = nil
        leave?()
    }

    /// 頁面規格選單。
    ///
    /// # 為什麼它在工具列上，而不是收進設定
    ///
    /// 規格同時決定三件事：畫布多大、分頁在哪裡斷、匯出的 PDF 多大。
    /// 它是**編輯當下**會想改的東西（「這份要印成 A5」），不是設定一次
    /// 就不動的偏好。收進設定的話，使用者要先離開筆記才改得到。
    var pageFormatMenu: some View {
        Menu {
            ForEach(pageFormats(), id: \.id) { format in
                Button {
                    applyPageFormat(format.id)
                } label: {
                    HStack {
                        Text(localizationManager.localized(format.titleKey))
                        if (notebook.pageFormatId ?? defaultPageFormatId()) == format.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            // 大尺寸頁取代無限畫布：任意寬高（300–6000）。
            Button {
                showCustomPageSize = true
            } label: {
                HStack {
                    Text(localizationManager.localized("page_format_custom"))
                    if isCustomPageFormat(id: notebook.pageFormatId ?? defaultPageFormatId()) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityIdentifier("page_format.custom")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: EditorToolbarMetrics.icon))
                Text(pageFormatTitle)
                    .font(.system(size: EditorToolbarMetrics.label))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("page_format"))
        .help(localizationManager.localized("page_format_desc"))
        .sheet(isPresented: $showCustomPageSize) {
            CustomPageSizeSheet(initial: PageGeometry.size) { applyPageFormat($0) }
        }
    }

    /// 這一頁上所有手繪線的點：專業筆刷（含製圖線）加上 PencilKit 的筆畫。
    private func solidSketchPolylines() -> [[CGPoint]] {
        var all = (canvasView as? AdaptiveCanvasView)?.proLayer?.sketchPolylines ?? []
        if let drawing = canvasView?.drawing {
            for stroke in drawing.strokes {
                all.append(stroke.path.interpolatedPoints(by: .distance(3)).map(\.location))
            }
        }
        return all
    }

    /// 把立體輔助排好的圖紙插進目前這一頁：放在**目前看得到的範圍正中央**（不是固定貼頂，
    /// 那樣會壓在既有的圖上），整組一次復原。插入後直接用套索選住它，使用者拖一下就能搬。
    private func insertSolidSheet(_ sheet: FfiSolidSheet) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let page = PageGeometry.size
        let w = CGFloat(sheet.width), h = CGFloat(sheet.height)
        let center = layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
        let origin = CGPoint(
            x: min(max(0, center.x - w / 2), max(0, page.width - w)),
            y: min(max(0, center.y - h / 2), max(0, page.height - h)))
        let made = layer.insertDrafted(sheet.strokes, origin: origin)
        showCanvasNotice(localizationManager.localized("solid_place_hint"))
        guard !made.isEmpty else { return }
        selectedTool = .lasso
        // 換工具會清掉舊的選取；等下一個 runloop 再選，選取框才不會被清掉。
        let ids = Set(made.map(\.id))
        let box = made.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        DispatchQueue.main.async { lasso.select(proStrokeIds: ids, around: box) }
    }

    /// 把一組製圖符號放在目前看得到的範圍正中央（同 `insertSolidSheet`：整組一次復原、插入後套索選住）。
    private func insertDraftKit(_ kit: FfiDraftKit) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let pts = kit.strokes.flatMap(\.points)
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return }
        let page = PageGeometry.size
        let w = CGFloat(maxX - minX), h = CGFloat(maxY - minY)
        let center = layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
        // 讓符號的包圍盒中心落在視野中央，再夾回頁面裡。
        let left = min(max(0, center.x - w / 2), max(0, page.width - w))
        let top = min(max(0, center.y - h / 2), max(0, page.height - h))
        let origin = CGPoint(x: left - CGFloat(minX), y: top - CGFloat(minY))
        let made = layer.insertDrafted(kit.strokes, origin: origin)
        showCanvasNotice(localizationManager.localized("draft_symbol_placed"))
        guard !made.isEmpty else { return }
        selectedTool = .lasso
        let ids = Set(made.map(\.id))
        let box = made.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        DispatchQueue.main.async { lasso.select(proStrokeIds: ids, around: box) }
    }

    /// 匯出本頁的製圖線（SVG 或 DXF，毫米）：隱藏的圖層不輸出；寫進暫存資料夾再交給分享表。
    private func exportDrafting(format: String) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        let strokes: [FfiExportStroke] = layer.allStrokes.compactMap { s in
            guard s.points.count >= 2,
                  s.layerId == 0 || !drafting.isHidden(layer: s.layerId, notebookId: layer.notebookId)
            else { return nil }
            let c = s.colorRGBA
            let hex = c.count >= 3 ? String(format: "#%02X%02X%02X", c[0], c[1], c[2]) : "#111827"
            return FfiExportStroke(
                points: s.points.map { FfiPoint(x: $0.x, y: $0.y) }, layer: s.layerId, lineType: s.lineTypeId,
                width: s.baseWidth, colorHex: hex)
        }
        guard !strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("draft_export_empty"))
            return
        }
        let size = PageGeometry.size
        let text = format == "dxf"
            ? draftExportDxf(strokes: strokes, pageWidth: Float(size.width), pageHeight: Float(size.height))
            : draftExportSvg(strokes: strokes, pageWidth: Float(size.width), pageHeight: Float(size.height))
        let url = FileManager.default.temporaryDirectory
            .appending(path: "padnote-page-\(currentPageIndex + 1).\(format)")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showCanvasNotice(localizationManager.localized("draft_export_failed"))
            return
        }
        // 工具箱剛關：等它收起來再開分享表，兩個 sheet 同時換手會被系統吃掉。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { draftExportShare = SharedFile(url: url) }
    }

    /// 開始一題練習：把題目線放進目前這一頁（頁面大小由核心依它排版）。
    private func startPractice(kind: String) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        selectedTool = .drafting
        PracticeSession.shared.start(kind: kind, layer: layer, pageSize: PageGeometry.size)
    }

    /// 矩形陣列：套用在套索選的那批線上（一次復原）。
    private func applyRectArray(rows: Int, cols: Int, dxMm: Double, dyMm: Double) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        DraftingState.shared.editSelection = lasso.proIds
        guard !lasso.proIds.isEmpty else {
            showCanvasNotice(localizationManager.localized("draft_edit_need_selection"))
            return
        }
        DraftEditController.shared.applyRectArray(rows: rows, cols: cols, dxMm: dxMm, dyMm: dyMm, layer: layer)
    }

    /// 把量角器讀到的角度畫成一條線（從圓心到外緣），一次復原。
    private func markProtractorReading() {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        guard let (a, b) = drafting.instrument?.readingRay else { return }
        let pen = drafting.activePen
        let stroke = FfiSheetStroke(
            points: [FfiPoint(x: Float(a.x), y: Float(a.y)), FfiPoint(x: Float(b.x), y: Float(b.y))],
            layer: drafting.activeLayerId, lineType: drafting.activeLineType, width: pen.width, colorHex: pen.colorHex)
        guard !drafting.isLocked(layer: stroke.layer, notebookId: layer.notebookId) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        drafting.ensureVisible(layer: stroke.layer, notebookId: layer.notebookId)
        layer.insertDrafted([stroke], origin: .zero)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 目前視野的正中央（頁面座標）。
    private func draftViewportCenter() -> CGPoint {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else {
            return CGPoint(x: PageGeometry.size.width / 2, y: PageGeometry.size.height / 2)
        }
        return layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
    }

    /// 這一頁的紙張規格有沒有標準圖框（A4／A3／A2，直式或橫式）。
    private var frameSupportedForCurrentPage: Bool {
        draftSheetFrame(paperId: notebook.pageFormatId ?? defaultPageFormatId(), scaleText: "", thirdAngle: true, titleBlock: false) != nil
    }

    /// 插入圖框與標題欄：框線是製圖筆畫（粗框、細格），欄位名稱是文字方塊（跟著介面語言）。
    private func insertDraftFrame(thirdAngle: Bool) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        guard let kit = draftSheetFrame(
            paperId: notebook.pageFormatId ?? defaultPageFormatId(),
            scaleText: drafting.scaleLabel(notebookId: notebook.id),
            thirdAngle: thirdAngle, titleBlock: true)
        else {
            showCanvasNotice(localizationManager.localized("draft_frame_unsupported"))
            return
        }
        layer.insertDrafted(kit.strokes, origin: .zero)
        var added = notebook.textAttachments ?? []
        for label in kit.texts {
            added.append(NoteTextAttachment(
                pageIndex: currentPageIndex, text: localizationManager.localized(label.key),
                fontSize: CGFloat(label.fontSize), isBold: label.bold, alignmentRaw: "left",
                textColorHex: label.colorHex, backgroundColorHex: "clear", hasBorder: false,
                x: CGFloat(label.x), y: CGFloat(label.y), width: CGFloat(label.width),
                height: CGFloat(label.fontSize) * 1.6 + 6))
        }
        notebook.textAttachments = added
        showCanvasNotice(localizationManager.localized("draft_frame_inserted"))
    }

    /// 工具列上顯示的規格名稱。自訂的直接顯示尺寸（「2000×1500」）。
    private var pageFormatTitle: String {
        let id = notebook.pageFormatId ?? defaultPageFormatId()
        let format = pageFormat(id: id)
        if isCustomPageFormat(id: id) {
            return "\(Int(format.width))×\(Int(format.height))"
        }
        return localizationManager.localized(format.titleKey)
    }

    /// 版面配色。
    ///
    /// # 為什麼是整本一個
    ///
    /// 每一頁各挑一個顏色不是「豐富」，是雜亂 —— 翻頁時整份筆記在閃。
    /// 一本筆記一個調子，而那個調子是使用者選的。
    var guidePaletteMenu: some View {
        let current = notebook.guidePaletteId ?? guidePalettes().first?.id ?? "graphite"
        return Menu {
            ForEach(guidePalettes(), id: \.id) { palette in
                Button {
                    applyGuidePalette(palette.id)
                } label: {
                    HStack {
                        Text(localizationManager.localized(palette.nameKey))
                        if current == palette.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                // 直接畫出那個顏色。名字旁邊放一個色點，比只寫「靛藍」清楚 ——
                // 使用者要挑的是顏色，不是詞。
                Circle()
                    .fill(Color(uiColor: UIColor(hexString: guidePalette(id: current).accentHex) ?? .systemIndigo))
                    .frame(width: EditorToolbarMetrics.icon - 4, height: EditorToolbarMetrics.icon - 4)
                Text(localizationManager.localized(guidePalette(id: current).nameKey))
                    .font(.system(size: EditorToolbarMetrics.label))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("guide_palette"))
        .help(localizationManager.localized("guide_palette_desc"))
    }

    private func applyGuidePalette(_ id: String) {
        guard notebook.guidePaletteId != id else { return }
        notebook.guidePaletteId = id
        commitNotebook()
        // 縮圖的快取鍵含配色，所以側欄會跟著換 —— 但畫布要自己重畫一次。
        PageThumbnailRenderer.invalidateAll()
        showCanvasNotice(localizationManager.localized(guidePalette(id: id).nameKey))
    }

    /// 換一種紙。
    ///
    /// 換完之後**既有的內容要跟著進來**：A4 直式換成 A5 之後，原本靠右
    /// 那一欄的東西會落在新頁面外面 —— 畫布上看得到、匯出時整欄不見。
    /// 所以一併把每個物件夾回新的可列印範圍，並講清楚發生了什麼事。
    private func applyPageFormat(_ id: String) {
        guard notebook.pageFormatId != id else { return }
        notebook.pageFormatId = id
        PageGeometry.use(format: id)
        clampAttachmentsIntoPage()
        commitNotebook()
        showCanvasNotice(localizationManager.localized("page_format_change_warning"))
    }

    /// 把所有附件夾回目前頁面的可列印範圍。
    private func clampAttachmentsIntoPage() {
        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)

        func fit(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            let clamped = clampToPrintable(
                rect: FfiRect(
                    minX: Float(x), minY: Float(y),
                    maxX: Float(x + w), maxY: Float(y + h)),
                pageWidth: Float(page.width), pageHeight: Float(page.height), inset: inset)
            return CGRect(
                x: CGFloat(clamped.minX), y: CGFloat(clamped.minY),
                width: CGFloat(clamped.maxX - clamped.minX),
                height: CGFloat(clamped.maxY - clamped.minY))
        }

        notebook.attachments = notebook.attachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            moved.width = r.width; moved.height = r.height
            return moved
        }
        notebook.textAttachments = notebook.textAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            moved.width = r.width; moved.height = r.height
            return moved
        }
        notebook.tableAttachments = notebook.tableAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, 0)
            moved.x = r.minX; moved.y = r.minY
            return moved
        }
        notebook.shapeAttachments = notebook.shapeAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            return moved
        }
    }

    /// 把落在可列印範圍**之外**的筆畫收回。
    ///
    /// # 為什麼是「完全在外面才收回」
    ///
    /// 界線判斷分三種答案（見核心 `is_within_printable` / `is_outside_printable`）：
    /// 整個在裡面、整個在外面、跨在界線上。三種要分開處理：
    ///
    /// - **整個在外面** → 收回。那一筆印不出來也匯不出去，留著只會讓使用者
    ///   以為它存在，等到列印那天才發現不見了。
    /// - **跨在界線上** → 留著，但提醒一次。寫到一半被整筆吃掉比溢出更難用，
    ///   而且那一筆大半還看得見。
    ///
    /// 要改成「碰到界線就擋」的話，把下面的 `isOutside` 換成 `!isWithin` 即可。
    private func enforcePrintableArea(_ drawing: PKDrawing) -> PKDrawing {
        guard drawing.strokes.count > lastStrokeCount else { return drawing }

        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)
        var kept: [PKStroke] = []
        var rejected = false
        var straddled = false

        for (index, stroke) in drawing.strokes.enumerated() {
            // 只檢查這一次新加的那幾筆 —— 既有的筆畫可能是別的裝置或別的
            // 頁面尺寸下寫的，回頭去刪它們等於幫使用者做了他沒要求的決定。
            guard index >= lastStrokeCount else {
                kept.append(stroke)
                continue
            }
            let bounds = stroke.renderBounds
            let rect = FfiRect(
                minX: Float(bounds.minX), minY: Float(bounds.minY),
                maxX: Float(bounds.maxX), maxY: Float(bounds.maxY))
            if isOutsidePrintable(
                rect: rect, pageWidth: Float(page.width),
                pageHeight: Float(page.height), inset: inset) {
                rejected = true
                continue
            }
            if !isWithinPrintable(
                rect: rect, pageWidth: Float(page.width),
                pageHeight: Float(page.height), inset: inset) {
                straddled = true
            }
            kept.append(stroke)
        }

        if rejected {
            showCanvasNotice(localizationManager.localized("outside_printable_rejected"))
            return PKDrawing(strokes: kept)
        }
        if straddled {
            showCanvasNotice(localizationManager.localized("outside_printable_clamped"))
        }
        return drawing
    }

    /// 在畫布上顯示一則提示，幾秒後自己淡掉。
    func showCanvasNotice(_ text: String) {
        canvasNoticeToken += 1
        let token = canvasNoticeToken
        withAnimation(.easeInOut(duration: 0.2)) { canvasNotice = text }
        let duration: Double = ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" ? 10.0 : 3.5
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard canvasNoticeToken == token else { return }
            withAnimation(.easeInOut(duration: 0.3)) { canvasNotice = nil }
        }
    }

    /// 自動清理重複 ID 與未完成的幽靈空白文字方塊
    private func sanitizeTextAttachments() {
        guard let attachments = notebook.textAttachments, !attachments.isEmpty else { return }
        var seenIds = Set<String>()
        var cleaned: [NoteTextAttachment] = []
        for item in attachments {
            if seenIds.contains(item.id) {
                // 重複 ID：若已存入的是空的但目前這筆有內容，以有內容的替換
                if !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let existingIdx = cleaned.firstIndex(where: { $0.id == item.id }),
                       cleaned[existingIdx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        cleaned[existingIdx] = item
                    }
                }
                continue
            }
            // 清理幽靈空方塊（若文字為空且非當前正在輸入的項目，自動清除）
            if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && item.id != inlineEditingTextId {
                continue
            }
            seenIds.insert(item.id)
            cleaned.append(item)
        }
        if cleaned.count != attachments.count {
            notebook.textAttachments = cleaned
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        }
    }

    /// 自動自癒示範筆記《Kairumo(功能範例)》：將背景大卡片移至筆跡下方圖層，使筆跡可見且不干擾手繪與打字。
    private func sanitizeUnderInkObjects() {
        let isShowcase = notebook.id.caseInsensitiveCompare("seed-feature-showcase-v1") == .orderedSame || notebook.titleKey == "seed_feature_showcase_title"
        if isShowcase {
            if notebook.underInkObjectIds(forPage: 1).isEmpty {
                for p in 0..<notebook.pageCount {
                    let bgCardIds = (notebook.shapeAttachments ?? []).filter {
                        $0.pageIndex == p && $0.kindName == "rectangle" && $0.label.isEmpty
                    }.map(\.id)
                    notebook.setUnderInkObjectIds(Set(bgCardIds), forPage: p)
                }
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        }
    }

    /// 打字工具列要套用格式的那一個方塊。
    ///
    /// **不再退回「這一頁第一個方塊」。** 那個退路讓工具列在焦點一閃而過時
    /// 改到不相干的方塊（例如頁首標題被加上「1. ☐」）。沒有目標就回 nil，
    /// 由呼叫端決定（工具列改的是 `pendingTypingStyle`）。
    var activeTextAttachment: NoteTextAttachment? {
        func find(_ id: String) -> NoteTextAttachment? {
            notebook.textAttachments?.first(where: { $0.id == id })
        }
        if let id = inlineEditingTextId { return find(id) }
        if let id = editingTextId { return find(id) }
        if let id = activeSelectedObjectId {
            // 選中的是圖片、表格等非文字物件：文字工具列沒有目標。
            return find(id)
        }
        if !selectedShapeIds.isEmpty || !selectedObjectIds.isEmpty { return nil }
        if let id = textFormatTargetId, let match = find(id), match.pageIndex == currentPageIndex {
            return match
        }
        return nil
    }

    /// 使用者主動換了目標（點畫布、換頁、換模式）：格式化工作階段結束。
    private func endTextFormatSession() {
        textFormatTargetId = nil
        suspendedInlineTextId = nil
    }

    /// 打字工具列的每一個格式變更都走這裡：記復原點、調整高度、存檔、廣播，
    /// 再把游標還給剛剛在打字的方塊 —— 跟 Word 一樣，按完粗體可以直接接著打。
    /// 工具列這一次要改哪裡：選取的字、游標處、或整個方塊（見 `TextFormatScope`）。
    private func textFormatScope(for target: NoteTextAttachment) -> TextFormatScope {
        let tracker = textSelectionTracker
        guard tracker.textId == target.id,
              inlineEditingTextId == target.id || suspendedInlineTextId == target.id else { return .wholeBox }
        let length = RichText.utf16Length(target.text)
        let location = min(max(0, tracker.range.location), length)
        let range = NSRange(location: location, length: min(max(0, tracker.range.length), length - location))
        if range.length > 0 {
            // 全選等於整個方塊：改方塊層級的值，之後在結尾接著打的字也會是這個格式。
            return range.length == length ? .wholeBox : .selection(range)
        }
        if let word = RichText.wordRange(around: location, in: target.text) { return .selection(word) }
        return .caret(location)
    }

    /// 工具列顯示的格式：有選取時是選取文字的格式（Word 的按鈕狀態跟著選取走），
    /// 只有游標時是游標處的格式，否則是方塊層級的格式。
    func toolbarDisplayedText() -> NoteTextAttachment {
        guard let target = activeTextAttachment else { return pendingTypingStyle }
        let resolved: ResolvedCharStyle
        switch textFormatScope(for: target) {
        case .wholeBox:
            return target
        case .selection(let range):
            resolved = RichText.resolvedStyle(at: range, in: target)
        case .caret(let location):
            let caret = textSelectionTracker.caretStyle
            if let caret, caret.textId == target.id, caret.location == location {
                resolved = RichText.resolve(caret.style, over: RichText.base(of: target))
            } else {
                resolved = RichText.resolvedStyle(at: NSRange(location: location, length: 0), in: target)
            }
        }
        var shown = target
        shown.isBold = resolved.bold
        shown.isItalic = resolved.italic
        shown.isUnderline = resolved.underline
        shown.isStrikethrough = resolved.strikethrough
        shown.fontSize = resolved.fontSize
        shown.fontFamily = resolved.fontFamily
        shown.textColorHex = resolved.textColorHex
        return shown
    }

    /// 工具列改了哪些字元格式（與它看到的值比較）。
    private func charStyleChange(from shown: NoteTextAttachment, to updated: NoteTextAttachment) -> TextCharStyle {
        var edit = TextCharStyle()
        if shown.isBold != updated.isBold { edit.bold = updated.isBold }
        if shown.isItalic != updated.isItalic { edit.italic = updated.isItalic }
        if shown.isUnderline != updated.isUnderline { edit.underline = updated.isUnderline }
        if shown.isStrikethrough != updated.isStrikethrough { edit.strikethrough = updated.isStrikethrough }
        if abs(shown.fontSize - updated.fontSize) > 0.001 { edit.fontSize = updated.fontSize }
        if shown.fontFamily != updated.fontFamily { edit.fontFamily = updated.fontFamily ?? "" }
        if shown.textColorHex != updated.textColorHex { edit.textColorHex = updated.textColorHex }
        return edit
    }

    /// 打字工具列的每一個格式變更都走這裡：決定套用範圍、記復原點、調整高度、存檔、廣播，
    /// 再把游標還給剛剛在打字的方塊 —— 跟 Word 一樣，按完粗體可以直接接著打。
    func applyToolbarTextChange(_ updated: NoteTextAttachment) {
        guard let target = activeTextAttachment, target.id == updated.id,
              notebook.textAttachments?.contains(where: { $0.id == target.id }) == true else {
            var style = updated
            style.text = ""
            pendingTypingStyle = style
            return
        }
        let edit = charStyleChange(from: toolbarDisplayedText(), to: updated)

        // 段落層級的欄位（對齊、縮排、行距、文字內容…）直接沿用工具列的值；
        // 字元層級的欄位先還原成方塊原本的值，再依範圍套用這一次的變更。
        var next = updated
        next.isBold = target.isBold
        next.isItalic = target.isItalic
        next.isUnderline = target.isUnderline
        next.isStrikethrough = target.isStrikethrough
        next.fontSize = target.fontSize
        next.fontFamily = target.fontFamily
        next.textColorHex = target.textColorHex
        next.runs = target.runs
        if next.text != target.text {
            RichText.adjustRunsLineByLine(of: &next, from: target.text)
        }
        if !edit.isEmpty {
            switch textFormatScope(for: target) {
            case .wholeBox:
                RichText.applyToWholeBox(edit, to: &next)
            case .selection(let range):
                RichText.apply(edit, range: range, to: &next)
            case .caret(let location):
                // 只有游標：不改現有的字，改接下來要打的字（Word 的行為）。
                var caret = textSelectionTracker.caretStyle
                if caret?.textId != target.id || caret?.location != location {
                    caret = CaretStyle(textId: target.id, location: location, style: TextCharStyle())
                }
                if var caret {
                    caret.style = caret.style.overlaid(with: edit)
                    textSelectionTracker.setCaretStyle(caret)
                }
            }
        }
        commitToolbarText(next)
    }

    /// 把工具列算好的結果寫回筆記本。
    private func commitToolbarText(_ candidate: NoteTextAttachment) {
        guard let idx = notebook.textAttachments?.firstIndex(where: { $0.id == candidate.id }) else { return }
        guard notebook.textAttachments?[idx] != candidate else {
            resumeInlineEditingAfterToolbar(candidate.id)
            return
        }
        recordTextUndoState()
        var next = candidate
        next.height = max(next.height, RichText.boxHeight(for: next))
        notebook.textAttachments?[idx] = next
        textFormatTargetId = next.id
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(next),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        resumeInlineEditingAfterToolbar(next.id)
    }

    /// 工具列醒目提示按鈕目前代表的顏色。
    func toolbarHighlightHex() -> String? {
        guard let target = activeTextAttachment else { return nil }
        switch textFormatScope(for: target) {
        case .selection(let range):
            return RichText.resolvedStyle(at: range, in: target).highlightHex
        case .caret(let location):
            if let caret = textSelectionTracker.caretStyle, caret.textId == target.id, caret.location == location {
                return caret.style.highlightHex == "clear" ? nil : caret.style.highlightHex
            }
            return RichText.resolvedStyle(at: NSRange(location: location, length: 0), in: target).highlightHex
        case .wholeBox:
            // 整個方塊都是同一個醒目提示色時才算「有」。
            let runs = RichText.normalized(target) ?? []
            let length = RichText.utf16Length(target.text)
            if runs.count == 1, runs[0].start == 0, runs[0].length == length { return runs[0].style.highlightHex }
            return nil
        }
    }

    /// Word 的文字醒目提示：套在字上（字的背景），不是整個方塊的底色。
    func applyToolbarHighlight(_ hex: String) {
        guard let target = activeTextAttachment else { return }
        var next = target
        let edit = TextCharStyle(highlightHex: hex)
        switch textFormatScope(for: target) {
        case .wholeBox:
            RichText.applyToWholeBox(edit, to: &next)
        case .selection(let range):
            RichText.apply(edit, range: range, to: &next)
        case .caret(let location):
            var caret = textSelectionTracker.caretStyle
            if caret?.textId != target.id || caret?.location != location {
                caret = CaretStyle(textId: target.id, location: location, style: TextCharStyle())
            }
            if var caret {
                caret.style = caret.style.overlaid(with: edit)
                textSelectionTracker.setCaretStyle(caret)
            }
        }
        commitToolbarText(next)
    }

    /// Word 的「清除所有格式設定」：有選取時只清選取的字；否則整個方塊回到內文樣式。
    /// 段落設定（對齊、行距、縮排）一律回到預設。文字內容不動。
    func clearToolbarFormatting() {
        guard let target = activeTextAttachment else {
            pendingTypingStyle = NoteTextAttachment(
                id: pendingTypingStyle.id, text: "", backgroundColorHex: "clear", hasBorder: false)
            return
        }
        var next = target
        next.alignmentRaw = "left"
        next.lineSpacing = nil
        next.paragraphIndent = nil
        switch textFormatScope(for: target) {
        case .selection(let range):
            RichText.clearOverrides(in: range, of: &next)
        case .caret:
            textSelectionTracker.clear(textId: target.id)
            next.runs = target.runs
        case .wholeBox:
            next.fontSize = 15
            next.fontFamily = nil
            next.isBold = false
            next.isItalic = false
            next.isUnderline = false
            next.isStrikethrough = false
            next.textColorHex = "#000000"
            next.runs = nil
        }
        commitToolbarText(next)
    }

    /// Word 格式快捷鍵（見 `TextFormatCommand`）。只在打字工具列出現時作用，
    /// 手繪時按 ⌘B 不該偷偷改掉某個文字方塊。
    private func handleTextFormatCommand(_ command: TextFormatCommand) {
        guard effectiveToolbarMode == .type else { return }
        var next = toolbarDisplayedText()
        switch command {
        case .bold: next.isBold.toggle()
        case .italic: next.isItalic.toggle()
        case .underline: next.isUnderline.toggle()
        case .strikethrough: next.isStrikethrough.toggle()
        case .growFont: next.fontSize = min(400, next.fontSize + 1)
        case .shrinkFont: next.fontSize = max(1, next.fontSize - 1)
        case .alignLeft: next.alignmentRaw = "left"
        case .alignRight: next.alignmentRaw = "right"
        case .bulletList:
            guard activeTextAttachment != nil else {
                insertQuickTextSnippet("• ")
                return
            }
            next.text = WordListKind.bullet.toggle(in: next.text)
        }
        applyToolbarTextChange(next)
    }

    /// 焦點是被工具列借走的：把就地編輯還回去，鍵盤／游標回到原方塊。
    private func resumeInlineEditingAfterToolbar(_ id: String) {
        guard suspendedInlineTextId == id else { return }
        // 等選單／按鈕的事件跑完再要焦點，否則 UIKit 會在收選單時又把它收走。
        DispatchQueue.main.async {
            guard suspendedInlineTextId == id, inlineEditingTextId == nil,
                  notebook.textAttachments?.contains(where: { $0.id == id }) == true else { return }
            suspendedInlineTextId = nil
            // 新的編輯器把游標（或選取範圍）放回原處，而不是跳到最後。
            textSelectionTracker.restoreSelectionOnNextBegin = true
            inlineEditingTextId = id
        }
    }

    var isCurrentTextBold: Bool {
        activeTextAttachment?.isBold ?? false
    }

    var isCurrentTextItalic: Bool {
        activeTextAttachment?.isItalic ?? false
    }

    var isCurrentTextUnderline: Bool {
        activeTextAttachment?.isUnderline ?? false
    }

    var currentTextAlignment: String {
        activeTextAttachment?.alignmentRaw ?? "left"
    }

    private func ensureActiveTextAttachment() -> (id: String, index: Int) {
        if let id = activeTextAttachment?.id,
           let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
            return (id, index)
        }
        let draft = insertTextBox(at: CGPoint(x: PageGeometry.printableInset, y: 200))
        let idx = (notebook.textAttachments?.firstIndex(where: { $0.id == draft.id })) ?? 0
        return (draft.id, idx)
    }

    func toggleActiveTextBold() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isBold.toggle()
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func toggleActiveTextItalic() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isItalic.toggle()
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func toggleActiveTextUnderline() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isUnderline.toggle()
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func setActiveTextAlignment(_ align: String) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].alignmentRaw = align
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func changeActiveTextFontSize(delta: CGFloat) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        let current = notebook.textAttachments?[target.index].fontSize ?? 16
        notebook.textAttachments?[target.index].fontSize = max(10, min(72, current + delta))
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func setActiveTextColor(_ hex: String) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].textColorHex = hex
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func bringActiveObjectForward() {
        let order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        let targetId = inlineEditingTextId ?? editingTextId ?? selectedShapeIds.first ?? selectedObjectIds.first ?? (notebook.textAttachments?.last(where: { $0.pageIndex == currentPageIndex })?.id)
        guard let id = targetId else { return }
        let newOrder = ObjectStacking.bringForward([id], in: order)
        notebook.setObjectOrder(newOrder, forPage: currentPageIndex)
        commitNotebook()
    }

    func sendActiveObjectBackward() {
        let order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        let targetId = inlineEditingTextId ?? editingTextId ?? selectedShapeIds.first ?? selectedObjectIds.first ?? (notebook.textAttachments?.last(where: { $0.pageIndex == currentPageIndex })?.id)
        guard let id = targetId else { return }
        let newOrder = ObjectStacking.sendBackward([id], in: order)
        notebook.setObjectOrder(newOrder, forPage: currentPageIndex)
        commitNotebook()
    }

    private func findObjectAt(location: CGPoint, page: Int) -> (id: String, kind: String)? {
        let order = notebook.objectOrder(forPage: page)
        let stacking = ObjectStacking.Lookup(order: order)

        var candidates: [(id: String, kind: String, z: Double, rect: CGRect)] = []
        if let items = notebook.attachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "image", stacking.zIndex(for: item.id, kind: .image), rect))
            }
        }
        if let items = notebook.shapeAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "shape", stacking.zIndex(for: item.id, kind: .shape), rect))
            }
        }
        if let items = notebook.tableAttachments {
            for item in items where item.pageIndex == page {
                let layout = item.layout()
                let rect = CGRect(x: item.x, y: item.y, width: CGFloat(layout.width), height: CGFloat(layout.height)).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "table", stacking.zIndex(for: item.id, kind: .table), rect))
            }
        }
        if let items = notebook.audioAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "audio", stacking.zIndex(for: item.id, kind: .audio), rect))
            }
        }
        if let items = notebook.linkAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "link", stacking.zIndex(for: item.id, kind: .link), rect))
            }
        }
        if let items = notebook.model3DAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "3d", stacking.zIndex(for: item.id, kind: .model3D), rect))
            }
        }
        let hit = candidates.filter { $0.rect.contains(location) }.sorted(by: { $0.z > $1.z })
        if let first = hit.first {
            return (first.id, first.kind)
        }
        return nil
    }

    private func rectContainsPoint(_ baseRect: CGRect, rotation: Double, touchPadding: CGFloat, point: CGPoint) -> Bool {
        let touchRect = baseRect.insetBy(dx: -touchPadding, dy: -touchPadding)
        if abs(rotation) < 0.1 {
            return touchRect.contains(point)
        }
        let center = CGPoint(x: baseRect.midX, y: baseRect.midY)
        let rad = -rotation * .pi / 180.0
        let dx = point.x - center.x
        let dy = point.y - center.y
        let unrotated = CGPoint(
            x: center.x + CGFloat(Double(dx) * cos(rad) - Double(dy) * sin(rad)),
            y: center.y + CGFloat(Double(dx) * sin(rad) + Double(dy) * cos(rad))
        )
        return touchRect.contains(unrotated)
    }

    /// 智慧穿透判定：當觸控點落在筆跡下方的物件時，決定是否讓畫布返回 nil 使得觸控能直達下層物件
    // unused-param-ok: 依 UIKit hitTest(_:with:) 簽章保留 event 參數供擴充使用，穿透邏輯以座標與物件狀態裁決
    private func isUnderInkPointPassThrough(point: CGPoint, page: Int, event: UIEvent? = nil) -> Bool {
        // 手寫模式下，若沒有任何物件處於選取或編輯狀態，所有觸控一律留在畫布上（O(1) 快速返回，避免每次 hitTest 配置集合與掃描附件陣列）。
        if editorMode == .draw,
           activeSelectedObjectId == nil,
           selectedObjectIds.isEmpty,
           selectedShapeIds.isEmpty,
           inlineEditingTextId == nil,
           editingTextId == nil {
            return false
        }
        // 鎖定的物件不接觸控：落在它上面的筆照樣畫在畫布上，不穿透下去。
        let underInkSet = notebook.underInkObjectIds(forPage: page)
            .subtracting(notebook.allLockedObjectIds)
        guard !underInkSet.isEmpty else { return false }

        var hitSelected = false
        var hitUnselected = false

        let checkHit: (CGRect, Double, Bool) -> Void = { baseRect, rot, isSel in
            let padding: CGFloat = isSel ? 48 : 8
            if rectContainsPoint(baseRect, rotation: rot, touchPadding: padding, point: point) {
                if isSel {
                    hitSelected = true
                } else {
                    hitUnselected = true
                }
            }
        }

        if let items = notebook.attachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), item.canvasRotation, isSel)
            }
        }
        if let items = notebook.textAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id) || inlineEditingTextId == item.id || editingTextId == item.id)
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), item.canvasRotation, isSel)
            }
        }
        if let items = notebook.shapeAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (selectedShapeIds.contains(item.id) || activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), item.canvasRotation, isSel)
            }
        }
        if let items = notebook.tableAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                let layout = item.layout()
                checkHit(CGRect(x: item.x, y: item.y, width: CGFloat(layout.width), height: CGFloat(layout.height)), 0, isSel)
            }
        }
        if let items = notebook.linkAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), 0, isSel)
            }
        }
        if let items = notebook.audioAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), 0, isSel)
            }
        }
        if let items = notebook.model3DAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), 0, isSel)
            }
        }

        if hitSelected {
            // 已選取的筆跡下方物件：優先穿透，以操作控制把手、旋轉、縮放與拖曳
            return true
        }

        if hitUnselected {
            // 未選取的筆跡下方物件：
            // 打字模式下穿透以利點選；手繪模式下不穿透，由畫布接收以順暢在其上方繪圖
            return editorMode == .type
        }

        return false
    }

    private func isLocationInsideAnyObject(at location: CGPoint, page: Int) -> Bool {
        if findObjectAt(location: location, page: page) != nil { return true }
        if let items = notebook.tapeAttachments {
            for item in items where item.pageIndex == page {
                if item.rect.insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        return false
    }

    /// 🌟 全自動意圖感知：Apple Pencil 碰到畫布時自動切換至手繪模式，並收回未輸入完成的空白文字框
    private func handlePencilTouchBegan() {
        // 手繪區塊已經取得墨跡輸入權，不要再把頂層文件模式改成 `.draw`。
        if editorMode != .draw && !isInlineInkEditing {
            pencilModeSwitchAt = Date()
            // 不加動畫：筆尖已經在紙上，0.2 秒的過場期間整個編輯器在重排，第一筆會卡在那段時間裡。
            transitionToMode(.draw, animated: false)
        }
        if let activeId = inlineEditingTextId {
            if let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
               activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notebook.textAttachments?.removeAll { $0.id == activeId }
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
            inlineEditingTextId = nil
        }
    }

    /// 拿掉「手指輕點」留下的那個小點。
    ///
    /// 只動**最後一筆**，而且必須同時符合：夠小（近乎一個點）、就落在點擊位置、
    /// 剛剛才畫下（不會誤刪使用者真正寫的東西）。
    private func removeTapDotStroke(near location: CGPoint) {
        guard let last = currentDrawing.strokes.last else { return }
        let bounds = last.renderBounds
        let isDot = bounds.width < 10 && bounds.height < 10
        let isHere = abs(bounds.midX - location.x) < 16 && abs(bounds.midY - location.y) < 16
        let isFresh = Date().timeIntervalSince(last.path.creationDate) < 2
        guard isDot, isHere, isFresh else { return }
        var strokes = currentDrawing.strokes
        strokes.removeLast()
        currentDrawing = PKDrawing(strokes: strokes)
    }

    // MARK: - 特殊樣板智慧互動引導線（核取方塊 Checkbox、選項狀態與進度管控）

    struct GuideCheckboxItem: Identifiable {
        let id: String
        let key: String
        let guide: FfiGuide
        let page: Int
    }

    private func interactiveGuideCheckboxes(forPage page: Int) -> [GuideCheckboxItem] {
        let paper = notebook.paperId(forPage: page)
        let guides = pageGuides(
            paperId: paper,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        return guides.filter { $0.kind == .checkbox }.map { g in
            let gx = CGFloat(g.x), gy = CGFloat(g.y)
            let key = "\(page)_\(Int(round(gx)))_\(Int(round(gy)))"
            return GuideCheckboxItem(id: key, key: key, guide: g, page: page)
        }
    }

    private func hitTestGuideCheckbox(at location: CGPoint, page: Int) -> (guide: FfiGuide, key: String)? {
        let items = interactiveGuideCheckboxes(forPage: page)
        for item in items {
            let gx = CGFloat(item.guide.x), gy = CGFloat(item.guide.y)
            let gw = CGFloat(item.guide.w), gh = CGFloat(item.guide.h)
            // 擴展點擊範圍（約 34x34pt），手指與觸控筆皆能精準觸發
            let hitRect = CGRect(x: gx, y: gy, width: gw, height: gh).insetBy(dx: -12, dy: -10)
            if hitRect.contains(location) {
                return (item.guide, item.key)
            }
        }
        return nil
    }

    private func toggleGuideCheckbox(key: String) {
        if notebook.checkedGuideItems == nil {
            notebook.checkedGuideItems = [:]
        }
        let current = notebook.checkedGuideItems?[key] ?? false
        notebook.checkedGuideItems?[key] = !current
        commitNotebook()
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
        PageThumbnailRenderer.invalidateAll()
    }

    private func toggleRowStrikethrough(y: CGFloat, page: Int) {
        guard let texts = notebook.textAttachments, !texts.isEmpty else { return }
        recordTextUndoState()
        var updated = texts
        for i in 0 ..< updated.count where updated[i].pageIndex == page && abs(updated[i].y - y) < 30 {
            updated[i].isStrikethrough.toggle()
        }
        notebook.textAttachments = updated
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    private func clearRowText(y: CGFloat, page: Int) {
        guard let texts = notebook.textAttachments, !texts.isEmpty else { return }
        recordTextUndoState()
        notebook.textAttachments?.removeAll { $0.pageIndex == page && abs($0.y - y) < 30 }
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    private func resetPageCheckboxes(page: Int) {
        guard var checked = notebook.checkedGuideItems, !checked.isEmpty else { return }
        let prefix = "\(page)_"
        for key in checked.keys where key.hasPrefix(prefix) {
            checked[key] = false
        }
        notebook.checkedGuideItems = checked
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    /// 🌟 方案 A+B：手指或游標在畫布上的單擊事件
    private func handleCanvasDirectTap(at location: CGPoint, page: Int? = nil) {
        if Date().timeIntervalSince(lastPastePlacementAt) < 0.35 {
            removeTapDotStroke(near: location)
            return
        }
        endTextFormatSession()
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage

        if isPlacingPasteObject && !objectClipboard.isEmpty {
            lastPastePlacementAt = Date()
            removeTapDotStroke(near: location)
            paste(objectClipboard, onPage: targetPage, at: location)
            isPlacingPasteObject = false
            return
        }

        // 🌟 優先檢查是否點擊在特殊樣板引導線互動元件上（例如核取方塊 Checkbox）
        if let (_, key) = hitTestGuideCheckbox(at: location, page: targetPage) {
            removeTapDotStroke(near: location)
            toggleGuideCheckbox(key: key)
            return
        }

        if editorMode == .type {
            handleCanvasTapInTypeMode(at: location, page: targetPage)
        } else {
            // 手寫模式下手指點到鎖定的物件（或它角落的鎖頭）：鎖定的物件不接觸控，
            // 也不能被選起來 —— 這一下就是要找解鎖的入口。手寫模式下物件層不吃觸控、
            // 解鎖鈕按不到，所以切到打字模式再給解鎖鈕（與放置貼紙同一個做法）。
            if let lockedId = lockedObjectHit(at: location, page: targetPage) {
                removeTapDotStroke(near: location)
                transitionToMode(.type)
                lockPromptId = lockedId
                return
            }

            // 手寫模式下單擊：優先檢查是否點擊在既有文字方塊範圍內
            if let existing = notebook.textAttachments?.first(where: { item in
                item.pageIndex == targetPage &&
                CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -12, dy: -12).contains(location)
            }) {
                // 單擊與 PencilKit 的繪圖手勢同時辨識（見 `Coordinator.gestureRecognizer`），
                // 手指輕點會被畫成一個小點。這一下是「點文字方塊」，不是落筆 ——
                // 把那個點拿掉，否則每次點方塊紙上都多一顆墨點。
                removeTapDotStroke(near: location)
                withAnimation(.easeInOut(duration: 0.15)) {
                    // 全自動意圖感知：手指點擊文字方塊，立即進入行內聚焦編輯並展開 Word 級文字工具列
                    inlineEditingTextId = existing.id
                    editingTextId = nil
                    activeSelectedObjectId = existing.id
                }
                return
            }

            // 手指輕點到文字以外的物件（圖片、形狀、表格、錄音卡…）：使用者要的是「選它」。
            // 手寫模式下手指點中物件，精準選中物件並顯示把手，同時維持手繪工具列就緒，不強迫進入打字模式。
            if let (hitId, hitKind) = findObjectAt(location: location, page: targetPage) {
                removeTapDotStroke(near: location)
                withAnimation(.easeInOut(duration: 0.15)) {
                    inlineEditingTextId = nil
                    if hitKind == "shape" {
                        selectedShapeIds = [hitId]
                        activeSelectedObjectId = nil
                    } else {
                        selectedShapeIds = []
                        activeSelectedObjectId = hitId
                    }
                    selectedConnectionId = nil
                    selectedObjectIds = [hitId]
                    collaborationManager.broadcastSelection(selectedId: hitId)
                }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                return
            }

            // 手寫模式下單擊畫布空白處：清空所有選取狀態
            activeSelectedObjectId = nil
            selectedShapeIds = []
            selectedConnectionId = nil
            selectedObjectIds = []
            collaborationManager.broadcastSelection(selectedId: nil)

            if let activeId = inlineEditingTextId {
                if let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
                   activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notebook.textAttachments?.removeAll { $0.id == activeId }
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                    watchdog.notifyEmptyTextBoxDismissedQuickly(isStylusActive: true) {
                        transitionToMode(.draw)
                    }
                }
                inlineEditingTextId = nil
            }
        }
    }

    /// 🌟 方案 A+B：手指或游標在畫布上的雙擊事件（手繪或打字模式下皆可直接建立並聚焦文字方塊）
    private func handleCanvasDirectDoubleTap(at location: CGPoint, page: Int? = nil) {
        endTextFormatSession()
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage
        if hitTestGuideCheckbox(at: location, page: targetPage) != nil { return }
        if isLocationInsideAnyObject(at: location, page: targetPage) { return }
        // 若先前有空白文字方塊先清理
        if let activeId = inlineEditingTextId,
           let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
           activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notebook.textAttachments?.removeAll { $0.id == activeId }
            commitNotebook()
            if activeSelectedObjectId == activeId {
                activeSelectedObjectId = nil
            }
            PageThumbnailRenderer.invalidateAll()
        }
        let draft = insertTextBox(at: location, page: targetPage, tapToWrite: true)
        transitionToMode(.type)
        activeSelectedObjectId = nil
        inlineEditingTextId = draft.id
        editingTextId = nil
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
    }

    private func handleCanvasTapInTypeMode(at location: CGPoint, page: Int? = nil) {
        endTextFormatSession()
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage

        // 0. 特殊頁面智慧引導線元件（核取方塊 Checkbox 等）點擊判定
        if let (_, key) = hitTestGuideCheckbox(at: location, page: targetPage) {
            toggleGuideCheckbox(key: key)
            return
        }
        // 0b. 點到鎖定在畫布上的物件：鎖定的物件不接觸控，這一下穿透到頁面來了。
        // 不當成「點空白」（會在這裡開新文字方塊、或就地編輯它），而是在它上方給「解除鎖定」鈕 ——
        // 看得到的物件就要點得到解鎖的入口。只有單指點一下才會到這裡，雙指縮放、捲動照樣穿透。
        if let lockedId = lockedObjectHit(at: location, page: targetPage) {
            lockPromptId = (lockPromptId == lockedId) ? nil : lockedId
            return
        }
        lockPromptId = nil

        // 1. 若先前有就地編輯但未打任何字的空方塊，先自動清理
        if let activeId = inlineEditingTextId,
           let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
           activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notebook.textAttachments?.removeAll { $0.id == activeId }
            commitNotebook()
            inlineEditingTextId = nil
            if activeSelectedObjectId == activeId {
                activeSelectedObjectId = nil
            }
            PageThumbnailRenderer.invalidateAll()
            watchdog.notifyEmptyTextBoxDismissedQuickly(isStylusActive: true) {
                transitionToMode(.draw)
            }
        }

        // 2. 檢查是否點擊在既有文字範圍內
        if let existing = notebook.textAttachments?.first(where: { item in
            item.pageIndex == targetPage &&
            CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -12, dy: -12).contains(location)
        }) {
            // 直接就地聚焦編輯既有文字，退出其他物件選取
            activeSelectedObjectId = existing.id
            inlineEditingTextId = existing.id
            editingTextId = nil
            selectedShapeIds = []
            selectedConnectionId = nil
            selectedObjectIds = []
            collaborationManager.broadcastSelection(selectedId: existing.id)
            return
        }

        // 3. 若點擊在其他畫布物件（圖片、表格、形狀、錄音卡片、3D等）上，選取該物件並展開操作把手
        if let (hitId, hitKind) = findObjectAt(location: location, page: targetPage) {
            inlineEditingTextId = nil
            if hitKind == "shape" {
                selectedShapeIds = [hitId]
                activeSelectedObjectId = nil
            } else {
                selectedShapeIds = []
                activeSelectedObjectId = hitId
            }
            selectedConnectionId = nil
            selectedObjectIds = [hitId]
            collaborationManager.broadcastSelection(selectedId: hitId)
            return
        }

        // 4. 點擊空白處：在打字模式下，點擊空白處即為「隨點即書」
        // 先清理所有先前的物件選取與就地編輯焦點
        activeSelectedObjectId = nil
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
        inlineEditingTextId = nil
        editingTextId = nil
        collaborationManager.broadcastSelection(selectedId: nil)

        // 立即在手指點擊處啟動隨點隨打（隨點即書）
        let draft = insertTextBox(at: location, page: targetPage, tapToWrite: true)
        // 隨點即書為純文字輸入游標，不啟用物件選取態（保持 activeSelectedObjectId = nil），
        // 避免渲染出選取藍框與縮放/旋轉把手（使用戶誤以為是「新增文字方塊」按鈕產生的物件）
        activeSelectedObjectId = nil
        inlineEditingTextId = draft.id
        editingTextId = nil
    }

    /// 打字模式下 Apple Pencil 輕點：移除可能產生的微小墨點，並轉由文字模式點擊處理（即點即書或聚焦文字/物件）
    private func handlePencilTapInTypeMode(at location: CGPoint, page: Int? = nil) {
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage
        removeTapDotStroke(near: location)
        handleCanvasTapInTypeMode(at: location, page: targetPage)
    }


    /// 這一頁所有水平格線的 y（導引線與底紋都算，見 `RuledWriting.horizontalRules`）。
    private func pageHorizontalRules(page: Int? = nil) -> [CGFloat] {
        let paperId = notebook.paperId(forPage: page ?? currentPageIndex)
        let guides = pageGuides(
            paperId: paperId,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        let bands = pageTexture(
            paperId: paperId,
            style: NoteTemplate(paperId: paperId)?.pageStyle ?? .blank,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        return RuledWriting.horizontalRules(guides: guides, bands: bands)
    }

    /// 拖曳文字方塊時的吸附：讓第一行底部坐在最近的格線上（文字貼著格線上方、格線為底，絕不穿透重疊）。
    private func snapYToGuideLine(at y: CGFloat, page: Int? = nil) -> CGFloat {
        let rules = pageHorizontalRules(page: page)
        let fontSize: CGFloat = activeTextAttachment?.fontSize ?? 16
        let offset = RuledWriting.textBottomOffset(fontSize: fontSize)

        let targetBottom = y + offset
        if let nearest = rules.min(by: { abs($0 - targetBottom) < abs($1 - targetBottom) }), abs(nearest - targetBottom) < 50 {
            return max(PageGeometry.printableInset, nearest - offset)
        }
        // 沒有格線或離得遠：吸附至 20pt 步進網格。
        let step: CGFloat = 20.0
        return round(y / step) * step
    }

    /// - Parameter tapToWrite: 文字模式「隨點即書」。文字從點的地方開始；橫線紙上基準線坐在格線上，
    ///   一行一行對著格線寫；沒有框線、透明底，方塊會跟著內容長高。
    ///   `false` 是工具列「新增文字方塊」那一顆：有框線的獨立方塊。
    func insertTextBox(
        at location: CGPoint, page: Int? = nil, openStudio: Bool = false, tapToWrite: Bool = false
    ) -> NoteTextAttachment {
        let targetPage = page ?? currentPageIndex
        var targetX = location.x
        var targetY = location.y
        var tapPlacement: RuledWriting.Placement?
        // 新方塊沿用目前方塊的樣式；沒有目前方塊時，沿用使用者在工具列預先選好的樣式。
        let inheritedStyle = activeTextAttachment ?? pendingTypingStyle
        if tapToWrite {
            let baseSize: CGFloat = inheritedStyle.fontSize
            let minTop = PageGeometry.printableRect.minY
            if snapToGrid,
               let ruled = RuledWriting.placement(
                   tapY: location.y, rules: pageHorizontalRules(page: targetPage),
                   fontSize: baseSize, minTop: minTop) {
                tapPlacement = ruled
            } else {
                tapPlacement = RuledWriting.freePlacement(tapY: location.y, fontSize: baseSize, minTop: minTop)
            }
            targetY = tapPlacement?.top ?? targetY
            // 文字從點的地方開始：方塊左緣 = 點 − 內距。
            targetX = location.x - RuledWriting.padding
        } else if snapToGrid {
            let step: CGFloat = 20.0
            targetX = round(targetX / step) * step
            targetY = snapYToGuideLine(at: location.y)
        }
        let printable = PageGeometry.printableRect
        var startX = max(printable.minX, targetX)
        if tapToWrite {
            // 隨點即書：若點擊處過於靠右，留出合理輸入起點，避免文字方塊超出可視區域
            startX = min(startX, printable.maxX - 60)
        }
        let midX = PageGeometry.width / 2
        // 若在左右分欄或四象限結構的左半部，文字寬度以中線為界；否則延伸至右側可列印邊界
        let availWidth: CGFloat
        // 以中線為界只在左半邊還有像樣的寬度時才成立：點在中線左邊一點點時，
        // 界線會把方塊壓到幾十點寬，打一個英文字就折成兩行。
        if startX < midX - 30 && printable.maxX > midX && midX - startX - 12 >= 200 {
            availWidth = max(tapToWrite ? 60 : 180, midX - startX - 12)
        } else {
            availWidth = max(tapToWrite ? 60 : 180, printable.maxX - startX)
        }
        let tapHeight = RuledWriting.boxHeight(
            text: "", width: availWidth, fontSize: tapPlacement?.fontSize ?? inheritedStyle.fontSize, bold: inheritedStyle.isBold,
            lineSpacing: tapPlacement?.lineSpacing ?? 0)
        var draft = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: targetPage,
            text: "",
            fontSize: tapPlacement?.fontSize ?? inheritedStyle.fontSize,
            isBold: inheritedStyle.isBold,
            isItalic: inheritedStyle.isItalic,
            isUnderline: inheritedStyle.isUnderline,
            isStrikethrough: inheritedStyle.isStrikethrough,
            alignmentRaw: inheritedStyle.alignmentRaw,
            textColorHex: inheritedStyle.textColorHex,
            backgroundColorHex: "clear",
            hasBorder: !tapToWrite,
            x: startX,
            y: tapToWrite
                ? max(printable.minY - RuledWriting.padding, min(targetY, printable.maxY - tapHeight))
                : max(printable.minY, min(targetY, printable.maxY - 40)),
            width: availWidth,
            height: tapToWrite ? tapHeight : 40
        )
        draft.fontFamily = inheritedStyle.fontFamily
        if let placement = tapPlacement, placement.lineSpacing > 0 {
            draft.lineSpacing = placement.lineSpacing
        }
        recordTextUndoState()
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(draft)
        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: targetPage))
        order = ObjectStacking.bringToFront([draft.id], in: order)
        notebook.setObjectOrder(order, forPage: targetPage)

        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(draft),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        inlineEditingTextId = draft.id
        lastAddedTextId = draft.id
        if openStudio {
            editingTextId = draft.id
        } else {
            editingTextId = nil
        }
        return draft
    }

    /// 符號分類的語系鍵。與 Android 的 `categoryKey` 同一組。
    func symbolCategoryKey(_ category: FfiSymbolCategory) -> String {
        switch category {
        case .special: return "special_symbols"
        case .punctuation: return "punctuation_symbols"
        case .math: return "math_symbols"
        case .roman: return "roman_symbols"
        }
    }

    func insertQuickTextSnippet(_ text: String, onNewLine: Bool = false) {
        // 跟格式按鈕同一個目標（焦點被工具列借走時也找得到），不會插到別的方塊。
        if var target = activeTextAttachment {
            if onNewLine, !target.text.isEmpty, !target.text.hasSuffix("\n") {
                target.text.append("\n")
            }
            target.text.append(text)
            if onNewLine { target.text.append("\n") }
            applyToolbarTextChange(target)
            return
        }
        let style = pendingTypingStyle
        let newBox = NoteTextAttachment(
            pageIndex: currentPageIndex,
            text: text,
            fontSize: style.fontSize,
            isBold: style.isBold,
            isItalic: style.isItalic,
            isUnderline: style.isUnderline,
            isStrikethrough: style.isStrikethrough,
            alignmentRaw: style.alignmentRaw,
            textColorHex: style.textColorHex,
            hasBorder: true,
            x: PageGeometry.printableInset,
            y: 200,
            width: 260,
            height: 64
        )
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(newBox)
        inlineEditingTextId = newBox.id
        editingTextId = newBox.id
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    /// 將算式以可編輯的文字方塊插入畫布（使用者可隨意修改、縮放、變更字型顏色及刪除）
    private func insertFormulaText(_ text: String) {
        let printable = PageGeometry.printableRect
        let availWidth: CGFloat = min(360, printable.width - 40)
        let fontSize: CGFloat = 18
        let calculatedHeight = max(52, RuledWriting.boxHeight(
            text: text,
            width: availWidth,
            fontSize: fontSize,
            bold: false,
            lineSpacing: 0
        ))
        let targetX = printable.minX + 24
        let targetY = max(printable.minY + 20, min(180, printable.maxY - calculatedHeight - 20))

        let mathBox = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: currentPageIndex,
            text: text,
            fontSize: fontSize,
            isBold: false,
            textColorHex: "#000000",
            backgroundColorHex: "#F8F9FA",
            hasBorder: true,
            cornerRadius: 10,
            x: targetX,
            y: targetY,
            width: availWidth,
            height: calculatedHeight
        )

        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(mathBox)

        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        order = ObjectStacking.bringToFront([mathBox.id], in: order)
        notebook.setObjectOrder(order, forPage: currentPageIndex)

        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(mathBox),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        transitionToMode(.type)
        DispatchQueue.main.async {
            inlineEditingTextId = mathBox.id
            editingTextId = mathBox.id
        }
    }

    /// 將語音辨識/轉錄出的文字稿作為「隨點即書」自然排版文字插入在錄音卡片周遭，
    /// 無框線、無預設灰底，高度隨內容自動伸縮，並切換至打字模式進入就地編輯以供後續編修。
    private func insertTranscriptText(_ text: String, for audio: NoteAudioAttachment) {
        let printable = PageGeometry.printableRect
        let startX = max(printable.minX, audio.x)
        let midX = PageGeometry.width / 2
        let availWidth: CGFloat
        if startX < midX - 30 && printable.maxX > midX {
            availWidth = max(180, midX - startX - 12)
        } else {
            availWidth = max(180, printable.maxX - startX)
        }

        let baseFontSize: CGFloat = activeTextAttachment?.fontSize ?? 16
        let calculatedHeight = RuledWriting.boxHeight(
            text: text,
            width: availWidth,
            fontSize: baseFontSize,
            bold: false,
            lineSpacing: 0
        )
        let targetY = max(printable.minY, min(audio.y + audio.height + 16, printable.maxY - calculatedHeight))
        let existingId = audio.transcriptTextId
        let existingIndex = notebook.textAttachments?.firstIndex(where: { $0.id == existingId })

        let transcriptBox: NoteTextAttachment
        if let idx = existingIndex, var existing = notebook.textAttachments?[idx] {
            existing.text = text
            existing.height = RuledWriting.boxHeight(
                text: text,
                width: existing.width,
                fontSize: existing.fontSize,
                bold: existing.isBold,
                lineSpacing: existing.lineSpacing ?? 0
            )
            notebook.textAttachments?[idx] = existing
            transcriptBox = existing
        } else {
            let newBox = NoteTextAttachment(
                id: existingId ?? UUID().uuidString,
                pageIndex: audio.pageIndex,
                text: text,
                fontSize: baseFontSize,
                isBold: false,
                textColorHex: activeTextAttachment?.textColorHex ?? "#000000",
                backgroundColorHex: "clear",
                hasBorder: false,
                x: startX,
                y: targetY,
                width: availWidth,
                height: calculatedHeight
            )
            if notebook.textAttachments == nil {
                notebook.textAttachments = []
            }
            notebook.textAttachments?.append(newBox)
            if let aIdx = notebook.audioAttachments?.firstIndex(where: { $0.id == audio.id }) {
                notebook.audioAttachments?[aIdx].transcriptTextId = newBox.id
            }
            transcriptBox = newBox
        }

        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: audio.pageIndex))
        order = ObjectStacking.bringToFront([transcriptBox.id], in: order)
        notebook.setObjectOrder(order, forPage: audio.pageIndex)

        // 確保轉錄文字預設位於筆跡上方（前景層）
        var under = notebook.underInkObjectIds(forPage: audio.pageIndex)
        if under.contains(transcriptBox.id) {
            under.remove(transcriptBox.id)
            notebook.setUnderInkObjectIds(under, forPage: audio.pageIndex)
        }

        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(transcriptBox),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        transitionToMode(.type)
        activeSelectedObjectId = transcriptBox.id
        selectedObjectIds = [transcriptBox.id]
        // 文字框先進入視圖樹，再要求就地編輯。和同一個動畫 transaction 一起
        // 設定時，FocusState 偶爾會早於 TextField 建立，鍵盤便時有時無。
        DispatchQueue.main.async {
            inlineEditingTextId = transcriptBox.id
        }
    }

    func formatTime(seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - 附件管理核心
    /// 把一張圖插到頁面上。
    ///
    /// - Parameters:
    ///   - at: 拖放的落點（頁面座標）。`nil` 表示從選單插入 —— 沿用固定位置。
    ///   - page: 落在哪一頁。連續模式下拖到哪一頁就是哪一頁，`nil` 用焦點頁。
    private func insertImageAttachment(
        _ image: UIImage,
        chartSpecJSON: String? = nil,
        mathFormula: String? = nil,
        at dropPoint: CGPoint? = nil,
        page: Int? = nil
    ) {
        guard let fileName = store.saveAttachmentImage(image) else { return }
        let aspect = image.size.width / max(1, image.size.height)
        let placed = dropPoint.map {
            ImageDropPlacement.frame(
                dropPoint: $0,
                imageSize: image.size,
                pageSize: CGSize(width: PageGeometry.width, height: PageGeometry.height))
        }
        let w: CGFloat = placed?.width ?? 280
        let h: CGFloat = placed?.height ?? max(80, 280 / aspect)
        let newAttachment = NoteImageAttachment(
            fileName: fileName,
            pageIndex: page ?? currentPageIndex,
            x: placed?.minX ?? 80,
            y: placed?.minY ?? 120,
            width: w,
            height: h,
            rotationDegrees: 0,
            cornerRadius: 8,
            hasShadow: true,
            hasBorder: false,
            filterStyle: .original,
            chartSpecJSON: chartSpecJSON,
            mathFormula: mathFormula
        )
        if notebook.attachments == nil {
            notebook.attachments = []
        }
        notebook.attachments?.append(newAttachment)
        commitNotebook()
        if var dict = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(newAttachment))) as? [String: Any] {
            if let imgData = image.pngData() {
                dict["image_base64"] = imgData.base64EncodedString()
            }
            collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
        }
    }

    /// 從系統剪貼簿讀取圖片（含螢幕截圖、剪下／拷貝的圖片、或是剪貼簿裡的原始圖檔資料）。
    private func getClipboardImage() -> UIImage? {
        if let image = UIPasteboard.general.image {
            return image
        }
        if let images = UIPasteboard.general.images, let first = images.first {
            return first
        }
        let supportedTypes = [
            "public.png",
            "public.jpeg",
            "public.tiff",
            "com.compuserve.gif",
            "public.image"
        ]
        for type in supportedTypes {
            if let data = UIPasteboard.general.data(forPasteboardType: type),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }

    /// 貼上螢幕截圖或剪貼簿中的圖片到目前畫布。
    @discardableResult
    func pasteScreenshotOrClipboardImage() -> Bool {
        if let image = getClipboardImage() {
            insertImageAttachment(image)
            showNoticeToast(name: localizationManager.localized("screenshot_pasted"), icon: "checkmark.circle.fill")
            return true
        } else {
            showNoticeToast(name: localizationManager.localized("clipboard_no_image"), icon: "exclamationmark.triangle.fill")
            return false
        }
    }

    private func showNoticeToast(name: String, icon: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            activeToolToast = (name: name, icon: icon)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.15)) {
                if self.activeToolToast?.name == name {
                    self.activeToolToast = nil
                }
            }
        }
    }

    /// 「匯入文件」：把檔案解析成原生物件，合併進**這本筆記**的目前頁面。
    ///
    /// 解析在暫存套件裡由核心做（見 `DocumentImport`）；這裡負責合併：
    /// 超出頁高的內容接到後面新插入的頁面，不覆蓋既有頁面。失敗一律給提示 ——
    /// 舊版只 `print`，使用者看到的是「點了沒反應」。
    private func importDocumentOutcome(_ outcome: FileImport.Outcome) {
        if outcome.fileExtension == "pptx" {
            importErrorKey = "import_unsupported_type"
            return
        }
        let url = store.importedFileURL(fileName: outcome.storedName)
        let imported: NotebookPackageBridge.ImportedNotebook
        do {
            imported = try DocumentImport.parse(fileURL: url, title: outcome.displayName)
        } catch DocumentImport.Failure.empty {
            importErrorKey = "import_empty_file"
            return
        } catch {
            importErrorKey = "import_failed_read"
            return
        }

        let base = currentPageIndex
        let doc = imported.document

        // 區塊依 id（UUIDv7 ＝ 建立順序）排回文件順序，再由上往下排版 ——
        // 核心建立區塊時沒有給位置，全部會落在同一點疊成一團。
        enum Piece { case text(Int), table(Int), image(Int) }
        var texts = doc.textAttachments ?? []
        var tables = doc.tableAttachments ?? []
        var images = doc.attachments ?? []
        var pieces: [(id: String, piece: Piece)] = []
        for (i, t) in texts.enumerated() { pieces.append((t.id, .text(i))) }
        for (i, t) in tables.enumerated() { pieces.append((t.id, .table(i))) }
        for (i, t) in images.enumerated() { pieces.append((t.id, .image(i))) }
        // 依建立時間（UUIDv7 前 48 位元的毫秒時間戳）排回文件順序。**不能比整個 id** ——
        // 同一毫秒內產生的 id 後面是隨機位元，字串順序跟建立順序無關。同一毫秒（匯入時
        // 一股腦建出來，常態）維持各自在核心裡原本的順序。
        pieces = pieces.enumerated().sorted { lhs, rhs in
            let l = DocumentImport.timestampKey(lhs.element.id), r = DocumentImport.timestampKey(rhs.element.id)
            return l != r ? l < r : lhs.offset < rhs.offset
        }.map(\.element)

        let contentWidth = PageGeometry.width - PageGeometry.printableInset * 2
        let heights: [CGFloat] = pieces.map { entry in
            switch entry.piece {
            case .text(let i):
                texts[i].width = contentWidth
                texts[i].x = PageGeometry.printableInset
                let h = DocumentImport.estimatedHeight(
                    text: texts[i].text, fontSize: texts[i].fontSize, width: contentWidth)
                texts[i].height = h
                return h
            case .table(let i):
                tables[i].x = PageGeometry.printableInset
                return tables[i].height
            case .image(let i):
                // 圖片寬度不超過內容區；等比縮小。
                if images[i].width > contentWidth {
                    let scale = contentWidth / images[i].width
                    images[i].width = contentWidth
                    images[i].height *= scale
                }
                images[i].x = PageGeometry.printableInset
                return images[i].height
            }
        }
        let placements = DocumentImport.flow(heights: heights)
        var maxOffset = 0
        for (entry, place) in zip(pieces, placements) {
            maxOffset = max(maxOffset, place.pageOffset)
            switch entry.piece {
            case .text(let i): texts[i].y = place.y; texts[i].pageIndex = place.pageOffset
            case .table(let i): tables[i].y = place.y; tables[i].pageIndex = place.pageOffset
            case .image(let i): images[i].y = place.y; images[i].pageIndex = place.pageOffset
            }
        }
        // 新頁插在目前這一頁後面：走頁面結構變動的共用流程（等背景寫入落盤、頁碼暫存與畫布跟著對齊）。
        let insertedPages = maxOffset
        changePageStructure(pageMap: { $0 > base ? $0 + insertedPages : $0 }) {
            for k in 0..<maxOffset {
                _ = store.insertPage(
                    notebookId: notebook.id, afterIndex: base + k,
                    paperId: notebook.paperId(forPage: base))
            }
            if maxOffset > 0, let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
                notebook = updated
            }

            // id 沿用暫存套件給的：每次匯入都是全新的暫存套件，所以同一個檔案
            // 匯入兩次得到的是兩份獨立的物件，不會撞 id。
            for var item in texts {
                item.pageIndex = base + item.pageIndex
                notebook.textAttachments = (notebook.textAttachments ?? []) + [item]
            }
            for var item in tables {
                item.pageIndex = base + item.pageIndex
                notebook.tableAttachments = (notebook.tableAttachments ?? []) + [item]
            }
            for var item in images {
                guard let bytes = imported.imageData[item.fileName],
                      let saved = store.saveImportedFile(data: bytes, extension: "png") else { continue }
                item.fileName = saved
                item.pageIndex = base + item.pageIndex
                notebook.attachments = (notebook.attachments ?? []) + [item]
            }
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
            showCanvasNotice(localizationManager.localized("import_document_done"))
            return base
        }
    }

    /// 把一段既有的錄音插到目前這一頁。
    ///
    /// 位置逐張往右下錯開。全部疊在同一點的話，插第二張時使用者會以為沒插進去。
    /// 匯入的音訊檔變成一張跟自己錄的完全一樣的卡片。
    ///
    /// **它會被登記成一段真正的錄音**（`addRecording`），而不是另一種
    /// 只在這一頁存在的附件。理由是使用者接下來會做的每一件事 ——
    /// 播放、在「最近錄音」找它、讓它跟著筆記本同步到另一台裝置 ——
    /// 走的都是錄音那條路；自成一格的話，那些全部要再實作一次，
    /// 而漏掉的那一項會變成「這張卡片按了沒反應」。
    private func insertImportedAudio(_ outcome: FileImport.Outcome) {
        // 長度走核心算（S-42）。各平台問各自的系統 API 的話，
        // 同一個檔案在兩台裝置上會顯示不同的秒數。
        let url = store.recordingFileURL(fileName: outcome.storedName, notebookId: nil)
        let seconds = (try? Data(contentsOf: url)).map {
            Int(audioDurationSeconds(bytes: $0))
        } ?? 0
        let rec = store.addRecording(
            title: outcome.displayName,
            durationSeconds: seconds,
            fileName: outcome.storedName,
            linkedNotebookId: notebook.id
        )
        insertAudioAttachment(rec)
    }

    private func insertAudioAttachment(_ recording: AudioRecordingRecord) {
        let existing = (notebook.audioAttachments ?? []).filter { $0.pageIndex == currentPageIndex }.count
        let offset = CGFloat(existing % 6) * 18
        let attachment = NoteAudioAttachment(
            pageIndex: currentPageIndex,
            recordingId: recording.id,
            fileName: recording.fileName,
            title: recording.title,
            durationSeconds: recording.durationSeconds,
            x: 80 + offset,
            y: 120 + offset
        )
        if notebook.audioAttachments == nil {
            notebook.audioAttachments = []
        }
        notebook.audioAttachments?.append(attachment)
        // 這本筆記從此「有錄音」—— 首頁的錄音篩選要看得到它。
        notebook.hasRecording = true
        commitNotebook()
    }

    /// 用新算出來的圖表取代原本那一張。
    ///
    /// 位置、尺寸、邊框、濾鏡全部原地保留 —— 使用者只是改了裡面的數字，
    /// 圖不該跳回預設大小、跑回左上角。
    private func replaceChartAttachment(id: String, spec: ChartSpec, image: UIImage) {
        guard let index = notebook.attachments?.firstIndex(where: { $0.id == id }),
              let fileName = store.saveAttachmentImage(image) else { return }
        notebook.attachments?[index].fileName = fileName
        notebook.attachments?[index].chartSpecJSON = spec.encodedJSON()
        commitNotebook()
        editingChartAttachmentId = nil
    }

    /// 用新算出來的算式卡片取代原本那一張。
    /// 若轉成文字方塊（image == nil），則從附件移除卡片。
    private func replaceMathAttachment(id: String, formula: String, image: UIImage?) {
        guard let index = notebook.attachments?.firstIndex(where: { $0.id == id }) else {
            editingMathAttachmentId = nil
            return
        }
        if let image = image, let fileName = store.saveAttachmentImage(image) {
            notebook.attachments?[index].fileName = fileName
            notebook.attachments?[index].mathFormula = formula
        } else {
            // 使用者選擇轉插入為可編輯文字方塊
            notebook.attachments?.remove(at: index)
        }
        commitNotebook()
        editingMathAttachmentId = nil
    }

    /// 目前這一頁的形狀，依堆疊順序。
    private var pageShapes: [NoteShapeAttachment] {
        (notebook.shapeAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
    }

    // MARK: - 形狀與連接線的編修

    /// 刪除一個形狀，連著它的線一起走。
    ///
    /// 留著的話會指向一個不存在的形狀，畫面上是一條從空氣連出來的線。
    private func deleteShape(_ id: String) {
        notebook.shapeAttachments?.removeAll { $0.id == id }
        notebook.connectionAttachments?.removeAll { $0.fromShapeId == id || $0.toShapeId == id }
        selectedShapeIds.remove(id)
        if editingShapeId == id { editingShapeId = nil }
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    private func deleteConnection(_ id: String) {
        notebook.connectionAttachments?.removeAll { $0.id == id }
        if selectedConnectionId == id { selectedConnectionId = nil }
        if editingConnectionId == id { editingConnectionId = nil }
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    private func duplicateShape(_ id: String) {
        guard var copy = notebook.shapeAttachments?.first(where: { $0.id == id }) else { return }
        var fresh = NoteShapeAttachment(
            pageIndex: copy.pageIndex, kindName: copy.kindName,
            x: copy.x + 24, y: copy.y + 24, width: copy.width, height: copy.height,
            cornerRadius: copy.cornerRadius, label: copy.label,
            strokeColorHex: copy.strokeColorHex, fillColorHex: copy.fillColorHex,
            lineWidth: copy.lineWidth)
        copy.groupId = nil
        fresh.rotationDegrees = copy.rotationDegrees
        fresh.dashStyle = copy.dashStyle; fresh.fontSize = copy.fontSize
        fresh.textColorHex = copy.textColorHex; fresh.isBold = copy.isBold
        fresh.isItalic = copy.isItalic; fresh.opacity = copy.opacity
        notebook.shapeAttachments = (notebook.shapeAttachments ?? []) + [fresh]
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        selectedShapeIds = [fresh.id]
        editingShapeId = fresh.id
    }

    private func connectionBinding(for id: String) -> Binding<NoteConnectionAttachment> {
        let normId = id.lowercased()
        return Binding(
            get: {
                notebook.connectionAttachments?.first(where: { $0.id.lowercased() == normId })
                    ?? NoteConnectionAttachment(id: id, fromShapeId: "", toShapeId: "")
            },
            set: { updated in
                guard let index = notebook.connectionAttachments?
                    .firstIndex(where: { $0.id.lowercased() == normId }) else { return }
                notebook.connectionAttachments?[index] = updated
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        )
    }

    /// 從形狀的連接點拉線。拖曳中畫預覽，放開時連到底下的形狀。
    private func handleConnectDrag(
        from sourceId: String, anchor: ShapeAnchorName,
        start: CGPoint, current: CGPoint, finished: Bool
    ) {
        guard let source = notebook.shapeAttachments?.first(where: { $0.id == sourceId }) else { return }
        guard finished else {
            connectionDraft = (source.pageIndex, start, current)
            return
        }
        connectionDraft = nil

        // 放開的位置在哪個形狀上。越晚畫的越在上面，所以從後往前找。
        let pageShapes = (notebook.shapeAttachments ?? []).filter {
            $0.pageIndex == source.pageIndex && $0.id != sourceId && !$0.isLinear
        }
        let target = pageShapes.reversed().first { candidate in
            // 轉過的形狀：把點轉回形狀自己的座標軸再判斷，才不會在轉 45° 的方塊邊角誤判。
            let local = ShapeFrameMath.rotate(current, about: candidate.center, degrees: -candidate.canvasRotation)
            return CGRect(x: candidate.x, y: candidate.y, width: candidate.width, height: candidate.height)
                .insetBy(dx: -6, dy: -6).contains(local)
        }
        guard let target else { return }
        // 入線位置：目標形狀上離放開點最近的連接點。
        let toAnchor = ShapeAnchorName.allCases.min {
            let a = target.anchorPoint($0), b = target.anchorPoint($1)
            return hypot(a.x - current.x, a.y - current.y) < hypot(b.x - current.x, b.y - current.y)
        } ?? .top

        var connection = NoteConnectionAttachment(
            pageIndex: source.pageIndex, fromShapeId: sourceId, toShapeId: target.id)
        connection.fromAnchor = anchor.rawValue
        connection.toAnchor = toAnchor.rawValue
        notebook.connectionAttachments = (notebook.connectionAttachments ?? []) + [connection]
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        selectedShapeIds = []
        selectedConnectionId = connection.id
        if let data = try? JSONEncoder().encode(connection),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "connection", itemDict: dict)
        }
    }


    /// 對齊目前選取的物件。
    ///
    /// 幾何交給核心；這裡只負責「哪個 id 是哪個附件」與把新座標寫回去。
    /// id 由圖層面板給 —— 它才是多選發生的地方。
    /// 七種型別各有自己的陣列，所以搬移得逐型別處理 —— 但**順序必須與
    /// 傳給核心的矩形順序一致**，錯位的話每個物件會搬到別人的位置。
    private func alignSelectedObjects(_ mode: FfiAlignMode, ids: [String]) {
        guard ids.count >= 2 else { return }

        // 收集矩形，順序即 ids 的順序。
        var rects: [CGRect] = []
        for id in ids {
            guard let rect = frameOfObject(id: id) else { return }
            rects.append(rect)
        }

        let origins = ObjectAlignment.aligned(rects: rects, mode: mode)
        guard origins.count == ids.count else { return }
        for (id, origin) in zip(ids, origins) {
            moveObject(id: id, to: origin)
        }
        commitNotebook()
    }

    /// 某個物件目前的版面框（頁面座標）。
    private func frameOfObject(id: String) -> CGRect? {
        let norm = id.lowercased()
        if let i = notebook.attachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.shapeAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.tableAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.textAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.linkAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.model3DAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.audioAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        return nil
    }

    /// 把某個物件的左上角搬到指定座標（並夾回可列印區域，S-85）。
    private func moveObject(id: String, to rawOrigin: CGPoint) {
        let size = frameOfObject(id: id)?.size ?? .zero
        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)
        let clamped = clampToPrintable(
            rect: FfiRect(
                minX: Float(rawOrigin.x), minY: Float(rawOrigin.y),
                maxX: Float(rawOrigin.x + size.width), maxY: Float(rawOrigin.y + size.height)),
            pageWidth: Float(page.width), pageHeight: Float(page.height), inset: inset)
        let origin = CGPoint(x: CGFloat(clamped.minX), y: CGFloat(clamped.minY))
        let norm = id.lowercased()

        if let index = notebook.attachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.attachments?[index].x = origin.x
            notebook.attachments?[index].y = origin.y
            return
        }
        if let index = notebook.shapeAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.shapeAttachments?[index].x = origin.x
            notebook.shapeAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.tableAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.tableAttachments?[index].x = origin.x
            notebook.tableAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.textAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.textAttachments?[index].x = origin.x
            notebook.textAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.linkAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.linkAttachments?[index].x = origin.x
            notebook.linkAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.model3DAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.model3DAttachments?[index].x = origin.x
            notebook.model3DAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.audioAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.audioAttachments?[index].x = origin.x
            notebook.audioAttachments?[index].y = origin.y
        }
    }

    // MARK: - 框選

    /// 這一頁上每一個物件的位置與大小，給框選判定用。依堆疊順序由下到上排，
    /// 點選時才拿得到最上面那一個。
    private var marqueeCandidates: [MarqueeHit] {
        marqueeCandidates(forPage: currentPageIndex)
    }

    private func marqueeCandidates(forPage page: Int) -> [MarqueeHit] {
        let stacking = ObjectStacking.Lookup(order: notebook.objectOrder(forPage: page))
        let lockedIds = notebook.allLockedObjectIds
        return stackableObjects(forPage: page).compactMap { object -> MarqueeHit? in
            // 別人正在編輯的物件不能被框選帶著一起搬、一起刪（設計 §5.2）。
            // 鎖定在畫布上的物件也不框：框選帶著它一起搬，就不叫鎖定了。
            guard collaborationManager.leaseHolder(for: object.id) == nil,
                  !lockedIds.contains(object.id),
                  let frame = frameOfObject(id: object.id) else { return nil }
            return MarqueeHit(id: object.id, kind: object.kind, frame: frame)
        }
        .sorted { stacking.zIndex(for: $0.id, kind: $0.kind) < stacking.zIndex(for: $1.id, kind: $1.kind) }
    }

    /// 框選層：拉框、顯示選取外框、整組拖曳（支援單頁模式與連續頁面模式）。
    private func marqueeLayer(forPage page: Int) -> some View {
        let candidates = marqueeCandidates(forPage: page)
        let selectionBounds = ObjectMarquee.bounds(of: selectedObjectIds, among: candidates)
        return ZStack(alignment: .topLeading) {
            // 這一層要吃掉觸控 —— 框選模式下畫布不捲、物件不動，
            // 只剩框選這一件事（見 ObjectMarquee 開頭的說明）。
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2,
                                coordinateSpace: .named(CanvasCoordinateSpace.name))
                        .onChanged { value in
                            if pageDisplayMode == .continuous { focusContinuousPage(page) }
                            if let bounds = selectionBounds,
                               bounds.contains(value.startLocation) {
                                // 從選取範圍裡面開始拖＝搬整組。
                                groupDragOffset = value.translation
                            } else {
                                if marqueeStart == nil { marqueeStart = value.startLocation }
                                marqueeCurrent = value.location
                            }
                        }
                        .onEnded { value in
                            if groupDragOffset != .zero {
                                moveSelection(by: groupDragOffset)
                                groupDragOffset = .zero
                            } else if let start = marqueeStart {
                                let rect = ObjectMarquee.rect(from: start, to: value.location)
                                selectedObjectIds = ObjectMarquee.combined(
                                    selectedObjectIds,
                                    with: ObjectMarquee.hits(in: rect, among: candidates),
                                    additive: marqueeAdditive)
                            }
                            marqueeStart = nil
                            marqueeCurrent = nil
                        }
                )
                // 點物件＝選它（連續框選時切換加入／移除）；點空白＝取消選取（連續框選時保留）。
                .simultaneousGesture(
                    SpatialTapGesture(coordinateSpace: .named(CanvasCoordinateSpace.name))
                        .onEnded { value in
                            if pageDisplayMode == .continuous { focusContinuousPage(page) }
                            selectedObjectIds = ObjectMarquee.tapped(
                                ObjectMarquee.topmostHit(at: value.location, among: candidates),
                                existing: selectedObjectIds,
                                additive: marqueeAdditive)
                        }
                )

            // 每個被選中的物件畫一個外框。只畫一個大框的話，
            // 使用者看不出「到底選到了哪幾個」。
            ForEach(candidates.filter { selectedObjectIds.contains($0.id) }, id: \.id) { hit in
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: hit.frame.width, height: hit.frame.height)
                    .offset(x: hit.frame.minX + groupDragOffset.width,
                            y: hit.frame.minY + groupDragOffset.height)
                    .allowsHitTesting(false)
            }

            // 拉框中的橡皮筋
            if page == currentPageIndex, let start = marqueeStart, let current = marqueeCurrent {
                let rect = ObjectMarquee.rect(from: start, to: current)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.10))
                    .overlay(Rectangle().stroke(Color.accentColor, style: StrokeStyle(
                        lineWidth: 1, dash: [4, 3])))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 進入／離開框選。
    ///
    /// # 框選選的是「物件」，不是筆跡
    ///
    /// 圖片、貼紙、文字方塊、表格、圖形、錄音卡片…這些是物件，框選一次可以整組
    /// 搬、複製、刪除。手寫的筆跡不是物件，要選它們用**套索**（手寫模式的筆具列）。
    /// 兩者分工：物件用框選、筆跡用套索。
    ///
    /// 手寫模式下物件本來就不吃觸控，框了也動不了，所以進入時自動切到打字模式
    /// （Android 一直是這樣做）。進入時說明怎麼操作，否則使用者面對一個空的選取列，
    /// 不知道下一步是什麼。
    func setMarqueeActive(_ on: Bool) {
        isMarqueeActive = on
        if on {
            transitionToMode(.type)
            showCanvasNotice(localizationManager.localized("marquee_hint"))
        } else {
            selectedObjectIds = []
            marqueeAdditive = false
        }
    }

    /// 框選模式的工具列。掛在畫布外面（工具列那一層），不隨畫布捲動 ——
    /// 跟著捲的話，選了下半頁的東西就得捲回去才按得到刪除。
    var marqueeToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.dashed.inset.filled")
                .foregroundColor(.accentColor)
            if selectedObjectIds.isEmpty && isCompactEditorWidth {
                // 手機寬度不放說明句：它會把整排按鈕擠到畫面外（進入框選時已用浮動提示說過一次）。
                EmptyView()
            } else if selectedObjectIds.isEmpty {
                // 還沒選到東西時，顯示「怎麼選」而不是「已選 0 個」。
                Text(localizationManager.localized("marquee_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text(localizationManager.localized("marquee_selected")
                    .replacingOccurrences(of: "%@", with: "\(selectedObjectIds.count)"))
                    .font(.caption)
                    .monospacedDigit()
            }

            Divider().frame(height: 18)

            // 連續框選：一框一框累積，或點物件逐一加入／移除。
            Button {
                marqueeAdditive.toggle()
                if marqueeAdditive { showCanvasNotice(localizationManager.localized("marquee_continuous_hint")) }
            } label: {
                Label(localizationManager.localized("marquee_continuous"),
                      systemImage: marqueeAdditive ? "plus.square.fill.on.square.fill" : "plus.square.on.square")
            }
            .foregroundColor(marqueeAdditive ? .accentColor : .primary)
            .accessibilityIdentifier("editor.marquee.continuous")
            .accessibilityLabel(localizationManager.localized("marquee_continuous"))
            .accessibilityAddTraits(marqueeAdditive ? .isSelected : [])
            .help(localizationManager.localized("marquee_continuous_hint"))

            // 全選：這一頁所有物件一次選起來。
            Button {
                selectedObjectIds = Set(marqueeCandidates.map(\.id))
            } label: {
                Label(localizationManager.localized("select_all"), systemImage: "checkmark.square")
            }
            .disabled(marqueeCandidates.isEmpty)
            .accessibilityIdentifier("editor.marquee.select_all")

            Button {
                selectedObjectIds = []
            } label: {
                Label(localizationManager.localized("deselect_all"), systemImage: "square")
            }
            .disabled(selectedObjectIds.isEmpty)
            .accessibilityIdentifier("editor.marquee.deselect_all")

            Divider().frame(height: 18)

            Button {
                cutSelection()
            } label: {
                Label(localizationManager.localized("action_cut"), systemImage: "scissors")
            }
            .disabled(selectedObjectIds.isEmpty)
            .accessibilityIdentifier("editor.marquee.cut")

            Button {
                copySelection()
            } label: {
                Label(localizationManager.localized("action_copy"), systemImage: "doc.on.doc")
            }
            .disabled(selectedObjectIds.isEmpty)

            Button {
                pasteClipboard()
            } label: {
                Label(localizationManager.localized("action_paste"), systemImage: "doc.on.clipboard")
            }
            .disabled(objectClipboard.isEmpty && getClipboardImage() == nil)

            Button {
                isPlacingPasteObject = true
            } label: {
                Label(localizationManager.localized("paste_at_location"), systemImage: "hand.point.up.left.fill")
            }
            .disabled(objectClipboard.isEmpty)
            .accessibilityIdentifier("editor.marquee.paste_at_location")

            Button {
                duplicateSelection()
            } label: {
                Label(localizationManager.localized("action_duplicate"), systemImage: "plus.square.on.square")
            }
            .disabled(selectedObjectIds.isEmpty)

            Button(role: .destructive) {
                deleteSelection()
            } label: {
                Label(localizationManager.localized("action_delete"), systemImage: "trash")
            }
            .disabled(selectedObjectIds.isEmpty)

            Divider().frame(height: 18)

            Button {
                setMarqueeActive(false)
            } label: {
                Label(localizationManager.localized("done"), systemImage: "checkmark")
            }
        }
        .font(.caption)
        // 手機寬度只放圖示（名稱仍是無障礙標籤），一排放得下全部的動作。
        .labelStyle(MarqueeLabelStyle(compact: isCompactEditorWidth))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    // MARK: - 框選與單一物件剪貼簿批次操作

    @ViewBuilder
    private var editorKeyboardShortcuts: some View {
        Group {
            Button("") {
                if !effectiveSelectedObjectIds.isEmpty && inlineEditingTextId == nil {
                    deleteSelection()
                } else {
                    deleteSelectedStrokes()
                }
            }
            .keyboardShortcut(.delete, modifiers: [])

            Button("") {
                if !effectiveSelectedObjectIds.isEmpty && inlineEditingTextId == nil {
                    deleteSelection()
                } else {
                    deleteSelectedStrokes()
                }
            }
            .keyboardShortcut(.deleteForward, modifiers: [])

            Button("") {
                guard inlineEditingTextId == nil else { return }
                if selectedTool == .lasso && lasso.hasSelection {
                    cutSelectedStrokes()
                } else if !effectiveSelectedObjectIds.isEmpty {
                    cutSelection()
                }
            }
            .keyboardShortcut("x", modifiers: .command)

            Button("") {
                guard inlineEditingTextId == nil else { return }
                if selectedTool == .lasso && lasso.hasSelection {
                    copySelectedStrokes()
                } else if !effectiveSelectedObjectIds.isEmpty {
                    copySelection()
                }
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("") {
                pasteClipboard()
            }
            .keyboardShortcut("v", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    /// 目前被選取的物件 ID 集合（涵蓋框選、多選形狀、單點選取或開啟屬性面板的物件）。
    var effectiveSelectedObjectIds: Set<String> {
        if !selectedObjectIds.isEmpty { return selectedObjectIds }
        if !selectedShapeIds.isEmpty { return selectedShapeIds }
        if let active = activeSelectedObjectId { return [active] }
        if let table = editingTable { return [table.id] }
        if let shapeId = editingShapeId { return [shapeId] }
        if let attId = editingAttachmentId { return [attId] }
        if let textId = editingTextId { return [textId] }
        return []
    }

    /// 供所有物件右鍵／長按選單與屬性面板使用的剪下、複製、建立副本動作。
    private var objectClipboardActions: ObjectClipboardActions {
        ObjectClipboardActions(
            cut: { id in cutObject(id: id) },
            copy: { id in copyObject(id: id) },
            duplicate: { id in duplicateObject(id: id) }
        )
    }

    private func moveSelection(by delta: CGSize) {
        guard !selectedObjectIds.isEmpty, delta != .zero else { return }
        for id in selectedObjectIds {
            guard let frame = frameOfObject(id: id) else { continue }
            moveObject(id: id, to: CGPoint(x: frame.minX + delta.width,
                                           y: frame.minY + delta.height))
        }
        commitNotebook()
        continuousObjectGeneration += 1
    }

    func copySelection() {
        let ids = effectiveSelectedObjectIds
        guard !ids.isEmpty else { return }
        objectClipboard = ids.compactMap(clipboardObject(forId:))
        isPlacingPasteObject = false
        showCanvasNotice(localizationManager.localized("object_copied_hint"))
    }

    func cutSelection() {
        let ids = effectiveSelectedObjectIds
        guard !ids.isEmpty else { return }
        objectClipboard = ids.compactMap(clipboardObject(forId:))
        isPlacingPasteObject = false
        deleteObjects(ids: ids)
        showCanvasNotice(localizationManager.localized("object_cut_hint"))
    }

    private func copyObject(id: String) {
        if selectedObjectIds.contains(id) && selectedObjectIds.count > 1 {
            copySelection()
            return
        }
        guard let obj = clipboardObject(forId: id) else { return }
        objectClipboard = [obj]
        isPlacingPasteObject = false
        showCanvasNotice(localizationManager.localized("object_copied_hint"))
    }

    private func cutObject(id: String) {
        if selectedObjectIds.contains(id) && selectedObjectIds.count > 1 {
            cutSelection()
            return
        }
        guard let obj = clipboardObject(forId: id) else { return }
        objectClipboard = [obj]
        isPlacingPasteObject = false
        deleteObjects(ids: [id])
        showCanvasNotice(localizationManager.localized("object_cut_hint"))
    }

    private func duplicateObject(id: String) {
        if selectedObjectIds.contains(id) && selectedObjectIds.count > 1 {
            duplicateSelection()
            return
        }
        guard let obj = clipboardObject(forId: id) else { return }
        let targetPage = pageOfObject(id) ?? currentPageIndex
        paste([obj], onPage: targetPage, at: nil)
    }

    private func duplicateSelection() {
        let ids = effectiveSelectedObjectIds
        let copies = ids.compactMap(clipboardObject(forId:))
        paste(copies, onPage: currentPageIndex, at: nil)
    }

    private func pasteClipboard() {
        if selectedTool == .lasso && lasso.canPaste {
            pasteStrokes()
        } else if !objectClipboard.isEmpty {
            paste(objectClipboard, onPage: currentPageIndex, at: nil)
        } else if let image = getClipboardImage() {
            insertImageAttachment(image)
            showNoticeToast(name: localizationManager.localized("screenshot_pasted"), icon: "checkmark.circle.fill")
        }
    }

    /// 貼上一組物件到指定頁面與指定座標（`targetPoint == nil` 為預設偏移貼上，有值則將物件中心對齊該座標）。
    /// **每一個都給新的 id** —— 沿用原 id 的話，兩份物件會共用同一筆資料，拖其中一個另一個也會跟著動。
    func paste(
        _ objects: [ClipboardObject],
        onPage targetPage: Int? = nil,
        at targetPoint: CGPoint? = nil
    ) {
        guard !objects.isEmpty else { return }
        let page = targetPage ?? currentPageIndex
        let instantiated = ObjectMarquee.pasted(objects, onPage: page, at: targetPoint)
        var pastedIds: Set<String> = []
        var singleShapeId: String? = nil
        var singleNonShapeId: String? = nil

        for object in instantiated {
            switch object {
            case .image(let copy):
                notebook.attachments = (notebook.attachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                }
            case .text(let copy):
                notebook.textAttachments = (notebook.textAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                }
            case .table(let copy):
                notebook.tableAttachments = (notebook.tableAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
            case .shape(let copy):
                notebook.shapeAttachments = (notebook.shapeAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "shape", itemDict: dict)
                }
            case .link(let copy):
                notebook.linkAttachments = (notebook.linkAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
            case .model3D(let copy):
                notebook.model3DAttachments = (notebook.model3DAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                }
            case .audio(let copy):
                notebook.audioAttachments = (notebook.audioAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
            }
        }

        if pageDisplayMode == .continuous {
            focusContinuousPage(page)
        } else {
            currentPageIndex = page
        }
        commitNotebook()
        continuousObjectGeneration += 1
        thumbnailRevision += 1

        // 貼上之後選取新的那一份，接著就能直接再拖一次（手繪與打字模式下皆生效）。
        selectedObjectIds = pastedIds
        if pastedIds.count == 1 {
            if let sid = singleShapeId {
                selectedShapeIds = [sid]
                activeSelectedObjectId = nil
            } else if let oid = singleNonShapeId {
                selectedShapeIds = []
                activeSelectedObjectId = oid
            }
        }
    }

    private func deleteSelection() {
        let ids = effectiveSelectedObjectIds
        guard !ids.isEmpty else { return }
        deleteObjects(ids: ids)
    }

    private func deleteObjects(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            if (notebook.attachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "image")
            }
            if (notebook.textAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "text")
            }
            if (notebook.model3DAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "3d")
            }
            if (notebook.tableAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "table")
            }
        }
        notebook.attachments?.removeAll { ids.contains($0.id) }
        notebook.textAttachments?.removeAll { ids.contains($0.id) }
        notebook.tableAttachments?.removeAll { ids.contains($0.id) }
        notebook.linkAttachments?.removeAll { ids.contains($0.id) }
        notebook.model3DAttachments?.removeAll { ids.contains($0.id) }
        notebook.audioAttachments?.removeAll { ids.contains($0.id) }
        notebook.commentPins?.removeAll { ids.contains($0.id) }
        // 形狀連同它的連接線一起刪 —— 只刪形狀的話，線會留在畫布上，
        // 兩端各指著一個不存在的東西。
        notebook.shapeAttachments?.removeAll { ids.contains($0.id) }
        notebook.connectionAttachments?.removeAll {
            ids.contains($0.fromShapeId) || ids.contains($0.toShapeId)
        }
        selectedObjectIds.subtract(ids)
        selectedShapeIds.subtract(ids)
        if let active = activeSelectedObjectId, ids.contains(active) { activeSelectedObjectId = nil }
        if let editing = editingAttachmentId, ids.contains(editing) { editingAttachmentId = nil }
        if let editing = editingTextId, ids.contains(editing) { editingTextId = nil }
        if let editing = inlineEditingTextId, ids.contains(editing) { inlineEditingTextId = nil }
        if let editing = editingShapeId, ids.contains(editing) { editingShapeId = nil }
        if let editing = editingTable?.id, ids.contains(editing) { editingTable = nil }
        commitNotebook()
        continuousObjectGeneration += 1
        thumbnailRevision += 1
    }

    private func clipboardObject(forId id: String) -> ClipboardObject? {
        if let item = notebook.attachments?.first(where: { $0.id == id }) { return .image(item) }
        if let item = notebook.textAttachments?.first(where: { $0.id == id }) { return .text(item) }
        if let item = notebook.tableAttachments?.first(where: { $0.id == id }) { return .table(item) }
        if let item = notebook.shapeAttachments?.first(where: { $0.id == id }) { return .shape(item) }
        if let item = notebook.linkAttachments?.first(where: { $0.id == id }) { return .link(item) }
        if let item = notebook.model3DAttachments?.first(where: { $0.id == id }) { return .model3D(item) }
        if let item = notebook.audioAttachments?.first(where: { $0.id == id }) { return .audio(item) }
        return nil
    }

    /// 目前模式的徽章：這個模式下筆會不會畫線、物件拖不拖得動。
    /// 讓模式徽章亮起，並排程淡出。
    private func flashModeBadge() {
        modeBadgeToken += 1
        let token = modeBadgeToken
        modeBadgeVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            // 這段期間又切過模式的話，token 對不上，就讓後來那一次決定。
            if token == modeBadgeToken { modeBadgeVisible = false }
        }
    }

    private var modeBadge: some View {
        let isDraw = editorMode == .draw
        return HStack(spacing: 7) {
            Image(systemName: isDraw ? "pencil.tip" : "keyboard.fill")
                .font(.caption)
                .foregroundColor(isDraw ? .orange : .accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(localizationManager.localized(isDraw ? "mode_draw_badge" : "mode_type_badge"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(localizationManager.localized(isDraw ? "mode_draw_hint" : "mode_type_hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 330, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((isDraw ? Color.orange : Color.accentColor).opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
        // 徽章是狀態顯示，不是按鈕 —— 吃掉觸控的話，它蓋住的那塊畫布
        // 就寫不了字，而使用者看不出是被什麼擋住的。
        .allowsHitTesting(false)
    }

    /// 文字編修、圖片編修、圖層三張浮動面板。
    ///
    /// **掛在 `canvasWorkArea`（兩種頁面模式共用的那一層），而且層級最高。**
    ///
    /// 這三張面板原本各自藏在畫布內部的 ZStack 裡，沒有 zIndex：
    /// - 手寫模式下 PencilKit 畫布（zIndex 2）蓋在它上面，點關閉鈕變成在
    ///   畫布上畫了一筆；
    /// - 打字模式下全頁的文字輸入層（zIndex 2）與物件層（zIndex 3）也在它上面；
    /// - 連續頁面模式根本不會走到那一段程式，編輯鈕按了完全沒有反應。
    /// 症狀分別是「編輯視窗出現了卻關不掉」與「編輯鈕沒作用」。
    @ViewBuilder
    private var objectEditPanels: some View {
        ZStack(alignment: .topTrailing) {
        // 🌟 文字編修浮動面板
        //
        // 以前是 modal sheet，蓋住整個畫布 —— 要調一個文字方塊的排版，
        // 卻看不到那個文字方塊。與圖片美化面板同樣的問題、同樣的解法：
        // 浮在畫布上、標題列可以拖到一旁，改動直接反映在物件上。
        if let id = editingTextId {
            FloatingPanel(
                title: localizationManager.localized("text_studio"),
                onClose: { editingTextId = nil }
            ) {
                VStack(spacing: 10) {
                    ObjectOrderBar(id: id)
                    WordTextStudioView(
                        attachment: wholeBoxBinding(forTextId: id),
                        presentation: .inlinePanel
                    ) { updated in
                        if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                            notebook.textAttachments?[idx] = updated
                            commitNotebook()
                        }
                    }
                }
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }

        // 🌟 圖片美化浮動面板
        //
        // 以前是 modal sheet，蓋住整個畫布 —— 調濾鏡時看不到自己在調
        // 什麼。改成浮在畫布上、標題列可拖到一旁的面板：控制項與圖片
        // 同時在畫面上，改動直接反映在物件上。
        if let id = editingAttachmentId {
            FloatingPanel(
                title: localizationManager.localized("image_beautify"),
                onClose: { editingAttachmentId = nil }
            ) {
                VStack(spacing: 10) {
                    ObjectOrderBar(id: id)
                    // 這張圖如果是數字製圖，先給重新編修的入口 ——
                    // 濾鏡與邊框改不了圖表裡的數字。
                    if let spec = notebook.attachments?
                        .first(where: { $0.id == id })?.chartSpec {
                        Button {
                            editingChartAttachmentId = ChartEditTarget(id: id, spec: spec)
                        } label: {
                            Label(localizationManager.localized("chart_edit"),
                                  systemImage: "chart.bar.xaxis")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    // 這張圖如果是算式卡片，提供回到計算機重新求值的入口
                    if let formula = notebook.attachments?
                        .first(where: { $0.id == id })?.mathFormula {
                        Button {
                            editingMathAttachmentId = MathEditTarget(id: id, formula: formula)
                        } label: {
                            Label(localizationManager.localized("math_calc"),
                                  systemImage: "function")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    ImageEditControls(
                        attachment: binding(for: id),
                        onDone: { editingAttachmentId = nil },
                        onDelete: {
                            notebook.attachments?.removeAll { $0.id == id }
                            commitNotebook()
                            editingAttachmentId = nil
                        }
                    )
                }
            }
        }


        // 形狀編修面板。與圖片、文字同一套 —— 浮在畫布上，改動即時反映在物件上。
        if let id = editingShapeId,
           notebook.shapeAttachments?.contains(where: { $0.id == id }) == true {
            FloatingPanel(
                title: localizationManager.localized("shape_edit"),
                onClose: { editingShapeId = nil }
            ) {
                ShapeEditPanel(
                    shape: shapeBinding(for: id),
                    onDuplicate: { duplicateShape(id) },
                    onDelete: { deleteShape(id) }
                )
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }

        if let id = editingConnectionId,
           notebook.connectionAttachments?.contains(where: { $0.id == id }) == true {
            FloatingPanel(
                title: localizationManager.localized("connection_edit"),
                onClose: { editingConnectionId = nil }
            ) {
                ConnectionEditPanel(
                    connection: connectionBinding(for: id),
                    onDelete: { deleteConnection(id) }
                )
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }

        if showLayerPanel {
            FloatingPanel(
                title: localizationManager.localized("layers_panel"),
                onClose: { showLayerPanel = false }
            ) {
                VStack(spacing: 10) {
                    // 跨型別的堆疊：圖片、文字、表格、圖表、3D、連結、
                    // 形狀全部在同一份順序裡。使用者要的「圖層上下排序」
                    // 指的是這個 —— 底下那個只認形狀。
                    CanvasStackPanel(
                        objects: pageStackableObjects,
                        order: Binding(
                            get: {
                                ObjectStacking.normalized(
                                    objects: pageStackableObjects,
                                    order: notebook.objectOrder(forPage: currentPageIndex)
                                )
                            },
                            set: { updated in
                                // **只寫這一頁。** 整個欄位覆蓋掉的話，在第 2 頁
                                // 調一次順序，第 1 頁的順序就被清光了 ——
                                // 那是 v3.8.0 (32) 已經出貨的 bug。
                                notebook.setObjectOrder(updated, forPage: currentPageIndex)
                                commitNotebook()
                            }
                        ),
                        selection: $selectedShapeIds,
                        onAlign: { mode, ids in alignSelectedObjects(mode, ids: ids) }
                    )

                    // 形狀的群組操作留在原本的面板 —— 群組是形狀專屬的
                    // 概念（連接線要接得住），其餘型別沒有這回事。
                    if !pageShapes.isEmpty {
                        Divider()
                        ObjectLayerPanel(
                            shapes: Binding(
                                get: { pageShapes },
                                set: { updated in replacePageShapes(with: updated) }
                            ),
                            selection: $selectedShapeIds,
                            groupingOnly: true
                        )
                    }
                }
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }


        }
        .environment(\.objectReorder, { id, op in reorderObject(id, op) })
        .environment(\.objectLock, objectLockActions)
        .environment(\.objectClipboard, objectClipboardActions)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .zIndex(10_000)
    }

    /// 物件所在的頁面。找不到（已刪除）回傳 nil。
    private func pageOfObject(_ id: String) -> Int? {
        let norm = id.lowercased()
        if let v = notebook.attachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.shapeAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.tableAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.textAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.linkAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.model3DAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.audioAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.commentPins?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        return nil
    }

    /// 物件選單、編輯面板、圖層面板共用的「鎖定在畫布上」。
    private var objectLockActions: ObjectLockActions {
        ObjectLockActions(
            isLocked: { id in notebook.allLockedObjectIds.contains(id.lowercased()) },
            setLocked: { id, locked in setObjectLocked(id, locked) })
    }

    /// 點在哪一個鎖定物件上（最上層的那一個）。沒有回 nil。
    private func lockedObjectHit(at point: CGPoint, page: Int) -> String? {
        let locked = notebook.allLockedObjectIds
        guard !locked.isEmpty else { return nil }
        let stacking = ObjectStacking.Lookup(order: notebook.objectOrder(forPage: page))
        return stackableObjects(forPage: page)
            .filter { locked.contains($0.id.lowercased()) }
            .sorted { stacking.zIndex(for: $0.id, kind: $0.kind) > stacking.zIndex(for: $1.id, kind: $1.kind) }
            // 放寬 20pt：角落的鎖頭露在物件外面，點鎖頭也要算點到它。
            .first { frameOfObject(id: $0.id)?.insetBy(dx: -20, dy: -20).contains(point) == true }?
            .id
    }

    /// 每個鎖定物件右上角的鎖頭（頁面座標，依物件的實際外框放）。不分模式都畫：
    /// 看得到的鎖定物件，一定要看得出它鎖住了、也知道從哪裡解。
    /// 手寫模式下物件層不吃觸控，手指點鎖頭會落到畫布上，由 `handleCanvasDirectTap` 接住（同樣給解鎖鈕）。
    @ViewBuilder
    private func lockedObjectBadges(forPage page: Int) -> some View {
        let locked = notebook.allLockedObjectIds
        if !locked.isEmpty {
            ForEach(stackableObjects(forPage: page).filter { locked.contains($0.id.lowercased()) }, id: \.id) { object in
                if let frame = frameOfObject(id: object.id) {
                    LockedObjectBadge {
                        lockPromptId = (lockPromptId?.caseInsensitiveCompare(object.id) == .orderedSame) ? nil : object.id
                    }
                    .position(x: frame.maxX, y: frame.minY)
                    .zIndex(9_700)
                }
            }
        }
    }

    /// 鎖定物件上方的「解除鎖定」鈕（頁面座標，畫在物件層裡）。
    @ViewBuilder
    private func lockedObjectPrompt(forPage page: Int) -> some View {
        if let id = lockPromptId, pageOfObject(id) == page,
           notebook.allLockedObjectIds.contains(id.lowercased()), let frame = frameOfObject(id: id) {
            Button {
                setObjectLocked(id, false)
                lockPromptId = nil
            } label: {
                Label(localizationManager.localized("object_unlock"), systemImage: "lock.open.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("object.unlock.prompt")
            .position(x: frame.midX, y: max(16, frame.minY - 20))
            .zIndex(9_800)
        }
    }

    /// 鎖定／解除鎖定一個物件。鎖定時一併收掉它的選取與編輯面板 ——
    /// 鎖定的物件點不到，留著選取外框的話，使用者看到的是一組拖不動的把手。
    private func setObjectLocked(_ id: String, _ locked: Bool) {
        let normId = id.lowercased()
        guard notebook.allLockedObjectIds.contains(normId) != locked else { return }
        if locked {
            guard let page = pageOfObject(normId) else { return }
            notebook.setLockedObjectIds(notebook.lockedObjectIds(forPage: page).union([normId]), forPage: page)
        } else {
            // 解除時每一頁都拿掉：頁面搬移過的話，它記在哪個頁次鍵底下不一定是現在這一頁。
            for key in (notebook.lockedObjectIdsByPage ?? [:]).keys {
                guard let page = Int(key) else { continue }
                notebook.setLockedObjectIds(notebook.lockedObjectIds(forPage: page).subtracting([normId]), forPage: page)
            }
        }
        if locked {
            if activeSelectedObjectId?.lowercased() == normId {
                activeSelectedObjectId = nil
                collaborationManager.broadcastSelection(selectedId: nil)
            }
            selectedObjectIds.remove(id)
            selectedObjectIds.remove(normId)
            selectedShapeIds.remove(id)
            selectedShapeIds.remove(normId)
            if inlineEditingTextId?.lowercased() == normId { inlineEditingTextId = nil }
            if editingTextId?.lowercased() == normId { editingTextId = nil }
            if editingShapeId?.lowercased() == normId { editingShapeId = nil }
            if editingAttachmentId?.lowercased() == normId { editingAttachmentId = nil }
        }
        if lockPromptId?.lowercased() == normId { lockPromptId = nil }
        commitNotebook()
        // 只重建物件層：重建畫布會整頁白一下，寫到一半的筆畫也會不見。
        continuousObjectGeneration += 1
    }

    /// 調整單一物件的層級（選單、編輯面板共用，支援移至筆跡下方/上方）。
    func reorderObject(_ id: String, _ op: ObjectReorderOp) {
        guard let page = pageOfObject(id) else { return }
        switch op {
        case .sendBelowInk:
            var current = notebook.underInkObjectIds(forPage: page)
            if !current.contains(id) {
                current.insert(id)
                notebook.setUnderInkObjectIds(current, forPage: page)
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        case .bringAboveInk:
            var current = notebook.underInkObjectIds(forPage: page)
            if current.contains(id) {
                current.remove(id)
                notebook.setUnderInkObjectIds(current, forPage: page)
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        case .toFront:
            var current = notebook.underInkObjectIds(forPage: page)
            if current.contains(id) {
                current.remove(id)
                notebook.setUnderInkObjectIds(current, forPage: page)
            }
            let order = ObjectStacking.normalized(
                objects: stackableObjects(forPage: page),
                order: notebook.objectOrder(forPage: page))
            notebook.setObjectOrder(op.apply(id, to: order), forPage: page)
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        case .toBack:
            var current = notebook.underInkObjectIds(forPage: page)
            if !current.contains(id) {
                current.insert(id)
                notebook.setUnderInkObjectIds(current, forPage: page)
            }
            let order = ObjectStacking.normalized(
                objects: stackableObjects(forPage: page),
                order: notebook.objectOrder(forPage: page))
            notebook.setObjectOrder(op.apply(id, to: order), forPage: page)
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        default:
            let order = ObjectStacking.normalized(
                objects: stackableObjects(forPage: page),
                order: notebook.objectOrder(forPage: page))
            notebook.setObjectOrder(op.apply(id, to: order), forPage: page)
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        }
        continuousObjectGeneration += 1
        thumbnailRevision += 1
    }

    /// 這本筆記上所有物件的 id（不含連接線）。用來偵測「新插入了什麼」。
    private var allObjectIds: [String] {
        var ids: [String] = []
        ids += (notebook.attachments ?? []).map(\.id)
        ids += (notebook.shapeAttachments ?? []).map(\.id)
        ids += (notebook.tableAttachments ?? []).map(\.id)
        ids += (notebook.textAttachments ?? []).map(\.id)
        ids += (notebook.linkAttachments ?? []).map(\.id)
        ids += (notebook.model3DAttachments ?? []).map(\.id)
        ids += (notebook.audioAttachments ?? []).map(\.id)
        return ids
    }

    /// **新插入的物件一律放在最上層。**
    ///
    /// 沒有明確順序的物件，疊放次序由「型別的預設層級」決定 —— 圖片永遠
    /// 在文字、表格之下，於是新貼的圖片被舊的文字蓋住，看起來像沒插進去。
    /// 這裡掛在「物件數量變了」這一個點上，而不是改每一個插入路徑：
    /// 本機插入、匯入、範本、協同遠端寫入全部會經過同一處，不會漏。
    private func placeNewObjectsOnTop() {
        let ids = allObjectIds
        defer { knownObjectIds = Set(ids) }
        guard let known = knownObjectIds else { return }
        let fresh = ids.filter { !known.contains($0) }
        guard !fresh.isEmpty else { return }

        var byPage: [Int: [String]] = [:]
        for id in fresh {
            if let page = pageOfObject(id) { byPage[page, default: []].append(id) }
        }
        for (page, newIds) in byPage {
            let newSet = Set(newIds)
            let existing = stackableObjects(forPage: page).filter { !newSet.contains($0.id) }
            var order = ObjectStacking.normalized(
                objects: existing, order: notebook.objectOrder(forPage: page))
            order += newIds   // 到達順序＝插入順序
            notebook.setObjectOrder(order, forPage: page)
        }
        commitNotebook()

        // 手寫模式下物件不吃觸控：剛插進來的東西會拖不動、選不起來，看起來像插壞了
        // （使用者回報「形狀無法編輯」「圖片的編輯鈕沒有作用」的一個原因）。
        // 本機插入就切到打字模式，與 Android 同一條規則；遠端協同寫進來的不切，
        // 別人插東西不該把我的筆搶走。
        if editorMode == .draw && !isApplyingRemoteUpdate && !isCollaborating {
            transitionToMode(.type)
        }
    }

    /// 這一頁上所有可堆疊的物件，跨七種型別收成同一份清單。
    ///
    /// 名字取得出來就用內容（文字方塊取內文、形狀取標籤），取不出來就用型別名
    /// —— 面板上一整排「未命名」的話，使用者分不出哪一列是哪一個。
    private var pageStackableObjects: [StackableObject] {
        stackableObjects(forPage: currentPageIndex)
    }

    /// 指定頁面上的所有可堆疊物件。連續模式下每一頁各有自己的順序，
    /// 不能只認焦點頁。
    private func stackableObjects(forPage page: Int) -> [StackableObject] {
        let unnamed = localizationManager.localized("layer_unnamed")
        func title(_ raw: String, _ fallbackKey: String) -> String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return localizationManager.localized(fallbackKey) }
            return String(trimmed.prefix(24))
        }

        var result: [StackableObject] = []
        for item in (notebook.attachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .image,
                                title: localizationManager.localized("layer_kind_image")))
        }
        for item in (notebook.shapeAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .shape,
                                title: title(item.label, "layer_kind_shape")))
        }
        for item in (notebook.tableAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .table,
                                title: localizationManager.localized("layer_kind_table")))
        }
        for item in (notebook.textAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .text,
                                title: title(item.text, "layer_kind_text")))
        }
        for item in (notebook.linkAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .link,
                                title: title(item.title.isEmpty ? item.urlString : item.title, "layer_kind_link")))
        }
        for item in (notebook.model3DAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .model3D,
                                title: localizationManager.localized("layer_kind_model3d")))
        }
        for item in (notebook.audioAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .audio,
                                title: title(item.title, "layer_kind_audio")))
        }
        for pin in (notebook.commentPins ?? []) where pin.pageIndex == page {
            result.append(.init(id: pin.id, kind: .pin,
                                title: localizationManager.localized("layer_kind_pin")))
        }
        _ = unnamed
        return result
    }

    /// 換掉這一頁的形狀，其餘頁面原封不動。
    ///
    /// 陣列順序就是堆疊順序，所以整段換掉是必要的 —— 只改個別元素的話，
    /// 圖層面板調的順序不會反映到畫布上。
    private func replacePageShapes(with updated: [NoteShapeAttachment]) {
        var others = (notebook.shapeAttachments ?? []).filter { $0.pageIndex != currentPageIndex }
        others.append(contentsOf: updated)
        notebook.shapeAttachments = others
        commitNotebook()
    }

    private func toggleShapeSelection(_ id: String) {
        // 選到群組裡的一個就整組選起來 —— 那正是群組的意義。
        // 形狀被選取時，其他種類的物件一律退出編輯狀態（畫布上同時最多一個待編輯物件）。
        activeSelectedObjectId = nil
        if inlineEditingTextId != nil { inlineEditingTextId = nil }
        let mates = ObjectLayerOps.groupMates(of: id, in: pageShapes)
        if mates.isSubset(of: selectedShapeIds) {
            selectedShapeIds.subtract(mates)
        } else {
            selectedShapeIds = mates
        }
    }

    /// 選取單一物件（圖片、文字、表格、連結、錄音、3D）。
    /// 先前被選取的物件（包括形狀、連接線、就地編輯中的文字）自動退出編輯狀態。
    private func selectSingleObject(_ id: String, keepInlineText: Bool = false) {
        activeSelectedObjectId = id
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
        if !keepInlineText, inlineEditingTextId != nil, inlineEditingTextId != id {
            inlineEditingTextId = nil
        }
        collaborationManager.broadcastSelection(selectedId: id)
    }

    /// 拖曳一個形狀時，同一組的其他成員要跟著走。
    ///
    /// 不跟的話，群組起來的流程圖一拖就散開了。
    private func moveShapeGroup(_ id: String, by delta: CGSize) {
        guard var all = notebook.shapeAttachments,
              let page = all.first(where: { $0.id == id })?.pageIndex else { return }
        // 同組成員以**這個形狀所在的頁**來找：連續模式下它不一定在焦點頁上。
        let mates = ObjectLayerOps.groupMates(of: id, in: all.filter { $0.pageIndex == page })
        for index in all.indices where mates.contains(all[index].id) {
            all[index].x += delta.width
            all[index].y += delta.height
        }
        // 連續模式：整組的中心拖到別頁就整組換頁。連到組外形狀的連接線會被拆到兩頁上，
        // 那種組合留在本頁（連接線只畫得出同一頁的兩端）。
        var crossedTo: Int?
        let frames = all.filter { mates.contains($0.id) }.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        let links = (notebook.connectionAttachments ?? []).filter { mates.contains($0.fromShapeId) || mates.contains($0.toShapeId) }
        if let union = frames.dropFirst().reduce(frames.first, { $0?.union($1) }),
           links.allSatisfy({ mates.contains($0.fromShapeId) && mates.contains($0.toShapeId) }),
           let landing = crossingLanding(for: union, page: page) {
            for index in all.indices where mates.contains(all[index].id) {
                all[index].x += landing.offset.width
                all[index].y += landing.offset.height
                all[index].pageIndex = landing.page
            }
            if var connections = notebook.connectionAttachments {
                for index in connections.indices
                where mates.contains(connections[index].fromShapeId) {
                    connections[index].pageIndex = landing.page
                }
                notebook.connectionAttachments = connections
            }
            crossedTo = landing.page
        } else if let union = frames.dropFirst().reduce(frames.first, { $0?.union($1) }) {
            // 留在本頁：與其他物件一樣推回可列印範圍（S-85）。原本形狀拖出頁外就留在頁外，
            // 畫面與縮圖上都看不到、也點不到。
            let landed = PrintableArea.clampOrigin(
                x: union.minX, y: union.minY, width: union.width, height: union.height)
            for index in all.indices where mates.contains(all[index].id) {
                all[index].x += landed.x - union.minX
                all[index].y += landed.y - union.minY
            }
        }
        notebook.shapeAttachments = all
        commitNotebook()
        finishPageCrossing(ids: crossedTo == nil ? [] : Array(mates), to: crossedTo)
    }

    private func shapeBinding(for id: String) -> Binding<NoteShapeAttachment> {
        let normId = id.lowercased()
        return Binding(
            get: {
                notebook.shapeAttachments?.first(where: { $0.id.lowercased() == normId })
                    ?? NoteShapeAttachment(id: id)
            },
            set: { updated in
                guard let index = notebook.shapeAttachments?
                    .firstIndex(where: { $0.id.lowercased() == normId }) else { return }
                notebook.shapeAttachments?[index] = updated
                commitNotebook()
            }
        )
    }

    private func moveTable(_ id: String, by delta: CGSize) {
        guard hypot(delta.width, delta.height) >= 1 else {
            finishPageCrossing(ids: [], to: nil)
            return
        }
        let normId = id.lowercased()
        guard var all = notebook.tableAttachments,
              let index = all.firstIndex(where: { $0.id.lowercased() == normId }) else { return }
        let previous = all[index]
        all[index].x += delta.width
        all[index].y += delta.height
        // 連續模式：拖到別頁就換頁。表格裡寫了字的不換 —— 筆跡屬於頁面，跟不過去，
        // 表格換頁而字留在原頁，等於把內容拆散。
        if let frame = frameOfObject(id: id),
           let landing = crossingLanding(
               for: frame.offsetBy(dx: delta.width, dy: delta.height), page: previous.pageIndex),
           !drawingForPage(previous.pageIndex).strokes.contains(where: previous.containsStroke) {
            all[index].x += landing.offset.width
            all[index].y += landing.offset.height
            all[index].pageIndex = landing.page
            notebook.tableAttachments = all
            commitNotebook()
            finishPageCrossing(ids: [id], to: landing.page)
            return
        }
        // 留在本頁：與其他物件一樣推回可列印範圍（S-85）。原本表格拖出頁外就留在頁外，看不到也點不到。
        var applied = delta
        if let frame = frameOfObject(id: id) {
            let moved = frame.offsetBy(dx: delta.width, dy: delta.height)
            let landed = PrintableArea.clampOrigin(
                x: moved.minX, y: moved.minY, width: moved.width, height: moved.height)
            all[index].x += landed.x - moved.minX
            all[index].y += landed.y - moved.minY
            applied = CGSize(width: all[index].x - previous.x, height: all[index].y - previous.y)
        }
        notebook.tableAttachments = all
        commitNotebook()
        finishPageCrossing(ids: [], to: nil)

        moveStrokesInsideTable(previous, by: applied)
    }

    private func tableBinding(for id: String) -> Binding<NoteTableAttachment> {
        let normId = id.lowercased()
        return Binding(
            get: {
                notebook.tableAttachments?.first(where: { $0.id.lowercased() == normId })
                    ?? NoteTableAttachment(id: id)
            },
            set: { updated in
                guard let index = notebook.tableAttachments?
                    .firstIndex(where: { $0.id.lowercased() == normId }) else { return }
                let previous = notebook.tableAttachments![index]
                notebook.tableAttachments?[index] = updated
                commitNotebook()

                let dx = updated.x - previous.x
                let dy = updated.y - previous.y
                if hypot(dx, dy) >= 1 {
                    moveStrokesInsideTable(previous, by: CGSize(width: dx, height: dy))
                }
            }
        )
    }

    private func moveStrokesInsideTable(_ table: NoteTableAttachment, by delta: CGSize) {
        guard hypot(delta.width, delta.height) >= 0.5 else { return }
        let page = table.pageIndex

        // 1. 標準 PencilKit 筆跡（PKDrawing）
        let drawing = (pageDisplayMode == .single && page == currentPageIndex && canvasView != nil)
            ? (canvasView?.drawing ?? currentDrawing)
            : drawingForPage(page)

        let result = table.offsetContainedStrokes(in: drawing, by: delta)
        if result.movedCount > 0 {
            let updatedDrawing = result.drawing
            if page == currentPageIndex {
                currentDrawing = updatedDrawing
                if let canvas = canvasView {
                    canvas.drawing = updatedDrawing
                    if let adaptive = canvas as? AdaptiveCanvasView {
                        adaptive.initialLoadedStrokeCount = updatedDrawing.strokes.count
                        adaptive.forceDisplayRefresh(with: updatedDrawing)
                    }
                }
            }
            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: updatedDrawing)
            recordDrawingEdit(page: page, drawing: updatedDrawing)
            broadcastDrawingChange(page: page, drawing: updatedDrawing)
            PageThumbnailRenderer.invalidateAll()
            if pageDisplayMode == .continuous {
                // 筆跡已經寫進磁碟：讓那一頁合併重讀，不重建畫布。基準設成搬動前的那一份 ——
                // 畫面上的就是它，合併結果才會整份換成搬過的，不會把舊位置當成「這台剛寫的」留下來。
                inkDiskBaselines[page] = drawing
                continuousInkReloadGeneration += 1
                continuousObjectGeneration += 1
            }
        }

        // 2. 專業製圖筆畫（ProInk）
        if page == currentPageIndex, let proLayer = (canvasView as? AdaptiveCanvasView)?.proLayer {
            let layout = table.layout()
            let tableWidth = max(table.width, CGFloat(layout.width))
            let tableHeight = max(table.height, CGFloat(layout.height))
            let tableRect = CGRect(x: table.x, y: table.y, width: tableWidth, height: tableHeight)
            let hitRect = tableRect.insetBy(dx: -4, dy: -4)

            var proIdsToMove = Set<String>()
            for s in proLayer.ownStrokes {
                let b = s.bounds
                let mid = CGPoint(x: b.midX, y: b.midY)
                let intersection = tableRect.intersection(b)
                let isInside = tableRect.contains(b)
                    || hitRect.contains(mid)
                    || (!intersection.isNull && (intersection.width * intersection.height) >= (b.width * b.height * 0.4))
                    || (hitRect.contains(b.origin) && !intersection.isNull && intersection.width > 2 && intersection.height > 2)
                if isInside {
                    proIdsToMove.insert(s.id)
                }
            }
            if !proIdsToMove.isEmpty {
                proLayer.move(ids: proIdsToMove, by: delta)
                proLayer.endMove()
            }
        }
    }

    private func binding(for id: String) -> Binding<NoteImageAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.attachments?.first(where: { $0.id.lowercased() == norm }) ?? NoteImageAttachment(fileName: "")
            },
            set: { updated in
                if let idx = notebook.attachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.attachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    /// - Parameter hint: 呼叫端已經知道的位置（`ForEach` 走到第幾個）。
    ///   對得上就直接用，O(1)；對不上（陣列在兩次算繪之間變動了）才退回線性搜尋。
    ///
    /// **不能每次都線性搜尋。** `Binding(get:set:)` 建立時就會先呼叫一次 `get`，
    /// 一頁有 m 個文字方塊、全本有 n 個，一次算繪就是 m×n 次 UUID 字串比對，
    /// 而 SwiftUI 一次更新會重算好幾輪。主執行緒因此卡住超過十秒，看門狗
    /// （`0x8BADF00D`）在背景把 App 殺掉 —— 崩潰報告的主執行緒堆疊停在
    /// 這個閉包裡的 `_stringCompareInternal`。
    private func binding(forTextId id: String, hint: Int? = nil) -> Binding<NoteTextAttachment> {
        let norm = id.lowercased()
        func index(in items: [NoteTextAttachment]?) -> Int? {
            guard let items else { return nil }
            if let hint, items.indices.contains(hint), items[hint].id.lowercased() == norm { return hint }
            return items.firstIndex(where: { $0.id.lowercased() == norm })
        }
        return Binding(
            get: {
                index(in: notebook.textAttachments).map { notebook.textAttachments![$0] }
                    ?? NoteTextAttachment()
            },
            set: { updated in
                if let idx = index(in: notebook.textAttachments) {
                    notebook.textAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    /// 排版面板用：面板改的是**整個方塊**。改了字級、顏色這類方塊層級的值時，
    /// 逐字格式裡同一項的覆寫要一起拿掉，否則有覆寫的那幾個字看起來「改不動」；
    /// 面板裡直接改文字時，區段跟著移動。
    private func wholeBoxBinding(forTextId id: String) -> Binding<NoteTextAttachment> {
        let base = binding(forTextId: id)
        return Binding(
            get: { base.wrappedValue },
            set: { updated in
                let old = base.wrappedValue
                var next = updated
                if next.runs != nil, next.runs == old.runs {
                    if next.text != old.text { RichText.adjustRunsLineByLine(of: &next, from: old.text) }
                    var edit = TextCharStyle()
                    if next.isBold != old.isBold { edit.bold = next.isBold }
                    if next.isItalic != old.isItalic { edit.italic = next.isItalic }
                    if next.isUnderline != old.isUnderline { edit.underline = next.isUnderline }
                    if next.isStrikethrough != old.isStrikethrough { edit.strikethrough = next.isStrikethrough }
                    if next.fontSize != old.fontSize { edit.fontSize = next.fontSize }
                    if next.fontFamily != old.fontFamily { edit.fontFamily = next.fontFamily ?? "" }
                    if next.textColorHex != old.textColorHex { edit.textColorHex = next.textColorHex }
                    if !edit.isEmpty { RichText.applyToWholeBox(edit, to: &next) }
                }
                base.wrappedValue = next
            }
        )
    }

    private func binding(forLinkId id: String) -> Binding<NoteLinkAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.linkAttachments?.first(where: { $0.id.lowercased() == norm }) ?? NoteLinkAttachment(urlString: "")
            },
            set: { updated in
                if let idx = notebook.linkAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.linkAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    private func binding(forAudioId id: String) -> Binding<NoteAudioAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.audioAttachments?.first(where: { $0.id.lowercased() == norm })
                    ?? NoteAudioAttachment(fileName: "")
            },
            set: { updated in
                if let idx = notebook.audioAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.audioAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    private func binding(forModel3DId id: String) -> Binding<Note3DAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.model3DAttachments?.first(where: { $0.id.lowercased() == norm }) ?? Note3DAttachment()
            },
            set: { updated in
                if let idx = notebook.model3DAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.model3DAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }
}

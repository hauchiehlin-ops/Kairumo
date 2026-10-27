//
//  NotebookStore.swift
//  Kairumo
//
//  真實筆記與錄音資料庫管理員
//  支援本機檔案持久化、即時搜尋、排序、複製、重新命名與刪除
//

import SwiftUI
import Combine
import PencilKit
import CryptoKit
import PDFKit
#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 插入物件共用的外框樣式。
///
/// 文字方塊、圖片、3D 模型、網址預覽在畫布上都是「一個有邊框與底色的方框」。
/// 樣式各寫一份的結果是：改了文字方塊的邊框，圖片的邊框還是寫死的 ——
/// 使用者的期待是「所有插入的東西都能調」，所以共用同一組欄位與同一份繪製規則。
///
/// 全部是 `Optional` 並帶預設值：舊檔沒有這些欄位，解碼時會落到 `nil`，
/// 由 `resolved*` 取回各型別原本的外觀，升級上來的筆記看起來不會變。
public protocol ObjectFrameStyled {
    /// 是否畫邊框。
    var hasBorder: Bool { get set }
    /// 邊框顏色（`#RRGGBB`）。`nil` 代表沿用該型別的預設色。
    var borderColorHex: String? { get set }
    /// 邊框粗細。`nil` 代表沿用預設。
    var borderWidth: CGFloat? { get set }
    /// 方框底色。`"clear"` 代表透明；`nil` 代表沿用該型別的預設。
    var backgroundColorHex: String? { get set }
    var cornerRadius: CGFloat { get set }
    /// 物件在畫布上的旋轉角度（度，順時針）。
    ///
    /// 這是**畫布上的 2D 旋轉**，與 `Note3DAttachment` 的 `rotationX/Y/Z`
    /// （模型自身的姿態）是兩回事，不要混用。
    ///
    /// 宣告成計算屬性而非儲存屬性：實際的儲存欄位在各型別裡是 `Double?`。
    /// 這些結構都是 `Codable`，而載入走的是 `try? JSONDecoder().decode(...)`
    /// —— 新增一個**非 Optional** 的欄位，舊檔會因為缺鍵而整份解碼失敗，
    /// `try?` 再把失敗變成 nil：使用者的筆記會**整批靜默消失**。
    /// （`NoteTextAttachment` 的段落欄位全是 Optional 就是同一個理由。）
    var canvasRotation: Double { get set }
}

public extension ObjectFrameStyled {
    /// 底色是否為透明。
    var isBackgroundClear: Bool { backgroundColorHex == "clear" }

    /// 旋轉是否偏離正向 —— 命中測試與算繪要不要走旋轉路徑看這個。
    var isRotated: Bool { abs(canvasRotation.truncatingRemainder(dividingBy: 360)) > 0.01 }
}

/// 畫布旋轉的共用規則，兩個平台用同一組數值。
public enum CanvasRotation {
    /// 拖曳旋轉把手時吸附到這個倍數（度）。
    public static let snapStep: Double = 15
    /// 距離吸附角多少度以內才吸附。超過就自由角度。
    public static let snapTolerance: Double = 3

    /// 把任意角度正規化到 [0, 360)。
    public static func normalized(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// 拖曳中的角度 → 實際要套用的角度（含吸附）。
    ///
    /// 吸附只在**接近**整數角時發生。無條件吸附的話使用者就永遠轉不出
    /// 22° 這種角度，而「自由角度」正是這個功能的重點。
    public static func snapped(_ degrees: Double) -> Double {
        let value = normalized(degrees)
        let nearest = (value / snapStep).rounded() * snapStep
        return abs(value - nearest) <= snapTolerance ? normalized(nearest) : value
    }
}

/// 筆記三大核心主題分類
public enum NoteThemeCategory: String, Codable, CaseIterable, Identifiable {
    case general = "通用基礎"
    case aesthetic = "美學視覺"
    case engineering = "工程製程"
    case digital = "數位體驗"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .general: return "doc.text"
        case .aesthetic: return "paintpalette.fill"
        case .engineering: return "ruler.fill"
        case .digital: return "macbook.and.iphone"
        }
    }

    public var localizationKey: String {
        switch self {
        case .general: return "theme_general"
        case .aesthetic: return "theme_aesthetic"
        case .engineering: return "theme_engineering"
        case .digital: return "theme_digital"
        }
    }

    /// 核心的對應分類。紙張清單由核心供應，兩個平台才會是同一份。
    public var ffiTheme: FfiPaperTheme {
        switch self {
        case .general: return .general
        case .aesthetic: return .aesthetic
        case .engineering: return .engineering
        case .digital: return .digital
        }
    }
}

/// 筆記樣板種類。
///
/// # 這個列舉為什麼還在
///
/// 清單本身（有哪些紙、屬於哪個主題、什麼圖示、什麼底紋）**全部來自核心**
/// 的 `paperTemplates()`，兩個平台才會是同一份。留著這個列舉的唯一理由是
/// `rawValue`：前十三個是**中文字面值，而且已經寫進使用者的
/// `notebooks_v1.json`**，動不得。
///
/// 所以新加的樣板一律用與核心相同的英文 `id` 當 rawValue —— 沒有歷史包袱的
/// 東西不必背上歷史包袱。舊的十三個在 `legacyPaperId` 裡對照一次。
public enum NoteTemplate: String, Codable, CaseIterable, Identifiable {
    // ---- 既有的十三種：rawValue 是中文，已落盤，不可更動 ----
    case blank = "空白紙張"
    case grid = "方格點陣"
    case lined = "橫線筆記"
    case cornell = "康乃爾"
    case dotGridFine = "極細點陣 (5mm)"
    case goldenRatio = "黃金比例與三分構圖"
    case moodboardMatrix = "情緒板與色卡矩陣"
    case blueprintMetric = "工程藍圖坐標紙"
    case isometricGrid = "30° 等角立體軸測網格"
    case orthographic3View = "三視圖與剖面範本"
    case mobileWireframe = "行動端線框 (8pt Grid)"
    case webResponsiveGrid = "響應式 Web 12 欄網格"
    case userJourneyFlow = "使用者旅程與流程圖"

    // ---- 筆記方法 ----
    case cornellGrid = "cornell_grid"
    case quadrant = "quadrant"
    case outline = "outline"
    case twoColumn = "two_column"
    case qa = "qa"
    case kwl = "kwl"
    case mindMap = "mind_map"

    // ---- 規劃排程 ----
    case monthlyGrid = "monthly_grid"
    case weeklyColumns = "weekly_columns"
    case dailySchedule = "daily_schedule"
    case timeline24h = "timeline_24h"
    case studyPlanner = "study_planner"
    case projectTimeline = "project_timeline"

    // ---- 清單追蹤 ----
    case todoList = "todo_list"
    case checklistTwo = "checklist_two"
    case habitMonth = "habit_month"
    case assignmentTracker = "assignment_tracker"
    case choreRoster = "chore_roster"
    case challenge21 = "challenge_21"

    // ---- 學習 ----
    // 核心目錄有、這個列舉原本漏掉的兩種。漏掉的後果：選單裡看得到，
    // 點了卻什麼都沒發生（`NoteTemplate(paperId:)` 回 nil，選取被靜默略過）。
    case english3Line = "english_3line"
    case errorBook = "error_book"

    // ---- 圖學 ----
    case draftingSteps = "drafting_steps"
    case draftingTrap = "drafting_trap"

    public var id: String { rawValue }

    /// 舊的十三個：中文 rawValue → 核心的英文 id。
    private static let legacyPaperId: [NoteTemplate: String] = [
        .blank: "blank",
        .grid: "grid",
        .lined: "lined",
        .cornell: "cornell",
        .dotGridFine: "dot_grid_fine",
        .goldenRatio: "golden_ratio",
        .moodboardMatrix: "moodboard",
        .blueprintMetric: "blueprint",
        .isometricGrid: "isometric",
        .orthographic3View: "orthographic",
        .mobileWireframe: "mobile_wireframe",
        .webResponsiveGrid: "web_grid",
        .userJourneyFlow: "user_journey",
    ]

    /// 與語言無關的識別字，對應核心 `paperTemplates()` 的 `id`。
    nonisolated public var paperId: String { Self.legacyPaperId[self] ?? rawValue }

    /// 從核心的識別字還原。認不得就是 nil —— 悄悄退回空白紙的話，
    /// 核心新增一種紙、平台忘了跟上時不會有人發現。
    public nonisolated init?(paperId: String) {
        guard let match = NoteTemplate.allCases.first(where: { $0.paperId == paperId })
        else { return nil }
        self = match
    }

    private static let catalog: [String: FfiPaperTemplate] = {
        Dictionary(uniqueKeysWithValues: paperTemplates().map { ($0.id, $0) })
    }()

    /// 核心目錄裡的那一筆。
    ///
    /// 查表而不是再寫一份 switch：圖示、主題、底紋三件事各寫一份 switch 的
    /// 結果，是核心改了其中一項而平台沒跟上 —— 而那只會在那一種紙上看得到。
    nonisolated private var entry: FfiPaperTemplate? { NoteTemplate.catalog[paperId] }

    nonisolated public var ffiTheme: FfiPaperTheme { entry?.theme ?? .general }

    /// 素材庫那一組分類只對得上其中三個主題，對不上的回 nil。
    public var category: NoteThemeCategory? {
        switch ffiTheme {
        case .general, .method, .planner, .tracker: return .general
        case .aesthetic: return .aesthetic
        case .engineering: return .engineering
        case .digital: return .digital
        }
    }

    nonisolated public var iconName: String { entry?.iconApple ?? "doc.plaintext" }

    nonisolated public var localizationKey: String { entry?.titleKey ?? "tmpl_blank" }

    nonisolated public var descriptionLocalizationKey: String { entry?.descKey ?? "tmpl_blank_desc" }

    /// 這張紙的底紋。畫布與縮圖都照它鋪材質。
    nonisolated public var pageStyle: PageStyle { entry?.pageStyle ?? .blank }

    /// 顯示用的說明。**跟著語系走** —— 原本這裡是一串中文字面值，
    /// 於是介面切到英文時，樣板名稱翻了、說明沒翻。
    @MainActor
    public var description: String {
        LocalizationManager.shared.localized(descriptionLocalizationKey)
    }
}

/// 筆記資料夾模型（支援多層級子資料夾與自訂名稱）
public struct FolderItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var nameKey: String?
    public var parentId: String? // nil 代表位於最上層根目錄下
    public var createdAt: Date
    public var colorHex: String?

    @MainActor
    public var displayName: String {
        if let key = nameKey {
            let l = LocalizationManager.shared.localized(key)
            if !l.isEmpty && l != key { return l }
        }
        return name
    }

    public init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        nameKey: String? = nil,
        parentId: String? = nil,
        createdAt: Date = Date(),
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameKey = nameKey
        self.parentId = parentId
        self.createdAt = createdAt
        self.colorHex = colorHex
    }
}

/// 筆記文件本機模型
public struct NotebookDocument: Identifiable, Codable, Hashable, @unchecked Sendable {
    public let id: String
    public var title: String
    public var createdAt: Date
    public var lastModifiedDate: Date
    public var pageCount: Int
    public var hasRecording: Bool
    /// 這本筆記的套件加密了嗎。
    ///
    /// **必須是 Optional**：舊的 `notebooks.json` 沒有這個欄位，
    /// 不給預設值的話整份清單都解不開，而症狀是「所有筆記都不見了」。
    public var isEncryptedFlag: Bool?
    /// 使用者設定的「範例」標記（`nil` = 沒設定過，見 `isReadOnlySample`）。存進套件的中繼資料，跟著同步。
    public var sampleFlag: Bool?
    /// 加密狀態。真相在套件的 `manifest.json`，這個欄位只是清單顯示用的快取。
    public var isEncrypted: Bool {
        get { isEncryptedFlag ?? false }
        set { isEncryptedFlag = newValue }
    }
    public var previewSnippet: String?
    public var template: NoteTemplate
    public var recordingAudioPath: String?
    /// 所屬資料夾 ID（nil 代表位於最上層根目錄或未分類）
    public var folderId: String?
    /// 各頁面之 PKDrawing 向量筆跡資料（以 Data 形式持久化）
    public var pagesData: [Data]
    /// 各頁面之客製化畫布長度（以 pt 為單位，預設 1800pt，支援自由向下延長）
    public var pageHeights: [CGFloat]?
    /// 頁面規格的識別字（核心 `page_formats()` 的 id）。
    ///
    /// nil = A4 直式。**舊筆記沒有這個欄位，而它們全部是用 A4 的座標寫的** ——
    /// 所以預設值不能挑別的，否則每一本舊筆記的內容位置都會跟著跑掉。
    public var pageFormatId: String?
    /// 筆記內嵌圖片與圖表附件清單
    public var attachments: [NoteImageAttachment]?
    /// 筆記內嵌 Word 級文字方塊清單
    public var textAttachments: [NoteTextAttachment]?
    /// 筆記內嵌網址連結預覽清單
    public var linkAttachments: [NoteLinkAttachment]?
    /// 筆記內嵌 3D 空間模型清單
    public var model3DAttachments: [Note3DAttachment]?
    /// 筆記內嵌討論圖釘清單
    public var commentPins: [NoteCommentPin]?
    /// 筆記內嵌形狀清單（含流程圖符號）。
    public var shapeAttachments: [NoteShapeAttachment]?
    /// 形狀之間的連接線。
    public var connectionAttachments: [NoteConnectionAttachment]?
    /// 筆記內嵌表格清單。
    ///
    /// 舊檔沒有這個欄位，解碼後是 `nil` —— 升級上來的筆記不會有任何變化。
    public var tableAttachments: [NoteTableAttachment]?

    /// 貼在頁面上的錄音檔清單。
    ///
    /// 與 `recordingAudioPath` 不同：那是「整本筆記配一段錄音」，
    /// 位置在筆記本層級，畫布上看不到也移不動。這個是**頁面上的物件** ——
    /// 可以放在任何一頁的任何位置、可以搬、可以縮放、可以刪。
    ///
    /// 必須是 Optional：舊檔沒有這個欄位（見 `canvasRotation` 的說明）。
    public var audioAttachments: [NoteAudioAttachment]?
    public var tapeAttachments: [NoteTapeAttachment]?
    /// 手寫與文字動態流式錨定 (Fluid Sticky Annotations)
    public var stickyAnchors: [StickyAnnotationAnchor]?
    /// 特殊版面互動引導線狀態（例如核取清單勾選、選項狀態），Key 格式為 "\(pageIndex)_\(Int(x))_\(Int(y))"
    public var checkedGuideItems: [String: Bool]?

    /// 每一頁各自的紙張樣板 id。
    ///
    /// # 為什麼需要逐頁
    ///
    /// `template` 是**整本**的選擇，而一本會議紀錄的第一頁想用四象限、
    /// 後面幾頁想用橫線，這件事原本做不到 —— 選完樣板進去之後，整本就定了。
    ///
    /// 陣列長度可以短於頁數（舊筆記根本沒有這個欄位），取不到的那幾頁
    /// 退回整本的 `template` —— 那正是它們原本的樣子。
    public var pagePaperIds: [String]?
    /// 每一頁的穩定 id（核心的頁面 id）。即時協同以它指稱頁面（設計 §8.1）：頁碼會因為
    /// 別人新增、刪除、搬動頁面而改變，id 不會。`nil` = 這本還沒需要過（舊檔沒有這個欄位）。
    /// 有值時，每一個頁面操作都要讓它跟著走（見 `NotebookStore` 的 add/insert/delete/move/duplicate）。
    public var pageIds: [String]?

    /// 版面的配色。nil 是預設那一組。
    ///
    /// 整本一個而不是逐頁：同一本筆記裡每頁不同顏色不是「豐富」，是雜亂。
    public var guidePaletteId: String?

    /// 手寫辨識出來的文字，逐頁一份：`["頁次": "辨識結果"]`。
    ///
    /// **只用來搜尋，不會取代任何一筆畫。** 手寫筆記的價值就在那個手寫，
    /// 辨識只是讓它找得到。Android 走核心的搜尋索引（`index_handwriting`），
    /// Apple 這邊的搜尋是在文件本身上做的，所以結果存在這裡。
    ///
    /// 必須是 Optional：舊筆記沒有這個欄位，非 Optional 會讓 Codable 在解碼時
    /// 丟例外，而那會讓**整本筆記開不起來**（見 `canvasRotation` 的說明）。
    public var recognizedText: [String: String]?

    /// 畫布物件的**堆疊順序**，逐頁一份：`["頁次": [由後到前的物件 id]]`。
    ///
    /// 為什麼是一份順序清單而不是每個物件各帶一個 z 值：
    /// 物件散在七個不同型別的陣列裡（圖片、文字、表格、圖表、3D、連結、形狀）。
    /// 每個型別各加一個欄位＝七次資料格式變更、七份遷移；而真正要表達的
    /// 只有一件事 —— 誰在誰上面。那是一個順序，就用順序來存。
    ///
    /// 不在清單裡的 id 排在最後面（最上層），順序照型別的預設值 ——
    /// 舊筆記沒有這個欄位，疊放順序與過去完全相同。
    public var objectOrderByPage: [String: [String]]?

    /// v3.8.0 的舊欄位：**整本一份**的堆疊順序。只讀不寫。
    ///
    /// 那一版有 bug：面板讀的是「這一頁的物件」，寫回去的卻是整個欄位 ——
    /// 在第 2 頁調一次順序，第 1 頁的順序就被清掉了。
    ///
    /// 不能直接把欄位型別改掉：v3.8.0 (32) 已經送上 TestFlight，那些筆記裡
    /// 存的是陣列。同名改成字典的話，Swift 的 Codable 會在解碼時丟例外，
    /// 而那會讓**整本筆記解不開**（見 `canvasRotation` 的說明）。
    /// 所以留著它、只當成沒有分頁資訊時的退路。
    public var objectOrder: [String]?

    /// 某一頁的堆疊順序。沒有逐頁資料時退回舊欄位。
    public func objectOrder(forPage page: Int) -> [String]? {
        objectOrderByPage?[String(page)] ?? objectOrder
    }

    /// 寫入某一頁的堆疊順序。**只動那一頁**，其餘頁面原封不動。
    public mutating func setObjectOrder(_ order: [String], forPage page: Int) {
        var map = objectOrderByPage ?? [:]
        map[String(page)] = order
        objectOrderByPage = map
    }

    /// 某一頁**明確**放到手寫筆跡下方的物件 ID（使用者搬過，或插入時指定）。
    ///
    /// 沒有列在這裡的物件照型別的預設：插入的素材（PDF 頁面、圖片、圖表、表格、形狀…）在筆跡
    /// 下方，文字、圖釘、紙膠帶在上方。規則在核心（`padnote-core::ffi_layering`），
    /// 實際在哪一層一律問 `underInkObjectIds(forPage:)`。
    public var underInkObjectIdsByPage: [String: [String]]?

    /// 某一頁**明確**放到手寫筆跡上方的物件 ID（預設在下方、被使用者搬上來的）。
    /// 與 Android `NotebookMeta.KEY_OVER_INK_BY_PAGE` 同一個鍵。
    public var overInkObjectIdsByPage: [String: [String]]?

    public func explicitUnderInkObjectIds(forPage page: Int) -> Set<String> {
        Set(underInkObjectIdsByPage?[String(page)] ?? [])
    }

    public func explicitOverInkObjectIds(forPage page: Int) -> Set<String> {
        Set(overInkObjectIdsByPage?[String(page)] ?? [])
    }

    /// 這一頁**實際**在筆跡下方的物件（核心規則 + 兩份明確清單）。
    public func underInkObjectIds(forPage page: Int) -> Set<String> {
        Set(objectsBelowInk(
            objects: layerObjects(forPage: page),
            under: underInkObjectIdsByPage?[String(page)] ?? [],
            over: overInkObjectIdsByPage?[String(page)] ?? []))
    }

    /// 只寫明確的「筆跡下方」清單（範例筆記的背景卡片）。一般的搬動走 `moveObjects(_:to:forPage:)`。
    public mutating func setUnderInkObjectIds(_ ids: Set<String>, forPage page: Int) {
        var map = underInkObjectIdsByPage ?? [:]
        // 排序：同一組物件每次都寫出同一份內容，同步才不會誤判「有變動」。
        map[String(page)] = ids.sorted()
        underInkObjectIdsByPage = map
    }

    /// 把物件搬到筆跡的上方或下方。兩份清單怎麼寫由核心決定（`moveObjectsToInkPlane`）。
    public mutating func moveObjects(_ ids: Set<String>, to plane: FfiInkPlane, forPage page: Int) {
        let keys = Set(ids.map { $0.lowercased() })
        let moving = layerObjects(forPage: page).filter { keys.contains($0.id.lowercased()) }
        guard !moving.isEmpty else { return }
        let key = String(page)
        let lists = moveObjectsToInkPlane(
            moving: moving, plane: plane,
            under: underInkObjectIdsByPage?[key] ?? [],
            over: overInkObjectIdsByPage?[key] ?? [])
        var under = underInkObjectIdsByPage ?? [:]
        under[key] = lists.under
        underInkObjectIdsByPage = under
        var over = overInkObjectIdsByPage ?? [:]
        over[key] = lists.over.isEmpty ? nil : lists.over
        overInkObjectIdsByPage = over.isEmpty ? nil : over
    }

    /// 這一頁上可以疊放的物件（id 與種類），給核心的圖層規則用。
    public func layerObjects(forPage page: Int) -> [FfiLayerObject] {
        var out: [FfiLayerObject] = []
        func add<T>(_ items: [T]?, _ kind: FfiLayerKind, _ id: (T) -> String, _ pageOf: (T) -> Int) {
            for item in items ?? [] where pageOf(item) == page { out.append(FfiLayerObject(id: id(item), kind: kind)) }
        }
        add(attachments, .image, \.id, \.pageIndex)
        add(shapeAttachments, .shape, \.id, \.pageIndex)
        // 連接線跟著它連的形狀：形狀在筆跡下方，線也在下方。
        add(connectionAttachments, .shape, \.id, \.pageIndex)
        add(tableAttachments, .table, \.id, \.pageIndex)
        add(textAttachments, .text, \.id, \.pageIndex)
        add(linkAttachments, .link, \.id, \.pageIndex)
        add(model3DAttachments, .model3d, \.id, \.pageIndex)
        add(audioAttachments, .audio, \.id, \.pageIndex)
        add(commentPins, .pin, \.id, \.pageIndex)
        add(tapeAttachments, .tape, \.id, \.pageIndex)
        return out
    }

    /// 某一頁「鎖定在畫布上」的物件 ID。鎖定的物件不接收任何觸控（點選、拖曳、長按都穿透到頁面），
    /// 雙指縮放或捲動頁面時就不會誤點到手指底下的物件、讓它進入編輯狀態。
    /// 解除鎖定走圖層面板或物件選單（見 `ObjectLockMenuItem`）。與 Android `NotebookMeta.KEY_LOCKED_BY_PAGE` 同一個鍵。
    public var lockedObjectIdsByPage: [String: [String]]?

    public func lockedObjectIds(forPage page: Int) -> Set<String> {
        Set((lockedObjectIdsByPage?[String(page)] ?? []).map { $0.lowercased() })
    }

    /// 所有頁面鎖定的物件（不分頁）。物件 id 全域唯一，查「這個物件鎖了沒」不必先知道頁次。
    public var allLockedObjectIds: Set<String> {
        Set((lockedObjectIdsByPage ?? [:]).values.flatMap { $0 }.map { $0.lowercased() })
    }

    public mutating func setLockedObjectIds(_ ids: Set<String>, forPage page: Int) {
        var map = lockedObjectIdsByPage ?? [:]
        // 排序：同一組物件每次都寫出同一份內容，同步才不會誤判「有變動」。空的整頁拿掉。
        let normalized = ids.map { $0.lowercased() }
        map[String(page)] = normalized.isEmpty ? nil : normalized.sorted()
        lockedObjectIdsByPage = map.isEmpty ? nil : map
    }

    /// 以頁碼為鍵的名單（堆疊順序、筆跡下方、鎖定）照每個物件**現在所在的頁**重新歸位。
    ///
    /// 舊版同步在另一台搬頁、刪頁之後把本機的舊名單原封不動留下來，名單的頁碼與物件的頁碼
    /// 從此對不上：第 1 頁的堆疊順序列的是第 2 頁的物件、第 3 頁（已不存在）的鎖定名單鎖著
    /// 第 1 頁的方塊。這裡把每個 id 搬到它的物件實際所在的那一頁；找不到物件的 id 原地留著
    /// （可能是還沒同步到的物件，丟掉會讓它到的時候失去層級）。回傳有沒有動到。
    @discardableResult
    public mutating func realignPageKeyedObjectLists() -> Bool {
        var pageOf: [String: Int] = [:]
        func index<T: Identifiable & PageIndexed>(_ items: [T]?) where T.ID == String {
            for item in items ?? [] { pageOf[item.id.lowercased()] = item.pageIndex }
        }
        index(attachments); index(textAttachments); index(tableAttachments); index(shapeAttachments)
        index(connectionAttachments); index(linkAttachments); index(model3DAttachments)
        index(audioAttachments); index(commentPins); index(tapeAttachments); index(stickyAnchors)

        func realign(_ map: [String: [String]]?, sorted: Bool) -> [String: [String]]? {
            guard let map else { return nil }
            var out: [String: [String]] = [:]
            // 頁碼小的先放，同一頁裡維持原本的先後（堆疊順序要保住）。
            for key in map.keys.sorted(by: { (Int($0) ?? .max, $0) < (Int($1) ?? .max, $1) }) {
                for id in map[key] ?? [] {
                    let normId = id.lowercased()
                    let target = pageOf[normId].map(String.init) ?? key
                    if out[target]?.contains(where: { $0.caseInsensitiveCompare(normId) == .orderedSame }) == true { continue }
                    out[target, default: []].append(id)
                }
            }
            if sorted { out = out.mapValues { $0.sorted() } }
            return out
        }
        let order = realign(objectOrderByPage, sorted: false)
        let underInk = realign(underInkObjectIdsByPage, sorted: true)
        let overInk = realign(overInkObjectIdsByPage, sorted: true).flatMap { $0.isEmpty ? nil : $0 }
        let locked = realign(lockedObjectIdsByPage, sorted: true).flatMap { $0.isEmpty ? nil : $0 }
        let changed = order != objectOrderByPage || underInk != underInkObjectIdsByPage
            || overInk != overInkObjectIdsByPage || locked != lockedObjectIdsByPage
        objectOrderByPage = order
        underInkObjectIdsByPage = underInk
        overInkObjectIdsByPage = overInk
        lockedObjectIdsByPage = locked
        return changed
    }

    /// 檢查並修復座標超出所屬頁面邊界的物件（例如放置貼紙時跨頁拖曳但未換頁留下的幽靈物件）。
    /// 將它們歸入實際視覺所在的頁面，並將座標換算為新頁面的內部相對座標。
    @discardableResult
    public mutating func repairOutOfBoundsObjects() -> Bool {
        guard pageCount > 1 else { return false }
        var changed = false
        let totalPages = max(1, pageCount)
        let pageH = Float(PageGeometry.height)
        let pageW = Float(PageGeometry.width)
        let gap: Float = 20.0
        let inset = Float(PageGeometry.printableInset)

        if let items = attachments {
            var updatedItems = items
            for i in 0..<updatedItems.count {
                let item = updatedItems[i]
                if item.y >= CGFloat(pageH) || (item.y + item.height) < 0 {
                    let rect = FfiRect(
                        minX: Float(item.x),
                        minY: Float(item.y),
                        maxX: Float(item.x + item.width),
                        maxY: Float(item.y + item.height)
                    )
                    let landing = landOnPage(
                        rect: rect,
                        pageIndex: UInt32(max(0, item.pageIndex)),
                        pageCount: UInt32(totalPages),
                        pageWidth: pageW,
                        pageHeight: pageH,
                        pageGap: gap,
                        inset: inset
                    )
                    let targetPage = Int(landing.pageIndex)
                    if targetPage != item.pageIndex || CGFloat(landing.minY) != item.y {
                        updatedItems[i].pageIndex = targetPage
                        updatedItems[i].x = CGFloat(landing.minX)
                        updatedItems[i].y = CGFloat(landing.minY)
                        changed = true
                    }
                }
            }
            if changed {
                attachments = updatedItems
            }
        }
        if changed {
            realignPageKeyedObjectLists()
        }
        return changed
    }

    /// 系統預設標題的語系鍵。
    ///
    /// 內建的示範筆記若把中文標題直接寫死存進 JSON，切換介面語言時檔名不會跟著變
    /// —— 但標題同時又是使用者可以改的資料，不能每次都用翻譯覆蓋。折衷做法是記下
    /// 「這個標題還是系統給的」：顯示時翻譯，使用者一改名就清掉這個標記，
    /// 從此完全尊重使用者輸入。
    public var titleKey: String?
    /// 系統預設摘要的語系鍵，語意同 `titleKey`。
    public var snippetKey: String?

    /// 某一頁用的紙張樣板 id。取不到就是整本的那一個。
    public nonisolated func paperId(forPage index: Int) -> String {
        if let ids = pagePaperIds, index >= 0, index < ids.count, !ids[index].isEmpty {
            return ids[index]
        }
        return template.paperId
    }

    /// 某一頁的底紋。認不得的 id 退回整本的樣板 —— 未知的底紋比沒有底紋難解釋。
    public nonisolated func pageStyle(forPage index: Int) -> PageStyle {
        NoteTemplate(paperId: paperId(forPage: index))?.pageStyle ?? template.pageStyle
    }

    /// 把逐頁樣板陣列補到指定長度。
    ///
    /// 補的是整本的樣板，不是空字串：長度不足時取不到的那幾頁本來就是照
    /// 整本的樣板畫的，補一個空字串會讓它在某些路徑上變成「認不得的紙」。
    /// 補齊或截斷頁面 id 到 `pageCount` 頁（只在已經有 `pageIds` 時才動）。
    public nonisolated mutating func alignPageIds() {
        guard let ids = pageIds else { return }
        // 補的頁用確定性的 id（見 `NotebookPackageBridge.fallbackPageId`）：隨機的話每台裝置補出不同的頁。
        pageIds = NotebookPackageBridge.alignedPageIds(
            ids, count: pageCount, package: nil, notebookId: id)
    }

    public nonisolated mutating func padPagePaperIds(to count: Int) {
        var ids = pagePaperIds ?? []
        while ids.count < count { ids.append(template.paperId) }
        pagePaperIds = ids
    }

    /// 顯示用標題：系統預設標題會跟著介面語言走。
    ///
    /// 範例的名字後面標「（唯讀）」（見 `isReadOnlySample`）。
    @MainActor
    public func displayTitle(_ l10n: LocalizationManager = .shared) -> String {
        let base = baseDisplayTitle(l10n)
        guard isReadOnlySample else { return base }
        return base + l10n.localized("sample_readonly_suffix")
    }

    /// 不含「（唯讀）」的標題。由範例複製出的筆記本以它命名。
    @MainActor
    public func baseDisplayTitle(_ l10n: LocalizationManager = .shared) -> String {
        guard let key = titleKey else { return title }
        return l10n.localized(key)
    }

    /// 這本是不是「範例」：打開後的改動先放暫存區、離開時再決定（見 `NotebookStore.beginSampleSession`）。
    /// 使用者設定過就照設定（`sampleFlag`），沒設定過的話內建範例是、其他不是。
    public var isReadOnlySample: Bool { sampleFlag ?? NotebookPackageBridge.isDeviceLocalSeed(id) }

    /// 六種語言的 `created_on` 前綴（`%@` 之前的字），用來認出舊筆記存下的「建立於 …」。
    @MainActor private static let createdOnPrefixes: [String] = {
        AppLanguage.allCases.compactMap { lang in
            LocalizationManager.generatedStrings["created_on"]?[lang]?
                .components(separatedBy: "%@").first
        }.filter { !$0.isEmpty }
    }()

    @MainActor static func isCreatedOnSnippet(_ text: String) -> Bool {
        createdOnPrefixes.contains { text.hasPrefix($0) }
    }

    /// 顯示用摘要，語意同 `displayTitle`。
    @MainActor
    public func displaySnippet(_ l10n: LocalizationManager = .shared) -> String? {
        if let key = snippetKey { return l10n.localized(key) }
        // 「建立於 <日期>」是建立當下存下來的整句話 —— 語言與日期格式都是那一刻的。
        // 換了介面語言之後它還是舊語言，所以認出這種句子就依建立時間重新組。
        if let stored = previewSnippet, Self.isCreatedOnSnippet(stored) {
            return String(
                format: l10n.localized("created_on"),
                LocalizationManager.formatted(createdAt, date: .abbreviated, time: .shortened))
        }
        return previewSnippet
    }

    /// 頁面高度。**固定值** —— 每一頁都一樣高。
    ///
    /// 舊版可以任意延長頁面，於是同一本筆記裡每頁高度都不同，匯出與列印無從
    /// 對齊紙張。現在高度由 `PageGeometry` 決定；`pageHeights` 這個欄位只為了
    /// 舊檔解碼而保留，遷移時用來判斷哪些頁需要重新分頁（見 `PageRepagination`）。
    /// 這一本筆記的頁面尺寸。
    public var pageSize: CGSize { PageGeometry.size(forFormat: pageFormatId) }

    /// 這一本筆記某一頁的高度。
    ///
    /// 取的是**這一本自己的**規格，不是 `PageGeometry.height`。後者是
    /// 「目前螢幕上那一本」的高度（`PageGeometry.currentSize`），同步一次
    /// 要匯出幾十本、其中只有一本在螢幕上，用那個值等於把作用中筆記的頁高
    /// 寫進所有其他筆記 —— 規格不同的那些在另一台裝置上就會變形。
    ///
    /// 也因為 `PageGeometry.height` 走 `MainActor.assumeIsolated`（在背景
    /// 執行緒上直接 trap），連當作**預設參數**都不行 —— 預設參數是在呼叫端
    /// 求值的。匯出搬離主執行緒就是卡在這裡。`pageSize` 走的是純函式
    /// `PageGeometry.size(forFormat:)`，哪個執行緒都成立。
    ///
    /// `pageIndex` 目前用不到：頁高早就統一由規格決定，不再逐頁記錄
    /// （舊檔的 `pageHeights` 只有遷移會讀，見 `legacyHeight(forPage:)`）。
    /// 保留參數是因為分頁一旦回到「每頁可不同」，簽名不必再動一次。
    ///
    /// 原本還有一個 `defaultHeight` 參數，而函式主體**從來沒有用過它** ——
    /// 編輯器那邊一直傳 1800 進來，也一直沒有生效。拿掉，而不是留著：
    /// 一個被默默忽略的參數看起來像是有作用的。
    // unused-param-ok: 頁高統一由規格決定，不再逐頁記錄；保留參數是為了分頁
    // 一旦回到「每頁可不同」時簽章不必再動一次（理由見上方說明）。
    public func height(forPage pageIndex: Int) -> CGFloat {
        pageSize.height
    }

    /// 舊版存下來的頁面高度。只有遷移會用到。
    public func legacyHeight(forPage pageIndex: Int) -> CGFloat? {
        guard let heights = pageHeights, pageIndex >= 0, pageIndex < heights.count else {
            return nil
        }
        return heights[pageIndex]
    }

    public init(
        id: String = UUID().uuidString.lowercased(),
        title: String,
        createdAt: Date = Date(),
        lastModifiedDate: Date = Date(),
        pageCount: Int = 1,
        hasRecording: Bool = false,
        previewSnippet: String? = nil,
        template: NoteTemplate = .blank,
        recordingAudioPath: String? = nil,
        folderId: String? = nil,
        pagesData: [Data] = [],
        pageHeights: [CGFloat]? = nil,
        attachments: [NoteImageAttachment]? = [],
        textAttachments: [NoteTextAttachment]? = [],
        linkAttachments: [NoteLinkAttachment]? = [],
        model3DAttachments: [Note3DAttachment]? = [],
        commentPins: [NoteCommentPin]? = [],
        tableAttachments: [NoteTableAttachment]? = [],
        shapeAttachments: [NoteShapeAttachment]? = [],
        connectionAttachments: [NoteConnectionAttachment]? = [],
        audioAttachments: [NoteAudioAttachment]? = [],
        checkedGuideItems: [String: Bool]? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastModifiedDate = lastModifiedDate
        self.pageCount = max(1, pageCount)
        self.hasRecording = hasRecording
        self.previewSnippet = previewSnippet
        self.template = template
        self.recordingAudioPath = recordingAudioPath
        self.folderId = folderId
        self.pageHeights = pageHeights
        self.tableAttachments = tableAttachments ?? []
        self.shapeAttachments = shapeAttachments ?? []
        self.connectionAttachments = connectionAttachments ?? []
        self.attachments = attachments ?? []
        self.textAttachments = textAttachments ?? []
        self.linkAttachments = linkAttachments ?? []
        self.model3DAttachments = model3DAttachments ?? []
        self.commentPins = commentPins ?? []
        self.audioAttachments = audioAttachments ?? []
        self.checkedGuideItems = checkedGuideItems
        if pagesData.isEmpty {
            // 預設建立一頁空白筆劃
            let emptyDrawing = PKDrawing()
            self.pagesData = [emptyDrawing.dataRepresentation()]
        } else {
            self.pagesData = pagesData
        }
    }
}

/// 圖片風格濾鏡
public enum ImageFilterStyle: String, Codable, CaseIterable, Identifiable {
    case original = "原圖"
    case vintage = "復古"
    case mono = "黑白"
    case contrast = "清晰"
    case warm = "柔光"

    public var id: String { rawValue }

    /// 顯示名稱的語系鍵。rawValue 是持久化用的識別字，不可拿來顯示 ——
    /// 那會讓濾鏡名稱永遠是中文。
    public var localizationKey: String {
        switch self {
        case .original: return "filter_original"
        case .vintage: return "filter_vintage"
        case .mono: return "filter_mono"
        case .contrast: return "filter_contrast"
        case .warm: return "filter_warm"
        }
    }
}

/// 外觀材料屬性（支援 3D 模型 PBR 物理反射與 2D 圖片材質濾鏡）
public enum MaterialType: String, Codable, CaseIterable, Identifiable {
    case plastic = "塑膠"
    case gold = "黃金"
    case silver = "白銀"
    case copper = "紅銅"
    case iron = "鋼鐵"
    case wood = "原木"
    case marble = "大理石"
    case granite = "花崗岩"
    case obsidian = "黑曜石"

    public var id: String { rawValue }

    public var localizationKey: String {
        switch self {
        case .plastic: return "mat_plastic"
        case .gold: return "mat_gold"
        case .silver: return "mat_silver"
        case .copper: return "mat_copper"
        case .iron: return "mat_iron"
        case .wood: return "mat_wood"
        case .marble: return "mat_marble"
        case .granite: return "mat_granite"
        case .obsidian: return "mat_obsidian"
        }
    }
}

/// 筆記內嵌圖片與圖表附件模型
/// 附著在某一頁上的東西。
///
/// 刪除或插入頁面時要把 `pageIndex` 重新對齊，而那段邏輯每個型別各寫一份
/// 的結果是新增型別時漏掉其中一種 —— 使用者會在別的頁上看到一張不該在
/// 那裡的表格。有了這個協定，共用的那份程式碼只要寫一次。
public protocol PageIndexed {
    var pageIndex: Int { get set }
}

public struct NoteImageAttachment: Identifiable, Codable, Hashable, ObjectFrameStyled {
    public let id: String
    /// 協定橋接。圖片的旋轉欄位早就存在且是非 Optional，沿用即可。
    public var canvasRotation: Double {
        get { rotationDegrees }
        set { rotationDegrees = newValue }
    }
    public var fileName: String
    public var pageIndex: Int
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    public var rotationDegrees: Double
    public var cornerRadius: CGFloat
    public var hasShadow: Bool
    public var hasBorder: Bool
    public var filterStyle: ImageFilterStyle
    public var materialType: MaterialType?
    /// 邊框顏色。舊檔沒有這個欄位，`nil` 時沿用原本的強調色。
    public var borderColorHex: String?
    /// 邊框粗細。`nil` 時沿用原本的 2.5。
    public var borderWidth: CGFloat?
    /// 方框底色。`"clear"` 為透明；`nil` 時不畫底色（圖片本來就是滿版的）。
    public var backgroundColorHex: String?
    /// 這張圖如果是數字製圖，這裡放它的設定 JSON（見 `ChartSpec`）。
    ///
    /// 有了它，圖表才**改得動**：重新編修時讀回原本的數字與樣式，而不是
    /// 面對一張只能刪掉重做的點陣圖。`nil` 代表這是一般的圖片。
    /// 這份 JSON 也會寫進 `.padnote` 套件的區塊外觀，所以在 Android 上
    /// 一樣改得動。
    public var chartSpecJSON: String?
    /// 這張圖如果是算式便簽，這裡放原本輸入的算式表達式字串（例如 "125 * 8 + 45"）。
    /// 有了它，算式卡片才能重新召喚原生的 MathCalculatorSheet 進行編輯與重新求值。
    public var mathFormula: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        fileName: String,
        pageIndex: Int = 0,
        x: CGFloat = 80,
        y: CGFloat = 120,
        width: CGFloat = 280,
        height: CGFloat = 200,
        rotationDegrees: Double = 0,
        cornerRadius: CGFloat = 8,
        hasShadow: Bool = true,
        hasBorder: Bool = false,
        filterStyle: ImageFilterStyle = .original,
        materialType: MaterialType? = nil,
        borderColorHex: String? = nil,
        borderWidth: CGFloat? = nil,
        backgroundColorHex: String? = nil,
        chartSpecJSON: String? = nil,
        mathFormula: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.pageIndex = pageIndex
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotationDegrees = rotationDegrees
        self.cornerRadius = cornerRadius
        self.hasShadow = hasShadow
        self.hasBorder = hasBorder
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.backgroundColorHex = backgroundColorHex
        self.chartSpecJSON = chartSpecJSON
        self.mathFormula = mathFormula
        self.filterStyle = filterStyle
        self.materialType = materialType
    }

    /// 這張圖的圖表設定，讀得回來才回傳。
    ///
    /// 讀不回來時回 `nil` 而不是丟出錯誤：規格壞掉最多是「這張圖改不動了」，
    /// 不該讓整本筆記開不起來。
    public var chartSpec: ChartSpec? {
        chartSpecJSON.flatMap(ChartSpec.decode(from:))
    }
}

/// 筆記內嵌 3D 模型附件模型
public struct Note3DAttachment: Identifiable, Codable, Hashable, ObjectFrameStyled {
    public let id: String
    /// 畫布旋轉角度。**必須是 Optional** —— 見 `ObjectFrameStyled.canvasRotation`
    /// 的說明：非 Optional 會讓舊筆記整批解碼失敗而消失。
    public var rotationDegrees: Double?
    public var canvasRotation: Double {
        get { rotationDegrees ?? 0 }
        set { rotationDegrees = newValue }
    }
    public var pageIndex: Int
    public var title: String
    public var modelTypeRaw: String // "cube", "sphere", "cylinder", "torus", "pyramid", "capsule"
    /// 匯入的模型檔名（在 `Attachments` 目錄下）。`nil` 代表用內建幾何體。
    ///
    /// **必須是 Optional** —— 非 Optional 的新欄位會讓舊筆記整份解碼失敗，
    /// 而載入走的是 `try?`：使用者的筆記會**整批靜默消失**
    /// （見 `ObjectFrameStyled.canvasRotation` 的說明）。
    public var importedFileName: String?
    /// 使用者原本的檔名，只拿來顯示。
    ///
    /// 存這一個是因為 `importedFileName` 是 `imp_<uuid>.usdz` 這種內部名字
    /// —— 拿它當標題的話，使用者在自己的筆記裡看到一串 UUID。
    public var importedDisplayName: String?
    public var materialType: MaterialType
    public var rotationX: Float
    public var rotationY: Float
    public var rotationZ: Float
    public var scale: Float
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    /// 是否畫邊框。
    public var hasBorder: Bool
    /// 邊框顏色。`nil` 時沿用該型別原本的預設色。
    public var borderColorHex: String?
    /// 邊框粗細。`nil` 時沿用原本的預設。
    public var borderWidth: CGFloat?
    /// 方框底色。`"clear"` 為透明；`nil` 時沿用原本的預設底色。
    public var backgroundColorHex: String?
    public var cornerRadius: CGFloat

    public init(
        id: String = UUID().uuidString.lowercased(),
        pageIndex: Int = 0,
        title: String = L10n.t("model3d_default_title"),
        modelTypeRaw: String = "sphere",
        materialType: MaterialType = .gold,
        rotationX: Float = 0.4,
        rotationY: Float = 0.6,
        rotationZ: Float = 0.0,
        scale: Float = 1.0,
        x: CGFloat = 80,
        y: CGFloat = 160,
        width: CGFloat = 280,
        height: CGFloat = 240,
        hasBorder: Bool = true,
        borderColorHex: String? = nil,
        borderWidth: CGFloat? = nil,
        backgroundColorHex: String? = nil,
        cornerRadius: CGFloat = 12,
        importedFileName: String? = nil,
        importedDisplayName: String? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.title = title
        self.modelTypeRaw = modelTypeRaw
        self.importedFileName = importedFileName
        self.importedDisplayName = importedDisplayName
        self.materialType = materialType
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
        self.scale = scale
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.hasBorder = hasBorder
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.backgroundColorHex = backgroundColorHex
        self.cornerRadius = cornerRadius
    }
}

/// 筆記內嵌 Word 級文字方塊附件模型
public struct NoteTextAttachment: Identifiable, Codable, Hashable, ObjectFrameStyled {
    public let id: String
    /// 畫布旋轉角度。**必須是 Optional** —— 見 `ObjectFrameStyled.canvasRotation`
    /// 的說明：非 Optional 會讓舊筆記整批解碼失敗而消失。
    public var rotationDegrees: Double?
    public var canvasRotation: Double {
        get { rotationDegrees ?? 0 }
        set { rotationDegrees = newValue }
    }
    public var pageIndex: Int
    public var text: String
    public var fontSize: CGFloat
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var isStrikethrough: Bool
    public var fontFamily: String?
    public var alignmentRaw: String // "left", "center", "right", "justified"
    public var textColorHex: String // e.g. "#000000"
    /// e.g. "#FFFFFF"、"#FFF9C4"、"clear"（透明）
    public var backgroundColorHex: String?
    public var hasBorder: Bool
    public var cornerRadius: CGFloat
    /// 邊框顏色（舊檔沒有這個欄位，解碼時會落到預設值）
    public var borderColorHex: String?
    /// 邊框粗細
    public var borderWidth: CGFloat?
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    // MARK: - 段落
    //
    // 全部是 Optional：舊檔沒有這些欄位，解碼後是 nil，套用系統預設 ——
    // 升級上來的筆記排版不會變。

    /// 行距（點）。`nil` 為系統預設。
    public var lineSpacing: CGFloat?
    /// 段落之間的額外間距（點）。
    public var paragraphSpacing: CGFloat?
    /// 首行縮排（點）。
    public var firstLineIndent: CGFloat?
    /// 整段縮排（點）。
    public var paragraphIndent: CGFloat?

    /// 逐字格式（見 `RichText`）。`nil` = 整個方塊同一種格式。舊檔沒有這個欄位。
    public var runs: [TextStyleRun]? = nil

    public init(
        id: String = UUID().uuidString.lowercased(),
        pageIndex: Int = 0,
        text: String = L10n.t("text_default_content"),
        fontSize: CGFloat = 16,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        alignmentRaw: String = "left",
        textColorHex: String = "#000000",
        backgroundColorHex: String = "#FFFFFF",
        hasBorder: Bool = true,
        cornerRadius: CGFloat = 8,
        borderColorHex: String? = nil,
        borderWidth: CGFloat? = nil,
        x: CGFloat = 100,
        y: CGFloat = 150,
        width: CGFloat = 300,
        height: CGFloat = 160,
        lineSpacing: CGFloat? = nil,
        paragraphSpacing: CGFloat? = nil,
        firstLineIndent: CGFloat? = nil,
        paragraphIndent: CGFloat? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.text = text
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.alignmentRaw = alignmentRaw
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.hasBorder = hasBorder
        self.cornerRadius = cornerRadius
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.firstLineIndent = firstLineIndent
        self.paragraphIndent = paragraphIndent
    }
}

/// 手寫筆劃與文字方塊動態流式錨定 (Fluid Sticky Annotations)
public struct StickyAnnotationAnchor: Identifiable, Codable, Hashable {
    public let id: String
    public var pageIndex: Int
    public var targetId: String
    public var strokeIndices: [Int]?
    public var strokeIds: [String]?
    public var anchorOriginX: Float
    public var anchorOriginY: Float
    public var createdAtMs: Int64

    public init(
        id: String = UUID().uuidString.lowercased(),
        pageIndex: Int = 0,
        targetId: String,
        strokeIndices: [Int]? = nil,
        strokeIds: [String]? = nil,
        anchorOriginX: Float = 0,
        anchorOriginY: Float = 0,
        createdAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.targetId = targetId
        self.strokeIndices = strokeIndices
        self.strokeIds = strokeIds
        self.anchorOriginX = anchorOriginX
        self.anchorOriginY = anchorOriginY
        self.createdAtMs = createdAtMs
    }
}

/// 筆記內嵌網頁連結預覽附件模型
public struct NoteLinkAttachment: Identifiable, Codable, Hashable, ObjectFrameStyled {
    public let id: String
    /// 畫布旋轉角度。**必須是 Optional** —— 見 `ObjectFrameStyled.canvasRotation`
    /// 的說明：非 Optional 會讓舊筆記整批解碼失敗而消失。
    public var rotationDegrees: Double?
    public var canvasRotation: Double {
        get { rotationDegrees ?? 0 }
        set { rotationDegrees = newValue }
    }
    public var pageIndex: Int
    public var urlString: String
    public var title: String
    public var descriptionText: String
    public var siteName: String
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    /// 是否畫邊框。
    public var hasBorder: Bool
    /// 邊框顏色。`nil` 時沿用該型別原本的預設色。
    public var borderColorHex: String?
    /// 邊框粗細。`nil` 時沿用原本的預設。
    public var borderWidth: CGFloat?
    /// 方框底色。`"clear"` 為透明；`nil` 時沿用原本的預設底色。
    public var backgroundColorHex: String?
    public var cornerRadius: CGFloat

    public init(
        id: String = UUID().uuidString.lowercased(),
        pageIndex: Int = 0,
        urlString: String,
        title: String = "",
        descriptionText: String = "",
        siteName: String = "",
        x: CGFloat = 80,
        y: CGFloat = 180,
        width: CGFloat = 320,
        height: CGFloat = 120,
        hasBorder: Bool = true,
        borderColorHex: String? = nil,
        borderWidth: CGFloat? = nil,
        backgroundColorHex: String? = nil,
        cornerRadius: CGFloat = 10
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.urlString = urlString
        self.title = title
        self.descriptionText = descriptionText
        self.siteName = siteName
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.hasBorder = hasBorder
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.backgroundColorHex = backgroundColorHex
        self.cornerRadius = cornerRadius
    }
}

/// 筆記內嵌討論留言訊息模型
public struct NoteCommentMessage: Identifiable, Codable, Hashable {
    public let id: String
    public let authorId: String
    public let authorName: String
    public let authorColor: String
    public var text: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString.lowercased(),
        authorId: String,
        authorName: String,
        authorColor: String,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorColor = authorColor
        self.text = text
        self.createdAt = createdAt
    }
}

/// 筆記內嵌討論圖釘模型
public struct NoteCommentPin: Identifiable, Codable, Hashable {
    public let id: String
    public var pageIndex: Int
    public var x: CGFloat
    public var y: CGFloat
    public let authorId: String
    public let authorName: String
    public let authorColor: String
    public let createdAt: Date
    public var isResolved: Bool
    public var messages: [NoteCommentMessage]

    public init(
        id: String = UUID().uuidString.lowercased(),
        pageIndex: Int = 0,
        x: CGFloat,
        y: CGFloat,
        authorId: String,
        authorName: String,
        authorColor: String,
        createdAt: Date = Date(),
        isResolved: Bool = false,
        messages: [NoteCommentMessage] = []
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.x = x
        self.y = y
        self.authorId = authorId
        self.authorName = authorName
        self.authorColor = authorColor
        self.createdAt = createdAt
        self.isResolved = isResolved
        self.messages = messages
    }
}

/// 一個里程碑快照（時光機）。
///
/// # 這裡為什麼沒有內容
///
/// 舊版把整份 `NotebookDocument` 與每一頁的 `PKDrawing` 編碼塞在這個結構裡 ——
/// 一份完整副本。那個做法有三個問題：`PKDrawing` 是 Apple 私有格式，
/// Android 讀不出來；還原是整份覆蓋，會默默吃掉另一台裝置同時寫進來的東西；
/// 而且每建一次就多一份完整副本。
///
/// 現在快照住在核心（`padnote_doc::milestone`），記的是**歷史上的一刀**
/// —— 一組向量時鐘，幾百個位元組，兩個平台讀的是同一份資料。
public struct NotebookMilestoneSnapshot: Identifiable, Codable, Equatable {
    public let id: String
    public let notebookId: String
    public let title: String
    public let creatorName: String
    public let createdAt: Date
    /// 執行還原前自動建立的。UI 要跟使用者自己命名的分開，
    /// 否則按幾次還原之後清單就被系統產生的項目淹沒。
    public let automatic: Bool
    /// 舊版 `.snapshot` 檔留下來的。**唯讀** ——
    /// 舊檔是內容副本，換不成「一刀」，但也不該默默把使用者的東西丟掉。
    public let isLegacy: Bool

    public init(
        id: String,
        notebookId: String,
        title: String,
        creatorName: String,
        createdAt: Date,
        automatic: Bool = false,
        isLegacy: Bool = false
    ) {
        self.id = id
        self.notebookId = notebookId
        self.title = title
        self.creatorName = creatorName
        self.createdAt = createdAt
        self.automatic = automatic
        self.isLegacy = isLegacy
    }
}

/// 錄音項目資料模型
public struct AudioRecordingRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var durationSeconds: Int
    public var recordedDate: Date
    public var transcriptionStatus: String
    public var isTranscribed: Bool
    public var fileName: String
    public var linkedNotebookId: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        title: String,
        durationSeconds: Int,
        recordedDate: Date = Date(),
        transcriptionStatus: String = "已完成",
        isTranscribed: Bool = true,
        fileName: String,
        linkedNotebookId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.durationSeconds = durationSeconds
        self.recordedDate = recordedDate
        self.transcriptionStatus = transcriptionStatus
        self.isTranscribed = isTranscribed
        self.fileName = fileName
        self.linkedNotebookId = linkedNotebookId
    }
}

/// 頁面上的錄音物件。
///
/// # 為什麼不沿用 `recordingAudioPath`
///
/// 那個欄位是「整本筆記一段錄音」，沒有座標也沒有頁次 —— 使用者在首頁錄完，
/// 打開筆記本後那段錄音不在任何一頁上，也就無從擺放。要做到「插在第 3 頁
/// 這一段筆記旁邊」，錄音必須是一個**有位置的物件**，和圖片、表格同一層級。
///
/// `recordingId` 指向 `AudioRecordingRecord`；`fileName` 同時存一份，
/// 是為了錄音索引被刪掉時卡片還播得出來 —— 檔案還在，只是清單裡沒有了。
public struct NoteAudioAttachment: Identifiable, Codable, Hashable, ObjectFrameStyled {
    public let id: String
    /// 畫布旋轉角度。**必須是 Optional** —— 見 `ObjectFrameStyled.canvasRotation`。
    public var rotationDegrees: Double?
    public var canvasRotation: Double {
        get { rotationDegrees ?? 0 }
        set { rotationDegrees = newValue }
    }
    public var pageIndex: Int
    /// 對應的錄音索引 id。索引被刪掉時仍然保留，播放走 `fileName`。
    public var recordingId: String
    /// 音檔檔名。
    ///
    /// 位置由 `NotebookStore.recordingFileURL(fileName:notebookId:)` 決定：
    /// 新的錄音住在所屬筆記本套件的 `media/audio/`（會被同步），
    /// 還沒遷移的舊錄音在 `Kairumo Record`（套件外，不會被同步）。
    public var fileName: String
    public var title: String
    public var durationSeconds: Int
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    public var hasBorder: Bool
    public var cornerRadius: CGFloat
    public var borderColorHex: String?
    public var borderWidth: CGFloat?
    /// `"clear"` 為透明。
    public var backgroundColorHex: String?
    /// 關聯的轉譯文字方塊 ID（避免重複轉譯產生多個相同的文字方塊）。
    public var transcriptTextId: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        pageIndex: Int = 0,
        recordingId: String = "",
        fileName: String,
        title: String = "",
        durationSeconds: Int = 0,
        x: CGFloat = 80,
        y: CGFloat = 120,
        // 預設尺寸照卡片內容抓：一行標題 + 一行時間 + 播放鈕。
        // 太大的話使用者拿到的第一件事是縮小它。
        width: CGFloat = 260,
        height: CGFloat = 76,
        rotationDegrees: Double? = nil,
        hasBorder: Bool = true,
        cornerRadius: CGFloat = 12,
        borderColorHex: String? = nil,
        borderWidth: CGFloat? = nil,
        backgroundColorHex: String? = nil,
        transcriptTextId: String? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.recordingId = recordingId
        self.fileName = fileName
        self.title = title
        self.durationSeconds = durationSeconds
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotationDegrees = rotationDegrees
        self.hasBorder = hasBorder
        self.cornerRadius = cornerRadius
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.backgroundColorHex = backgroundColorHex
        self.transcriptTextId = transcriptTextId
    }
}

/// 筆記資料持久化中樞
@MainActor
public final class NotebookStore: ObservableObject {
    // profile-scope: profile 每個設定檔各有一份狀態，切換時必須重設
    public static let shared = NotebookStore()

    @Published public var notebooks: [NotebookDocument] = []
    @Published public var recordings: [AudioRecordingRecord] = []
    @Published public var folders: [FolderItem] = []
    /// 根資料夾名稱。空字串代表「使用者沒有自訂」，顯示時走語系預設值。
    @Published public var rootFolderName: String = ""
    /// 目前正在檢視／編輯的作用中筆記本 ID（供雙軌同步優先排程使用）
    @Published public var activeNotebookId: String? = nil

    /// 顯示用根資料夾名稱。
    public var displayRootFolderName: String {
        rootFolderName.isEmpty
            ? LocalizationManager.shared.localized("default_root_folder")
            : rootFolderName
    }

    private let rootFolderNameKey = "kairumo.notebooks.rootFolderName"

    /// 舊版寫死的根資料夾預設名稱。
    ///
    /// 舊版每次存檔都會把這個預設值寫進 UserDefaults，所以升級上來的使用者看起來
    /// 像是「已經自訂過名稱」，切語言時名稱不會跟著變。認得出這幾個字串就當成
    /// 未自訂，交還給語系處理；使用者真的把資料夾取名叫「我的筆記」的話，
    /// 顯示結果在中文介面下完全一樣，不會有感。
    private static let legacyDefaultRootNames: Set<String> = ["我的筆記", "我的笔记", "My Notes"]

    /// 資料根目錄。備份與同步都要知道它在哪。
    public var documentsDirectory: URL { documentsDir }

    /// 測試用的資料根目錄（S-92）。`nil` 時用真正的文件目錄。
    ///
    /// 測試原本直接操作 `NotebookStore.shared`，而 `deletePage` / `transferPages`
    /// 內部都會 `persistData()` —— 於是**跑完測試，使用者的筆記清單裡就多
    /// 幾本叫「測試」的筆記**（`defer` 只把陣列裡那幾筆移掉，沒有再存一次）。
    /// 模擬器上看得很清楚。
    private let documentsRootOverride: URL?

    private var documentsDir: URL {
        documentsRootOverride
            ?? DocumentStorageLocation.shared.libraryRootURL
    }

    private var notebooksFile: URL {
        documentsDir.appending(path: "notebooks_v1.json")
    }

    private var recordingsFile: URL {
        documentsDir.appending(path: "recordings_v1.json")
    }

    private var foldersFile: URL {
        documentsDir.appending(path: "folders_v1.json")
    }

    private var trashFile: URL {
        documentsDir.appending(path: "trash_v1.json")
    }

    private init() {
        StartupLogger.logKey("log_store_init_begin")
        documentsRootOverride = nil
        loadAndSeed()
        StartupLogger.logKey("log_store_init_done")

        // 錄音檔案掃描與時長校正非關鍵啟動路徑，改為真正非同步於背景佇列執行，
        // 避免在主執行緒上開啟所有套件及讀取龐大音檔，徹底消除 App 啟動凍結 (卡頓數秒)。
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshRecordings()
        }
    }

    /// 讀目前設定檔的資料；是空的就放範例筆記。`init` 與切換設定檔共用。
    private func loadAndSeed() {
        loadData()
        if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
            for id in pendingSampleSessionIds {
                finishSampleSession(id, choice: .discard)
            }
        }
        let nonInbox = notebooks.filter {
            $0.id.caseInsensitiveCompare(recordingInboxNotebookId()) != .orderedSame
        }
        if nonInbox.isEmpty {
            StartupLogger.logKey("log_store_seed_create")
            seedDefaultNotebooks()
            // 剛產生的就是標準內容，不必再被「重設」一次。
            ProfileDefaults.current.set(Self.seedGeneration, forKey: Self.seedGenerationKey)
        } else {
            StartupLogger.logKey("log_store_seed_check")
            backfillEmptySeedNotebooks()
        }
        injectInteractionFixturesIfRequested()
        injectInkInvariantFixtureIfRequested()
    }

    /// 筆跡不變式矩陣專用筆記本的 id（`InkInvariantMatrix` 靠它從首頁找到這本）。
    static let inkInvariantFixtureNotebookId = "uitest-ink-notebook"

    /// 筆跡不變式矩陣每一頁預先放的筆畫數。**彼此都不同**：
    /// 筆跡跑到別頁（以頁序號當 key 的 bug）時，數字一定對不上。
    static let inkInvariantFixtureStrokeCounts = [3, 5, 2]

    /// UI 測試專用（`KAIRUMO_UITEST_SEED_INK=1`）：建立一本三頁、每頁筆畫數不同的筆記。
    ///
    /// 架構審視 P0：使用者回報「切模式／點縮圖之後整頁變白」。矩陣測試在每個操作之後
    /// 讀畫布的 `strokes:N`，跟這裡寫的數字比 —— 不靠截圖、不靠人眼。
    /// 每次啟動都重建，上一輪測試畫上去的筆畫不會讓這一輪的預期值失準。
    private func injectInkInvariantFixtureIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["KAIRUMO_UITEST"] == "1", env["KAIRUMO_UITEST_SEED_INK"] == "1" else { return }
        let nbId = Self.inkInvariantFixtureNotebookId
        let counts = Self.inkInvariantFixtureStrokeCounts
        notebooks.removeAll { $0.id == nbId }
        // 清掉上一輪留下的頁面檔案（含專業筆畫與核心套件），只留這一輪寫的。
        if let files = try? FileManager.default.contentsOfDirectory(atPath: drawingsDirectory.path) {
            for f in files where f.hasPrefix("\(nbId)_") {
                try? FileManager.default.removeItem(at: drawingsDirectory.appending(path: f))
            }
        }
        let doc = NotebookDocument(id: nbId, title: "Ink Invariants", pageCount: counts.count)
        for (page, n) in counts.enumerated() {
            let ink = PKInk(.pen, color: .black)
            let strokes: [PKStroke] = (0..<n).map { k in
                let y = CGFloat(120 + k * 60)
                let pts = (0..<8).map { i in
                    PKStrokePoint(
                        location: CGPoint(x: 80 + CGFloat(i) * 30, y: y + CGFloat(i % 2) * 6),
                        timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: 3, height: 3),
                        opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
                }
                return PKStroke(ink: ink, path: PKStrokePath(controlPoints: pts, creationDate: Date()))
            }
            saveDrawing(notebookId: nbId, pageIndex: page, drawing: PKDrawing(strokes: strokes))
        }
        notebooks.append(doc)
        persistData(signalsLocalEdit: false)
    }

    /// 互動矩陣專用筆記本的 id（`InteractionMatrixAudit` 靠它從首頁找到這本）。
    static let interactionFixtureNotebookId = "uitest-matrix-notebook"

    /// UI 測試專用（`KAIRUMO_UITEST_SEED_OBJECTS=1`）：建立一本**專用的**空白筆記，第 1 頁上每種物件各一個，
    /// 互動矩陣（`InteractionMatrixAudit`）才有東西可以點。
    ///
    /// 獨立一本而不是塞進歡迎筆記：歡迎筆記已經有內容，物件會疊在別的東西上；
    /// 而且位置全放在頁面上半部，橫式（可視高度短）也在畫面裡，量到的是「點不點得到」而不是「要不要捲」。
    /// 音檔是真的 Ogg-Opus（核心編碼器產生），播放鈕走真實的播放管線。固定 id、冪等；沒設環境變數時完全不動。
    private func injectInteractionFixturesIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["KAIRUMO_UITEST"] == "1", env["KAIRUMO_UITEST_SEED_OBJECTS"] == "1" else { return }
        let nbId = Self.interactionFixtureNotebookId
        // 每次啟動都重建：上一輪測試刪掉的物件不能讓這一輪少一格。
        notebooks.removeAll { $0.id == nbId }
        var doc = NotebookDocument(id: nbId, title: "Interaction Matrix", pageCount: 1)

        let audioName = "uitest-fixture.opus"
        let audioURL = AudioRecorderManager.shared.recordingsDirectory.appending(path: audioName)
        if !FileManager.default.fileExists(atPath: audioURL.path) {
            let pcm = (0..<32_000).map { Float(sin(Double($0) * 2 * .pi * 440 / 16_000)) * 0.4 }
            _ = audioEncodePcmToOpus(pcm16kMono: pcm, outPath: audioURL.path)
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        let png = renderer.image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }
        doc.audioAttachments = [NoteAudioAttachment(
            id: "00000000-0000-4000-8000-0000000000a1", pageIndex: 0, recordingId: "uitest",
            fileName: audioName, title: "Fixture audio", durationSeconds: 2, x: 60, y: 40)]
        if let name = saveAttachmentImage(png) {
            doc.attachments = [NoteImageAttachment(
                id: "00000000-0000-4000-8000-0000000000a2", fileName: name, pageIndex: 0, x: 440, y: 40,
                width: 120, height: 120, rotationDegrees: 0, cornerRadius: 0, hasShadow: false,
                hasBorder: false, filterStyle: .original, chartSpecJSON: nil)]
        }
        doc.linkAttachments = [NoteLinkAttachment(
            id: "00000000-0000-4000-8000-0000000000a4", pageIndex: 0, urlString: "https://example.com",
            title: "Fixture link", x: 60, y: 200, width: 300, height: 100)]
        doc.textAttachments = [NoteTextAttachment(
            id: "00000000-0000-4000-8000-0000000000a3", pageIndex: 0, text: "Fixture text",
            x: 440, y: 200, width: 280, height: 80)]
        doc.shapeAttachments = [NoteShapeAttachment(
            id: "00000000-0000-4000-8000-0000000000a5", pageIndex: 0, kindName: "process",
            x: 60, y: 360, width: 160, height: 80, label: "Fixture shape")]
        // `KAIRUMO_UITEST_SEED_TWO_PAGES=1`：兩頁，第 1 頁多一個表格（測連續模式把物件拖到下一頁）。
        if env["KAIRUMO_UITEST_SEED_TWO_PAGES"] == "1" {
            doc.pageCount = 2
            doc.tableAttachments = [NoteTableAttachment(
                id: "00000000-0000-4000-8000-0000000000a6", pageIndex: 0,
                x: 440, y: 360, width: 240, rows: 2, cols: 2, cells: ["A", "B", "C", "D"])]
        }
        // `KAIRUMO_UITEST_SEED_LOCKED=1`：圖片一開始就鎖定在畫布上（`ObjectLockUITests` 測解鎖的入口）。
        if env["KAIRUMO_UITEST_SEED_LOCKED"] == "1" {
            doc.setLockedObjectIds(["00000000-0000-4000-8000-0000000000a2"], forPage: 0)
        }
        notebooks.append(doc)
        persistData(signalsLocalEdit: false)
    }

    /// 測試專用：把資料根目錄換成一個暫存目錄，而且**不放範例筆記**（S-92）。
    ///
    /// 用 `init` 而不是「測試完再清乾淨」：清理跑不到的情況太多（測試失敗、
    /// 中途中斷、`persistData` 在別的執行緒），而每一次漏掉都是使用者的
    /// 筆記清單裡多一本垃圾。
    public init(testDocumentsRoot: URL) {
        documentsRootOverride = testDocumentsRoot
        try? FileManager.default.createDirectory(
            at: testDocumentsRoot, withIntermediateDirectories: true)
    }

    // MARK: - 資料載入與持久化

    /// 移除重複 id 的筆記，保留最後修改的那一筆。
    ///
    /// 正常情況不該出現重複；但編輯器曾經把「切換到另一則筆記」實作成
    /// 直接寫進 `$store.notebooks[index]` 這個 Binding —— 那會把目前開著的
    /// 那一格覆蓋成目標筆記，於是陣列裡出現兩筆相同 id，
    /// `ForEach` 的識別就壞了（畫面整片空白），原本那則筆記的紀錄也不見了。
    /// 根因已修（見 `NotebookEditorView.switchToNotebook`），這裡負責讓
    /// 已經寫壞的檔案在下次啟動時自己痊癒，而不是一直卡著。
    static func deduplicateById(_ list: [NotebookDocument]) -> [NotebookDocument] {
        var seen: [String: Int] = [:]
        var result: [NotebookDocument] = []
        for item in list {
            if let idx = seen[item.id] {
                if item.lastModifiedDate > result[idx].lastModifiedDate {
                    result[idx] = item
                }
            } else {
                seen[item.id] = result.count
                result.append(item)
            }
        }

        // 範例筆記跨裝置同步去重：若存在多本預設範例筆記（例如各裝置初次啟動各建了一本），
        // 保留修改時間最新的一本，避免畫面上重複出現「課堂與會議記錄」或「歡迎使用 Kairumo」。
        var dedupedResult: [NotebookDocument] = []
        var seedSeen: [String: Int] = [:]
        for item in result {
            if let key = item.titleKey, (key == "seed_welcome_title" || key == "seed_meeting_title") {
                if let existingIdx = seedSeen[key] {
                    if item.lastModifiedDate > dedupedResult[existingIdx].lastModifiedDate {
                        dedupedResult[existingIdx] = item
                    }
                } else {
                    seedSeen[key] = dedupedResult.count
                    dedupedResult.append(item)
                }
            } else {
                dedupedResult.append(item)
            }
        }
        return dedupedResult
    }

    /// 同步剛拉回來的舊版範例筆記可能使用隨機 id；在同一輪立刻收斂成一本，
    /// 不要求使用者關掉 App 再開才看見去重結果。只處理仍保有系統 titleKey
    /// 的範例，使用者自行改過名的筆記不會被碰。
    public func repairSyncedSeedDuplicates() {
        let migrated = notebooks.map(migrateSeedTitles)
        var deduped = Self.deduplicateById(migrated)

        // 同步索引庫具備最新 Lamport 時戳權威：若遠端或其他裝置已改名或調整資料夾，讓工作副本同步跟進
        let liveIndex = syncLiveNotebooks(indexJson: AccountSyncStore.shared.indexJSON)
        let liveTitles = Dictionary(liveIndex.compactMap { item -> (String, String)? in
            let clean = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : (item.id.lowercased(), clean)
        }, uniquingKeysWith: { first, _ in first })

        let liveParents = Dictionary(liveIndex.map { item -> (String, String?) in
            let p = item.parentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return (item.id.lowercased(), p.isEmpty ? nil : p)
        }, uniquingKeysWith: { first, _ in first })

        for i in deduped.indices {
            let nid = deduped[i].id.lowercased()
            if let indexTitle = liveTitles[nid], !indexTitle.isEmpty, deduped[i].title != indexTitle {
                deduped[i].title = indexTitle
                // 預載範例必須維持系統 titleKey，否則將失去語系切換及自癒辨識能力
                if !NotebookPackageBridge.isDeviceLocalSeed(nid) {
                    deduped[i].titleKey = nil
                }
            }
            if let indexParent = liveParents[nid], deduped[i].folderId?.lowercased() != indexParent {
                deduped[i].folderId = indexParent
            }
        }

        let retainedIds = Set(deduped.map { $0.id.lowercased() })
        let removed = migrated.filter { !retainedIds.contains($0.id.lowercased()) }
        let needsSave = !removed.isEmpty || deduped != notebooks

        if needsSave {
            notebooks = deduped
            for document in removed {
                AccountSyncStore.shared.recordDeletion(id: document.id)
                let original = corePackagesDirectory.appending(path: "\(document.id).padnote")
                let canonical = corePackagesDirectory.appending(path: "\(document.id.lowercased()).padnote")
                try? FileManager.default.removeItem(at: original)
                if canonical != original { try? FileManager.default.removeItem(at: canonical) }
            }
            markDirtyAndPersist(signalsLocalEdit: false)
        }

        reconcileFoldersAndAssignmentsFromSync()

        if healInflatedSeedNotebooksIfNeeded() {
            markDirtyAndPersist(signalsLocalEdit: false)
        }
        if repairPhantomPagesIfNeeded() {
            markDirtyAndPersist(signalsLocalEdit: true)
        }
    }

    /// 依據帳號同步索引（AccountSyncStore / LibraryIndex）收斂資料夾結構與筆記所屬資料夾
    public func reconcileFoldersAndAssignmentsFromSync() {
        let indexJSON = AccountSyncStore.shared.indexJSON
        guard !indexJSON.isEmpty else { return }

        var foldersChanged = false
        var notebooksChanged = false

        // 1. 取得同步索引中所有有效資料夾
        let syncFolders = AccountSyncStore.shared.liveFolders()
        let syncFolderMap = Dictionary(syncFolders.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        // 2. 移除已被墓碑標記刪除的本機資料夾，更新現有資料夾的名稱與 parentId
        var updatedFolders: [FolderItem] = []
        for var folder in self.folders {
            let fId = folder.id.lowercased()
            // 若資料夾本身在同步索引中被標記刪除，予以移除
            if AccountSyncStore.shared.isDeleted(id: folder.id) {
                foldersChanged = true
                continue
            }
            // 若資料夾本身未被刪除，僅因上層資料夾被刪而呈隱藏，將其提升回最上層而非刪除
            if isHiddenBySync(folder.id) {
                folder.parentId = nil
                AccountSyncStore.shared.recordParent(id: folder.id, parentId: nil)
                foldersChanged = true
            }
            // 若同步索引中有最新中繼資料，更新名稱與 parentId
            if let syncItem = syncFolderMap[fId] {
                let cleanTitle = syncItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanTitle.isEmpty && folder.name != cleanTitle {
                    folder.name = cleanTitle
                    foldersChanged = true
                }
                let newParent = syncItem.parentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let targetParent: String? = (newParent.isEmpty || AccountSyncStore.shared.isDeleted(id: newParent) || isHiddenBySync(newParent)) ? nil : newParent
                if folder.parentId?.lowercased() != targetParent {
                    folder.parentId = targetParent
                    foldersChanged = true
                }
            } else {
                // 本機新建但尚未進 liveFolders（例如上層已不存在或剛建立）的資料夾：確保寫入同步索引
                let rawParent = folder.parentId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let validParent: String? = {
                    guard let p = rawParent, !p.isEmpty else { return nil }
                    if AccountSyncStore.shared.isDeleted(id: p) || isHiddenBySync(p) { return nil }
                    return p
                }()
                if folder.parentId?.lowercased() != validParent {
                    folder.parentId = validParent
                    foldersChanged = true
                }
                AccountSyncStore.shared.record(
                    id: folder.id,
                    title: folder.name,
                    parentId: validParent,
                    isFolder: true
                )
            }
            updatedFolders.append(folder)
        }

        // 3. 加入同步索引中有、但本機尚未建立的資料夾
        let existingFolderIds = Set(updatedFolders.map { $0.id.lowercased() })
        for syncFolder in syncFolders {
            let sfId = syncFolder.id.lowercased()
            if !existingFolderIds.contains(sfId) {
                let cleanTitle = syncFolder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? L10n.t("folder_new_default")
                    : syncFolder.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let parent = syncFolder.parentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let targetParent = parent.isEmpty ? nil : parent
                let newFolder = FolderItem(
                    id: sfId,
                    name: cleanTitle,
                    parentId: targetParent
                )
                updatedFolders.append(newFolder)
                foldersChanged = true
            }
        }

        // 去重保護（以小寫 id 為準）
        var seenIds = Set<String>()
        var dedupedFolders: [FolderItem] = []
        for folder in updatedFolders {
            let lower = folder.id.lowercased()
            if seenIds.insert(lower).inserted {
                dedupedFolders.append(folder)
            } else {
                foldersChanged = true
            }
        }
        updatedFolders = dedupedFolders

        if foldersChanged || updatedFolders != self.folders {
            self.folders = updatedFolders
        }
        sanitizeFolders()

        // 4. 收斂筆記本的所屬資料夾 (folderId)
        // 同步索引具備最新時戳權威：比對 liveNotebooks 取得正確的 parentId
        let liveNotebooksList = syncLiveNotebooks(indexJson: indexJSON)
        let liveNotebookMap = Dictionary(liveNotebooksList.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let validFolderIds = Set(self.folders.map { $0.id.lowercased() })

        for i in self.notebooks.indices {
            let nid = self.notebooks[i].id.lowercased()
            if !NotebookPackageBridge.isDeviceLocalSeed(nid),
               !AccountSyncStore.shared.isDeleted(id: nid),
               isHiddenBySync(nid) {
                // 筆記本本身未被刪除，僅因舊父資料夾被刪而在索引中呈 hidden：重置回未分類以確保顯示於「全部筆記」
                self.notebooks[i].folderId = nil
                AccountSyncStore.shared.recordParent(id: nid, parentId: nil)
                notebooksChanged = true
                continue
            }
            if let item = liveNotebookMap[nid] {
                let indexParent = item.parentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let targetFolderId = (indexParent.isEmpty || !validFolderIds.contains(indexParent)) ? nil : indexParent
                if self.notebooks[i].folderId?.lowercased() != targetFolderId {
                    self.notebooks[i].folderId = targetFolderId
                    notebooksChanged = true
                }
            }
        }

        if foldersChanged || notebooksChanged {
            markDirtyAndPersist(signalsLocalEdit: false)
        }
    }


    public func loadData() {
        if let data = try? Data(contentsOf: notebooksFile),
           let list = try? JSONDecoder().decode([NotebookDocument].self, from: data) {
            let migrated = list.map(migrateSeedTitles)
            let deduped = Self.deduplicateById(migrated)
            self.notebooks = deduped

            // 若有被去重清理掉的重複範例筆記，同步清理其套件並記錄刪除墓碑避免死灰復燃
            let retainedIds = Set(deduped.map { $0.id })
            for original in migrated {
                if !retainedIds.contains(original.id) {
                    AccountSyncStore.shared.recordDeletion(id: original.id)
                    let pkgDir = corePackagesDirectory.appending(path: "\(original.id).padnote")
                    try? FileManager.default.removeItem(at: pkgDir)
                    if let cloudFolder = CloudSyncFolder.resolveFolder() {
                        let scoped = cloudFolder.startAccessingSecurityScopedResource()
                        defer { if scoped { cloudFolder.stopAccessingSecurityScopedResource() } }
                        let remotePkg = cloudFolder.appending(path: "\(original.id).padnote")
                        try? FileManager.default.removeItem(at: remotePkg)
                    }
                }
            }
        }

        if let recData = try? Data(contentsOf: recordingsFile),
           let recList = try? JSONDecoder().decode([AudioRecordingRecord].self, from: recData) {
            self.recordings = recList
        }

        if let fData = try? Data(contentsOf: foldersFile),
           let fList = try? JSONDecoder().decode([FolderItem].self, from: fData) {
            self.folders = fList
            reconcileFoldersAndAssignmentsFromSync()
            sanitizeFolders()
        }

        if let tData = try? Data(contentsOf: trashFile),
           let tList = try? JSONDecoder().decode([NotebookDocument].self, from: tData) {
            self.trashedNotebooks = Self.deduplicateById(tList)
        }

        if let savedRoot = ProfileDefaults.current.string(forKey: rootFolderNameKey),
           !savedRoot.isEmpty,
           !Self.legacyDefaultRootNames.contains(savedRoot) {
            self.rootFolderName = savedRoot
        }
        StartupLogger.logKey("log_store_load_done", self.notebooks.count, self.recordings.count, self.folders.count)
    }

    /// 背景序列寫檔佇列。
    ///
    /// 編碼與原子寫檔原本在主執行緒同步執行，而拖曳／縮放物件時每一幀都會呼叫
    /// 到這裡 —— 一秒鐘六十次「整份 notebooks 重新 JSON 編碼 + 三次原子寫檔」，
    /// 主執行緒被卡住，畫面就抖。改成丟到背景佇列，並用 `pendingWrite` 合併
    /// 連續請求：中途的版本沒有人看得到，只有最後一版需要落盤。
    private static let ioQueue = DispatchQueue(label: "kairumo.store.io", qos: .utility)
    private var pendingWrite: Bool = false

    /// 舊版種子筆記的標題 → 語系鍵。
    ///
    /// 這兩本示範筆記在舊版是把中文標題直接寫死存進 JSON 的，升級上來的使用者
    /// 切語言時檔名不會變。認出來就補上 `titleKey`；使用者若已改過名，
    /// 字串對不上就不會被動到。
    private static let legacySeedTitles: [String: (title: String, snippet: String)] = [
        LocalizationManager.shared.localized("sample_welcome"): ("seed_welcome_title", "seed_welcome_snippet"),
        "课堂与会议记录": ("seed_meeting_title", "seed_meeting_snippet"),
        LocalizationManager.shared.localized("sample_lectures"): ("seed_meeting_title", "seed_meeting_snippet"),
        SeedContent.kairumoManualTitle: ("seed_manual_title", "seed_manual_snippet")
    ]

    private func migrateSeedTitles(_ doc: NotebookDocument) -> NotebookDocument {
        // UUID 的筆記不是舊範例：由範例另存出來的筆記本（`finishSampleSession`）名字相近，
        // 被認回範例的話會被範例的自癒修復整本重設。
        guard doc.titleKey == nil, UUID(uuidString: doc.id) == nil,
              let keys = Self.legacySeedTitles[doc.title] else { return doc }
        var migrated = doc
        migrated.titleKey = keys.title
        migrated.snippetKey = keys.snippet
        return migrated
    }

    /// 把「有名字、沒內容」的範例筆記補上內容。
    ///
    /// # 為什麼需要這一步
    ///
    /// `seedDefaultNotebooks()` 只在筆記庫**空的時候**跑。而範例筆記的內容
    /// （`SeedContent`）是後來才加的 —— 在那之前裝過這個 App 的人，庫裡早就
    /// 有兩本只有標題與頁數的空殼，而空殼不是空的，所以那個補內容的分支
    /// 一輩子不會執行。實機上看到的就是：「歡迎使用 Kairumo」打開來一片白，
    /// 而它的名字承諾的是說明。
    ///
    /// # 為什麼只補「完全空白」的那幾本
    ///
    /// 種子跑完，那些字就是**使用者自己的內容**了。他可能已經在上面寫了東西、
    /// 刪掉了幾段、加了頁。只要有任何一筆筆跡或物件，就一個字都不碰 ——
    /// 補內容補掉使用者的筆記，比一片空白嚴重得多。
    func backfillEmptySeedNotebooks() {
        var changed = false
        for index in notebooks.indices {
            guard let key = notebooks[index].titleKey,
                  key == "seed_welcome_title" || key == "seed_meeting_title" || key == "seed_feature_showcase_title",
                  Self.isBlank(notebooks[index])
            else { continue }

            // 先把空白頁收回到範例本來的頁數。舊版的種子曾經一口氣建了
            // 二十幾頁空白頁，補完內容之後那些頁還在 —— 一本三頁的說明
            // 後面拖著二十頁空白，看起來像沒載完。整本已經驗證是空的，
            // 收掉不會動到任何內容。
            notebooks[index].pagesData = []
            notebooks[index].pageHeights = nil
            notebooks[index].pageCount = 0

            if key == "seed_welcome_title" {
                SeedContent.fillWelcome(&notebooks[index])
            } else if key == "seed_meeting_title" {
                SeedContent.fillMeeting(&notebooks[index], store: self)
            } else if key == "seed_feature_showcase_title" {
                SeedContent.fillFeatureShowcase(&notebooks[index], store: self)
            }
            changed = true
        }

        // 徹底廢除舊版《Kairumo（精選實例）》：若存在則從列表與套件中主動清理
        let legacyBioIds = ["seed-featured-biology-v1"]
        let hadBio = notebooks.contains { doc in
            legacyBioIds.contains(doc.id.lowercased()) || doc.titleKey == "seed_featured_biology_title"
        }
        if hadBio {
            notebooks.removeAll { doc in
                legacyBioIds.contains(doc.id.lowercased()) || doc.titleKey == "seed_featured_biology_title"
            }
            for bioId in legacyBioIds {
                AccountSyncStore.shared.recordDeletion(id: bioId)
                let original = corePackagesDirectory.appending(path: "\(bioId).padnote")
                try? FileManager.default.removeItem(at: original)
            }
            changed = true
        }

        // 若現有使用者庫中尚未有功能實戰範例筆記，自動補入 —— **只補一次**（旗標）。
        // 以前每次啟動都補，使用者刪掉之後它每次更新、每次開 App 都長回來。
        let showcaseChecked = ProfileDefaults.current.bool(forKey: Self.showcaseSeededKey)
        ProfileDefaults.current.set(true, forKey: Self.showcaseSeededKey)
        let hasShowcase = notebooks.contains {
            $0.id == "seed-feature-showcase-v1" || $0.titleKey == "seed_feature_showcase_title"
        }
        if !showcaseChecked, !hasShowcase, !Self.retiredSamples.contains("seed-feature-showcase-v1") {
            var n3 = NotebookDocument(
                id: "seed-feature-showcase-v1",
                title: LocalizationManager.shared.localized("seed_feature_showcase_title"),
                createdAt: Date().addingTimeInterval(-43200),
                lastModifiedDate: Date().addingTimeInterval(-1800),
                pageCount: 4,
                hasRecording: false,
                previewSnippet: LocalizationManager.shared.localized("seed_feature_showcase_snippet"),
                template: .grid
            )
            n3.titleKey = "seed_feature_showcase_title"
            n3.snippetKey = "seed_feature_showcase_snippet"
            SeedContent.fillFeatureShowcase(&n3, store: self)
            notebooks.append(n3)
            changed = true
        }

        // 一次性清理：過去範例筆記本參與同步，各裝置各自生成的同一份內容（id 不同）被合併成兩份，
        // 每一頁的文字、圖形、筆跡都重複。範例現在不再同步（見 `isDeviceLocalSeed`），
        // 這裡把本機每一本範例重設回乾淨的標準內容。
        let needsGenerationReset = ProfileDefaults.current.integer(forKey: Self.seedGenerationKey) < Self.seedGeneration
        if healInflatedSeedNotebooksIfNeeded(force: needsGenerationReset) {
            changed = true
        }
        if repairPhantomPagesIfNeeded() {
            changed = true
        }
        if needsGenerationReset {
            ProfileDefaults.current.set(Self.seedGeneration, forKey: Self.seedGenerationKey)
        }

        // 自癒修復：若現有示範筆記《Kairumo(功能範例)》**從來沒有**設定背景卡片 underInkObjectIds，自動補齊。
        // 只看「有沒有設定過」，不看「是不是空的」：使用者把卡片移回筆跡上方之後是空的，
        // 那是使用者的選擇 —— 看空的話每次啟動都會被改回去（使用者回報：圖層調整後又恢復原狀）。
        for index in notebooks.indices {
            if notebooks[index].id.caseInsensitiveCompare("seed-feature-showcase-v1") == .orderedSame || notebooks[index].titleKey == "seed_feature_showcase_title" {
                if notebooks[index].explicitUnderInkObjectIds(forPage: 1).isEmpty {
                    for p in 0..<notebooks[index].pageCount {
                        let bgCardIds = (notebooks[index].shapeAttachments ?? []).filter {
                            $0.pageIndex == p && $0.kindName == "rectangle" && $0.label.isEmpty
                        }.map(\.id)
                        notebooks[index].setUnderInkObjectIds(Set(bgCardIds), forPage: p)
                    }
                    changed = true
                }
            }
        }

        // 《Kairumo手冊》：舊使用者只補一次（旗標），之後刪掉就不再長回來。
        if !ProfileDefaults.current.bool(forKey: Self.manualSeededKey) {
            ProfileDefaults.current.set(true, forKey: Self.manualSeededKey)
            let hasManual = notebooks.contains {
                $0.id == SeedContent.kairumoManualId || $0.title == SeedContent.kairumoManualTitle
            }
            if !hasManual {
                var manual = Self.makeKairumoManual()
                SeedContent.fillKairumoManual(&manual, store: self)
                notebooks.append(manual)
                changed = true
            }
        }

        // 《圖學範例》：舊使用者只補一次（旗標），之後刪掉就不再長回來。
        if !ProfileDefaults.current.bool(forKey: Self.draftingExampleSeededKey) {
            ProfileDefaults.current.set(true, forKey: Self.draftingExampleSeededKey)
            if !Self.retiredSamples.contains(Self.draftingExampleId),
               !notebooks.contains(where: { $0.id == Self.draftingExampleId }) {
                notebooks.append(makeDraftingExample())
                changed = true
            }
        }

        // 《歡迎使用 Kairumo》与《課堂與會議記錄》：若裝置先前在非空狀態啟動而漏建這兩本範例，只補一次（旗標）。
        if !ProfileDefaults.current.bool(forKey: Self.welcomeSeededKey) {
            ProfileDefaults.current.set(true, forKey: Self.welcomeSeededKey)
            let hasWelcome = notebooks.contains {
                $0.id.caseInsensitiveCompare("seed-welcome-notebook-v1") == .orderedSame || $0.titleKey == "seed_welcome_title"
            }
            if !hasWelcome, !Self.retiredSamples.contains("seed-welcome-notebook-v1"),
               let welcome = standardSample(id: "seed-welcome-notebook-v1") {
                notebooks.insert(welcome, at: 0)
                changed = true
            }
        }

        if !ProfileDefaults.current.bool(forKey: Self.meetingSeededKey) {
            ProfileDefaults.current.set(true, forKey: Self.meetingSeededKey)
            let hasMeeting = notebooks.contains {
                $0.id.caseInsensitiveCompare("seed-meeting-notebook-v1") == .orderedSame || $0.titleKey == "seed_meeting_title"
            }
            if !hasMeeting, !Self.retiredSamples.contains("seed-meeting-notebook-v1"),
               let meeting = standardSample(id: "seed-meeting-notebook-v1") {
                let insertIdx = min(1, notebooks.count)
                notebooks.insert(meeting, at: insertIdx)
                changed = true
            }
        }

        // 預設兩個資料夾架構：初次初始化或升級時建立，並將相關範例預載分配到這兩個資料夾中
        if !ProfileDefaults.current.bool(forKey: Self.seedFoldersInitializedKey) {
            ProfileDefaults.current.set(true, forKey: Self.seedFoldersInitializedKey)
            let hasF1 = folders.contains { $0.id.caseInsensitiveCompare(Self.seedFeaturesFolderId) == .orderedSame }
            let f1Deleted = AccountSyncStore.shared.isDeleted(id: Self.seedFeaturesFolderId)
            if !hasF1 && !f1Deleted {
                let f1 = FolderItem(
                    id: Self.seedFeaturesFolderId,
                    name: LocalizationManager.shared.localized("seed_folder_features"),
                    nameKey: "seed_folder_features"
                )
                folders.append(f1)
                AccountSyncStore.shared.record(id: f1.id, title: f1.name, parentId: nil, isFolder: true)
                changed = true
            }

            let hasF2 = folders.contains { $0.id.caseInsensitiveCompare(Self.seedDraftingFolderId) == .orderedSame }
            let f2Deleted = AccountSyncStore.shared.isDeleted(id: Self.seedDraftingFolderId)
            if !hasF2 && !f2Deleted {
                let f2 = FolderItem(
                    id: Self.seedDraftingFolderId,
                    name: LocalizationManager.shared.localized("seed_folder_drafting"),
                    nameKey: "seed_folder_drafting"
                )
                folders.append(f2)
                AccountSyncStore.shared.record(id: f2.id, title: f2.name, parentId: nil, isFolder: true)
                changed = true
            }

            let featuresIds = Set([
                "seed-welcome-notebook-v1",
                "seed-meeting-notebook-v1",
                "seed-feature-showcase-v1",
                SeedContent.kairumoManualId.lowercased()
            ])
            for i in notebooks.indices {
                let lowerId = notebooks[i].id.lowercased()
                if notebooks[i].folderId == nil {
                    if featuresIds.contains(lowerId) && !f1Deleted {
                        notebooks[i].folderId = Self.seedFeaturesFolderId
                        changed = true
                    } else if lowerId == "seed-drafting-example-v1" && !f2Deleted {
                        notebooks[i].folderId = Self.seedDraftingFolderId
                        changed = true
                    }
                }
            }
        }

        if changed { persistData() }
    }

    /// 這本筆記有沒有任何內容 —— 筆跡、物件都算。
    static func isBlank(_ doc: NotebookDocument) -> Bool {
        let objectCount = (doc.textAttachments?.count ?? 0)
            + (doc.attachments?.count ?? 0)
            + (doc.tableAttachments?.count ?? 0)
            + (doc.shapeAttachments?.count ?? 0)
            + (doc.connectionAttachments?.count ?? 0)
            + (doc.linkAttachments?.count ?? 0)
            + (doc.model3DAttachments?.count ?? 0)
            + (doc.audioAttachments?.count ?? 0)
            + (doc.commentPins?.count ?? 0)
        guard objectCount == 0 else { return false }

        if doc.pagesData.isEmpty { return true }
        // 快速路徑：若任何頁面位元組大於 64 bytes，表示已有繪製筆跡（空白 PKDrawing 標頭小於 32 bytes），
        // 避免在啟動主執行緒逐頁反序列化 PKDrawing 造成多秒卡頓。
        if doc.pagesData.contains(where: { $0.count > 64 }) {
            return false
        }
        // 解不開的筆跡資料當成「有東西」。判斷不出來就不要動它。
        return doc.pagesData.allSatisfy { data in
            guard let drawing = try? PKDrawing(data: data) else { return false }
            return drawing.strokes.isEmpty
        }
    }

    /// - Parameter signalsLocalEdit: 寫完之後要不要通知同步「本機有編輯」。
    ///   **同步自己寫進來的東西不能通知**：同步匯入了別台的內容 → 寫檔 → 通知「本機有編輯」→
    ///   排出下一輪同步 → 匯出（檔案時間比套件新）→ 上傳 → 對方下載、匯入、寫檔、通知……
    ///   兩台裝置就這樣永遠互相推（實測：兩台一直在同步，排程器的「沒變動就安靜」從來沒有機會生效）。
    public func persistData(signalsLocalEdit: Bool = true) {
        if signalsLocalEdit { signalAfterWrite = true }
        // 快照必須在主執行緒取得：這些陣列是 @MainActor 隔離的狀態。
        let snapshot = (
            notebooks: notebooks, recordings: recordings, folders: folders,
            trash: trashedNotebooks
        )
        let rootName = rootFolderName
        let files = (
            notebooks: notebooksFile, recordings: recordingsFile, folders: foldersFile,
            trash: trashFile
        )
        let key = rootFolderNameKey
        // **在排進佇列的當下就取定設定檔。** 背景寫檔是稍後才執行的；若到執行時才問「現在是哪個設定檔」，
        // 切換發生在中間的話，舊設定檔的資料夾名稱就寫進了新設定檔。檔案路徑上面已經是當下取定的。
        let defaults = ProfileDefaults.current

        guard !pendingWrite else {
            needsAnotherWrite = true
            return
        }
        pendingWrite = true

        Self.ioQueue.async { [weak self] in
            if let data = try? JSONEncoder().encode(snapshot.notebooks) {
                try? data.write(to: files.notebooks, options: .atomic)
            }
            if let recData = try? JSONEncoder().encode(snapshot.recordings) {
                try? recData.write(to: files.recordings, options: .atomic)
            }
            if let fData = try? JSONEncoder().encode(snapshot.folders) {
                try? fData.write(to: files.folders, options: .atomic)
            }
            if let tData = try? JSONEncoder().encode(snapshot.trash) {
                try? tData.write(to: files.trash, options: .atomic)
            }
            defaults.set(rootName, forKey: key)

            Task { @MainActor in
                guard let self else { return }
                self.pendingWrite = false
                // 寫檔期間若又有變更，補寫最後一版，否則會漏掉結尾的編輯。
                if self.needsAnotherWrite {
                    self.needsAnotherWrite = false
                    self.persistData(signalsLocalEdit: self.signalAfterWrite)
                    return
                }
                // 落盤完成才通知同步。**順序不能顛倒**：先通知的話，
                // 同步可能讀到還沒寫完的檔案。
                //
                // 這是去抖動的觸發 —— 使用者還在寫字時每一筆都推只是浪費電，
                // 排程器會等他停手 1.5 秒。
                if self.signalAfterWrite {
                    self.signalAfterWrite = false
                    AutoSyncController.shared.noteLocalEdit()
                }
            }
        }
    }

    /// 這一批寫入裡有沒有**使用者的**編輯。有才通知同步；只有同步自己的寫入就不通知。
    private var signalAfterWrite: Bool = false

    /// 寫檔進行中又收到新變更的標記。
    private var needsAnotherWrite: Bool = false

    /// 標記資料已變更並排程落盤。寫檔進行中則記下，待目前這次寫完再補一次。
    public func markDirtyAndPersist(signalsLocalEdit: Bool = true) {
        if signalsLocalEdit { signalAfterWrite = true }
        if pendingWrite {
            needsAnotherWrite = true
        } else {
            persistData(signalsLocalEdit: signalsLocalEdit)
        }
    }

    /// 把整個持續使用中的文件庫搬到使用者透過系統選擇器指定的位置。
    ///
    /// 路徑是**每台裝置自己的設定**，不會同步成別台裝置上不存在的絕對路徑；
    /// 跨裝置仍以筆記 UUID、device id 與既有 CRDT 同步索引辨識同一本筆記。
    /// 搬完後所有自動儲存、錄音、附件、備份與同步都從新根目錄讀寫。
    func moveStorage(
        toParentFolder folder: URL,
        progress: DocumentStorageLocation.ProgressHandler? = nil
    ) async throws {
        // 位置設定（書籤）是預設設定檔的。其他設定檔的資料固定放在 `Profiles/<id>/`，
        // 讓它走這裡會把預設設定檔的位置一起改掉。介面已經停用這個入口，這裡是第二道防線。
        guard ProfileContext.isDefault else {
            throw NSError(
                domain: "Kairumo.StorageLocation", code: 3,
                userInfo: [NSLocalizedDescriptionKey: L10n.t("profile_storage_default_only")])
        }
        // 先把記憶體裡最後一版確實落盤。若此時直接換根目錄，背景寫入會在
        // 舊路徑收尾，使用者剛寫的最後幾筆就不在新文件庫裡。
        markDirtyAndPersist()
        while pendingWrite || needsAnotherWrite {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        // 正在跑的那一輪同步會佔著互斥閘（下載大筆記本可以跑幾分鐘），而搬移要等它放手。
        // 先請它中斷：同步是冪等的，下一輪會接著做；不中斷的話畫面就是一個轉圈圈等兩分鐘。
        progress?(DocumentStorageLocation.MoveProgress(phase: .waitingForSync))
        NotebookSyncCoordinator.cancelSync()
        guard let grant = await SyncGateQueue.enter(label: "storage-location") else {
            throw NSError(
                domain: "Kairumo.StorageLocation", code: 1,
                userInfo: [NSLocalizedDescriptionKey: L10n.t("storage_sync_running")])
        }
        defer { _ = syncGateLeave(ticket: grant.ticket) }

        let oldRoot = documentsDir
        _ = try await DocumentStorageLocation.shared.useParentFolder(
            folder, movingFrom: oldRoot, progress: progress)

        // copyDirectoryContents 已完成才切 bookmark；因此這裡讀到的一定是一份
        // 完整文件庫。清掉舊的記憶體投影，避免目的地若是空庫時殘留舊清單。
        notebooks = []
        recordings = []
        folders = []
        trashedNotebooks = []
        loadData()
        refreshRecordings()
        StartupLogger.logKey("log_library_switched", documentsDir.path)
        AutoSyncController.shared.request(.localEdit)
    }

    /// 「重設本機資料」的階段，給畫面顯示。
    enum ResetPhase: Sendable { case cloud, local }

    /// 重設本機資料：清掉這台裝置上的筆記本、錄音、附件與同步狀態，從乾淨的資料庫開始。
    ///
    /// 順序：**先雲端、後本機**。本機先清、雲端還在的話，下一輪同步會把雲端的東西全部
    /// 下載回來；而雲端清失敗就整個中止，本機一個檔案都不動。
    /// 保留已下載的語音模型（`models`，幾百 MB，要重新下載很不划算）。
    func resetLocalData(
        alsoWipeCloud: Bool,
        progress: (@Sendable (ResetPhase) -> Void)? = nil
    ) async throws {
        // 雲端：自己會進同步互斥閘，所以必須在我們拿閘之前做完。
        if alsoWipeCloud {
            progress?(.cloud)
            NotebookSyncCoordinator.cancelSync()
            var attempted = false
            var result: FfiWipeResult?
            if await GoogleAuth.shared.isSignedIn {
                attempted = true
                result = await CloudSync.wipeCloud()
            } else if CloudSyncFolder.resolveFolder() != nil {
                attempted = true
                result = await CloudSyncFolder.wipeCloud()
            }
            // 有同步可清卻沒有結果（忙碌、連不上）或清失敗：整個中止，本機不動。
            // 沒設定任何同步就沒有雲端可清，那不是失敗。
            if attempted, result?.ok != true {
                throw NSError(
                    domain: "Kairumo.ResetLocalData", code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        LocalizationManager.shared.localizedUnsafe("storage_reset_cloud_failed")])
            }
        }

        // 讓進行中的寫檔收尾：不然刪完之後背景寫入又把檔案寫回來。
        while pendingWrite || needsAnotherWrite {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        progress?(.local)
        NotebookSyncCoordinator.cancelSync()
        guard let grant = await SyncGateQueue.enter(label: "reset-local-data") else {
            throw NSError(
                domain: "Kairumo.ResetLocalData", code: 2,
                userInfo: [NSLocalizedDescriptionKey: L10n.t("storage_sync_running")])
        }
        defer { _ = syncGateLeave(ticket: grant.ticket) }

        let root = documentsDir
        let account = await GoogleAuth.shared.accountEmail ?? ""
        await Task.detached(priority: .utility) {
            DocumentStorageLocation.clearLibraryContents(at: root, keeping: ["models"])
            _ = try? DocumentStorageLocation.ensureManifest(in: root)
        }.value

        AccountSyncStore.shared.resetLocalSyncState(account: account)
        notebooks = []
        recordings = []
        folders = []
        trashedNotebooks = []
        loadData()
        refreshRecordings()
        StartupLogger.logKey("log_local_reset", root.path)
        AutoSyncController.shared.request(.localEdit)
    }

    private struct CachedDrawing {
        let modDate: Date?
        let drawing: PKDrawing
        let isPendingWrite: Bool
    }
    private nonisolated static let drawingCacheLock = NSLock()
    // profile-scope: profile 以完整檔案路徑（含設定檔專屬目錄）為鍵，快取已解碼的 PKDrawing 避免在主執行緒反覆重讀與反序列化
    private nonisolated(unsafe) static var drawingCache: [String: CachedDrawing] = [:]
    private var cachedDrawingsDirPath: String?

    /// 專屬畫布筆畫向量二進位儲存目錄
    public var drawingsDirectory: URL {
        let dir = documentsDir.appendingPathComponent("Drawings", isDirectory: true)
        let path = dir.path
        if cachedDrawingsDirPath != path {
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            cachedDrawingsDirPath = path
        }
        return dir
    }

    /// 即時自動儲存單頁手繪內容
    public func saveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing) {
        let fileUrl = drawingsDirectory.appending(path: "\(notebookId)_p\(pageIndex).drawing")
        Self.writeDrawing(drawing, to: fileUrl)
    }

    /// 清除記憶體中的筆跡快取
    nonisolated static func invalidateDrawingCache(notebookId: String? = nil) {
        drawingCacheLock.lock()
        if let id = notebookId?.lowercased() {
            drawingCache = drawingCache.filter { !$0.key.contains("/\(id)_p") }
        } else {
            drawingCache.removeAll()
        }
        drawingCacheLock.unlock()
    }

    /// 先把最新筆跡寫入記憶體快取（供主執行緒立即讀取，零磁碟等待），實際序列化與寫檔可交由背景序列佇列完成。
    nonisolated static func primeDrawingCache(_ drawing: PKDrawing, for fileURL: URL) {
        let key = fileURL.path
        drawingCacheLock.lock()
        drawingCache[key] = CachedDrawing(modDate: nil, drawing: drawing, isPendingWrite: true)
        drawingCacheLock.unlock()
    }

    /// Background counterpart used by the editor's serialized ink writer.
    /// The caller resolves the URL on the main actor; serialization and disk I/O
    /// happen on the writer queue.
    nonisolated static func writeDrawing(_ drawing: PKDrawing, to fileURL: URL) {
        let key = fileURL.path
        let data = drawing.dataRepresentation()
        try? data.write(to: fileURL, options: .atomic)
        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        drawingCacheLock.lock()
        drawingCache[key] = CachedDrawing(modDate: modDate, drawing: drawing, isPendingWrite: false)
        drawingCacheLock.unlock()
    }

    /// 讀取單頁手繪內容（具記憶體快取，檔案修改時間未變時直接回傳已解碼的 PKDrawing）
    public func loadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing {
        let fileUrl = drawingsDirectory.appending(path: "\(notebookId)_p\(pageIndex).drawing")
        let key = fileUrl.path
        let modDate = (try? fileUrl.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        Self.drawingCacheLock.lock()
        if modDate == nil {
            if let cached = Self.drawingCache[key], cached.isPendingWrite {
                Self.drawingCacheLock.unlock()
                return cached.drawing
            }
            Self.drawingCache.removeValue(forKey: key)
            Self.drawingCacheLock.unlock()

            // 🌟 容錯與自癒：若磁碟筆跡檔不存在，嘗試自文件 pagesData 或範例筆記本種子資料重建
            if let recovered = recoverDrawingFromDocumentOrSeed(notebookId: notebookId, pageIndex: pageIndex) {
                saveDrawing(notebookId: notebookId, pageIndex: pageIndex, drawing: recovered)
                return recovered
            }
            return PKDrawing()
        }
        if let cached = Self.drawingCache[key], cached.modDate == modDate, !cached.isPendingWrite {
            Self.drawingCacheLock.unlock()
            return cached.drawing
        }
        Self.drawingCacheLock.unlock()

        guard let data = try? Data(contentsOf: fileUrl),
              let d = try? PKDrawing(data: data) else {
            Self.drawingCacheLock.lock()
            Self.drawingCache.removeValue(forKey: key)
            Self.drawingCacheLock.unlock()

            // 🌟 容錯與自癒：若磁碟筆跡檔損毀或為空，嘗試自文件 pagesData 或範例筆記本種子資料重建
            if let recovered = recoverDrawingFromDocumentOrSeed(notebookId: notebookId, pageIndex: pageIndex) {
                saveDrawing(notebookId: notebookId, pageIndex: pageIndex, drawing: recovered)
                return recovered
            }
            return PKDrawing()
        }
        Self.drawingCacheLock.lock()
        Self.drawingCache[key] = CachedDrawing(modDate: modDate, drawing: d, isPendingWrite: false)
        Self.drawingCacheLock.unlock()
        return d
    }

    /// 容錯與自癒：若磁碟筆跡檔不存在或損毀，嘗試自文件 pagesData 或範例筆記本種子資料重建
    private func recoverDrawingFromDocumentOrSeed(notebookId: String, pageIndex: Int) -> PKDrawing? {
        if let doc = notebooks.first(where: { $0.id.caseInsensitiveCompare(notebookId) == .orderedSame }) {
            if pageIndex < doc.pagesData.count {
                let data = doc.pagesData[pageIndex]
                if !data.isEmpty, let d = try? PKDrawing(data: data), d.strokes.count > 0 {
                    return d
                }
            }
        }
        let idLower = notebookId.lowercased()
        if idLower == SeedContent.kairumoManualId.lowercased() {
            let drawings = SeedContent.kairumoManualDrawings(language: LocalizationManager.snapshotLanguage)
            if pageIndex < drawings.count {
                return drawings[pageIndex]
            }
        } else if idLower == "seed-feature-showcase-v1" {
            var temp = NotebookDocument(id: "seed-feature-showcase-v1", title: "", pageCount: 4)
            SeedContent.fillFeatureShowcase(&temp, store: nil)
            if pageIndex < temp.pagesData.count {
                let data = temp.pagesData[pageIndex]
                if !data.isEmpty, let d = try? PKDrawing(data: data), d.strokes.count > 0 {
                    return d
                }
            }
        }
        return nil
    }

    // MARK: - 錄音套件（R2）

    /// 開一個可以寫入的套件 session，套件不存在就建立。
    ///
    /// 錄音必須落在套件裡 —— **套件才是同步的單位**。存在套件外的後果
    /// 已經看過了：Apple 的錄音存在 `Documents/Kairumo Record`，
    /// 於是從來沒有被同步過。
    public func packageSession(forNotebookId id: String, title: String) -> PadnoteSession? {
        let path = corePackagesDirectory.appending(path: "\(id.lowercased()).padnote")
        try? FileManager.default.createDirectory(
            at: corePackagesDirectory, withIntermediateDirectories: true)
        return Self.openPackageSession(at: path, title: title, deviceId: NotebookMigration.deviceId)
    }

    /// 同 `packageSession(forNotebookId:title:)`，但在背景執行緒開。
    ///
    /// 開套件要把整份操作紀錄重播一次。「錄音收件匣」會隨每一段錄音與逐字稿越長越大，
    /// 在主執行緒上開，按下「開始錄音」之後畫面要停好幾秒才開始錄。
    public func packageSessionInBackground(forNotebookId id: String, title: String) async -> PadnoteSession? {
        let path = corePackagesDirectory.appending(path: "\(id.lowercased()).padnote")
        try? FileManager.default.createDirectory(
            at: corePackagesDirectory, withIntermediateDirectories: true)
        let device = NotebookMigration.deviceId
        return await Task.detached(priority: .userInitiated) {
            Self.openPackageSession(at: path, title: title, deviceId: device)
        }.value
    }

    nonisolated static func openPackageSession(at path: URL, title: String, deviceId: UInt32) -> PadnoteSession? {
        if let existing = try? PadnoteSession.openExisting(path: path.path, deviceId: deviceId) {
            return existing
        }
        let now = UInt64(max(0, Date().timeIntervalSince1970 * 1000))
        return try? PadnoteSession.create(
            path: path.path, title: title, nowUnixMs: now, deviceId: deviceId)
    }

    /// 「錄音收件匣」筆記本，不存在就建立。
    ///
    /// id 由核心給（`recordingInboxNotebookId()`），兩個平台共用同一個值 ——
    /// 各自取一個的話，同一個帳號下會出現兩本收件匣，而且誰也不會發現，
    /// 因為兩台裝置各自只看得到自己那本。
    @discardableResult
    public func recordingInbox() -> NotebookDocument {
        let id = recordingInboxNotebookId()
        if let existing = notebooks.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) {
            return existing
        }
        var doc = NotebookDocument(
            id: id,
            title: LocalizationManager.shared.localized("recording_inbox"),
            pageCount: 1,
            template: .blank)
        doc.hasRecording = true
        notebooks.append(doc)
        AccountSyncStore.shared.record(id: id, title: doc.title, parentId: nil, isFolder: false)
        markDirtyAndPersist(signalsLocalEdit: false)
        return doc
    }

    /// 圖片附件實體存儲目錄
    public var attachmentsDirectory: URL {
        let dir = documentsDir.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 把**任何**匯入的檔案存進附件目錄，回傳檔名。
    ///
    /// # 為什麼是通用的，不是每種附件各寫一份
    ///
    /// 插入工具原本只給得出內建的東西 —— 3D 模型只有六個固定幾何體。
    /// 使用者手上那個檔案（一個模型、一份 PDF、一段錄音）進不來，
    /// 而那才是他真正想放進筆記的東西。
    ///
    /// 每種附件各寫一個儲存函式的話，第七種附件出現時會再抄一次，
    /// 而抄漏的那一次（忘了 `.atomic`、忘了建目錄）要等使用者掉資料才發現。
    ///
    /// 副檔名保留原樣：SceneKit 要靠它判斷格式（`SCNScene(url:)` 讀的是
    /// 副檔名，不是內容）。
    public func saveImportedFile(data: Data, extension ext: String) -> String? {
        let clean = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let fileName = clean.isEmpty
            ? "imp_\(UUID().uuidString)"
            : "imp_\(UUID().uuidString).\(clean)"
        let fileUrl = attachmentsDirectory.appending(path: fileName)
        do {
            // `.atomic`：寫到一半當機的話，留下的是舊檔或沒有檔，
            // 不是一個讀得到但壞掉的檔 —— 後者會讓使用者看到一個
            // 打不開的物件，而且看不出原因。
            try data.write(to: fileUrl, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    /// 匯入檔案在磁碟上的位置。**不保證它存在**。
    public func importedFileURL(fileName: String) -> URL {
        attachmentsDirectory.appending(path: fileName)
    }

    /// 記憶體層級圖片快取，徹底消除物件拖曳時每秒 60-120 次磁碟讀取解碼產生的殘影與掉幀
    private let imageCache = NSCache<NSString, UIImage>()

    /// 儲存圖片附件至本地磁碟，回傳儲存後的檔名
    public func saveAttachmentImage(_ image: UIImage) -> String? {
        let fileName = "att_\(UUID().uuidString).png"
        let fileUrl = attachmentsDirectory.appending(path: fileName)
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: fileUrl, options: .atomic)
            imageCache.setObject(image, forKey: fileName as NSString)
            return fileName
        } catch {
            return nil
        }
    }

    /// 讀取圖片附件（優先自記憶體快取命中，未命中則自磁碟讀取並寫入快取）
    public func loadAttachmentImage(fileName: String) -> UIImage? {
        let key = fileName as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        let fileUrl = attachmentsDirectory.appending(path: fileName)
        guard let data = try? Data(contentsOf: fileUrl), let img = UIImage(data: data) else { return nil }
        imageCache.setObject(img, forKey: key)
        return img
    }

    func seedDefaultNotebooks() {
        // title/previewSnippet 仍然寫入（供未安裝語系或外部讀取時 fallback），
        // 但顯示一律走 titleKey/snippetKey。
        var n1 = NotebookDocument(
            id: "seed-welcome-notebook-v1",
            title: LocalizationManager.shared.localized("sample_welcome"),
            createdAt: Date().addingTimeInterval(-86400 * 2),
            lastModifiedDate: Date().addingTimeInterval(-3600),
            pageCount: SeedContent.welcomePageCount,
            hasRecording: false,
            previewSnippet: "點擊進入畫布即可隨心手寫、繪製圖形、插入錄音並導出 PDF",
            template: .blank
        )

        var n2 = NotebookDocument(
            id: "seed-meeting-notebook-v1",
            title: LocalizationManager.shared.localized("sample_lectures"),
            createdAt: Date().addingTimeInterval(-86400),
            lastModifiedDate: Date().addingTimeInterval(-7200),
            pageCount: SeedContent.meetingPageCount,
            hasRecording: true,
            previewSnippet: "支援麥克風即時收音，聲音與筆跡精確對齊",
            template: .cornell
        )

        var n3 = NotebookDocument(
            id: "seed-feature-showcase-v1",
            title: LocalizationManager.shared.localized("seed_feature_showcase_title"),
            createdAt: Date().addingTimeInterval(-43200),
            lastModifiedDate: Date().addingTimeInterval(-1800),
            pageCount: 4,
            hasRecording: false,
            previewSnippet: LocalizationManager.shared.localized("seed_feature_showcase_snippet"),
            template: .grid
        )

        n1.titleKey = "seed_welcome_title"
        n1.snippetKey = "seed_welcome_snippet"
        n2.titleKey = "seed_meeting_title"
        n2.snippetKey = "seed_meeting_snippet"
        n3.titleKey = "seed_feature_showcase_title"
        n3.snippetKey = "seed_feature_showcase_snippet"

        // 範例筆記：示範手寫、幾何形狀、原生表格與考點遮蔽膠帶
        SeedContent.fillWelcome(&n1)
        SeedContent.fillMeeting(&n2, store: self)
        SeedContent.fillFeatureShowcase(&n3, store: self)

        var n4 = Self.makeKairumoManual()
        SeedContent.fillKairumoManual(&n4, store: self)
        ProfileDefaults.current.set(true, forKey: Self.welcomeSeededKey)
        ProfileDefaults.current.set(true, forKey: Self.meetingSeededKey)
        ProfileDefaults.current.set(true, forKey: Self.manualSeededKey)
        ProfileDefaults.current.set(true, forKey: Self.showcaseSeededKey)

        var n5 = makeDraftingExample()
        ProfileDefaults.current.set(true, forKey: Self.draftingExampleSeededKey)

        // 預設建立兩個資料夾並將範例分配到這兩個資料夾中
        let fFeatures = FolderItem(
            id: Self.seedFeaturesFolderId,
            name: LocalizationManager.shared.localized("seed_folder_features"),
            nameKey: "seed_folder_features"
        )
        let fDrafting = FolderItem(
            id: Self.seedDraftingFolderId,
            name: LocalizationManager.shared.localized("seed_folder_drafting"),
            nameKey: "seed_folder_drafting"
        )
        self.folders = [fFeatures, fDrafting]
        AccountSyncStore.shared.record(id: fFeatures.id, title: fFeatures.name, parentId: nil, isFolder: true)
        AccountSyncStore.shared.record(id: fDrafting.id, title: fDrafting.name, parentId: nil, isFolder: true)
        ProfileDefaults.current.set(true, forKey: Self.seedFoldersInitializedKey)

        n1.folderId = Self.seedFeaturesFolderId
        n2.folderId = Self.seedFeaturesFolderId
        n3.folderId = Self.seedFeaturesFolderId
        n4.folderId = Self.seedFeaturesFolderId
        n5.folderId = Self.seedDraftingFolderId

        self.notebooks = [n1, n2, n3, n4, n5]
        persistData()
    }

    public static let seedFeaturesFolderId = "seed-folder-features-v1"
    public static let seedDraftingFolderId = "seed-folder-drafting-v1"
    private static let seedFoldersInitializedKey = "seed.folders.initialized.v1"

    private static let welcomeSeededKey = "seed.welcome.added"
    private static let meetingSeededKey = "seed.meeting.added"
    /// 《Kairumo手冊》：全手繪的預載筆記本。名稱是固定的，不走語系表。
    private static let manualSeededKey = "seed.kairumoManual.added"
    /// 《Kairumo(功能範例)》：舊使用者只補一次，之後刪掉就不再長回來。
    private static let showcaseSeededKey = "seed.featureShowcase.added"
    /// 舊版「轉成一般筆記」而退役的範例 id：不再自動補回（範例改成唯讀後不再寫入）。
    static let retiredSamplesKey = "seed.retiredSamples"

    static var retiredSamples: Set<String> {
        Set(ProfileDefaults.current.stringArray(forKey: retiredSamplesKey) ?? [])
    }
    /// 範例筆記本內容的「世代」。提高它，下次啟動時所有範例會重設回標準內容一次。
    private static let seedGenerationKey = "seed.contentGeneration"
    // 3：範例改為唯讀（一編輯就另存一本），現有的範例重設一次（裡面有使用者內容的先另存，見
    // `restoreSamplePreservingUserContent`）。被刪掉或退役的範例**不補回**：更新程式不重新安裝範例。
    // 提高這個數字 = 下次更新時重設所有範例一次，非必要不要動。
    private static let seedGeneration = 3

    /// 自癒修復：若預載範例筆記因為跨裝置同步 CRDT 合併產生頁數或區塊膨脹，自動收斂重設回標準頁數並清理多餘頁面與繪圖檔
    @discardableResult
    public func healInflatedSeedNotebooksIfNeeded(force: Bool = false) -> Bool {
        var changed = false
        // 先抓好範例的 id 再逐本處理：另存出來的筆記本會插在清單最前面，邊走索引邊插入會跳過下一本。
        let sampleIds = notebooks.map(\.id).filter { NotebookPackageBridge.seedStandardPageCount(for: $0) != nil }
        for id in sampleIds {
            guard let doc = notebooks.first(where: { $0.id == id }) else { continue }
            // 只認範例自己的 id。以名字認的話，由範例另存出來的筆記本（名字相近）會被整本重設。
            guard let standardCount = NotebookPackageBridge.seedStandardPageCount(for: doc.id) else { continue }
            let canonicalIds = NotebookPackageBridge.deterministicSeedPageIds(for: doc.id)
            let pageIdsMismatch = canonicalIds != nil && doc.pageIds != canonicalIds
            if force || doc.pageCount > standardCount || (doc.textAttachments ?? []).count > 100 || pageIdsMismatch {
                // 重設之前，範例裡若有使用者的內容（舊版範例可以直接編輯），先另存成一般筆記本 —— 更新程式不能清掉使用者的東西。
                restoreSamplePreservingUserContent(doc.id)
                changed = true
            }
        }
        return changed
    }

    /// 一本範例的標準內容（全新產生；會把標準筆跡寫進這台的筆跡檔）。不是範例回 nil。
    public func standardSample(id: String) -> NotebookDocument? {
        let l = LocalizationManager.shared
        switch id.lowercased() {
        case "seed-welcome-notebook-v1":
            var doc = NotebookDocument(
                id: "seed-welcome-notebook-v1", title: l.localized("sample_welcome"),
                pageCount: SeedContent.welcomePageCount, hasRecording: false,
                previewSnippet: "點擊進入畫布即可隨心手寫、繪製圖形、插入錄音並導出 PDF", template: .blank)
            doc.titleKey = "seed_welcome_title"
            doc.snippetKey = "seed_welcome_snippet"
            doc.folderId = Self.seedFeaturesFolderId
            SeedContent.fillWelcome(&doc)
            return doc
        case "seed-meeting-notebook-v1":
            var doc = NotebookDocument(
                id: "seed-meeting-notebook-v1", title: l.localized("sample_lectures"),
                pageCount: SeedContent.meetingPageCount, hasRecording: true,
                previewSnippet: "支援麥克風即時收音，聲音與筆跡精確對齊", template: .cornell)
            doc.titleKey = "seed_meeting_title"
            doc.snippetKey = "seed_meeting_snippet"
            doc.folderId = Self.seedFeaturesFolderId
            SeedContent.fillMeeting(&doc, store: self)
            return doc
        case "seed-feature-showcase-v1":
            var doc = NotebookDocument(
                id: "seed-feature-showcase-v1", title: l.localized("seed_feature_showcase_title"),
                pageCount: 4, hasRecording: false,
                previewSnippet: l.localized("seed_feature_showcase_snippet"), template: .grid)
            doc.titleKey = "seed_feature_showcase_title"
            doc.snippetKey = "seed_feature_showcase_snippet"
            doc.folderId = Self.seedFeaturesFolderId
            SeedContent.fillFeatureShowcase(&doc, store: self)
            return doc
        case SeedContent.kairumoManualId.lowercased():
            var doc = Self.makeKairumoManual()
            doc.pageCount = 4
            doc.folderId = Self.seedFeaturesFolderId
            SeedContent.fillKairumoManual(&doc, store: self)
            return doc
        case Self.draftingExampleId.lowercased():
            var doc = makeDraftingExample()
            doc.folderId = Self.seedDraftingFolderId
            return doc
        default:
            return nil
        }
    }

    /// 把一本範例重設回乾淨的標準內容：磁碟上的套件、筆跡、同步基準全部清掉重建。
    /// 只保留使用者放的資料夾與建立時間。
    func restoreSampleToStandard(_ id: String) {
        guard let index = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else { return }
        let old = notebooks[index]
        // 先清再產生：標準內容的筆跡在產生時就寫進筆跡檔，順序反了會被清掉。
        resetSeedStorage(notebookId: old.id)
        guard var fresh = standardSample(id: old.id) else { return }
        let defaultSeedFolder = old.id.lowercased() == Self.draftingExampleId.lowercased() ? Self.seedDraftingFolderId : Self.seedFeaturesFolderId
        fresh.folderId = old.folderId ?? defaultSeedFolder
        fresh.createdAt = old.createdAt
        fresh.lastModifiedDate = old.createdAt
        if let canonical = NotebookPackageBridge.deterministicSeedPageIds(for: fresh.id) {
            fresh.pageIds = Array(canonical.prefix(max(fresh.pageCount, 1)))
        }
        let drawings = (0..<max(fresh.pageCount, 1)).map { loadDrawing(notebookId: fresh.id, pageIndex: $0) }
        try? NotebookPackageBridge.export(
            document: fresh, drawings: drawings,
            to: corePackagesDirectory.appending(path: "\(fresh.id.lowercased()).padnote"),
            deviceId: NotebookMigration.deviceId)
        notebooks[index] = fresh
        try? FileManager.default.removeItem(at: sampleSessionDirectory(old.id))
        PageThumbnailRenderer.invalidateAll()
    }

    /// 刪掉一本範例筆記本在磁碟上的衍生資料（核心套件、手繪與專業筆畫檔、同步基準），
    /// 讓重新產生的標準內容不會疊在舊的（含重複的）內容上。
    private func resetSeedStorage(notebookId: String) {
        Self.invalidateDrawingCache(notebookId: notebookId)
        let fm = FileManager.default
        for name in [notebookId, notebookId.lowercased()] {
            try? fm.removeItem(at: corePackagesDirectory.appending(path: "\(name).padnote"))
        }
        let prefixes = [notebookId, notebookId.lowercased()].map { "\($0)_p" }
        for directory in [drawingsDirectory, syncBaselineDirectory] {
            let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for file in files {
                let name = file.lastPathComponent
                if prefixes.contains(where: { name.hasPrefix($0) }) {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }

    private static func makeKairumoManual() -> NotebookDocument {
        var manual = NotebookDocument(
            id: SeedContent.kairumoManualId,
            title: SeedContent.kairumoManualTitle,
            createdAt: Date().addingTimeInterval(-600),
            lastModifiedDate: Date().addingTimeInterval(-600),
            pageCount: 2,
            hasRecording: false,
            previewSnippet: "Kairumo 優勢：結構化、視覺化、多語言 —— 全部手繪",
            template: .blank
        )
        // 標題與摘要跟著介面語言走（使用者改名後這個標記就會清掉）。
        manual.titleKey = "seed_manual_title"
        manual.snippetKey = "seed_manual_snippet"
        return manual
    }

    // MARK: - 筆記操作 CRUD

    @discardableResult
    public func createNotebook(title: String, template: NoteTemplate, folderId: String? = nil) -> NotebookDocument {
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? LocalizationManager.shared.localized("untitled_note") : title
        let newDoc = NotebookDocument(
            title: safeTitle,
            createdAt: Date(),
            lastModifiedDate: Date(),
            pageCount: 1,
            hasRecording: false,
            previewSnippet: String(
                format: LocalizationManager.shared.localized("created_on"),
                LocalizationManager.formatted(Date(), date: .abbreviated, time: .shortened)),
            template: template,
            folderId: folderId
        )
        notebooks.insert(newDoc, at: 0)
        AccountSyncStore.shared.record(
            id: newDoc.id,
            title: newDoc.title,
            parentId: folderId,
            isFolder: false
        )
        persistData()
        return newDoc
    }

    /// 這份文件除了修改時間之外，是否與 store 裡的那一份完全一樣。
    ///
    /// 編輯器在切頁、切模式、點縮圖時都會「存檔」。存之前先問這個：沒有任何東西變，
    /// 就不要更新修改時間、也不要通知同步有編輯（否則同步與編輯器會互相觸發，沒完沒了）。
    public func notebookMatchesStored(_ doc: NotebookDocument) -> Bool {
        guard let stored = notebooks.first(where: { $0.id == doc.id }) else { return false }
        var probe = doc
        probe.lastModifiedDate = stored.lastModifiedDate
        return probe == stored
    }

    public func updateNotebook(_ doc: NotebookDocument) {
        if let idx = notebooks.firstIndex(where: { $0.id == doc.id }) {
            let previous = notebooks[idx]
            var updated = doc
            updated.lastModifiedDate = Date()
            // **所屬資料夾不從這裡改。** 搬資料夾只走 `moveNotebook`；這裡收到的常是編輯器開啟時
            // 抄的那一份 —— 開著的期間在首頁（或別台同步過來）把它搬進資料夾，編輯器一存檔
            // 就把舊的「未分類」寫回去，而且帶著新的時戳傳到每一台（使用者回報：分類好的筆記本
            // 又回到未分類）。
            updated.folderId = previous.folderId
            notebooks[idx] = updated
            // 只有**中繼資料**變了才記進同步索引。每次存檔都記的話，
            // 寫一筆字就會把這本筆記的時戳往前推，於是它永遠贏過另一台裝置
            // 對同一本筆記的改名 —— 而那次改名其實比較晚。
            if previous.title != updated.title {
                AccountSyncStore.shared.record(
                    id: updated.id,
                    title: updated.title,
                    parentId: updated.folderId,
                    isFolder: false
                )
            }
            markDirtyAndPersist()
        }
    }

    /// 有就更新、沒有就新增。
    ///
    /// 與 `updateNotebook` 的差別在最後那句：`updateNotebook` 找不到 id 時
    /// **什麼也不做**。同步時另一台裝置新建的筆記本正好是「本機還沒有」的那種，
    /// 走 `updateNotebook` 會靜靜地被丟掉 —— 使用者看到的是「同步成功，
    /// 但筆記沒出現」。
    ///
    /// 也不更新 `lastModifiedDate`：這份內容是從檔案讀回來的，不是使用者剛改的。
    /// - Parameter fromSync: 是同步匯入的結果。要落盤，但**不通知**同步「本機有編輯」（見 `persistData`）。
    public func upsertNotebook(_ doc: NotebookDocument, fromSync: Bool = false) {
        if let index = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(doc.id) == .orderedSame }) {
            notebooks[index] = doc
        } else {
            notebooks.append(doc)
        }
        markDirtyAndPersist(signalsLocalEdit: !fromSync)
    }

    /// 從外部 `.padnote` 封裝檔匯入整本筆記本。
    ///
    /// # 解壓縮走核心，不走 ZIPFoundation
    ///
    /// 套件的壓縮格式是**檔案格式的一部分**（`format-spec.md` §2），
    /// 兩個平台必須解得出一模一樣的東西。各自用平台的 zip 函式庫的話，
    /// 路徑分隔符、大小寫與 Unicode 正規化的處理都不一樣 ——
    /// 而症狀是「在 Android 匯出的筆記，在 iPad 上打開少了幾頁」。
    /// 核心的 `extract_notebook` 兩邊共用，Android 走的是同一支。
    ///
    /// # 內容從套件本身讀，不從另一份中繼資料
    ///
    /// 標題、頁數、筆畫全部在套件裡（manifest + oplog）。另外維護一份
    /// `meta.json` 只會多一個會漂移的真相來源。
    @discardableResult
    public func importNotebookArchive(from archiveUrl: URL) throws -> NotebookDocument {
        let isSecurityScoped = archiveUrl.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                archiveUrl.stopAccessingSecurityScopedResource()
            }
        }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(path: UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let pkgDir = tempDir.appending(path: "notebook.padnote")
        try extractNotebook(archiveFile: archiveUrl.path, outDir: pkgDir.path)

        // 匯入一律給新的 id。沿用檔案裡那個的話，把自己匯出的檔再匯入
        // 就會蓋掉原本那一本 —— 使用者以為多一份副本，實際是少一本。
        let rawFileName = archiveUrl.deletingPathExtension().lastPathComponent
        let newId = UUID().uuidString.lowercased()
        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: pkgDir, deviceId: NotebookMigration.deviceId, documentId: newId)

        // 套件要留下來，否則這本筆記下次開啟是空的 —— 內容在套件裡，
        // `NotebookDocument` 只是畫面用的投影。
        let destination = corePackagesDirectory.appending(path: "\(newId).padnote")
        try? fm.createDirectory(at: corePackagesDirectory, withIntermediateDirectories: true)
        try? fm.removeItem(at: destination)
        try fm.moveItem(at: pkgDir, to: destination)

        // `importDocument` 已經用 `documentId` 建好文件，id 是常數。
        upsertNotebook(imported.document)
        // 筆跡、專業筆刷、圖片也要寫回這台的工作副本。原本只存了文件本身，
        // 編輯器打開時讀的是本機的筆跡檔 —— 全手寫的筆記匯回來每一頁都是空白，圖片也不見
        // （使用者回報：匯出再匯回是空白頁）。這裡走與同步還原同一條路，全部內容算成「已在套件裡」。
        try NotebookSyncCoordinator.applyPackageToWorkingCopy(
            notebookId: newId, store: self, deviceId: NotebookMigration.deviceId)
        guard var document = notebooks.first(where: { $0.id == newId }) else { return imported.document }
        if !rawFileName.isEmpty && (document.title.isEmpty || document.title == "未命名筆記" || document.title == "Untitled Note" || document.title == "notebook") {
            document.title = rawFileName
            upsertNotebook(document)
        }
        AccountSyncStore.shared.record(
            id: newId, title: document.title, parentId: document.folderId, isFolder: false)
        PageThumbnailRenderer.invalidateAll()
        return document
    }

    public func deleteNotebook(id: String) {
        // 移進回收桶，**不是**真的刪。保留期限內還原得回來；期滿才永久刪除
        // （`purgeExpiredTrash`）。設計見 docs/plans/expiry-purge.md。
        if !trashLocally(id: id) {
            // 不在清單裡（只剩一個孤立的套件目錄）：沒有東西可以進回收桶，直接清掉。
            purgeLocally(id: id)
        }
        AccountSyncStore.shared.recordDeletion(id: id)
        // 使用者資料夾裡的副本照舊立刻移除（那是匯出／備份用的資料夾，不是 App 的資料）。
        removeFolderSyncCopy(id: id)
        persistData()
    }

    // MARK: - 回收桶

    /// 回收桶裡的筆記本。`NotebookDocument` 本身存在 `trash_v1.json`，
    /// 套件目錄搬到 `TrashPackages/`。
    ///
    /// **套件搬離 `corePackagesDirectory`，而不是留在原地打個記號。**
    /// 同步與匯入有十幾處會列舉那個目錄，任何一處漏判「已在回收桶」，
    /// 這本筆記就會被當成新筆記匯回來 —— 刪掉的東西自己復活。搬走之後，
    /// 那些程式碼根本看不到它。
    @Published public var trashedNotebooks: [NotebookDocument] = []

    /// 回收桶裡的套件與同步基準線。
    public var trashPackagesDirectory: URL {
        documentsDir.appending(path: "TrashPackages")
    }

    /// 一個筆記本 id 在磁碟上可能的目錄名（舊資料的 id 可能有大寫）。
    private func packageDirectoryNames(for id: String) -> [String] {
        var names = ["\(id).padnote"]
        let lower = "\(id.lowercased()).padnote"
        if lower != names[0] { names.append(lower) }
        return names
    }

    private func moveIfExists(_ from: URL, to: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: from.path) else { return }
        try? fm.createDirectory(
            at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: to)
        try? fm.moveItem(at: from, to: to)
    }

    /// 移進回收桶（**只動本機**，不記墓碑）。回傳有沒有真的移。
    ///
    /// 記墓碑是呼叫端的事（`deleteNotebook`）—— 分開是為了讓檔案搬移可以單獨測，
    /// 不必碰到全域的同步索引。
    @discardableResult
    public func trashLocally(id: String) -> Bool {
        guard let index = notebooks.firstIndex(where: {
            $0.id.caseInsensitiveCompare(id) == .orderedSame
        }) else { return false }
        let document = notebooks[index]
        if activeNotebookId?.caseInsensitiveCompare(id) == .orderedSame {
            activeNotebookId = nil
        }
        withAnimation {
            _ = notebooks.remove(at: index)
        }
        trashedNotebooks.removeAll { $0.id.caseInsensitiveCompare(id) == .orderedSame }
        trashedNotebooks.append(document)

        for name in packageDirectoryNames(for: id) {
            moveIfExists(
                corePackagesDirectory.appending(path: name),
                to: trashPackagesDirectory.appending(path: name))
            moveIfExists(
                documentsDirectory.appending(path: "SyncBaseline/\(name)"),
                to: trashPackagesDirectory.appending(path: "SyncBaseline/\(name)"))
        }
        return true
    }

    /// 從回收桶還原（**只動本機**，不記還原）。回傳有沒有真的還原。
    @discardableResult
    public func restoreLocally(id: String) -> Bool {
        guard let index = trashedNotebooks.firstIndex(where: {
            $0.id.caseInsensitiveCompare(id) == .orderedSame
        }) else { return false }
        var document = trashedNotebooks.remove(at: index)

        for name in packageDirectoryNames(for: id) {
            moveIfExists(
                trashPackagesDirectory.appending(path: name),
                to: corePackagesDirectory.appending(path: name))
            moveIfExists(
                trashPackagesDirectory.appending(path: "SyncBaseline/\(name)"),
                to: documentsDirectory.appending(path: "SyncBaseline/\(name)"))
        }
        // 刪除前的資料夾已經不在了：放回「未分類」，並記進同步索引（別台也放到同一個地方）。
        if document.folderId != nil, treeFolderId(of: document) == nil {
            document.folderId = nil
            AccountSyncStore.shared.recordParent(id: document.id, parentId: nil)
        }
        // 已經有同 id 的（不該發生）就不要再塞一份，否則 ForEach 的識別會壞。
        if !notebooks.contains(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) {
            withAnimation {
                notebooks.append(document)
            }
        }
        return true
    }

    /// 永久刪除本機的一本（**只動本機**）：回收桶裡的紀錄、套件、同步基準線。
    ///
    /// 原本的位置也一併清 —— 正常不會有東西留在那裡，但殘留的話等於沒刪乾淨。
    /// - Returns: 這一次**真的刪掉了東西**。索引裡的墓碑要等雲端確認才會消失，期滿名單
    ///   每一輪都一樣；不回報這個的話，每輪同步都會宣稱「已清理 N 本」，而實際上什麼都沒動。
    @discardableResult
    public func purgeLocally(id: String) -> Bool {
        var removedAny = false
        let before = trashedNotebooks.count
        trashedNotebooks.removeAll { $0.id.caseInsensitiveCompare(id) == .orderedSame }
        if trashedNotebooks.count != before { removedAny = true }
        let fm = FileManager.default
        for name in packageDirectoryNames(for: id) {
            for url in [
                trashPackagesDirectory.appending(path: name),
                trashPackagesDirectory.appending(path: "SyncBaseline/\(name)"),
                corePackagesDirectory.appending(path: name),
                documentsDirectory.appending(path: "SyncBaseline/\(name)"),
            ] where fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
                removedAny = true
            }
        }
        removeFolderSyncCopy(id: id)
        return removedAny
    }

    /// 使用者資料夾（雲端／匯出）裡這本筆記本的副本。
    private func removeFolderSyncCopy(id: String) {
        guard let cloudFolder = CloudSyncFolder.resolveFolder() else { return }
        let scoped = cloudFolder.startAccessingSecurityScopedResource()
        defer { if scoped { cloudFolder.stopAccessingSecurityScopedResource() } }
        for name in packageDirectoryNames(for: id) {
            try? FileManager.default.removeItem(at: cloudFolder.appending(path: name))
        }
    }

    /// 從回收桶還原並記下還原（別的裝置也會看到它回來）。
    @discardableResult
    public func restoreNotebook(id: String) -> Bool {
        AccountSyncStore.shared.recordRestore(id: id)
        guard restoreLocally(id: id) else { return false }
        if let restored = notebooks.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }),
           restored.folderId == nil {
            AccountSyncStore.shared.recordParent(id: restored.id, parentId: nil)
        }
        markDirtyAndPersist(signalsLocalEdit: true)
        return true
    }

    /// 永久刪除回收桶裡的一本。墓碑留著（不然別台會把它傳回來）。
    public func purgeNotebookPermanently(id: String) {
        // 先把「立即永久刪除」寫進墓碑，再清本機 —— 雲端那一半與別台的副本靠它自然完成。
        AccountSyncStore.shared.recordPurgeRequest(id: id)
        purgeLocally(id: id)
        persistData()
    }

    /// 永久清掉**已期滿**的本機筆記本。啟動時與每輪同步之後呼叫。
    /// 期限由核心算（`AccountSyncStore.expiredNotebookIdsForLocalPurge`）。
    @discardableResult
    public func purgeExpiredTrash() -> Int {
        AccountSyncStore.shared.stampLegacyTombstonesIfNeeded()
        let expired = AccountSyncStore.shared.expiredNotebookIdsForLocalPurge()
        let purged = expired.filter { purgeLocally(id: $0) }
        if !purged.isEmpty { persistData(signalsLocalEdit: false) }
        return purged.count
    }

    /// 清空回收桶（使用者按了「立即清除」）。雲端那一半由呼叫端接著觸發回收。
    @discardableResult
    public func emptyTrash() -> Int {
        let ids = trashedNotebooks.map(\.id)
        for id in ids {
            AccountSyncStore.shared.recordPurgeRequest(id: id)
            purgeLocally(id: id)
        }
        if !ids.isEmpty { persistData() }
        return ids.count
    }

    /// 依據同步收斂後的刪除墓碑名單，讓本機與索引一致。
    ///
    /// - **別台刪掉的** → 這台也移進回收桶（**不是**永久刪除）。資料留到期滿，
    ///   使用者在這台看得到、還原得回來，而不是被別台的一個動作直接抹掉。
    /// - **別台還原的** → 這台回收桶裡那一本自動救回來。套件目錄還在，
    ///   如果不救的話，同步看到「套件已存在」會略過複製，於是這本筆記
    ///   不會出現在清單裡。
    ///
    /// 兩個方向都**以現在的索引為準**，不用傳進來的名單：同步進行到一半時使用者
    /// 可能剛好刪了或還原了一本，用開頭算好的名單會把它倒回去。
    public func syncPurgeDeletedNotebooks(_ deletedIds: Set<String>) {
        var changed = false

        for id in deletedIds where AccountSyncStore.shared.isDeleted(id: id) {
            if trashLocally(id: id) { changed = true }
        }
        for document in trashedNotebooks where !AccountSyncStore.shared.isDeleted(id: document.id) {
            if restoreLocally(id: document.id) { changed = true }
        }

        if changed {
            persistData(signalsLocalEdit: false)
        }
    }

    @discardableResult
    public func duplicateNotebook(id: String) -> NotebookDocument? {
        guard let original = notebooks.first(where: { $0.id == id }) else { return nil }
        var copy = original
        copy = NotebookDocument(
            title: String(format: LocalizationManager.shared.localized("copy_suffix"), original.title),
            createdAt: Date(),
            lastModifiedDate: Date(),
            pageCount: original.pageCount,
            hasRecording: original.hasRecording,
            previewSnippet: original.previewSnippet,
            template: original.template,
            recordingAudioPath: original.recordingAudioPath,
            folderId: original.folderId,
            pagesData: original.pagesData,
            pageHeights: original.pageHeights,
            attachments: original.attachments,
            textAttachments: original.textAttachments,
            linkAttachments: original.linkAttachments,
            model3DAttachments: original.model3DAttachments,
            commentPins: original.commentPins
        )
        notebooks.insert(copy, at: 0)
        AccountSyncStore.shared.record(
            id: copy.id,
            title: copy.title,
            parentId: copy.folderId,
            isFolder: false
        )
        persistData()
        return copy
    }

    public func renameNotebook(id: String, newTitle: String) {
        guard let idx = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else { return }
        // 範例是唯讀的，名字也不改（要自己的名字請先編輯，另存出來的那一本可以改名）。
        guard !notebooks[idx].isReadOnlySample else { return }
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            notebooks[idx].title = clean
            // 使用者親自命名之後就不再翻譯，否則改了名字又被語系蓋回去。
            notebooks[idx].titleKey = nil
            notebooks[idx].lastModifiedDate = Date()
            AccountSyncStore.shared.recordTitle(id: notebooks[idx].id, title: notebooks[idx].title)
            // 同步更新磁碟上的 .padnote 套件標題，並觸摸修改時間促使 workingCopyNeedsExport 判定為新
            let packagePath = corePackagesDirectory.appending(path: "\(notebooks[idx].id.lowercased()).padnote")
            if FileManager.default.fileExists(atPath: packagePath.path),
               let session = try? PadnoteSession.openExisting(path: packagePath.path, deviceId: NotebookMigration.deviceId) {
                try? session.setTitle(title: clean)
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: packagePath.path)
            }
            markDirtyAndPersist(signalsLocalEdit: true)
        }
    }

    // MARK: - 資料夾管理 CRUD

    @discardableResult
    public func createFolder(name: String, parentId: String? = nil, colorHex: String? = nil) -> FolderItem {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.t("folder_new_default") : name
        let validParentId: String? = {
            guard let p = parentId?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty else { return nil }
            if AccountSyncStore.shared.isDeleted(id: p) || isHiddenBySync(p) { return nil }
            return p
        }()
        let folder = FolderItem(name: cleanName, parentId: validParentId, colorHex: colorHex)
        folders.append(folder)
        AccountSyncStore.shared.record(
            id: folder.id,
            title: cleanName,
            parentId: validParentId,
            isFolder: true
        )
        markDirtyAndPersist(signalsLocalEdit: true)
        return folder
    }

    public func renameFolder(id: String, newName: String) {
        guard let idx = folders.firstIndex(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else { return }
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            folders[idx].name = clean
            folders[idx].nameKey = nil
            AccountSyncStore.shared.recordTitle(id: folders[idx].id, title: clean)
            markDirtyAndPersist(signalsLocalEdit: true)
        }
    }

    public func deleteFolder(id: String) {
        // 將該資料夾內的筆記安全移回其父資料夾（若無父資料夾則移回根目錄 nil）
        let targetFolder = folders.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame })
        let fallbackParentId = targetFolder?.parentId
        // 每一個被搬出來的項目都要記進索引 —— 只記「資料夾刪了」的話，
        // 另一台裝置合併之後會依照核心的規則把裡面的東西一起隱藏
        // （已刪資料夾底下的項目不顯示），而它們在這台其實已經搬到外面了。
        for i in 0..<notebooks.count {
            if notebooks[i].folderId?.caseInsensitiveCompare(id) == .orderedSame {
                notebooks[i].folderId = fallbackParentId
                AccountSyncStore.shared.recordParent(id: notebooks[i].id, parentId: fallbackParentId)
            }
        }
        // 將該資料夾底下的子資料夾提升至父資料夾
        for i in 0..<folders.count {
            if folders[i].parentId?.caseInsensitiveCompare(id) == .orderedSame {
                folders[i].parentId = fallbackParentId
                AccountSyncStore.shared.recordParent(id: folders[i].id, parentId: fallbackParentId)
            }
        }
        folders.removeAll { $0.id.caseInsensitiveCompare(id) == .orderedSame }
        AccountSyncStore.shared.recordDeletion(id: id)
        markDirtyAndPersist(signalsLocalEdit: true)
    }

    public func renameRootFolder(newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            rootFolderName = clean
            persistData()
        }
    }

    public func moveNotebook(id: String, toFolderId: String?) {
        guard let idx = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else { return }
        notebooks[idx].folderId = toFolderId
        notebooks[idx].lastModifiedDate = Date()
        AccountSyncStore.shared.recordParent(id: notebooks[idx].id, parentId: toFolderId)
        markDirtyAndPersist(signalsLocalEdit: true)
    }

    /// 另一台裝置刪掉的東西，這台要跟著藏起來。
    ///
    /// # 這件事以前完全沒有做
    ///
    /// 刪除**寫**進同步索引是有的（`recordDeletion`），但從來沒有人**讀**它 ——
    /// `AccountSyncStore.isDeleted` 在整個 Apple 端一個呼叫端都沒有。
    /// 結果是：在 Android 刪掉一本筆記，同步到 iPad 之後它還在，
    /// 而且每一輪同步都把它原封不動留著。
    ///
    /// 用核心的 `sync_is_hidden` 而不是 `sync_is_deleted`：後者只看自己那一筆，
    /// 刪掉一個資料夾之後，裡面的筆記本仍然會被列出來 ——
    /// 那就是「存在但打不開、也刪不掉」的幽靈。
    ///
    /// **索引裡沒看過的一律不藏。** 「沒看過」不是「被刪了」：剛建好還沒
    /// 同步過的筆記本會落在這個狀態，藏起來的話它在使用者眼前憑空消失。
    private var isHiddenCache = [String: Bool]()
    private var lastIndexJSONForHidden: String = ""

    public func isHiddenBySync(_ id: String) -> Bool {
        let indexJSON = AccountSyncStore.shared.indexJSON
        if indexJSON != lastIndexJSONForHidden {
            isHiddenCache.removeAll(keepingCapacity: true)
            lastIndexJSONForHidden = indexJSON
        }
        if let cached = isHiddenCache[id] { return cached }
        let result = syncIsHidden(indexJson: indexJSON, itemId: id)
        isHiddenCache[id] = result
        return result
    }

    /// 檢查並修復資料夾階層中的循環引用與自我引用，避免遞迴無窮迴圈（工作項 S-62、G-05）
    public func sanitizeFolders() {
        var folderMap = [String: FolderItem]()
        for folder in folders {
            folderMap[folder.id.lowercased()] = folder
        }

        var changed = false
        var cleanedFolders: [FolderItem] = []

        for var folder in folders {
            let fId = folder.id.lowercased()
            if let pId = folder.parentId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                // 1. 自指保護：若 parentId 指向自己，重設為 nil
                if pId == fId {
                    folder.parentId = nil
                    changed = true
                } else {
                    // 2. 迴圈保護：檢查祖先鏈是否成環
                    var seen = Set<String>([fId])
                    var cursor: String? = pId
                    var hasCycle = false
                    while let c = cursor {
                        if seen.contains(c) {
                            hasCycle = true
                            break
                        }
                        seen.insert(c)
                        cursor = folderMap[c]?.parentId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }
                    if hasCycle {
                        folder.parentId = nil
                        changed = true
                    }
                }
            }
            cleanedFolders.append(folder)
        }

        if changed {
            self.folders = cleanedFolders
        }
    }

    public func subfolders(of parentId: String?) -> [FolderItem] {
        let target = parentId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let target, !target.isEmpty {
            return folders.filter {
                let fId = $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let pId = $0.parentId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return pId == target && fId != target && !isHiddenBySync($0.id)
            }
        } else {
            // 最上層：沒有上層的，**以及上層已經不存在的**。後者不放這裡的話，它和裡面的筆記本
            // 在樹上無處可去 —— 首頁「全部筆記」看不到、卻還算在其他地方的數字裡。
            let liveFolderIds = Set(folders.filter { !isHiddenBySync($0.id) }.map {
                $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })
            return folders.filter {
                let fId = $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let pId = $0.parentId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let orphan = pId.map { !$0.isEmpty && !liveFolderIds.contains($0) } ?? false
                return (pId == nil || pId?.isEmpty == true || pId == fId || orphan)
                    && !isHiddenBySync($0.id)
            }
        }
    }

    /// 這本筆記本在首頁樹上該放在哪個資料夾：它的資料夾還在就是那個，否則是「未分類」（nil）。
    ///
    /// 從回收桶還原的筆記本帶著刪除前的資料夾；那個資料夾之後被刪掉的話，它在樹上就無處可去 ——
    /// 「繼續」看得到、「全部筆記」看不到（使用者回報）。
    public func treeFolderId(of notebook: NotebookDocument) -> String? {
        guard let folder = notebook.folderId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !folder.isEmpty else { return nil }
        let exists = folders.contains {
            $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == folder && !isHiddenBySync($0.id)
        }
        return exists ? folder : nil
    }

    public func notebooks(in folderId: String?) -> [NotebookDocument] {
        let target = folderId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let target, !target.isEmpty {
            return notebooks.filter {
                $0.folderId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
                && !isHiddenBySync($0.id)
            }
        } else {
            return notebooks.filter { treeFolderId(of: $0) == nil && !isHiddenBySync($0.id) }
        }
    }

    /// 清單要顯示的筆記本。**不要用 `notebooks`** —— 那一份是真相來源，
    /// 編輯器靠它找得到目前開著的那一本，過濾掉會讓正在編輯的筆記消失。
    public var visibleNotebooks: [NotebookDocument] {
        notebooks.filter {
            !isHiddenBySync($0.id) &&
            $0.id.caseInsensitiveCompare(recordingInboxNotebookId()) != .orderedSame
        }
    }

    // MARK: - 集中單一事實分頁管理 (Atomic Page Management)

    /// 為指定筆記安全原子新增下一頁，回傳新頁碼 index
    @discardableResult
    public func addPage(notebookId: String, paperId: String? = nil, pageId: String? = nil) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return 0 }
        let oldPageCount = max(1, notebooks[idx].pageCount)
        let newPageCount = oldPageCount + 1
        notebooks[idx].alignPageIds()
        notebooks[idx].pageCount = newPageCount
        if notebooks[idx].pageIds != nil {
            notebooks[idx].pageIds?.append(pageId ?? UUID().uuidString.lowercased())
        }

        // 確保 pageHeights 陣列長度對齊
        let defaultHeight = notebooks[idx].pageSize.height
        var heights = notebooks[idx].pageHeights ?? Array(repeating: defaultHeight, count: oldPageCount)
        while heights.count < newPageCount {
            heights.append(defaultHeight)
        }
        notebooks[idx].pageHeights = heights
        // 逐頁樣板也要跟著長一格，否則新頁在陣列裡取不到、退回整本的樣板 ——
        // 那在「這一頁想用別的格式」之後就是錯的。
        notebooks[idx].padPagePaperIds(to: oldPageCount)
        notebooks[idx].pagePaperIds?.append(paperId ?? notebooks[idx].template.paperId)
        notebooks[idx].lastModifiedDate = Date()

        let newPageIndex = newPageCount - 1
        // 新的一頁從空白開始：舊版刪頁留下的專業筆畫、同步記帳不能被它撿回來。
        removePageFiles(notebookId: notebookId, page: newPageIndex)
        remapPageKeyedFields(at: idx) { $0 == newPageIndex ? nil : $0 }
        // 儲存空白筆跡至磁碟
        saveDrawing(notebookId: notebookId, pageIndex: newPageIndex, drawing: PKDrawing())
        persistData()
        return newPageIndex
    }

    /// 在指定頁面後方插入新頁面，平移後續頁面並回傳新插入頁面之 pageIndex
    @discardableResult
    public func insertPage(notebookId: String, afterIndex: Int, paperId: String? = nil, pageId: String? = nil) -> Int {
        insertPages(notebookId: notebookId, afterIndex: afterIndex, count: 1, paperId: paperId,
                    pageIds: pageId.map { [$0] })
    }

    /// 在指定頁面後方一次插入 `count` 頁，回傳第一個新頁的 pageIndex。
    ///
    /// # 為什麼不是呼叫 `insertPage` 很多次
    ///
    /// 每插一頁都要把插入點之後**每一頁**的逐頁檔案（筆跡、專業筆畫、同步記帳）改名一次、
    /// 再落盤一次中繼資料。匯入一份 30 頁的 PDF 就是 30 輪 —— 在主執行緒上、而且文件庫
    /// 可能在外接磁碟上。這裡只挪一次、只寫一次。
    @discardableResult
    public func insertPages(
        notebookId: String, afterIndex: Int, count: Int, paperId: String? = nil, pageIds newIds: [String]? = nil
    ) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return 0 }
        let count = max(1, count)
        let oldPageCount = max(1, notebooks[idx].pageCount)
        let newPageCount = oldPageCount + count
        let insertIndex = min(max(0, afterIndex + 1), oldPageCount)
        notebooks[idx].alignPageIds()
        if notebooks[idx].pageIds != nil {
            let ids = (0 ..< count).map { i in
                (newIds?.indices.contains(i) == true ? newIds?[i] : nil) ?? UUID().uuidString.lowercased()
            }
            notebooks[idx].pageIds?.insert(contentsOf: ids,
                                           at: min(insertIndex, notebooks[idx].pageIds?.count ?? 0))
        }

        // 插入點之後每一頁的所有逐頁檔案往後挪（不只 `.drawing`：專業筆畫、同步記帳也是以頁碼命名）。
        removePageFiles(notebookId: notebookId, pages: Set(oldPageCount ..< newPageCount))
        shiftPageFiles(notebookId: notebookId, from: insertIndex, through: oldPageCount - 1, by: count)
        // 新插入的頁面設為空白
        for page in insertIndex ..< insertIndex + count {
            saveDrawing(notebookId: notebookId, pageIndex: page, drawing: PKDrawing())
        }
        remapPageKeyedFields(at: idx) { $0 >= insertIndex ? $0 + count : $0 }

        // 更新 pageHeights
        let defaultHeight = notebooks[idx].pageSize.height
        var heights = notebooks[idx].pageHeights ?? Array(repeating: defaultHeight, count: oldPageCount)
        while heights.count < oldPageCount {
            heights.append(defaultHeight)
        }
        heights.insert(contentsOf: Array(repeating: defaultHeight, count: count), at: insertIndex)
        notebooks[idx].pageHeights = heights

        notebooks[idx].padPagePaperIds(to: oldPageCount)
        notebooks[idx].pagePaperIds?.insert(
            contentsOf: Array(repeating: paperId ?? notebooks[idx].template.paperId, count: count),
            at: min(insertIndex, notebooks[idx].pagePaperIds?.count ?? 0))

        // 每一種附件都要重新對齊頁碼。
        //
        // **表格、形狀、連接線與錄音原本整組漏掉了** —— 與刪除頁面同一個
        // 病灶：前面那幾種各自手寫一份「插入點之後的往後移一格」，新增型別
        // 時沒有人回來補。症狀是「我在第 1 頁後面插了一頁，第 2 頁的表格
        // 留在原地，現在它落在那張新的空白頁上」。
        //
        // 算術在核心（`pageIndexAfterInsert`），這裡只負責把每一種餵進去。
        for _ in 0 ..< count {
            notebooks[idx].attachments = Self.shiftPages(
                notebooks[idx].attachments, inserting: insertIndex)
            notebooks[idx].textAttachments = Self.shiftPages(
                notebooks[idx].textAttachments, inserting: insertIndex)
            notebooks[idx].linkAttachments = Self.shiftPages(
                notebooks[idx].linkAttachments, inserting: insertIndex)
            notebooks[idx].model3DAttachments = Self.shiftPages(
                notebooks[idx].model3DAttachments, inserting: insertIndex)
            notebooks[idx].commentPins = Self.shiftPages(
                notebooks[idx].commentPins, inserting: insertIndex)
            notebooks[idx].tableAttachments = Self.shiftPages(
                notebooks[idx].tableAttachments, inserting: insertIndex)
            notebooks[idx].shapeAttachments = Self.shiftPages(
                notebooks[idx].shapeAttachments, inserting: insertIndex)
            notebooks[idx].connectionAttachments = Self.shiftPages(
                notebooks[idx].connectionAttachments, inserting: insertIndex)
            notebooks[idx].audioAttachments = Self.shiftPages(
                notebooks[idx].audioAttachments, inserting: insertIndex)
            notebooks[idx].tapeAttachments = Self.shiftPages(
                notebooks[idx].tapeAttachments, inserting: insertIndex)
            notebooks[idx].stickyAnchors = Self.shiftPages(
                notebooks[idx].stickyAnchors, inserting: insertIndex)
        }

        // 內嵌筆跡陣列也要跟著長一頁，否則 pagesData 與 pageCount 會錯開，
        // 而匯出是看前者的 —— 插入的那一頁在 PDF 裡不存在。
        if insertIndex <= notebooks[idx].pagesData.count {
            notebooks[idx].pagesData.insert(
                contentsOf: Array(repeating: PKDrawing().dataRepresentation(), count: count), at: insertIndex)
        }

        notebooks[idx].pageCount = newPageCount
        notebooks[idx].lastModifiedDate = Date()
        persistData()
        return insertIndex
    }

    /// 把整份匯入的 PDF 頁面放上內頁：第 `firstPage + i` 頁放第 `i` 張，整頁大小、鎖定在畫布上。
    ///
    /// **鎖定**：PDF 頁面是被標註的底稿。不鎖的話，打字模式下點頁面任何一處都會選到這張
    /// 整頁的圖、開始拖它，而不是新增文字。要搬動或刪除時從圖層面板解除鎖定。
    ///
    /// 圖層不必另外設定：依核心規則，圖片本來就在筆跡下方。
    func placePdfPages(notebookId: String, pages: [PdfImportedPage], firstPage: Int) {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }), !pages.isEmpty else { return }
        var doc = notebooks[idx]
        if doc.attachments == nil { doc.attachments = [] }
        for (offset, page) in pages.enumerated() {
            let pageIndex = firstPage + offset
            let attachment = NoteImageAttachment(
                fileName: page.fileName,
                pageIndex: pageIndex,
                x: page.frame.minX, y: page.frame.minY,
                width: page.frame.width, height: page.frame.height,
                rotationDegrees: 0,
                cornerRadius: 0,
                hasShadow: false,
                hasBorder: false,
                filterStyle: .original)
            doc.attachments?.append(attachment)
            doc.setLockedObjectIds(doc.lockedObjectIds(forPage: pageIndex).union([attachment.id]), forPage: pageIndex)
            // 堆疊順序：底稿放在這一頁最底下，之後插入的東西都在它上面。
            let order = doc.objectOrder(forPage: pageIndex) ?? []
            doc.setObjectOrder([attachment.id] + order.filter { $0 != attachment.id }, forPage: pageIndex)
        }
        updateNotebook(doc)
    }

    /// 由一份外部 PDF 直接建立筆記本：頁面尺寸自動跟隨 PDF，並將各頁面作為鎖定底稿載入。
    @discardableResult
    public func createNotebookFromPdf(fileURL: URL) -> NotebookDocument? {
        let isAccessing = fileURL.startAccessingSecurityScopedResource()
        defer { if isAccessing { fileURL.stopAccessingSecurityScopedResource() } }

        guard let doc = PDFDocument(url: fileURL), doc.pageCount > 0 else { return nil }

        let page0 = doc.page(at: 0)
        let box = page0?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 800, height: 1132)
        let formatId = pdfRecommendedPageFormat(sourceWidth: Float(box.width), sourceHeight: Float(box.height))

        let titleRaw = fileURL.deletingPathExtension().lastPathComponent
        let title = titleRaw.isEmpty ? LocalizationManager.shared.localizedUnsafe("new_notebook") : titleRaw
        var created = createNotebook(title: title, template: .blank)
        created.pageFormatId = formatId
        updateNotebook(created)

        let pageSize = PageGeometry.size(forFormat: formatId)
        var importedPages: [PdfImportedPage] = []
        for i in 0 ..< doc.pageCount {
            if let imported = PdfPageRenderer.importPage(
                document: doc, index: i, pageSize: pageSize, into: attachmentsDirectory
            ) {
                importedPages.append(imported)
            }
        }

        guard !importedPages.isEmpty else { return nil }

        let extraPages = importedPages.count - 1
        if extraPages > 0 {
            insertPages(notebookId: created.id, afterIndex: 0, count: extraPages, paperId: created.paperId(forPage: 0))
        }

        placePdfPages(notebookId: created.id, pages: importedPages, firstPage: 0)

        return notebooks.first(where: { $0.id == created.id }) ?? created
    }

    /// 刪除指定頁面，平移後續頁面並回傳安全之 currentPageIndex
    @discardableResult
    public func deletePage(notebookId: String, pageIndex: Int, currentIndex: Int) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return 0 }
        let total = notebooks[idx].pageCount
        guard total > 1, pageIndex >= 0, pageIndex < total else { return currentIndex }

        // 記下刪掉的是哪一頁（id），同步時寫成 `RemovePage` —— 不寫的話別台的 oplog 會把它加回來。
        // 沒記頁面 id 的舊筆記先採用套件裡的那批，刪的才是同步那邊的同一頁。
        if notebooks[idx].pageIds == nil {
            notebooks[idx].pageIds = NotebookPackageBridge.resolvedPageIds(
                for: notebooks[idx], packagesDirectory: corePackagesDirectory)
        }
        if let ids = notebooks[idx].pageIds, pageIndex < ids.count {
            SyncDeletedPages.record([ids[pageIndex]], notebookId)
        }

        // 刪掉這一頁的所有逐頁檔案，後面每一頁往前挪一頁。只平移 `.drawing` 的話，
        // 專業筆畫與同步記帳留在原頁碼 —— 刪掉的那一頁的炭筆字跑到下一頁上。
        removePageFiles(notebookId: notebookId, page: pageIndex)
        shiftPageFiles(notebookId: notebookId, from: pageIndex + 1, through: total - 1, by: -1)
        remapPageKeyedFields(at: idx) { page in
            page == pageIndex ? nil : (page > pageIndex ? page - 1 : page)
        }

        // 平移高度陣列
        if var heights = notebooks[idx].pageHeights, heights.count >= total {
            heights.remove(at: pageIndex)
            notebooks[idx].pageHeights = heights
        }

        // 平移附件之 pageIndex
        notebooks[idx].attachments = Self.shiftPages(
            notebooks[idx].attachments, removing: pageIndex)
        notebooks[idx].textAttachments = Self.shiftPages(
            notebooks[idx].textAttachments, removing: pageIndex)
        notebooks[idx].linkAttachments = Self.shiftPages(
            notebooks[idx].linkAttachments, removing: pageIndex)
        notebooks[idx].model3DAttachments = Self.shiftPages(
            notebooks[idx].model3DAttachments, removing: pageIndex)
        notebooks[idx].commentPins = Self.shiftPages(
            notebooks[idx].commentPins, removing: pageIndex)

        // 每一種附件都要重新對齊頁碼。
        //
        // **表格、形狀、連接線與錄音原本整組漏掉了。**
        //
        // 前面那幾種各自寫了一份幾乎一樣的「刪掉這一頁的、後面的往前移」，
        // 而新增型別時沒有人記得回來加 —— 症狀是：按了刪除頁面，頁數確實
        // 少了一頁，但那一頁上的表格與圖形**還在**，而且跑到別頁去了。
        // 使用者看到的就是「刪不掉，只是把內容清掉」。
        //
        // 改成一個泛型函式：之後新增型別時，漏掉會是編譯期的事，
        // 不是使用者在某一頁上發現多了一張表。
        notebooks[idx].tableAttachments = Self.shiftPages(
            notebooks[idx].tableAttachments, removing: pageIndex)
        notebooks[idx].shapeAttachments = Self.shiftPages(
            notebooks[idx].shapeAttachments, removing: pageIndex)
        notebooks[idx].connectionAttachments = Self.shiftPages(
            notebooks[idx].connectionAttachments, removing: pageIndex)
        notebooks[idx].audioAttachments = Self.shiftPages(
            notebooks[idx].audioAttachments, removing: pageIndex)
        notebooks[idx].tapeAttachments = Self.shiftPages(
            notebooks[idx].tapeAttachments, removing: pageIndex)
        notebooks[idx].stickyAnchors = Self.shiftPages(
            notebooks[idx].stickyAnchors, removing: pageIndex)

        // 內嵌的筆跡陣列也要跟著縮短。
        //
        // 不縮的話 `pagesData.count` 會永遠比 `pageCount` 多，而
        // 「這本筆記是不是空的」「匯出幾頁」都在看前者 —— 刪掉的那一頁
        // 會在匯出的 PDF 裡復活。
        if pageIndex < notebooks[idx].pagesData.count {
            notebooks[idx].pagesData.remove(at: pageIndex)
        }
        notebooks[idx].alignPageIds()
        if var ids = notebooks[idx].pageIds, pageIndex < ids.count {
            ids.remove(at: pageIndex)
            notebooks[idx].pageIds = ids
        }
        if var ids = notebooks[idx].pagePaperIds, pageIndex < ids.count {
            ids.remove(at: pageIndex)
            notebooks[idx].pagePaperIds = ids
        }

        let newPageCount = total - 1
        notebooks[idx].pageCount = newPageCount
        notebooks[idx].lastModifiedDate = Date()
        persistData()

        var safeCurrent = currentIndex
        if safeCurrent >= newPageCount {
            safeCurrent = max(0, newPageCount - 1)
        }
        return safeCurrent
    }

    /// 刪掉某一頁之後，把附件的 `pageIndex` 重新對齊。
    ///
    /// 這一頁上的整個丟掉，後面每一頁往前移一格。所有附件型別共用這一份 ——
    /// 各寫一份的結果是新增型別時漏掉其中一種，而那要等到使用者在別的頁上
    /// 看到一張不該在那裡的表格才會被發現。
    static func shiftPages<T: PageIndexed>(_ items: [T]?, removing pageIndex: Int) -> [T]? {
        guard let items else { return nil }
        return items.compactMap { item in
            if item.pageIndex == pageIndex { return nil }
            var moved = item
            if moved.pageIndex > pageIndex { moved.pageIndex -= 1 }
            return moved
        }
    }

    /// 插入一頁之後，把附件的 `pageIndex` 重新對齊。
    ///
    /// 算術在核心：插入、刪除、搬動三種情況的區間各不相同，各寫一份的人
    /// 會在其中一個方向上差一格，而差一格的症狀（東西跑到隔壁頁）要等到
    /// 使用者翻到那一頁才會發現。
    static func shiftPages<T: PageIndexed>(_ items: [T]?, inserting insertIndex: Int) -> [T]? {
        guard let items else { return nil }
        guard insertIndex >= 0 else { return items }
        return items.map { item in
            var moved = item
            moved.pageIndex = Int(pageIndexAfterInsert(index: UInt32(max(0, item.pageIndex)),
                                                      at: UInt32(insertIndex)))
            return moved
        }
    }

    /// 搬動一頁之後，把附件的 `pageIndex` 重新對齊。
    static func shiftPages<T: PageIndexed>(_ items: [T]?, movingFrom from: Int, to: Int) -> [T]? {
        guard let items else { return nil }
        guard from >= 0, to >= 0 else { return items }
        return items.map { item in
            var moved = item
            moved.pageIndex = Int(pageIndexAfterMove(index: UInt32(max(0, item.pageIndex)),
                                                    from: UInt32(from),
                                                    to: UInt32(to)))
            return moved
        }
    }

    /// 把某一頁搬到另一個位置，回傳搬完之後應該停在哪一頁。
    ///
    /// # 為什麼不是「把陣列重排就好」
    ///
    /// 一頁不是一筆資料，是散在四個地方的東西：磁碟上的筆跡檔案
    /// （`{id}_p{n}.drawing`，檔名就是頁碼）、`pageHeights`、`pagesData`，
    /// 以及九種附件各自的 `pageIndex`。只重排其中一樣的結果不是「沒搬動」，
    /// 是「筆跡搬了、上面的表格沒搬」—— 比不能搬還糟。
    ///
    /// 只重寫兩個端點之間那一段（`pageMoveTouchedRange`）：整本重寫在
    /// 幾十頁的筆記上是看得到的卡頓，而搬一頁本來就只會動到那一段。
    @discardableResult
    public func movePage(notebookId: String, from: Int, to: Int) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return from }
        let total = notebooks[idx].pageCount
        guard from >= 0, to >= 0,
              pageMoveIsValid(count: UInt32(max(0, total)),
                              from: UInt32(from),
                              to: UInt32(to)) else { return from }

        // 1. 每一頁在磁碟上的檔案：不只 `.drawing`，專業筆畫（`.proink*.json`）、擦除帳本、
        //    同步基準與上次匯出的快照也都以頁碼命名。只搬 `.drawing` 的結果是 PencilKit 的字跡
        //    搬過去了，炭筆／蠟筆寫的字、同步記帳留在原頁 —— 下一輪同步再把舊的帶回來。
        let touched = pageMoveTouchedRange(from: UInt32(from), to: UInt32(to)).map { Int($0) }
        permutePageFiles(notebookId: notebookId, pages: Set(touched)) { page in
            Int(pageIndexAfterMove(index: UInt32(page), from: UInt32(from), to: UInt32(to)))
        }

        // 2. 高度與內嵌筆跡陣列：單純的搬一格。
        if var heights = notebooks[idx].pageHeights, heights.count >= total {
            let h = heights.remove(at: from)
            heights.insert(h, at: min(to, heights.count))
            notebooks[idx].pageHeights = heights
        }
        if from < notebooks[idx].pagesData.count, to < notebooks[idx].pagesData.count {
            let d = notebooks[idx].pagesData.remove(at: from)
            notebooks[idx].pagesData.insert(d, at: to)
        }
        notebooks[idx].padPagePaperIds(to: total)
        notebooks[idx].alignPageIds()
        if var ids = notebooks[idx].pageIds, from < ids.count, to < ids.count {
            ids.insert(ids.remove(at: from), at: to)
            notebooks[idx].pageIds = ids
        }
        if var ids = notebooks[idx].pagePaperIds, from < ids.count, to < ids.count {
            let moved = ids.remove(at: from)
            ids.insert(moved, at: to)
            notebooks[idx].pagePaperIds = ids
        }

        // 3. 九種附件。
        notebooks[idx].attachments = Self.shiftPages(
            notebooks[idx].attachments, movingFrom: from, to: to)
        notebooks[idx].textAttachments = Self.shiftPages(
            notebooks[idx].textAttachments, movingFrom: from, to: to)
        notebooks[idx].linkAttachments = Self.shiftPages(
            notebooks[idx].linkAttachments, movingFrom: from, to: to)
        notebooks[idx].model3DAttachments = Self.shiftPages(
            notebooks[idx].model3DAttachments, movingFrom: from, to: to)
        notebooks[idx].commentPins = Self.shiftPages(
            notebooks[idx].commentPins, movingFrom: from, to: to)
        notebooks[idx].tableAttachments = Self.shiftPages(
            notebooks[idx].tableAttachments, movingFrom: from, to: to)
        notebooks[idx].shapeAttachments = Self.shiftPages(
            notebooks[idx].shapeAttachments, movingFrom: from, to: to)
        notebooks[idx].connectionAttachments = Self.shiftPages(
            notebooks[idx].connectionAttachments, movingFrom: from, to: to)
        notebooks[idx].audioAttachments = Self.shiftPages(
            notebooks[idx].audioAttachments, movingFrom: from, to: to)
        notebooks[idx].tapeAttachments = Self.shiftPages(
            notebooks[idx].tapeAttachments, movingFrom: from, to: to)
        notebooks[idx].stickyAnchors = Self.shiftPages(
            notebooks[idx].stickyAnchors, movingFrom: from, to: to)

        // 4. 以頁碼為鍵的逐頁資料（堆疊順序、筆跡下方的物件、鎖定、辨識文字、版面勾選）。
        remapPageKeyedFields(at: idx) { page in
            Int(pageIndexAfterMove(index: UInt32(max(0, page)), from: UInt32(from), to: UInt32(to)))
        }

        notebooks[idx].lastModifiedDate = Date()
        persistData()
        return to
    }

    /// 把 `pages` 這幾頁的所有逐頁檔案改名到 `destination(頁次)`。
    ///
    /// 逐頁檔案的命名一律是 `{筆記 id}_p{頁次}.{種類}`，散在筆跡與同步基準兩個資料夾。
    /// 用目錄列舉而不是一份副檔名清單：新增一種逐頁檔案時不必回來這裡補（漏補的症狀是
    /// 那一種東西搬頁之後留在原頁）。
    ///
    /// 先全部改成暫存名再改成目標名 —— 直接改名會把還沒搬走的那一頁蓋掉。
    private func permutePageFiles(notebookId: String, pages: Set<Int>, destination: (Int) -> Int) {
        guard !pages.isEmpty else { return }
        let fm = FileManager.default
        let prefix = "\(notebookId)_p"
        for dir in [drawingsDirectory, syncBaselineDirectory] {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            var staged: [(temp: URL, target: URL)] = []
            for name in names where name.hasPrefix(prefix) {
                let rest = name.dropFirst(prefix.count)
                guard let dot = rest.firstIndex(of: "."),
                      let page = Int(rest[rest.startIndex..<dot]),
                      pages.contains(page) else { continue }
                let target = dir.appending(path: "\(prefix)\(destination(page))\(rest[dot...])")
                let temp = dir.appending(path: ".moving-\(UUID().uuidString)-\(name)")
                guard (try? fm.moveItem(at: dir.appending(path: name), to: temp)) != nil else { continue }
                staged.append((temp, target))
            }
            for item in staged {
                try? fm.removeItem(at: item.target)
                try? fm.moveItem(at: item.temp, to: item.target)
            }
        }
    }

    /// 把逐頁檔案排回原本的頁碼（「還原到初始狀態」）。`origins[目前頁碼]` = 原本的頁碼；
    /// `nil` 是這次才新增的頁，它的檔案刪掉。原本有、現在沒有的頁（刪掉了）沒有檔案，由呼叫端寫回初始內容。
    public func restorePageFiles(notebookId: String, origins: [Int?]) {
        for (page, origin) in origins.enumerated() where origin == nil {
            removePageFiles(notebookId: notebookId, page: page)
        }
        let kept = Set(origins.indices.filter { origins[$0] != nil })
        permutePageFiles(notebookId: notebookId, pages: kept) { origins[$0] ?? $0 }
    }

    /// 刪掉某一頁的所有逐頁檔案（見 `permutePageFiles`）。只刪 `.drawing` 的話，
    /// 那一頁的專業筆畫與同步記帳留在磁碟上，之後新增到同一個頁碼的頁會把它們撿回來。
    private func removePageFiles(notebookId: String, page: Int) {
        removePageFiles(notebookId: notebookId, pages: [page])
    }

    /// 一次清掉好幾頁的逐頁檔案：目錄只列一次（插入多頁時每頁各列一次是白做工）。
    private func removePageFiles(notebookId: String, pages: Set<Int>) {
        guard !pages.isEmpty else { return }
        let fm = FileManager.default
        let prefixes = pages.map { "\(notebookId)_p\($0)." }
        for dir in [drawingsDirectory, syncBaselineDirectory] {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in names where prefixes.contains(where: { name.hasPrefix($0) }) {
                try? fm.removeItem(at: dir.appending(path: name))
            }
        }
    }

    /// 把 `pages` 這幾頁的逐頁檔案往後挪 `by` 頁（插入、複製頁時讓出位置）。由後往前挪不會互相覆蓋，
    /// 但 `permutePageFiles` 本來就先改暫存名，順序無所謂。
    private func shiftPageFiles(notebookId: String, from first: Int, through last: Int, by offset: Int) {
        guard first <= last else { return }
        permutePageFiles(notebookId: notebookId, pages: Set(first...last)) { $0 + offset }
    }

    /// 以頁碼為鍵的逐頁欄位，照 `transform` 換頁碼；回傳 `nil` 的那一頁整個丟掉（刪除頁）。
    ///
    /// 這幾個欄位是字典而不是帶 `pageIndex` 的陣列，`shiftPages` 管不到 —— 原本插入、刪除、
    /// 搬動都沒有處理，症狀是堆疊順序、鎖定、筆跡下方的物件留在原頁碼，套到了隔壁頁的物件上。
    private func remapPageKeyedFields(at idx: Int, _ transform: (Int) -> Int?) {
        func remap<V>(_ map: [String: V]?) -> [String: V]? {
            guard let map else { return nil }
            var out: [String: V] = [:]
            for (key, value) in map {
                guard let page = Int(key) else { out[key] = value; continue }
                if let moved = transform(page) { out[String(moved)] = value }
            }
            return out
        }
        notebooks[idx].objectOrderByPage = remap(notebooks[idx].objectOrderByPage)
        notebooks[idx].underInkObjectIdsByPage = remap(notebooks[idx].underInkObjectIdsByPage)
        notebooks[idx].overInkObjectIdsByPage = remap(notebooks[idx].overInkObjectIdsByPage)
        let locked = remap(notebooks[idx].lockedObjectIdsByPage)
        notebooks[idx].lockedObjectIdsByPage = (locked?.isEmpty ?? true) ? nil : locked
        notebooks[idx].recognizedText = remap(notebooks[idx].recognizedText)
        if let guides = notebooks[idx].checkedGuideItems {
            // 鍵是 "頁次_x_y"。
            var out: [String: Bool] = [:]
            for (key, value) in guides {
                var parts = key.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2, let page = Int(parts[0]) else { out[key] = value; continue }
                guard let moved = transform(page) else { continue }
                parts[0] = Substring(String(moved))
                out[parts.joined(separator: "_")] = value
            }
            notebooks[idx].checkedGuideItems = out
        }
    }

    /// 複製一頁的筆跡檔（PencilKit 與專業筆畫）到另一個頁碼。
    ///
    /// 專業筆畫要換新的 id：複本若沿用原本的身分，擦掉其中一筆另一筆也跟著消失（見 `ProStroke.id`）。
    /// 別台寫的那一份在複本上就是這台新寫的，併進自己的。同步記帳與基準不複製 —— 新的一頁從來沒同步過。
    private func copyPageInk(notebookId: String, from source: Int, to destination: Int,
                             targetNotebookId: String? = nil) {
        let targetId = targetNotebookId ?? notebookId
        saveDrawing(notebookId: targetId, pageIndex: destination,
                    drawing: loadDrawing(notebookId: notebookId, pageIndex: source))
        let dir = drawingsDirectory
        let strokes = ProInkStore.load(in: dir, notebookId: notebookId, page: source, foreign: true)
            + ProInkStore.load(in: dir, notebookId: notebookId, page: source)
        let copies = strokes.map { stroke -> ProStroke in
            var copy = stroke
            copy.id = UUID().uuidString
            return copy
        }
        if !copies.isEmpty {
            ProInkStore.save(copies, in: dir, notebookId: targetId, page: destination)
        }
    }

    /// 把幾頁複製（或搬）到另一本筆記本，回傳實際處理的頁數。
    ///
    /// # 一頁不是一筆資料
    ///
    /// 它是散在四個地方的東西：磁碟上的筆跡檔案（檔名就是頁碼）、
    /// `pageHeights`、`pagesData`，以及九種附件各自的 `pageIndex`。
    /// 只搬其中一樣的結果不是「沒搬」，是「筆跡到了、上面的表格沒到」。
    ///
    /// # 計畫先算好
    ///
    /// 「複製到哪幾頁、要刪哪幾頁、准不准做」由核心的 `pageTransferPlan`
    /// 一次算清楚。邊走邊算的話會出現「複製成功、刪的時候刪錯頁」——
    /// 而那時原本那幾頁已經不在了。
    ///
    /// 搬動時**由大到小**刪：由小到大刪的話，刪掉第 1 頁之後第 3 頁已經
    /// 變成第 2 頁，接著刪「第 3 頁」就刪到了別人。
    @discardableResult
    public func transferPages(
        from sourceId: String,
        pageIndexes: [Int],
        to targetId: String,
        move: Bool
    ) -> Int {
        guard let sourceIdx = notebooks.firstIndex(where: { $0.id == sourceId }),
              let targetIdx = notebooks.firstIndex(where: { $0.id == targetId })
        else { return 0 }

        let plan = pageTransferPlan(
            sourceCount: UInt32(max(0, notebooks[sourceIdx].pageCount)),
            selected: pageIndexes.filter { $0 >= 0 }.map { UInt32($0) },
            targetCount: UInt32(max(0, notebooks[targetIdx].pageCount)),
            moveOut: move,
            sameNotebook: sourceId == targetId
        )
        guard plan.allowed else { return 0 }

        for (offset, source) in plan.sources.enumerated() {
            let from = Int(source)
            let to = Int(plan.destinations[offset])

            // 1. 筆跡。整頁複製，不是只複製看得見的那一段 —— 專業筆畫（炭筆、蠟筆…）也算，
            //    原本只複製 `.drawing`，用那幾支筆寫的字留在原本那一本。
            //    目的頁碼上可能留著舊版刪頁遺留的檔案，先清掉。
            removePageFiles(notebookId: targetId, page: to)
            copyPageInk(notebookId: sourceId, from: from, to: to, targetNotebookId: targetId)

            // 2. 頁高與內嵌筆跡陣列。
            let defaultHeight = notebooks[targetIdx].pageSize.height
            let sourceHeights = notebooks[sourceIdx].pageHeights
            var heights = notebooks[targetIdx].pageHeights
                ?? Array(repeating: defaultHeight, count: max(0, notebooks[targetIdx].pageCount))
            while heights.count < to { heights.append(defaultHeight) }
            heights.append(
                (from < (sourceHeights?.count ?? 0)) ? sourceHeights![from] : notebooks[sourceIdx].pageSize.height)
            notebooks[targetIdx].pageHeights = heights

            if from < notebooks[sourceIdx].pagesData.count {
                notebooks[targetIdx].pagesData.append(notebooks[sourceIdx].pagesData[from])
            } else {
                notebooks[targetIdx].pagesData.append(PKDrawing().dataRepresentation())
            }

            // 紙張跟著頁走。不帶的話，一張四象限搬到別本之後會變成那本的
            // 預設紙 —— 使用者搬的是「那一頁」，不是「那一頁上的字」。
            let carried = notebooks[sourceIdx].paperId(forPage: from)
            notebooks[targetIdx].alignPageIds()
            if notebooks[targetIdx].pageIds != nil {
                // 搬到另一本的頁是那一本的新頁：給新的 id，不沿用來源的。
                notebooks[targetIdx].pageIds?.append(UUID().uuidString.lowercased())
            }
            notebooks[targetIdx].padPagePaperIds(to: to)
            notebooks[targetIdx].pagePaperIds?.append(carried)

            // 3. 九種附件。
            notebooks[targetIdx].attachments = Self.appendCopies(
                of: notebooks[sourceIdx].attachments, page: from,
                into: notebooks[targetIdx].attachments, newPage: to)
            notebooks[targetIdx].textAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].textAttachments, page: from,
                into: notebooks[targetIdx].textAttachments, newPage: to)
            notebooks[targetIdx].linkAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].linkAttachments, page: from,
                into: notebooks[targetIdx].linkAttachments, newPage: to)
            notebooks[targetIdx].model3DAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].model3DAttachments, page: from,
                into: notebooks[targetIdx].model3DAttachments, newPage: to)
            notebooks[targetIdx].commentPins = Self.appendCopies(
                of: notebooks[sourceIdx].commentPins, page: from,
                into: notebooks[targetIdx].commentPins, newPage: to)
            notebooks[targetIdx].tableAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].tableAttachments, page: from,
                into: notebooks[targetIdx].tableAttachments, newPage: to)
            notebooks[targetIdx].shapeAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].shapeAttachments, page: from,
                into: notebooks[targetIdx].shapeAttachments, newPage: to)
            notebooks[targetIdx].connectionAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].connectionAttachments, page: from,
                into: notebooks[targetIdx].connectionAttachments, newPage: to)
            notebooks[targetIdx].audioAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].audioAttachments, page: from,
                into: notebooks[targetIdx].audioAttachments, newPage: to)
            notebooks[targetIdx].tapeAttachments = Self.appendCopies(
                of: notebooks[sourceIdx].tapeAttachments, page: from,
                into: notebooks[targetIdx].tapeAttachments, newPage: to)

            notebooks[targetIdx].pageCount = to + 1
        }

        notebooks[targetIdx].lastModifiedDate = Date()
        persistData()

        // 4. 搬動才刪來源。刪除本身沿用 `deletePage` —— 那一支已經處理過
        //    九種附件與 `pagesData`，在這裡另寫一份只會漏掉其中幾種。
        if move {
            for index in plan.removals {
                _ = deletePage(notebookId: sourceId, pageIndex: Int(index), currentIndex: 0)
            }
        }
        return plan.sources.count
    }

    /// 把某一頁上的附件複製一份到另一本筆記本的某一頁。
    ///
    /// # 為什麼要換一個 id
    ///
    /// `id` 是**同一本筆記裡**的身分。複製到別本時沿用原本的 id 看起來沒事，
    /// 直到使用者把那一頁再複製回來 —— 這時同一本筆記裡有兩個相同 id 的
    /// 物件，而選取、刪除、堆疊順序全部是照 id 找的：點其中一個，
    /// 另一個跟著動。
    ///
    /// 換 id 走 JSON 來回而不是替每一種型別各寫一個複製建構子：那九個
    /// 建構子加起來是上百個欄位，漏抄一個的症狀是「複製過去的表格少了一欄」。
    /// 換不動時保留原本的 —— 少一個新 id 也比掉一個物件好。
    static func appendCopies<T: PageIndexed & Codable>(
        of items: [T]?,
        page: Int,
        into existing: [T]?,
        newPage: Int
    ) -> [T]? {
        let onPage = (items ?? []).filter { $0.pageIndex == page }
        guard !onPage.isEmpty else { return existing }
        var out = existing ?? []
        for item in onPage {
            var copy = reIdentified(item) ?? item
            copy.pageIndex = newPage
            out.append(copy)
        }
        return out
    }

    /// 換一個 id 的複本。認不得的結構（沒有 `id` 欄位）回 nil。
    static func reIdentified<T: Codable>(_ item: T) -> T? {
        guard let data = try? JSONEncoder().encode(item),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              dict["id"] != nil
        else { return nil }
        dict["id"] = UUID().uuidString
        guard let patched = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(T.self, from: patched)
    }

    /// 複製指定頁面並插入於其後，回傳新頁碼 index
    @discardableResult
    public func duplicatePage(notebookId: String, pageIndex: Int) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return 0 }
        let total = notebooks[idx].pageCount
        guard pageIndex >= 0, pageIndex < total else { return pageIndex }

        // 後續頁面的所有逐頁檔案往後挪一頁，再把這一頁的筆跡（含專業筆畫）複製到 pageIndex + 1。
        removePageFiles(notebookId: notebookId, page: total)
        shiftPageFiles(notebookId: notebookId, from: pageIndex + 1, through: total - 1, by: 1)
        copyPageInk(notebookId: notebookId, from: pageIndex, to: pageIndex + 1)
        remapPageKeyedFields(at: idx) { $0 > pageIndex ? $0 + 1 : $0 }

        // 複製高度
        let defaultHeight = notebooks[idx].pageSize.height
        var heights = notebooks[idx].pageHeights ?? Array(repeating: defaultHeight, count: total)
        while heights.count < total { heights.append(defaultHeight) }
        let copyHeight = heights[pageIndex]
        heights.insert(copyHeight, at: pageIndex + 1)
        notebooks[idx].pageHeights = heights

        // 複本要跟原本那一頁同一種紙 —— 不然「建立此頁副本」會得到一張
        // 版面不一樣的頁。
        let sourcePaper = notebooks[idx].paperId(forPage: pageIndex)
        notebooks[idx].padPagePaperIds(to: total)
        notebooks[idx].pagePaperIds?.insert(
            sourcePaper, at: min(pageIndex + 1, notebooks[idx].pagePaperIds?.count ?? 0))
        // 複製出來的是新的一頁：給新的 id（與被複製的那頁不是同一頁）。
        notebooks[idx].alignPageIds()
        if notebooks[idx].pageIds != nil {
            notebooks[idx].pageIds?.insert(
                UUID().uuidString.lowercased(), at: min(pageIndex + 1, notebooks[idx].pageIds?.count ?? 0))
        }

        // 附件的頁碼也要讓出一格。
        //
        // 原本整段不存在：複製第 1 頁之後，第 2 頁以後的表格、圖片與文字
        // 方塊全部留在原本的頁碼上，於是它們落在那張複本上，而原本的那一頁
        // 空了。複製是為了留一份原稿，結果把原稿搬走了。
        let insertIndex = pageIndex + 1
        notebooks[idx].attachments = Self.shiftPages(
            notebooks[idx].attachments, inserting: insertIndex)
        notebooks[idx].textAttachments = Self.shiftPages(
            notebooks[idx].textAttachments, inserting: insertIndex)
        notebooks[idx].linkAttachments = Self.shiftPages(
            notebooks[idx].linkAttachments, inserting: insertIndex)
        notebooks[idx].model3DAttachments = Self.shiftPages(
            notebooks[idx].model3DAttachments, inserting: insertIndex)
        notebooks[idx].commentPins = Self.shiftPages(
            notebooks[idx].commentPins, inserting: insertIndex)
        notebooks[idx].tableAttachments = Self.shiftPages(
            notebooks[idx].tableAttachments, inserting: insertIndex)
        notebooks[idx].shapeAttachments = Self.shiftPages(
            notebooks[idx].shapeAttachments, inserting: insertIndex)
        notebooks[idx].connectionAttachments = Self.shiftPages(
            notebooks[idx].connectionAttachments, inserting: insertIndex)
        notebooks[idx].audioAttachments = Self.shiftPages(
            notebooks[idx].audioAttachments, inserting: insertIndex)
        notebooks[idx].tapeAttachments = Self.shiftPages(
            notebooks[idx].tapeAttachments, inserting: insertIndex)
        notebooks[idx].stickyAnchors = Self.shiftPages(
            notebooks[idx].stickyAnchors, inserting: insertIndex)

        if insertIndex <= notebooks[idx].pagesData.count {
            let copied = insertIndex - 1 < notebooks[idx].pagesData.count
                ? notebooks[idx].pagesData[insertIndex - 1]
                : PKDrawing().dataRepresentation()
            notebooks[idx].pagesData.insert(copied, at: insertIndex)
        }

        notebooks[idx].pageCount = total + 1
        notebooks[idx].lastModifiedDate = Date()
        persistData()

        return pageIndex + 1
    }

    // MARK: - 錄音操作 CRUD

    @discardableResult
    public func addRecording(title: String, durationSeconds: Int, fileName: String, linkedNotebookId: String? = nil) -> AudioRecordingRecord {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle: String
        if !trimmed.isEmpty {
            safeTitle = trimmed
        } else if let nId = linkedNotebookId, nId.caseInsensitiveCompare(recordingInboxNotebookId()) == .orderedSame {
            safeTitle = Self.defaultQuickRecordingTitle()
        } else {
            safeTitle = Self.defaultRecordingTitle()
        }
        let rec = AudioRecordingRecord(
            title: safeTitle,
            durationSeconds: durationSeconds,
            recordedDate: Date(),
            transcriptionStatus: "轉錄就緒",
            isTranscribed: true,
            fileName: fileName,
            linkedNotebookId: linkedNotebookId
        )
        recordings.insert(rec, at: 0)

        if let nId = linkedNotebookId,
           let idx = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(nId) == .orderedSame }) {
            notebooks[idx].hasRecording = true
            notebooks[idx].recordingAudioPath = fileName
            // 名字要跟著這本筆記本的套件同步出去 —— 算作這本有修改。
            notebooks[idx].lastModifiedDate = Date()
        }
        // 使用者取的名字當下就寫進套件（與改名同一條路，見 `writeRecordingTitle`）。
        // 只靠下一輪匯出的話，音檔可能先到別台，別台就只看得到預設名稱。
        if !Self.isGenericOrQuickRecordTitle(safeTitle) {
            let notebookId = (linkedNotebookId ?? recordingInboxNotebookId()).lowercased()
            let packagePath = corePackagesDirectory.appending(path: "\(notebookId).padnote").path
            let file = fileName.lowercased()
            let device = NotebookMigration.deviceId
            pendingTitleWrites[file] = safeTitle
            Task.detached(priority: .userInitiated) { [weak self] in
                NotebookPackageBridge.writeRecordingTitle(
                    packagePath: packagePath, fileName: file, title: safeTitle, deviceId: device)
                await MainActor.run {
                    if self?.pendingTitleWrites[file] == safeTitle { self?.pendingTitleWrites.removeValue(forKey: file) }
                }
            }
        }
        persistData()
        syncRecordingsExportFolder()
        return rec
    }

    /// 一段錄音的實體檔案在哪裡。
    ///
    /// # 為什麼要有這個函式
    ///
    /// 錄音有兩個可能的位置：新的在**筆記本套件裡**（`media/audio/`，
    /// 會被同步），舊的在 `Documents/Kairumo Record`（套件外，
    /// 從來沒有被同步過，等 R5 遷移）。
    ///
    /// 各處自己拼路徑的話，遷移期間一定會有地方拼到錯的那一個 ——
    /// 而症狀是「按了播放沒有反應」，沒有任何錯誤訊息。
    /// 依檔名解析錄音的位置（`notebookId` 為這一段錄音所屬的筆記本）。
    ///
    /// 與 [`recordingFileURL(for:)`] 同一條規則，給只拿得到檔名的呼叫端用。
    public func recordingFileURL(fileName: String, notebookId: String? = nil, recordingId: String? = nil) -> URL {
        let fm = FileManager.default
        let raw = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 0. 如果傳進來的字串本身就是本機上實際存在的檔案路徑或 file:// URL
        if !raw.isEmpty {
            if raw.hasPrefix("file://"), let u = URL(string: raw), fm.fileExists(atPath: u.path) {
                return u
            }
            if raw.hasPrefix("/") && fm.fileExists(atPath: raw) {
                return URL(fileURLWithPath: raw)
            }
        }

        // 取得純檔名（過濾路徑成分、URL 編碼與 media/audio 前綴）
        var cleanName = (raw as NSString).lastPathComponent
        if let decoded = cleanName.removingPercentEncoding, !decoded.isEmpty {
            cleanName = decoded
        }
        if (cleanName.isEmpty || cleanName == "/") && recordingId != nil {
            if let rec = recordings.first(where: { $0.id == recordingId }) {
                cleanName = (rec.fileName as NSString).lastPathComponent
            }
        }
        guard !cleanName.isEmpty && cleanName != "/" else {
            return AudioRecorderManager.shared.recordingsDirectory.appending(path: "missing.m4a")
        }

        // 收集所有可能的候選檔名（同名、或者不同音訊副檔名如 .m4a / .opus / .wav / .caf / .mp3）
        let baseName = (cleanName as NSString).deletingPathExtension
        let originalExt = (cleanName as NSString).pathExtension.lowercased()
        let candidateNames: [String]
        if originalExt.isEmpty {
            candidateNames = [cleanName, "\(baseName).m4a", "\(baseName).opus", "\(baseName).wav", "\(baseName).caf", "\(baseName).mp3"]
        } else {
            candidateNames = [cleanName, "\(baseName).opus", "\(baseName).m4a", "\(baseName).wav", "\(baseName).caf", "\(baseName).mp3"]
        }

        // 檢查給定目錄底下是否有任何候選檔名
        func probeDirectory(_ dir: URL) -> URL? {
            for name in candidateNames {
                let candidate = dir.appending(path: name)
                if fm.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
            return nil
        }

        // 1. 當前筆記本的套件 media/audio
        if let notebookId {
            let pkgAudio = corePackagesDirectory
                .appending(path: "\(notebookId.lowercased()).padnote")
                .appending(path: "media/audio")
            if let found = probeDirectory(pkgAudio) {
                return found
            }
        }

        // 2. 透過 recordingId 或 cleanName 查詢 recordings 索引中的 linkedNotebookId 套件
        if let rec = recordings.first(where: { (!cleanName.isEmpty && $0.fileName == cleanName) || ($0.id == recordingId) }) {
            if let linkedId = rec.linkedNotebookId, !linkedId.isEmpty, linkedId.caseInsensitiveCompare(notebookId ?? "") != .orderedSame {
                let linkedPkgAudio = corePackagesDirectory
                    .appending(path: "\(linkedId.lowercased()).padnote")
                    .appending(path: "media/audio")
                if let found = probeDirectory(linkedPkgAudio) {
                    return found
                }
            }
        }

        // 3. 錄音收件匣 inbox 的套件 media/audio
        let inInbox = corePackagesDirectory
            .appending(path: "\(recordingInboxNotebookId().lowercased()).padnote")
            .appending(path: "media/audio")
        if let found = probeDirectory(inInbox) {
            return found
        }

        // 4. 掃描 corePackagesDirectory 底下所有 .padnote 套件的 media/audio
        if let packages = try? fm.contentsOfDirectory(at: corePackagesDirectory, includingPropertiesForKeys: nil) {
            for pkg in packages where pkg.pathExtension == "padnote" {
                if let found = probeDirectory(pkg.appending(path: "media/audio")) {
                    return found
                }
            }
        }

        // 5. 掃描 documentsDir 底下的 .padnote（防止遷移未進 corePackagesDirectory）
        if let docPackages = try? fm.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil) {
            for pkg in docPackages where pkg.pathExtension == "padnote" {
                if let found = probeDirectory(pkg.appending(path: "media/audio")) {
                    return found
                }
            }
        }

        // 6. 主要錄音目錄 AudioRecorderManager.shared.recordingsDirectory
        let recDir = AudioRecorderManager.shared.recordingsDirectory
        if let found = probeDirectory(recDir) {
            return found
        }

        // 7. 使用者文件庫 DocumentStorageLocation.shared.rootURL / Kairumo Record
        let rootKairumoRecord = DocumentStorageLocation.shared.libraryRootURL.appendingPathComponent("Kairumo Record", isDirectory: true)
        if let found = probeDirectory(rootKairumoRecord) {
            return found
        }

        // 8. 舊容器 Documents / Kairumo Record（沙盒內的傳統路徑）
        // profile-scope: default 舊版容器路徑，只有升級前的預設設定檔會有東西在這裡
        if let legacyDocs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let legacyRecord = legacyDocs.appendingPathComponent("Kairumo Record", isDirectory: true)
            if let found = probeDirectory(legacyRecord) {
                return found
            }
            if let found = probeDirectory(legacyDocs) {
                return found
            }
        }

        // 9. documentsDir / Attachments 目錄（匯入音訊可能落點）
        let attachmentsDir = documentsDir.appendingPathComponent("Attachments", isDirectory: true)
        if let found = probeDirectory(attachmentsDir) {
            return found
        }

        // 10. 預設退回路徑
        return recDir.appending(path: cleanName)
    }

    public func recordingFileURL(for record: AudioRecordingRecord) -> URL {
        recordingFileURL(fileName: record.fileName, notebookId: record.linkedNotebookId, recordingId: record.id)
    }

    /// 重新掃描所有套件裡的錄音，與本機那份清單合併。
    ///
    /// # 為什麼要掃檔案，而不是只信自己那份索引
    ///
    /// 只信索引的話，**從另一台裝置同步過來的錄音永遠不會出現在清單上**
    /// —— 而那正是「最近錄音」最該顯示的東西。Android 一直是掃套件的
    /// （`RecordingIndex.kt`），Apple 這邊補齊。
    ///
    /// 既有的記錄會被保留（標題是使用者取的，不能用檔名蓋掉）；
    /// 只有掃到、而索引裡沒有的才會被補進來。

    // MARK: - 清理沒人用的檔案

    private static let janitorLastRunKey = "kairumo.storageJanitor.lastRun"

    /// 每天最多清一次（App 啟動之後，背景、低優先）。規則與理由見 `StorageJanitor`。
    func cleanUnusedFilesIfDue(now: Date = Date()) {
        let last = ProfileDefaults.current.object(forKey: Self.janitorLastRunKey) as? Date
        if let last, now.timeIntervalSince(last) < 24 * 3600 { return }
        cleanUnusedFiles(now: now)
    }

    func cleanUnusedFiles(now: Date = Date()) {
        // 在主執行緒取快照（這些是 @MainActor 狀態），規劃與刪除丟到背景。
        let all = notebooks + trashedNotebooks
        var referenced = Set<String>()
        for doc in all {
            for image in doc.attachments ?? [] { referenced.insert(image.fileName) }
        }
        let infos = all.map { StorageJanitor.NotebookInfo(id: $0.id, pageCount: $0.pageCount) }
        let attachments = attachmentsDirectory
        let drawings = drawingsDirectory
        let baseline = documentsDir.appendingPathComponent("SyncBaseline", isDirectory: true)
        let protectedIds = Self.notebookIds(inSyncIndex: AccountSyncStore.indexJSONSnapshot())
        let pkgDir = corePackagesDirectory
        let deviceId = NotebookMigration.deviceId
        ProfileDefaults.current.set(now, forKey: Self.janitorLastRunKey)

        Task.detached(priority: .background) {
            let plan = StorageJanitor.plan(
                attachmentsDirectory: attachments,
                pageDirectories: [drawings, baseline],
                notebooks: infos, protectedIds: protectedIds,
                referencedAttachments: referenced, now: now)
            let done = StorageJanitor.execute(plan)
            _ = Self.optimizePackages(in: pkgDir, deviceId: deviceId, deepClean: false)
            guard done.count > 0 || !plan.keptSuspicious.isEmpty else { return }
            let mb = String(format: "%.1f", Double(done.bytes) / 1_048_576)
            SyncLogger.logAsync(
                "已清理 \(done.count) 個沒有用到的檔案（\(mb) MB）；留下 \(plan.keptSuspicious.count) 個超出頁數但有內容的筆跡",
                source: .general)
        }
    }

    /// 最佳化所有筆記本套件的儲存空間（合併 Oplog、回收未引用 Blob、壓實筆跡）。
    @discardableResult
    public func optimizeAllNotebooks(deepClean: Bool = false) async -> FfiStorageOptimizationReport {
        let deviceId = NotebookMigration.deviceId
        let pkgDir = corePackagesDirectory
        return await Task.detached(priority: .utility) {
            Self.optimizePackages(in: pkgDir, deviceId: deviceId, deepClean: deepClean)
        }.value
    }

    nonisolated static func optimizePackages(in pkgDir: URL, deviceId: UInt32, deepClean: Bool) -> FfiStorageOptimizationReport {
        var totalOplogs: UInt32 = 0
        var totalBlobs: UInt32 = 0
        var totalBlobBytes: UInt64 = 0
        var totalInkPages: UInt32 = 0
        var totalInkBytes: UInt64 = 0

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: pkgDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return FfiStorageOptimizationReport(oplogFilesMerged: 0, blobsRemoved: 0, blobBytesReclaimed: 0, inkPagesCompacted: 0, inkBytesReclaimed: 0)
        }

        for url in contents where url.pathExtension == "padnote" {
            do {
                let report = try optimizeNotebookStorage(packagePath: url.path, deviceId: deviceId, deepClean: deepClean)
                totalOplogs += report.oplogFilesMerged
                totalBlobs += report.blobsRemoved
                totalBlobBytes += report.blobBytesReclaimed
                totalInkPages += report.inkPagesCompacted
                totalInkBytes += report.inkBytesReclaimed
            } catch {
                SyncLogger.logAsync("optimizeNotebookStorage error for \(url.lastPathComponent): \(error)", source: .general)
            }
        }

        let totalBytes = Int64(totalBlobBytes + totalInkBytes)
        if totalOplogs > 0 || totalBlobs > 0 || totalInkPages > 0 {
            let mb = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            SyncLogger.logAsync(
                "已完成筆記儲存最佳化：合併 \(totalOplogs) 個記錄檔，清除 \(totalBlobs) 個未引用檔案，壓實 \(totalInkPages) 個筆跡頁，釋放 \(mb)",
                source: .general
            )
        }

        return FfiStorageOptimizationReport(
            oplogFilesMerged: totalOplogs,
            blobsRemoved: totalBlobs,
            blobBytesReclaimed: totalBlobBytes,
            inkPagesCompacted: totalInkPages,
            inkBytesReclaimed: totalInkBytes
        )
    }

    /// 同步索引裡記得的筆記本 id。
    nonisolated static func notebookIds(inSyncIndex json: String) -> Set<String> {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var ids = Set<String>()
        func walk(_ value: Any) {
            if let dict = value as? [String: Any] {
                if let id = dict["id"] as? String { ids.insert(id) }
                dict.values.forEach(walk)
            } else if let array = value as? [Any] {
                array.forEach(walk)
            }
        }
        walk(root)
        return ids
    }

    /// 別台取的錄音名字，但這台的清單裡還沒有那段錄音（檔名小寫 → 名字）。
    private var unmatchedIncomingTitles: [String: String] = [:]


    /// 剛改、還在寫進套件的錄音名字（檔名小寫 → 名字）。寫完之前套件裡還是舊名字 ——
    /// 這段期間的重掃與匯入不能拿套件的舊名字蓋回去，否則改完名字會先跳回去一下。
    private var pendingTitleWrites: [String: String] = [:]

    /// 把別台改的錄音名字套進清單（見 `RecordingTitle`）。
    ///
    /// 套件裡的名字一律採用（改名會直接寫進套件，見 `NotebookPackageBridge.writeRecordingTitle`）。
    func applyRecordingTitles(_ titles: [String: String]) {
        guard !titles.isEmpty else { return }
        // 清單裡還沒有這段錄音的（別台剛錄、這台還沒掃描到）先記下來，掃描建立紀錄時用。
        // 匯入名字發生在掃描**之前**：不記的話，掃描替它取預設名（「快速錄音」），
        // 別台取的名字就永遠對不上 —— 使用者看到的是「檔名沒有同步」。
        let known = Set(recordings.map { $0.fileName.lowercased() })
        for (key, title) in titles where !known.contains(key)
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            unmatchedIncomingTitles[key] = title
        }
        // 套件裡的名字就是答案（核心的外觀操作，最後一次改的贏，見 `writeRecordingTitle`）。
        // 以前這裡有一堆「通用名稱／匯出當下的名字」的猜測，那些猜測彼此打架，名字就來回跳。
        var changed = false
        for index in recordings.indices {
            let key = recordings[index].fileName.lowercased()
            guard pendingTitleWrites[key] == nil,
                  let incoming = titles[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !incoming.isEmpty, incoming != recordings[index].title,
                  !Self.downgradesTitle(from: recordings[index].title, to: incoming) else { continue }
            recordings[index].title = incoming
            changed = true
        }

        // 畫布上的錄音卡片跟著錄音的名字走（卡片不是名字的來源）。
        for (key, incoming) in titles where pendingTitleWrites[key] == nil {
            let clean = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            for notebookIndex in notebooks.indices {
                guard var cards = notebooks[notebookIndex].audioAttachments else { continue }
                var cardChanged = false
                for cardIndex in cards.indices where cards[cardIndex].fileName.lowercased() == key {
                    if cards[cardIndex].title != clean,
                       !Self.downgradesTitle(from: cards[cardIndex].title, to: clean) {
                        cards[cardIndex].title = clean
                        cardChanged = true
                    }
                }
                if cardChanged {
                    notebooks[notebookIndex].audioAttachments = cards
                    changed = true
                }
            }
        }

        if changed {
            persistData(signalsLocalEdit: false)
            syncRecordingsExportFolder()
        }
    }

    /// 錄音檔名（`<UUIDv7>.opus`）裡的建立時間。不是 v7 或不合理就回 `fallback`。
    ///
    /// UUIDv7 的前 48 位元是 Unix 毫秒。核心的錄音 id 就是 v7（`start_recording`），所以同一段錄音在每台裝置上
    /// 都能算出同一個時間 —— 不必依賴檔案修改時間（同步下載後那是下載時間）。
    nonisolated static func recordingDate(fromFileName name: String, fallback: Date) -> Date {
        let stem = (name as NSString).deletingPathExtension
        guard let uuid = UUID(uuidString: stem) else { return fallback }
        let b = uuid.uuid
        guard (b.6 >> 4) == 7 else { return fallback }
        let ms = (UInt64(b.0) << 40) | (UInt64(b.1) << 32) | (UInt64(b.2) << 24)
            | (UInt64(b.3) << 16) | (UInt64(b.4) << 8) | UInt64(b.5)
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        guard date > Date(timeIntervalSince1970: 1_577_836_800), date < Date().addingTimeInterval(86_400) else {
            return fallback
        }
        return date
    }

    /// 套件裡的名字只是自動產生的預設名稱，清單裡卻是使用者取的名字：不採用。
    ///
    /// 那個預設名稱是舊版從別台蓋過來的（見 `NotebookSyncCoordinator.mergedExportTitles`），
    /// 採用的話使用者取的名字就沒了；保留下來，下一輪匯出會把它寫回套件。
    nonisolated static func downgradesTitle(from current: String, to incoming: String) -> Bool {
        isGenericOrQuickRecordTitle(incoming) && !isGenericOrQuickRecordTitle(current)
    }

    /// 這個名字是 App 依時間自動產生的預設名稱（而不是使用者取的）。
    static func isAutoPlaceholderTitle(_ title: String, recordedDate: Date) -> Bool {
        title == defaultQuickRecordingTitle(at: recordedDate) || title == defaultRecordingTitle(at: recordedDate)
    }

    /// 新快速錄音的預設名稱：「語音錄音與對齊 日期時間」（與 iPad 首頁保持一致）。
    static func defaultQuickRecordingTitle(at date: Date = Date()) -> String {
        let label = LocalizationManager.localizedString("quick_record_title")
        return "\(label) \(LocalizationManager.formatted(date, date: .numeric, time: .shortened))"
    }

    /// 判斷標題是否為尚未經使用者自訂命名的通用「快速錄音」佔位標題（跨語系與自動時間戳格式）。
    nonisolated static func isGenericOrQuickRecordTitle(_ title: String) -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return true }

        // 1. 完全比對各語系通用字串
        let genericExact: [String] = [
            "快速錄音", "快速录音", "Quick Record", "Quick Recording", "クイック録音", "빠른 녹음", "บันทึกเสียงด่วน",
            "錄音", "录音", "Recording", "녹음", "การบันทึก",
            "語音錄音", "语音录音", "Voice recording", "音声録音", "음성 녹음", "บันทึกเสียง",
            "錄音收件匣", "录音收件箱", "Recording Inbox", "録音受信箱", "녹음 받은편지함", "กล่องข้อความเสียง",
            "語音錄音與對齊", "语音录音与对齐", "Audio Recording & Sync", "音声録音と同期", "음성 녹음 및 동기화", "การบันทึกเสียงและการซิงค์"
        ]
        for candidate in genericExact {
            if clean.caseInsensitiveCompare(candidate) == .orderedSame { return true }
        }

        let localizedTerms = [
            LocalizationManager.localizedString("quick_record"),
            LocalizationManager.localizedString("recording_inbox"),
            LocalizationManager.localizedString("recording_suffix"),
            LocalizationManager.localizedString("quick_record_title"),
            LocalizationManager.localizedString("recording_default_title")
        ]
        for term in localizedTerms {
            let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && clean.caseInsensitiveCompare(t) == .orderedSame { return true }
        }

        // 2. 字首比對：自動生成的預設名稱，如「語音錄音與對齊 2026/10/11 晚上 8:15」或「錄音 2026/10/11 下午 5:46」
        let genericPrefixes: [String] = [
            "語音錄音與對齊", "语音录音与对齐", "Audio Recording & Sync", "音声録音と同期", "음성 녹음 및 동기化", "음성 녹음 및 동기화", "การบันทึกเสียงและการซิงค์",
            "快速錄音", "快速录音", "Quick Record", "Quick Recording", "クイック録音", "빠른 녹음", "บันทึกเสียงด่วน",
            "語音錄音", "语音录音", "Voice recording", "音声録音", "음성 녹음", "บันทึกเสียง",
            "錄音", "录音", "Recording", "녹음", "การบันทึก"
        ]
        let lowerClean = clean.lowercased()
        for prefix in genericPrefixes {
            let lowerPrefix = prefix.lowercased()
            if lowerClean.hasPrefix(lowerPrefix) {
                let remainder = lowerClean.dropFirst(lowerPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if remainder.isEmpty { return true }
                let firstChar = remainder.first
                if firstChar?.isNumber == true ||
                   remainder.hasPrefix("晚上") || remainder.hasPrefix("下午") || remainder.hasPrefix("上午") ||
                   remainder.hasPrefix("am") || remainder.hasPrefix("pm") ||
                   remainder.contains("/") || remainder.contains("-") || remainder.contains(":") {
                    return true
                }
            }
        }
        for term in localizedTerms {
            let lowerTerm = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !lowerTerm.isEmpty && lowerClean.hasPrefix(lowerTerm) {
                let remainder = lowerClean.dropFirst(lowerTerm.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if remainder.isEmpty { return true }
                let firstChar = remainder.first
                if firstChar?.isNumber == true ||
                   remainder.hasPrefix("晚上") || remainder.hasPrefix("下午") || remainder.hasPrefix("上午") ||
                   remainder.hasPrefix("am") || remainder.hasPrefix("pm") ||
                   remainder.contains("/") || remainder.contains("-") || remainder.contains(":") {
                    return true
                }
            }
        }

        return false
    }

    /// 讀出一個套件裡的全部 `rectitle` 錄音標題（與 Android `RecordingIndex.titlesIn` 100% 對齊）。
    nonisolated static func packageRecordingTitles(packageURL: URL, deviceId: UInt32 = 0) -> [String: String] {
        guard FileManager.default.fileExists(atPath: packageURL.path) else { return [:] }
        guard let session = try? PadnoteSession.openExisting(path: packageURL.path, deviceId: deviceId) else {
            return [:]
        }
        guard let pageId = (try? session.pageIdAt(index: 0)) else { return [:] }
        var titles: [String: String] = [:]
        guard let imageBlocks = try? session.imageBlockIds(pageId: pageId) else { return [:] }
        for blockId in imageBlocks {
            guard let appearance = try? session.blockAppearance(blockId: blockId) else { continue }
            if ObjectEnvelope.kind(of: appearance) == "rectitle",
               let item = ObjectEnvelope.decode(RecordingTitle.self, kind: "rectitle", from: appearance) {
                let clean = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    titles[item.fileName.lowercased()] = clean
                }
            }
        }
        return titles
    }

    /// 新錄音的預設名稱：「錄音 日期時間」。
    ///
    /// **不帶筆記本名稱。** 原本是「<筆記本名> 錄音」，於是在名為「mac建立」的筆記本裡錄的音，
    /// 在錄音清單裡每一筆都叫「mac建立 錄音」—— 使用者看到的是別的筆記本的名字出現在他新錄的檔案上。
    /// 時間才是區分兩段錄音的東西。
    static func defaultRecordingTitle(at date: Date = Date()) -> String {
        let label = LocalizationManager.shared.localized("recording_suffix")
        return "\(label) \(LocalizationManager.formatted(date, date: .numeric, time: .shortened))"
    }

    public func refreshRecordings() {
        let fm = FileManager.default
        let currentRecordings = self.recordings
        let currentNotebooks = self.notebooks
        let currentUnmatched = self.unmatchedIncomingTitles
        let pendingTitles = self.pendingTitleWrites
        let pkgDir = self.corePackagesDirectory
        let legacyDir = AudioRecorderManager.shared.recordingsDirectory
        let inboxId = recordingInboxNotebookId()

        struct TargetInfo {
            let id: String
            let displayTitle: String
        }
        var targets: [TargetInfo] = currentNotebooks.map { TargetInfo(id: $0.id, displayTitle: $0.displayTitle()) }
        if !targets.contains(where: { $0.id.caseInsensitiveCompare(inboxId) == .orderedSame }) {
            targets.append(TargetInfo(id: inboxId, displayTitle: LocalizationManager.shared.localized("recording_inbox")))
        }

        let docsDir = self.documentsDir
        let work: () -> ([AudioRecordingRecord], Set<String>) = {
            var byFileName: [String: AudioRecordingRecord] = [:]
            for rec in currentRecordings {
                byFileName[rec.fileName.lowercased()] = rec
            }

            var localUnmatched = currentUnmatched
            var consumedUnmatchedKeys: Set<String> = []
            var scanned: [AudioRecordingRecord] = []

            for doc in targets {
                let isInbox = doc.id.caseInsensitiveCompare(inboxId) == .orderedSame
                let packageURL = pkgDir.appending(path: "\(doc.id.lowercased()).padnote")
                let audioDir = packageURL.appending(path: "media/audio")
                guard fm.fileExists(atPath: audioDir.path) else { continue }
                let files = (try? fm.contentsOfDirectory(
                    at: audioDir, includingPropertiesForKeys: [.contentModificationDateKey]))?
                    .filter { $0.pathExtension.lowercased() == "opus" } ?? []
                guard !files.isEmpty else { continue }

                let packageTitles = Self.packageRecordingTitles(packageURL: packageURL)
                for file in files {
                    let name = file.lastPathComponent
                    let lowerName = name.lowercased()
                    let candidateTitle = packageTitles[lowerName] ?? localUnmatched[lowerName]

                    if let existing = byFileName[lowerName] {
                        var updated = existing
                        if updated.linkedNotebookId == nil {
                            updated.linkedNotebookId = doc.id
                        }
                        // 1. 真實時長校正：僅當現存時長為 0 或缺漏時，才讀檔解碼，避免每次重複讀取龐大音檔
                        if updated.durationSeconds <= 0 {
                            let bytes = (try? Data(contentsOf: file)) ?? Data()
                            let realSeconds = Int(audioDurationSeconds(bytes: bytes))
                            if realSeconds > 0 {
                                updated.durationSeconds = realSeconds
                            }
                        }
                        // 1b. 修復：以前從別台下載來的錄音拿「檔案修改時間」（= 下載時間）當錄音時間，
                        // 名字就成了「語音錄音與對齊 <下載那一刻>」，幾段錄音全是同一分鐘。
                        // 檔名是 UUIDv7，前 48 位元就是錄音建立時間 —— 只修**自動產生**的名字，使用者改過的不碰。
                        let fileDate = Self.recordingDate(fromFileName: name, fallback: updated.recordedDate)
                        if abs(fileDate.timeIntervalSince(updated.recordedDate)) > 60,
                           Self.isAutoPlaceholderTitle(updated.title, recordedDate: updated.recordedDate)
                        {
                            let wasQuick = updated.title == Self.defaultQuickRecordingTitle(at: updated.recordedDate)
                            updated.recordedDate = fileDate
                            updated.title = wasQuick
                                ? Self.defaultQuickRecordingTitle(at: fileDate)
                                : Self.defaultRecordingTitle(at: fileDate)
                        }
                        // 2. 標題校正：
                        //   - 本機標題是通用佔位名稱（如「快速錄音」），套件或遠端有具體自訂名稱 → 採納；
                        //   - 本機標題是**自己依時間產生的預設名稱**（不是使用者取的），遠端有名字（即使也是預設名稱，
                        //     那一個帶的是錄音當下的時間）→ 採納遠端的。
                        //   套件裡有名字：**一律採用**（套件是唯一的真相來源，改名會直接寫進去，見 `writeRecordingTitle`）。
                        if let pending = pendingTitles[lowerName] {
                            updated.title = pending // 剛改、套件還沒寫完
                        } else if let named = packageTitles[lowerName], !named.isEmpty, named != updated.title,
                                  !Self.downgradesTitle(from: updated.title, to: named) {
                            updated.title = named
                        } else if let named = candidateTitle, !named.isEmpty, named != updated.title,
                                  Self.isAutoPlaceholderTitle(updated.title, recordedDate: updated.recordedDate) {
                            updated.title = named
                        }
                        scanned.append(updated)
                        byFileName.removeValue(forKey: lowerName)
                        localUnmatched.removeValue(forKey: lowerName)
                        consumedUnmatchedKeys.insert(lowerName)
                        continue
                    }
                    // 從別台同步過來的：索引裡沒有，要補一筆才看得到。
                    let bytes = (try? Data(contentsOf: file)) ?? Data()
                    let seconds = Int(audioDurationSeconds(bytes: bytes))
                    let fileModified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                        .contentModificationDate ?? Date()
                    // 錄音時間取檔名裡的 UUIDv7 時間戳；修改時間在別台同步來的檔案上是「下載時間」。
                    let modified = Self.recordingDate(fromFileName: name, fallback: fileModified)
                    let title: String
                    if let named = candidateTitle, !named.isEmpty {
                        title = named
                        localUnmatched.removeValue(forKey: lowerName)
                        consumedUnmatchedKeys.insert(lowerName)
                    } else if isInbox {
                        title = Self.defaultQuickRecordingTitle(at: modified)
                    } else {
                        title = Self.defaultRecordingTitle(at: modified)
                    }
                    scanned.append(AudioRecordingRecord(
                        title: title,
                        durationSeconds: seconds,
                        recordedDate: modified,
                        fileName: name,
                        linkedNotebookId: doc.id))
                }
            }

            let mirroredManifest = Self.readMirroredRecordingsManifest(in: legacyDir)
            let mirroredNames = Set(mirroredManifest.values.map { $0.lowercased() })
                .union(mirroredManifest.keys.map { $0.lowercased() })
            let legacy = byFileName.values.filter {
                let lower = $0.fileName.lowercased()
                guard !mirroredNames.contains(lower),
                      ($0.fileName as NSString).pathExtension.lowercased() != "opus" else {
                    return false
                }
                return fm.fileExists(atPath: legacyDir.appending(path: $0.fileName).path)
            }

            // 不再以卡片名稱覆蓋清單：卡片跟著錄音的名字走，兩邊互相覆蓋就是名字來回跳的原因之一。
            let refreshed = (scanned + legacy).sorted { $0.recordedDate > $1.recordedDate }
            _ = Self.syncRecordingsExportFolder(
                recordings: refreshed,
                packagesDir: pkgDir,
                documentsDir: docsDir,
                exportDir: legacyDir)

            return (refreshed, consumedUnmatchedKeys)
        }

        let applyResult: ([AudioRecordingRecord], Set<String>) -> Void = { [weak self] refreshed, consumedKeys in
            guard let self else { return }
            for key in consumedKeys {
                self.unmatchedIncomingTitles.removeValue(forKey: key)
            }
            guard refreshed != self.recordings else { return }
            self.recordings = refreshed
            self.persistData(signalsLocalEdit: false)
        }

        if Thread.isMainThread {
            DispatchQueue.global(qos: .utility).async {
                let (refreshed, consumedKeys) = work()
                DispatchQueue.main.async {
                    applyResult(refreshed, consumedKeys)
                }
            }
        } else {
            let (refreshed, consumedKeys) = work()
            DispatchQueue.main.async {
                applyResult(refreshed, consumedKeys)
            }
        }
    }

    private nonisolated static let mirroredManifestFileName = ".kairumo-mirrored.json"

    private nonisolated static func readMirroredRecordingsManifest(in exportDir: URL) -> [String: String] {
        let url = exportDir.appending(path: mirroredManifestFileName)
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private nonisolated static func writeMirroredRecordingsManifest(_ manifest: [String: String], in exportDir: URL) {
        let url = exportDir.appending(path: mirroredManifestFileName)
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private nonisolated static func sanitizeExportedRecordingTitle(_ rawTitle: String, fallbackStem: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\\0\n\r\t")
        let replaced = rawTitle.unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }.joined()
        let trimmed = replaced.trimmingCharacters(in: CharacterSet(charactersIn: ". \t\n\r"))
        return trimmed.isEmpty ? fallbackStem : trimmed
    }

    /// 將所有套件內的真實錄音檔（`*.padnote/media/audio/*.opus`）同步鏡射至 `Kairumo Record` 資料夾，
    /// 使 Finder／「檔案」App 打開 `Kairumo Record` 時能看到與 App 錄音清單一致的音訊檔案。
    /// 回傳 `rec.fileName.lowercased() -> Kairumo Record 內對應檔案 URL` 的對照表。
    @discardableResult
    public func syncRecordingsExportFolder() -> [String: URL] {
        Self.syncRecordingsExportFolder(
            recordings: recordings,
            packagesDir: corePackagesDirectory,
            documentsDir: documentsDir,
            exportDir: AudioRecorderManager.shared.recordingsDirectory)
    }

    /// 取得錄音在 `Kairumo Record` 匯出資料夾中的對應檔案 URL（供分享與 Finder 顯示）。
    public func exportedRecordingFileURL(for rawURL: URL) -> URL {
        let map = syncRecordingsExportFolder()
        let key = rawURL.lastPathComponent.lowercased()
        if let mapped = map[key], FileManager.default.fileExists(atPath: mapped.path) {
            return mapped
        }
        return rawURL
    }

    @discardableResult
    nonisolated static func syncRecordingsExportFolder(
        recordings: [AudioRecordingRecord],
        packagesDir: URL,
        documentsDir: URL,
        exportDir: URL
    ) -> [String: URL] {
        let fm = FileManager.default
        if !fm.fileExists(atPath: exportDir.path) {
            try? fm.createDirectory(at: exportDir, withIntermediateDirectories: true)
        }

        let isUITest = ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1"
        if !isUITest {
            let fixture = exportDir.appending(path: "uitest-fixture.opus")
            if fm.fileExists(atPath: fixture.path) {
                try? fm.removeItem(at: fixture)
            }
        }

        let previousManifest = readMirroredRecordingsManifest(in: exportDir)
        var newManifest: [String: String] = [:]
        var resultURLs: [String: URL] = [:]
        var usedExportNames: Set<String> = []
        let inboxId = recordingInboxNotebookId().lowercased()

        let allPackageDirs: [URL] = {
            var dirs: [URL] = []
            if let pkgs = try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil) {
                dirs.append(contentsOf: pkgs.filter { $0.pathExtension == "padnote" })
            }
            if let docPkgs = try? fm.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil) {
                dirs.append(contentsOf: docPkgs.filter { $0.pathExtension == "padnote" })
            }
            return dirs
        }()

        func findSourceAudio(for rec: AudioRecordingRecord) -> URL? {
            let clean = (rec.fileName as NSString).lastPathComponent
            guard !clean.isEmpty else { return nil }
            if let linked = rec.linkedNotebookId?.lowercased(), !linked.isEmpty {
                let candidate = packagesDir.appending(path: "\(linked).padnote/media/audio/\(clean)")
                if fm.fileExists(atPath: candidate.path) { return candidate }
            }
            let inInbox = packagesDir.appending(path: "\(inboxId).padnote/media/audio/\(clean)")
            if fm.fileExists(atPath: inInbox.path) { return inInbox }
            for pkg in allPackageDirs {
                let candidate = pkg.appending(path: "media/audio/\(clean)")
                if fm.fileExists(atPath: candidate.path) { return candidate }
            }
            return nil
        }

        for rec in recordings {
            let key = (rec.fileName as NSString).lastPathComponent.lowercased()
            guard !key.isEmpty else { continue }

            guard let sourceURL = findSourceAudio(for: rec) else {
                let looseURL = exportDir.appending(path: rec.fileName)
                if fm.fileExists(atPath: looseURL.path) {
                    usedExportNames.insert(rec.fileName.lowercased())
                    resultURLs[key] = looseURL
                }
                continue
            }

            let stem = (rec.fileName as NSString).deletingPathExtension
            let ext = (rec.fileName as NSString).pathExtension.isEmpty
                ? "opus"
                : (rec.fileName as NSString).pathExtension
            let baseTitle = sanitizeExportedRecordingTitle(rec.title, fallbackStem: stem)

            var exportName = "\(baseTitle).\(ext)"
            var suffix = 2
            while usedExportNames.contains(exportName.lowercased()) {
                exportName = "\(baseTitle) (\(suffix)).\(ext)"
                suffix += 1
            }
            usedExportNames.insert(exportName.lowercased())

            let targetURL = exportDir.appending(path: exportName)
            if let oldName = previousManifest[key],
               oldName.caseInsensitiveCompare(exportName) != .orderedSame {
                let oldURL = exportDir.appending(path: oldName)
                if fm.fileExists(atPath: oldURL.path) && !fm.fileExists(atPath: targetURL.path) {
                    try? fm.moveItem(at: oldURL, to: targetURL)
                }
            }

            let sourceSize = (try? fm.attributesOfItem(atPath: sourceURL.path)[.size] as? UInt64) ?? 0
            let targetSize = (try? fm.attributesOfItem(atPath: targetURL.path)[.size] as? UInt64)
            if targetSize != sourceSize {
                if fm.fileExists(atPath: targetURL.path) {
                    try? fm.removeItem(at: targetURL)
                }
                try? fm.copyItem(at: sourceURL, to: targetURL)
                try? fm.setAttributes([.modificationDate: rec.recordedDate], ofItemAtPath: targetURL.path)
            }

            newManifest[key] = exportName
            resultURLs[key] = targetURL
        }

        for (_, oldExportName) in previousManifest {
            if !usedExportNames.contains(oldExportName.lowercased()) {
                let staleURL = exportDir.appending(path: oldExportName)
                if fm.fileExists(atPath: staleURL.path) {
                    try? fm.removeItem(at: staleURL)
                }
            }
        }

        if let files = try? fm.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension.lowercased() == "opus" {
                let name = file.lastPathComponent
                if isUITest && name.caseInsensitiveCompare("uitest-fixture.opus") == .orderedSame {
                    continue
                }
                if !usedExportNames.contains(name.lowercased()) {
                    try? fm.removeItem(at: file)
                }
            }
        }

        writeMirroredRecordingsManifest(newManifest, in: exportDir)
        return resultURLs
    }

    /// 遷移之後改指到套件裡的新檔案。
    public func replaceRecordingFile(recordingId: String, fileName: String, notebookId: String) {
        guard let idx = recordings.firstIndex(where: { $0.id == recordingId }) else { return }
        recordings[idx].fileName = fileName
        recordings[idx].linkedNotebookId = notebookId
        if let nIdx = notebooks.firstIndex(where: {
            $0.id.caseInsensitiveCompare(notebookId) == .orderedSame
        }) {
            notebooks[nIdx].hasRecording = true
            notebooks[nIdx].recordingAudioPath = fileName
        }
        // 畫布上的錄音卡片也指著舊檔名 —— 不一起換的話，
        // 卡片會變成「按了播放沒有反應」。
        for nIdx in notebooks.indices {
            guard var cards = notebooks[nIdx].audioAttachments else { continue }
            var touched = false
            for cIdx in cards.indices where cards[cIdx].recordingId == recordingId {
                cards[cIdx].fileName = fileName
                touched = true
            }
            if touched {
                notebooks[nIdx].audioAttachments = cards
            }
        }
        persistData()
    }

    /// 重新命名錄音的顯示名稱。
    ///
    /// 音檔本身以 UUID 命名，不能跟著改檔名，否則同步路徑與媒體墓碑都會
    /// 斷掉。這裡更新首頁索引，並同步更新已插入各頁的錄音卡片；因此從首頁
    /// 或筆記頁看到的是同一個名稱，下一輪套件匯出也會把卡片名稱帶到別台。
    public func renameRecording(id: String? = nil, fileName targetFileName: String? = nil, newTitle: String) {
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let targetId = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetFile = targetFileName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let recordingIndex = recordings.firstIndex { rec in
            if let targetId, !targetId.isEmpty, rec.id == targetId { return true }
            if let targetFile, !targetFile.isEmpty, rec.fileName.lowercased() == targetFile { return true }
            return false
        }
        guard let recordingIndex else { return }

        recordings[recordingIndex].title = clean
        // 名字存在錄音所在的套件裡。沒有卡片的錄音，改名不會動到任何筆記，同步就以為沒有東西要匯出 ——
        // 把那本筆記標成有修改，下一輪才會把新名字寫進套件。
        let targetNotebookId = recordings[recordingIndex].linkedNotebookId ?? recordingInbox().id
        if recordings[recordingIndex].linkedNotebookId == nil {
            recordings[recordingIndex].linkedNotebookId = targetNotebookId
        }

        // 確保對應的筆記本存在於清單中（若是收件匣則自動建立/讀入），並更新修改時間
        if let idx = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(targetNotebookId) == .orderedSame }) {
            notebooks[idx].lastModifiedDate = Date()
        } else if targetNotebookId.caseInsensitiveCompare(recordingInboxNotebookId()) == .orderedSame {
            var inbox = recordingInbox()
            inbox.lastModifiedDate = Date()
            if let idx = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(inbox.id) == .orderedSame }) {
                notebooks[idx] = inbox
            }
        }

        let fileName = recordings[recordingIndex].fileName.lowercased()
        // 名字直接寫進錄音所在的套件（唯一的真相來源，見 `writeRecordingTitle`）。
        let packagePath = corePackagesDirectory
            .appending(path: "\(targetNotebookId.lowercased()).padnote").path
        let device = NotebookMigration.deviceId
        pendingTitleWrites[fileName] = clean
        Task.detached(priority: .userInitiated) { [weak self] in
            NotebookPackageBridge.writeRecordingTitle(
                packagePath: packagePath, fileName: fileName, title: clean, deviceId: device)
            await MainActor.run {
                if self?.pendingTitleWrites[fileName] == clean { self?.pendingTitleWrites.removeValue(forKey: fileName) }
            }
        }
        for notebookIndex in notebooks.indices {
            guard var cards = notebooks[notebookIndex].audioAttachments else { continue }
            var changed = false
            // 用檔名也對：卡片上的錄音 id 是**建立那台裝置**的，這台裝置替同一個檔案產生的 id 不同，
            // 只比 id 的話，在 iPad 改一段 Mac 錄的音，卡片不會跟著改，名字也就不會同步回去。
            for cardIndex in cards.indices
            where cards[cardIndex].recordingId == id || cards[cardIndex].fileName.lowercased() == fileName {
                cards[cardIndex].title = clean
                changed = true
            }
            if changed {
                notebooks[notebookIndex].audioAttachments = cards
                notebooks[notebookIndex].lastModifiedDate = Date()
            }
        }
        markDirtyAndPersist(signalsLocalEdit: true)
        syncRecordingsExportFolder()
    }

    public func deleteRecording(id: String) {
        if let rec = recordings.first(where: { $0.id == id }) {
            let fileName = rec.fileName
            // 1. 若有關聯筆記本，走核心標記墓碑並刪除
            if let notebookId = rec.linkedNotebookId {
                let packagePath = corePackagesDirectory
                    .appending(path: "\(notebookId.lowercased()).padnote").path
                let error = mediaDeleteAudio(packagePath: packagePath, name: fileName, deviceId: NotebookMigration.deviceId)
                if !error.isEmpty {
                    SyncLogger.logAsync("刪除錄音：\(error)", source: .googleDrive)
                }
            }
            // 2. 檢查「錄音收件匣」套件
            let inboxPath = corePackagesDirectory
                .appending(path: "\(recordingInboxNotebookId().lowercased()).padnote").path
            if FileManager.default.fileExists(atPath: inboxPath) {
                _ = mediaDeleteAudio(packagePath: inboxPath, name: fileName, deviceId: NotebookMigration.deviceId)
            }
            // 3. 搜尋所有本機套件目錄，凡有該音訊檔皆刪除並留墓碑
            if let packages = try? FileManager.default.contentsOfDirectory(at: corePackagesDirectory, includingPropertiesForKeys: nil) {
                for pkg in packages where pkg.pathExtension == "padnote" {
                    let audioFile = pkg.appending(path: "media/audio").appending(path: fileName)
                    if FileManager.default.fileExists(atPath: audioFile.path) {
                        _ = mediaDeleteAudio(packagePath: pkg.path, name: fileName, deviceId: NotebookMigration.deviceId)
                        try? FileManager.default.removeItem(at: audioFile)
                    }
                }
            }
            // 4. 套件外那一份（還沒歸到任何筆記本的錄音）直接刪，它不參與同步。
            let loose = AudioRecorderManager.shared.recordingsDirectory
                .appending(path: fileName)
            try? FileManager.default.removeItem(at: loose)
        }
        withAnimation {
            recordings.removeAll { $0.id == id }
        }
        persistData()
        syncRecordingsExportFolder()
    }

    // MARK: - 核心格式遷移（工作包 WP4c）

    /// 把目前所有筆記遷移成核心的 `.padnote` 套件。
    ///
    /// **不會在啟動時自動執行。** 這是一個明確的動作，由呼叫端決定何時做 ——
    /// 在 App 啟動路徑上偷偷跑一次會動到使用者的資料，而且出事的時候他們
    /// 連自己做過什麼都不知道。
    ///
    /// 遷移只讀既有資料，產物寫到 `Documents/Packages/`；動手前先備份，
    /// 每一本都匯出後立刻讀回來逐點驗過才算數。詳見 `NotebookMigration`。
    @discardableResult
    public func migrateToCoreFormat() -> NotebookMigration.Report {
        NotebookMigration.migrate(
            documents: notebooks,
            root: documentsDir,
            deviceId: NotebookMigration.deviceId,
            drawingLoader: { [weak self] id, page in
                self?.loadDrawing(notebookId: id, pageIndex: page) ?? PKDrawing()
            },
            imageLoader: { [weak self] fileName in
                guard let self else { return nil }
                let url = self.attachmentsDirectory.appending(path: fileName)
                return try? Data(contentsOf: url)
            }
        )
    }

    /// 把舊版的可延長頁面重新切成固定高度的頁（問題 3＋5）。
    ///
    /// **不會在啟動時自動執行。** 它會動到使用者的頁面配置，必須是明確的動作。
    /// 原始資料在備份裡，可以還原。
    @discardableResult
    public func repaginateToFixedPages() -> PageRepagination.Report {
        let report = PageRepagination.migrate(
            documents: notebooks,
            root: documentsDir,
            drawingLoader: { [weak self] id, page in
                self?.loadDrawing(notebookId: id, pageIndex: page) ?? PKDrawing()
            },
            drawingWriter: { [weak self] id, page, drawing in
                self?.saveDrawing(notebookId: id, pageIndex: page, drawing: drawing)
            },
            documentWriter: { [weak self] doc in
                guard let self, let index = self.notebooks.firstIndex(where: { $0.id == doc.id })
                else { return }
                self.notebooks[index] = doc
            }
        )
        persistData()
        return report
    }

    /// 有沒有筆記還在用舊版的可延長頁面。
    public var needsRepagination: Bool {
        notebooks.contains(where: PageRepagination.needsRepagination)
    }

    /// 從備份還原，並清掉遷移產物。
    public func rollbackCoreMigration(from backup: URL) throws {
        try NotebookMigration.rollback(root: documentsDir, from: backup)
        loadData()
    }

    /// 目前的遷移狀態（哪幾本已經遷好、各有幾筆畫）。
    public var coreMigrationState: NotebookMigration.State {
        NotebookMigration.loadState(in: documentsDir)
    }

    /// 遷移產物的位置。
    public var corePackagesDirectory: URL {
        NotebookMigration.packagesDirectory(in: documentsDir)
    }

    // MARK: - 里程碑快照時光機（工作項 S-99）
    //
    // 三支全部走核心。Apple 端的工作副本在套件外面，所以每一支的第一步
    // 都是把工作副本鏡進套件（`mirrorWorkingCopyIntoPackage`），
    // 還原之後再讀回來 —— 少了這兩步，使用者會看到「按了還原但畫面沒變」。

    /// 舊版 `.snapshot` 檔的位置。**只讀不寫**，見 `legacySnapshots`。
    public var snapshotsDirectory: URL {
        documentsDir.appendingPathComponent("Snapshots", isDirectory: true)
    }

    /// 建立里程碑快照。
    @discardableResult
    public func createMilestoneSnapshot(notebookId: String, title: String, creatorName: String)
        -> NotebookMilestoneSnapshot?
    {
        guard let note = notebooks.first(where: { $0.id == notebookId }) else { return nil }
        let deviceId = NotebookMigration.deviceId
        do {
            let package = try NotebookSyncCoordinator.mirrorWorkingCopyIntoPackage(
                note, store: self, deviceId: deviceId)
            let session = try PadnoteSession.openExisting(path: package.path, deviceId: deviceId)
            let created = try session.createMilestone(
                title: title.isEmpty
                    ? LocalizationManager.shared.localized("collab_snapshot") : title,
                creator: creatorName,
                nowUnixMs: UInt64(max(0, Date().timeIntervalSince1970 * 1000)))
            return snapshot(from: created, notebookId: notebookId)
        } catch {
            return nil
        }
    }

    /// 列出指定筆記的全部里程碑，新的在前。舊版 `.snapshot` 檔接在後面。
    public func listMilestoneSnapshots(notebookId: String) -> [NotebookMilestoneSnapshot] {
        var list: [NotebookMilestoneSnapshot] = []
        let deviceId = NotebookMigration.deviceId
        let package = corePackagesDirectory
            .appending(path: "\(notebookId.lowercased()).padnote")
        if let session = try? PadnoteSession.openExisting(path: package.path, deviceId: deviceId),
            let milestones = try? session.milestones()
        {
            // Android 每次開編輯器會插一個內部標記（「一鍵恢復初始狀態」用），不是使用者的快照。
            list = milestones
                .filter { $0.title != "\u{200B}editor-open" }
                .map { snapshot(from: $0, notebookId: notebookId) }
        }
        return list + legacySnapshots(notebookId: notebookId)
    }

    /// 回滾至指定快照。
    @discardableResult
    public func restoreMilestoneSnapshot(notebookId: String, snapshot: NotebookMilestoneSnapshot)
        -> Bool
    {
        if snapshot.isLegacy {
            // 舊檔沒有辦法變成「一刀」——  它是一份內容副本。
            // 這裡不假裝做得到，交給舊的還原路徑。
            return restoreLegacySnapshot(notebookId: notebookId, id: snapshot.id)
        }
        guard let note = notebooks.first(where: { $0.id == notebookId }) else { return false }
        let deviceId = NotebookMigration.deviceId
        do {
            // 先把「還原之前」的工作副本推進套件 —— 自動安全快照才照得到它。
            let package = try NotebookSyncCoordinator.mirrorWorkingCopyIntoPackage(
                note, store: self, deviceId: deviceId)
            let session = try PadnoteSession.openExisting(path: package.path, deviceId: deviceId)
            _ = try session.restoreMilestone(
                milestoneId: snapshot.id,
                nowUnixMs: UInt64(max(0, Date().timeIntervalSince1970 * 1000)),
                safetyTitle: String(
                    format: LocalizationManager.shared.localized("milestone_before_restore"),
                    snapshot.title))
            try NotebookSyncCoordinator.applyPackageToWorkingCopy(
                notebookId: notebookId, store: self, deviceId: deviceId)
            if let idx = notebooks.firstIndex(where: { $0.id == notebookId }) {
                notebooks[idx].lastModifiedDate = Date()
            }
            persistData()
            return true
        } catch {
            return false
        }
    }

    private func snapshot(from m: FfiMilestone, notebookId: String) -> NotebookMilestoneSnapshot {
        NotebookMilestoneSnapshot(
            id: m.id,
            notebookId: notebookId,
            title: m.title,
            creatorName: m.creator,
            createdAt: Date(timeIntervalSince1970: Double(m.createdUnixMs) / 1000),
            automatic: m.automatic)
    }

    // MARK: 舊版 `.snapshot` 檔
    //
    // 4.8.x 以前的快照是整份內容副本。那些檔案換不成核心的「一刀」，
    // 但使用者手上真的有，直接無視等於把他的東西丟掉。所以照樣列出來、
    // 照樣還原得動，只是不再產生新的。

    /// 舊檔的最小解碼形狀 —— 只取還原需要的欄位。
    private struct LegacySnapshot: Codable {
        let id: String
        let title: String
        let creatorName: String
        let createdAt: Date
        let noteData: Data
        let pagesData: [Data]
    }

    private func legacySnapshots(notebookId: String) -> [NotebookMilestoneSnapshot] {
        let dir = snapshotsDirectory.appendingPathComponent(notebookId, isDirectory: true)
        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return
            files
            .filter { $0.pathExtension == "snapshot" }
            .compactMap { url -> NotebookMilestoneSnapshot? in
                guard let data = try? Data(contentsOf: url),
                    let old = try? JSONDecoder().decode(LegacySnapshot.self, from: data)
                else { return nil }
                return NotebookMilestoneSnapshot(
                    id: old.id,
                    notebookId: notebookId,
                    title: old.title,
                    creatorName: old.creatorName,
                    createdAt: old.createdAt,
                    isLegacy: true)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func restoreLegacySnapshot(notebookId: String, id: String) -> Bool {
        let url = snapshotsDirectory
            .appendingPathComponent(notebookId, isDirectory: true)
            .appending(path: "\(id).snapshot")
        guard let data = try? Data(contentsOf: url),
            let old = try? JSONDecoder().decode(LegacySnapshot.self, from: data),
            let restoredNote = try? JSONDecoder().decode(
                NotebookDocument.self, from: old.noteData),
            let idx = notebooks.firstIndex(where: { $0.id == notebookId })
        else { return false }

        for (pageIdx, bytes) in old.pagesData.enumerated() {
            if let drawing = try? PKDrawing(data: bytes) {
                saveDrawing(notebookId: notebookId, pageIndex: pageIdx, drawing: drawing)
            }
        }
        notebooks[idx] = restoredNote
        notebooks[idx].lastModifiedDate = Date()
        persistData()
        return true
    }
}

// MARK: - 頁面歸屬
//
// 全部用 extension 宣告符合，而不是改動每個 struct 的宣告行 ——
// 那些宣告行同時掛著 Codable 與 ObjectFrameStyled，動它們容易改錯。
extension NoteImageAttachment: PageIndexed {}
extension Note3DAttachment: PageIndexed {}
extension NoteTextAttachment: PageIndexed {}
extension NoteLinkAttachment: PageIndexed {}
extension NoteCommentPin: PageIndexed {}
extension NoteAudioAttachment: PageIndexed {}
extension NoteTableAttachment: PageIndexed {}
extension NoteShapeAttachment: PageIndexed {}
extension NoteConnectionAttachment: PageIndexed {}
extension NoteTapeAttachment: PageIndexed {}
extension StickyAnnotationAnchor: PageIndexed {}

public struct NoteTapeAttachment: Identifiable, Codable, Hashable {
    public let id: String
    public var pageIndex: Int
    public var rect: CGRect
    public var isRevealed: Bool
    public var colorHex: String?
    public var rotation: Double
    
    public init(id: String = UUID().uuidString.lowercased(), pageIndex: Int, rect: CGRect, isRevealed: Bool = false, colorHex: String? = nil, rotation: Double = 0.0) {
        self.id = id
        self.pageIndex = pageIndex
        self.rect = rect
        self.isRevealed = isRevealed
        self.colorHex = colorHex
        self.rotation = rotation
    }

    private enum CodingKeys: String, CodingKey {
        case id, pageIndex, rect, isRevealed, colorHex, x, y, width, height, rotation
    }

    private struct KeyedRect: Decodable {
        struct Point: Decodable { var x: CGFloat; var y: CGFloat }
        struct Size: Decodable { var width: CGFloat; var height: CGFloat }
        var origin: Point
        var size: Size
    }

    /// `rect` 讀得懂三種寫法：Apple 的 `CGRect` 預設格式 `[[x,y],[w,h]]`、
    /// `{origin:{x,y}, size:{width,height}}`（舊版 Android 寫的）與扁平的 x／y／width／height。
    /// 原本只認第一種：Android 寫的膠帶在這裡整筆解不開，位置與大小跟著跳掉。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        pageIndex = try c.decodeIfPresent(Int.self, forKey: .pageIndex) ?? 0
        isRevealed = try c.decodeIfPresent(Bool.self, forKey: .isRevealed) ?? false
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0.0
        if let r = try? c.decode(CGRect.self, forKey: .rect) {
            rect = r
        } else if let k = try? c.decode(KeyedRect.self, forKey: .rect) {
            rect = CGRect(x: k.origin.x, y: k.origin.y, width: k.size.width, height: k.size.height)
        } else {
            rect = CGRect(
                x: try c.decodeIfPresent(CGFloat.self, forKey: .x) ?? 0,
                y: try c.decodeIfPresent(CGFloat.self, forKey: .y) ?? 0,
                width: try c.decodeIfPresent(CGFloat.self, forKey: .width) ?? 120,
                height: try c.decodeIfPresent(CGFloat.self, forKey: .height) ?? 32)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(pageIndex, forKey: .pageIndex)
        try c.encode(rect, forKey: .rect)
        try c.encode(isRevealed, forKey: .isRevealed)
        try c.encodeIfPresent(colorHex, forKey: .colorHex)
        try c.encode(rotation, forKey: .rotation)
    }
}

// MARK: - 設定檔切換

extension NotebookStore: ProfileScoped {
    func finishPreparingForProfileSwitch() async {
        // 同步已經安靜了：把記憶體裡最後一版落盤，並等背景寫檔佇列真的寫完。
        // 不等的話，寫檔會在切換之後才收尾 —— 路徑雖然是當下取定的，但寫完之後的
        // `Task { @MainActor }` 會拿新設定檔的陣列再排一次寫入，兩個設定檔的狀態就纏在一起了。
        markDirtyAndPersist(signalsLocalEdit: false)
        // **不能用一個很短的上限放棄等待。** 這裡原本最多等 10 秒就照常切換 —— 慢的裝置（舊 iPad、CI 機器）
        // 上，整份文件庫（含範例的手繪資料）編碼並寫檔可以超過 10 秒；放棄等待的結果是新設定檔重讀檔案時，
        // 舊設定檔最後一次編輯**還沒寫完**，那筆資料就在切換裡消失了。寫檔慢是慢，丟資料是另一回事。
        // 上限只是防止永遠卡住（2 分鐘），不是「太久就算了」。
        var waited = 0
        while (pendingWrite || needsAnotherWrite), waited < 2_400 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 1
        }
        // 旗標清掉只代表「最後一次排進去的寫入」收尾了；再用一個屏障確認寫檔佇列裡沒有殘留的工作。
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Self.ioQueue.async { continuation.resume() }
        }
    }

    func resetForProfileSwitch() {
        notebooks = []
        recordings = []
        folders = []
        trashedNotebooks = []
        rootFolderName = ""
        activeNotebookId = nil
        pendingWrite = false
        needsAnotherWrite = false
        signalAfterWrite = false
        imageCache.removeAllObjects()
        isHiddenCache.removeAll()
        lastIndexJSONForHidden = ""
        unmatchedIncomingTitles.removeAll()
        loadAndSeed()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshRecordings()
        }
    }
}


// MARK: - 範例筆記本：編輯先放暫存區，離開時再決定

/// 被設為「範例」的筆記本（內建範例預設是，任何一本都能設定／解除，見 `NotebookDocument.isReadOnlySample`）。
///
/// 打開範例之後，所有操作照常在畫面上進行，但**不提示、不同步**：開啟那一刻的完整內容先備份到暫存區
/// （`SampleSessions/<id>/`：文件、筆跡檔、同步基準、核心套件）。使用者離開筆記本時，若內容真的有變，
/// 再問要「存檔（保留在此範例）」、「另存可編輯副本」或「放棄修改」，照選擇處理（`finishSampleSession`）。
///
/// App 被關掉時沒辦法問（行動平台不允許擋住關閉）：暫存區留在磁碟上，下次回到首頁再問
/// （`pendingSampleSessionIds`）。與 Android `SampleSession` 同一套規則。
///
/// 「有沒有變」只比使用者會改的內容（`sampleContentFingerprint`）。原本比的是整份文件與筆跡檔的位元組，
/// 翻頁時背景的手寫辨識寫回 `recognizedText`、整理頁面 id 都會讓它變 —— 只是瀏覽就被當成編輯（使用者回報）。
enum SampleLeaveChoice {
    /// 改動留在這本範例裡。
    case keep
    /// 改動另存成一本一般筆記本，範例回到打開前的樣子。
    case saveCopy
    /// 改動丟掉，範例回到打開前的樣子。
    case discard
}

extension NotebookStore {

    var sampleSessionsDirectory: URL { documentsDir.appending(path: "SampleSessions") }

    private func sampleSessionDirectory(_ id: String) -> URL {
        sampleSessionsDirectory.appending(path: id.lowercased())
    }

    /// 這本是不是正在範例暫存期間（打開了、還沒決定怎麼處理改動）。暫存期間不同步。
    func hasSampleSession(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: sampleSessionDirectory(id).appending(path: "doc.json").path)
    }

    /// 還沒決定怎麼處理的範例暫存（例如 App 在範例開著時被關掉）。
    var pendingSampleSessionIds: [String] {
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: sampleSessionsDirectory, includingPropertiesForKeys: nil)) ?? []
        return dirs.map(\.lastPathComponent).compactMap { name in
            notebooks.first { $0.id.lowercased() == name }?.id
        }.filter { hasSampleSession($0) }
    }

    /// 打開範例時：把現在的完整內容備份到暫存區。已經有暫存（上次還沒決定）就沿用，不覆蓋。
    func beginSampleSession(_ id: String) {
        guard let doc = notebooks.first(where: { $0.id == id }), doc.isReadOnlySample, !hasSampleSession(id) else { return }
        let fm = FileManager.default
        let dir = sampleSessionDirectory(id)
        try? fm.removeItem(at: dir)
        do {
            try fm.createDirectory(at: dir.appending(path: "drawings"), withIntermediateDirectories: true)
            try fm.createDirectory(at: dir.appending(path: "baseline"), withIntermediateDirectories: true)
            for (source, target) in [(drawingsDirectory, "drawings"), (syncBaselineDirectory, "baseline")] {
                for file in sessionFiles(of: doc.id, in: source) {
                    try fm.copyItem(at: file, to: dir.appending(path: target).appending(path: file.lastPathComponent))
                }
            }
            let package = corePackagesDirectory.appending(path: "\(doc.id.lowercased()).padnote")
            if fm.fileExists(atPath: package.path) {
                try fm.copyItem(at: package, to: dir.appending(path: "package.padnote"))
            }
            try Data(sampleContentFingerprint(doc).utf8).write(to: dir.appending(path: "fingerprint"))
            // doc.json 最後寫：它在不在就代表暫存是否完整（`hasSampleSession`）。
            try JSONEncoder().encode(doc).write(to: dir.appending(path: "doc.json"), options: .atomic)
        } catch {
            try? fm.removeItem(at: dir)
        }
    }

    /// 打開之後內容有沒有真的改過。
    func sampleSessionHasChanges(_ id: String) -> Bool {
        guard hasSampleSession(id),
              let doc = notebooks.first(where: { $0.id == id }),
              let data = try? Data(contentsOf: sampleSessionDirectory(id).appending(path: "fingerprint")),
              let before = String(data: data, encoding: .utf8) else { return false }
        return sampleContentFingerprint(doc) != before
    }

    /// 照使用者的選擇處理範例的改動，結束暫存。選「另存可編輯副本」時回傳新的那一本。
    @discardableResult
    func finishSampleSession(_ id: String, choice: SampleLeaveChoice) -> NotebookDocument? {
        guard hasSampleSession(id) else { return nil }
        defer { try? FileManager.default.removeItem(at: sampleSessionDirectory(id)) }
        switch choice {
        case .keep:
            markDirtyAndPersist(signalsLocalEdit: true)
            return nil
        case .discard:
            restoreSampleSession(id)
            return nil
        case .saveCopy:
            guard let current = notebooks.first(where: { $0.id == id }), let copy = copySample(current) else { return nil }
            restoreSampleSession(id, persist: false)
            adoptSampleCopy(copy, from: id)
            markDirtyAndPersist(signalsLocalEdit: true)
            return copy
        }
    }

    /// 把範例放回打開前的樣子（文件、筆跡檔、同步基準、核心套件）。
    private func restoreSampleSession(_ id: String, persist: Bool = true) {
        let fm = FileManager.default
        let dir = sampleSessionDirectory(id)
        guard let data = try? Data(contentsOf: dir.appending(path: "doc.json")),
              let saved = try? JSONDecoder().decode(NotebookDocument.self, from: data) else { return }
        for (target, source) in [(drawingsDirectory, "drawings"), (syncBaselineDirectory, "baseline")] {
            for file in sessionFiles(of: saved.id, in: target) { try? fm.removeItem(at: file) }
            for file in (try? fm.contentsOfDirectory(at: dir.appending(path: source), includingPropertiesForKeys: nil)) ?? [] {
                try? fm.copyItem(at: file, to: target.appending(path: file.lastPathComponent))
            }
        }
        let package = corePackagesDirectory.appending(path: "\(saved.id.lowercased()).padnote")
        let savedPackage = dir.appending(path: "package.padnote")
        if fm.fileExists(atPath: savedPackage.path) {
            try? fm.removeItem(at: package)
            try? fm.copyItem(at: savedPackage, to: package)
        }
        if let index = notebooks.firstIndex(where: { $0.id == id }) {
            notebooks[index] = saved
        }
        PageThumbnailRenderer.invalidateAll()
        if persist {
            persistData(signalsLocalEdit: false)
        }
    }

    /// 一本筆記在某個目錄裡的逐頁檔案（`<id>_p…`）。
    private func sessionFiles(of id: String, in directory: URL) -> [URL] {
        let prefixes = Set([id, id.lowercased()].map { "\($0)_p" })
        return ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { file in prefixes.contains { file.lastPathComponent.hasPrefix($0) } }
    }

    /// 使用者會改的內容的指紋：物件、文字、紙張、圖層、勾選項，以及每一頁筆畫的身分。
    ///
    /// **不比**修改時間、背景手寫辨識（`recognizedText`）、頁面 id 與舊版的頁面資料 ——
    /// 那些只是瀏覽就會被系統寫入。筆畫比身分而不是檔案位元組：同一份筆跡重新存檔，位元組可能不同。
    func sampleContentFingerprint(_ doc: NotebookDocument) -> String {
        struct Content: Encodable {
            let title: String
            let pageCount: Int
            let template: String
            let pagePaperIds: [String]?
            let pageFormatId: String?
            let guidePaletteId: String?
            let attachments: [NoteImageAttachment]?
            let textAttachments: [NoteTextAttachment]?
            let linkAttachments: [NoteLinkAttachment]?
            let model3DAttachments: [Note3DAttachment]?
            let commentPins: [NoteCommentPin]?
            let shapeAttachments: [NoteShapeAttachment]?
            let connectionAttachments: [NoteConnectionAttachment]?
            let tableAttachments: [NoteTableAttachment]?
            let audioAttachments: [NoteAudioAttachment]?
            let tapeAttachments: [NoteTapeAttachment]?
            let stickyAnchors: [StickyAnnotationAnchor]?
            let checkedGuideItems: [String: Bool]?
            let objectOrderByPage: [String: [String]]?
            let underInkObjectIdsByPage: [String: [String]]?
            let overInkObjectIdsByPage: [String: [String]]?
            let lockedObjectIdsByPage: [String: [String]]?
            let ink: [String]
        }
        var ink: [String] = []
        for page in 0 ..< max(doc.pageCount, 1) {
            let strokes = loadDrawing(notebookId: doc.id, pageIndex: page).strokes
                .map { StrokeDelta.Identity($0).key }.sorted()
            let pro = (ProInkStore.load(in: drawingsDirectory, notebookId: doc.id, page: page)
                + ProInkStore.load(in: drawingsDirectory, notebookId: doc.id, page: page, foreign: true))
                .map(\.contentKey).sorted()
            ink.append("\(page):" + strokes.joined(separator: ",") + "|" + pro.joined(separator: ","))
        }
        let content = Content(
            title: doc.title, pageCount: doc.pageCount, template: doc.template.rawValue,
            pagePaperIds: doc.pagePaperIds, pageFormatId: doc.pageFormatId, guidePaletteId: doc.guidePaletteId,
            attachments: doc.attachments, textAttachments: doc.textAttachments, linkAttachments: doc.linkAttachments,
            model3DAttachments: doc.model3DAttachments, commentPins: doc.commentPins,
            shapeAttachments: doc.shapeAttachments, connectionAttachments: doc.connectionAttachments,
            tableAttachments: doc.tableAttachments, audioAttachments: doc.audioAttachments,
            tapeAttachments: doc.tapeAttachments, stickyAnchors: doc.stickyAnchors,
            checkedGuideItems: doc.checkedGuideItems, objectOrderByPage: doc.objectOrderByPage,
            underInkObjectIdsByPage: doc.underInkObjectIdsByPage,
            overInkObjectIdsByPage: doc.overInkObjectIdsByPage,
            lockedObjectIdsByPage: doc.lockedObjectIdsByPage, ink: ink)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(content)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 設定或解除「範例」。解除之後就是一般筆記本（照常編輯、照常同步）。
    func setSampleFlag(_ id: String, isSample: Bool) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        // 解除時若正好還有暫存（理論上不會：範例開著時無法從首頁操作），保留目前內容。
        if !isSample, hasSampleSession(id) { finishSampleSession(id, choice: .keep) }
        notebooks[index].sampleFlag = isSample
        notebooks[index].lastModifiedDate = Date()
        markDirtyAndPersist(signalsLocalEdit: true)
    }

    /// 由範例另存出來的筆記本名稱：「範例名 日期 時:分:秒」。
    static func sampleCopyTitle(base: String, at date: Date = Date()) -> String {
        "\(base) \(LocalizationManager.formatted(date, date: .numeric, time: .standard))"
    }

    /// 更新程式或修復時重設範例：範例裡若有使用者的內容（舊版範例可以直接編輯），先另存成一般筆記本，
    /// 範例才重設。跟標準內容一樣（使用者沒動過）的就不另存。只動範例自己，使用者的筆記本與資料夾一律不碰。
    func restoreSamplePreservingUserContent(_ id: String) {
        guard let original = notebooks.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }),
              NotebookPackageBridge.isDeviceLocalSeed(original.id) else { return }
        let hadRecordings = recordings.contains {
            $0.linkedNotebookId?.caseInsensitiveCompare(original.id) == .orderedSame
        }
        let copy = copySample(original)
        restoreSampleToStandard(original.id)
        guard let copy else { return }
        let fresh = notebooks.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
        if !hadRecordings, let fresh, sampleContentSignature(copy) == sampleContentSignature(fresh) {
            discardSampleCopy(copy.id)
        } else {
            adoptSampleCopy(copy, from: original.id)
        }
    }

    /// 比對「有沒有使用者的內容」用的摘要：頁數、各種物件的數量、所有文字、每頁筆畫數。
    /// 物件 id 每次產生都不同，所以不比 id、只比內容。
    func sampleContentSignature(_ doc: NotebookDocument) -> String {
        var parts = ["pages:\(doc.pageCount)"]
        var counts: [Int] = []
        counts.append(doc.attachments?.count ?? 0)
        counts.append(doc.textAttachments?.count ?? 0)
        counts.append(doc.tableAttachments?.count ?? 0)
        counts.append(doc.shapeAttachments?.count ?? 0)
        counts.append(doc.connectionAttachments?.count ?? 0)
        counts.append(doc.linkAttachments?.count ?? 0)
        counts.append(doc.model3DAttachments?.count ?? 0)
        counts.append(doc.audioAttachments?.count ?? 0)
        counts.append(doc.commentPins?.count ?? 0)
        counts.append(doc.tapeAttachments?.count ?? 0)
        counts.append(doc.stickyAnchors?.count ?? 0)
        parts.append("counts:" + counts.map(String.init).joined(separator: ","))
        parts.append("texts:" + (doc.textAttachments ?? []).map(\.text).sorted().joined(separator: "\u{1F}"))
        parts.append("labels:" + (doc.shapeAttachments ?? []).map(\.label).sorted().joined(separator: "\u{1F}"))
        for page in 0 ..< max(doc.pageCount, 1) {
            let ink = loadDrawing(notebookId: doc.id, pageIndex: page).strokes.count
            let pro = ProInkStore.load(in: drawingsDirectory, notebookId: doc.id, page: page).count
            parts.append("ink\(page):\(ink)+\(pro)")
        }
        return parts.joined(separator: "|")
    }

    /// 把範例目前的樣子複製成一本新的（文件、筆跡、套件、錄音）。還沒放進清單、也還沒記進同步索引。
    private func copySample(_ original: NotebookDocument) -> NotebookDocument? {
        let newId = UUID().uuidString.lowercased()

        // 1. 文件：所有欄位照抄，只換 id 與名字（名字固定下來，不再隨語系翻譯）。
        guard var json = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(original))) as? [String: Any]
        else { return nil }
        json["id"] = newId
        json["title"] = Self.sampleCopyTitle(base: original.baseDisplayTitle())
        json.removeValue(forKey: "titleKey")
        // 另存出來的是一般筆記本：不繼承「範例」標記（新 id 不是內建範例，沒有標記就不是範例）。
        json.removeValue(forKey: "sampleFlag")
        // 操作（編輯）範例後生成的副本，一律歸納於「未分類筆記」，不直接放在該範例的資料夾中
        json.removeValue(forKey: "folderId")
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              var copy = try? JSONDecoder().decode(NotebookDocument.self, from: data) else { return nil }
        copy.folderId = nil
        copy.createdAt = Date()
        copy.lastModifiedDate = Date()
        let pageCount = max(copy.pageCount, 1)
        // 頁面 id 要明確寫進新的那一本：留空的話匯出時才補，各台補的不一樣。
        copy.pageIds = NotebookPackageBridge.alignedPageIds(
            original.pageIds ?? NotebookPackageBridge.deterministicSeedPageIds(for: original.id),
            count: pageCount, package: nil, notebookId: newId)

        // 2. 筆跡（含專業筆刷檔）：`<id>_p…` 全部複製一份到新 id 底下。
        let fm = FileManager.default
        let prefixes = Set([original.id, original.id.lowercased()].map { "\($0)_p" })
        for file in (try? fm.contentsOfDirectory(at: drawingsDirectory, includingPropertiesForKeys: nil)) ?? [] {
            let name = file.lastPathComponent
            for prefix in prefixes where name.hasPrefix(prefix) {
                let remainder = name.dropFirst(prefix.count)
                let renamed = "\(newId)_p" + remainder
                try? fm.copyItem(at: file, to: drawingsDirectory.appending(path: renamed))
                break
            }
        }

        // 複本為使用者本地獨立筆記本：若原範例有外來專業筆畫（.proink-foreign），
        // 在新筆記中一律合併為本機自己的筆畫，避免因「外來筆畫」在同步或匯出時被濾除。
        for page in 0..<pageCount {
            let own = ProInkStore.load(in: drawingsDirectory, notebookId: newId, page: page)
            let foreign = ProInkStore.load(in: drawingsDirectory, notebookId: newId, page: page, foreign: true)
            if !foreign.isEmpty {
                ProInkStore.save(own + foreign, in: drawingsDirectory, notebookId: newId, page: page)
                try? fm.removeItem(at: drawingsDirectory.appending(path: "\(newId)_p\(page).proink-foreign.json"))
            }
        }

        // 讀取筆跡資料與附件圖片以供完整匯出
        let drawings = (0..<pageCount).map { loadDrawing(notebookId: newId, pageIndex: $0) }
        let pro = (0..<pageCount).map { ProInkStore.load(in: drawingsDirectory, notebookId: newId, page: $0) }
        let ledgers = (0..<pageCount).map { ProInkStore.loadLedger(in: drawingsDirectory, notebookId: newId, page: $0) }
        copy.pagesData = drawings.map { $0.dataRepresentation() }

        var images: [String: Data] = [:]
        for attachment in copy.attachments ?? [] {
            let url = attachmentsDirectory.appending(path: attachment.fileName)
            if let bytes = try? Data(contentsOf: url) {
                images[attachment.fileName] = bytes
            }
        }

        // 讀取原範例中的錄音標題（若有）
        var recTitles: [String: String] = [:]
        for name in [original.id, original.id.lowercased()] {
            let pkg = corePackagesDirectory.appending(path: "\(name).padnote")
            if fm.fileExists(atPath: pkg.path) {
                recTitles = Self.packageRecordingTitles(packageURL: pkg, deviceId: NotebookMigration.deviceId)
                if !recTitles.isEmpty { break }
            }
        }

        // 3. 套件：以工作副本匯出一份完整的核心套件（包含向量手繪、專業筆刷、圖片與物件中繼）。
        let newPackage = corePackagesDirectory.appending(path: "\(newId).padnote")
        try? NotebookPackageBridge.export(
            document: copy,
            drawings: drawings,
            imageData: images,
            to: newPackage,
            deviceId: NotebookMigration.deviceId,
            pageIds: copy.pageIds,
            proStrokes: pro,
            proLedgers: ledgers,
            recordingTitles: recTitles
        )

        // 範例套件裡的錄音（使用者在範例裡錄的）一起帶過去。
        for name in [original.id, original.id.lowercased()] {
            let audio = corePackagesDirectory.appending(path: "\(name).padnote/media/audio")
            guard let files = try? fm.contentsOfDirectory(at: audio, includingPropertiesForKeys: nil) else { continue }
            let target = newPackage.appending(path: "media/audio")
            try? fm.createDirectory(at: target, withIntermediateDirectories: true)
            for file in files where !fm.fileExists(atPath: target.appending(path: file.lastPathComponent).path) {
                try? fm.copyItem(at: file, to: target.appending(path: file.lastPathComponent))
            }
        }

        // 建立同步基準與快照，保證工作副本與套件一致，避免同步誤判為需要反向覆蓋。
        ObjectLedger.save(copy, in: syncBaselineDirectory)
        for page in 0..<pageCount {
            PKInkSnapshotStore.save(drawings[page], in: drawingsDirectory, notebookId: newId, page: page)
        }
        let now = Date()
        copy.lastModifiedDate = now
        let manifestUrl = newPackage.appending(path: "manifest.json")
        try? fm.setAttributes([.modificationDate: now], ofItemAtPath: manifestUrl.path)
        try? fm.setAttributes([.modificationDate: now], ofItemAtPath: newPackage.path)

        return copy
    }

    /// 複本正式成為一本一般筆記本：放在最前面、記進同步索引（一律歸納於「未分類筆記」）、錄音改指到它。
    private func adoptSampleCopy(_ copy: NotebookDocument, from sampleId: String) {
        for r in recordings.indices where recordings[r].linkedNotebookId?.caseInsensitiveCompare(sampleId) == .orderedSame {
            recordings[r].linkedNotebookId = copy.id
        }
        var targetCopy = copy
        targetCopy.folderId = nil
        notebooks.insert(targetCopy, at: 0)
        AccountSyncStore.shared.record(id: targetCopy.id, title: targetCopy.title, parentId: nil, isFolder: false)
    }

    /// 用不到的複本（範例本來就是標準內容）：磁碟上的檔案清掉。
    private func discardSampleCopy(_ id: String) {
        let fm = FileManager.default
        try? fm.removeItem(at: corePackagesDirectory.appending(path: "\(id.lowercased()).padnote"))
        for file in sessionFiles(of: id, in: drawingsDirectory) { try? fm.removeItem(at: file) }
        for file in sessionFiles(of: id, in: syncBaselineDirectory) { try? fm.removeItem(at: file) }
    }
}

// MARK: - 同步膨脹出來的空白頁

extension NotebookStore {
    /// 已經檢查過的筆記本（一本只修一次）。
    static let phantomPagesRepairedKey = "sync.phantomPagesRepaired.v2"

    /// 一次性修復：清掉舊版同步膨脹出來的空白頁。
    ///
    /// 舊版匯出時，筆記沒有記頁面 id 的話由核心隨機發 id，每台裝置、每一輪各發一批；
    /// 合併後頁數是各台的總和（使用者回報：3 頁的筆記變 30、48 頁）。根因已經修掉
    /// （`NotebookPackageBridge.fallbackPageId`），這裡清理已經長出來的那些。
    ///
    /// 只刪**同時符合**下列條件的頁，寧可少刪：
    /// - 完全空白：沒有筆跡（含專業筆刷、別台的）、沒有任何物件；
    /// - id 是核心隨機發的（UUID 第 7 版）或舊版升格重複產生的決定性 id —— 這台使用者自己加的頁是第 4 版；
    /// - 夾在內容頁之間，或結尾連續膨脹出 2 頁以上的空白頁（單獨一頁結尾空白很可能是故意留的）；
    /// - 這樣的頁至少兩頁（單獨一頁空白很可能是故意的）。
    /// 刪除走 `deletePage`，所以會寫成 `RemovePage` 同步到別台。
    @discardableResult
    func repairPhantomPagesIfNeeded() -> Bool {
        var repaired = Set(ProfileDefaults.current.stringArray(forKey: Self.phantomPagesRepairedKey) ?? [])
        let inbox = recordingInboxNotebookId()
        var changed = false
        for notebook in notebooks {
            let key = notebook.id.lowercased()
            guard !repaired.contains(key) else { continue }
            repaired.insert(key)
            guard !NotebookPackageBridge.isDeviceLocalSeed(notebook.id),
                  notebook.id.caseInsensitiveCompare(inbox) != .orderedSame,
                  notebook.pageCount > 2
            else { continue }
            let phantoms = phantomPageIndexes(of: notebook)
            guard phantoms.count >= 2 else { continue }
            for index in phantoms.sorted(by: >) {
                _ = deletePage(notebookId: notebook.id, pageIndex: index, currentIndex: 0)
            }
            changed = true
        }
        ProfileDefaults.current.set(Array(repaired).sorted(), forKey: Self.phantomPagesRepairedKey)
        return changed
    }

    /// 符合 `repairPhantomPagesIfNeeded` 條件的頁次。
    func phantomPageIndexes(of notebook: NotebookDocument) -> [Int] {
        let count = notebook.pageCount
        let ids = notebook.pageIds?.count == count
            ? notebook.pageIds!
            : NotebookPackageBridge.resolvedPageIds(for: notebook, packagesDirectory: corePackagesDirectory)
        guard ids.count == count else { return [] }
        let empty = (0 ..< count).map { isBlankPage(notebook, index: $0) }
        guard let lastContent = empty.lastIndex(of: false) else { return [] }
        var result = (0 ..< lastContent).filter { index in
            empty[index] && Self.isCoreMintedPageId(ids[index])
        }
        // 若最後一個有內容頁面之後還拖著 2 頁以上的空白頁，且其頁面 ID 屬於同步產物
        // （UUID v7 或 fallbackPageId UUID v5），一併納入清理（例如「課堂與會議記錄」膨脹到 48 頁）。
        // 若結尾只有 1 頁空白（或使用者手動新增的 UUID v4 頁），則完整保留。
        let trailingRange = (lastContent + 1) ..< count
        if trailingRange.count >= 2 {
            let trailingPhantoms = trailingRange.filter { index in
                guard empty[index] else { return false }
                let id = ids[index]
                let fallback = NotebookPackageBridge.fallbackPageId(notebookId: notebook.id, index: index)
                return Self.isCoreMintedPageId(id) || id.caseInsensitiveCompare(fallback) == .orderedSame
            }
            if trailingPhantoms.count >= 2 {
                result.append(contentsOf: trailingPhantoms)
            }
        }
        return result
    }

    /// 核心 `addPage` 發的 id 是 UUID 第 7 版（時間排序）。
    static func isCoreMintedPageId(_ id: String) -> Bool {
        let chars = Array(id.lowercased())
        return chars.count == 36 && chars[14] == "7"
    }

    func isBlankPage(_ notebook: NotebookDocument, index: Int) -> Bool {
        func none<T: PageIndexed>(_ items: [T]?) -> Bool {
            !(items ?? []).contains { $0.pageIndex == index }
        }
        guard none(notebook.attachments), none(notebook.textAttachments), none(notebook.linkAttachments),
              none(notebook.model3DAttachments), none(notebook.commentPins), none(notebook.audioAttachments),
              none(notebook.tableAttachments), none(notebook.shapeAttachments),
              none(notebook.connectionAttachments), none(notebook.tapeAttachments), none(notebook.stickyAnchors)
        else { return false }
        guard loadDrawing(notebookId: notebook.id, pageIndex: index).strokes.isEmpty else { return false }
        return ProInkStore.load(in: drawingsDirectory, notebookId: notebook.id, page: index).isEmpty
            && ProInkStore.load(in: drawingsDirectory, notebookId: notebook.id, page: index, foreign: true).isEmpty
    }
}


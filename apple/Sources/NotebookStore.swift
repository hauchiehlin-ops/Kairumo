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
public struct FolderItem: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var parentId: String? // nil 代表位於最上層根目錄下
    public var createdAt: Date
    public var colorHex: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        parentId: String? = nil,
        createdAt: Date = Date(),
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = createdAt
        self.colorHex = colorHex
    }
}

/// 筆記文件本機模型
public struct NotebookDocument: Identifiable, Codable, Hashable {
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
    public nonisolated mutating func padPagePaperIds(to count: Int) {
        var ids = pagePaperIds ?? []
        while ids.count < count { ids.append(template.paperId) }
        pagePaperIds = ids
    }

    /// 顯示用標題：系統預設標題會跟著介面語言走。
    @MainActor
    public func displayTitle(_ l10n: LocalizationManager = .shared) -> String {
        guard let key = titleKey else { return title }
        return l10n.localized(key)
    }

    /// 顯示用摘要，語意同 `displayTitle`。
    @MainActor
    public func displaySnippet(_ l10n: LocalizationManager = .shared) -> String? {
        if let key = snippetKey { return l10n.localized(key) }
        return previewSnippet
    }

    /// 頁面高度。**固定值** —— 每一頁都一樣高。
    ///
    /// 舊版可以任意延長頁面，於是同一本筆記裡每頁高度都不同，匯出與列印無從
    /// 對齊紙張。現在高度由 `PageGeometry` 決定；`pageHeights` 這個欄位只為了
    /// 舊檔解碼而保留，遷移時用來判斷哪些頁需要重新分頁（見 `PageRepagination`）。
    /// 這一本筆記的頁面尺寸。
    public var pageSize: CGSize { PageGeometry.size(forFormat: pageFormatId) }

    public func height(forPage pageIndex: Int, defaultHeight: CGFloat = PageGeometry.height) -> CGFloat {
        PageGeometry.height
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
        audioAttachments: [NoteAudioAttachment]? = []
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

    public init(
        id: String = UUID().uuidString,
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
        chartSpecJSON: String? = nil
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
        id: String = UUID().uuidString,
        pageIndex: Int = 0,
        title: String = "3D 幾何模型",
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
        cornerRadius: CGFloat = 12
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.title = title
        self.modelTypeRaw = modelTypeRaw
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

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int = 0,
        text: String = "請在此輸入文字...",
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
        id: String = UUID().uuidString,
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
        id: String = UUID().uuidString,
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
        id: String = UUID().uuidString,
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
        id: String = UUID().uuidString,
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
public struct AudioRecordingRecord: Identifiable, Codable, Hashable {
    public let id: String
    public var title: String
    public var durationSeconds: Int
    public var recordedDate: Date
    public var transcriptionStatus: String
    public var isTranscribed: Bool
    public var fileName: String
    public var linkedNotebookId: String?

    public init(
        id: String = UUID().uuidString,
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

    public init(
        id: String = UUID().uuidString,
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
        backgroundColorHex: String? = nil
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
    }
}

/// 筆記資料持久化中樞
@MainActor
public final class NotebookStore: ObservableObject {
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
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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

    private init() {
        StartupLogger.log("NotebookStore.init 開始載入資料")
        documentsRootOverride = nil
        loadData()
        if notebooks.isEmpty {
            StartupLogger.log("NotebookStore: 建立預設種子筆記")
            seedDefaultNotebooks()
        } else {
            StartupLogger.log("NotebookStore: 檢查/回填種子筆記")
            backfillEmptySeedNotebooks()
        }
        StartupLogger.log("NotebookStore.init 初始化完成")
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
        }

        if let savedRoot = UserDefaults.standard.string(forKey: rootFolderNameKey),
           !savedRoot.isEmpty,
           !Self.legacyDefaultRootNames.contains(savedRoot) {
            self.rootFolderName = savedRoot
        }
        StartupLogger.log("NotebookStore.loadData 完成: \(self.notebooks.count) 本筆記, \(self.recordings.count) 則錄音, \(self.folders.count) 個資料夾")
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
        LocalizationManager.shared.localized("sample_lectures"): ("seed_meeting_title", "seed_meeting_snippet")
    ]

    private func migrateSeedTitles(_ doc: NotebookDocument) -> NotebookDocument {
        guard doc.titleKey == nil, let keys = Self.legacySeedTitles[doc.title] else { return doc }
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
    private func backfillEmptySeedNotebooks() {
        var changed = false
        for index in notebooks.indices {
            guard let key = notebooks[index].titleKey,
                  key == "seed_welcome_title" || key == "seed_meeting_title",
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
                SeedContent.fillWelcome(&notebooks[index], store: self)
            } else {
                SeedContent.fillMeeting(&notebooks[index], store: self)
            }
            changed = true
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

        // 解不開的筆跡資料當成「有東西」。判斷不出來就不要動它。
        return doc.pagesData.allSatisfy { data in
            guard let drawing = try? PKDrawing(data: data) else { return false }
            return drawing.strokes.isEmpty
        }
    }

    public func persistData() {
        // 快照必須在主執行緒取得：這些陣列是 @MainActor 隔離的狀態。
        let snapshot = (notebooks: notebooks, recordings: recordings, folders: folders)
        let rootName = rootFolderName
        let files = (notebooks: notebooksFile, recordings: recordingsFile, folders: foldersFile)
        let key = rootFolderNameKey

        guard !pendingWrite else { return }
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
            UserDefaults.standard.set(rootName, forKey: key)

            Task { @MainActor in
                guard let self else { return }
                self.pendingWrite = false
                // 寫檔期間若又有變更，補寫最後一版，否則會漏掉結尾的編輯。
                if self.needsAnotherWrite {
                    self.needsAnotherWrite = false
                    self.persistData()
                    return
                }
                // 落盤完成才通知同步。**順序不能顛倒**：先通知的話，
                // 同步可能讀到還沒寫完的檔案。
                //
                // 這是去抖動的觸發 —— 使用者還在寫字時每一筆都推只是浪費電，
                // 排程器會等他停手 1.5 秒。
                AutoSyncController.shared.noteLocalEdit()
            }
        }
    }

    /// 寫檔進行中又收到新變更的標記。
    private var needsAnotherWrite: Bool = false

    /// 標記資料已變更並排程落盤。寫檔進行中則記下，待目前這次寫完再補一次。
    public func markDirtyAndPersist() {
        if pendingWrite {
            needsAnotherWrite = true
        } else {
            persistData()
        }
    }

    /// 專屬畫布筆畫向量二進位儲存目錄
    public var drawingsDirectory: URL {
        let dir = documentsDir.appendingPathComponent("Drawings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 即時自動儲存單頁手繪內容
    public func saveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing) {
        let fileUrl = drawingsDirectory.appending(path: "\(notebookId)_p\(pageIndex).drawing")
        let data = drawing.dataRepresentation()
        try? data.write(to: fileUrl, options: .atomic)
    }

    /// 讀取單頁手繪內容
    public func loadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing {
        let fileUrl = drawingsDirectory.appending(path: "\(notebookId)_p\(pageIndex).drawing")
        if let data = try? Data(contentsOf: fileUrl), let d = try? PKDrawing(data: data) {
            return d
        }
        return PKDrawing()
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
        let device = NotebookMigration.deviceId
        if let existing = try? PadnoteSession.openExisting(path: path.path, deviceId: device) {
            return existing
        }
        let now = UInt64(max(0, Date().timeIntervalSince1970 * 1000))
        return try? PadnoteSession.create(
            path: path.path, title: title, nowUnixMs: now, deviceId: device)
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
        markDirtyAndPersist()
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

    private func seedDefaultNotebooks() {
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

        n1.titleKey = "seed_welcome_title"
        n1.snippetKey = "seed_welcome_snippet"
        n2.titleKey = "seed_meeting_title"
        n2.snippetKey = "seed_meeting_snippet"

        // 兩本範例筆記原本都只有空白頁。「示範」什麼都不示範的話，
        // 使用者第一次打開看到的是一片白 —— 那比沒有範例還糟，
        // 因為他會以為這個 App 只能手寫。
        SeedContent.fillWelcome(&n1, store: self)
        SeedContent.fillMeeting(&n2, store: self)

        self.notebooks = [n1, n2]
        persistData()
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
                Date().formatted(date: .abbreviated, time: .shortened)),
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

    public func updateNotebook(_ doc: NotebookDocument) {
        if let idx = notebooks.firstIndex(where: { $0.id == doc.id }) {
            let previous = notebooks[idx]
            var updated = doc
            updated.lastModifiedDate = Date()
            notebooks[idx] = updated
            // 只有**中繼資料**變了才記進同步索引。每次存檔都記的話，
            // 寫一筆字就會把這本筆記的時戳往前推，於是它永遠贏過另一台裝置
            // 對同一本筆記的改名 —— 而那次改名其實比較晚。
            if previous.title != updated.title || previous.folderId != updated.folderId {
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
    public func upsertNotebook(_ doc: NotebookDocument) {
        if let index = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(doc.id) == .orderedSame }) {
            notebooks[index] = doc
        } else {
            notebooks.append(doc)
        }
        markDirtyAndPersist()
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
        let document = imported.document
        upsertNotebook(document)
        AccountSyncStore.shared.record(
            id: newId, title: document.title, parentId: document.folderId, isFolder: false)
        return document
    }

    public func deleteNotebook(id: String) {
        notebooks.removeAll { $0.id.caseInsensitiveCompare(id) == .orderedSame }
        AccountSyncStore.shared.recordDeletion(id: id)
        let pkgDir = corePackagesDirectory.appending(path: "\(id).padnote")
        try? FileManager.default.removeItem(at: pkgDir)
        let lowerPkgDir = corePackagesDirectory.appending(path: "\(id.lowercased()).padnote")
        try? FileManager.default.removeItem(at: lowerPkgDir)
        let baseDir = documentsDirectory.appending(path: "SyncBaseline/\(id).padnote")
        try? FileManager.default.removeItem(at: baseDir)
        let lowerBaseDir = documentsDirectory.appending(path: "SyncBaseline/\(id.lowercased()).padnote")
        try? FileManager.default.removeItem(at: lowerBaseDir)
        if let cloudFolder = CloudSyncFolder.resolveFolder() {
            let scoped = cloudFolder.startAccessingSecurityScopedResource()
            defer { if scoped { cloudFolder.stopAccessingSecurityScopedResource() } }
            let remotePkg = cloudFolder.appending(path: "\(id).padnote")
            try? FileManager.default.removeItem(at: remotePkg)
            let lowerRemotePkg = cloudFolder.appending(path: "\(id.lowercased()).padnote")
            try? FileManager.default.removeItem(at: lowerRemotePkg)
        }
        persistData()
    }

    /// 依據同步收斂後的刪除墓碑名單，清理本機中已在其他裝置被刪除的筆記本實體。
    public func syncPurgeDeletedNotebooks(_ deletedIds: Set<String>) {
        guard !deletedIds.isEmpty else { return }
        let lowercasedDeleted = Set(deletedIds.map { $0.lowercased() })
        let beforeCount = notebooks.count
        notebooks.removeAll { lowercasedDeleted.contains($0.id.lowercased()) }
        for id in deletedIds {
            let lowerId = id.lowercased()
            let pkgDir = corePackagesDirectory.appending(path: "\(lowerId).padnote")
            try? FileManager.default.removeItem(at: pkgDir)
            let origPkgDir = corePackagesDirectory.appending(path: "\(id).padnote")
            try? FileManager.default.removeItem(at: origPkgDir)
            let baseDir = documentsDirectory.appending(path: "SyncBaseline/\(lowerId).padnote")
            try? FileManager.default.removeItem(at: baseDir)
            let origBaseDir = documentsDirectory.appending(path: "SyncBaseline/\(id).padnote")
            try? FileManager.default.removeItem(at: origBaseDir)
            if let cloudFolder = CloudSyncFolder.resolveFolder() {
                let scoped = cloudFolder.startAccessingSecurityScopedResource()
                defer { if scoped { cloudFolder.stopAccessingSecurityScopedResource() } }
                let remotePkg = cloudFolder.appending(path: "\(lowerId).padnote")
                try? FileManager.default.removeItem(at: remotePkg)
                let origRemotePkg = cloudFolder.appending(path: "\(id).padnote")
                try? FileManager.default.removeItem(at: origRemotePkg)
            }
        }
        if notebooks.count != beforeCount {
            persistData()
        }
    }

    public func duplicateNotebook(id: String) {
        guard let original = notebooks.first(where: { $0.id == id }) else { return }
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
    }

    public func renameNotebook(id: String, newTitle: String) {
        guard let idx = notebooks.firstIndex(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else { return }
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            notebooks[idx].title = clean
            // 使用者親自命名之後就不再翻譯，否則改了名字又被語系蓋回去。
            notebooks[idx].titleKey = nil
            notebooks[idx].lastModifiedDate = Date()
            AccountSyncStore.shared.record(
                id: notebooks[idx].id,
                title: notebooks[idx].title,
                parentId: notebooks[idx].folderId,
                isFolder: false
            )
            persistData()
        }
    }

    // MARK: - 資料夾管理 CRUD

    @discardableResult
    public func createFolder(name: String, parentId: String? = nil, colorHex: String? = nil) -> FolderItem {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新增資料夾" : name
        let folder = FolderItem(name: cleanName, parentId: parentId, colorHex: colorHex)
        folders.append(folder)
        AccountSyncStore.shared.record(
            id: folder.id,
            title: cleanName,
            parentId: parentId,
            isFolder: true
        )
        persistData()
        return folder
    }

    public func renameFolder(id: String, newName: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            folders[idx].name = clean
            AccountSyncStore.shared.record(
                id: id,
                title: clean,
                parentId: folders[idx].parentId,
                isFolder: true
            )
            persistData()
        }
    }

    public func deleteFolder(id: String) {
        // 將該資料夾內的筆記安全移回其父資料夾（若無父資料夾則移回根目錄 nil）
        let targetFolder = folders.first(where: { $0.id == id })
        let fallbackParentId = targetFolder?.parentId
        // 每一個被搬出來的項目都要記進索引 —— 只記「資料夾刪了」的話，
        // 另一台裝置合併之後會依照核心的規則把裡面的東西一起隱藏
        // （已刪資料夾底下的項目不顯示），而它們在這台其實已經搬到外面了。
        for i in 0..<notebooks.count {
            if notebooks[i].folderId == id {
                notebooks[i].folderId = fallbackParentId
                AccountSyncStore.shared.record(
                    id: notebooks[i].id,
                    title: notebooks[i].title,
                    parentId: fallbackParentId,
                    isFolder: false
                )
            }
        }
        // 將該資料夾底下的子資料夾提升至父資料夾
        for i in 0..<folders.count {
            if folders[i].parentId == id {
                folders[i].parentId = fallbackParentId
                AccountSyncStore.shared.record(
                    id: folders[i].id,
                    title: folders[i].name,
                    parentId: fallbackParentId,
                    isFolder: true
                )
            }
        }
        folders.removeAll { $0.id == id }
        AccountSyncStore.shared.recordDeletion(id: id)
        persistData()
    }

    public func renameRootFolder(newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            rootFolderName = clean
            persistData()
        }
    }

    public func moveNotebook(id: String, toFolderId: String?) {
        guard let idx = notebooks.firstIndex(where: { $0.id == id }) else { return }
        notebooks[idx].folderId = toFolderId
        notebooks[idx].lastModifiedDate = Date()
        AccountSyncStore.shared.record(
            id: id,
            title: notebooks[idx].title,
            parentId: toFolderId,
            isFolder: false
        )
        persistData()
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

    public func subfolders(of parentId: String?) -> [FolderItem] {
        folders.filter { $0.parentId == parentId && !isHiddenBySync($0.id) }
    }

    public func notebooks(in folderId: String?) -> [NotebookDocument] {
        notebooks.filter { $0.folderId == folderId && !isHiddenBySync($0.id) }
    }

    /// 清單要顯示的筆記本。**不要用 `notebooks`** —— 那一份是真相來源，
    /// 編輯器靠它找得到目前開著的那一本，過濾掉會讓正在編輯的筆記消失。
    public var visibleNotebooks: [NotebookDocument] {
        notebooks.filter { !isHiddenBySync($0.id) }
    }

    // MARK: - 集中單一事實分頁管理 (Atomic Page Management)

    /// 為指定筆記安全原子新增下一頁，回傳新頁碼 index
    @discardableResult
    public func addPage(notebookId: String, paperId: String? = nil) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return 0 }
        let oldPageCount = max(1, notebooks[idx].pageCount)
        let newPageCount = oldPageCount + 1
        notebooks[idx].pageCount = newPageCount

        // 確保 pageHeights 陣列長度對齊
        var heights = notebooks[idx].pageHeights ?? Array(repeating: 1800.0, count: oldPageCount)
        while heights.count < newPageCount {
            heights.append(1800.0)
        }
        notebooks[idx].pageHeights = heights
        // 逐頁樣板也要跟著長一格，否則新頁在陣列裡取不到、退回整本的樣板 ——
        // 那在「這一頁想用別的格式」之後就是錯的。
        notebooks[idx].padPagePaperIds(to: oldPageCount)
        notebooks[idx].pagePaperIds?.append(paperId ?? notebooks[idx].template.paperId)
        notebooks[idx].lastModifiedDate = Date()

        let newPageIndex = newPageCount - 1
        // 儲存空白筆跡至磁碟
        saveDrawing(notebookId: notebookId, pageIndex: newPageIndex, drawing: PKDrawing())
        persistData()
        return newPageIndex
    }

    /// 在指定頁面後方插入新頁面，平移後續頁面並回傳新插入頁面之 pageIndex
    @discardableResult
    public func insertPage(notebookId: String, afterIndex: Int, paperId: String? = nil) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return 0 }
        let oldPageCount = max(1, notebooks[idx].pageCount)
        let newPageCount = oldPageCount + 1
        let insertIndex = min(max(0, afterIndex + 1), oldPageCount)

        // 從最後一頁往前平移圖檔
        var p = oldPageCount - 1
        while p >= insertIndex {
            let existingDrawing = loadDrawing(notebookId: notebookId, pageIndex: p)
            saveDrawing(notebookId: notebookId, pageIndex: p + 1, drawing: existingDrawing)
            p -= 1
        }
        // 將新插入的一頁設為空白
        saveDrawing(notebookId: notebookId, pageIndex: insertIndex, drawing: PKDrawing())

        // 更新 pageHeights
        var heights = notebooks[idx].pageHeights ?? Array(repeating: 1800.0, count: oldPageCount)
        while heights.count < oldPageCount {
            heights.append(1800.0)
        }
        heights.insert(1800.0, at: insertIndex)
        notebooks[idx].pageHeights = heights

        notebooks[idx].padPagePaperIds(to: oldPageCount)
        notebooks[idx].pagePaperIds?.insert(
            paperId ?? notebooks[idx].template.paperId,
            at: min(insertIndex, notebooks[idx].pagePaperIds?.count ?? 0))

        // 每一種附件都要重新對齊頁碼。
        //
        // **表格、形狀、連接線與錄音原本整組漏掉了** —— 與刪除頁面同一個
        // 病灶：前面那幾種各自手寫一份「插入點之後的往後移一格」，新增型別
        // 時沒有人回來補。症狀是「我在第 1 頁後面插了一頁，第 2 頁的表格
        // 留在原地，現在它落在那張新的空白頁上」。
        //
        // 算術在核心（`pageIndexAfterInsert`），這裡只負責把每一種餵進去。
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

        // 內嵌筆跡陣列也要跟著長一頁，否則 pagesData 與 pageCount 會錯開，
        // 而匯出是看前者的 —— 插入的那一頁在 PDF 裡不存在。
        if insertIndex <= notebooks[idx].pagesData.count {
            notebooks[idx].pagesData.insert(PKDrawing().dataRepresentation(), at: insertIndex)
        }

        notebooks[idx].pageCount = newPageCount
        notebooks[idx].lastModifiedDate = Date()
        persistData()
        return insertIndex
    }

    /// 刪除指定頁面，平移後續頁面並回傳安全之 currentPageIndex
    @discardableResult
    public func deletePage(notebookId: String, pageIndex: Int, currentIndex: Int) -> Int {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return 0 }
        let total = notebooks[idx].pageCount
        guard total > 1, pageIndex >= 0, pageIndex < total else { return currentIndex }

        // 平移磁碟圖檔
        var p = pageIndex
        while p < total - 1 {
            let nextDrawing = loadDrawing(notebookId: notebookId, pageIndex: p + 1)
            saveDrawing(notebookId: notebookId, pageIndex: p, drawing: nextDrawing)
            p += 1
        }
        // 移除最後一頁檔案
        let lastFileUrl = drawingsDirectory.appending(path: "\(notebookId)_p\(total - 1).drawing")
        try? FileManager.default.removeItem(at: lastFileUrl)

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

        // 內嵌的筆跡陣列也要跟著縮短。
        //
        // 不縮的話 `pagesData.count` 會永遠比 `pageCount` 多，而
        // 「這本筆記是不是空的」「匯出幾頁」都在看前者 —— 刪掉的那一頁
        // 會在匯出的 PDF 裡復活。
        if pageIndex < notebooks[idx].pagesData.count {
            notebooks[idx].pagesData.remove(at: pageIndex)
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

        // 1. 筆跡檔案。先把受影響那一段整段讀進來，再照新的順序寫回去 ——
        //    邊讀邊寫會把還沒讀到的那一頁覆蓋掉。
        let touched = pageMoveTouchedRange(from: UInt32(from), to: UInt32(to)).map { Int($0) }
        let loaded = touched.map { loadDrawing(notebookId: notebookId, pageIndex: $0) }
        for (offset, page) in touched.enumerated() {
            let destination = Int(pageIndexAfterMove(index: UInt32(page),
                                                     from: UInt32(from),
                                                     to: UInt32(to)))
            saveDrawing(notebookId: notebookId, pageIndex: destination, drawing: loaded[offset])
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

        notebooks[idx].lastModifiedDate = Date()
        persistData()
        return to
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

            // 1. 筆跡。整頁複製，不是只複製看得見的那一段。
            let drawing = loadDrawing(notebookId: sourceId, pageIndex: from)
            saveDrawing(notebookId: targetId, pageIndex: to, drawing: drawing)

            // 2. 頁高與內嵌筆跡陣列。
            let sourceHeights = notebooks[sourceIdx].pageHeights
            var heights = notebooks[targetIdx].pageHeights
                ?? Array(repeating: 1800.0, count: max(0, notebooks[targetIdx].pageCount))
            while heights.count < to { heights.append(1800.0) }
            heights.append(
                (from < (sourceHeights?.count ?? 0)) ? sourceHeights![from] : 1800.0)
            notebooks[targetIdx].pageHeights = heights

            if from < notebooks[sourceIdx].pagesData.count {
                notebooks[targetIdx].pagesData.append(notebooks[sourceIdx].pagesData[from])
            } else {
                notebooks[targetIdx].pagesData.append(PKDrawing().dataRepresentation())
            }

            // 紙張跟著頁走。不帶的話，一張四象限搬到別本之後會變成那本的
            // 預設紙 —— 使用者搬的是「那一頁」，不是「那一頁上的字」。
            let carried = notebooks[sourceIdx].paperId(forPage: from)
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

        let drawingToCopy = loadDrawing(notebookId: notebookId, pageIndex: pageIndex)

        // 後續頁面往後移動一格
        var p = total
        while p > pageIndex + 1 {
            let prev = loadDrawing(notebookId: notebookId, pageIndex: p - 1)
            saveDrawing(notebookId: notebookId, pageIndex: p, drawing: prev)
            p -= 1
        }
        // 寫入複製內容至 pageIndex + 1
        saveDrawing(notebookId: notebookId, pageIndex: pageIndex + 1, drawing: drawingToCopy)

        // 複製高度
        var heights = notebooks[idx].pageHeights ?? Array(repeating: 1800.0, count: total)
        while heights.count < total { heights.append(1800.0) }
        let copyHeight = heights[pageIndex]
        heights.insert(copyHeight, at: pageIndex + 1)
        notebooks[idx].pageHeights = heights

        // 複本要跟原本那一頁同一種紙 —— 不然「建立此頁副本」會得到一張
        // 版面不一樣的頁。
        let sourcePaper = notebooks[idx].paperId(forPage: pageIndex)
        notebooks[idx].padPagePaperIds(to: total)
        notebooks[idx].pagePaperIds?.insert(
            sourcePaper, at: min(pageIndex + 1, notebooks[idx].pagePaperIds?.count ?? 0))

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
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "語音錄音" : title
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

        if let nId = linkedNotebookId, let idx = notebooks.firstIndex(where: { $0.id == nId }) {
            notebooks[idx].hasRecording = true
            notebooks[idx].recordingAudioPath = fileName
        }
        persistData()
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
    public func recordingFileURL(fileName: String, notebookId: String?) -> URL {
        if let notebookId {
            let inPackage = corePackagesDirectory
                .appending(path: "\(notebookId.lowercased()).padnote")
                .appending(path: "media/audio")
                .appending(path: fileName)
            if FileManager.default.fileExists(atPath: inPackage.path) {
                return inPackage
            }
        }
        return AudioRecorderManager.shared.recordingsDirectory.appending(path: fileName)
    }

    public func recordingFileURL(for record: AudioRecordingRecord) -> URL {
        if let notebookId = record.linkedNotebookId {
            let inPackage = corePackagesDirectory
                .appending(path: "\(notebookId.lowercased()).padnote")
                .appending(path: "media/audio")
                .appending(path: record.fileName)
            if FileManager.default.fileExists(atPath: inPackage.path) {
                return inPackage
            }
        }
        return AudioRecorderManager.shared.recordingsDirectory
            .appending(path: record.fileName)
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
    public func refreshRecordings() {
        let fm = FileManager.default
        var byFileName: [String: AudioRecordingRecord] = [:]
        for rec in recordings {
            byFileName[rec.fileName.lowercased()] = rec
        }

        var scanned: [AudioRecordingRecord] = []
        for doc in notebooks {
            let audioDir = corePackagesDirectory
                .appending(path: "\(doc.id.lowercased()).padnote")
                .appending(path: "media/audio")
            let files = (try? fm.contentsOfDirectory(
                at: audioDir, includingPropertiesForKeys: [.contentModificationDateKey]))?
                .filter { $0.pathExtension.lowercased() == "opus" } ?? []
            for file in files {
                let name = file.lastPathComponent
                if let existing = byFileName[name.lowercased()] {
                    scanned.append(existing)
                    byFileName.removeValue(forKey: name.lowercased())
                    continue
                }
                // 從別台同步過來的：索引裡沒有，要補一筆才看得到。
                // 長度走核心算 —— 兩個平台各自問系統 API 的話，
                // 同一段錄音會顯示不同的秒數，而使用者會以為同步壞了。
                let bytes = (try? Data(contentsOf: file)) ?? Data()
                let seconds = Int(audioDurationSeconds(bytes: bytes))
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? Date()
                let suffix = LocalizationManager.shared.localized("recording_suffix")
                scanned.append(AudioRecordingRecord(
                    title: "\(doc.displayTitle()) \(suffix)",
                    durationSeconds: seconds,
                    recordedDate: modified,
                    fileName: name,
                    linkedNotebookId: doc.id))
            }
        }

        // 還沒遷移、仍然躺在 Kairumo Record 的舊錄音要留著，
        // 否則使用者會以為它們不見了。
        let legacyDir = AudioRecorderManager.shared.recordingsDirectory
        let legacy = byFileName.values.filter {
            fm.fileExists(atPath: legacyDir.appending(path: $0.fileName).path)
        }

        recordings = (scanned + legacy).sorted { $0.recordedDate > $1.recordedDate }
        persistData()
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

    public func deleteRecording(id: String) {
        if let rec = recordings.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(at: recordingFileURL(for: rec))
        }
        recordings.removeAll { $0.id == id }
        persistData()
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
            list = milestones.map { snapshot(from: $0, notebookId: notebookId) }
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

public struct NoteTapeAttachment: Identifiable, Codable, Hashable {
    public let id: String
    public var pageIndex: Int
    public var rect: CGRect
    public var isRevealed: Bool
    
    public init(id: String = UUID().uuidString, pageIndex: Int, rect: CGRect, isRevealed: Bool = false) {
        self.id = id
        self.pageIndex = pageIndex
        self.rect = rect
        self.isRevealed = isRevealed
    }
}

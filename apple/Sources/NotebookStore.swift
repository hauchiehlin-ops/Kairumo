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
}

public extension ObjectFrameStyled {
    /// 底色是否為透明。
    var isBackgroundClear: Bool { backgroundColorHex == "clear" }
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
}

/// 筆記樣板種類（涵蓋三大主題與通用基礎）
public enum NoteTemplate: String, Codable, CaseIterable, Identifiable {
    // 通用基礎
    case blank = "空白紙張"
    case grid = "方格點陣"
    case lined = "橫線筆記"
    case cornell = "康乃爾"

    // 美學視覺
    case dotGridFine = "極細點陣 (5mm)"
    case goldenRatio = "黃金比例與三分構圖"
    case moodboardMatrix = "情緒板與色卡矩陣"

    // 工程製程
    case blueprintMetric = "工程藍圖坐標紙"
    case isometricGrid = "30° 等角立體軸測網格"
    case orthographic3View = "三視圖與剖面範本"

    // 數位體驗
    case mobileWireframe = "行動端線框 (8pt Grid)"
    case webResponsiveGrid = "響應式 Web 12 欄網格"
    case userJourneyFlow = "使用者旅程與流程圖"

    public var id: String { rawValue }

    public var category: NoteThemeCategory {
        switch self {
        case .blank, .grid, .lined, .cornell:
            return .general
        case .dotGridFine, .goldenRatio, .moodboardMatrix:
            return .aesthetic
        case .blueprintMetric, .isometricGrid, .orthographic3View:
            return .engineering
        case .mobileWireframe, .webResponsiveGrid, .userJourneyFlow:
            return .digital
        }
    }

    public var iconName: String {
        switch self {
        case .blank: return "doc.plaintext"
        case .grid: return "circle.grid.3x3"
        case .lined: return "line.horizontal.3"
        case .cornell: return "sidebar.left"
        case .dotGridFine: return "circle.dotted"
        case .goldenRatio: return "camera.metering.center.weighted"
        case .moodboardMatrix: return "rectangle.split.2x2"
        case .blueprintMetric: return "square.grid.3x3.square"
        case .isometricGrid: return "cube.transparent"
        case .orthographic3View: return "square.split.2x2"
        case .mobileWireframe: return "iphone"
        case .webResponsiveGrid: return "macwindow"
        case .userJourneyFlow: return "arrow.triangle.branch"
        }
    }

    public var localizationKey: String {
        switch self {
        case .blank: return "tmpl_blank"
        case .grid: return "tmpl_grid"
        case .lined: return "tmpl_lined"
        case .cornell: return "tmpl_cornell"
        case .dotGridFine: return "tmpl_dot_grid_fine"
        case .goldenRatio: return "tmpl_golden_ratio"
        case .moodboardMatrix: return "tmpl_moodboard"
        case .blueprintMetric: return "tmpl_blueprint"
        case .isometricGrid: return "tmpl_isometric"
        case .orthographic3View: return "tmpl_orthographic"
        case .mobileWireframe: return "tmpl_mobile_wireframe"
        case .webResponsiveGrid: return "tmpl_web_grid"
        case .userJourneyFlow: return "tmpl_user_journey"
        }
    }

    public var descriptionLocalizationKey: String {
        switch self {
        case .blank: return "tmpl_blank_desc"
        case .grid: return "tmpl_grid_desc"
        case .lined: return "tmpl_lined_desc"
        case .cornell: return "tmpl_cornell_desc"
        case .dotGridFine: return "tmpl_dot_grid_fine_desc"
        case .goldenRatio: return "tmpl_golden_ratio_desc"
        case .moodboardMatrix: return "tmpl_moodboard_desc"
        case .blueprintMetric: return "tmpl_blueprint_desc"
        case .isometricGrid: return "tmpl_isometric_desc"
        case .orthographic3View: return "tmpl_orthographic_desc"
        case .mobileWireframe: return "tmpl_mobile_wireframe_desc"
        case .webResponsiveGrid: return "tmpl_web_grid_desc"
        case .userJourneyFlow: return "tmpl_user_journey_desc"
        }
    }

    public var description: String {
        switch self {
        case .blank: return "適合自由手繪、心智圖與草稿"
        case .grid: return "幾何繪圖、公式推導與圖表繪製"
        case .lined: return "課堂筆記、會議逐字與行文撰寫"
        case .cornell: return "左側提綱摘要、右側主體筆記、底部總結"
        case .dotGridFine: return "視覺藝術與版面設計師專用暖灰精密點陣"
        case .goldenRatio: return "經典黃金分割線與九宮格參考輔助線"
        case .moodboardMatrix: return "頂部 5 格代表色票位，中央大尺寸靈感畫布"
        case .blueprintMetric: return "青藍精密毫米網格，含右下角標準 Title Block 標題欄"
        case .isometricGrid: return "機械構件、三維產品外觀與爆炸透視專用"
        case .orthographic3View: return "正視、俯視、側視與立體軸測四象限分區引導"
        case .mobileWireframe: return "內建雙手機螢幕輪廓框與 8pt 像素網格"
        case .webResponsiveGrid: return "標準 12 欄格線、間距與安全邊距引導"
        case .userJourneyFlow: return "階段泳道、步驟節點與決策條件分支引導"
        }
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
        id: String = UUID().uuidString,
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
    public var previewSnippet: String?
    public var template: NoteTemplate
    public var recordingAudioPath: String?
    /// 所屬資料夾 ID（nil 代表位於最上層根目錄或未分類）
    public var folderId: String?
    /// 各頁面之 PKDrawing 向量筆跡資料（以 Data 形式持久化）
    public var pagesData: [Data]
    /// 各頁面之客製化畫布長度（以 pt 為單位，預設 1800pt，支援自由向下延長）
    public var pageHeights: [CGFloat]?
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

    /// 系統預設標題的語系鍵。
    ///
    /// 內建的示範筆記若把中文標題直接寫死存進 JSON，切換介面語言時檔名不會跟著變
    /// —— 但標題同時又是使用者可以改的資料，不能每次都用翻譯覆蓋。折衷做法是記下
    /// 「這個標題還是系統給的」：顯示時翻譯，使用者一改名就清掉這個標記，
    /// 從此完全尊重使用者輸入。
    public var titleKey: String?
    /// 系統預設摘要的語系鍵，語意同 `titleKey`。
    public var snippetKey: String?

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
        id: String = UUID().uuidString,
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
        commentPins: [NoteCommentPin]? = []
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
        self.attachments = attachments ?? []
        self.textAttachments = textAttachments ?? []
        self.linkAttachments = linkAttachments ?? []
        self.model3DAttachments = model3DAttachments ?? []
        self.commentPins = commentPins ?? []
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
public struct NoteImageAttachment: Identifiable, Codable, Hashable, ObjectFrameStyled {
    public let id: String
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
    public var pageIndex: Int
    public var text: String
    public var fontSize: CGFloat
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var isStrikethrough: Bool
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

/// 筆記內嵌網頁連結預覽附件模型
public struct NoteLinkAttachment: Identifiable, Codable, Hashable, ObjectFrameStyled {
    public let id: String
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

/// 筆記里程碑快照資料模型（時光機歷史版本）
public struct NotebookMilestoneSnapshot: Identifiable, Codable {
    public let id: String
    public let notebookId: String
    public let title: String
    public let creatorName: String
    public let createdAt: Date
    public let noteData: Data
    public let pagesData: [Data]

    public init(
        id: String = UUID().uuidString,
        notebookId: String,
        title: String,
        creatorName: String,
        createdAt: Date = Date(),
        noteData: Data,
        pagesData: [Data]
    ) {
        self.id = id
        self.notebookId = notebookId
        self.title = title
        self.creatorName = creatorName
        self.createdAt = createdAt
        self.noteData = noteData
        self.pagesData = pagesData
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

/// 筆記資料持久化中樞
@MainActor
public final class NotebookStore: ObservableObject {
    public static let shared = NotebookStore()

    @Published public var notebooks: [NotebookDocument] = []
    @Published public var recordings: [AudioRecordingRecord] = []
    @Published public var folders: [FolderItem] = []
    /// 根資料夾名稱。空字串代表「使用者沒有自訂」，顯示時走語系預設值。
    @Published public var rootFolderName: String = ""

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

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var notebooksFile: URL {
        documentsDir.appendingPathComponent("notebooks_v1.json")
    }

    private var recordingsFile: URL {
        documentsDir.appendingPathComponent("recordings_v1.json")
    }

    private var foldersFile: URL {
        documentsDir.appendingPathComponent("folders_v1.json")
    }

    private init() {
        loadData()
        if notebooks.isEmpty {
            seedDefaultNotebooks()
        }
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
        return result
    }


    public func loadData() {
        if let data = try? Data(contentsOf: notebooksFile),
           let list = try? JSONDecoder().decode([NotebookDocument].self, from: data) {
            self.notebooks = Self.deduplicateById(list.map(migrateSeedTitles))
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
        "歡迎使用 Kairumo": ("seed_welcome_title", "seed_welcome_snippet"),
        "课堂与会议记录": ("seed_meeting_title", "seed_meeting_snippet"),
        "課堂與會議記錄": ("seed_meeting_title", "seed_meeting_snippet")
    ]

    private func migrateSeedTitles(_ doc: NotebookDocument) -> NotebookDocument {
        guard doc.titleKey == nil, let keys = Self.legacySeedTitles[doc.title] else { return doc }
        var migrated = doc
        migrated.titleKey = keys.title
        migrated.snippetKey = keys.snippet
        return migrated
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
                }
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
        let fileUrl = drawingsDirectory.appendingPathComponent("\(notebookId)_p\(pageIndex).drawing")
        let data = drawing.dataRepresentation()
        try? data.write(to: fileUrl, options: .atomic)
    }

    /// 讀取單頁手繪內容
    public func loadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing {
        let fileUrl = drawingsDirectory.appendingPathComponent("\(notebookId)_p\(pageIndex).drawing")
        if let data = try? Data(contentsOf: fileUrl), let d = try? PKDrawing(data: data) {
            return d
        }
        return PKDrawing()
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
        let fileUrl = attachmentsDirectory.appendingPathComponent(fileName)
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
        let fileUrl = attachmentsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileUrl), let img = UIImage(data: data) else { return nil }
        imageCache.setObject(img, forKey: key)
        return img
    }

    private func seedDefaultNotebooks() {
        // title/previewSnippet 仍然寫入（供未安裝語系或外部讀取時 fallback），
        // 但顯示一律走 titleKey/snippetKey。
        var n1 = NotebookDocument(
            title: "歡迎使用 Kairumo",
            createdAt: Date().addingTimeInterval(-86400 * 2),
            lastModifiedDate: Date().addingTimeInterval(-3600),
            pageCount: 1,
            hasRecording: false,
            previewSnippet: "點擊進入畫布即可隨心手寫、繪製圖形、插入錄音並導出 PDF",
            template: .blank
        )

        var n2 = NotebookDocument(
            title: "課堂與會議記錄",
            createdAt: Date().addingTimeInterval(-86400),
            lastModifiedDate: Date().addingTimeInterval(-7200),
            pageCount: 2,
            hasRecording: true,
            previewSnippet: "支援麥克風即時收音，聲音與筆跡精確對齊",
            template: .cornell
        )

        n1.titleKey = "seed_welcome_title"
        n1.snippetKey = "seed_welcome_snippet"
        n2.titleKey = "seed_meeting_title"
        n2.snippetKey = "seed_meeting_snippet"

        self.notebooks = [n1, n2]
        persistData()
    }

    // MARK: - 筆記操作 CRUD

    @discardableResult
    public func createNotebook(title: String, template: NoteTemplate, folderId: String? = nil) -> NotebookDocument {
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名筆記" : title
        let newDoc = NotebookDocument(
            title: safeTitle,
            createdAt: Date(),
            lastModifiedDate: Date(),
            pageCount: 1,
            hasRecording: false,
            previewSnippet: "建立於 \(Date().formatted(date: .abbreviated, time: .shortened))",
            template: template,
            folderId: folderId
        )
        notebooks.insert(newDoc, at: 0)
        persistData()
        return newDoc
    }

    public func updateNotebook(_ doc: NotebookDocument) {
        if let idx = notebooks.firstIndex(where: { $0.id == doc.id }) {
            var updated = doc
            updated.lastModifiedDate = Date()
            notebooks[idx] = updated
            markDirtyAndPersist()
        }
    }

    public func deleteNotebook(id: String) {
        notebooks.removeAll { $0.id == id }
        persistData()
    }

    public func duplicateNotebook(id: String) {
        guard let original = notebooks.first(where: { $0.id == id }) else { return }
        var copy = original
        copy = NotebookDocument(
            title: "\(original.title) (副本)",
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
        persistData()
    }

    public func renameNotebook(id: String, newTitle: String) {
        guard let idx = notebooks.firstIndex(where: { $0.id == id }) else { return }
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            notebooks[idx].title = clean
            // 使用者親自命名之後就不再翻譯，否則改了名字又被語系蓋回去。
            notebooks[idx].titleKey = nil
            notebooks[idx].lastModifiedDate = Date()
            persistData()
        }
    }

    // MARK: - 資料夾管理 CRUD

    @discardableResult
    public func createFolder(name: String, parentId: String? = nil, colorHex: String? = nil) -> FolderItem {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新增資料夾" : name
        let folder = FolderItem(name: cleanName, parentId: parentId, colorHex: colorHex)
        folders.append(folder)
        persistData()
        return folder
    }

    public func renameFolder(id: String, newName: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            folders[idx].name = clean
            persistData()
        }
    }

    public func deleteFolder(id: String) {
        // 將該資料夾內的筆記安全移回其父資料夾（若無父資料夾則移回根目錄 nil）
        let targetFolder = folders.first(where: { $0.id == id })
        let fallbackParentId = targetFolder?.parentId
        for i in 0..<notebooks.count {
            if notebooks[i].folderId == id {
                notebooks[i].folderId = fallbackParentId
            }
        }
        // 將該資料夾底下的子資料夾提升至父資料夾
        for i in 0..<folders.count {
            if folders[i].parentId == id {
                folders[i].parentId = fallbackParentId
            }
        }
        folders.removeAll { $0.id == id }
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
        persistData()
    }

    public func subfolders(of parentId: String?) -> [FolderItem] {
        folders.filter { $0.parentId == parentId }
    }

    public func notebooks(in folderId: String?) -> [NotebookDocument] {
        notebooks.filter { $0.folderId == folderId }
    }

    // MARK: - 集中單一事實分頁管理 (Atomic Page Management)

    /// 為指定筆記安全原子新增下一頁，回傳新頁碼 index
    @discardableResult
    public func addPage(notebookId: String) -> Int {
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
        notebooks[idx].lastModifiedDate = Date()

        let newPageIndex = newPageCount - 1
        // 儲存空白筆跡至磁碟
        saveDrawing(notebookId: notebookId, pageIndex: newPageIndex, drawing: PKDrawing())
        persistData()
        return newPageIndex
    }

    /// 在指定頁面後方插入新頁面，平移後續頁面並回傳新插入頁面之 pageIndex
    @discardableResult
    public func insertPage(notebookId: String, afterIndex: Int) -> Int {
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

        // 平移各類附件之 pageIndex
        if let atts = notebooks[idx].attachments {
            notebooks[idx].attachments = atts.map { item in
                var mod = item
                if mod.pageIndex >= insertIndex { mod.pageIndex += 1 }
                return mod
            }
        }
        if let txts = notebooks[idx].textAttachments {
            notebooks[idx].textAttachments = txts.map { item in
                var mod = item
                if mod.pageIndex >= insertIndex { mod.pageIndex += 1 }
                return mod
            }
        }
        if let lnks = notebooks[idx].linkAttachments {
            notebooks[idx].linkAttachments = lnks.map { item in
                var mod = item
                if mod.pageIndex >= insertIndex { mod.pageIndex += 1 }
                return mod
            }
        }
        if let mods = notebooks[idx].model3DAttachments {
            notebooks[idx].model3DAttachments = mods.map { item in
                var mod = item
                if mod.pageIndex >= insertIndex { mod.pageIndex += 1 }
                return mod
            }
        }
        if let pins = notebooks[idx].commentPins {
            notebooks[idx].commentPins = pins.map { item in
                var mod = item
                if mod.pageIndex >= insertIndex { mod.pageIndex += 1 }
                return mod
            }
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
        let lastFileUrl = drawingsDirectory.appendingPathComponent("\(notebookId)_p\(total - 1).drawing")
        try? FileManager.default.removeItem(at: lastFileUrl)

        // 平移高度陣列
        if var heights = notebooks[idx].pageHeights, heights.count >= total {
            heights.remove(at: pageIndex)
            notebooks[idx].pageHeights = heights
        }

        // 平移附件之 pageIndex
        notebooks[idx].attachments?.removeAll { $0.pageIndex == pageIndex }
        if let atts = notebooks[idx].attachments {
            notebooks[idx].attachments = atts.map { item in
                var mod = item
                if mod.pageIndex > pageIndex { mod.pageIndex -= 1 }
                return mod
            }
        }
        notebooks[idx].textAttachments?.removeAll { $0.pageIndex == pageIndex }
        if let txts = notebooks[idx].textAttachments {
            notebooks[idx].textAttachments = txts.map { item in
                var mod = item
                if mod.pageIndex > pageIndex { mod.pageIndex -= 1 }
                return mod
            }
        }
        notebooks[idx].linkAttachments?.removeAll { $0.pageIndex == pageIndex }
        if let lnks = notebooks[idx].linkAttachments {
            notebooks[idx].linkAttachments = lnks.map { item in
                var mod = item
                if mod.pageIndex > pageIndex { mod.pageIndex -= 1 }
                return mod
            }
        }
        notebooks[idx].model3DAttachments?.removeAll { $0.pageIndex == pageIndex }
        if let mods = notebooks[idx].model3DAttachments {
            notebooks[idx].model3DAttachments = mods.map { item in
                var mod = item
                if mod.pageIndex > pageIndex { mod.pageIndex -= 1 }
                return mod
            }
        }
        notebooks[idx].commentPins?.removeAll { $0.pageIndex == pageIndex }
        if let pins = notebooks[idx].commentPins {
            notebooks[idx].commentPins = pins.map { item in
                var mod = item
                if mod.pageIndex > pageIndex { mod.pageIndex -= 1 }
                return mod
            }
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

        notebooks[idx].pageCount = total + 1
        notebooks[idx].lastModifiedDate = Date()
        persistData()

        return pageIndex + 1
    }

    // MARK: - 錄音操作 CRUD

    public func addRecording(title: String, durationSeconds: Int, fileName: String, linkedNotebookId: String? = nil) {
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
    }

    public func deleteRecording(id: String) {
        if let rec = recordings.first(where: { $0.id == id }) {
            let fileUrl = AudioRecorderManager.shared.recordingsDirectory.appendingPathComponent(rec.fileName)
            try? FileManager.default.removeItem(at: fileUrl)
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
                let url = self.attachmentsDirectory.appendingPathComponent(fileName)
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

    // MARK: - 里程碑快照時光機 (Milestone Snapshots)

    /// 里程碑快照目錄
    public var snapshotsDirectory: URL {
        let dir = documentsDir.appendingPathComponent("Snapshots", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 建立里程碑快照
    @discardableResult
    public func createMilestoneSnapshot(notebookId: String, title: String, creatorName: String) -> NotebookMilestoneSnapshot? {
        guard let note = notebooks.first(where: { $0.id == notebookId }) else { return nil }
        var drawingsData: [Data] = []
        for p in 0..<note.pageCount {
            let drawing = loadDrawing(notebookId: notebookId, pageIndex: p)
            drawingsData.append(drawing.dataRepresentation())
        }

        guard let noteData = try? JSONEncoder().encode(note) else { return nil }

        let snapshot = NotebookMilestoneSnapshot(
            id: UUID().uuidString,
            notebookId: notebookId,
            title: title.isEmpty ? "協同快照" : title,
            creatorName: creatorName,
            createdAt: Date(),
            noteData: noteData,
            pagesData: drawingsData
        )

        let noteSnapshotDir = snapshotsDirectory.appendingPathComponent(notebookId, isDirectory: true)
        if !FileManager.default.fileExists(atPath: noteSnapshotDir.path) {
            try? FileManager.default.createDirectory(at: noteSnapshotDir, withIntermediateDirectories: true)
        }

        let fileUrl = noteSnapshotDir.appendingPathComponent("\(snapshot.id).snapshot")
        if let snapData = try? JSONEncoder().encode(snapshot) {
            try? snapData.write(to: fileUrl, options: .atomic)
            return snapshot
        }
        return nil
    }

    /// 列出指定筆記之所有里程碑快照
    public func listMilestoneSnapshots(notebookId: String) -> [NotebookMilestoneSnapshot] {
        let noteSnapshotDir = snapshotsDirectory.appendingPathComponent(notebookId, isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: noteSnapshotDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var list: [NotebookMilestoneSnapshot] = []
        for file in files where file.pathExtension == "snapshot" {
            if let data = try? Data(contentsOf: file),
               let snap = try? JSONDecoder().decode(NotebookMilestoneSnapshot.self, from: data) {
                list.append(snap)
            }
        }
        return list.sorted(by: { $0.createdAt > $1.createdAt })
    }

    /// 回滾至指定快照
    @discardableResult
    public func restoreMilestoneSnapshot(notebookId: String, snapshot: NotebookMilestoneSnapshot) -> Bool {
        guard let restoredNote = try? JSONDecoder().decode(NotebookDocument.self, from: snapshot.noteData) else {
            return false
        }
        guard let idx = notebooks.firstIndex(where: { $0.id == notebookId }) else { return false }

        // 回滾各頁筆跡
        for (pageIdx, data) in snapshot.pagesData.enumerated() {
            if let drawing = try? PKDrawing(data: data) {
                saveDrawing(notebookId: notebookId, pageIndex: pageIdx, drawing: drawing)
            }
        }

        notebooks[idx] = restoredNote
        notebooks[idx].lastModifiedDate = Date()
        persistData()
        return true
    }
}

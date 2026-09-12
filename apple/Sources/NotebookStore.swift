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
        case .blank: return "blank"
        case .grid: return "grid"
        case .lined: return "lined"
        case .cornell: return "cornell"
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
        case .blank: return "blank"
        case .grid: return "grid"
        case .lined: return "lined"
        case .cornell: return "cornell"
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

    public func height(forPage pageIndex: Int, defaultHeight: CGFloat = 1800) -> CGFloat {
        guard let heights = pageHeights, pageIndex >= 0, pageIndex < heights.count else {
            return defaultHeight
        }
        return max(defaultHeight, heights[pageIndex])
    }

    public mutating func setHeight(_ height: CGFloat, forPage pageIndex: Int) {
        var heights = pageHeights ?? Array(repeating: 1800.0, count: max(pageCount, pageIndex + 1))
        while heights.count <= pageIndex {
            heights.append(1800.0)
        }
        heights[pageIndex] = height
        self.pageHeights = heights
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
public struct NoteImageAttachment: Identifiable, Codable, Hashable {
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
        materialType: MaterialType? = nil
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
        self.filterStyle = filterStyle
        self.materialType = materialType
    }
}

/// 筆記內嵌 3D 模型附件模型
public struct Note3DAttachment: Identifiable, Codable, Hashable {
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
        height: CGFloat = 240
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
    }
}

/// 筆記內嵌 Word 級文字方塊附件模型
public struct NoteTextAttachment: Identifiable, Codable, Hashable {
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
    public var backgroundColorHex: String // e.g. "#FFFFFF", "#FFF9C4", "clear"
    public var hasBorder: Bool
    public var cornerRadius: CGFloat
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

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
        x: CGFloat = 100,
        y: CGFloat = 150,
        width: CGFloat = 300,
        height: CGFloat = 160
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
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 筆記內嵌網頁連結預覽附件模型
public struct NoteLinkAttachment: Identifiable, Codable, Hashable {
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
        height: CGFloat = 120
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
    @Published public var rootFolderName: String = "我的筆記"

    private let rootFolderNameKey = "kairumo.notebooks.rootFolderName"

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

    public func loadData() {
        if let data = try? Data(contentsOf: notebooksFile),
           let list = try? JSONDecoder().decode([NotebookDocument].self, from: data) {
            self.notebooks = list
        }

        if let recData = try? Data(contentsOf: recordingsFile),
           let recList = try? JSONDecoder().decode([AudioRecordingRecord].self, from: recData) {
            self.recordings = recList
        }

        if let fData = try? Data(contentsOf: foldersFile),
           let fList = try? JSONDecoder().decode([FolderItem].self, from: fData) {
            self.folders = fList
        }

        if let savedRoot = UserDefaults.standard.string(forKey: rootFolderNameKey), !savedRoot.isEmpty {
            self.rootFolderName = savedRoot
        }
    }

    public func persistData() {
        if let data = try? JSONEncoder().encode(notebooks) {
            try? data.write(to: notebooksFile, options: .atomic)
        }
        if let recData = try? JSONEncoder().encode(recordings) {
            try? recData.write(to: recordingsFile, options: .atomic)
        }
        if let fData = try? JSONEncoder().encode(folders) {
            try? fData.write(to: foldersFile, options: .atomic)
        }
        UserDefaults.standard.set(rootFolderName, forKey: rootFolderNameKey)
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
        let n1 = NotebookDocument(
            title: "歡迎使用 Kairumo",
            createdAt: Date().addingTimeInterval(-86400 * 2),
            lastModifiedDate: Date().addingTimeInterval(-3600),
            pageCount: 1,
            hasRecording: false,
            previewSnippet: "點擊進入畫布即可隨心手寫、繪製圖形、插入錄音並導出 PDF",
            template: .blank
        )

        let n2 = NotebookDocument(
            title: "課堂與會議記錄",
            createdAt: Date().addingTimeInterval(-86400),
            lastModifiedDate: Date().addingTimeInterval(-7200),
            pageCount: 2,
            hasRecording: true,
            previewSnippet: "支援麥克風即時收音，聲音與筆跡精確對齊",
            template: .cornell
        )

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
            persistData()
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

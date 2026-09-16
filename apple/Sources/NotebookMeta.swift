//
//  NotebookMeta.swift
//  Kairumo
//
//  筆記本層級的平台中繼資料（核心的 `SetNotebookMeta`，op 33）。
//
//  # 這裡放什麼
//
//  「是一本筆記的屬性、但核心沒有對應概念」的東西：版面樣板、所屬資料夾、
//  討論圖釘、連結卡片、3D 模型、建立時間、系統標題的語系鍵。
//
//  核心的文件模型只認得頁、區塊、筆畫。少了這一層，同一本筆記在另一台裝置上
//  打開會變回空白樣板、掉出資料夾、圖釘與連結卡片整串消失 —— 那不是
//  「還沒支援」，是資料遺失。
//
//  # 為什麼直接用 Codable 原樣塞
//
//  這些型別在 Apple 端已經是 `Codable`，逐欄位手寫對應表只會多出一份會漂移的
//  定義。核心不解讀內容，所以原樣塞進去是安全的；Android 日後長出這些功能時，
//  讀的是同一組鍵。
//
//  ⚠️ 這份 JSON 會寫進 `.padnote`。改欄位等於改檔案格式 —— 只能加、不能改名，
//  而且每個欄位都必須是 Optional，舊檔才打得開。
//

import Foundation

struct NotebookMeta: Codable, Hashable {
    /// `NoteTemplate.rawValue`。核心的 `PageStyle` 種類比它少，所以樣板必須
    /// 另外記 —— 只靠 `PageStyle` 回推會把「等距格線」變成普通格線。
    var template: String?
    var folderId: String?
    /// 系統預設標題／摘要的語系鍵（見 `NotebookDocument.titleKey`）。
    var titleKey: String?
    var snippetKey: String?
    var previewSnippet: String?
    var createdAt: Date?
    var lastModifiedDate: Date?
    var hasRecording: Bool?
    var recordingAudioPath: String?

    /// 這本筆記在核心裡的頁面 id，依頁次。
    ///
    /// 頁面身分必須跟著筆記走，不是跟著某一次匯出走。每次重建都隨機生一批 id
    /// 的話，兩台裝置的頁**永遠不會收斂** —— 合併之後不是一頁有兩邊的內容，
    /// 而是變成兩頁，每同步一趟再多一批。
    var pageIds: [String]?

    /// 畫布物件的堆疊順序：`["頁次": [由後到前的物件 id]]`。
    ///
    /// 放在這裡而不是只留在 Apple 自己的 JSON 裡，是為了讓它**跨得過平台** ——
    /// 這份中繼資料會寫進 `.padnote`，Android 讀的是同一組鍵。
    /// 只留在平台自己的檔案裡的話，在 iPad 上排好的疊放順序，換到 Android
    /// 就回到型別預設，而使用者會以為圖層被打亂了。
    ///
    /// 鍵是頁次的字串（JSON 的物件鍵只能是字串）。
    var objectOrderByPage: [String: [String]]?

    /// 核心沒有對應區塊型別的物件，原樣保存。
    var linkAttachments: [NoteLinkAttachment]?
    var model3DAttachments: [Note3DAttachment]?
    /// 頁面上的錄音卡片。核心沒有對應的區塊型別，與連結卡片同一條路：
    /// 真身放在中繼資料，套件裡另外放一張算繪好的 PNG 當後備。
    var audioAttachments: [NoteAudioAttachment]?
    var commentPins: [NoteCommentPin]?

    // MARK: - JSON

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // 欄位順序固定、日期用 ISO 8601：同一份筆記每次匯出要得到同一份位元組，
        // 否則同步時每次都看起來像「內容有變」。
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func encodedJSON() -> String {
        (try? Self.encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// 讀不懂時回 `nil`，呼叫端自己決定退路。
    ///
    /// 回 `nil` 而不是丟錯：中繼資料壞掉最多是「這本筆記回到預設樣板」，
    /// 不該讓整本筆記開不起來 —— 筆畫與文字都還在。
    static func decode(from json: String) -> NotebookMeta? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(NotebookMeta.self, from: data)
    }

    // MARK: - 與 NotebookDocument 的對應

    init(from document: NotebookDocument) {
        template = document.template.rawValue
        folderId = document.folderId
        titleKey = document.titleKey
        snippetKey = document.snippetKey
        previewSnippet = document.previewSnippet
        createdAt = document.createdAt
        lastModifiedDate = document.lastModifiedDate
        hasRecording = document.hasRecording
        recordingAudioPath = document.recordingAudioPath
        linkAttachments = document.linkAttachments
        model3DAttachments = document.model3DAttachments
        audioAttachments = document.audioAttachments
        commentPins = document.commentPins
        objectOrderByPage = document.objectOrderByPage
    }

    /// 把中繼資料套回文件。缺的欄位一律保留文件原本的值。
    func apply(to document: inout NotebookDocument) {
        if let raw = template, let value = NoteTemplate(rawValue: raw) { document.template = value }
        if let folderId { document.folderId = folderId }
        if let titleKey { document.titleKey = titleKey }
        if let snippetKey { document.snippetKey = snippetKey }
        if let previewSnippet { document.previewSnippet = previewSnippet }
        if let createdAt { document.createdAt = createdAt }
        if let lastModifiedDate { document.lastModifiedDate = lastModifiedDate }
        if let hasRecording { document.hasRecording = hasRecording }
        if let recordingAudioPath { document.recordingAudioPath = recordingAudioPath }
        if let linkAttachments { document.linkAttachments = linkAttachments }
        if let model3DAttachments { document.model3DAttachments = model3DAttachments }
        if let audioAttachments { document.audioAttachments = audioAttachments }
        if let commentPins { document.commentPins = commentPins }
        if let objectOrderByPage { document.objectOrderByPage = objectOrderByPage }
    }
}

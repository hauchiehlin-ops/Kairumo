import CoreGraphics
import Foundation

/// 文件範本目錄（工作項 S-61）。
///
/// # 這與 `NoteTemplate` 不是同一件事
///
/// `NoteTemplate` 選的是**紙張**（方格、橫線、康乃爾）—— 它決定底紋，不放內容。
/// 這裡選的是**文件**（詢價單、租賃契約、會議紀錄）—— 它在頁面上放真正的
/// 文字與表格。兩者可以並存：一份會議紀錄鋪在橫線紙上。
///
/// # 內容為什麼不寫在這個檔案裡
///
/// 39 種文件、每種兩個版本 = 78 份。在 Swift 與 Kotlin 各手寫一份的話，
/// 兩邊必然漂移，而症狀是「同一份契約範本在 iPad 與 Android 上長得不一樣」。
///
/// 所以內容寫在 `templates/src/*.json`，版面由 `scripts/doc_templates_tool.py`
/// **算好之後**輸出成一份 `document-templates.json`，兩個平台載入同一份檔案。
/// 座標只算一次，兩邊必然相同。
///
/// # 為什麼是「載入」不是「編譯進去」
///
/// 走的是手冊與隱私權政策同一條資源路徑（`Resources/Templates`）。
/// 產成 Swift 原始碼的話是一個上萬行的檔案，編譯時間與可讀性都很難看。
public enum DocumentTemplateCatalog {

    // MARK: - 模型

    public struct Theme: Identifiable, Hashable {
        public let id: String
        public let iconName: String
        public let name: [String: String]
        public let categories: [Category]
    }

    public struct Category: Identifiable, Hashable {
        public let id: String
        public let name: [String: String]
        public let templates: [Template]
    }

    public struct Template: Identifiable, Hashable {
        public let id: String
        public let name: [String: String]
        public let description: [String: String]
        public let pageStyle: String
        /// `example` / `blank` → 語言 → 內容。
        public let variants: [String: [String: Variant]]
    }

    public struct Variant: Hashable {
        public let pageCount: Int
        public let blocks: [Block]
    }

    public struct Block: Hashable {
        public let kind: String
        public let page: Int
        public let x: CGFloat
        public let y: CGFloat
        public let width: CGFloat
        public let height: CGFloat
        public let text: String
        public let fontSize: CGFloat
        public let bold: Bool
        public let lineSpacing: CGFloat
        public let rows: Int
        public let cols: Int
        public let cells: [String]
        public let headerRow: Bool
    }

    /// 完整案例 / 空白範本。
    public enum Variantkind: String, CaseIterable, Identifiable {
        case example
        case blank

        public var id: String { rawValue }

        public var localizationKey: String {
            switch self {
            case .example: return "doc_variant_example"
            case .blank: return "doc_variant_blank"
            }
        }
    }

    // MARK: - 載入

    /// 目錄內容。載入失敗回空陣列 —— 範本是加分功能，不該讓首頁開不起來。
    public static let themes: [Theme] = load()

    private static func load() -> [Theme] {
        guard let url = Bundle.main.url(
            forResource: "document-templates", withExtension: "json", subdirectory: "Templates")
            ?? Bundle.main.url(forResource: "document-templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawThemes = root["themes"] as? [[String: Any]]
        else { return [] }

        return rawThemes.map { theme in
            Theme(
                id: theme["id"] as? String ?? "",
                iconName: ((theme["icon"] as? [String: Any])?["apple"] as? String) ?? "doc.text",
                name: stringMap(theme["name"]),
                categories: (theme["categories"] as? [[String: Any]] ?? []).map { category in
                    Category(
                        id: category["id"] as? String ?? "",
                        name: stringMap(category["name"]),
                        templates: (category["templates"] as? [[String: Any]] ?? []).map(template)
                    )
                }
            )
        }
    }

    private static func template(_ raw: [String: Any]) -> Template {
        var variants: [String: [String: Variant]] = [:]
        for (kind, byLang) in (raw["variants"] as? [String: [String: Any]] ?? [:]) {
            var langs: [String: Variant] = [:]
            for (lang, body) in byLang {
                guard let body = body as? [String: Any] else { continue }
                langs[lang] = Variant(
                    pageCount: body["pageCount"] as? Int ?? 1,
                    blocks: (body["blocks"] as? [[String: Any]] ?? []).map(block)
                )
            }
            variants[kind] = langs
        }
        return Template(
            id: raw["id"] as? String ?? "",
            name: stringMap(raw["name"]),
            description: stringMap(raw["description"]),
            pageStyle: raw["pageStyle"] as? String ?? "blank",
            variants: variants
        )
    }

    private static func block(_ raw: [String: Any]) -> Block {
        Block(
            kind: raw["kind"] as? String ?? "body",
            page: raw["page"] as? Int ?? 0,
            x: cg(raw["x"]), y: cg(raw["y"]),
            width: cg(raw["width"]), height: cg(raw["height"]),
            text: raw["text"] as? String ?? "",
            fontSize: cg(raw["fontSize"], default: 15),
            bold: raw["bold"] as? Bool ?? false,
            lineSpacing: cg(raw["lineSpacing"], default: 5),
            rows: raw["rows"] as? Int ?? 0,
            cols: raw["cols"] as? Int ?? 0,
            cells: raw["cells"] as? [String] ?? [],
            headerRow: raw["headerRow"] as? Bool ?? true
        )
    }

    private static func cg(_ value: Any?, default fallback: CGFloat = 0) -> CGFloat {
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        return fallback
    }

    private static func stringMap(_ value: Any?) -> [String: String] {
        (value as? [String: String]) ?? [:]
    }

    // MARK: - 取用

    public static func template(id: String) -> Template? {
        for theme in themes {
            for category in theme.categories {
                if let found = category.templates.first(where: { $0.id == id }) { return found }
            }
        }
        return nil
    }

    /// 依介面語言取字。沒有那個語系就退回繁體中文，再退回第一個有的。
    ///
    /// 退而不是留白：範本名稱空白的話，使用者看到的是一列空清單。
    public static func localized(_ table: [String: String], language: String) -> String {
        table[language] ?? table["zhHant"] ?? table.values.first ?? ""
    }

    /// 取某個版本在某個語言下的內容。
    ///
    /// 文件**內文**只有繁體中文與英文（公文、契約、訴狀綁的是特定法域的
    /// 格式，逐字翻成其他語言不會變成當地可用的文件）。所以非這兩種語言的
    /// 介面，內文退回繁體中文。
    public static func variant(
        _ template: Template, kind: Variantkind, language: String
    ) -> Variant? {
        guard let byLang = template.variants[kind.rawValue] else { return nil }
        return byLang[language] ?? byLang["zhHant"] ?? byLang.values.first
    }
}

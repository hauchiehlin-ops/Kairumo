//
//  TextBoxAppearance.swift
//  Kairumo
//
//  文字方塊外觀的跨平台編碼（`format-spec.md` §6.2）。
//
//  # 為什麼需要它
//
//  匯出到 `.padnote` 時，文字方塊原本只帶了「文字」與「位置」—— 顏色、邊框、
//  段落設定全部留在 Apple 自己的 JSON 裡。使用者在 iPad 上把方塊設成透明底、
//  加了行距，換到 Android 打開會變回白底無行距。那不是「還沒支援」，是資料遺失。
//
//  核心新增了 `SetBlockAppearance`，帶一段它不解讀的 JSON。**鍵名由格式規格
//  定義，兩個平台共用同一組** —— Android 端有一份對應的實作。
//

import Foundation

enum TextBoxAppearance {

    /// 把文字方塊的外觀編成 JSON。
    ///
    /// `nil` 的欄位**不寫進去**，而不是寫成 0 或空字串：接收端才分得出
    /// 「使用者沒設定」與「使用者設成 0」。
    static func encode(_ item: NoteTextAttachment) -> String {
        var json: [String: Any] = [
            "fontSize": item.fontSize,
            "bold": item.isBold,
            "italic": item.isItalic,
            "underline": item.isUnderline,
            "strikethrough": item.isStrikethrough,
            "alignment": item.alignmentRaw,
            "textColorHex": item.textColorHex,
            "hasBorder": item.hasBorder,
            "cornerRadius": item.cornerRadius,
            "width": item.width,
            "height": item.height
        ]
        // "clear" 是哨符不是顏色 —— 原樣帶過去，不要走任何顏色轉換。
        if let value = item.backgroundColorHex { json["backgroundColorHex"] = value }
        if let value = item.borderColorHex { json["borderColorHex"] = value }
        if let value = item.borderWidth { json["borderWidth"] = value }
        if let value = item.lineSpacing { json["lineSpacing"] = value }
        if let value = item.paragraphSpacing { json["paragraphSpacing"] = value }
        if let value = item.firstLineIndent { json["firstLineIndent"] = value }
        if let value = item.paragraphIndent { json["paragraphIndent"] = value }

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// 把 JSON 套回文字方塊。認不得的鍵一律忽略。
    ///
    /// 忽略而不是報錯：另一個平台可能帶了我們還沒實作的欄位，
    /// 那時該做的是保留其餘設定，不是整塊樣式都不套。
    static func apply(_ json: String, to item: inout NoteTextAttachment) {
        guard let data = json.data(using: .utf8),
              let map = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return }

        if let value = map["fontSize"] as? Double { item.fontSize = CGFloat(value) }
        if let value = map["bold"] as? Bool { item.isBold = value }
        if let value = map["italic"] as? Bool { item.isItalic = value }
        if let value = map["underline"] as? Bool { item.isUnderline = value }
        if let value = map["strikethrough"] as? Bool { item.isStrikethrough = value }
        if let value = map["alignment"] as? String { item.alignmentRaw = value }
        if let value = map["textColorHex"] as? String { item.textColorHex = value }
        if let value = map["backgroundColorHex"] as? String { item.backgroundColorHex = value }
        if let value = map["hasBorder"] as? Bool { item.hasBorder = value }
        if let value = map["borderColorHex"] as? String { item.borderColorHex = value }
        if let value = map["borderWidth"] as? Double { item.borderWidth = CGFloat(value) }
        if let value = map["cornerRadius"] as? Double { item.cornerRadius = CGFloat(value) }
        if let value = map["width"] as? Double { item.width = CGFloat(value) }
        if let value = map["height"] as? Double { item.height = CGFloat(value) }
        if let value = map["lineSpacing"] as? Double { item.lineSpacing = CGFloat(value) }
        if let value = map["paragraphSpacing"] as? Double { item.paragraphSpacing = CGFloat(value) }
        if let value = map["firstLineIndent"] as? Double { item.firstLineIndent = CGFloat(value) }
        if let value = map["paragraphIndent"] as? Double { item.paragraphIndent = CGFloat(value) }
    }
}

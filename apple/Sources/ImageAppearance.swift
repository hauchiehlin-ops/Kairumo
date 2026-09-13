//
//  ImageAppearance.swift
//  Kairumo
//
//  圖片區塊的外觀編碼（`format-spec.md` §6.2）。
//
//  # 為什麼圖片也需要一份
//
//  核心的圖片區塊只記得「哪個 blob、多寬多高」。使用者調過的圓角、邊框、
//  陰影、濾鏡、旋轉、底色全都沒有對應概念 —— 少了這一層，同一本筆記在另一台
//  裝置上打開，每張圖都會變回一張沒有樣式的方形照片。那不是「還沒支援」，
//  是資料遺失。
//
//  外層的 `object` 是**判別欄位**，與圖表共用同一個約定：
//  `{"object":"chart"|"image", "image":{…樣式…}, "chart":{…圖表設定…}}`。
//  沒有它，讀的人只能靠猜 JSON 的形狀來判斷這是什麼。
//
//  Android 端的 `ImageAppearance.kt` 用同一組鍵。
//

import Foundation

enum ImageAppearance {

    private static let objectKey = "object"
    private static let imageKey = "image"
    private static let chartKey = "chart"
    private static let chartObject = "chart"
    private static let imageObject = "image"

    /// 由別種物件算繪出來的圖片區塊 —— 連結卡片與 3D 模型。
    ///
    /// 這些東西核心沒有對應的區塊型別，匯出時算繪成圖片，PDF 裡才看得到。
    /// 但它們的**真身**跟著筆記本中繼資料走，匯入時會原樣還原 —— 所以這些
    /// 衍生圖片必須認得出來並跳過，否則同一張卡片會變成兩份（真的一份、
    /// 圖片一份），而且每同步一趟就再多一份。
    static let derivedObjects: Set<String> = ["link", "model3d"]

    /// 標記一個「由別種物件算繪出來」的圖片區塊。
    static func encodeDerived(objectKind: String, fileName: String) -> String {
        let root: [String: Any] = [
            objectKey: objectKind,
            imageKey: ["fileName": fileName]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// 這個區塊是不是衍生圖片（匯入時要跳過）。
    static func isDerived(_ json: String?) -> Bool {
        guard let json,
              let data = json.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let kind = root[objectKey] as? String
        else { return false }
        return derivedObjects.contains(kind)
    }

    /// 把圖片的樣式（以及它若是圖表，還有圖表設定）編成區塊外觀 JSON。
    static func encode(_ item: NoteImageAttachment) -> String {
        var style: [String: Any] = [
            "rotationDegrees": item.rotationDegrees,
            "cornerRadius": item.cornerRadius,
            "hasShadow": item.hasShadow,
            "hasBorder": item.hasBorder,
            "filterStyle": item.filterStyle.rawValue,
            "fileName": item.fileName
        ]
        // `nil` 的欄位不寫進去：接收端才分得出「沒設定」與「設成 0」。
        if let value = item.materialType?.rawValue { style["materialType"] = value }
        if let value = item.borderColorHex { style["borderColorHex"] = value }
        if let value = item.borderWidth { style["borderWidth"] = value }
        // "clear" 是哨符不是顏色 —— 原樣帶過去，不要走任何顏色轉換。
        if let value = item.backgroundColorHex { style["backgroundColorHex"] = value }

        var root: [String: Any] = [
            objectKey: item.chartSpecJSON == nil ? imageObject : chartObject,
            imageKey: style
        ]
        if let spec = item.chartSpec {
            root[chartKey] = (try? JSONSerialization.jsonObject(
                with: Data(spec.encodedJSON().utf8))) ?? [:]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// 把 JSON 套回圖片附件。認不得的鍵一律忽略。
    ///
    /// 忽略而不是報錯：另一個平台可能帶了我們還沒實作的欄位，那時該做的是
    /// 保留其餘設定，不是整張圖都不套樣式。
    static func apply(_ json: String, to item: inout NoteImageAttachment) {
        guard let data = json.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return }

        if let chart = root[chartKey],
           let chartData = try? JSONSerialization.data(withJSONObject: chart),
           let text = String(data: chartData, encoding: .utf8) {
            item.chartSpecJSON = text
        }

        guard let style = root[imageKey] as? [String: Any] else { return }
        if let value = style["rotationDegrees"] as? Double { item.rotationDegrees = value }
        if let value = style["cornerRadius"] as? Double { item.cornerRadius = CGFloat(value) }
        if let value = style["hasShadow"] as? Bool { item.hasShadow = value }
        if let value = style["hasBorder"] as? Bool { item.hasBorder = value }
        if let raw = style["filterStyle"] as? String,
           let filter = ImageFilterStyle(rawValue: raw) { item.filterStyle = filter }
        if let raw = style["materialType"] as? String {
            item.materialType = MaterialType(rawValue: raw)
        }
        if let value = style["borderColorHex"] as? String { item.borderColorHex = value }
        if let value = style["borderWidth"] as? Double { item.borderWidth = CGFloat(value) }
        if let value = style["backgroundColorHex"] as? String { item.backgroundColorHex = value }
    }

    /// 這段外觀裡原本的檔名。
    ///
    /// 匯入時圖片的位元組會存成新檔，但**原檔名要留著** —— 不然同一本筆記
    /// 來回同步幾次，每次都會產生一組新檔名，比對與去重就失效了。
    static func fileName(in json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let style = root[imageKey] as? [String: Any]
        else { return nil }
        return style["fileName"] as? String
    }
}

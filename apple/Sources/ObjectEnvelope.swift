//
//  ObjectEnvelope.swift
//  Kairumo
//
//  核心沒有對應區塊型別的物件（連結卡片、3D 模型、錄音卡片、討論圖釘、紙膠帶、
//  便利貼錨點）的**逐物件同步通道**。
//
//  # 為什麼要有這一層
//
//  這些物件原本只存在筆記本中繼資料（`NotebookMeta`）那一份 JSON 裡。中繼資料在核心裡是
//  「最後寫入者贏」的單一暫存器：兩台裝置各改不同的物件，後寫的整包蓋掉先寫的，
//  其中一台的修改就消失，而且沒有任何錯誤訊息。
//
//  # 做法
//
//  每個物件另外寫成**一個衍生圖片區塊**（id 是物件自己的穩定 id），真身（整個 payload）放在
//  該區塊的外觀 JSON 裡。區塊是各自獨立的，所以逐物件合併、位置與內容的差異只動那一個物件，
//  跟文字框、表格走的是同一條路。
//
//  中繼資料裡的清單**照舊寫**：Android 讀的是同一組鍵，而且舊版 App 只認那裡。
//  匯入時以信封為準，清單裡信封沒有的才補上（見 `merged`）。
//
//  衍生圖片區塊的 PNG 只是 PDF 匯出用的後備圖：沒有可視外觀的物件（圖釘、便利貼錨點）
//  放一張 1×1 的透明圖。

import Foundation

enum ObjectEnvelope {

    static let payloadKey = "payload"

    /// 1×1 全透明 PNG。沒有可視外觀的物件用它當後備圖。
    static let transparentPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")!

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // `deferredToDate`：日期存成雙精度浮點數，來回不失真。ISO 8601 會丟掉毫秒，
        // 那樣「內容沒變」的比對永遠不相等，每一輪都會多寫一批操作。
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }()

    /// 編成區塊外觀 JSON。
    static func encode<T: Encodable>(kind: String, fileName: String, payload: T) -> String {
        guard let payloadData = try? encoder.encode(payload),
              let payloadObject = try? JSONSerialization.jsonObject(with: payloadData)
        else { return ImageAppearance.encodeDerived(objectKind: kind, fileName: fileName) }
        let root: [String: Any] = [
            "object": kind,
            "image": ["fileName": fileName],
            payloadKey: payloadObject,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// 取出 payload。不是信封、或內容讀不懂就回 `nil`。
    static func decode<T: Decodable>(_ type: T.Type, kind: String, from json: String?) -> T? {
        guard let object = payloadObject(kind: kind, in: json),
              let data = try? JSONSerialization.data(withJSONObject: object)
        else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// 這個外觀 JSON 是哪一種信封。
    static func kind(of json: String?) -> String? {
        guard let json, let root = rootObject(json), root[payloadKey] != nil else { return nil }
        return root["object"] as? String
    }

    /// payload 的正規化字串（鍵排序）。比對「內容有沒有變」用 —— 不比型別，所以也不怕欄位順序不同。
    static func canonicalPayload(of json: String?) -> String? {
        guard let json, let root = rootObject(json), let object = root[payloadKey] else { return nil }
        return canonical(object)
    }

    static func canonicalPayload<T: Encodable>(_ payload: T) -> String? {
        guard let data = try? encoder.encode(payload),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return canonical(object)
    }

    private static func canonical(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func rootObject(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func payloadObject(kind: String, in json: String?) -> Any? {
        guard let json, let root = rootObject(json),
              (root["object"] as? String) == kind else { return nil }
        return root[payloadKey]
    }

    /// 信封版本與中繼資料清單合併：信封為準，清單裡信封沒有的才補上。
    static func merged<T: Identifiable>(envelopes: [T], legacy: [T]?) -> [T]? where T.ID == String {
        let known = Set(envelopes.map { $0.id.lowercased() })
        let extra = (legacy ?? []).filter { !known.contains($0.id.lowercased()) }
        let all = envelopes + extra
        return all.isEmpty ? nil : all
    }
}

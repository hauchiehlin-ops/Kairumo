//
//  SidebarMetrics.swift
//  Kairumo
//
//  側欄裡可以拖曳的東西。
//

import SwiftUI
import UniformTypeIdentifiers


/// 拖曳一頁時帶著走的東西。
///
/// # 為什麼不是直接拖頁碼字串
///
/// 側欄裡同時有兩種可以拖的東西：頁面與筆記本，而筆記本拖的是 id 字串。
/// 兩種都用 `String` 的話，把一本筆記拖到頁面縮圖上會被當成換頁 ——
/// 型別不同，系統就不會讓它們互相落下，不必自己判斷。
public struct PageDragPayload: Codable, Transferable, Hashable {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .kairumoPageIndex)
    }
}

extension UTType {
    public static let kairumoPageIndex = UTType(exportedAs: "com.kairumo.page-index")
}

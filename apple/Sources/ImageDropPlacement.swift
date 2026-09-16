//
//  ImageDropPlacement.swift
//  Kairumo
//
//  拖進來的圖片要放在哪、放多大（工作項 S-68）。
//
//  # 為什麼要算，不能直接用原圖大小
//
//  手機拍的照片是 4000 像素寬。照著放的話整個頁面被它蓋掉，而使用者要
//  縮很久才看得到自己的字 —— 從插入圖片那條路進來的圖早就有縮放
//  （`ImageStore.insert` 的 `maxWidth`），拖進來的不能是另一套規則。
//
//  # 為什麼要以落點為中心，還要夾回頁內
//
//  使用者拖到哪就是想放哪 —— 一律放在左上角的話，拖放跟按「插入圖片」
//  沒有差別。而以落點為中心的直接後果是：拖到邊邊時圖會有一半在頁面外，
//  那一半在匯出與列印時**會被裁掉**，畫面上卻看得見。所以要夾回去。
//
//  Android 端是同一份規則（見 `image/ImageDropPlacement.kt`）。同一張圖
//  拖到同一個位置，兩台裝置上要落在同一個地方 —— 不然同步之後版面會跑掉。
//

import CoreGraphics

enum ImageDropPlacement {

    /// 拖進來的圖片預設寬度（點）。與插入圖片那條路同一個值。
    static let preferredWidth: CGFloat = 280

    /// - Parameters:
    ///   - dropPoint: 放開的位置，頁面座標。
    ///   - imageSize: 圖片的原始像素大小。
    ///   - pageSize: 頁面大小。
    /// - Returns: 圖片在頁面上的方框。
    static func frame(dropPoint: CGPoint, imageSize: CGSize, pageSize: CGSize) -> CGRect {
        // 比原圖還寬是把圖放大 —— 放大只會讓它糊掉。
        // 同時不超過頁寬的八成，否則在窄頁上一張圖就佔滿整行。
        let width = max(1, min(preferredWidth, max(imageSize.width, 1), pageSize.width * 0.8))
        let aspect = imageSize.height > 0 ? imageSize.height / imageSize.width : 0.75
        let height = max(1, width * aspect)

        // 夾回頁內。圖比頁面還大時（極端的長條圖）靠左上，
        // 不是讓 `max` 與 `min` 打架算出負數。
        let x = min(max(dropPoint.x - width / 2, 0), max(pageSize.width - width, 0))
        let y = min(max(dropPoint.y - height / 2, 0), max(pageSize.height - height, 0))

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

#if canImport(UIKit)
import UIKit

/// 把拖進來的東西變成一張圖。
///
/// 用 `loadObject(ofClass: UIImage.self)` 而不是自己讀 data：拖放的來源
/// 五花八門（相簿、Safari 上的圖、檔案 App、另一個 App 的畫布），各自
/// 提供的型別識別碼不同。`UIImage` 的 `NSItemProviderReading` 認得全部，
/// 自己列型別清單一定會漏掉某一個來源 —— 而漏掉的症狀是「從那個 App
/// 拖過來沒反應」，使用者只會覺得拖放壞了。
enum ImageDropLoader {

    /// 取出第一個載得出來的圖片。全部都載不出來時回傳 `nil`。
    ///
    /// 回呼**保證在主執行緒**：呼叫端拿到圖之後就要改 SwiftUI 狀態。
    static func firstImage(
        from providers: [NSItemProvider],
        completion: @escaping (UIImage?) -> Void
    ) {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: UIImage.self) })
        else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        provider.loadObject(ofClass: UIImage.self) { object, _ in
            DispatchQueue.main.async { completion(object as? UIImage) }
        }
    }
}
#endif

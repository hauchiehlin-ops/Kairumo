//
//  PageGeometry.swift
//  Kairumo
//
//  固定頁面幾何（問題 3＋5）。
//
//  # 問題出在哪裡
//
//  畫布的座標寬度原本就是「視窗寬度」。同一則筆記在 Mac 寬視窗寫的物件座標
//  可能在 x=1400，到了 iPhone 就在畫面外；匯出時再依當下的寬度取一次圖，
//  於是「畫布上看到的」與「匯出的」永遠對不起來。**那不是繪圖程式碼的錯，
//  是座標空間的錯。**
//
//  # 解法
//
//  頁面有一個與視窗無關的固定尺寸。畫布上畫出它的邊界，內容不得超出；
//  匯出與列印就是那個矩形。視窗再怎麼變，頁面不變。
//
//  尺寸取自核心的 `standard_page_size()` —— 兩個平台唯一的來源。各自寫一份
//  常數的話遲早會差一點點，而差一點點的後果就是兩邊的分頁位置不一樣。
//

import CoreGraphics
import Foundation

public enum PageGeometry {

    /// 預設尺寸（A4 直式）。來源是核心，不要在這裡寫死數字。
    public static let defaultSize: CGSize = {
        let values = standardPageSize()
        guard values.count == 2 else { return CGSize(width: 800, height: 1132) }
        return CGSize(width: CGFloat(values[0]), height: CGFloat(values[1]))
    }()

    /// 某個規格的尺寸。
    ///
    /// 認不得的識別字（包含 nil）回 A4 —— 舊筆記沒有這個欄位，而它們全部
    /// 都是用 A4 的座標寫的。回一個零尺寸的頁面會讓畫布整個消失。
    public static func size(forFormat id: String?) -> CGSize {
        guard let id, !id.isEmpty else { return defaultSize }
        let format = pageFormat(id: id)
        return CGSize(width: CGFloat(format.width), height: CGFloat(format.height))
    }

    /// 目前螢幕上這一本筆記的頁面尺寸。
    ///
    /// # 為什麼需要一個「目前」
    ///
    /// 頁面尺寸變成**每本筆記各自的設定**之後，畫布、分頁計算、縮圖與匯出
    /// 這四條路都要拿到同一個值。其中分頁計算（`PageRepagination`）與縮圖
    /// 是純函式，手上沒有筆記本 —— 把筆記本一路傳進去要改十幾個簽名，
    /// 而漏掉其中一個的症狀是「這一頁的分頁位置跟別的地方算的不一樣」。
    ///
    /// 所以由編輯器在開啟筆記與變更規格時設定一次。**只在主執行緒寫**，
    /// 而且畫面上同時只會有一本筆記在編輯。
    ///
    /// # 為什麼是鎖，不是 `@MainActor`
    ///
    /// 原本這裡是 `@MainActor var`，而 `size` 用 `MainActor.assumeIsolated`
    /// 去讀它。那個組合在主執行緒上看起來沒事，離開主執行緒就**直接 trap**
    /// （`dispatch_assert_queue_fail` / SIGTRAP）—— 而且編譯器不會警告，
    /// 因為 `assumeIsolated` 的意思正是「我保證這裡是主執行緒」。
    ///
    /// 這讓同步的匯出搬不出主執行緒（見 H-SYNC-MAINACTOR）：一搬就在
    /// `PageGeometry.width` 上炸掉。改成一把鎖之後，寫的人照樣只有主執行緒，
    /// 但**任何執行緒都讀得到**，而且是編譯器管不到的地方由鎖真的管住。
    private nonisolated(unsafe) static var storedCurrentSize: CGSize = defaultSize
    private nonisolated static let currentSizeLock = NSLock()

    @MainActor
    public static var currentSize: CGSize { size }

    /// 換一本筆記或改了規格時呼叫。
    @MainActor
    public static func use(format id: String?) {
        let next = size(forFormat: id)
        currentSizeLock.withLock { storedCurrentSize = next }
    }

    public nonisolated static var size: CGSize {
        currentSizeLock.withLock { storedCurrentSize }
    }

    public static var width: CGFloat { size.width }
    public static var height: CGFloat { size.height }

    /// 頁面矩形（頁面座標系，原點在左上）。
    public static var rect: CGRect { CGRect(origin: .zero, size: size) }

    /// 可列印邊界的內縮。畫布上畫出來的界線與匯出的邊界就是這一圈。
    ///
    /// 24pt ≈ 8.5mm，比多數印表機的實體不可列印範圍寬一點 —— 目的是讓
    /// 使用者看到的界線是「一定印得出來」的範圍，而不是「理論上的紙張邊緣」。
    public static let printableInset: CGFloat = 24

    /// 可列印區域。
    public static var printableRect: CGRect { rect.insetBy(dx: printableInset, dy: printableInset) }

    // MARK: - 分頁

    /// 某個 y 座標落在第幾頁（由 0 起算）。
    public static func pageIndex(forY y: CGFloat) -> Int {
        guard height > 0 else { return 0 }
        return max(0, Int(floor(y / height)))
    }

    /// 把跨頁的 y 換算成該頁內的 y。
    public static func yWithinPage(_ y: CGFloat) -> CGFloat {
        guard height > 0 else { return y }
        let remainder = y.truncatingRemainder(dividingBy: height)
        return remainder < 0 ? remainder + height : remainder
    }

    /// 這個矩形是否整個落在頁面內。
    public static func fitsInPage(_ rect: CGRect) -> Bool {
        rect.minX >= 0 && rect.minY >= 0
            && rect.maxX <= width && rect.maxY <= height
    }

    /// 把矩形夾進頁面內。
    ///
    /// 比頁面還大的物件夾不進去 —— 那種情況只縮到頁面大小，而不是讓它溢出去。
    /// 溢出的部分在匯出時會被裁掉，使用者看不到自己丟了什麼。
    public static func clamp(_ rect: CGRect) -> CGRect {
        let w = min(rect.width, width)
        let h = min(rect.height, height)
        let x = min(max(rect.minX, 0), width - w)
        let y = min(max(rect.minY, 0), height - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

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

    /// 頁面尺寸（點）。來源是核心，不要在這裡寫死數字。
    public static let size: CGSize = {
        let values = standardPageSize()
        guard values.count == 2 else { return CGSize(width: 800, height: 1132) }
        return CGSize(width: CGFloat(values[0]), height: CGFloat(values[1]))
    }()

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

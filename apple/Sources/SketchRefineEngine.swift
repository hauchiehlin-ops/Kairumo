//
//  SketchRefineEngine.swift
//  Kairumo
//
//  手繪草圖美化：幾何辨識與抗抖動平滑。
//
//  **演算法在核心**（`padnote-ink::refine`），這裡只負責 PencilKit 的進出。
//  原本整套幾何都寫在這個檔案裡，Android 沒有對應品 —— 同一個歪圓在 iPad 上
//  被拉正、在 Android 上還是歪的。下沉之後兩邊判定完全一樣。
//
//  順帶修掉一個一直存在的缺陷：舊版是「先測橢圓，過門檻就收工」，
//  而那個門檻寬到連軸對齊矩形都過得了 —— 畫方框會被美化成橢圓，
//  底下的矩形分支幾乎是死碼。核心改成兩種圖形一起評分取誤差小的。
//

import PencilKit
import SwiftUI

public enum SketchRefineEngine {

    /// 美化整張 `PKDrawing`。
    /// - Parameters:
    ///   - drawing: 原始手繪
    ///   - intensity: 修飾強度 0…1（預設 0.85）
    public static func refine(drawing: PKDrawing, intensity: CGFloat = 0.85) -> PKDrawing {
        guard !drawing.strokes.isEmpty else { return drawing }

        var refinedStrokes: [PKStroke] = []
        for stroke in drawing.strokes {
            let path = stroke.path
            // 兩個點沒有形狀可言，核心也會原樣回傳；在這裡先擋掉省一次跨語言呼叫。
            guard path.count >= 3 else {
                refinedStrokes.append(stroke)
                continue
            }

            let input = (0..<path.count).map { i in
                FfiPoint(x: Float(path[i].location.x), y: Float(path[i].location.y))
            }
            let result = sketchRefineStroke(points: input, intensity: Float(intensity))

            if let newStroke = rebuild(stroke, at: result.points) {
                refinedStrokes.append(newStroke)
            } else {
                refinedStrokes.append(stroke)
            }
        }
        return PKDrawing(strokes: refinedStrokes)
    }

    /// 美化單一筆劃並回傳辨識結果。
    /// - Returns: `(refinedStroke, kind)` — `kind` 為 `.freehand` 表示未辨識出圖形。
    public static func refineSingleStroke(_ stroke: PKStroke, intensity: CGFloat = 0.85) -> (PKStroke, FfiRefinedKind)? {
        let path = stroke.path
        guard path.count >= 3 else { return nil }
        let input = (0..<path.count).map { i in
            FfiPoint(x: Float(path[i].location.x), y: Float(path[i].location.y))
        }
        let result = sketchRefineStroke(points: input, intensity: Float(intensity))
        guard let newStroke = rebuild(stroke, at: result.points) else { return nil }
        return (newStroke, result.kind)
    }

    /// 把新座標套回原筆畫。
    ///
    /// 壓感、時間戳、方位角、傾角全部沿用原本的取樣點 —— 核心保證輸出點數
    /// 與輸入相同，所以索引可以直接對應；只換位置，筆觸的手感不變。
    fileprivate static func rebuild(_ stroke: PKStroke, at points: [FfiPoint]) -> PKStroke? {
        guard points.count >= 2 else { return nil }
        let origPath = stroke.path
        let strokePoints = points.enumerated().map { (i, pt) -> PKStrokePoint in
            let sample = origPath[min(origPath.count - 1, i)]
            return PKStrokePoint(
                location: CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)),
                timeOffset: sample.timeOffset,
                size: sample.size,
                opacity: sample.opacity,
                force: sample.force,
                azimuth: sample.azimuth,
                altitude: sample.altitude
            )
        }
        let newPath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: stroke.ink, path: newPath, transform: stroke.transform, mask: stroke.mask)
    }
}

//
//  SketchRefineEngine.swift
//  Kairumo
//
//  手繪草圖智慧幾何識別、曲線平滑化與修飾修正引擎
//  支援一鍵修飾 (Apply)、重做 (Redo)、恢復原草圖 (Restore)
//

import SwiftUI
import PencilKit

public class SketchRefineEngine {

    /// 智慧大幅度修飾畫布筆跡
    /// - Parameters:
    ///   - drawing: 原始手繪 PKDrawing
    ///   - intensity: 修飾強度 (0.1 ~ 1.0，預設 0.85)
    /// - Returns: 修飾後之精美幾何與平滑向量 PKDrawing
    public static func refine(drawing: PKDrawing, intensity: CGFloat = 0.85) -> PKDrawing {
        guard !drawing.strokes.isEmpty else { return drawing }

        var refinedStrokes: [PKStroke] = []

        for stroke in drawing.strokes {
            let path = stroke.path
            let count = path.count
            guard count >= 3 else {
                refinedStrokes.append(stroke)
                continue
            }

            var points: [CGPoint] = []
            var timeStamps: [TimeInterval] = []
            for i in 0..<count {
                let pt = path[i]
                points.append(pt.location)
                timeStamps.append(pt.timeOffset)
            }

            let ink = stroke.ink
            let strokeWidth = path[0].size.width

            // 1. 嘗試幾何圖形辨識 (正圓/橢圓、矩形、直線)
            if let shapePoints = detectAndGenerateGeometricShape(points: points, count: count) {
                // 將幾何點與原手繪點按 intensity 進行平滑融合
                let finalPoints = blendPoints(original: points, target: shapePoints, intensity: intensity)
                if let newStroke = createStroke(from: finalPoints, ink: ink, baseWidth: strokeWidth, originalStroke: stroke) {
                    refinedStrokes.append(newStroke)
                    continue
                }
            }

            // 2. 自由曲線樣條平滑化 (消除抖動與毛刺)
            let smoothed = smoothCurve(points: points, intensity: intensity)
            if let newStroke = createStroke(from: smoothed, ink: ink, baseWidth: strokeWidth, originalStroke: stroke) {
                refinedStrokes.append(newStroke)
            } else {
                refinedStrokes.append(stroke)
            }
        }

        return PKDrawing(strokes: refinedStrokes)
    }

    // MARK: - 幾何圖形偵測與重繪
    private static func detectAndGenerateGeometricShape(points: [CGPoint], count: Int) -> [CGPoint]? {
        // 空陣列會讓 first!/last! 直接當掉；筆畫在擦除或極短點擊時真的可能是空的
        guard let first = points.first, let last = points.last else { return nil }
        let startEndDistance = hypot(first.x - last.x, first.y - last.y)

        // 計算邊界與中心
        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        var totalLength: CGFloat = 0

        for i in 0..<count {
            let p = points[i]
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
            if i > 0 {
                totalLength += hypot(p.x - points[i - 1].x, p.y - points[i - 1].y)
            }
        }

        let width = maxX - minX
        let height = maxY - minY
        let diag = hypot(width, height)
        guard diag > 20 else { return nil }

        // 判定 A: 直線 (起訖點距離與路徑總長極度接近)
        let straightRatio = startEndDistance / max(1, totalLength)
        if straightRatio > 0.88 && count >= 5 {
            return generateEquallySpacedLine(from: first, to: last, count: count)
        }

        // 判定 B: 閉合曲線 (起訖點距離小於對角線 25%)
        let isClosed = startEndDistance < diag * 0.28

        if isClosed && count >= 10 {
            let centerX = (minX + maxX) / 2.0
            let centerY = (minY + maxY) / 2.0
            let radiusX = width / 2.0
            let radiusY = height / 2.0

            // 測試圓形/橢圓擬合方差
            var radialVariance: CGFloat = 0
            for p in points {
                let dx = (p.x - centerX) / max(1, radiusX)
                let dy = (p.y - centerY) / max(1, radiusY)
                let normalizedDist = hypot(dx, dy)
                radialVariance += abs(normalizedDist - 1.0)
            }
            let avgVariance = radialVariance / CGFloat(count)

            if avgVariance < 0.28 {
                // 判定為圓形或橢圓！
                let isCircle = abs(width - height) / max(width, height) < 0.22
                let finalRx = isCircle ? (radiusX + radiusY) / 2 : radiusX
                let finalRy = isCircle ? finalRx : radiusY
                return generateEllipse(centerX: centerX, centerY: centerY, rx: finalRx, ry: finalRy, count: count)
            }

            // 測試矩形擬合
            if isRoughRectangle(points: points, minX: minX, maxX: maxX, minY: minY, maxY: maxY) {
                return generateRectangle(minX: minX, maxX: maxX, minY: minY, maxY: maxY, count: count)
            }
        }

        return nil
    }

    private static func isRoughRectangle(points: [CGPoint], minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) -> Bool {
        var onEdgeCount = 0
        let threshold: CGFloat = max(8, hypot(maxX - minX, maxY - minY) * 0.12)
        for p in points {
            let nearLeft = abs(p.x - minX) < threshold
            let nearRight = abs(p.x - maxX) < threshold
            let nearTop = abs(p.y - minY) < threshold
            let nearBottom = abs(p.y - maxY) < threshold
            if nearLeft || nearRight || nearTop || nearBottom {
                onEdgeCount += 1
            }
        }
        return CGFloat(onEdgeCount) / CGFloat(points.count) > 0.72
    }

    private static func generateEquallySpacedLine(from start: CGPoint, to end: CGPoint, count: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(count - 1)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }

    private static func generateEllipse(centerX: CGFloat, centerY: CGFloat, rx: CGFloat, ry: CGFloat, count: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        for i in 0..<count {
            let angle = (CGFloat(i) / CGFloat(count)) * CGFloat.pi * 2.0
            let x = centerX + rx * cos(angle)
            let y = centerY + ry * sin(angle)
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }

    private static func generateRectangle(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat, count: Int) -> [CGPoint] {
        let corners = [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: minX, y: minY)
        ]
        let segmentCount = max(2, count / 4)
        var result: [CGPoint] = []
        for i in 0..<4 {
            let p1 = corners[i]
            let p2 = corners[i + 1]
            for s in 0..<segmentCount {
                let t = CGFloat(s) / CGFloat(segmentCount)
                result.append(CGPoint(x: p1.x + (p2.x - p1.x) * t, y: p1.y + (p2.y - p1.y) * t))
            }
        }
        return result
    }

    // MARK: - 曲線抗抖動平滑演算法
    private static func smoothCurve(points: [CGPoint], intensity: CGFloat) -> [CGPoint] {
        guard points.count >= 4 else { return points }
        var smoothed: [CGPoint] = points

        let windowSize = min(5, points.count / 2)
        for i in 1..<(points.count - 1) {
            let startIdx = max(0, i - windowSize)
            let endIdx = min(points.count - 1, i + windowSize)
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            var wSum: CGFloat = 0

            for j in startIdx...endIdx {
                let dist = abs(CGFloat(j - i))
                let weight = max(0.1, 1.0 - dist / CGFloat(windowSize + 1))
                sumX += points[j].x * weight
                sumY += points[j].y * weight
                wSum += weight
            }

            let avgX = sumX / wSum
            let avgY = sumY / wSum
            let orig = points[i]
            smoothed[i] = CGPoint(
                x: orig.x * (1.0 - intensity) + avgX * intensity,
                y: orig.y * (1.0 - intensity) + avgY * intensity
            )
        }

        return smoothed
    }

    private static func blendPoints(original: [CGPoint], target: [CGPoint], intensity: CGFloat) -> [CGPoint] {
        var blended: [CGPoint] = []
        let origCount = original.count
        let targetCount = target.count

        for i in 0..<origCount {
            let targetIdx = min(targetCount - 1, Int((CGFloat(i) / CGFloat(origCount)) * CGFloat(targetCount)))
            let o = original[i]
            let t = target[targetIdx]
            let bx = o.x * (1.0 - intensity) + t.x * intensity
            let by = o.y * (1.0 - intensity) + t.y * intensity
            blended.append(CGPoint(x: bx, y: by))
        }
        return blended
    }

    private static func createStroke(from points: [CGPoint], ink: PKInk, baseWidth: CGFloat, originalStroke: PKStroke) -> PKStroke? {
        guard points.count >= 2 else { return nil }
        var strokePoints: [PKStrokePoint] = []
        let origPath = originalStroke.path
        let origCount = origPath.count

        for (i, pt) in points.enumerated() {
            let sampleIdx = min(origCount - 1, i)
            let samplePt = origPath[sampleIdx]
            let strokePt = PKStrokePoint(
                location: pt,
                timeOffset: samplePt.timeOffset,
                size: samplePt.size,
                opacity: samplePt.opacity,
                force: samplePt.force,
                azimuth: samplePt.azimuth,
                altitude: samplePt.altitude
            )
            strokePoints.append(strokePt)
        }

        let newPath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: ink, path: newPath, transform: originalStroke.transform, mask: originalStroke.mask)
    }
}

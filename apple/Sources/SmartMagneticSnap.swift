//
//  SmartMagneticSnap.swift
//  Kairumo
//
//  次世代筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap & Ruler)。
//  當筆畫接近水平、垂直、45° 或紙張格線時，自動磁吸吸附並給予觸覺反饋與光導引。
//

import CoreGraphics
import SwiftUI

public struct MagneticSnapResult: Equatable {
    public let snappedPoint: CGPoint
    public let snappedAngleDegrees: Double?
    public let didSnap: Bool

    public init(snappedPoint: CGPoint, snappedAngleDegrees: Double?, didSnap: Bool) {
        self.snappedPoint = snappedPoint
        self.snappedAngleDegrees = snappedAngleDegrees
        self.didSnap = didSnap
    }
}

public enum SmartMagneticSnap {
    private static let canonicalAngles: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
    private static let angleToleranceDegrees: Double = 6.0
    private static let gridStep: CGFloat = 20.0

    public static func snap(start: CGPoint, current: CGPoint, enableGrid: Bool = true) -> MagneticSnapResult {
        let dx = current.x - start.x
        let dy = current.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 18 else {
            return MagneticSnapResult(snappedPoint: current, snappedAngleDegrees: nil, didSnap: false)
        }

        let angleRad = atan2(dy, dx)
        var angleDeg = angleRad * 180.0 / .pi
        if angleDeg < 0 { angleDeg += 360 }

        var bestAngle: Double? = nil
        for canonical in canonicalAngles {
            let diff = abs(angleDeg - canonical)
            let wrapDiff = min(diff, 360 - diff)
            if wrapDiff <= angleToleranceDegrees {
                bestAngle = canonical
                break
            }
        }

        if let angle = bestAngle {
            let rad = angle * .pi / 180.0
            var snappedX = start.x + cos(rad) * distance
            var snappedY = start.y + sin(rad) * distance
            if enableGrid {
                snappedX = round(snappedX / gridStep) * gridStep
                snappedY = round(snappedY / gridStep) * gridStep
            }
            return MagneticSnapResult(
                snappedPoint: CGPoint(x: snappedX, y: snappedY),
                snappedAngleDegrees: angle,
                didSnap: true
            )
        }

        if enableGrid {
            let snappedX = round(current.x / gridStep) * gridStep
            let snappedY = round(current.y / gridStep) * gridStep
            if abs(snappedX - current.x) < 5 && abs(snappedY - current.y) < 5 {
                return MagneticSnapResult(
                    snappedPoint: CGPoint(x: snappedX, y: snappedY),
                    snappedAngleDegrees: nil,
                    didSnap: true
                )
            }
        }

        return MagneticSnapResult(snappedPoint: current, snappedAngleDegrees: nil, didSnap: false)
    }
}

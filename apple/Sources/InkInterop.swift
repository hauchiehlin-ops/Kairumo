//
//  InkInterop.swift
//  Kairumo
//
//  PencilKit ⇄ 核心筆畫格式的轉換（工作包 WP4）。
//
//  # 為什麼這支程式一定要寫在 Apple 端
//
//  `PKDrawing` 的二進位只有 PencilKit 解析得了，Android 沒有任何途徑。所以
//  「兩個平台打得開同一份筆記」這件事，轉換器只能寫在這裡 —— 這條相依關係
//  繞不過去。
//
//  # 它不改變現有行為
//
//  這是一個純函式集合：讀 `PKDrawing`、產生核心要的資料；或反過來。它不碰
//  `NotebookStore` 的儲存路徑，也不碰畫布。既有的 iOS / iPadOS / macOS 功能
//  走的還是原本那條路，這裡只是多開了一個出口。
//

import Foundation
import PencilKit
import UIKit

/// 一筆待寫入核心的筆畫（尚未有 id —— id 由核心產生）。
///
/// 刻意不宣告 `Equatable`：`StrokePoint` 是 UniFFI 產生的型別、本身沒有
/// `Equatable`，而且筆畫比對本來就該逐欄位講清楚容差（座標要完全相同、
/// 壓感與角度只能要求在一個量化格內），不適合用 `==` 一筆帶過。
struct CoreStrokeDraft {
    var tool: ToolKind
    /// RGBA 各 0–255，固定 4 個位元組。型別配合 UniFFI 的 `Data`，
    /// 直接餵給 `addStroke(pageId:tool:colorRgba:baseWidth:points:)`。
    var colorRgba: Data
    var baseWidth: Float
    var points: [StrokePoint]
}

enum InkInterop {

    // MARK: - 寬度與壓感的對應

    /// 核心 `half_width()` 的壓感曲線：`width = base × (0.35 + 0.65 × pressure)`。
    ///
    /// 這兩個常數不是隨手取的，是 `padnote-ink/src/geometry.rs` 裡真正在用的值。
    /// 轉換時必須照著它反推壓感，Android 畫出來的粗細才會跟 iPad 上一樣；
    /// 若改用「壓感 = 寬度比例」這種直覺寫法，同一筆畫在 Android 會偏細。
    static let widthFloorRatio: Float = 0.35
    static let widthPressureSpan: Float = 0.65

    /// PencilKit 的每點寬度 → 核心壓感。
    ///
    /// 刻意不用 `PKStrokePoint.force`：PencilKit 沒有公開 force 的數值範圍，
    /// 不同裝置與輸入方式（手指 / Apple Pencil）也不一致，硬夾到 0–1 會讓
    /// 重壓的筆畫整段飽和。寬度則是 PencilKit **實際畫出來**的結果，
    /// 拿它回推壓感，往返後粗細才對得起來。
    static func pressure(forWidth width: Float, baseWidth: Float) -> Float {
        guard baseWidth > 0 else { return 1 }
        let ratio = width / baseWidth
        let p = (ratio - widthFloorRatio) / widthPressureSpan
        return min(max(p, 0), 1)
    }

    /// 核心壓感 → 寬度（上面那條式子的反向）。
    static func width(forPressure pressure: Float, baseWidth: Float, tool: ToolKind) -> Float {
        guard isPressureSensitive(tool) else { return baseWidth }
        let p = min(max(pressure, 0), 1)
        return baseWidth * (widthFloorRatio + widthPressureSpan * p)
    }

    /// 與核心 `Tool::is_pressure_sensitive()` 一致。
    static func isPressureSensitive(_ tool: ToolKind) -> Bool {
        switch tool {
        case .fountainPen, .pencil, .brush, .watercolor: return true
        case .ballPoint, .highlighter, .marker: return false
        }
    }

    // MARK: - 筆刷對應

    static func toolKind(for inkType: PKInk.InkType) -> ToolKind {
        switch inkType {
        case .pen: return .fountainPen
        case .pencil: return .pencil
        case .marker: return .marker
        default:
            // iOS 17 之後多出來的筆種。用 rawValue 比對，才不會為了幾個
            // 列舉值把整個檔案綁死在新版 SDK 上。
            switch inkType.rawValue {
            case "com.apple.ink.monoline": return .ballPoint
            case "com.apple.ink.fountainpen": return .brush
            case "com.apple.ink.watercolor": return .watercolor
            case "com.apple.ink.crayon": return .pencil
            default: return .fountainPen
            }
        }
    }

    static func inkType(for tool: ToolKind) -> PKInk.InkType {
        switch tool {
        case .fountainPen: return .pen
        case .ballPoint: return .pen      // 固定寬度由壓感恆為 1 表現
        case .highlighter: return .marker
        case .pencil: return .pencil
        case .brush:
            if #available(iOS 17.0, *) {
                return .fountainPen
            } else {
                return .pen
            }
        case .marker: return .marker
        case .watercolor:
            if #available(iOS 17.0, *) {
                return .watercolor
            } else {
                return .marker
            }
        }
    }

    // MARK: - 顏色

    /// UIColor → RGBA 0–255。
    ///
    /// 一定要先轉進 sRGB：深色模式下的動態顏色、P3 色域的顏色直接取分量會拿到
    /// 另一組數字，Android 那邊就會變色。
    static func rgba(from color: UIColor) -> Data {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        let resolved: UIColor
        if let converted = color.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ) {
            resolved = UIColor(cgColor: converted)
        } else {
            resolved = color
        }
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        let to255: (CGFloat) -> UInt8 = { UInt8(min(max($0, 0), 1) * 255 + 0.5) }
        return Data([to255(r), to255(g), to255(b), to255(a)])
    }

    static func color(fromRGBA bytes: Data) -> UIColor {
        let raw = Array(bytes)
        let c = raw.count >= 4 ? raw : raw + Array(repeating: UInt8(255), count: 4 - raw.count)
        return UIColor(
            red: CGFloat(c[0]) / 255,
            green: CGFloat(c[1]) / 255,
            blue: CGFloat(c[2]) / 255,
            alpha: CGFloat(c[3]) / 255
        )
    }

    // MARK: - PKDrawing → 核心

    /// 把一筆 `PKStroke` 轉成核心要的資料。
    ///
    /// 取的是 `path` 的**控制點**而不是插值後的樣本：控制點就是 PencilKit
    /// 自己存的東西，照搬才不會在轉換時偷偷重新取樣。
    static func draft(from stroke: PKStroke) -> CoreStrokeDraft {
        let transform = stroke.transform
        let controlPoints = Array(stroke.path)

        let widths = controlPoints.map { Float($0.size.width) }
        let baseWidth = max(widths.max() ?? 1, Float.ulpOfOne)

        var points: [StrokePoint] = []
        points.reserveCapacity(controlPoints.count)
        var previousOffset: TimeInterval? = nil

        for cp in controlPoints {
            let location = cp.location.applying(transform)
            // 格式規格 §5.4 的 dt 是 u16 微秒，上限 65535µs（約 65ms）。
            // 超過就夾住 —— 那代表使用者中途停筆，時間差本來就不具意義。
            let deltaSeconds = previousOffset.map { cp.timeOffset - $0 } ?? 0
            let dtUs = UInt32(min(max(deltaSeconds, 0) * 1_000_000, 65_535))
            previousOffset = cp.timeOffset

            points.append(
                StrokePoint(
                    x: Float(location.x),
                    y: Float(location.y),
                    pressure: pressure(forWidth: Float(cp.size.width), baseWidth: baseWidth),
                    // PencilKit 的 altitude 是「與螢幕平面的夾角」（π/2 為垂直握筆），
                    // 核心的 tilt 是「偏離垂直的角度」。兩者是互補角，不是同一個東西。
                    tilt: Float(min(max(.pi / 2 - cp.altitude, 0), .pi / 2)),
                    azimuth: Float(normalizedAzimuth(cp.azimuth)),
                    dtUs: dtUs,
                    // 滾動角（Pencil Pro）。PencilKit 的控制點在 iOS 17.5 起
                    // 有 `rollAngle`；其他筆與更舊的系統回報不出來，一律是 0。
                    //
                    // 核心那邊 **0 就是「沒有這個維度」**，不是「角度剛好是零」
                    // —— 扁頭筆的筆觸角度會退回只看傾角，而不是被硬轉成 0 度。
                    // 見下面 `rollAngle(of:)`：PencilKit 這條路上拿不到，一律 0。
                    roll: Float(Self.rollAngle(of: cp))
                )
            )
        }

        return CoreStrokeDraft(
            tool: toolKind(for: stroke.ink.inkType),
            colorRgba: rgba(from: stroke.ink.color),
            baseWidth: baseWidth,
            points: points
        )
    }

    /// 整份手繪內容 → 核心筆畫清單，順序即繪製順序。
    static func drafts(from drawing: PKDrawing) -> [CoreStrokeDraft] {
        drawing.strokes.map(draft(from:))
    }

    // MARK: - 核心 → PKDrawing

    /// 把核心讀回來的一筆畫還原成 `PKStroke`。
    static func stroke(from full: FullStroke, creationDate: Date = Date(timeIntervalSince1970: 0)) -> PKStroke {
        var offset: TimeInterval = 0
        var controlPoints: [PKStrokePoint] = []
        controlPoints.reserveCapacity(full.points.count)

        for p in full.points {
            offset += TimeInterval(p.dtUs) / 1_000_000
            let w = CGFloat(width(forPressure: p.pressure, baseWidth: full.baseWidth, tool: full.tool))
            controlPoints.append(
                PKStrokePoint(
                    location: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)),
                    timeOffset: offset,
                    size: CGSize(width: w, height: w),
                    opacity: 1,
                    force: CGFloat(p.pressure),
                    azimuth: CGFloat(p.azimuth),
                    altitude: CGFloat(.pi / 2 - min(max(p.tilt, 0), Float.pi / 2))
                )
            )
            // 滾動角**沒有還原回去**：`PKStrokePoint` 沒有這個欄位。
            // 詳見下面 `rollAngle(of:)` 的說明。
        }

        let path = PKStrokePath(controlPoints: controlPoints, creationDate: creationDate)
        let ink = PKInk(inkType(for: full.tool), color: color(fromRGBA: full.colorRgba))
        return PKStroke(ink: ink, path: path)
    }

    /// 核心筆畫清單 → 可直接丟進畫布的 `PKDrawing`。
    static func drawing(from strokes: [FullStroke]) -> PKDrawing {
        PKDrawing(strokes: strokes.map { stroke(from: $0) })
    }

    // MARK: - 私有

    /// 這一筆畫的滾動角。**目前一律是 0。**
    ///
    /// # 為什麼不是「還沒做」而是「做不到」
    ///
    /// 滾動角在系統裡只出現在 `UITouch.rollAngle` 上。`PKStrokePoint`
    /// **沒有這個欄位** —— PencilKit 自己把觸控收成筆畫，中間不經過我們，
    /// 所以沒有任何地方能把 `UITouch` 的滾動角對應回某一個控制點。
    ///
    /// 硬做的話只能「記下最後看到的滾動角，整筆套用」，那是錯的：使用者
    /// 寫一個字的過程中本來就會轉筆，整筆同一個角度比沒有還糟 —— 它會讓
    /// 扁頭筆的筆觸方向在一筆之內完全不變，看起來像壞掉。
    ///
    /// 所以這條路上滾動角**只用在即時的地方**（懸停預覽的筆頭方向、
    /// 診斷列），不寫進筆畫。格式那一層已經備好（見核心 `EXT_ROLL`），
    /// Android 自己收觸控，寫得進去。
    ///
    /// 要在這一邊也存得下來，前提是不再用 PencilKit 收筆畫 —— 那是另一個
    /// 量級的決定，不在這裡順手做。
    private static func rollAngle(of cp: PKStrokePoint) -> CGFloat {
        0
    }

    /// 把方位角收進 0–2π。PencilKit 可能回傳負值，核心格式的範圍是 0–2π。
    private static func normalizedAzimuth(_ radians: CGFloat) -> CGFloat {
        let tau = CGFloat.pi * 2
        let r = radians.truncatingRemainder(dividingBy: tau)
        return r < 0 ? r + tau : r
    }
}

//
//  FrameGovernor.swift
//  Kairumo
//
//  執行期自我調節（即時響應架構 · 原則 7）。
//
//  # 為什麼
//
//  不同裝置、不同系統版本、不同負載下，「做得起」的量不一樣，不可能事先為每一種寫死參數。
//  所以讓每台裝置在**執行時**看自己的幀表現：連續掉幀就降低非必要工作的強度（縮圖解析度、
//  縮圖逐張之間的間隔），表現恢復後再升回來。筆跡本身永遠不降級。
//
//  # 做法
//
//  `CADisplayLink` 每幀回報實際幀間隔；滑動視窗內「超過目標幀時間 1.5 倍」的比例過高就進入
//  `constrained`，低於較低門檻才離開（遲滯，避免來回跳）。判斷邏輯是純函式（`ingest`），可單元測試。
//

import QuartzCore
import UIKit

final class FrameGovernor {
    enum Level: Equatable { case normal, constrained }

    // profile-scope: device 幀表現調節，不含使用者資料
    @MainActor static let shared = FrameGovernor()

    private(set) var level: Level = .normal
    private let window: Int
    private let enterRatio: Double
    private let exitRatio: Double
    private var recentOver: [Bool] = []
    private var overCount = 0

    init(window: Int = 60, enterRatio: Double = 0.25, exitRatio: Double = 0.05) {
        self.window = window
        self.enterRatio = enterRatio
        self.exitRatio = exitRatio
    }

    /// 餵一幀的實際間隔與目標間隔（秒）。回傳目前等級。
    @discardableResult
    func ingest(frameDuration: Double, target: Double) -> Level {
        let over = frameDuration > target * 1.5
        recentOver.append(over)
        if over { overCount += 1 }
        if recentOver.count > window {
            if recentOver.removeFirst() { overCount -= 1 }
        }
        guard recentOver.count >= window / 2 else { return level }
        let ratio = Double(overCount) / Double(recentOver.count)
        switch level {
        case .normal where ratio >= enterRatio: level = .constrained
        case .constrained where ratio <= exitRatio: level = .normal
        default: break
        }
        return level
    }

    /// 縮圖解析度倍率（相對於正常）。
    var thumbnailScaleFactor: CGFloat { level == .constrained ? 0.75 : 1 }
    /// 縮圖逐張之間多等多久（秒）。
    var thumbnailGap: TimeInterval { level == .constrained ? 0.06 : 0 }

    // MARK: 顯示連結（只在編輯器開著時跑）

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    @MainActor func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: GovernorTarget(self), selector: #selector(GovernorTarget.tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        lastTimestamp = 0
    }

    @MainActor func stop() {
        link?.invalidate()
        link = nil
        recentOver.removeAll(); overCount = 0; level = .normal
    }

    fileprivate func tick(_ l: CADisplayLink) {
        defer { lastTimestamp = l.timestamp }
        guard lastTimestamp > 0 else { return }
        let target = l.targetTimestamp - l.timestamp
        guard target > 0 else { return }
        let dt = l.timestamp - lastTimestamp
        // 切到背景再回來的第一幀間隔會很大，不是掉幀。
        guard dt < 1 else { return }
        ingest(frameDuration: dt, target: target)
    }
}

private final class GovernorTarget: NSObject {
    weak var owner: FrameGovernor?
    init(_ owner: FrameGovernor) { self.owner = owner }
    @objc func tick(_ l: CADisplayLink) { owner?.tick(l) }
}

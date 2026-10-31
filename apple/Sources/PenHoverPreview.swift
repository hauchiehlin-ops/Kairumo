//
//  PenHoverPreview.swift
//  Kairumo
//
//  懸停預覽：筆尖靠近但還沒碰到螢幕時，先顯示會落在哪裡（工作項 S-69）。
//
//  # 為什麼需要
//
//  核心的仲裁器早就有 `Verdict::Hover`，說明寫著「顯示落筆預覽，不產生
//  筆跡」—— 但**沒有任何平台真的畫過那個預覽**。硬體會回報懸停，判定也
//  分類好了，然後那個結果被丟掉。
//
//  對使用者來說的差別：不知道筆尖會落在哪，就只能先點一下看看。一筆下去
//  才發現位置不對，那一筆已經在紙上了 —— 而 undo 一次的成本遠高於「先看
//  一眼」。手寫筆記尤其明顯：對齊既有的字、接一條線、點一個小按鈕。
//
//  # 為什麼是 `UIHoverGestureRecognizer` 而不是 `UIPointerInteraction`
//
//  畫布上已經有一個 `UIPointerInteraction`，那是給**滑鼠游標**用的：它把
//  系統游標換成筆頭形狀。但觸控筆的懸停不會產生系統游標 —— 指標互動那條
//  路根本不會被呼叫，所以筆懸在螢幕上方時什麼也不會發生。
//
//  兩者要並存：接滑鼠的人要游標，拿筆的人要預覽。
//
//  # 傾角要跟著畫
//
//  懸停時系統就已經給得出 `altitudeAngle` 與 `azimuthAngle`。把筆頭照那個
//  角度傾斜畫出來，使用者才看得出扁頭筆現在是哪個方向 —— 只畫一個圓點的話，
//  麥克筆與螢光筆的預覽長得一模一樣，而它們的筆觸完全不同。
//

import UIKit

/// 疊在畫布上的一層懸停預覽。**不吃任何觸控。**
final class PenHoverPreviewView: UIView {

    private let shape = CAShapeLayer()
    private let reticleLayer = CAShapeLayer()
    /// 橡皮擦範圍：淡底色＋外白內深雙環，深色筆跡與白紙上都看得清楚。
    private let eraserFill = CAShapeLayer()
    private let eraserOuter = CAShapeLayer()
    private let eraserInner = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 這一層是純視覺的。可命中的話，畫布就收不到筆畫了 ——
        // 症狀是「筆在螢幕上畫不出東西」，而且找不到原因。
        isUserInteractionEnabled = false
        backgroundColor = .clear
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = 1
        layer.addSublayer(shape)

        // 圖學／幾何磁吸十字準心（提供「所見即所得」的預先反饋）
        reticleLayer.fillColor = UIColor.clear.cgColor
        reticleLayer.lineWidth = 1.2
        reticleLayer.strokeColor = UIColor.systemTeal.withAlphaComponent(0.85).cgColor
        layer.addSublayer(reticleLayer)
        reticleLayer.isHidden = true

        eraserFill.fillColor = UIColor.systemBlue.withAlphaComponent(0.10).cgColor
        eraserFill.strokeColor = nil
        eraserOuter.fillColor = UIColor.clear.cgColor
        eraserOuter.strokeColor = UIColor.white.withAlphaComponent(0.95).cgColor
        eraserOuter.lineWidth = 2.6
        eraserInner.fillColor = UIColor.clear.cgColor
        eraserInner.strokeColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 0.85).cgColor
        eraserInner.lineWidth = 1.2
        for l in [eraserFill, eraserOuter, eraserInner] {
            l.isHidden = true
            layer.addSublayer(l)
        }

        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("不從 storyboard 建立") }

    /// 更新預覽。
    ///
    /// - Parameters:
    ///   - point: 筆尖在這個視圖座標系裡的落點。
    ///   - path: 筆頭形狀，`nil`（套索）時不畫。
    ///   - tilt: 偏離垂直的角度，0 為垂直握筆。
    ///   - azimuth: 筆桿的方位角。
    ///   - color: 目前的墨色。
    ///   - snapPoint: 專業圖學或磁吸格線對齊目標點（若存在，呈現吸附十字準心）。
    func show(
        at point: CGPoint,
        path: UIBezierPath?,
        tilt: CGFloat,
        azimuth: CGFloat,
        color: UIColor,
        snapPoint: CGPoint? = nil
    ) {
        guard let path else {
            hide()
            return
        }

        let transformed = UIBezierPath(cgPath: path.cgPath)
        // 先照筆桿方位轉，再依傾角把筆頭壓扁 —— 順序反過來會壓在錯的軸上，
        // 看起來像筆頭忽然變細。
        var t = CGAffineTransform(rotationAngle: azimuth)
        // 垂直握筆（tilt = 0）不壓；越躺越扁，但留一個下限，
        // 否則筆躺平時預覽會細到看不見。
        let squash = max(cos(tilt), 0.35)
        t = t.concatenating(CGAffineTransform(scaleX: 1, y: squash))
        transformed.apply(t)
        transformed.apply(CGAffineTransform(translationX: point.x, y: point.y))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        setEraserHidden(true)
        shape.isHidden = false
        shape.path = transformed.cgPath
        // 只描邊、不填滿：填滿的預覽會把它自己要對齊的那個字蓋住。
        shape.strokeColor = color.withAlphaComponent(0.55).cgColor

        // 繪製磁吸準心（所見即所得吸附指示）
        if let snap = snapPoint {
            let reticle = UIBezierPath(arcCenter: snap, radius: 5.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            // 十字刻度線
            reticle.move(to: CGPoint(x: snap.x - 11, y: snap.y))
            reticle.addLine(to: CGPoint(x: snap.x - 6, y: snap.y))
            reticle.move(to: CGPoint(x: snap.x + 6, y: snap.y))
            reticle.addLine(to: CGPoint(x: snap.x + 11, y: snap.y))
            reticle.move(to: CGPoint(x: snap.x, y: snap.y - 11))
            reticle.addLine(to: CGPoint(x: snap.x, y: snap.y - 6))
            reticle.move(to: CGPoint(x: snap.x, y: snap.y + 6))
            reticle.addLine(to: CGPoint(x: snap.x, y: snap.y + 11))
            reticleLayer.path = reticle.cgPath
            reticleLayer.isHidden = false
        } else {
            reticleLayer.isHidden = true
        }

        isHidden = false
    }

    /// 正在觸控擦除中（筆尖/手指觸控螢幕進行擦除）。
    private(set) var isEraserTracking: Bool = false

    /// 橡皮擦範圍圓圈。
    ///
    /// 與筆頭預覽分開畫：筆頭會依筆桿傾角壓扁、用墨色淡描邊 —— 套在橡皮擦上，
    /// 圓變成斜的橢圓、淺色時幾乎看不見，使用者讀不出實際擦除範圍。
    /// - Parameters:
    ///   - point: 中心（這個視圖的座標系）。
    ///   - diameter: 螢幕上的直徑（已乘上畫布縮放倍率），與實際擦除寬度一比一。
    ///   - tracking: 筆尖／手指**貼在螢幕上**擦除中（`true`）或只是懸停（`false`）。
    ///     只有前者要擋住懸停結束時的 `hide()`。原本懸停也標成「擦除中」：筆一離開，
    ///     懸停結束的 `hide()` 被擋掉，圓圈就一直留在畫面上（實機截圖裡那個不會消失的 ⊕）。
    func showEraser(at point: CGPoint, diameter: CGFloat, tracking: Bool = false) {
        if tracking { isEraserTracking = true }
        let d = max(diameter, 6)
        let rect = CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)
        let ring = UIBezierPath(ovalIn: rect).cgPath
        // 中心微型十字：擦細小筆跡時對準用，長度隨圓縮小。
        let tick = min(3.5, d / 5)
        let cross = UIBezierPath(ovalIn: rect)
        cross.move(to: CGPoint(x: point.x - tick, y: point.y))
        cross.addLine(to: CGPoint(x: point.x + tick, y: point.y))
        cross.move(to: CGPoint(x: point.x, y: point.y - tick))
        cross.addLine(to: CGPoint(x: point.x, y: point.y + tick))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        // 畫布上後來加入的子視圖（專業筆畫層）會疊在預覽上面；每次顯示都拉回最上層。
        superview?.bringSubviewToFront(self)
        shape.isHidden = true
        reticleLayer.isHidden = true
        eraserFill.path = ring
        eraserOuter.path = ring
        eraserInner.path = cross.cgPath
        setEraserHidden(false)
        isHidden = false
    }

    private func setEraserHidden(_ hidden: Bool) {
        eraserFill.isHidden = hidden
        eraserOuter.isHidden = hidden
        eraserInner.isHidden = hidden
    }

    /// 觸控擦除結束時明確呼叫。
    func hideEraser() {
        isEraserTracking = false
        hide()
    }

    func hide() {
        // 若正在擦除中（筆尖/手指觸控螢幕進行擦除），懸停結束事件絕不可強制隱藏擦除指示圓圈！
        guard !isEraserTracking else { return }
        guard !isHidden || !reticleLayer.isHidden else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        isHidden = true
        reticleLayer.isHidden = true
        CATransaction.commit()
    }
}

/// 把懸停事件接到預覽層上。
final class PenHoverCoordinator: NSObject {

    /// 現在該畫什麼形狀。由畫布在換筆刷、換粗細時更新。
    var currentPath: (() -> UIBezierPath?)?
    var currentColor: (() -> UIColor)?
    /// 手寫模式才預覽。打字模式下畫布不收筆畫，畫一個筆頭只會誤導。
    var isPreviewEnabled: (() -> Bool)?
    /// 專業圖學與幾何磁吸點查詢（若命中格線或錨點，回傳吸附座標）。
    var snapQuery: ((CGPoint) -> CGPoint?)?
    /// 選了橡皮擦時回傳螢幕上的擦除直徑（已含縮放），其餘工具回傳 `nil`。
    var eraserDiameter: (() -> CGFloat?)?

    private weak var preview: PenHoverPreviewView?

    func attach(to canvas: UIView, preview: PenHoverPreviewView) {
        self.preview = preview
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        hover.cancelsTouchesInView = false
        hover.delaysTouchesBegan = false
        hover.delaysTouchesEnded = false
        // **這一行不能少。** 預設 `UIHoverGestureRecognizer` 只認滑鼠指標；
        // 少了它，觸控筆懸在螢幕上方時這個 recognizer 完全不會被呼叫，
        // 而且不會有任何錯誤 —— 看起來就只是「懸停沒有做」。
        if #available(iOS 16.4, *) {
            hover.allowedTouchTypes = [
                NSNumber(value: UITouch.TouchType.pencil.rawValue),
                NSNumber(value: UITouch.TouchType.direct.rawValue),
            ]
        }
        canvas.addGestureRecognizer(hover)
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        guard let preview, let view = gesture.view else { return }

        guard isPreviewEnabled?() ?? true else {
            preview.hide()
            return
        }

        switch gesture.state {
        case .began, .changed:
            var tilt: CGFloat = 0
            var azimuth: CGFloat = 0
            let location = gesture.location(in: preview)
            if let diameter = eraserDiameter?() {
                preview.showEraser(at: location, diameter: diameter)
                return
            }
            if #available(iOS 16.4, *) {
                // `altitudeAngle` 是與螢幕平面的夾角（π/2 為垂直握筆），
                // 我們要的是偏離垂直的角度。兩者是互補角，不是同一個東西
                // —— 這個轉換在 `InkInterop` 也做過一次，弄反的話筆頭會在
                // 垂直握筆時壓到最扁。
                tilt = max(.pi / 2 - gesture.altitudeAngle, 0)
                azimuth = gesture.azimuthAngle(in: view)
            }
            let snapPoint = snapQuery?(location)
            preview.show(
                at: location,
                path: currentPath?(),
                tilt: tilt,
                azimuth: azimuth,
                color: currentColor?() ?? .label,
                snapPoint: snapPoint)
        default:
            preview.hide()
        }
    }
}

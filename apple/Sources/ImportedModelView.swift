import SwiftUI

/// 畫一個使用者自己匯入的 3D 模型。
///
/// # 為什麼不是 SceneKit
///
/// Apple 端原本用 `SCNScene(url:)` 讀匯入的模型。那條路**只有這一邊有**，
/// 於是同一個檔案在 iPad 上看得到、在 Android 上是一張寫著檔名的卡片 ——
/// 存得下、同步得動、畫不出來。
///
/// 真正缺的從來不是算繪器：核心裡一直有一個（旋轉、透視投影、深度排序、
/// 單一方向光著色），內建的六個幾何體兩端都靠它。缺的是「檔案 → 網格」
/// 那一段，而那一段現在也在核心（`FfiImportedModel3d`）。
///
/// 所以這個視圖做的事跟 Android 的 `Model3DRenderer` 一模一樣：把核心算好
/// 的多邊形**照順序**填色。順序就是前後關係（由遠而近），不要自己重排。
///
/// # 已知的限制
///
/// 匯入的模型不保證是凸的，纏繞方向也不保證一致，所以核心那一側不剔除
/// 背面，前後關係靠逐面深度排序（畫家演算法）。交錯的面會有瑕疵 ——
/// 那遠好過看不見，真要解得做 z-buffer，那是另一件事。
struct ImportedModelView: View {
    let model: FfiImportedModel3d
    let rotationX: Float
    let rotationY: Float
    let rotationZ: Float
    let scale: Float
    /// 材質的基本色（十六進位，含或不含 `#` 都行）。
    let hex: String

    var body: some View {
        Canvas { context, size in
            let faces = model.faces(
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ,
                scale: scale,
                width: Float(size.width),
                height: Float(size.height))

            let base = Self.colour(hex)
            for face in faces where face.points.count >= 3 {
                var path = Path()
                path.move(to: CGPoint(x: CGFloat(face.points[0].x), y: CGFloat(face.points[0].y)))
                for p in face.points.dropFirst() {
                    path.addLine(to: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                }
                path.closeSubpath()

                context.fill(path, with: .color(Self.shade(base, face.shade)))
                // 描一條同色系的細邊。沒有它的話相鄰面之間會出現抗鋸齒的
                // 細縫，模型看起來像裂開的（Android 端踩過同一件事）。
                context.stroke(
                    path,
                    with: .color(Self.shade(base, face.shade * 0.82)),
                    lineWidth: 1)
            }
        }
    }

    /// `#RRGGBB` → Color。認不得就回中性灰 —— 回透明的話，模型會整個消失，
    /// 而那看起來像「匯入失敗」。
    static func colour(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            return Color(white: 0.6)
        }
        return Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255)
    }

    /// 明暗係數套到基本色上。
    static func shade(_ base: Color, _ shade: Float) -> Color {
        let k = Double(max(0, min(1, shade)))
        // 直接乘會讓背光面接近全黑；混一點白讓它保留顏色，與 Android 端
        // 的做法一致。
        return base.opacity(1).brightnessAdjusted(k)
    }
}

private extension Color {
    /// 亮度縮放。SwiftUI 沒有直接的 API，用 `UIColor` 轉一趟。
    func brightnessAdjusted(_ k: Double) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b) * k, opacity: Double(a))
    }
}

/// 已經讀進來的匯入模型。
///
/// # 為什麼要快取
///
/// 使用者拖旋轉滑桿的時候每一幀都要重算投影。解析也塞進那條路的話，等於
/// 每一幀重讀一次整個檔案 —— 一個兩萬面的模型會讓滑桿變成幻燈片。
///
/// **讀失敗也要記住**：檔案可能還沒從雲端同步下來。不記住的話，每一幀都會
/// 再試一次讀那個讀不到的檔 —— 那比慢更糟，那是整個畫面卡在磁碟 I/O 上。
@MainActor
enum ImportedModelCache {
    private static var entries: [String: FfiImportedModel3d?] = [:]

    /// 讀得到就回模型，讀不到回 `nil`（介面退回檔名卡片）。
    static func model(fileName: String) -> FfiImportedModel3d? {
        if let cached = entries[fileName] { return cached }

        let url = NotebookStore.shared.importedFileURL(fileName: fileName)
        let parsed: FfiImportedModel3d?
        if let data = try? Data(contentsOf: url) {
            parsed = try? FfiImportedModel3d.parse(
                bytes: data, extension: url.pathExtension)
        } else {
            parsed = nil
        }
        entries[fileName] = parsed
        return parsed
    }

    /// 忘掉某一個檔案。同步把原本缺的檔案補下來之後要呼叫它，否則那本筆記
    /// 在這次啟動期間會一直顯示檔名卡片 —— 而使用者會以為同步沒成功。
    static func forget(fileName: String) {
        entries.removeValue(forKey: fileName)
    }
}

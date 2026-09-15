//
//  HandwritingRecognizer.swift
//  Kairumo
//
//  手寫辨識（WP7 / S-22）。Apple 端原本**完全沒有**這個功能 ——
//  Android 有 ML Kit Digital Ink，iPad 上寫的字卻搜不到。
//
//  # 為什麼走 Vision 而不是「筆畫辨識」
//
//  Apple 沒有公開的筆畫式手寫辨識 API（PencilKit 的 Scribble 是**輸入**用的，
//  不是拿來辨識既有筆跡）。`VNRecognizeTextRequest` 吃的是圖片，
//  所以這裡把每一組筆畫算繪成一張黑底白字的點陣圖再送進去。
//
//  代價要講清楚：這條路拿不到筆順資訊，對潦草的連筆中文比 ML Kit 吃力。
//  它是 Apple 上目前唯一不需要外部服務、不需要 API key、可離線的做法。
//
//  # 分組在核心
//
//  「停頓多久算換一組」由核心的 `hwrGroupStrokes` 決定，與 Android 同一份。
//  切法不同的話，同一頁筆記在兩台裝置上會被切成不同的組，搜尋結果也就不同。
//
//  # 辨識結果只進索引，不改筆跡
//
//  辨識出來的文字寫進核心的搜尋索引，**不會**取代或修改任何一筆畫。
//  手寫筆記的價值就在那個手寫，辨識只是讓它搜得到。
//

import PencilKit
import UIKit
import Vision

public enum HandwritingRecognizer {

    /// 辨識失敗的原因。逐項分開 —— 「辨識失敗」四個字幫不了使用者。
    public enum Failure: Error {
        /// 這台裝置或這個系統版本沒有可用的辨識能力。
        case unsupported(String)
        /// Vision 不支援這個語言。
        case noModel(String)
        case recognitionFailed(String)
    }

    /// 一頁的辨識結果：每一組筆畫對應一段文字。
    public struct GroupResult {
        public let strokeIds: [String]
        public let text: String
    }

    /// 辨識一整張 `PKDrawing`。
    ///
    /// 直接吃 PencilKit 的筆跡，因為 Apple 端的編輯器本來就以 `PKDrawing`
    /// 為準（不像 Android 有一個常駐的核心 session）。回傳的組數可能少於
    /// 分組數 —— 認不出東西的那一組直接略過，不要塞一個空字串進索引。
    public static func recognize(
        drawing: PKDrawing,
        languageTag: String
    ) async -> Result<[GroupResult], Failure> {
        let strokes = drawing.strokes
        guard !strokes.isEmpty else { return .success([]) }

        // PencilKit 的筆畫沒有 id，用索引當 id —— 它只在這一次辨識裡用來
        // 把分組結果對回筆畫，不會落盤。
        let timings = strokes.enumerated().map { index, stroke in
            FfiStrokeTiming(
                id: String(index),
                startedAtMs: startedAtMs(of: stroke),
                durationMs: durationMs(of: stroke)
            )
        }
        let groups = hwrGroupStrokes(strokes: timings, gapMs: hwrDefaultGapMs())

        var out: [GroupResult] = []
        for group in groups {
            let members = group.strokeIds.compactMap { Int($0) }.compactMap { index in
                index < strokes.count ? strokes[index] : nil
            }
            guard let image = render(strokes: members) else { continue }
            switch await recognize(image: image, languageTag: languageTag) {
            case .failure(let error):
                // 一組失敗就整頁失敗：部分成功會讓使用者以為「有些字太醜」，
                // 而實際上可能是語言不支援之類的整體問題。
                return .failure(error)
            case .success(let text) where !text.isEmpty:
                out.append(GroupResult(strokeIds: group.strokeIds, text: text))
            case .success:
                continue
            }
        }
        return .success(out)
    }

    /// 落筆時刻（毫秒）。
    ///
    /// `PKStrokePath.creationDate` 是這一筆開始的絕對時間；用它相減才知道
    /// 兩筆之間停了多久。只看 `timeOffset` 的話所有筆畫都從 0 起算，
    /// 停頓永遠是 0，整頁會被併成一組。
    private static func startedAtMs(of stroke: PKStroke) -> UInt64 {
        let seconds = stroke.path.creationDate.timeIntervalSince1970
        return UInt64(max(0, seconds * 1000))
    }

    /// 這一筆寫了多久（毫秒）。
    private static func durationMs(of stroke: PKStroke) -> UInt64 {
        guard let last = stroke.path.last else { return 0 }
        return UInt64(max(0, last.timeOffset * 1000))
    }

    /// 把一組筆畫算繪成辨識用的圖。
    ///
    /// 幾個對辨識率影響很大、但不寫下來就會被「順手改掉」的細節：
    /// - **白底黑字**：Vision 對深色底的手寫明顯較差。
    /// - **留邊**：字貼著邊界時 Vision 常常整組漏掉。
    /// - **放大到固定高度**：太小的圖辨識不出來，而使用者的字可能很小。
    private static func render(strokes: [PKStroke]) -> UIImage? {
        var bounds: CGRect = .null
        for stroke in strokes {
            bounds = bounds.union(stroke.renderBounds)
        }
        guard !bounds.isNull, bounds.width.isFinite, bounds.height.isFinite else { return nil }
        let (minX, minY) = (bounds.minX, bounds.minY)
        let (maxX, maxY) = (bounds.maxX, bounds.maxY)

        let padding: CGFloat = 24
        let rawWidth = max(maxX - minX, 1)
        let rawHeight = max(maxY - minY, 1)
        // 放大到大約 160pt 高，但不要縮小 —— 縮小只會讓細節消失。
        let scale = max(1, 160 / rawHeight)
        let size = CGSize(
            width: rawWidth * scale + padding * 2,
            height: rawHeight * scale + padding * 2
        )
        // 上限保護：一組筆畫如果橫跨整頁，放大之後會是一張巨圖。
        guard size.width < 4000, size.height < 4000 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineWidth(max(2, 3 * scale / 2))
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            for stroke in strokes {
                let path = stroke.path
                guard path.count > 0 else { continue }
                let place = { (location: CGPoint) -> CGPoint in
                    CGPoint(
                        x: (location.x - minX) * scale + padding,
                        y: (location.y - minY) * scale + padding
                    )
                }
                cg.move(to: place(path[0].location))
                for i in 1..<path.count {
                    cg.addLine(to: place(path[i].location))
                }
                cg.strokePath()
            }
        }
    }

    private static func recognize(
        image: UIImage,
        languageTag: String
    ) async -> Result<String, Failure> {
        guard let cgImage = image.cgImage else {
            return .failure(.recognitionFailed("無法取得點陣圖"))
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(returning: .failure(.recognitionFailed(error.localizedDescription)))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                continuation.resume(returning: .success(text))
            }
            // `.accurate` 慢得多，但這不是即時路徑 —— 使用者按下「辨識」
            // 之後等一下是可以接受的，認錯字不行。
            request.recognitionLevel = .accurate
            // 手寫要靠語言模型補上下文；關掉的話中文幾乎認不出來。
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages(for: languageTag)

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(returning: .failure(.recognitionFailed(error.localizedDescription)))
            }
        }
    }

    /// 要餵給 Vision 的語言清單。
    ///
    /// 一律把英文接在後面：中文筆記裡夾英文字是常態，只給中文的話，
    /// 那些英文會被硬湊成最接近的漢字。
    static func languages(for languageTag: String) -> [String] {
        let primary = languageTag.isEmpty ? "en-US" : languageTag
        return primary.hasPrefix("en") ? [primary] : [primary, "en-US"]
    }
}

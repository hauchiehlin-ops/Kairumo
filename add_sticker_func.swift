    private func saveSelectedAsSticker() {
        guard let canvas = canvasView, hasLassoSelection else { return }
        let originalStrokes = canvas.drawing.strokes
        UIResponderStandardEditActions.cut?(canvas)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let cutDrawing = canvas.drawing
            let originalDict = Dictionary(uniqueKeysWithValues: originalStrokes.map { ($0.path.creationDate, $0) })
            let cutDict = Dictionary(uniqueKeysWithValues: cutDrawing.strokes.map { ($0.path.creationDate, $0) })
            
            var extractedStrokes: [PKStroke] = []
            for (date, stroke) in originalDict {
                if cutDict[date] == nil {
                    extractedStrokes.append(stroke)
                }
            }
            guard !extractedStrokes.isEmpty else {
                canvas.drawing = PKDrawing(strokes: originalStrokes)
                return
            }
            let tempDrawing = PKDrawing(strokes: extractedStrokes)
            let bounds = tempDrawing.bounds
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
            let centeredStrokes = extractedStrokes.map {
                PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
            }
            let stickerDrawing = PKDrawing(strokes: centeredStrokes)
            StickerManager.shared.saveSticker(stickerDrawing)
            
            canvas.drawing = PKDrawing(strokes: originalStrokes)
            self.hasLassoSelection = false
            self.selectedTool = .pen
        }
    }

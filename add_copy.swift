    private func copySelectedStrokes() {
        guard let canvas = canvasView else { return }
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.copy(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.copy(_:)), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.currentDrawing = canvas.drawing
            self.saveCurrentPageDrawing()
        }
    }

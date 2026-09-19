import SwiftUI

struct PageBackgroundRepresentable: UIViewRepresentable {
    var paperId: String
    var paletteId: String?
    
    func makeUIView(context: Context) -> TemplateCanvasBackgroundView {
        let view = TemplateCanvasBackgroundView()
        view.paperId = paperId
        view.paletteId = paletteId
        return view
    }
    
    func updateUIView(_ uiView: TemplateCanvasBackgroundView, context: Context) {
        uiView.paperId = paperId
        uiView.paletteId = paletteId
    }
}

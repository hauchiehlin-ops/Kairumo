import SwiftUI

struct PageBackgroundRepresentable: UIViewRepresentable {
    var paperId: String
    var paletteId: String?
    var pageIndex: Int = 0
    var checkedGuideItems: [String: Bool]? = nil
    
    func makeUIView(context: Context) -> TemplateCanvasBackgroundView {
        let view = TemplateCanvasBackgroundView()
        view.paperId = paperId
        view.paletteId = paletteId
        view.pageIndex = pageIndex
        view.checkedGuideItems = checkedGuideItems
        return view
    }
    
    func updateUIView(_ uiView: TemplateCanvasBackgroundView, context: Context) {
        uiView.paperId = paperId
        uiView.paletteId = paletteId
        uiView.pageIndex = pageIndex
        uiView.checkedGuideItems = checkedGuideItems
    }
}

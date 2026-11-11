//
//  EditorSubsystemCoordinator.swift
//  Kairumo
//
//  職責：
//  將表格、圖表、算式、形狀、3D 模型等「次系統／重型外掛編輯視窗」從主畫布
//  NotebookEditorView 徹底解耦。
//
//  架構意義：
//  1. 零常態開銷：平時使用者手繪時，所有次系統視窗均為 nil/false，不進入
//     主畫布 View Hierarchy 的遞迴遍歷與 Diffing，保證 120Hz 手寫超低延遲（Layer 3）。
//  2. 消除 Type Explosion：避免主畫布 body 被 20+ 個重型 Sheet 串接導致
//     SwiftUI 編譯期型別推導逾時與執行期負擔。
//  3. 隨需通訊調度：外掛編輯模組僅在使用者主動點擊或快捷鍵觸發時實例化與呈現。
//

import SwiftUI

// MARK: - Table Subsystem Coordinator
struct TableSubsystemCoordinatorModifier: ViewModifier {
    @Binding var showTableStudio: Bool
    @Binding var editingTable: NoteTableAttachment?
    @Binding var tablePropertiesTarget: NoteTableAttachment?
    let getTable: (String) -> NoteTableAttachment?
    let onInsertTable: (NoteTableAttachment) -> Void
    let onUpdateTable: (NoteTableAttachment) -> Void

    func body(content: Content) -> some View {
        content
            // 全螢幕覆蓋建立全新表格
            .fullScreenCover(isPresented: $showTableStudio) {
                TableStudioView { created in
                    onInsertTable(created)
                }
            }
            // 全螢幕覆蓋編輯現有表格
            .fullScreenCover(item: $editingTable) { target in
                TableStudioView(editing: target) { updated in
                    onUpdateTable(updated)
                }
            }
            // 獨立 Sheet 呈現 Word 級「表格內容」五大分頁面板
            // 可拖曳調整高度（與其他次系統面板同一套 `resizableSheet`）。
            .sheet(item: $tablePropertiesTarget) { target in resizableSheet {
                TablePropertiesSheet(
                    table: getTable(target.id) ?? target,
                    onCommit: { onUpdateTable($0) }
                )
            } }
    }
}

extension View {
    /// 掛載表格次系統（新建表格、編輯表格、表格屬性面板）
    func tableSubsystem(
        showTableStudio: Binding<Bool>,
        editingTable: Binding<NoteTableAttachment?>,
        tablePropertiesTarget: Binding<NoteTableAttachment?>,
        getTable: @escaping (String) -> NoteTableAttachment?,
        onInsertTable: @escaping (NoteTableAttachment) -> Void,
        onUpdateTable: @escaping (NoteTableAttachment) -> Void
    ) -> some View {
        self.modifier(TableSubsystemCoordinatorModifier(
            showTableStudio: showTableStudio,
            editingTable: editingTable,
            tablePropertiesTarget: tablePropertiesTarget,
            getTable: getTable,
            onInsertTable: onInsertTable,
            onUpdateTable: onUpdateTable
        ))
    }
}

// MARK: - Creative Studios Presenter Modifier
struct CreativeStudiosPresenterModifier: ViewModifier {
    let parent: NotebookEditorView

    func body(content: Content) -> some View {
        parent.applyCreativeStudios(to: content)
    }
}

// MARK: - Creative Studios Coordinator Extension
extension NotebookEditorView {
    @ViewBuilder
    func applyCreativeStudios(to content: some View) -> some View {
        content
            .sheet(isPresented: $showMathCalculator) { resizableSheet {
                MathCalculatorSheet(
                    onInsertFormula: { exprText, cardImage in
                        insertImageAttachment(cardImage, mathFormula: exprText)
                    },
                    onInsertEditableText: { formulaText in
                        insertFormulaText(formulaText)
                    }
                )
            } }
            .sheet(isPresented: $showShapeStudio) { resizableSheet {
                ShapeStudioView { shapes, connections in
                    if notebook.shapeAttachments == nil { notebook.shapeAttachments = [] }
                    if notebook.connectionAttachments == nil { notebook.connectionAttachments = [] }
                    for shape in shapes {
                        var placed = shape
                        placed.pageIndex = currentPageIndex
                        notebook.shapeAttachments?.append(placed)
                        if let data = try? JSONEncoder().encode(placed),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            collaborationManager.broadcastAttachmentUpsert(type: "shape", itemDict: dict)
                        }
                    }
                    for connection in connections {
                        var placed = connection
                        placed.pageIndex = currentPageIndex
                        notebook.connectionAttachments?.append(placed)
                        if let data = try? JSONEncoder().encode(placed),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            collaborationManager.broadcastAttachmentUpsert(type: "connection", itemDict: dict)
                        }
                    }
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                }
            } }
            .sheet(isPresented: $showChartStudio) { resizableSheet {
                ChartStudioView { chartSpec, chartImage in
                    insertImageAttachment(chartImage, chartSpecJSON: chartSpec.encodedJSON())
                }
            } }
            .sheet(item: $editingChartAttachmentId) { identifier in resizableSheet {
                ChartStudioView(editing: identifier.spec) { updatedSpec, updatedImage in
                    replaceChartAttachment(id: identifier.id, spec: updatedSpec, image: updatedImage)
                }
            } }
            .sheet(item: $editingMathAttachmentId) { target in resizableSheet {
                MathCalculatorSheet(
                    initialFormula: target.formula,
                    onInsertFormula: { exprText, cardImage in
                        replaceMathAttachment(id: target.id, formula: exprText, image: cardImage)
                    },
                    onInsertEditableText: { formulaText in
                        replaceMathAttachment(id: target.id, formula: formulaText, image: nil)
                        insertFormulaText(formulaText)
                    }
                )
            } }
            .sheet(isPresented: $showNoteIntelligence) { resizableSheet {
                NoteIntelligenceSheet(
                    text: notebook.plainText(),
                    onInsert: { text in insertQuickTextSnippet(text) }
                )
            } }
            .sheet(isPresented: $showWordStudio) { resizableSheet {
                WordTextStudioView(attachment: $newTextDraft) { created in
                    if notebook.textAttachments == nil {
                        notebook.textAttachments = []
                    }
                    if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == created.id }) {
                        notebook.textAttachments?[idx] = created
                    } else {
                        notebook.textAttachments?.append(created)
                    }
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                    if let data = try? JSONEncoder().encode(created),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                    }
                }
            } }
            .sheet(isPresented: $showLinkPreviewSheet) { resizableSheet {
                LinkPreviewSheet { linkItem in
                    if notebook.linkAttachments == nil {
                        notebook.linkAttachments = []
                    }
                    var placed = linkItem
                    placed.pageIndex = currentPageIndex
                    notebook.linkAttachments?.append(placed)
                    commitNotebook()
                    if let data = try? JSONEncoder().encode(placed),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "link", itemDict: dict)
                    }
                }
            } }
            .sheet(isPresented: $show3DStudio) { resizableSheet {
                Model3DStudioView { new3DAttachment in
                    if notebook.model3DAttachments == nil {
                        notebook.model3DAttachments = []
                    }
                    var att = new3DAttachment
                    att.pageIndex = currentPageIndex
                    notebook.model3DAttachments?.append(att)
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                    if let data = try? JSONEncoder().encode(att),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                    }
                }
            } }
            .sheet(isPresented: $showAssetLibrarySheet) { resizableSheet {
                AssetLibraryView { image, _ in
                    insertImageAttachment(image)
                }
            } }
            .sheet(isPresented: $showAudioPicker) { resizableSheet {
                AudioInsertPickerSheet { recording in
                    insertAudioAttachment(recording)
                }
            } }
            .paywallSubsystem()
    }
}

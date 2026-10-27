//
//  EditorToolbars.swift
//  Kairumo
//
//  編輯器工作列：頂部主工具列、手繪工具列、文字排版工具列、以及閱讀模式工具列
//

import SwiftUI
import PencilKit
import UniformTypeIdentifiers

// MARK: - 工具列與選單擴充

extension NotebookEditorView {
    // MARK: - 1. 頂部自訂主工作列（自適應寬窄螢幕模式）
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var editorTopBar: AnyView { AnyView(editorTopBarContent) }

    var editorTopBarContent: some View {
        // 寬度夠就用單行完整版；放不下則切到緊湊版，把次要功能收進「更多」選單；
        // 都還塞不下才換行。優先維持單行，主要動作才會固定在同一個位置。
        ViewThatFits(in: .horizontal) {
            expandedEditorTopBar
            HStack(spacing: 6) {
                compactEditorTopBarItems
            }
            // 連緊湊版都放不下時換行。否則「首頁」與「匯出與列印」
            // 會被擠到視窗外，使用者連退出筆記都做不到。
            WrapLayout(spacing: 6, lineSpacing: 6) {
                compactEditorTopBarItems
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    func triggerFileImport(_ slot: FfiImportSlot) {
        SheetCoordinator.shared.triggerFileImportFromMenu {
            self.activeImportSlot = slot
        }
    }

    func presentFromMenu(_ action: @escaping () -> Void) {
        SheetCoordinator.shared.presentFromMenu(action)
    }

    /// 「插入／更多」選單的內容。**兩種版面（iPad 全寬的 expandedEditorTopBar、窄版的工具列）共用這一份。**
    ///
    /// 以前兩個版面各寫一份，內容早就分岔：全寬版少了自訂工具列、框選、貼紙、辨識手寫、掌拒、
    /// 筆設定與「回到初始狀態」，窄版又少了插入連結 —— 同一台 iPad 轉個方向，功能就不見了。
    @ViewBuilder
    var insertMenuContent: some View {
        Section {
            Button {
                presentFromMenu { showAssetLibrarySheet = true }
            } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                .accessibilityIdentifier("editor.insert.assets")
            Button {
                presentFromMenu { showStickerLibrary = true }
            } label: { Label(localizationManager.localized("sticker_library"), systemImage: "photo.on.rectangle") }
                .accessibilityIdentifier("editor.insert.stickers")
            Button {
                presentFromMenu { setMarqueeActive(!isMarqueeActive) }
            } label: { Label(localizationManager.localized("marquee_select"), systemImage: "square.dashed") }
                .accessibilityIdentifier("editor.insert.marquee")
            Button {
                presentFromMenu { showAudioPicker = true }
            } label: { Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus") }
                .accessibilityIdentifier("editor.insert.audio")
            Button {
                triggerFileImport(.audio)
            } label: { Label(localizationManager.localized("import_audio_from_files"), systemImage: "square.and.arrow.down.on.square") }
                .accessibilityIdentifier("editor.insert.audio_file")
            Button {
                presentFromMenu { showPhotoPicker = true }
            } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                .accessibilityIdentifier("editor.insert.image")
            Button {
                triggerFileImport(.image)
            } label: { Label(localizationManager.localized("import_from_files"), systemImage: "folder.badge.plus") }
                .accessibilityIdentifier("editor.insert.image_file")
            Button {
                pasteScreenshotOrClipboardImage()
            } label: { Label(localizationManager.localized("paste_screenshot"), systemImage: "doc.on.clipboard") }
                .accessibilityIdentifier("editor.insert.paste_screenshot")
            Button {
                triggerFileImport(.pdf)
            } label: { Label(localizationManager.localized("insert_pdf"), systemImage: "doc.richtext") }
                .accessibilityIdentifier("editor.insert.pdf")
            Button {
                triggerFileImport(.document)
            } label: { Label(localizationManager.localized("import_document"), systemImage: "doc.text") }
                .accessibilityIdentifier("editor.insert.document")
            Button {
                presentFromMenu { showMathCalculator = true }
            } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                .accessibilityIdentifier("editor.insert.math")
            Button {
                presentFromMenu { showChartStudio = true }
            } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                .accessibilityIdentifier("editor.insert.chart")
            Button {
                presentFromMenu { showTableStudio = true }
            } label: { Label(localizationManager.localized("table_studio"), systemImage: "tablecells") }
                .accessibilityIdentifier("editor.insert.table")
            Button {
                presentFromMenu { showShapeStudio = true }
            } label: { Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle") }
                .accessibilityIdentifier("editor.insert.shape")
            Button {
                presentFromMenu { show3DStudio = true }
            } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                .accessibilityIdentifier("editor.insert.model3d")
            Button {
                presentFromMenu { showThemeToolsSheet = true }
            } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
                .accessibilityIdentifier("editor.insert.theme_tools")
            Button {
                presentFromMenu { showLinkPreviewSheet = true }
            } label: { Label(localizationManager.localized("insert_link"), systemImage: "link") }
                .accessibilityIdentifier("editor.insert.link")
        } header: {
            Text(localizationManager.localized("insert_object"))
        }

        Section {
            Button {
                withAnimation {
                    insertSpaceDividerY = min(currentPageHeight - 100, max(150, canvasContentOffset.y + 300))
                    isInsertSpaceActive.toggle()
                }
            } label: { Label(localizationManager.localized("insert_vertical_space"), systemImage: "arrow.up.and.down.square") }
                .accessibilityIdentifier("editor.insert.space")
            Button { withAnimation { showSketchRefineBar.toggle() } } label: { Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars") }
                .accessibilityIdentifier("editor.insert.refine_sketch")
            Button {
                presentFromMenu { showNoteIntelligence = true }
            } label: {
                Label(localizationManager.localized("ai_summary"), systemImage: "sparkles")
            }
            .accessibilityIdentifier("editor.insert.ai_summary")
            Button { recognizeHandwritingOnCurrentPage() } label: {
                Label(localizationManager.localized("recognize_handwriting"), systemImage: "text.viewfinder")
            }
            .accessibilityIdentifier("editor.insert.recognize")
            Button {
                presentFromMenu { showCollaborationSheet = true }
            } label: { Label(localizationManager.localized("collaborate"), systemImage: "person.2.fill") }
                .accessibilityIdentifier("editor.insert.collaborate")
            Button { withAnimation { isPlacingCommentPin.toggle() } } label: { Label(localizationManager.localized("add_comment_pin"), systemImage: "text.bubble.fill") }
                .accessibilityIdentifier("editor.insert.comment_pin")
        }

        // 設定類：跟「插入什麼」「做什麼」分開放，使用者才不會在一長串插入項目裡找設定。
        Section {
            // 放在編輯器而不是設定頁：使用者想關掉某支筆的那一刻，
            // 是他正看著那支筆的時候。
            Button {
                presentFromMenu { showToolbarCustomization = true }
            } label: {
                Label(localizationManager.localized("customize_toolbar"), systemImage: "slider.horizontal.3")
            }
            .accessibilityIdentifier("editor.customize_toolbar")
            // 掌拒門檻（S-101）。判定一直都在核心，缺的只是「讓使用者調」——
            // 握筆姿勢比較特別的人，手掌一放上去就是一道線，
            // 而在此之前他完全沒有辦法處理。
            Button {
                presentFromMenu { showPalmThresholdSheet = true }
            } label: {
                Label(localizationManager.localized("palm_rejection_settings"), systemImage: "hand.raised.slash")
            }
            .accessibilityIdentifier("editor.insert.palm_thresholds")
            Button {
                presentFromMenu { showAdvancedPenSettingsSheet = true }
            } label: {
                Label(localizationManager.localized("pen_settings_title"), systemImage: "applepencil.and.scribble")
            }
            .accessibilityIdentifier("editor.insert.advanced_pen_settings")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isTabletopMode.toggle()
                }
            } label: {
                Label(L("posture_tabletop_mode"), systemImage: "laptopcomputer.and.ipad")
            }
            .accessibilityIdentifier("editor.tabletop_mode")

        }

        // 會丟掉變更的動作單獨一區，不跟一般項目擠在一起。
        Section {
            Button(role: .destructive) {
                showRevertConfirmAlert = true
            } label: {
                Label(localizationManager.localized("revert_to_initial_state"), systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("editor.revert_initial_state")
        }
    }

    // 寬螢幕完整主工具列
    var expandedEditorTopBar: some View {
        HStack(spacing: 10) {
            // 回到首頁按鈕（明顯、易見、帶底色）
            Button {
                requestLeave { dismiss() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "house.fill")
                        .font(.system(size: 13))
                    Text(localizationManager.localized("home"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .cornerRadius(8)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("home"))
            .help(localizationManager.localized("home"))
            .accessibilityIdentifier("editor.home")

            // 筆記結構側邊欄切換鈕
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showStructureSidebar.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showStructureSidebar ? "sidebar.left" : "sidebar.leading")
                        .font(.system(size: 13, weight: .semibold))
                    Text(localizationManager.localized("structure_sidebar"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(showStructureSidebar ? .accentColor : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(showStructureSidebar ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("structure_sidebar"))
            .help(localizationManager.localized("structure_sidebar_desc"))
            .accessibilityIdentifier("editor.sidebar_toggle")

            Spacer()

            // 手繪與打字模式切換器
            editorModeSwitcher()
                .accessibilityIdentifier("editor.mode")

            // 🌟 畫布極簡模式恢復按鈕（讓使用者一秒找到退出鍵）
            if isMinimalistCanvasActive {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        isMinimalistCanvasActive = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(localizationManager.localized("exit_canvas_minimal_mode"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("exit_canvas_minimal_mode"))
                .accessibilityLabel(localizationManager.localized("exit_canvas_minimal_mode"))
            }

            // 筆記標題（點擊可修改）
            Button {
                renameText = notebook.displayTitle()
                showRenameAlert = true
            } label: {
                HStack(spacing: 6) {
                    Text(notebook.displayTitle())
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.title")

            Spacer()

            // 頁碼切換器
            HStack(spacing: 6) {
                Button {
                    switchToPage(currentPageIndex - 1)
                } label: {
                    Image(systemName: "chevron.left.circle")
                }
                .disabled(currentPageIndex <= 0)
                .accessibilityIdentifier("editor.page.prev")

                Text("P.\(currentPageIndex + 1)/\(max(1, notebook.pageCount))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("editor.page.indicator")

                Button {
                    switchToPage(currentPageIndex + 1)
                } label: {
                    Image(systemName: "chevron.right.circle")
                }
                .disabled(currentPageIndex >= notebook.pageCount - 1)
                .accessibilityIdentifier("editor.page.next")

                // 新增頁面
                Button {
                    addNewPage()
                } label: {
                    Image(systemName: "plus.square.dashed")
                        .foregroundColor(.accentColor)
                }
                .accessibilityLabel(localizationManager.localized("add_page"))
                .help(localizationManager.localized("add_page_desc"))
                .accessibilityIdentifier("editor.page.add")
            }

            Divider()
                .frame(height: 18)

            // 尺規切換開關
            Button {
                isRulerActive.toggle()
            } label: {
                Image(systemName: "ruler")
                    .foregroundColor(isRulerActive ? .accentColor : .secondary)
                    .padding(5)
                    .background(isRulerActive ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
            }
            .accessibilityLabel(localizationManager.localized("ruler"))
            .help(localizationManager.localized("ruler_desc"))

            // 次世代 UI/UX Phase 5: 立起雙屏模式 (Tabletop Mode)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isTabletopMode.toggle()
                }
            } label: {
                Image(systemName: isTabletopMode ? "laptopcomputer.and.ipad" : "ipad.landscape")
                    .foregroundColor(isTabletopMode ? .accentColor : .secondary)
                    .padding(5)
                    .background(isTabletopMode ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
            }
            .accessibilityLabel(L("posture_tabletop_mode"))
            .help(L("posture_tabletop_mode_desc"))

            // 復原與重做 (Undo / Redo)
            HStack(spacing: 10) {
                Button {
                    performUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(localizationManager.localized("undo"))
                .help(localizationManager.localized("undo_desc"))
                .accessibilityIdentifier("editor.compact.undo")

                Button {
                    performRedo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(localizationManager.localized("redo"))
                .help(localizationManager.localized("redo_desc"))
                .accessibilityIdentifier("editor.compact.redo")

                Divider().frame(height: 20)

                Button {
                    showRevertConfirmAlert = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(localizationManager.localized("revert_to_initial_state"))
                .help(localizationManager.localized("revert_to_initial_state"))
                .accessibilityIdentifier("editor.compact.revert")
            }

            // 📦 素材圖庫快捷按鈕（與 iOS 首頁一致）
            Button {
                showAssetLibrarySheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.purple)
                    Text(localizationManager.localized("asset_library"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("asset_library"))
            .help(localizationManager.localized("asset_library"))

            // ➕ 插入物件下拉選單（整合圖片、算式、圖表、3D、主題工具）
            Menu {
                insertMenuContent
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("insert_object"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("insert_object"))
            .help(localizationManager.localized("insert_object"))
            .accessibilityIdentifier("editor.more")

            // 💬 畫布討論圖釘快捷按鈕
            Button {
                withAnimation {
                    isPlacingCommentPin.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPlacingCommentPin ? "pin.circle.fill" : "text.bubble.fill")
                        .foregroundColor(isPlacingCommentPin ? .orange : .accentColor)
                    Text(localizationManager.localized("comment_pin"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    if let count = notebook.commentPins?.filter({ !$0.isResolved }).count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isPlacingCommentPin ? Color.orange.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isPlacingCommentPin ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("comment_pin"))
            .help(localizationManager.localized("comment_pin_desc"))

            // 👥 線上多人即時協同按鈕
            Button {
                showCollaborationSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isCollaborating ? "person.2.wave.2.fill" : "person.2.fill")
                        .foregroundColor(isCollaborating ? .green : .accentColor)
                    Text(localizationManager.localized("collaborate"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    if isCollaborating {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(collaborationManager.peers.count + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isCollaborating ? Color.green.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isCollaborating ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("collaborate"))
            .help(localizationManager.localized("collaborate_desc"))

            // 錄音按鈕
            if audioManager.status == .recording || audioManager.status == .paused {
                Button {
                    stopAndSaveRecording()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(audioManager.status == .recording ? Color.red : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(localizationManager.localized("stop_recording"))
                            .font(.caption2)
                            .foregroundColor(audioManager.status == .recording ? .red : .orange)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background((audioManager.status == .recording ? Color.red : Color.orange).opacity(0.12))
                    .cornerRadius(6)
                }
                .accessibilityIdentifier("editor.record")
            } else {
                Button {
                    Task {
                        _ = await audioManager.startRecording(
                            notebookId: notebook.id,
                            notebookTitle: notebook.displayTitle(),
                            title: NotebookStore.defaultRecordingTitle(),
                            pageIndex: currentPageIndex,
                            languageTag: AudioTranscriber.shared.sourceLanguageTag)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(localizationManager.localized("record"))
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
                }
                .accessibilityIdentifier("editor.record")
            }

            // 匯出與列印選單（解決「看不到匯出相關工具列」問題）
            Menu {
                Button {
                    presentFromMenu {
                        exportAsPdf()
                    }
                } label: {
                    Label(localizationManager.localized("export_pdf"), systemImage: "doc.text.fill")
                }

                Button {
                    presentFromMenu {
                        exportAsPngImage()
                    }
                } label: {
                    Label(localizationManager.localized("export_image"), systemImage: "photo")
                }

                Button {
                    presentFromMenu {
                        printCurrentNotebook()
                    }
                } label: {
                    Label(localizationManager.localized("print_note"), systemImage: "printer.fill")
                }

                ToolbarSeparator()

                Button {
                    presentFromMenu {
                        shareNotebookFile()
                    }
                } label: {
                    Label(localizationManager.localized("share_note"), systemImage: "square.and.arrow.up")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text(localizationManager.localized("export_print"))
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .cornerRadius(7)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("export_print"))
            .help(localizationManager.localized("export_print"))
            .accessibilityIdentifier("editor.share")
        }
    }

    // 窄螢幕自適應緊湊工具列
    /// 緊湊模式的按鈕們（容器由呼叫端提供）。
    @ViewBuilder
    var compactEditorTopBarItems: some View {
        // 回到首頁按鈕（緊湊模式）
        Button {
            requestLeave { dismiss() }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: EditorToolbarMetrics.icon, weight: .bold))
                Image(systemName: "house.fill")
                    .font(.system(size: EditorToolbarMetrics.icon))
            }
            .foregroundColor(.white)
            .padding(.horizontal, EditorToolbarMetrics.padding + 3)
            .padding(.vertical, EditorToolbarMetrics.padding)
            .background(Color.accentColor)
            .cornerRadius(EditorToolbarMetrics.corner)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("home"))
        .help(localizationManager.localized("home"))
        .accessibilityIdentifier("editor.home")

        // 筆記結構側邊欄切換
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showStructureSidebar.toggle()
            }
        } label: {
            Image(systemName: showStructureSidebar ? "sidebar.left" : "sidebar.leading")
                .font(.system(size: EditorToolbarMetrics.icon, weight: .semibold))
                .foregroundColor(showStructureSidebar ? .accentColor : .primary)
                .padding(EditorToolbarMetrics.padding)
                .background(showStructureSidebar ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(EditorToolbarMetrics.corner)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.sidebar_toggle")

        // 模式切換（緊湊圖標）
        editorModeSwitcher()
            .accessibilityIdentifier("editor.mode")

        if isMinimalistCanvasActive {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    isMinimalistCanvasActive = false
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: EditorToolbarMetrics.icon, weight: .bold))
                    .foregroundColor(.white)
                    .padding(EditorToolbarMetrics.padding)
                    .background(Color.accentColor, in: Circle())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("exit_canvas_minimal_mode"))
            .accessibilityLabel(localizationManager.localized("exit_canvas_minimal_mode"))
        }

        // 筆記標題（彈性縮寫）
        Button {
            renameText = notebook.displayTitle()
            showRenameAlert = true
        } label: {
            Text(notebook.displayTitle())
                .font(.system(size: EditorToolbarMetrics.label, weight: .semibold))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.title")

        // 復原、重做與恢復初始狀態（膠囊群組，支援連續無限制復原）
        HStack(spacing: 2) {
            Button {
                performUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localizationManager.localized("undo"))
            .help(localizationManager.localized("undo_desc"))
            .accessibilityIdentifier("editor.compact.undo")

            Button {
                performRedo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localizationManager.localized("redo"))
            .help(localizationManager.localized("redo_desc"))
            .accessibilityIdentifier("editor.compact.redo")

            Divider().frame(height: 14)

            Button {
                showRevertConfirmAlert = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localizationManager.localized("revert_to_initial_state"))
            .help(localizationManager.localized("revert_to_initial_state"))
            .accessibilityIdentifier("editor.compact.revert")
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(EditorToolbarMetrics.corner)

        Spacer(minLength: 2)

        // 頁面導覽群組膠囊 (上一頁、頁碼指示、下一頁、新增頁面、連續/整頁切換)
        HStack(spacing: 2) {
            Button {
                switchToPage(currentPageIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .disabled(currentPageIndex <= 0)
            .accessibilityIdentifier("editor.page.prev")

            Text("\(currentPageIndex + 1)/\(max(1, notebook.pageCount))")
                .font(.system(size: EditorToolbarMetrics.label, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 3)
                .accessibilityIdentifier("editor.page.indicator")

            Button {
                switchToPage(currentPageIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .disabled(currentPageIndex >= notebook.pageCount - 1)
            .accessibilityIdentifier("editor.page.next")

            Divider().frame(height: 14)

            Button {
                addNewPage()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .bold))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 28)
            }
            .accessibilityLabel(localizationManager.localized("add_page"))
            .help(localizationManager.localized("add_page_desc"))
            .accessibilityIdentifier("editor.page.add")

            Button {
                saveCurrentPageDrawing()
                let next: PageDisplayMode = pageDisplayMode == .single ? .continuous : .single
                pageDisplayModeRaw = next.rawValue
                if next == .single {
                    loadCurrentPage()
                }
            } label: {
                Image(systemName: pageDisplayMode == .continuous
                    ? "rectangle.split.1x2"
                    : "doc.plaintext")
                    .font(.system(size: EditorToolbarMetrics.icon - 3))
                    .foregroundColor(pageDisplayMode == .continuous ? .accentColor : .secondary)
                    .frame(width: 24, height: 28)
            }
            .help(localizationManager.localized(
                pageDisplayMode == .continuous ? "page_mode_continuous" : "page_mode_single"))
            .accessibilityLabel(localizationManager.localized("page_mode"))
            .accessibilityIdentifier("editor.page.display_mode")
            .accessibilityValue(pageDisplayMode.rawValue)

            zoomMenu
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(EditorToolbarMetrics.corner)

        // 紙張規格與版面調色膠囊（整合為一體化功能膠囊）
        HStack(spacing: 2) {
            pageFormatMenu
                .accessibilityIdentifier("editor.page_format")
            Divider().frame(height: 14)
            guidePaletteMenu
                .accessibilityIdentifier("editor.guide_palette")
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(EditorToolbarMetrics.corner)

        // 👥 線上多人即時協同按鈕（常駐於頂部列，與 Mac 對齊；iPad 顯示圖示+文字，iPhone 顯示精簡圖示）
        Button {
            showCollaborationSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCollaborating ? "person.2.wave.2.fill" : "person.2.fill")
                    .font(.system(size: EditorToolbarMetrics.icon - 1))
                    .foregroundColor(isCollaborating ? .green : .accentColor)
                if horizontalSizeClass == .regular {
                    Text(localizationManager.localized("collaborate"))
                        .font(.system(size: EditorToolbarMetrics.label, weight: .medium))
                        .foregroundColor(isCollaborating ? .green : .primary)
                }
                if isCollaborating {
                    Text("\(collaborationManager.peers.count + 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 6 : EditorToolbarMetrics.padding)
            .padding(.vertical, EditorToolbarMetrics.padding)
            .background(isCollaborating ? Color.green.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(EditorToolbarMetrics.corner)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("collaborate"))
        .help(localizationManager.localized("collaborate_desc"))
        .accessibilityIdentifier("editor.compact.collaborate")

        // ➕ 插入物件選單（藍色品牌主按鈕，在 iPad 上以醒目膠囊呈現，對齊 Mac 體驗）
        Menu {
            insertMenuContent
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: EditorToolbarMetrics.icon - 1, weight: .semibold))
                if horizontalSizeClass == .regular {
                    Text(localizationManager.localized("insert_object"))
                        .font(.system(size: EditorToolbarMetrics.label, weight: .semibold))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, horizontalSizeClass == .regular ? 8 : EditorToolbarMetrics.padding + 2)
            .padding(.vertical, EditorToolbarMetrics.padding)
            .background(Color.accentColor)
            .cornerRadius(EditorToolbarMetrics.corner)
            .shadow(color: Color.accentColor.opacity(0.3), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("insert_object"))
        .help(localizationManager.localized("insert_object"))
        .accessibilityIdentifier("editor.more")

        // 錄音
        if audioManager.status == .recording || audioManager.status == .paused {
            Button {
                stopAndSaveRecording()
            } label: {
                Circle()
                    .fill(audioManager.status == .recording ? Color.red : Color.orange)
                    .frame(width: EditorToolbarMetrics.icon - 3, height: EditorToolbarMetrics.icon - 3)
                    .padding(EditorToolbarMetrics.padding + 1.5)
                    .background((audioManager.status == .recording ? Color.red : Color.orange).opacity(0.15))
                    .cornerRadius(EditorToolbarMetrics.corner)
            }
            .accessibilityIdentifier("editor.record")
        } else {
            Button {
                Task {
                    // **失敗要讓使用者看見。**
                    //
                    // 原本是 `_ = await ...` —— 回傳值直接丟掉。而
                    // `startRecording` 有三處會靜靜地回 false（權限被拒、
                    // 開不了套件、擷取啟動失敗），於是按下去之後畫面上
                    // 什麼都不會發生，使用者回報的就是「錄音鈕沒反應」。
                    //
                    // 權限被拒那一條由 `AudioRecorderManager` 自己跳系統
                    // 提示（`showPermissionAlert`），其餘的在這裡說一聲。
                    // **可以從外面把它弄壞。**
                    //
                    // 「失敗時會不會出聲」這件事，不製造一次失敗是驗不到的
                    // —— 而沒有測試守著的修正，等於一個還沒發生的回歸
                    // （筆跡那一條就是這樣活了很久）。
                    let forcedFailure = ProcessInfo.processInfo
                        .environment["KAIRUMO_UITEST_FAIL_RECORDING"] == "1"
                    if forcedFailure {
                        audioManager.showPermissionAlert = false
                        showCanvasNotice(localizationManager.localized("recording_failed"))
                    } else {
                        let started = await audioManager.startRecording(
                            notebookId: notebook.id,
                            notebookTitle: notebook.displayTitle(),
                            title: NotebookStore.defaultRecordingTitle(),
                            pageIndex: currentPageIndex,
                            languageTag: AudioTranscriber.shared.sourceLanguageTag)
                        if !started && !audioManager.showPermissionAlert {
                            showCanvasNotice(localizationManager.localized("recording_failed"))
                        }
                    }
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: EditorToolbarMetrics.icon))
                    .foregroundColor(.red)
                    .padding(EditorToolbarMetrics.padding)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(EditorToolbarMetrics.corner)
            }
            .accessibilityIdentifier("editor.record")
        }

        // 匯出功能選單
        Menu {
            Button {
                presentFromMenu {
                    exportAsPdf()
                }
            } label: { Label(localizationManager.localized("export_pdf"), systemImage: "doc.text.fill") }
                .accessibilityIdentifier("editor.export.pdf")
            Button {
                presentFromMenu {
                    exportAsPngImage()
                }
            } label: { Label(localizationManager.localized("export_image"), systemImage: "photo") }
                .accessibilityIdentifier("editor.export.image")
            Button {
                presentFromMenu {
                    printCurrentNotebook()
                }
            } label: { Label(localizationManager.localized("print_note"), systemImage: "printer.fill") }
                .accessibilityIdentifier("editor.export.print")
            Divider()
            // **把檔案存到使用者自己選的位置。**
            //
            // 分享面板可以把檔案送去別的 App，但它不是儲存對話框 ——
            // 使用者沒辦法說「存到我的文件資料夾」。而這個 App 的資料全部
            // 在沙盒容器裡，容器是隱藏的、使用者碰不到。Mac App Store 審查
            // 指南 2.4.5(i) 因此把這個版本退了回來。
            Button {
                presentFromMenu {
                    saveNotebookFile()
                }
            } label: { Label(localizationManager.localized("export_save_as"), systemImage: "folder.badge.plus") }
                .accessibilityIdentifier("editor.export.save_as")
            Button {
                presentFromMenu {
                    shareNotebookFile()
                }
            } label: { Label(localizationManager.localized("share_note"), systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier("editor.export.share")
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: EditorToolbarMetrics.icon, weight: .semibold))
                .foregroundColor(.white)
                .padding(EditorToolbarMetrics.padding)
                .background(Color.accentColor)
                .cornerRadius(EditorToolbarMetrics.corner)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.share")
    }


    // MARK: - 2-1. 🌟 Office Word / Google Docs 專屬打字排版工具列
    var wordModeToolbar: AnyView {
        AnyView(wordModeToolbarContent)
    }

    var wordModeToolbarContent: some View {
        VStack(spacing: 0) {
            if editorMode == .draw && (inlineEditingTextId != nil || isInlineEditingSuspendedOnThisPage) {
                HStack(spacing: 8) {
                    Image(systemName: "character.textbox")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("ed_text_toolbar_hint"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            inlineEditingTextId = nil
                            suspendedInlineTextId = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(localizationManager.localized("ed_done_back_to_ink"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12))
                Divider()
            }

            // **文字方塊物件的工具列。**
            //
            // 這一整份（新增方塊、粗體斜體底線、對齊、貼齊格線、疊層、
            // 特殊符號、框選）原本是**死的** —— 全專案沒有任何地方引用
            // `typingToolbar`，而規格要求的十六個 `editor.text.*` 識別碼
            // 全掛在它身上。結果是：靜態的跨平台對照閘門一直綠的（它掃的是
            // 原始碼裡有沒有那個字串），而使用者在 iPad 上**根本點不到**
            // 這些功能，Android 卻有。
            //
            WordToolbarView(
                activeText: Binding(
                    get: { toolbarDisplayedText() },
                    set: { updated in applyToolbarTextChange(updated) }
                ),
                hasTarget: activeTextAttachment != nil,
                selection: textSelectionTracker,
                currentHighlightHex: { toolbarHighlightHex() },
                onHighlight: { applyToolbarHighlight($0) },
                onClearFormatting: { clearToolbarFormatting() },
                canUndo: historyUndoManager.canUndo,
                canRedo: historyUndoManager.canRedo,
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                onInsertTable: { rows, cols in
                    let targetX = max(PageGeometry.printableInset, (PageGeometry.width - 440) / 2)
                    let baseOffsetY = max(PageGeometry.printableInset, canvasContentOffset.y + 120)
                    let existingCount = notebook.tableAttachments?.filter { $0.pageIndex == currentPageIndex }.count ?? 0
                    let targetY = min(PageGeometry.height - 200, baseOffsetY + CGFloat(existingCount * 40))
                    let table = NoteTableAttachment(pageIndex: currentPageIndex, x: targetX, y: targetY, rows: rows, cols: cols)
                    if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                    notebook.tableAttachments?.append(table)
                    activeSelectedObjectId = table.id
                    selectedObjectIds = [table.id]
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                    showCanvasNotice(String(format: localizationManager.localized("table_rows_cols"), "\(rows)", "\(cols)"))
                },
                onInsertImage: { showPhotoPicker = true },
                onInsertImageFile: { triggerFileImport(.image) },
                onPasteClipboardImage: { pasteScreenshotOrClipboardImage() },
                onInsertDrawingBlock: {
                    withAnimation {
                        activeInlineInkBlockId = "page-\(currentPageIndex)-ink"
                    }
                },
                onInsertLink: { showLinkPreviewSheet = true },
                onInsertDivider: { insertQuickTextSnippet("────────────────────────────────────────", onNewLine: true) },
                onInsertSnippet: { insertQuickTextSnippet($0) },
                onAddTextBox: {
                    let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
                    transitionToMode(.type)
                    inlineEditingTextId = draft.id
                },
                isSnapToGrid: snapToGrid,
                onToggleSnapToGrid: {
                    snapToGrid.toggle()
                },
                isUnderInk: activeTextAttachment.map { notebook.underInkObjectIds(forPage: currentPageIndex).contains($0.id) },
                onReorder: { op in
                    if let id = activeTextAttachment?.id {
                        reorderObject(id, op)
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))

            if isMarqueeActive {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    marqueeToolbar
                }
            }
        }
    }

    // MARK: - 2. 🌟 實體手繪工具列（水平滑動包裹、免擠壓、隨點隨用）
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var drawingToolbar: AnyView { AnyView(drawingToolbarContent) }

    /// 使用者選了一支工具（工具列、飛梭工具盤、⌘1… 快捷鍵）：換工具並在工具列旁閃一下名稱。
    /// 再按一次套索是離開套索。
    func selectEditorTool(_ tool: EditorToolType) {
        MainThreadStallMonitor.shared.breadcrumb("select tool \(tool)")
        if tool == .lasso, selectedTool == .lasso {
            exitLassoMode()
        } else {
            applyEditorTool(tool)
        }
        flashToolToast(for: tool)
    }

    /// **換工具的唯一正門**（程式自己換：筆身側鍵、插入圖紙後選住、製圖工具箱…也走這裡）。
    ///
    /// 不在手寫模式時先切回手寫 —— 直接改 `selectedTool` 的話，打字模式下換成套索或製圖筆，
    /// 工具列亮了、畫布卻不收筆。`scripts/check-state-entrypoints.py` 擋住其他地方直接改它。
    func applyEditorTool(_ tool: EditorToolType) {
        // 在文件內的手繪區塊換筆，只換工具；不可順手把整份文件的主模式
        // 改成手繪，否則「完成、回到文件」的情境會被拆掉。
        if editorMode != .draw && !isInlineInkEditing {
            transitionToMode(.draw)
        }
        selectedTool = tool // state-entry: 換工具的唯一正門
    }

    /// 點擊筆刷或繪圖工具時，在工具列緊鄰處顯示微型快顯提示，提示該工具名稱。
    func flashToolToast(for tool: EditorToolType) {
        // 若工具列已有文字標籤，使用者已能清楚辨識工具名稱，不重複彈出快顯遮罩以保證極致流暢
        guard !toolbarSettings.showLabels else {
            if activeToolToast != nil { activeToolToast = nil }
            return
        }
        let localizedName = localizationManager.localized(tool.localizationKey)
        toolToastToken += 1
        let token = toolToastToken
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            activeToolToast = (name: localizedName, icon: tool.iconName)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard toolToastToken == token else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                activeToolToast = nil
            }
        }
    }

    /// 緊鄰工具列的輕量快顯工具提示標籤
    @ViewBuilder
    var toolToastIndicator: some View {
        if let toast = activeToolToast {
            HStack(spacing: 6) {
                Image(systemName: toast.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(toast.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            .overlay(
                Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 1)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .allowsHitTesting(false)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    func exitLassoMode() {
        lasso.clear()
        applyEditorTool(previousTool ?? lastBrushTool)
        previousTool = nil
    }

    @ViewBuilder
    var eraserModeControls: some View {
        if selectedTool == .eraser {
            ToolbarSeparator().frame(height: 24)
            HStack(spacing: 4) {
                Button {
                    eraserMode = .stroke
                    canvasView?.tool = PKEraserTool(.vector)
                } label: {
                    Image(systemName: "eraser.line.dashed")
                        .font(.system(size: 16, weight: eraserMode == .stroke ? .bold : .regular))
                        .foregroundColor(eraserMode == .stroke ? .accentColor : .secondary)
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(eraserMode == .stroke ? 0.25 : 0.08))
                        .cornerRadius(DS.Radius.s)
                }
                .buttonStyle(.plain)

                Button {
                    eraserMode = .pixel
                    if #available(iOS 16.4, *) {
                        canvasView?.tool = PKEraserTool(.bitmap, width: pixelEraserWidth)
                    } else {
                        canvasView?.tool = PKEraserTool(.bitmap)
                    }
                } label: {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 16, weight: eraserMode == .pixel ? .bold : .regular))
                        .foregroundColor(eraserMode == .pixel ? .accentColor : .secondary)
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(eraserMode == .pixel ? 0.25 : 0.08))
                        .cornerRadius(DS.Radius.s)
                }
                .buttonStyle(.plain)
                
                if eraserMode == .pixel {
                    Slider(value: $pixelEraserWidth, in: 10...60, step: 1) { _ in
                        if #available(iOS 16.4, *) {
                            canvasView?.tool = PKEraserTool(.bitmap, width: pixelEraserWidth)
                        }
                    }
                    .frame(width: 80)
                    .tint(.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    var lassoRecolorButton: some View {
        Menu {
            ForEach(inkPalette(), id: \.hex) { swatch in
                if let color = Color(hex: swatch.hex) {
                    Button {
                        recolorSelectedStrokes(to: color)
                    } label: {
                        let labelText = swatch.key.isEmpty ? swatch.hex : localizationManager.localized(swatch.key)
                        Label(labelText, systemImage: "circle.fill")
                    }
                }
            }
        } label: {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
        }
        .help(localizationManager.localized("ink_change_colour"))
        .accessibilityLabel(localizationManager.localized("ink_change_colour"))
    }

    /// iOS 16.4+ 限定修飾器，低版本直接略過。
    private struct PopoverCompactAdaptation: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 16.4, *) {
                content.presentationCompactAdaptation(.popover)
            } else {
                content
            }
        }
    }

    /// 將套索選取的筆劃換色。
    func recolorSelectedStrokes(to newColor: Color) {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.recolorSelected(in: currentDrawing, to: UIColor(newColor)) else {
            showCanvasNotice("未能為選取筆劃更換色彩")
            return
        }
        applyLassoResult(updated)
        showCanvasNotice("已為圈選筆劃更換色彩")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// 在指定 Y 軸座標插入或調整垂直空間（GoodNotes 風格插入空間工具）
    /// 將落在 splitY 以下的所有手寫筆畫與附件往下推移 deltaY，並相應增加頁面高度。
    func applyVerticalSpaceInsertion(splitY: CGFloat, deltaY: CGFloat) {
        guard abs(deltaY) > 0.5 else { return }

        // 1. 移動 PKDrawing 中落在 splitY 以下的筆畫
        if let canvas = canvasView {
            let currentStrokes = canvas.drawing.strokes
            let shiftedStrokes = currentStrokes.map { stroke -> PKStroke in
                let bounds = stroke.renderBounds
                if bounds.minY >= splitY {
                    var transform = stroke.transform
                    transform = transform.translatedBy(x: 0, y: deltaY)
                    return PKStroke(ink: stroke.ink, path: stroke.path, transform: transform, mask: stroke.mask)
                }
                return stroke
            }
            canvas.drawing = PKDrawing(strokes: shiftedStrokes)
            self.currentDrawing = canvas.drawing
            self.saveCurrentPageDrawing()
        }

        // 2. 移動落在 splitY 以下的文字附件方塊
        if var attachments = notebook.textAttachments {
            var changed = false
            for i in 0..<attachments.count where attachments[i].pageIndex == currentPageIndex {
                if attachments[i].y >= splitY {
                    attachments[i].y = max(0, attachments[i].y + deltaY)
                    changed = true
                }
            }
            if changed {
                notebook.textAttachments = attachments
                commitNotebook()
            }
        }

        // 3. 移動落在 splitY 以下的圖片物件
        if var images = notebook.attachments {
            var changed = false
            for i in 0..<images.count where images[i].pageIndex == currentPageIndex {
                if images[i].y >= splitY {
                    images[i].y = max(0, images[i].y + deltaY)
                    changed = true
                }
            }
            if changed {
                notebook.attachments = images
                commitNotebook()
            }
        }

        // 4. 動態調整該頁高度，確保下推內容完整容納
        let newHeight = max(PageGeometry.height, currentPageHeight + deltaY)
        if newHeight != currentPageHeight {
            currentPageHeight = newHeight
        }

        // 觸覺回饋
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// 🌟 響應式極簡畫布懸浮工作丸專屬內容
    /// 專為 340pt 懸浮氣泡設計：輕量、緊湊、快速，不裝載重量級 ViewThatFits 與多層 WrapLayout，
    /// 徹底根除深層視圖階層引起的主執行緒堆疊溢位（Stack Overflow / EXC_BAD_ACCESS）。
    @ViewBuilder
    var minimalToolboxContent: some View {
        VStack(spacing: 8) {
            // 1. 筆刷工具水平快捷滑動列
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EditorToolType.allCases.filter { toolbarSettings.isVisible($0.parityIdentifier) }) { tool in
                        Button {
                            selectEditorTool(tool)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 14, weight: selectedTool == tool ? .bold : .regular))
                                    .foregroundColor(selectedTool == tool ? .accentColor : .primary)
                                    .frame(width: 32, height: 32)
                                    .background(selectedTool == tool ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized(tool.localizationKey))
                    }

                    // 文字方塊快捷按鈕
                    Button {
                        let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
                        transitionToMode(.type)
                        inlineEditingTextId = draft.id
                    } label: {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("add_text_box"))
                }
                .padding(.horizontal, 4)
            }

            // 2. 粗細預設點、快速色彩盤與復原
            HStack(spacing: 10) {
                // 筆刷粗細預設點
                HStack(spacing: 5) {
                    ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { w in
                        Button {
                            strokeWidth = CGFloat(w)
                        } label: {
                            Circle()
                                .fill(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: max(6, CGFloat(w)), height: max(6, CGFloat(w)))
                                .padding(3)
                                .background(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor.opacity(0.15) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 16)

                // 常用色彩
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(colorPalette.prefix(6), id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                    .overlay(Circle().stroke(selectedColor == color ? Color.accentColor : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showProColorPicker = true
                        } label: {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)

                // 復原
                Button {
                    performUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
    }

    var drawingToolbarContent: some View {
        VStack(spacing: 0) {
            if editorMode == .type && activeInlineInkBlockId != nil {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("ed_ink_toolbar_hint"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeInlineInkBlockId = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(localizationManager.localized("ed_done_back_to_doc"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12))
                Divider()
            }

            // 文字標籤（S-261b）。
            //
            // 使用者關掉的話就**不提供**帶標籤的那個變體 —— 原本這裡完全
            // 由 `ViewThatFits` 依寬度決定，塞得下就一定有字。
            // 泰文與日文的字串比英文長 30–50%，那些語言核心預設只給圖示，
            // 而使用者也該有權在任何語言下關掉它。
            ViewThatFits(in: .horizontal) {
                // fixedSize：量的是**理想寬度**。不加的話裡面的橫向捲動區（套索按鈕列）
                // 什麼寬度都「塞得下」，這一排就永遠被選中，然後被切掉一截而不是換行。
                if toolbarSettings.showLabels {
                    AnyView(drawingToolbarRow(showToolLabels: true).fixedSize(horizontal: true, vertical: false))
                }
                AnyView(drawingToolbarRow(showToolLabels: false).fixedSize(horizontal: true, vertical: false))
                if isCompactEditorWidth {
                    // 手機寬度：一條可以左右捲的列。換行的版本在 iPhone SE 上折成五、六排，
                    // 筆具面板佔掉下半個螢幕，畫布只剩一條 85pt 的縫 —— 根本寫不了字。
                    AnyView(
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) { drawingToolbarItems(showToolLabels: false) }
                        }
                    )
                } else {
                    AnyView(
                        WrapLayout(spacing: 12, lineSpacing: 8) {
                            drawingToolbarItems(showToolLabels: false)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                toolToastIndicator
            }
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        // 使用者把正在用的那一支關掉時要換一支，否則畫面上沒有任何按鈕
        // 是亮的，而畫布還在用那支筆 —— 他看到的是「我的筆不見了，
        // 但寫出來還是原本那支」。換成哪一支由核心決定（S-261），
        // Android 走同一條規則。
        .onChange(of: toolbarSettings.hiddenIdentifiers) { _ in
            DispatchQueue.main.async {
                let next = toolbarSettings.identifierAfterHiding(selectedTool.parityIdentifier)
                guard next != selectedTool.parityIdentifier,
                      let tool = EditorToolType.allCases.first(where: { $0.parityIdentifier == next })
                else { return }
                selectEditorTool(tool)
            }
        }
    }

    /// 工具列上的一顆工具按鈕：向量圖示、（筆刷才有）示範筆跡、選取時凸起。
    @ViewBuilder
    func brushToolButton(_ tool: EditorToolType, showToolLabels: Bool) -> some View {
        Button {
            selectEditorTool(tool)
        } label: {
            VStack(spacing: 2) {
                BrushToolContent(tool: tool, isSelected: selectedTool == tool, ink: selectedColor)
                // 工具列在窄螢幕上不顯示文字標籤（showToolLabels = false），
                // 那時整排都是純圖示。
                if showToolLabels {
                    Text(localizationManager.localized(tool.localizationKey))
                        .font(.system(size: 9, weight: selectedTool == tool ? .semibold : .regular))
                        .foregroundColor(selectedTool == tool ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized(tool.localizationKey))
        .accessibilityAddTraits(selectedTool == tool ? [.isSelected] : [])
        .accessibilityIdentifier(tool.parityIdentifier)
        .help(localizationManager.localized(tool.localizationKey))
    }

    func drawingToolbarRow(showToolLabels: Bool) -> some View {
        HStack(spacing: 14) {
            drawingToolbarItems(showToolLabels: showToolLabels)
        }
    }

    /// 工具列的內容。攤平成一連串子視圖，`HStack` 與 `WrapLayout` 共用同一份 ——
    /// 換行版才不會因為內容被包在容器裡而永遠不換行。
    @ViewBuilder
    func drawingToolbarItems(showToolLabels: Bool) -> some View {
                // 筆刷依「書寫／繪畫／標記」三族分段，族與族之間一條分隔線。
                // 橡皮擦與套索另成一組（見 EditorToolType.isBrush）。
                ForEach(Array([FfiBrushFamily.writing, .painting, .marking].enumerated()), id: \.offset) { index, family in
                    let tools = EditorToolType.allCases.filter {
                        $0.family == family && toolbarSettings.isVisible($0.parityIdentifier)
                    }
                    if !tools.isEmpty {
                        if index > 0 {
                            ToolbarSeparator().frame(height: 36)
                        }
                        ForEach(tools) { tool in
                            brushToolButton(tool, showToolLabels: showToolLabels)
                        }
                    }
                }

                ToolbarSeparator()
                    .frame(height: 36)

                // 擦除與選取。與筆刷分開，因為它們不沾墨，也不吃顏色與粗細。
                ForEach(EditorToolType.allCases.filter { !$0.isBrush && toolbarSettings.isVisible($0.parityIdentifier) }) { tool in
                    brushToolButton(tool, showToolLabels: showToolLabels)
                }

                Button {
                    let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
                    transitionToMode(.type)
                    inlineEditingTextId = draft.id
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 16, weight: .regular))
                        if showToolLabels {
                            Text(localizationManager.localized("add_text_box"))
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DS.Space.xs)
                    .padding(.vertical, 5)
                    .background(Color.clear)
                    .cornerRadius(DS.Radius.s)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("add_text_box"))
                .help(localizationManager.localized("add_text_box"))

                ToolbarSeparator()
                    .frame(height: 24)

                // 筆刷粗細：四個預設點 + 可拖曳的滑桿
                HStack(spacing: 6) {
                    ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { w in
                        Button {
                            strokeWidth = CGFloat(w)
                        } label: {
                            Circle()
                                .fill(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: max(6, CGFloat(w)), height: max(6, CGFloat(w)))
                                .padding(4)
                                .background(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor.opacity(0.15) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("\(localizationManager.localized("stroke_width")) \(Int(w))pt")
                    }

                    StrokeWidthSlider(
                        width: $strokeWidth,
                        tool: selectedTool,
                        color: selectedColor
                    )
                    .accessibilityIdentifier("editor.ink.width")
                }

                ToolbarSeparator()
                    .frame(height: 24)

                // 色彩選擇盤
                HStack(spacing: DS.Space.xs) {
                    ForEach(colorPalette, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: DS.Icon.small, height: DS.Icon.small)
                                .padding(3)
                                .background(Circle().fill(Color.white))
                                .overlay(
                                    Circle().stroke(DS.Color.hairline, lineWidth: 0.5)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedColor == color ? DS.Color.accent : .clear,
                                            lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(inkColorName(for: color))
                        .accessibilityAddTraits(selectedColor == color ? [.isSelected] : [])
                    }

                    Button {
                        showProColorPicker = true
                    } label: {
                        Image(systemName: "paintpalette")
                            .font(.system(size: DS.Icon.small, weight: .medium))
                            .foregroundStyle(DS.Color.secondaryText)
                            .frame(width: DS.Icon.medium, height: DS.Icon.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("pro_color"))
                    .help(localizationManager.localized("pro_color"))

                    // 🌟 專業 HSV 色相環與和諧色彈窗
                    Button {
                        showProColorWheel = true
                    } label: {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: DS.Icon.small, weight: .medium))
                            .foregroundStyle(DS.Color.secondaryText)
                            .frame(width: DS.Icon.medium, height: DS.Icon.medium)
                    }
                    .buttonStyle(.plain)
                    .help(localizationManager.localized("ink_pro_wheel"))
                    .accessibilityLabel(localizationManager.localized("ink_pro_wheel"))
                    .popover(isPresented: $showProColorWheel) {
                        ProColorWheelView(
                            selectedColorHex: Binding(
                                get: { selectedColor.toHex() ?? "#000000" },
                                set: { hex in selectedColor = Color(hex: hex) ?? selectedColor }
                            ),
                            onColorSelected: { hex in
                                selectedColor = Color(hex: hex) ?? selectedColor
                            }
                        )
                        .modifier(PopoverCompactAdaptation())
                    }
                }
                .accessibilityIdentifier("editor.ink.palette")

                ToolbarSeparator().frame(height: 24)

                // 🌟 專業筆刷平滑防抖 (Stroke Stabilizer)
                Menu {
                    Button(localizationManager.localized("stab_off")) { strokeStabilizer = 0.0 }
                    Button(localizationManager.localized("stab_light")) { strokeStabilizer = 0.25 }
                    Button(localizationManager.localized("stab_medium")) { strokeStabilizer = 0.50 }
                    Button(localizationManager.localized("stab_strong")) { strokeStabilizer = 0.85 }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 13, weight: strokeStabilizer > 0 ? .bold : .regular))
                        if strokeStabilizer > 0 {
                            Text("\(Int(strokeStabilizer * 100))%")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(strokeStabilizer > 0 ? .accentColor : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(strokeStabilizer > 0 ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .help(localizationManager.localized("stab_desc"))
                .accessibilityLabel(localizationManager.localized("stab_title"))

                // 🌟 鏡像對稱尺規 (Symmetry Guide)
                Button {
                    isSymmetryActive.toggle()
                } label: {
                    Image(systemName: isSymmetryActive ? "arrow.left.and.right.square.fill" : "arrow.left.and.right.square")
                        .font(.system(size: 14, weight: isSymmetryActive ? .bold : .regular))
                        .foregroundColor(isSymmetryActive ? .accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(isSymmetryActive ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("symmetry_guide_desc"))
                .accessibilityLabel(localizationManager.localized("symmetry_guide"))

                // 🌟 響應式極簡畫布收折按鈕
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        isMinimalistCanvasActive.toggle()
                    }
                } label: {
                    Image(systemName: isMinimalistCanvasActive ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized(
                    isMinimalistCanvasActive ? "exit_canvas_minimal_mode" : "enter_canvas_minimal_mode"
                ))
                .accessibilityLabel(localizationManager.localized(
                    isMinimalistCanvasActive ? "exit_canvas_minimal_mode" : "enter_canvas_minimal_mode"
                ))

                // 🌟 徑向飛輪快捷工具盤 (Radial Pie Menu) 手動喚醒按鈕
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        radialMenuAnchor = nil
                        showRadialMenu.toggle()
                    }
                } label: {
                    Image(systemName: showRadialMenu ? "circle.circle.fill" : "circle.circle")
                        .font(.system(size: 14, weight: showRadialMenu ? .bold : .regular))
                        .foregroundColor(showRadialMenu ? .accentColor : .secondary)
                        .padding(4)
                        .background(showRadialMenu ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("radial_menu"))
                .accessibilityLabel(localizationManager.localized("radial_menu"))
                // 與 Android `editor.radial_toggle` 同一個識別字（旅程測試靠它叫出工具盤）。
                .accessibilityIdentifier("editor.radial_toggle")

                eraserModeControls

                ToolbarSeparator()
                    .frame(height: 24)

                // 復原與重做
                HStack(spacing: 8) {
                    if toolbarSettings.isVisible("editor.ink.undo") {
                    Button {
                        performUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localizationManager.localized("undo"))
                    .help(localizationManager.localized("undo"))
                    .accessibilityIdentifier("editor.ink.undo")
                    }

                    if toolbarSettings.isVisible("editor.ink.redo") {
                    Button {
                        performRedo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localizationManager.localized("redo"))
                    .help(localizationManager.localized("redo"))
                    .accessibilityIdentifier("editor.ink.redo")
                    }

                    if toolbarSettings.isVisible("editor.ink.clear") {
                    // 「清空整頁」與復原／重做之間要有分隔（工作項 S-62）。
                    //
                    // 三顆按鈕原本等距排在一起，而其中一顆會**清掉整頁**。
                    // 手指在 iPad 上點復原點偏一格，清掉的東西雖然還原得回來，
                    // 但那一瞬間的驚嚇是真的。分隔線把「可逆」與「破壞性」
                    // 分成兩組，這是工具列最基本的一件事。
                    ToolbarSeparator()
                        .frame(height: 20)
                        .padding(.horizontal, DS.Space.xxs)

                    Button {
                        showClearConfirmAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.destructive)
                    }
                    .accessibilityLabel(localizationManager.localized("clear_page"))
                    .help(localizationManager.localized("clear_page"))
                    .accessibilityIdentifier("editor.ink.clear")
                    }
                }
    }

    // MARK: - 🌟 實體鍵盤打字與排版工具列
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var typingToolbar: AnyView { AnyView(typingToolbarContent) }

    var typingToolbarContent: some View {
        VStack(spacing: 0) {
            // 次要的插入工具收進「更多」選單；真的還是塞不下時才換行。
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    typingToolbarItems
                }
                WrapLayout(spacing: 12, lineSpacing: 8) {
                    typingToolbarItems
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 框選的動作列。掛在工具列這一層而不是畫布上 ——
            // 跟著畫布捲的話，選了下半頁的東西就得捲回去才按得到刪除。
            if isMarqueeActive {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    marqueeToolbar
                }
            }
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    @ViewBuilder
    var typingToolbarItems: some View {
        // 1. 新增文字方塊按鈕
        Button {
            let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
            transitionToMode(.type)
            inlineEditingTextId = draft.id
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 13, weight: .semibold))
                Text(localizationManager.localized("add_text_box"))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.accentColor)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("add_text_box"))
        .help(localizationManager.localized("add_text_box_desc"))
        .accessibilityIdentifier("editor.text.add_box")

        // 2. 文字排版 / 樣式面板
        Button {
            newTextDraft = activeTextAttachment ?? NoteTextAttachment(pageIndex: currentPageIndex)
            showWordStudio = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "character.textbox")
                    .font(.system(size: 13))
                Text(localizationManager.localized("tool_text"))
                    .font(.system(size: 11))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("word_studio"))
        .help(localizationManager.localized("word_studio_desc"))
        .accessibilityIdentifier("editor.text.studio")

        Divider().frame(height: 20)

        // 🌟 字級調節 (A- / 字號 / A+)
        HStack(spacing: 2) {
            Button {
                changeActiveTextFontSize(delta: -2)
            } label: {
                Text("A-")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            Text("\(Int(activeTextAttachment?.fontSize ?? 16))")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 22)

            Button {
                changeActiveTextFontSize(delta: 2)
            } label: {
                Text("A+")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        // 🌟 常用字色快捷色盤 (黑、深灰、藍、紅、綠、橙)
        HStack(spacing: 4) {
            ForEach(["#000000", "#555555", "#007AFF", "#FF3B30", "#34C759", "#FF9500"], id: \.self) { colorHex in
                Circle()
                    .fill(Color(hex: colorHex) ?? .black)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .stroke(
                                (activeTextAttachment?.textColorHex ?? "#000000").caseInsensitiveCompare(colorHex) == .orderedSame ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: (activeTextAttachment?.textColorHex ?? "#000000").caseInsensitiveCompare(colorHex) == .orderedSame ? 2.5 : 1
                            )
                    )
                    .onTapGesture {
                        setActiveTextColor(colorHex)
                    }
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 30)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        // 3. 粗體、斜體、底線快捷按鈕
        HStack(spacing: 2) {
            Button {
                toggleActiveTextBold()
            } label: {
                Image(systemName: "bold")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(isCurrentTextBold ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("text_bold"))
            .accessibilityIdentifier("editor.text.bold")

            Button {
                toggleActiveTextItalic()
            } label: {
                Image(systemName: "italic")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(isCurrentTextItalic ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("text_italic"))
            .accessibilityIdentifier("editor.text.italic")

            Button {
                toggleActiveTextUnderline()
            } label: {
                Image(systemName: "underline")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(isCurrentTextUnderline ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("text_underline"))
            .accessibilityIdentifier("editor.text.underline")
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        // 4. 段落對齊
        HStack(spacing: 2) {
            Button {
                setActiveTextAlignment("left")
            } label: {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(currentTextAlignment == "left" ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("align_left"))
            .accessibilityIdentifier("editor.text.align_left")

            Button {
                setActiveTextAlignment("center")
            } label: {
                Image(systemName: "text.aligncenter")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(currentTextAlignment == "center" ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("align_center_h"))
            .accessibilityIdentifier("editor.text.align_center")

            Button {
                setActiveTextAlignment("right")
            } label: {
                Image(systemName: "text.alignright")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(currentTextAlignment == "right" ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("align_right"))
            .accessibilityIdentifier("editor.text.align_right")
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        Divider().frame(height: 20)

        // 5. 格線/方格吸附開關
        Button {
            snapToGrid.toggle()
            // 這顆開關只有一個效果：隨點隨寫的文字落在哪裡。按下去當場說清楚，
            // 否則使用者只看到按鈕變色，不知道它到底管什麼。
            showCanvasNotice(localizationManager.localized(
                snapToGrid ? "snap_to_grid_on_notice" : "snap_to_grid_off_notice"))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: snapToGrid ? "squareshape.split.3x3" : "squareshape.dashed.squareshape")
                    .font(.system(size: 13))
                Text(localizationManager.localized("snap_to_grid"))
                    .font(.system(size: 11))
            }
            .foregroundColor(snapToGrid ? .white : .primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(snapToGrid ? Color.accentColor : Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("snap_to_grid"))
        .help(localizationManager.localized("snap_to_grid_desc"))
        .accessibilityIdentifier("editor.text.snap_grid")

        // 6. 圖層層級調整（物件與文字相對順序）
        HStack(spacing: 2) {
            Button {
                bringActiveObjectForward()
            } label: {
                Image(systemName: "square.2.layers.3d.top.filled")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("layer_bring_forward"))
            .help(localizationManager.localized("layer_bring_forward_desc"))
            .accessibilityIdentifier("editor.text.layer_forward")

            Button {
                sendActiveObjectBackward()
            } label: {
                Image(systemName: "square.2.layers.3d.bottom.filled")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("layer_send_backward"))
            .help(localizationManager.localized("layer_send_backward_desc"))
            .accessibilityIdentifier("editor.text.layer_backward")
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        Divider().frame(height: 20)

        // 7. 特殊符號選單
        Menu {
            ForEach(symbolCategories(), id: \.self) { category in
                Menu(localizationManager.localized(symbolCategoryKey(category))) {
                    ForEach(symbolPalette(category: category), id: \.self) { sym in
                        Button(sym) {
                            insertQuickTextSnippet(sym)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "star.bubble")
                    .font(.system(size: 14))
                Text(localizationManager.localized("special_symbols"))
                    .accessibilityIdentifier("editor.text.symbols")
                    .font(.system(size: 11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)

        // 8. 框選模式
        Button {
            setMarqueeActive(!isMarqueeActive)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 14))
                Text(localizationManager.localized("marquee_select"))
                    .accessibilityIdentifier("editor.text.select")
                    .font(.system(size: 11))
            }
            .foregroundColor(isMarqueeActive ? .white : .primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(isMarqueeActive ? Color.accentColor : Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("marquee_hint"))
        .help(localizationManager.localized("marquee_hint"))

        // 9. 插入連結
        Button {
            showLinkPreviewSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                Text(localizationManager.localized("insert_link"))
                    .font(.system(size: 11))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("insert_link"))
        .help(localizationManager.localized("insert_link"))
        .accessibilityIdentifier("editor.text.link")

        Spacer()

        // 10. 復原與重做
        HStack(spacing: 8) {
            Button {
                performUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(localizationManager.localized("undo"))
            .help(localizationManager.localized("undo"))
            .accessibilityIdentifier("editor.text.undo")

            Button {
                performRedo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(localizationManager.localized("redo"))
            .help(localizationManager.localized("redo"))
            .accessibilityIdentifier("editor.text.redo")
        }
    }


}

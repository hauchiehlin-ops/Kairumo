//
//  EditorFloatingPanels.swift
//  Kairumo
//
//  編輯器浮動控制面板：尺規輔助列、錄音播放與即時狀態條、浮動錄音徽章、套索操作列、草圖智慧修飾浮動條
//

import SwiftUI
import PencilKit

// MARK: - 浮動控制面板擴充

extension NotebookEditorView {
    // MARK: - 3. 尺規旋轉與量測輔助列
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var rulerControlBar: AnyView { AnyView(rulerControlBarContent) }

    var rulerControlBarContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "ruler")
                .foregroundColor(.accentColor)

            Text(localizationManager.localized("ruler_mode"))
                .font(.caption)
                .fontWeight(.bold)

            Text(localizationManager.localized("ruler_hint"))
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Button(localizationManager.localized("close_ruler")) {
                isRulerActive = false
            }
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
    }

    // MARK: - 4. 錄音播放器橫條
    func audioPlaybackBar(fileName: String) -> AnyView { AnyView(audioPlaybackBarContent(fileName: fileName)) }

    func audioPlaybackBarContent(fileName: String) -> some View {
        // 錄音現在住在套件裡（會被同步）；舊的還在 Kairumo Record，
        // 由 store 決定該指向哪一個。
        let fileUrl = store.recordingFileURL(fileName: fileName, notebookId: notebook.id)
        let isCurrentPlaying = audioManager.isPlaying && audioManager.playingRecordingId == fileName

        return HStack(spacing: 12) {
            Button {
                audioManager.playAudio(url: fileUrl, recordingId: fileName)
            } label: {
                Image(systemName: isCurrentPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }

            Text(localizationManager.localized("attached_audio"))
                .font(.caption)
                .fontWeight(.medium)

            ProgressView(value: isCurrentPlaying ? audioManager.playbackProgress : 0.0)
                .progressViewStyle(.linear)

            Button {
                notebook.hasRecording = false
                notebook.recordingAudioPath = nil
                commitNotebook()
                audioManager.stopPlayback()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }

    // MARK: - 5. 即時錄音狀態列
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var liveRecordingBar: AnyView { AnyView(liveRecordingBarContent) }

    var liveRecordingBarContent: some View {
        let isPaused = audioManager.status == .paused
        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isPaused ? Color.orange : Color.red)
                    .frame(width: 10, height: 10)
                Text(isPaused
                     ? "\(localizationManager.localized("recording_paused")): \(formatTime(seconds: audioManager.elapsedSeconds))"
                     : "\(localizationManager.localized("sync_recording_in_progress")): \(formatTime(seconds: audioManager.elapsedSeconds))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isPaused ? .orange : .red)
            }

            HStack(spacing: 2) {
                ForEach(0..<audioManager.audioLevels.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPaused ? Color.orange.opacity(0.6) : Color.red)
                        .frame(width: 3, height: max(4, audioManager.audioLevels[i] * 24))
                }
            }
            .frame(height: 24)

            Spacer()

            // 暫停 / 繼續按鈕
            Button {
                if isPaused {
                    audioManager.resumeRecording()
                } else {
                    audioManager.pauseRecording()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused
                         ? localizationManager.localized("resume_recording")
                         : localizationManager.localized("pause_recording"))
                }
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(isPaused ? .white : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isPaused ? Color.orange : Color.orange.opacity(0.15))
                .cornerRadius(6)
            }

            // 完成錄音按鈕
            Button(localizationManager.localized("finish_recording")) {
                stopAndSaveRecording()
            }
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background((isPaused ? Color.orange : Color.red).opacity(0.08))
    }

    // MARK: - 6. 畫布上之即時浮動錄音圖示徽章
    func floatingAudioBadge(fileName: String) -> AnyView { AnyView(floatingAudioBadgeContent(fileName: fileName)) }

    func floatingAudioBadgeContent(fileName: String) -> some View {
        // 錄音現在住在套件裡（會被同步）；舊的還在 Kairumo Record，
        // 由 store 決定該指向哪一個。
        let fileUrl = store.recordingFileURL(fileName: fileName, notebookId: notebook.id)
        let isCurrentPlaying = audioManager.isPlaying && audioManager.playingRecordingId == fileName

        return HStack(spacing: 8) {
            Button {
                audioManager.playAudio(url: fileUrl, recordingId: fileName)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                    Image(systemName: isCurrentPlaying ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(isCurrentPlaying ? localizationManager.localized("audio_playing") : localizationManager.localized("attached_audio"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Text(localizationManager.localized("audio_hint"))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 18)

            Button {
                audioManager.openRecordingsFolderInFinder(selectingFileURL: fileUrl)
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(localizationManager.localized("open_folder"))
            .help(localizationManager.localized("open_folder"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
    }

    // MARK: - 7. 🌟 套索選取浮動工具列（圈選筆跡後隨選隨刪、隨選隨複製）
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    /// 套索的圈、選取框與快顯工具列（兩種頁面模式共用）。
    ///
    /// - `zoom`/`offset`：頁面座標換成這一層座標的方式（整頁模式是畫布的縮放與捲動；
    ///   連續模式畫在頁面裡面，是 1 與 0）。
    /// - `barScale`：工具列本身要乘的倍率。連續模式整頁被 `scaleEffect` 縮過，
    ///   工具列要反向放大回螢幕上的原尺寸，不然縮小時按鈕小到按不到。
    @ViewBuilder
    func lassoSelectionDecoration(zoom: CGFloat, offset: CGPoint, viewSize: CGSize, barScale: CGFloat = 1) -> some View {
        let toView = { (p: CGPoint) -> CGPoint in
            CGPoint(x: p.x * zoom - offset.x, y: p.y * zoom - offset.y)
        }
        let loop = lasso.path.isEmpty ? lasso.committed : lasso.path
        if selectedTool == .lasso && !loop.isEmpty {
            LassoPathOverlay(path: loop.map(toView), isCommitted: lasso.path.isEmpty)
                .allowsHitTesting(false)
        }
        // 圈完、有選到東西才出工具列。選取框用「圈 ∪ 選中筆畫的外框」，
        // 露出圈外的筆畫也在框內，拖那一段一樣拖得動。
        if selectedTool == .lasso && lasso.hasSelection && lasso.path.isEmpty, let page = lasso.boundingRect {
            let origin = toView(page.origin)
            let rect = CGRect(x: origin.x, y: origin.y, width: page.width * zoom, height: page.height * zoom)
            let barHalfWidth = 230 * barScale
            let barGap = 30 * barScale
            // 上方放不下（貼著可視範圍頂端）就改放在選取框下方。
            let barY = rect.minY - barGap >= barGap ? rect.minY - barGap : rect.maxY + barGap
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                .frame(width: rect.width + 16, height: rect.height + 16)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            lassoFloatingActionBar
                .scaleEffect(barScale)
                .position(
                    x: min(max(rect.midX, barHalfWidth), max(barHalfWidth, viewSize.width - barHalfWidth)),
                    y: min(max(barY, barGap), max(barGap, viewSize.height - barGap))
                )
                .zIndex(100)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if selectedTool == .lasso && lasso.hasSelection {
                            watchdog.notifyLassoSelectionStalled()
                        }
                    }
                }
        }
    }

    /// 套索模式、沒有選取、剪貼簿有筆跡時的「貼上」入口。
    ///
    /// 快顯工具列只在有選取時出現；剪下之後選取就清空了，不另外給入口的話
    /// 剪下來的東西就再也貼不回去。
    @ViewBuilder
    var lassoPastePill: some View {
        if selectedTool == .lasso && !lasso.hasSelection && lasso.path.isEmpty && lasso.canPaste {
            Button {
                pasteStrokes()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                    Text(localizationManager.localized("paste_strokes"))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .accessibilityIdentifier("editor.lasso.paste")
            .accessibilityLabel(localizationManager.localized("paste_strokes"))
            .help(localizationManager.localized("paste_strokes_hint"))
            .padding(.top, 12)
            .transition(.opacity)
        }
    }

    /// 物件剪下／複製／貼上浮動膠囊：
    /// - 選取任一物件時（手繪或打字模式、單頁或連續模式）：顯示「剪下」、「複製」按鈕。
    /// - 物件剪貼簿有內容時：顯示「貼上」（貼到目前焦點頁）與「點選位置貼上」（點擊任意頁面任意座標貼上）。
    @ViewBuilder
    var objectPastePill: some View {
        let hasSelection = !effectiveSelectedObjectIds.isEmpty && inlineEditingTextId == nil && !isMarqueeActive
        let hasClipboard = !objectClipboard.isEmpty
        if isPlacingPasteObject && hasClipboard {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .foregroundColor(.accentColor)
                Text(localizationManager.localized("tap_to_paste_object"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Button {
                    isPlacingPasteObject = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.object.paste.cancel_place")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.45), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.10), radius: 4, y: 1)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .transition(.opacity)
        } else if hasSelection || hasClipboard {
            HStack(spacing: 8) {
                if hasSelection {
                    Button {
                        cutSelection()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "scissors")
                            Text(localizationManager.localized("action_cut"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                    .accessibilityIdentifier("editor.object.cut")

                    Divider().frame(height: 16)

                    Button {
                        copySelection()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc")
                            Text(localizationManager.localized("action_copy"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .accessibilityIdentifier("editor.object.copy")
                }

                if hasSelection && hasClipboard {
                    Divider().frame(height: 16)
                }

                if hasClipboard {
                    Button {
                        paste(objectClipboard, onPage: currentPageIndex, at: nil)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.clipboard")
                            Text(localizationManager.localized("action_paste"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .accessibilityIdentifier("editor.object.paste")

                    Divider().frame(height: 16)

                    Button {
                        isPlacingPasteObject = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "hand.point.up.left.fill")
                            Text(localizationManager.localized("paste_at_location"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("editor.object.paste_at_location")

                    Divider().frame(height: 16)

                    Button {
                        objectClipboard = []
                        isPlacingPasteObject = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editor.object.paste.clear")
                }
            }
            .font(.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.10), radius: 4, y: 1)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .transition(.opacity)
        }
    }

    /// 「點選位置貼上」時覆蓋在每一頁上的透明點擊層：無論手繪或打字、單頁或連續模式，
    /// 點擊該頁任意座標 `(x, y)` 即將 `objectClipboard` 對齊該座標貼到第 `page` 頁。
    func pasteTargetLayer(forPage page: Int) -> some View {
        Color.accentColor.opacity(0.001)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                SpatialTapGesture(coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onEnded { value in
                        lastPastePlacementAt = Date()
                        if pageDisplayMode == .continuous {
                            focusContinuousPage(page)
                        } else {
                            switchToPage(page)
                        }
                        paste(objectClipboard, onPage: page, at: value.location)
                        isPlacingPasteObject = false
                    }
            )
    }

    var lassoFloatingActionBar: AnyView {
        AnyView(
            ViewThatFits(in: .horizontal) {
                lassoFloatingActionBarRow(showLabels: true, showHint: false)
                    .fixedSize(horizontal: true, vertical: false)
                lassoFloatingActionBarRow(showLabels: false, showHint: false)
                    .fixedSize(horizontal: true, vertical: false)
            }
        )
    }

    func lassoDeleteButton(showLabel: Bool = true) -> some View {
        Button {
            deleteSelectedStrokes()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash.fill")
                    .font(.caption2)
                if showLabel {
                    Text(localizationManager.localized("delete_selected"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, showLabel ? 10 : 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("delete_selected"))
        .help(localizationManager.localized("delete_selected"))
    }

    var lassoCancelButton: some View {
        Button {
            exitLassoMode()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
        .accessibilityLabel(localizationManager.localized("ed_cancel_selection"))
        .help(localizationManager.localized("cancel_selection_hint"))
    }

    @ViewBuilder
    func lassoFloatingActionItems(showLabels: Bool) -> some View {
        lassoActionButton("scissors", "cut_selected", "cut_selected_hint", showLabel: showLabels) {
            cutSelectedStrokes()
        }
        lassoActionButton("doc.on.doc", "copy_selected", "copy_selected_hint", showLabel: showLabels) {
            copySelectedStrokes()
        }
        lassoActionButton("photo.on.rectangle", "save_as_sticker", "save_as_sticker", showLabel: showLabels) {
            saveSelectedAsSticker()
        }
        lassoActionButton("plus.square.on.square", "duplicate_selected", "duplicate_selected_hint", showLabel: showLabels) {
            duplicateSelectedStrokes()
        }
        if lasso.canPaste {
            lassoActionButton("doc.on.clipboard", "paste_strokes", "paste_strokes_hint", showLabel: showLabels) {
                pasteStrokes()
            }
        }
        lassoRecolorButton
        lassoActionButton("text.viewfinder", "recognize_handwriting", "recognize_handwriting", showLabel: showLabels) {
            recognizeHandwritingToTextBox()
        }
        lassoActionButton("link.badge.plus", "sticky_anchor_text", "sticky_anchored_hint", showLabel: showLabels) {
            anchorSelectedStrokesToNearestText()
        }
        lassoDeleteButton(showLabel: showLabels)

        Divider()
            .frame(height: 16)

        lassoCancelButton
    }

    func lassoFloatingActionBarRow(showLabels: Bool, showHint: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lasso")
                .foregroundColor(.accentColor)
                .font(.subheadline)

            if showHint {
                Text(localizationManager.localized("lasso_active_hint"))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Divider()
                    .frame(height: 16)
            }

            lassoFloatingActionItems(showLabels: showLabels)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
    }


    // MARK: - 🌟 草圖智慧修飾浮動控制面板
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var sketchRefineFloatingBar: AnyView { AnyView(sketchRefineFloatingBarContent) }

    var sketchRefineFloatingBarContent: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                    .font(.system(size: 15, weight: .bold))
                Text(localizationManager.localized("refine_sketch"))
                    .font(.subheadline.bold())
            }

            Divider()
                .frame(height: 20)

            // 修飾強度調節
            HStack(spacing: 6) {
                Text("\(localizationManager.localized("refine_strength")): \(Int(refineIntensity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $refineIntensity, in: 0.2...1.0, step: 0.05)
                    .frame(width: 90)
            }

            Divider()
                .frame(height: 20)

            // 一鍵修飾
            Button {
                applySketchRefine()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(localizationManager.localized("apply_refine"))
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // 恢復原草圖
            Button {
                restoreOriginalSketch()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text(localizationManager.localized("restore_original"))
                        .font(.caption)
                }
                .foregroundColor(originalSketchBackup != nil ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(originalSketchBackup != nil ? 0.15 : 0.06))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(originalSketchBackup == nil)

            // 重做修飾
            Button {
                redoSketchRefine()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.forward")
                    Text(localizationManager.localized("redo_refine"))
                        .font(.caption)
                }
                .foregroundColor(refinedSketchCache != nil ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(refinedSketchCache != nil ? 0.15 : 0.06))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(refinedSketchCache == nil)

            Spacer()

            // 關閉控制列
            Button {
                withAnimation {
                    showSketchRefineBar = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
        .padding(.horizontal, 16)
    }

    func applySketchRefine() {
        guard !currentDrawing.strokes.isEmpty else { return }
        if originalSketchBackup == nil {
            originalSketchBackup = currentDrawing
        }
        let refined = SketchRefineEngine.refine(drawing: currentDrawing, intensity: refineIntensity)
        refinedSketchCache = refined
        currentDrawing = refined
        canvasView?.drawing = refined
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: refined)
    }

    /// 辨識目前這一頁的手寫，結果存進筆記本供搜尋。
    ///
    /// **不會改動任何一筆畫。** 辨識只是讓手寫找得到 —— 手寫筆記的價值
    /// 就在那個手寫。分組規則走核心（與 Android 同一份），辨識引擎是 Vision。
    func recognizeHandwritingOnCurrentPage() {
        isRecognisingHandwriting = true
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else {
            recognitionMessage = localizationManager.localized("no_strokes")
            return
        }
        recognitionMessage = localizationManager.localized("recognizing")
        // Vision 吃 BCP-47；AppLanguage 的 rawValue 正好就是（zh-Hant / ja / …）。
        let language = localizationManager.currentLanguage.rawValue
        let page = currentPageIndex

        Task { @MainActor in
            switch await HandwritingRecognizer.recognize(drawing: drawing, languageTag: language) {
            case .success(let groups):
                let text = groups.map(\.text).joined(separator: " ")
                guard !text.isEmpty else {
                    recognitionMessage = localizationManager.localized("no_recognition_result")
                    return
                }
                var map = notebook.recognizedText ?? [:]
                map[String(page)] = text
                notebook.recognizedText = map
                commitNotebook()
                recognitionMessage = text
            case .failure(let error):
                // 逐項分開 —— 「辨識失敗」四個字幫不了使用者。
                recognitionMessage = switch error {
                case .unsupported(let detail): detail
                case .noModel(let tag): String(
                    format: localizationManager.localized("hwr_no_model"), tag)
                case .recognitionFailed(let detail): detail
                }
            }
        }
    }

    func restoreOriginalSketch() {
        guard let original = originalSketchBackup else { return }
        currentDrawing = original
        canvasView?.drawing = original
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: original)
    }

    func redoSketchRefine() {
        guard let refined = refinedSketchCache else { return }
        currentDrawing = refined
        canvasView?.drawing = refined
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: refined)
    }


}

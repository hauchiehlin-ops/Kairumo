package com.kairumo.padnote

import android.Manifest
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.mimeTypes
import androidx.compose.ui.draganddrop.toAndroidDragEvent
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.text.style.*
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.*
import androidx.compose.ui.zIndex
import androidx.documentfile.provider.DocumentFile
import com.kairumo.padnote.account.*
import com.kairumo.padnote.ai.*
import com.kairumo.padnote.asset.*
import com.kairumo.padnote.audio.*
import com.kairumo.padnote.backup.*
import com.kairumo.padnote.canvas.*
import com.kairumo.padnote.canvas.fingerTapOnLockedObject
import com.kairumo.padnote.chart.*
import com.kairumo.padnote.collab.*
import com.kairumo.padnote.comment.*
import com.kairumo.padnote.image.*
import com.kairumo.padnote.ink.*
import com.kairumo.padnote.library.*
import com.kairumo.padnote.math.*
import com.kairumo.padnote.model3d.*
import com.kairumo.padnote.platform.*
import com.kairumo.padnote.profile.*
import com.kairumo.padnote.shape.*
import com.kairumo.padnote.sync.*
import com.kairumo.padnote.table.*
import com.kairumo.padnote.text.*
import com.kairumo.padnote.text.doubleTapToWrite
import com.kairumo.padnote.theme.*
import com.kairumo.padnote.ui.*
import kotlinx.coroutines.*
import uniffi.padnote_core.*
import java.io.File


/**
 * 編輯器共享狀態持有者（State Holder Pattern）。
 * 集中管理畫布視區、手寫引擎、所有多媒體圖層與 26 個浮動面板的狀態。
 */
internal class EditorCanvasContext {
    lateinit var sessionRevisionState: MutableIntState
    var sessionRevision: Int
        get() = sessionRevisionState.intValue
        set(v) { sessionRevisionState.intValue = v }
    lateinit var openMarkIdState: MutableState<String?>
    var openMarkId: String?
        get() = openMarkIdState.value
        set(v) { openMarkIdState.value = v }
    lateinit var showRevertConfirmState: MutableState<Boolean>
    var showRevertConfirm: Boolean
        get() = showRevertConfirmState.value
        set(v) { showRevertConfirmState.value = v }
    lateinit var pageCountState: MutableIntState
    var pageCount: Int
        get() = pageCountState.intValue
        set(v) { pageCountState.intValue = v }
    lateinit var pageIndexState: MutableIntState
    var pageIndex: Int
        get() = pageIndexState.intValue
        set(v) { pageIndexState.intValue = v }
    lateinit var continuousScrollRequestState: MutableIntState
    var continuousScrollRequest: Int
        get() = continuousScrollRequestState.intValue
        set(v) { continuousScrollRequestState.intValue = v }
    lateinit var pageDisplayModeState: MutableState<PageDisplayMode>
    var pageDisplayMode: PageDisplayMode
        get() = pageDisplayModeState.value
        set(v) { pageDisplayModeState.value = v }
    lateinit var recordingState: MutableState<Boolean>
    var recording: Boolean
        get() = recordingState.value
        set(v) { recordingState.value = v }
    lateinit var recordingPausedState: MutableState<Boolean>
    var recordingPaused: Boolean
        get() = recordingPausedState.value
        set(v) { recordingPausedState.value = v }
    lateinit var recordSecondsState: MutableIntState
    var recordSeconds: Int
        get() = recordSecondsState.intValue
        set(v) { recordSecondsState.intValue = v }
    lateinit var backlogUsState: MutableLongState
    var backlogUs: Long
        get() = backlogUsState.longValue
        set(v) { backlogUsState.longValue = v }
    lateinit var messageState: MutableState<String?>
    var message: String?
        get() = messageState.value
        set(v) { messageState.value = v }
    lateinit var docsAssetState: MutableState<String?>
    var docsAsset: String?
        get() = docsAssetState.value
        set(v) { docsAssetState.value = v }
    lateinit var textRevisionState: MutableIntState
    var textRevision: Int
        get() = textRevisionState.intValue
        set(v) { textRevisionState.intValue = v }
    lateinit var selectedTextIdState: MutableState<String?>
    var selectedTextId: String?
        get() = selectedTextIdState.value
        set(v) { selectedTextIdState.value = v }
    lateinit var editingTextState: MutableState<TextBox?>
    var editingText: TextBox?
        get() = editingTextState.value
        set(v) { editingTextState.value = v }
    lateinit var chartRevisionState: MutableIntState
    var chartRevision: Int
        get() = chartRevisionState.intValue
        set(v) { chartRevisionState.intValue = v }
    lateinit var selectedChartIdState: MutableState<String?>
    var selectedChartId: String?
        get() = selectedChartIdState.value
        set(v) { selectedChartIdState.value = v }
    lateinit var editingChartState: MutableState<ChartObject?>
    var editingChart: ChartObject?
        get() = editingChartState.value
        set(v) { editingChartState.value = v }
    lateinit var insertingChartState: MutableState<Boolean>
    var insertingChart: Boolean
        get() = insertingChartState.value
        set(v) { insertingChartState.value = v }
    lateinit var tableRevisionState: MutableIntState
    var tableRevision: Int
        get() = tableRevisionState.intValue
        set(v) { tableRevisionState.intValue = v }
    lateinit var selectedTableIdState: MutableState<String?>
    var selectedTableId: String?
        get() = selectedTableIdState.value
        set(v) { selectedTableIdState.value = v }
    lateinit var editingTableState: MutableState<NoteTable?>
    var editingTable: NoteTable?
        get() = editingTableState.value
        set(v) { editingTableState.value = v }
    lateinit var editingShapeState: MutableState<NoteShape?>
    var editingShape: NoteShape?
        get() = editingShapeState.value
        set(v) { editingShapeState.value = v }
    lateinit var selectedConnectionIdState: MutableState<String?>
    var selectedConnectionId: String?
        get() = selectedConnectionIdState.value
        set(v) { selectedConnectionIdState.value = v }
    lateinit var editingConnectionState: MutableState<NoteConnection?>
    var editingConnection: NoteConnection?
        get() = editingConnectionState.value
        set(v) { editingConnectionState.value = v }
    lateinit var connectionDraftState: MutableState<ConnectionDraft?>
    var connectionDraft: ConnectionDraft?
        get() = connectionDraftState.value
        set(v) { connectionDraftState.value = v }
    lateinit var insertingTableState: MutableState<Boolean>
    var insertingTable: Boolean
        get() = insertingTableState.value
        set(v) { insertingTableState.value = v }
    lateinit var editorModeState: MutableState<EditorMode>
    var editorMode: EditorMode
        get() = editorModeState.value
        set(v) { editorModeState.value = v }
    lateinit var snapToGridState: MutableState<Boolean>
    var snapToGrid: Boolean
        get() = snapToGridState.value
        set(v) { snapToGridState.value = v }
    lateinit var showProColorWheelState: MutableState<Boolean>
    var showProColorWheel: Boolean
        get() = showProColorWheelState.value
        set(v) { showProColorWheelState.value = v }
    lateinit var minimalistCanvasModeState: MutableState<Boolean>
    var minimalistCanvasMode: Boolean
        get() = minimalistCanvasModeState.value
        set(v) { minimalistCanvasModeState.value = v }
    lateinit var floatingPillExpandedState: MutableState<Boolean>
    var floatingPillExpanded: Boolean
        get() = floatingPillExpandedState.value
        set(v) { floatingPillExpandedState.value = v }
    lateinit var strokeStabilizerState: MutableFloatState
    var strokeStabilizer: Float
        get() = strokeStabilizerState.floatValue
        set(v) { strokeStabilizerState.floatValue = v }
    lateinit var showSymmetryGuideState: MutableState<Boolean>
    var showSymmetryGuide: Boolean
        get() = showSymmetryGuideState.value
        set(v) { showSymmetryGuideState.value = v }
    lateinit var showRadialMenuState: MutableState<Boolean>
    var showRadialMenu: Boolean
        get() = showRadialMenuState.value
        set(v) { showRadialMenuState.value = v }
    lateinit var radialMenuCenterState: MutableState<Offset>
    var radialMenuCenter: Offset
        get() = radialMenuCenterState.value
        set(v) { radialMenuCenterState.value = v }
    lateinit var magneticGuideActiveState: MutableState<Boolean>
    var magneticGuideActive: Boolean
        get() = magneticGuideActiveState.value
        set(v) { magneticGuideActiveState.value = v }
    lateinit var magneticGuideStartState: MutableState<Offset>
    var magneticGuideStart: Offset
        get() = magneticGuideStartState.value
        set(v) { magneticGuideStartState.value = v }
    lateinit var magneticGuideEndState: MutableState<Offset>
    var magneticGuideEnd: Offset
        get() = magneticGuideEndState.value
        set(v) { magneticGuideEndState.value = v }
    lateinit var stackRevisionState: MutableIntState
    var stackRevision: Int
        get() = stackRevisionState.intValue
        set(v) { stackRevisionState.intValue = v }
    lateinit var showStackPanelState: MutableState<Boolean>
    var showStackPanel: Boolean
        get() = showStackPanelState.value
        set(v) { showStackPanelState.value = v }
    lateinit var showCalculatorState: MutableState<Boolean>
    var showCalculator: Boolean
        get() = showCalculatorState.value
        set(v) { showCalculatorState.value = v }
    lateinit var showProColorsState: MutableState<Boolean>
    var showProColors: Boolean
        get() = showProColorsState.value
        set(v) { showProColorsState.value = v }
    lateinit var pinsState: MutableState<MutableList<CommentPin>>
    var pins: MutableList<CommentPin>
        get() = pinsState.value
        set(v) { pinsState.value = v }
    lateinit var isPlacingCommentPinState: MutableState<Boolean>
    var isPlacingCommentPin: Boolean
        get() = isPlacingCommentPinState.value
        set(v) { isPlacingCommentPinState.value = v }
    lateinit var isRecognisingHandwritingState: MutableState<Boolean>
    var isRecognisingHandwriting: Boolean
        get() = isRecognisingHandwritingState.value
        set(v) { isRecognisingHandwritingState.value = v }
    lateinit var pinRevisionState: MutableIntState
    var pinRevision: Int
        get() = pinRevisionState.intValue
        set(v) { pinRevisionState.intValue = v }
    lateinit var openPinState: MutableState<CommentPin?>
    var openPin: CommentPin?
        get() = openPinState.value
        set(v) { openPinState.value = v }
    lateinit var models3DState: MutableState<MutableList<Model3DObject>>
    var models3D: MutableList<Model3DObject>
        get() = models3DState.value
        set(v) { models3DState.value = v }
    lateinit var model3DRevisionState: MutableIntState
    var model3DRevision: Int
        get() = model3DRevisionState.intValue
        set(v) { model3DRevisionState.intValue = v }
    lateinit var linksState: MutableState<MutableList<LinkObject>>
    var links: MutableList<LinkObject>
        get() = linksState.value
        set(v) { linksState.value = v }
    lateinit var linkRevisionState: MutableIntState
    var linkRevision: Int
        get() = linkRevisionState.intValue
        set(v) { linkRevisionState.intValue = v }
    lateinit var selectedLinkIdState: MutableState<String?>
    var selectedLinkId: String?
        get() = selectedLinkIdState.value
        set(v) { selectedLinkIdState.value = v }
    lateinit var insertingLinkState: MutableState<Boolean>
    var insertingLink: Boolean
        get() = insertingLinkState.value
        set(v) { insertingLinkState.value = v }
    lateinit var editingLinkState: MutableState<LinkObject?>
    var editingLink: LinkObject?
        get() = editingLinkState.value
        set(v) { editingLinkState.value = v }
    lateinit var audioCardsState: MutableState<MutableList<AudioObject>>
    var audioCards: MutableList<AudioObject>
        get() = audioCardsState.value
        set(v) { audioCardsState.value = v }
    lateinit var audioRevisionState: MutableIntState
    var audioRevision: Int
        get() = audioRevisionState.intValue
        set(v) { audioRevisionState.intValue = v }
    lateinit var selectedAudioIdState: MutableState<String?>
    var selectedAudioId: String?
        get() = selectedAudioIdState.value
        set(v) { selectedAudioIdState.value = v }
    lateinit var playingAudioIdState: MutableState<String?>
    var playingAudioId: String?
        get() = playingAudioIdState.value
        set(v) { playingAudioIdState.value = v }
    lateinit var insertingAudioState: MutableState<Boolean>
    var insertingAudio: Boolean
        get() = insertingAudioState.value
        set(v) { insertingAudioState.value = v }
    lateinit var marqueeActiveState: MutableState<Boolean>
    var marqueeActive: Boolean
        get() = marqueeActiveState.value
        set(v) { marqueeActiveState.value = v }
    lateinit var marqueeSelectionState: MutableState<Set<String>>
    var marqueeSelection: Set<String>
        get() = marqueeSelectionState.value
        set(v) { marqueeSelectionState.value = v }
    lateinit var marqueeAdditiveState: MutableState<Boolean>
    var marqueeAdditive: Boolean
        get() = marqueeAdditiveState.value
        set(v) { marqueeAdditiveState.value = v }
    lateinit var objectClipboardState: MutableState<List<com.kairumo.padnote.canvas.ClipboardObject>>
    var objectClipboard: List<com.kairumo.padnote.canvas.ClipboardObject>
        get() = objectClipboardState.value
        set(v) { objectClipboardState.value = v }
    lateinit var isPlacingPasteObjectState: MutableState<Boolean>
    var isPlacingPasteObject: Boolean
        get() = isPlacingPasteObjectState.value
        set(v) { isPlacingPasteObjectState.value = v }
    lateinit var renamingAudioState: MutableState<AudioObject?>
    var renamingAudio: AudioObject?
        get() = renamingAudioState.value
        set(v) { renamingAudioState.value = v }
    lateinit var selectedModel3DIdState: MutableState<String?>
    var selectedModel3DId: String?
        get() = selectedModel3DIdState.value
        set(v) { selectedModel3DIdState.value = v }
    lateinit var editingModel3DState: MutableState<Model3DObject?>
    var editingModel3D: Model3DObject?
        get() = editingModel3DState.value
        set(v) { editingModel3DState.value = v }
    lateinit var insertingModel3DState: MutableState<Boolean>
    var insertingModel3D: Boolean
        get() = insertingModel3DState.value
        set(v) { insertingModel3DState.value = v }
    lateinit var imageRevisionState: MutableIntState
    var imageRevision: Int
        get() = imageRevisionState.intValue
        set(v) { imageRevisionState.intValue = v }
    lateinit var selectedImageIdState: MutableState<String?>
    var selectedImageId: String?
        get() = selectedImageIdState.value
        set(v) { selectedImageIdState.value = v }
    lateinit var editingImageState: MutableState<NoteImage?>
    var editingImage: NoteImage?
        get() = editingImageState.value
        set(v) { editingImageState.value = v }
    lateinit var pendingSaveBytesState: MutableState<ByteArray?>
    var pendingSaveBytes: ByteArray?
        get() = pendingSaveBytesState.value
        set(v) { pendingSaveBytesState.value = v }
    lateinit var pdfToInsertState: MutableState<java.io.File?>
    var pdfToInsert: java.io.File?
        get() = pdfToInsertState.value
        set(v) { pdfToInsertState.value = v }
    lateinit var importedDocumentState: MutableState<DocumentImport.Parsed?>
    var importedDocument: DocumentImport.Parsed?
        get() = importedDocumentState.value
        set(v) { importedDocumentState.value = v }
    lateinit var shapeRevisionState: MutableIntState
    var shapeRevision: Int
        get() = shapeRevisionState.intValue
        set(v) { shapeRevisionState.intValue = v }
    lateinit var selectedShapeIdsState: MutableState<Set<String>>
    var selectedShapeIds: Set<String>
        get() = selectedShapeIdsState.value
        set(v) { selectedShapeIdsState.value = v }
    lateinit var insertingShapeState: MutableState<Boolean>
    var insertingShape: Boolean
        get() = insertingShapeState.value
        set(v) { insertingShapeState.value = v }
    lateinit var showLayerPanelState: MutableState<Boolean>
    var showLayerPanel: Boolean
        get() = showLayerPanelState.value
        set(v) { showLayerPanelState.value = v }
    lateinit var lockRevisionState: MutableIntState
    var lockRevision: Int
        get() = lockRevisionState.intValue
        set(v) { lockRevisionState.intValue = v }
    lateinit var lockPromptIdState: MutableState<String?>
    var lockPromptId: String?
        get() = lockPromptIdState.value
        set(v) { lockPromptIdState.value = v }
    lateinit var knownObjectIdsState: MutableState<Set<String>?>
    var knownObjectIds: Set<String>?
        get() = knownObjectIdsState.value
        set(v) { knownObjectIdsState.value = v }
    lateinit var micBlockedState: MutableState<Boolean>
    var micBlocked: Boolean
        get() = micBlockedState.value
        set(v) { micBlockedState.value = v }
    lateinit var penOnlyState: MutableState<Boolean>
    var penOnly: Boolean
        get() = penOnlyState.value
        set(v) { penOnlyState.value = v }
    lateinit var lowLatencyState: MutableState<Boolean>
    var lowLatency: Boolean
        get() = lowLatencyState.value
        set(v) { lowLatencyState.value = v }
    lateinit var showPalmThresholdsState: MutableState<Boolean>
    var showPalmThresholds: Boolean
        get() = showPalmThresholdsState.value
        set(v) { showPalmThresholdsState.value = v }
    lateinit var pendingExportState: MutableState<Pair<java.io.File, Exporter.Format>?>
    var pendingExport: Pair<java.io.File, Exporter.Format>?
        get() = pendingExportState.value
        set(v) { pendingExportState.value = v }
    lateinit var palmTunedState: MutableState<Boolean>
    var palmTuned: Boolean
        get() = palmTunedState.value
        set(v) { palmTunedState.value = v }
    lateinit var showPenSettingsState: MutableState<Boolean>
    var showPenSettings: Boolean
        get() = showPenSettingsState.value
        set(v) { showPenSettingsState.value = v }
    lateinit var penTunedState: MutableState<Boolean>
    var penTuned: Boolean
        get() = penTunedState.value
        set(v) { penTunedState.value = v }
    lateinit var lowLatencyUnavailableState: MutableState<Boolean>
    var lowLatencyUnavailable: Boolean
        get() = lowLatencyUnavailableState.value
        set(v) { lowLatencyUnavailableState.value = v }
    lateinit var revisionState: MutableIntState
    var revision: Int
        get() = revisionState.intValue
        set(v) { revisionState.intValue = v }
    lateinit var continuousContentRevisionState: MutableIntState
    var continuousContentRevision: Int
        get() = continuousContentRevisionState.intValue
        set(v) { continuousContentRevisionState.intValue = v }
    lateinit var clearTokenState: MutableIntState
    var clearToken: Int
        get() = clearTokenState.intValue
        set(v) { clearTokenState.intValue = v }
    lateinit var renamingCurrentState: MutableState<Boolean>
    var renamingCurrent: Boolean
        get() = renamingCurrentState.value
        set(v) { renamingCurrentState.value = v }
    lateinit var transferringPageState: MutableState<Pair<Int, Boolean>?>
    var transferringPage: Pair<Int, Boolean>?
        get() = transferringPageState.value
        set(v) { transferringPageState.value = v }
    lateinit var showSymbolPickerState: MutableState<Boolean>
    var showSymbolPicker: Boolean
        get() = showSymbolPickerState.value
        set(v) { showSymbolPickerState.value = v }
    lateinit var isRestoringHistoryState: MutableState<Boolean>
    var isRestoringHistory: Boolean
        get() = isRestoringHistoryState.value
        set(v) { isRestoringHistoryState.value = v }
    lateinit var inkToolState: MutableState<InkTool>
    var inkTool: InkTool
        get() = inkToolState.value
        set(v) { inkToolState.value = v }
    lateinit var lastBrushToolState: MutableState<InkTool>
    var lastBrushTool: InkTool
        get() = lastBrushToolState.value
        set(v) { lastBrushToolState.value = v }
    lateinit var penHeldToolState: MutableState<InkTool?>
    var penHeldTool: InkTool?
        get() = penHeldToolState.value
        set(v) { penHeldToolState.value = v }
    lateinit var isImageDropTargetedState: MutableState<Boolean>
    var isImageDropTargeted: Boolean
        get() = isImageDropTargetedState.value
        set(v) { isImageDropTargetedState.value = v }
    lateinit var isTabletopManualState: MutableState<Boolean>
    var isTabletopManual: Boolean
        get() = isTabletopManualState.value
        set(v) { isTabletopManualState.value = v }
    lateinit var isMagneticSnapActiveState: MutableState<Boolean>
    var isMagneticSnapActive: Boolean
        get() = isMagneticSnapActiveState.value
        set(v) { isMagneticSnapActiveState.value = v }
    lateinit var inkColorHexState: MutableState<String>
    var inkColorHex: String
        get() = inkColorHexState.value
        set(v) { inkColorHexState.value = v }
    lateinit var inkWidthState: MutableState<Float>
    var inkWidth: Float
        get() = inkWidthState.value
        set(v) { inkWidthState.value = v }
    lateinit var showSolidStudioState: MutableState<Boolean>
    var showSolidStudio: Boolean
        get() = showSolidStudioState.value
        set(v) { showSolidStudioState.value = v }
    lateinit var showDraftingToolboxState: MutableState<Boolean>
    var showDraftingToolbox: Boolean
        get() = showDraftingToolboxState.value
        set(v) { showDraftingToolboxState.value = v }
    lateinit var showStatusState: MutableState<Boolean>
    var showStatus: Boolean
        get() = showStatusState.value
        set(v) { showStatusState.value = v }
    lateinit var showInkDebugState: MutableState<Boolean>
    var showInkDebug: Boolean
        get() = showInkDebugState.value
        set(v) { showInkDebugState.value = v }
    lateinit var deletingPageState: MutableState<Boolean>
    var deletingPage: Boolean
        get() = deletingPageState.value
        set(v) { deletingPageState.value = v }
    lateinit var showRefineBarState: MutableState<Boolean>
    var showRefineBar: Boolean
        get() = showRefineBarState.value
        set(v) { showRefineBarState.value = v }
    lateinit var showThemeToolsState: MutableState<Boolean>
    var showThemeTools: Boolean
        get() = showThemeToolsState.value
        set(v) { showThemeToolsState.value = v }
    lateinit var showStickerLibraryState: MutableState<Boolean>
    var showStickerLibrary: Boolean
        get() = showStickerLibraryState.value
        set(v) { showStickerLibraryState.value = v }
    lateinit var showToolbarCustomizationState: MutableState<Boolean>
    var showToolbarCustomization: Boolean
        get() = showToolbarCustomizationState.value
        set(v) { showToolbarCustomizationState.value = v }
    lateinit var showAssetLibraryState: MutableState<Boolean>
    var showAssetLibrary: Boolean
        get() = showAssetLibraryState.value
        set(v) { showAssetLibraryState.value = v }
    lateinit var showCollaborationState: MutableState<Boolean>
    var showCollaboration: Boolean
        get() = showCollaborationState.value
        set(v) { showCollaborationState.value = v }
    lateinit var showSampleReadOnlyAlertState: MutableState<Boolean>
    var showSampleReadOnlyAlert: Boolean
        get() = showSampleReadOnlyAlertState.value
        set(v) { showSampleReadOnlyAlertState.value = v }
    lateinit var showLanguagePickerState: MutableState<Boolean>
    var showLanguagePicker: Boolean
        get() = showLanguagePickerState.value
        set(v) { showLanguagePickerState.value = v }
    lateinit var showNoteIntelligenceState: MutableState<Boolean>
    var showNoteIntelligence: Boolean
        get() = showNoteIntelligenceState.value
        set(v) { showNoteIntelligenceState.value = v }
    lateinit var collabBaseRoomState: MutableState<String?>
    var collabBaseRoom: String?
        get() = collabBaseRoomState.value
        set(v) { collabBaseRoomState.value = v }
    lateinit var collabLastStateRequestState: MutableState<Long>
    var collabLastStateRequest: Long
        get() = collabLastStateRequestState.value
        set(v) { collabLastStateRequestState.value = v }
    lateinit var collabTextRevisionState: MutableIntState
    var collabTextRevision: Int
        get() = collabTextRevisionState.intValue
        set(v) { collabTextRevisionState.intValue = v }
    lateinit var goldenSpiralState: MutableState<Boolean>
    var goldenSpiral: Boolean
        get() = goldenSpiralState.value
        set(v) { goldenSpiralState.value = v }
    lateinit var ruleOfThirdsState: MutableState<Boolean>
    var ruleOfThirds: Boolean
        get() = ruleOfThirdsState.value
        set(v) { ruleOfThirdsState.value = v }
    lateinit var refineRevisionState: MutableIntState
    var refineRevision: Int
        get() = refineRevisionState.intValue
        set(v) { refineRevisionState.intValue = v }
    lateinit var showMenuState: MutableState<Boolean>
    var showMenu: Boolean
        get() = showMenuState.value
        set(v) { showMenuState.value = v }
    lateinit var showPageSidebarState: MutableState<Boolean>
    var showPageSidebar: Boolean
        get() = showPageSidebarState.value
        set(v) { showPageSidebarState.value = v }
    lateinit var canvasScaleState: MutableFloatState
    var canvasScale: Float
        get() = canvasScaleState.floatValue
        set(v) { canvasScaleState.floatValue = v }
    lateinit var canvasOffsetState: MutableState<Offset>
    var canvasOffset: Offset
        get() = canvasOffsetState.value
        set(v) { canvasOffsetState.value = v }
    lateinit var canvasViewportState: MutableState<Size>
    var canvasViewport: Size
        get() = canvasViewportState.value
        set(v) { canvasViewportState.value = v }
    lateinit var didInitialFitState: MutableState<Boolean>
    var didInitialFit: Boolean
        get() = didInitialFitState.value
        set(v) { didInitialFitState.value = v }
    lateinit var activity: ComponentActivity
    lateinit var l10n: (String) -> String
    var notebook: Pair<PadnoteSession, String>? = null
    var pageId: String? = null
    lateinit var engine: InkEngine
    lateinit var lasso: LassoSelection
    lateinit var continuousLasso: LassoSelection
    lateinit var latency: InkLatencyMeter
    lateinit var audio: AudioCapture
    lateinit var scope: kotlinx.coroutines.CoroutineScope
    lateinit var textStore: TextBoxStore
    lateinit var chartStore: ChartStore
    lateinit var tableStore: TableStore
    lateinit var maskingTapes: androidx.compose.runtime.snapshots.SnapshotStateList<com.kairumo.padnote.canvas.NoteTape>
    var contextualState: com.kairumo.padnote.ui.ContextualPortalState? = null
    lateinit var effectiveToolbarMode: EditorMode
    lateinit var meta: NotebookMeta
    var audioDirectory: java.io.File? = null
    lateinit var insertAudioCard: (java.io.File) -> Unit
    lateinit var audioImportPicker: androidx.activity.result.ActivityResultLauncher<Array<String>>
    lateinit var imageStore: ImageStore
    lateinit var saveAsPicker: androidx.activity.result.ActivityResultLauncher<String>
    lateinit var imageMimeTypes: Array<String>
    lateinit var audioMimeTypes: Array<String>
    lateinit var photoPicker: androidx.activity.result.ActivityResultLauncher<androidx.activity.result.PickVisualMediaRequest>
    lateinit var imagePicker: androidx.activity.result.ActivityResultLauncher<Array<String>>
    lateinit var pasteClipboardImageOrScreenshot: () -> Unit
    lateinit var pdfMimeTypes: Array<String>
    lateinit var documentMimeTypes: Array<String>
    lateinit var documentPicker: androidx.activity.result.ActivityResultLauncher<Array<String>>
    lateinit var pdfPicker: androidx.activity.result.ActivityResultLauncher<Array<String>>
    lateinit var shapeStore: ShapeStore
    lateinit var stackItems: List<ObjectStacking.Item>
    lateinit var marqueeCandidates: List<com.kairumo.padnote.canvas.MarqueeHit>
    lateinit var marqueeCandidatesLatest: List<com.kairumo.padnote.canvas.MarqueeHit>
    lateinit var stackOrder: List<String>
    lateinit var stackOrderLatest: List<String>
    lateinit var underInkIds: Set<String>
    lateinit var kindOf: Map<String, ObjectStacking.Kind>
    lateinit var zIndexOf: (String) -> Float
    lateinit var lockedIds: Set<String>
    lateinit var lockedIdsLatest: Set<String>
    lateinit var objectLock: com.kairumo.padnote.canvas.ObjectLockActions
    lateinit var objectReorder: (String, ObjectStacking.Reorder) -> Unit
    lateinit var currentSelectedObjectIds: () -> Set<String>
    lateinit var applySinglePageClipboardSelection: (Set<String>) -> Unit
    lateinit var pasteSinglePageClipboard: (Offset?) -> Boolean
    lateinit var objectClipboardActions: com.kairumo.padnote.canvas.ObjectClipboardActions
    lateinit var backupPicker: androidx.activity.result.ActivityResultLauncher<Array<String>>
    lateinit var editorBackupCreatePicker: androidx.activity.result.ActivityResultLauncher<String>
    lateinit var folderPicker: androidx.activity.result.ActivityResultLauncher<android.net.Uri?>
    lateinit var micPermission: androidx.activity.result.ActivityResultLauncher<String>
    lateinit var exportNow: (Exporter.Format) -> Unit
    lateinit var printNow: (PadnoteSession) -> Unit
    lateinit var continuousUndo: ContinuousUndoController
    lateinit var noteTitle: String
    lateinit var collaboration: CollaborationManager
    lateinit var collab: AndroidCollabController
    lateinit var continuousCollab: ContinuousCollabBridge
    var collabActive: Boolean = false
    lateinit var layout: uniffi.padnote_core.FfiLayoutMetrics
    lateinit var posture: FoldPosture
    var isTabletopActive: Boolean = false
    lateinit var toolbarPlacement: uniffi.padnote_core.FfiPlacement
    lateinit var inkBarState: InkBarState
    var onOpenNotebook: ((String) -> Unit)? = null
    var notebookId: String? = null
    lateinit var globalUndo: () -> Unit
    lateinit var globalRedo: () -> Unit
    lateinit var fitCanvas: (String) -> Unit
    lateinit var applyInkTool: (InkTool) -> Unit
    lateinit var switchToPage: (Int) -> Unit
    lateinit var selectText: (String?) -> Unit
    lateinit var selectImage: (String?) -> Unit
    lateinit var clearSelection: () -> Unit
    lateinit var moveMarqueeSelection: (Float, Float) -> Unit
    lateinit var deleteMarqueeSelection: () -> Unit
    lateinit var duplicateMarqueeSelection: () -> Unit
    lateinit var movePage: (Int, Int) -> Unit
    lateinit var duplicatePage: (Int) -> Unit
    lateinit var insertPageAfter: (Int, String?) -> Unit
    lateinit var importPdfAsPages: suspend (java.io.File, (Int, Int) -> Unit) -> Pair<Int, Int>
    lateinit var deletePageAt: (Int) -> Unit
    lateinit var canvasSnapshot: () -> com.kairumo.padnote.canvas.CanvasSnapshot
    lateinit var applyCanvasSnapshot: (com.kairumo.padnote.canvas.CanvasSnapshot) -> Unit
    lateinit var collabCanvas: () -> AndroidCollabCanvas?
    lateinit var collabEngineFor: (String) -> InkEngine?
    lateinit var publishCollab: () -> Unit
    lateinit var releaseSelection: (String) -> Unit
    lateinit var applyCollabOp: (CollaborationManager.RemoteOplog) -> Unit
}

/**
 * 記住並建立 [EditorCanvasContext] 實例。
 */
@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
internal fun rememberEditorCanvasContext(
    activity: ComponentActivity,
    notebookId: String?,
    onBack: (() -> Unit)?,
    onOpenNotebook: ((String) -> Unit)?
): EditorCanvasContext {
    val l10n = { key: String -> uiString(key) }

    // **告訴自動同步「使用者正在看這一本」。**
    //
    // 自動同步靠它把這一本排到隊伍最前面 —— 在這之前只有編輯器裡的
    // 「立即同步」會傳，背景自動那條完全沒傳，於是最該即時的組合
    // （背景自動 + 正在編輯）反而排在隨意的順序裡。
    //
    // 離開編輯器要清掉，否則首頁也會一直讓那一本插隊。
    DisposableEffect(notebookId) {
        com.kairumo.padnote.sync.AutoSync.activeNotebookId = notebookId
        // 開著的這一本走焦點通道（秒同步）與區網直連。
        com.kairumo.padnote.sync.FocusSync.setFocus(notebookId)
        onDispose {
            com.kairumo.padnote.sync.AutoSync.activeNotebookId = null
            com.kairumo.padnote.sync.FocusSync.setFocus(null)
        }
    }

    // 真的開一本筆記本：沒有 session 的話，匯出與錄音都沒有東西可寫，
    // 這一頁就只是個畫圖玩具而不是筆記 App。
    // 同步把別台的 oplog 寫進套件之後，要重開 session 才看得到 ——
    // 檔案變了，記憶體裡那份還是同步前的。
    val sessionRevisionState = remember(notebookId) { mutableIntStateOf(0) }
    var sessionRevision by sessionRevisionState
    val notebook = remember(notebookId, sessionRevision) {
        if (notebookId != null && notebookId.equals(uniffi.padnote_core.recordingInboxNotebookId(), ignoreCase = true)) {
            null
        } else {
            openNotebook(activity, notebookId)
        }
    }
    LaunchedEffect(notebook) {
        if (notebook == null) {
            android.widget.Toast.makeText(
                activity,
                LocalizationStrings.localized("import_failed_read", deviceLanguageTag()),
                android.widget.Toast.LENGTH_SHORT
            ).show()
            onBack?.invoke()
        }
    }
    // 「一鍵恢復初始狀態」：開啟編輯器的這一刻在核心裡插一個標記（里程碑），還原就是還原到它。
    // 只在這次開啟的第一次建立（`remember(notebookId)`）；同步或還原之後重開 session 不會移動它，
    // 所以「初始」永遠是**打開這本筆記的那一刻**，與 Apple 一致。
    val openMarkIdState = remember(notebookId) { mutableStateOf<String?>(null) }
    var openMarkId by openMarkIdState
    val showRevertConfirmState = remember { mutableStateOf(false) }
    var showRevertConfirm by showRevertConfirmState
    LaunchedEffect(notebook?.second) {
        val session = notebook?.first ?: return@LaunchedEffect
        if (openMarkId == null) {
            // 用編輯器**自己的** session 寫：另開一個 session 寫同一個套件，
            // 編輯器之後的寫入不知道那一筆，會跟它搶同一個 oplog 的序號。
            openMarkId = runCatching {
                session.createMilestone(
                    NotebookLibrary.EDITOR_OPEN_MARK, "Kairumo", System.currentTimeMillis().toULong()
                ).id
            }.getOrNull()
        }
    }
    // 分頁狀態。
    //
    // 在此之前 Android **只認第一頁** —— `notebook.second` 是 firstPageId，
    // 而它從頭到尾沒有變過。一本 6 頁的筆記在 iPad 上翻得動，在 Android 上
    // 永遠停在第 1 頁，其餘 5 頁的內容看不到也刪不掉。
    //
    // 以**索引**為主而不是以 pageId 為主：新增與刪除之後 id 會變，索引不會，
    // 而使用者心裡想的是「第幾頁」。
    val pageCountState = remember(notebook) {
        mutableIntStateOf(
            runCatching { notebook?.first?.pageCount()?.toInt() ?: 1 }.getOrDefault(1)
        )
    }
    var pageCount by pageCountState
    val pageIndexState = remember(notebook) { mutableIntStateOf(0) }
    var pageIndex by pageIndexState

    /// 頁面顯示模式。記住使用者的選擇 —— 每次開筆記都退回整頁模式的話，
    /// 習慣連續捲動的人每次都要再按一次。與 Apple 端的 AppStorage 對應。
    // 側欄點了縮圖就遞增：連續模式據此再捲到目前頁（點的正好是目前頁時頁碼不變，只靠頁碼不會捲）。
    val continuousScrollRequestState = remember { mutableIntStateOf(0) }
    var continuousScrollRequest by continuousScrollRequestState
    val isTablet = remember(activity) {
        (activity.resources.configuration.screenLayout and android.content.res.Configuration.SCREENLAYOUT_SIZE_MASK) >= android.content.res.Configuration.SCREENLAYOUT_SIZE_LARGE
    }
    val pageDisplayModeState = remember {
        mutableStateOf(
            PageDisplayMode.fromWire(
                ProfileContext.prefs(activity, "kairumo_editor")
                    .getString("pageDisplayMode", null),
                isTablet = isTablet
            )
        )
    }
    var pageDisplayMode by pageDisplayModeState


    val pageId = remember(notebook, pageIndex, pageCount) {
        // 退回第一頁只在**本來就是第一頁**時才對。別頁查不到 id（頁數剛變、session 正在換）時
        // 退回第一頁的話，這一頁新增的物件與筆畫全寫進第 1 頁 —— 寧可這一瞬間寫不進去。
        runCatching { notebook?.first?.pageIdAt(pageIndex.toUInt()) }.getOrNull()
            ?: notebook?.second?.takeIf { pageIndex == 0 }
    }

    // 上一個引擎。別台同步進來要重開 session 時，新引擎先借它的筆畫當畫面（見 `seedDisplayFrom`），
    // 不然背景讀檔那段時間整頁是白的。只在同一頁才借 —— 換頁不能把上一頁的字帶過來。
    val previousEngine = remember(notebookId) { arrayOfNulls<InkEngine>(1) }
    val isSampleNotebook = remember(notebookId) {
        notebookId != null && com.kairumo.padnote.library.SampleFork.isSample(activity, notebookId, deviceId(activity))
    }
    var hasWarnedSampleReadOnly by remember(notebookId) { mutableStateOf(false) }
    val showSampleReadOnlyAlertState = remember { mutableStateOf(false) }
    val engine = remember(notebook, pageId) {
        InkEngine(session = notebook?.first, pageId = pageId).apply {
            previousEngine[0]?.takeIf { it.pageKey == (pageId ?: "") }?.let { seedDisplayFrom(it) }
            previousEngine[0] = this
            // 一筆畫完就通知同步。**會去抖動** —— 使用者還在寫字時
            // 每一筆都推只是浪費電，而且會拖慢正在編輯的這一本。
            onContentCommitted = {
                if (isSampleNotebook && !hasWarnedSampleReadOnly) {
                    hasWarnedSampleReadOnly = true
                    showSampleReadOnlyAlertState.value = true
                }
                com.kairumo.padnote.sync.AutoSync.noteLocalEdit(activity)
            }
            // 使用者調過的掌拒門檻要在**每次開新引擎時**套回去。
            // 只在設定當下套的話，換一頁就變回預設值，而使用者會以為
            // 設定沒有存到。
            setPalmThresholds(
                PalmThresholdStore.radius(activity),
                PalmThresholdStore.retractMs(activity)
            )
            setPressureCurve(
                PenSettingsStore.floor(activity) ?: 0.1f,
                PenSettingsStore.gamma(activity) ?: 1.0f
            )
        }
    }
    // 別台裝置（Drive 或區網）改了**正開著的這一本**：重開 session 才看得到。
    //
    // 在這之前編輯器完全不會反應 —— 下載的 oplog 檔已經寫進套件，但記憶體裡那份
    // 還是同步前的狀態，兩台同時開著同一本筆記時，另一台寫的東西要關掉重開才會出現。
    // 這正是「秒同步」在畫面上唯一看得見的一步。
    //
    // **等這一筆畫完再換。** 重開 session 會換掉引擎，落筆到一半換的話那一筆會消失。
    // 落筆完成的筆畫都已經寫進套件（每一筆畫完就是一個 oplog 檔），所以換 session
    // 不會丟掉任何已經畫完的東西。
    val remoteChange by com.kairumo.padnote.sync.FocusSync.remoteChange.collectAsState()
    LaunchedEffect(remoteChange.serial) {
        if (remoteChange.serial > 0L &&
            notebookId != null &&
            remoteChange.notebookId.equals(notebookId, ignoreCase = true)
        ) {
            while (engine.isDrawing || InkEngine.anyDrawing) kotlinx.coroutines.delay(50)
            sessionRevision++
        }
    }
    // 套索選取。換頁就換一個 —— 選取的是「這一頁的筆畫 id」，
    // 留著會指到另一頁不相干的東西。
    val lasso = remember(notebook, pageId) { LassoSelection() }
    // 連續頁面模式的套索另外一份：焦點頁一換 pageId 就變，跟著 pageId 重建的話
    // 捲一下選取與剪貼簿就不見了。選取屬於哪一頁由 ContinuousPagesView 記。
    val continuousLasso = remember(notebook) { LassoSelection() }
    val latency = remember { InkLatencyMeter() }
    val audio = remember { AudioCapture(activity) }
    val recordingState = remember { mutableStateOf(false) }
    var recording by recordingState
    val recordingPausedState = remember { mutableStateOf(false) }
    var recordingPaused by recordingPausedState
    val recordSecondsState = remember { mutableIntStateOf(0) }
    var recordSeconds by recordSecondsState
    val backlogUsState = remember { mutableLongStateOf(0L) }
    var backlogUs by backlogUsState
    val messageState = remember { mutableStateOf<String?>(null) }
    var message by messageState
    val docsAssetState = remember { mutableStateOf<String?>(null) }
    var docsAsset by docsAssetState
    val scope = rememberCoroutineScope()

    LaunchedEffect(recording, recordingPaused) {
        if (recording && !recordingPaused) {
            while (true) {
                kotlinx.coroutines.delay(1000L)
                recordSeconds++
                backlogUs = runCatching { notebook?.first?.transcriptionBacklogUs()?.toLong() ?: 0L }.getOrDefault(0L)
            }
        }
    }

    // 畫布文字方塊。與 Apple 端同一組資料模型與外觀規則（format-spec §6.2）。
    val textStore = remember(notebook, pageId) { TextBoxStore(notebook?.first, pageId) }
    val textRevisionState = remember { mutableIntStateOf(0) }
    var textRevision by textRevisionState
    val selectedTextIdState = remember { mutableStateOf<String?>(null) }
    var selectedTextId by selectedTextIdState
    val editingTextState = remember { mutableStateOf<TextBox?>(null) }
    var editingText by editingTextState
    LaunchedEffect(notebook, pageId, pageDisplayMode) {
        if (pageDisplayMode != PageDisplayMode.CONTINUOUS) {
            textStore.load(); textRevision++
        }
    }

    // 數字製圖。設定存進區塊外觀，所以插進去之後還改得動 ——
    // 與 Apple 端同一份 ChartSpec 與同一個核心版面引擎。
    val chartStore = remember(notebook, pageId) { ChartStore(notebook?.first, pageId) }
    val chartRevisionState = remember { mutableIntStateOf(0) }
    var chartRevision by chartRevisionState
    val selectedChartIdState = remember { mutableStateOf<String?>(null) }
    var selectedChartId by selectedChartIdState
    val editingChartState = remember { mutableStateOf<ChartObject?>(null) }
    var editingChart by editingChartState
    val insertingChartState = remember { mutableStateOf(false) }
    var insertingChart by insertingChartState
    LaunchedEffect(notebook, pageId, pageDisplayMode) {
        if (pageDisplayMode != PageDisplayMode.CONTINUOUS) {
            chartStore.load(); chartRevision++
        }
    }

    // 表格。內容走核心原生的表格區塊，樣式走區塊外觀 ——
    // 與 Apple 端同一組操作，所以表格互相打得開。
    val tableStore = remember(notebook, pageId) { TableStore(notebook?.first, pageId) }
    val tableRevisionState = remember { mutableIntStateOf(0) }
    var tableRevision by tableRevisionState
    val selectedTableIdState = remember { mutableStateOf<String?>(null) }
    var selectedTableId by selectedTableIdState
    val editingTableState = remember { mutableStateOf<NoteTable?>(null) }
    var editingTable by editingTableState
    /// 形狀的樣式編修對話框。strokeColorHex / fillColorHex / lineWidth 這三個
    /// 欄位一直都在、也一直跟著同步走，但過去沒有任何介面碰得到它們。
    val editingShapeState = remember { mutableStateOf<NoteShape?>(null) }
    var editingShape by editingShapeState
    /** 被選取的連接線。連接線不在 `selectedShapeIds` 裡 —— 它不是形狀，沒有群組與對齊。 */
    val selectedConnectionIdState = remember { mutableStateOf<String?>(null) }
    var selectedConnectionId by selectedConnectionIdState
    val editingConnectionState = remember { mutableStateOf<NoteConnection?>(null) }
    var editingConnection by editingConnectionState
    /** 拖曳連接點拉線時的預覽。 */
    val connectionDraftState = remember { mutableStateOf<ConnectionDraft?>(null) }
    var connectionDraft by connectionDraftState
    val insertingTableState = remember { mutableStateOf(false) }
    var insertingTable by insertingTableState
    val maskingTapes = remember { mutableStateListOf<com.kairumo.padnote.canvas.NoteTape>() }
    LaunchedEffect(notebook, pageId, pageDisplayMode) {
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) return@LaunchedEffect
        tableStore.load(); tableRevision++
        val session = notebook?.first
        if (session != null) {
            val meta = com.kairumo.padnote.library.NotebookMeta.load(session)
            val legacyTapes = meta.tapes().filter { it.pageIndex == pageIndex }
            val envelopeTapes = mutableListOf<com.kairumo.padnote.canvas.NoteTape>()
            if (pageId != null) {
                val blockIds = runCatching { session.imageBlockIds(pageId) }.getOrDefault(emptyList())
                for (bId in blockIds) {
                    val json = runCatching { session.blockAppearance(bId) }.getOrNull() ?: continue
                    com.kairumo.padnote.canvas.NoteTapeCodec.parseEnvelope(json, pageIndex)?.let {
                        envelopeTapes.add(it)
                    }
                }
            }
            val knownEnvelopeIds = envelopeTapes.map { it.id.lowercase() }.toSet()
            val combined = envelopeTapes + legacyTapes.filter { it.id.lowercase() !in knownEnvelopeIds }
            maskingTapes.clear()
            maskingTapes.addAll(combined)
        }
    }

    // 形狀與流程圖。幾何全部來自核心，與 Apple 端是同一組頂點；
    // 形狀本身也是核心的原生物件，所以關掉 App 再打開它們還在。
    /**
     * 手寫／打字模式。**與 Apple 端的 EditorMode 同一組語意。**
     *
     * 在此之前 Android 沒有這個概念：物件層永遠吃觸控，於是拿筆想在一張圖
     * 上圈重點，筆畫根本到不了畫布 —— 而那在一個手寫筆記 App 裡是最該能做
     * 的事之一。iPad 上圈得到、Android 上圈不到，同一個人換裝置就會發現。
     */
    val editorModeState = remember { mutableStateOf(EditorMode.DRAW) }
    var editorMode by editorModeState
    val snapToGridState = remember { mutableStateOf(true) }
    var snapToGrid by snapToGridState

    val showProColorWheelState = remember { mutableStateOf(false) }
    var showProColorWheel by showProColorWheelState
    val minimalistCanvasModeState = remember { mutableStateOf(false) }
    var minimalistCanvasMode by minimalistCanvasModeState
    val floatingPillExpandedState = remember { mutableStateOf(false) }
    var floatingPillExpanded by floatingPillExpandedState
    val strokeStabilizerState = remember { mutableFloatStateOf(35f) }
    var strokeStabilizer by strokeStabilizerState
    val showSymmetryGuideState = remember { mutableStateOf(false) }
    var showSymmetryGuide by showSymmetryGuideState
    val showRadialMenuState = remember { mutableStateOf(false) }
    var showRadialMenu by showRadialMenuState
    val radialMenuCenterState = remember { mutableStateOf(Offset(300f, 300f)) }
    var radialMenuCenter by radialMenuCenterState
    val magneticGuideActiveState = remember { mutableStateOf(false) }
    var magneticGuideActive by magneticGuideActiveState
    val magneticGuideStartState = remember { mutableStateOf(Offset.Zero) }
    var magneticGuideStart by magneticGuideStartState
    val magneticGuideEndState = remember { mutableStateOf(Offset.Zero) }
    var magneticGuideEnd by magneticGuideEndState

    val contextualState = remember(editorMode, editingText, selectedTextId) {
        if (editorMode == EditorMode.DRAW && (editingText != null || selectedTextId != null)) {
            ContextualPortalState.EditingTextInDrawMode(
                "${l10n("tool_text")} • ${l10n("edit")}"
            )
        } else {
            null
        }
    }

    val effectiveToolbarMode = remember(editorMode, editingText, selectedTextId) {
        if (editorMode == EditorMode.DRAW && (editingText != null || selectedTextId != null)) {
            EditorMode.TYPE
        } else {
            editorMode
        }
    }

    // 筆記本中繼資料。Android 在此之前**完全沒有讀過它** —— Apple 放在這裡的
    // 樣板、資料夾、圖釘、連結卡片、3D 與物件堆疊順序，同步過來就像不存在。
    val meta = remember(notebook) { NotebookMeta.load(notebook?.first) }
    val stackRevisionState = remember { mutableIntStateOf(0) }
    var stackRevision by stackRevisionState
    val showStackPanelState = remember { mutableStateOf(false) }
    var showStackPanel by showStackPanelState
    val showCalculatorState = remember { mutableStateOf(false) }
    var showCalculator by showCalculatorState
    val showProColorsState = remember { mutableStateOf(false) }
    var showProColors by showProColorsState
    // 討論圖釘。存在筆記本中繼資料裡，Android 在此之前讀不到 ——
    // iPad 上標的討論同步過來就像不存在。
    val pinsState = remember(notebook) { mutableStateOf(meta.commentPins()) }
    var pins by pinsState
    /// 正在放置討論圖釘 —— 點畫布就會放下一個。與 Apple 端同一個模式。
    val isPlacingCommentPinState = remember { mutableStateOf(false) }
    var isPlacingCommentPin by isPlacingCommentPinState
    /// 辨識手寫剛被按下 —— 只給操作提示用。
    ///
    /// 其他三個功能本身就是布林模式，辨識手寫不是（它跑完就結束），
    /// 所以要一個獨立的旗標才跳得出提示。
    val isRecognisingHandwritingState = remember { mutableStateOf(false) }
    var isRecognisingHandwriting by isRecognisingHandwritingState
    val pinRevisionState = remember { mutableIntStateOf(0) }
    var pinRevision by pinRevisionState
    val openPinState = remember { mutableStateOf<CommentPin?>(null) }
    var openPin by openPinState

    // 3D 模型。與圖釘一樣存在筆記本中繼資料（`model3DAttachments`），
    // 讀的是 Apple 端寫進去的同一個鍵。
    val models3DState = remember(notebook) { mutableStateOf(meta.models3D()) }
    var models3D by models3DState
    val model3DRevisionState = remember { mutableIntStateOf(0) }
    var model3DRevision by model3DRevisionState
    // 連結卡片。真身在中繼資料（`linkAttachments`），與 Apple 同一個鍵 ——
    // 少了這一份，Apple 上建的卡片在 Android 上會整個看不見：資料同步過來了，
    // 畫面上什麼都沒有（`ImageStore` 會跳過那張後備 PNG）。
    val linksState = remember(notebook) { mutableStateOf(meta.links()) }
    var links by linksState
    val linkRevisionState = remember { mutableIntStateOf(0) }
    var linkRevision by linkRevisionState
    val selectedLinkIdState = remember { mutableStateOf<String?>(null) }
    var selectedLinkId by selectedLinkIdState
    val insertingLinkState = remember { mutableStateOf(false) }
    var insertingLink by insertingLinkState
    val editingLinkState = remember { mutableStateOf<LinkObject?>(null) }
    var editingLink by editingLinkState

    // 頁面上的錄音卡片。與連結卡片一樣住在中繼資料（`audioAttachments`），
    // 與 Apple 端同一個鍵 —— 在此之前 Android 讀不到，iPad 上貼在某一頁的
    // 錄音同步過來就像不存在。
    val audioCardsState = remember(notebook) { mutableStateOf(meta.audioCards()) }
    var audioCards by audioCardsState
    val audioRevisionState = remember { mutableIntStateOf(0) }
    var audioRevision by audioRevisionState
    val selectedAudioIdState = remember { mutableStateOf<String?>(null) }
    var selectedAudioId by selectedAudioIdState
    val playingAudioIdState = remember { mutableStateOf<String?>(null) }
    var playingAudioId by playingAudioIdState
    val insertingAudioState = remember { mutableStateOf(false) }
    var insertingAudio by insertingAudioState

    // 框選。與 Apple 同一套規則 —— 見 canvas/ObjectMarquee.kt 的說明。
    val marqueeActiveState = remember { mutableStateOf(false) }
    var marqueeActive by marqueeActiveState
    val marqueeSelectionState = remember { mutableStateOf(setOf<String>()) }
    var marqueeSelection by marqueeSelectionState
    /** 連續框選（見 ObjectMarquee.combined）。 */
    val marqueeAdditiveState = remember { mutableStateOf(false) }
    var marqueeAdditive by marqueeAdditiveState
    /** 跨頁物件剪貼簿（支援單頁與連續模式在任一模式下剪下、複製、點選任意位置貼上）。 */
    val objectClipboardState = remember(notebook) {
        mutableStateOf<List<com.kairumo.padnote.canvas.ClipboardObject>>(emptyList())
    }
    var objectClipboard by objectClipboardState
    val isPlacingPasteObjectState = remember(notebook) { mutableStateOf(false) }
    var isPlacingPasteObject by isPlacingPasteObjectState
    val renamingAudioState = remember { mutableStateOf<AudioObject?>(null) }
    var renamingAudio by renamingAudioState
    // 套件裡的錄音目錄。錄音檔就住在這裡（format-spec §5），
    // 播放與「插入錄音」的清單都看它。
    val audioDirectory = remember(notebook, notebookId) {
        val id = notebookId ?: return@remember null
        java.io.File(
            java.io.File(NotebookLibrary.directory(activity), "$id.${NotebookLibrary.EXTENSION}"),
            "media/audio"
        )
    }
    // 插一張錄音卡片。挑既有錄音與匯入外部音訊走的是**同一條路** ——
    // 兩邊各寫一份的話，漏掉的那一項（寫回 meta、切模式）會變成
    // 「插進去了但畫面上沒反應」。
    val insertAudioCard: (java.io.File) -> Unit = { file ->
                    // 位置逐張往右下錯開。全部疊在同一點的話，插第二張時
                    // 使用者會以為沒插進去。
                    val existing = audioCards.count { it.pageIndex == pageIndex }
                    val offset = (existing % 6) * 18f
                    val card = AudioObject(
                        id = java.util.UUID.randomUUID().toString(),
                        pageIndex = pageIndex,
                        recordingId = file.nameWithoutExtension,
                        fileName = file.name,
                        title = file.nameWithoutExtension,
                        // 長度走核心算（S-42）。各平台問各自的系統 API 的話，
                        // 同一段錄音在兩台裝置上會顯示不同的秒數。
                        durationSeconds = runCatching {
                            uniffi.padnote_core.audioDurationSeconds(file.readBytes()).toInt()
                        }.getOrDefault(0),
                        x = 80f + offset, y = 120f + offset,
                        width = 260f, height = 76f
                    )
                    audioCards = (audioCards + card).toMutableList()
                    meta.setAudioCards(notebook?.first, audioCards)
                    insertingAudio = false
                    selectedAudioId = card.id
                    // 插入後切到打字模式 —— 手寫模式下物件不吃觸控，
                    // 剛插進來的卡片會拖不動，看起來像插壞了。
                    editorMode = EditorMode.TYPE
                    audioRevision++
    }

    // 匯入本機音訊檔。**收進套件的 media/audio**，不是附件目錄 ——
    // 播放與同步兩條路都是照「錄音就在那裡」在解析的，放錯地方的症狀
    // 是「按了播放沒有反應」，而且沒有任何錯誤訊息。
    val audioImportPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            val dir = audioDirectory
            if (dir == null) {
                message = l10n("import_failed_read")
            } else {
                val outcome = FileImport.take(activity, uri, FfiImportSlot.AUDIO, dir)
                if (outcome.errorKey.isNotEmpty()) {
                    message = l10n(outcome.errorKey)
                } else {
                    insertAudioCard(java.io.File(dir, outcome.storedName))
                }
            }
        }
    }

    // 離開編輯畫面要放掉播放器 —— 不放的話聲音會在使用者回到首頁之後
    // 繼續播下去，而且畫面上沒有任何東西能停它。
    androidx.compose.runtime.DisposableEffect(notebook) {
        onDispose { AudioPlayback.stop() }
    }
    val selectedModel3DIdState = remember { mutableStateOf<String?>(null) }
    var selectedModel3DId by selectedModel3DIdState
    val editingModel3DState = remember { mutableStateOf<Model3DObject?>(null) }
    var editingModel3D by editingModel3DState
    val insertingModel3DState = remember { mutableStateOf(false) }
    var insertingModel3D by insertingModel3DState






    val imageStore = remember(notebook, pageId) { ImageStore(notebook?.first, pageId) }
    val imageRevisionState = remember { mutableIntStateOf(0) }
    var imageRevision by imageRevisionState
    val selectedImageIdState = remember { mutableStateOf<String?>(null) }
    var selectedImageId by selectedImageIdState
    val editingImageState = remember { mutableStateOf<NoteImage?>(null) }
    var editingImage by editingImageState
    LaunchedEffect(notebook, pageId, pageDisplayMode) {
        if (pageDisplayMode != PageDisplayMode.CONTINUOUS) {
            imageStore.load(); imageRevision++
        }
    }

    fun switchToPage(target: Int) {
        val bounded = target.coerceIn(0, maxOf(0, pageCount - 1))
        if (pageIndex == bounded) {
            continuousScrollRequest++
            return
        }
        pageIndex = bounded // state-entry: 頁面切換的唯一正門
        continuousScrollRequest++
    }

    fun selectText(id: String?) {
        selectedTextId = id // state-entry: 選取文字的唯一正門
        if (id != null) {
            selectedImageId = null // state-entry: 選取互斥清空
        }
    }

    fun selectImage(id: String?) {
        selectedImageId = id // state-entry: 選取圖片的唯一正門
        if (id != null) {
            selectedTextId = null // state-entry: 選取互斥清空
        }
    }

    // 把打包好的筆記存到**使用者自己選的位置**（SAF）。
    //
    // App 的資料在私有目錄裡，使用者碰不到 —— 分享可以把檔案送去別的 App，
    // 但那不是「存到我選的資料夾」。Apple 端因為同一件事被 Mac App Store
    // 退件（審查指南 2.4.5(i)），而這個缺口兩邊都有。
    val pendingSaveBytesState = remember { mutableStateOf<ByteArray?>(null) }
    var pendingSaveBytes by pendingSaveBytesState
    val saveAsPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri ->
        val bytes = pendingSaveBytes
        pendingSaveBytes = null
        if (uri != null && bytes != null) {
            message = runCatching {
                activity.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                l10n("export_done")
            }.getOrElse { l10n("import_failed_read") }
        }
    }

    // 挑選器的過濾條件來自核心，算一次就好 —— 每次開選單都重算的話，
    // 那是一趟不必要的 FFI 往返。
    val imageMimeTypes = remember { FileImport.mimeTypes(FfiImportSlot.IMAGE) }
    val audioMimeTypes = remember { FileImport.mimeTypes(FfiImportSlot.AUDIO) }

    // 本機選圖。用 OpenDocument 而不是舊的 GET_CONTENT：前者拿得到持久權限，
    // 而且在 Android 13+ 不需要任何儲存權限。
    // 相簿與檔案兩個入口共用這一段。各寫一份的話，漏掉的那一項
    // （切模式、錯誤訊息）會變成「從相簿插得進去、從檔案插進去沒反應」。
    val onImagePicked: (android.net.Uri) -> Unit = { uri ->
        // **先問大小再讀。** 原本是直接 `readBytes()`，在一張 60 MB
        // 的掃描上那一下配置就可能被系統殺掉 —— 而那看起來像 App
        // 當掉，不像「檔案太大」。判斷走核心（`importCheck`），
        // 與 Apple 端同一套規則、同一套錯誤訊息。
        val outcome = FileImport.take(activity, uri, FfiImportSlot.IMAGE)
        if (outcome.errorKey.isNotEmpty()) {
            message = l10n(outcome.errorKey)
        } else {
            val bytes = runCatching {
                FileImport.fileFor(activity, outcome.storedName).readBytes()
            }.getOrNull()
            if (bytes != null) {
                val inserted = imageStore.insert(bytes, outcome.displayName)
                imageRevision++
                selectImage(inserted?.id)
                // 插入後自動切到打字模式 —— 手寫模式下物件不吃觸控，
                // 使用者剛插進來的圖會拖不動，看起來像插壞了。
                if (inserted != null) editorMode = EditorMode.TYPE
                else message = l10n("err_image_read_failed")
            } else {
                message = l10n("import_failed_read")
            }
        }
    }

    // 相簿選圖。與「從檔案選擇」是**不同的入口**：系統相簿挑選器看得到
    // 的只有相簿裡的東西，使用者從電腦拷進「下載」的那張圖它一張都看不到
    // —— 反過來也一樣。Apple 端同樣是兩個入口。
    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri -> if (uri != null) onImagePicked(uri) }

    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri -> if (uri != null) onImagePicked(uri) }

    val pasteClipboardImageOrScreenshot: () -> Unit = {
        val clipboard = activity.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
        val clip = clipboard?.primaryClip
        var pasted = false
        if (clip != null && clip.itemCount > 0) {
            val item = clip.getItemAt(0)
            val uri = item.uri
            if (uri != null) {
                val mime = activity.contentResolver.getType(uri)
                if (mime?.startsWith("image/") == true || uri.toString().contains("image")) {
                    onImagePicked(uri)
                    pasted = true
                }
            }
        }
        if (!pasted) {
            message = l10n("clipboard_no_image")
        }
    }

    // 插入 PDF 頁面。收進來的那份 PDF 與挑到第幾頁 —— 兩個一起才有意義，
    // 所以放在同一個狀態裡。
    val pdfToInsertState = remember { mutableStateOf<java.io.File?>(null) }
    var pdfToInsert by pdfToInsertState
    val pdfMimeTypes = remember { FileImport.mimeTypes(FfiImportSlot.PDF) }
    val documentMimeTypes = remember { FileImport.mimeTypes(FfiImportSlot.DOCUMENT) }
    // 解析好、等著排進筆記的文件。排版要用到 `insertPageAfter`（定義在更後面），
    // 所以挑選器只負責解析，實際放進筆記由後面的 LaunchedEffect 做。
    val importedDocumentState = remember { mutableStateOf<DocumentImport.Parsed?>(null) }
    var importedDocument by importedDocumentState
    val documentPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            val outcome = FileImport.take(activity, uri, FfiImportSlot.DOCUMENT)
            if (outcome.errorKey.isNotEmpty()) {
                message = l10n(outcome.errorKey)
            } else {
                val f = FileImport.fileFor(activity, outcome.storedName)
                // 副檔名要從**存下來的檔名**取 —— `displayName` 已經去掉副檔名了，
                // 拿它判斷的話永遠是空字串。
                val ext = outcome.storedName.substringAfterLast('.', "").lowercase()
                if (ext == "pptx") {
                    message = l10n("import_unsupported_type")
                } else {
                    try {
                        // profile-scope: device 匯入文件的暫存
                        importedDocument = DocumentImport.parse(activity.cacheDir, f, outcome.displayName)
                    } catch (_: DocumentImport.EmptyDocumentException) {
                        message = l10n("import_empty_file")
                    } catch (_: Exception) {
                        message = l10n("import_failed_read")
                    }
                }
            }
        }
    }

    val pdfPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            val outcome = FileImport.take(activity, uri, FfiImportSlot.PDF)
            if (outcome.errorKey.isNotEmpty()) {
                message = l10n(outcome.errorKey)
            } else {
                pdfToInsert = FileImport.fileFor(activity, outcome.storedName)
            }
        }
    }

    val shapeStore = remember(notebook, pageId) { ShapeStore(notebook?.first, pageId) }
    val shapeRevisionState = remember { mutableIntStateOf(0) }
    var shapeRevision by shapeRevisionState
    val selectedShapeIdsState = remember { mutableStateOf(setOf<String>()) }
    var selectedShapeIds by selectedShapeIdsState
    val insertingShapeState = remember { mutableStateOf(false) }
    var insertingShape by insertingShapeState
    val showLayerPanelState = remember { mutableStateOf(false) }
    var showLayerPanel by showLayerPanelState

    fun clearSelection() {
        selectedTextId = null // state-entry: 清空選取的唯一正門
        selectedImageId = null // state-entry: 清空選取的唯一正門
        selectedChartId = null
        selectedTableId = null
        selectedLinkId = null
        selectedAudioId = null
        selectedModel3DId = null
        selectedShapeIds = emptySet()
        selectedConnectionId = null
        marqueeSelection = emptySet()
    }
    // 切回手寫模式時一律收掉物件選取（與 Apple `transitionToMode`、連續頁面模式同一組規則）。
    //
    // 模式有三十幾個地方會改（工具列、觸控筆落下、Ctrl+E、飛梭工具盤、插入物件…），以前靠每個
    // 呼叫端自己記得清 —— 只有工具列那一條有清，其他路切回手寫，畫面上就留著一組在手寫模式下
    // 拖不動的把手。改成看著模式本身：不管從哪條路切的，結果都一樣。
    LaunchedEffect(editorMode) {
        if (editorMode == EditorMode.DRAW) {
            clearSelection()
        }
    }
    LaunchedEffect(notebook, pageId, pageDisplayMode) {
        if (pageDisplayMode != PageDisplayMode.CONTINUOUS) {
            shapeStore.load(); shapeRevision++
        }
    }
    LaunchedEffect(notebook, pageId) {
        clearSelection()
        editingText = null
        editingImage = null
        editingShape = null; selectedConnectionId = null
        editingTable = null
        editingChart = null
        editingLink = null
    }

    // 這一頁所有可堆疊的物件，跨五種型別收成同一份清單。
    // 名字取得出來就用內容，取不出來就用型別名 —— 面板上一整排「未命名」
    // 的話，使用者分不出哪一列是哪一個。
    val stackItems = remember(
        textRevision, shapeRevision, tableRevision, chartRevision, imageRevision,
        model3DRevision, linkRevision, pageId
    ) {
        buildList {
            imageStore.all.forEach {
                add(ObjectStacking.Item(it.id, ObjectStacking.Kind.IMAGE, l10n("layer_kind_image")))
            }
            shapeStore.all.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.SHAPE,
                    it.label.ifBlank { l10n("layer_kind_shape") }))
            }
            tableStore.all.forEach {
                add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TABLE, l10n("layer_kind_table")))
            }
            chartStore.all.forEach {
                add(ObjectStacking.Item(it.id, ObjectStacking.Kind.CHART, l10n("chart_studio")))
            }
            models3D.filter { it.pageIndex == pageIndex }.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.MODEL3D,
                    it.title.ifBlank { l10n("model3d_title") }))
            }
            links.filter { it.pageIndex == pageIndex }.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.IMAGE,
                    it.title.ifBlank { l10n("insert_link") }))
            }
            textStore.all.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.TEXT,
                    it.text.trim().take(24).ifBlank { l10n("layer_kind_text") }))
            }
        }
    }

    // 框選要用的「每個物件在哪、多大」。與 stackItems 走同一批來源，
    // 但這裡要的是幾何不是名字。
    val marqueeCandidates = remember(
        textRevision, shapeRevision, tableRevision, chartRevision, imageRevision,
        model3DRevision, linkRevision, audioRevision, pageId
    ) {
        buildList {
            imageStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            shapeStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            tableStore.all.forEach {
                // 表格的高度由核心的版面決定，模型上沒有可信的 height。
                val layout = it.layout()
                add(MarqueeHit(it.id, it.x, it.y, it.width, layout.height.toFloat()))
            }
            chartStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            textStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            links.filter { it.pageIndex == pageIndex }.forEach {
                add(MarqueeHit(it.id, it.x, it.y, it.width, it.height))
            }
            models3D.filter { it.pageIndex == pageIndex }.forEach {
                add(MarqueeHit(it.id, it.x, it.y, it.width, it.height))
            }
            audioCards.filter { it.pageIndex == pageIndex }.forEach {
                add(MarqueeHit(it.id, it.x, it.y, it.width, it.height))
            }
        }
    }

    /** 把選取的物件整組位移。每一種型別各自寫回自己的 store。 */
    fun moveMarqueeSelection(dx: Float, dy: Float) {
        if (marqueeSelection.isEmpty() || (dx == 0f && dy == 0f)) return
        imageStore.all.filter { it.id in marqueeSelection }.forEach {
            it.x += dx; it.y += dy; imageStore.persist(it)
        }
        shapeStore.all.filter { it.id in marqueeSelection }.forEach {
            shapeStore.persist(it.copyShape().apply { x = it.x + dx; y = it.y + dy })
        }
        tableStore.all.filter { it.id in marqueeSelection }.forEach {
            tableStore.persist(it.copyTable().apply { x = it.x + dx; y = it.y + dy })
        }
        chartStore.all.filter { it.id in marqueeSelection }.forEach {
            chartStore.persist(it.copy(x = it.x + dx, y = it.y + dy))
        }
        textStore.all.filter { it.id in marqueeSelection }.forEach {
            it.x += dx; it.y += dy; textStore.persist(it)
        }
        var linksChanged = false
        links = links.map {
            if (it.id in marqueeSelection) {
                linksChanged = true
                it.copy(x = it.x + dx, y = it.y + dy)
            } else it
        }.toMutableList()
        if (linksChanged) meta.setLinks(notebook?.first, links)

        var modelsChanged = false
        models3D = models3D.map {
            if (it.id in marqueeSelection) {
                modelsChanged = true
                it.copy(x = it.x + dx, y = it.y + dy)
            } else it
        }.toMutableList()
        if (modelsChanged) meta.setModels3D(notebook?.first, models3D)

        var audioChanged = false
        audioCards = audioCards.map {
            if (it.id in marqueeSelection) {
                audioChanged = true
                it.copy(x = it.x + dx, y = it.y + dy)
            } else it
        }.toMutableList()
        if (audioChanged) meta.setAudioCards(notebook?.first, audioCards)

        imageRevision++; shapeRevision++; tableRevision++; chartRevision++
        textRevision++; linkRevision++; model3DRevision++; audioRevision++
    }

    /** 刪掉選取的物件。形狀連同它的連接線一起刪 —— 只刪形狀的話，
     *  線會留在畫布上，兩端各指著一個不存在的東西。 */
    fun deleteMarqueeSelection() {
        if (marqueeSelection.isEmpty()) return
        imageStore.all.filter { it.id in marqueeSelection }.forEach { imageStore.remove(it) }
        shapeStore.all.filter { it.id in marqueeSelection }.forEach { shapeStore.remove(it) }
        tableStore.all.filter { it.id in marqueeSelection }.forEach { tableStore.remove(it) }
        chartStore.all.filter { it.id in marqueeSelection }.forEach { chartStore.remove(it) }
        textStore.all.filter { it.id in marqueeSelection }.forEach { textStore.remove(it) }
        links = links.filter { it.id !in marqueeSelection }.toMutableList()
        meta.setLinks(notebook?.first, links)
        models3D = models3D.filter { it.id !in marqueeSelection }.toMutableList()
        meta.setModels3D(notebook?.first, models3D)
        audioCards = audioCards.filter { it.id !in marqueeSelection }.toMutableList()
        meta.setAudioCards(notebook?.first, audioCards)
        marqueeSelection = emptySet()
        imageRevision++; shapeRevision++; tableRevision++; chartRevision++
        textRevision++; linkRevision++; model3DRevision++; audioRevision++
    }

    /** 建立副本。位移一段距離，貼在原位的話使用者會以為沒成功。 */
    fun duplicateMarqueeSelection() {
        if (marqueeSelection.isEmpty()) return
        val d = ObjectMarquee.PASTE_OFFSET
        val created = mutableSetOf<String>()
        shapeStore.all.filter { it.id in marqueeSelection }.forEach {
            created += shapeStore.create(it.copyShape().apply { x = it.x + d; y = it.y + d }).id
        }
        tableStore.all.filter { it.id in marqueeSelection }.forEach {
            created += tableStore.create(it.copyTable().apply { x = it.x + d; y = it.y + d }).id
        }
        chartStore.all.filter { it.id in marqueeSelection }.forEach {
            created += chartStore.create(it.spec, it.x + d, it.y + d).id
        }
        textStore.all.filter { it.id in marqueeSelection }.forEach { source ->
            val box = textStore.create(source.x + d, source.y + d)
            box.text = source.text
            box.width = source.width
            box.height = source.height
            box.fontSize = source.fontSize
            box.bold = source.bold
            box.italic = source.italic
            box.textColorHex = source.textColorHex
            box.backgroundColorHex = source.backgroundColorHex
            box.hasBorder = source.hasBorder
            textStore.persist(box)
            created += box.id
        }
        // 連結、3D 與錄音卡片住在中繼資料裡，直接複製一份帶新 id。
        val newLinks = links.filter { it.id in marqueeSelection }.map {
            it.copy(id = java.util.UUID.randomUUID().toString(), x = it.x + d, y = it.y + d)
        }
        if (newLinks.isNotEmpty()) {
            links = (links + newLinks).toMutableList()
            meta.setLinks(notebook?.first, links)
            created += newLinks.map { it.id }
        }
        val newAudio = audioCards.filter { it.id in marqueeSelection }.map {
            it.copy(id = java.util.UUID.randomUUID().toString(), x = it.x + d, y = it.y + d)
        }
        if (newAudio.isNotEmpty()) {
            audioCards = (audioCards + newAudio).toMutableList()
            meta.setAudioCards(notebook?.first, audioCards)
            created += newAudio.map { it.id }
        }
        marqueeSelection = created
        imageRevision++; shapeRevision++; tableRevision++; chartRevision++
        textRevision++; linkRevision++; model3DRevision++; audioRevision++
    }

    val stackOrder = remember(stackItems, stackRevision) {
        ObjectStacking.normalized(stackItems, meta.objectOrder(pageIndex))
    }
    // 錄音卡片不在圖層面板裡，但一樣要照核心的圖層規則決定在筆跡哪一側。
    val kindOf = remember(stackItems, audioCards, pageIndex) {
        stackItems.associate { it.id to it.kind } +
            audioCards.filter { it.pageIndex == pageIndex }.associate { it.id to ObjectStacking.Kind.AUDIO }
    }
    val underInkIds = remember(meta, pageIndex, stackRevision, kindOf) {
        meta.underInkObjectIds(pageIndex, kindOf)
    }
    val zIndexOf: (String) -> Float = { id ->
        val baseZ = ObjectStacking.zIndex(id, kindOf[id] ?: ObjectStacking.Kind.TEXT, stackOrder)
        ObjectStacking.inkAwareZ(baseZ, underInkIds.contains(id))
    }

    // 鎖定在畫布上（見 canvas/ObjectLock.kt）：鎖定的物件不接收觸控，雙指縮放、捲動頁面時
    // 碰到它也不會被選起來或進入編輯。不分頁查（物件 id 全域唯一）。
    val lockRevisionState = remember { mutableIntStateOf(0) }
    var lockRevision by lockRevisionState
    /** 正在顯示「解除鎖定」鈕的鎖定物件（點了鎖頭或點了鎖定的物件）。 */
    val lockPromptIdState = remember(pageId) { mutableStateOf<String?>(null) }
    var lockPromptId by lockPromptIdState
    val lockedIds = remember(meta, lockRevision, stackRevision) { meta.lockedObjectIds() }
    val objectLock = remember(meta, pageIndex) {
        com.kairumo.padnote.canvas.ObjectLockActions(
            isLocked = { id -> id in meta.lockedObjectIds() },
            setLocked = { id, locked ->
                meta.setObjectLocked(notebook?.first, pageIndex, id, locked)
                if (locked) {
                    // 鎖上就收掉它的選取：鎖定的物件點不到，留著選取外框的話是一組拖不動的把手。
                    if (selectedTextId == id) selectText(null)
                    if (selectedImageId == id) selectImage(null)
                    if (selectedChartId == id) selectedChartId = null
                    if (selectedTableId == id) selectedTableId = null
                    if (selectedLinkId == id) selectedLinkId = null
                    if (selectedAudioId == id) selectedAudioId = null
                    if (selectedModel3DId == id) selectedModel3DId = null
                    selectedShapeIds = selectedShapeIds - id
                    marqueeSelection = marqueeSelection - id
                }
                if (lockPromptId == id) lockPromptId = null
                lockRevision++
                AutoSync.noteLocalEdit(activity)
            }
        )
    }

    // pointerInput 的區塊只在 key 變時重建，裡面要讀最新的名單。
    val marqueeCandidatesLatest by androidx.compose.runtime.rememberUpdatedState(marqueeCandidates)
    val lockedIdsLatest by androidx.compose.runtime.rememberUpdatedState(lockedIds)
    val stackOrderLatest by androidx.compose.runtime.rememberUpdatedState(stackOrder)

    // 調整單一物件的層級（每個物件的把手、編輯面板共用，支援移至筆跡下方/上方）。
    val objectReorder: (String, ObjectStacking.Reorder) -> Unit = { id, op ->
        when (op) {
            ObjectStacking.Reorder.SEND_BELOW_INK -> {
                if (id !in underInkIds) {
                    meta.moveObjectsToInkPlane(notebook?.first, pageIndex, kindOf.filterKeys { it == id },
                        uniffi.padnote_core.FfiInkPlane.BELOW_INK)
                    stackRevision++
                }
            }
            ObjectStacking.Reorder.BRING_ABOVE_INK -> {
                if (id in underInkIds) {
                    meta.moveObjectsToInkPlane(notebook?.first, pageIndex, kindOf.filterKeys { it == id },
                        uniffi.padnote_core.FfiInkPlane.ABOVE_INK)
                    stackRevision++
                }
            }
            ObjectStacking.Reorder.TO_FRONT -> {
                if (id in underInkIds) {
                    meta.moveObjectsToInkPlane(notebook?.first, pageIndex, kindOf.filterKeys { it == id },
                        uniffi.padnote_core.FfiInkPlane.ABOVE_INK)
                }
                meta.setObjectOrder(notebook?.first, pageIndex, op.apply(id, stackOrder))
                stackRevision++
            }
            ObjectStacking.Reorder.TO_BACK -> {
                if (id !in underInkIds) {
                    meta.moveObjectsToInkPlane(notebook?.first, pageIndex, kindOf.filterKeys { it == id },
                        uniffi.padnote_core.FfiInkPlane.BELOW_INK)
                }
                meta.setObjectOrder(notebook?.first, pageIndex, op.apply(id, stackOrder))
                stackRevision++
            }
            else -> {
                meta.setObjectOrder(notebook?.first, pageIndex, op.apply(id, stackOrder))
                stackRevision++
            }
        }
    }

    val currentSelectedObjectIds: () -> Set<String> = {
        if (marqueeActive && marqueeSelection.isNotEmpty()) marqueeSelection
        else setOfNotNull(
            selectedTextId, selectedImageId, selectedTableId, selectedChartId,
            selectedLinkId, selectedAudioId, selectedModel3DId
        ) + selectedShapeIds
    }
    val applySinglePageClipboardSelection: (Set<String>) -> Unit = { created ->
        if (marqueeActive && created.size > 1) {
            marqueeSelection = created
        } else {
            val firstId = created.firstOrNull()
            selectText(firstId?.takeIf { textStore.find(it) != null })
            if (editingText != null && editingText?.id != selectedTextId) editingText = null
            selectImage(firstId?.takeIf { id -> imageStore.all.any { it.id == id } })
            selectedTableId = firstId?.takeIf { id -> tableStore.all.any { it.id == id } }
            selectedChartId = firstId?.takeIf { id -> chartStore.all.any { it.id == id } }
            selectedShapeIds = if (firstId != null && shapeStore.all.any { it.id == firstId }) setOf(firstId) else emptySet()
            selectedLinkId = firstId?.takeIf { id -> links.any { it.id == id } }
            selectedModel3DId = firstId?.takeIf { id -> models3D.any { it.id == id } }
            selectedAudioId = firstId?.takeIf { id -> audioCards.any { it.id == id } }
            if (marqueeActive) marqueeSelection = created
        }
    }
    val pasteSinglePageClipboard: (Offset?) -> Boolean = { targetPoint ->
        val created = com.kairumo.padnote.canvas.ObjectMarquee.pasteToStores(
            objectClipboard, targetPoint, pageIndex, notebook?.first, meta,
            imageStore, textStore, tableStore, chartStore, shapeStore
        )
        if (created.isNotEmpty()) {
            links = meta.links(); models3D = meta.models3D(); audioCards = meta.audioCards()
            isPlacingPasteObject = false
            applySinglePageClipboardSelection(created)
            imageRevision++; shapeRevision++; tableRevision++; chartRevision++
            textRevision++; linkRevision++; model3DRevision++; audioRevision++; stackRevision++
            AutoSync.noteLocalEdit(activity)
            true
        } else false
    }
    val objectClipboardActions = remember(pageIndex, pageId) {
        com.kairumo.padnote.canvas.ObjectClipboardActions(
            cut = { id ->
                val ids = if (marqueeActive && id in marqueeSelection) marqueeSelection else setOf(id)
                val captured = com.kairumo.padnote.canvas.ObjectMarquee.captureFromStores(
                    ids, true, pageIndex, notebook?.first, meta,
                    imageStore, textStore, tableStore, chartStore, shapeStore
                )
                if (captured.isNotEmpty()) {
                    objectClipboard = captured
                    isPlacingPasteObject = false
                    links = meta.links(); models3D = meta.models3D(); audioCards = meta.audioCards()
                    applySinglePageClipboardSelection(emptySet())
                    imageRevision++; shapeRevision++; tableRevision++; chartRevision++
                    textRevision++; linkRevision++; model3DRevision++; audioRevision++; stackRevision++
                    message = l10n("object_cut_hint")
                    AutoSync.noteLocalEdit(activity)
                }
            },
            copy = { id ->
                val ids = if (marqueeActive && id in marqueeSelection) marqueeSelection else setOf(id)
                val captured = com.kairumo.padnote.canvas.ObjectMarquee.captureFromStores(
                    ids, false, pageIndex, notebook?.first, meta,
                    imageStore, textStore, tableStore, chartStore, shapeStore
                )
                if (captured.isNotEmpty()) {
                    objectClipboard = captured
                    isPlacingPasteObject = false
                    message = l10n("object_copied_hint")
                }
            },
            duplicate = { id ->
                val ids = if (marqueeActive && id in marqueeSelection) marqueeSelection else setOf(id)
                val captured = com.kairumo.padnote.canvas.ObjectMarquee.captureFromStores(
                    ids, false, pageIndex, notebook?.first, meta,
                    imageStore, textStore, tableStore, chartStore, shapeStore
                )
                if (captured.isNotEmpty()) {
                    val created = com.kairumo.padnote.canvas.ObjectMarquee.pasteToStores(
                        captured, null, pageIndex, notebook?.first, meta,
                        imageStore, textStore, tableStore, chartStore, shapeStore
                    )
                    links = meta.links(); models3D = meta.models3D(); audioCards = meta.audioCards()
                    applySinglePageClipboardSelection(created)
                    imageRevision++; shapeRevision++; tableRevision++; chartRevision++
                    textRevision++; linkRevision++; model3DRevision++; audioRevision++; stackRevision++
                    AutoSync.noteLocalEdit(activity)
                }
            }
        )
    }

    // **新插入的物件一律放在最上層。**
    //
    // 沒有明確順序的物件，疊放次序由「型別的預設層級」決定 —— 圖片永遠在文字、
    // 表格之下，於是新貼的圖片被舊的文字蓋住，看起來像沒插進去。掛在「出現了新 id」
    // 這一個點上，而不是改每一個插入路徑：本機插入、匯入、範本全部會經過這裡。
    // 基準要等這一頁的物件讀完才記（載入也會讓 id 一個個冒出來，那不是「新插入」）。
    val latestStackItems by androidx.compose.runtime.rememberUpdatedState(stackItems)
    val knownObjectIdsState = remember(pageId) { mutableStateOf<Set<String>?>(null) }
    var knownObjectIds by knownObjectIdsState
    LaunchedEffect(pageId) {
        kotlinx.coroutines.delay(1000)
        knownObjectIds = latestStackItems.map { it.id }.toSet()
    }
    LaunchedEffect(stackItems, knownObjectIds) {
        val known = knownObjectIds ?: return@LaunchedEffect
        val appeared = stackItems.map { it.id }.filter { it !in known }
        if (appeared.isEmpty()) return@LaunchedEffect
        knownObjectIds = known + appeared
        // 鎖定的新物件是匯入的 PDF 底稿（`NotebookMeta.placePdfPages`）：它要留在最底下，
        // 也不該把使用者趕到打字模式 —— 匯入 PDF 就是為了接著在上面寫字。
        val locked = meta.lockedObjectIds()
        val fresh = appeared.filter { it.lowercase() !in locked }
        if (fresh.isEmpty()) return@LaunchedEffect
        val freshSet = fresh.toSet()
        meta.setObjectOrder(
            notebook?.first, pageIndex,
            ObjectStacking.withNewOnTop(
                stackItems.filter { it.id !in freshSet }, meta.objectOrder(pageIndex), fresh)
        )
        stackRevision++
        // 手寫模式下物件不吃觸控：剛插進來的東西會拖不動，看起來像插壞了。
        if (editorMode == EditorMode.DRAW) editorMode = EditorMode.TYPE
    }

    // 雲端同步（決策 D3 選項 A）：使用者挑一個資料夾，兩台裝置指同一個地方。
    // 備份檔：選一個既有的備份來復原。
    val backupPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        message = runRestore(activity, uri)
    }

    val editorBackupCreatePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        message = runBackupToUri(activity, uri)
    }

    val folderPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        FolderSync.setFolder(activity, uri)
        message = runFolderSync(activity, notebook?.first)
    }

    // 被永久拒絕之後，畫面上要多一條「開啟設定」—— 那是唯一還走得通的路。
    val micBlockedState = remember { mutableStateOf(false) }
    var micBlocked by micBlockedState
    val micPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        val session = notebook?.first
        if (granted && session != null) {
            recordSeconds = 0
            recordingPaused = false
            message = audio.start(pageId ?: "", session, com.kairumo.padnote.audio.AudioTranscriber.sourceLanguageTag(activity)) { message = it }
            recording = audio.isRecording
        } else {
            // 被拒之後再按同一顆按鈕，系統**不會再跳對話框** —— 只會直接回
            // 拒絕。所以這裡要講的是「去設定裡開」，而不是重複同一句話。
            micBlocked = true
            message = uiString("mic_permission_blocked")
        }
    }

    // 離開畫面時一定要停掉麥克風 —— 忘了停的話，App 退到背景還在錄，
    // 使用者只會看到狀態列那個紅點，不知道是誰。
    DisposableEffect(Unit) {
        onDispose { notebook?.first?.let { audio.stop(it) } }
    }
    val penOnlyState = remember { mutableStateOf(false) }
    var penOnly by penOnlyState
    // 預設**關閉**低延遲。
    //
    // 實機回報：開著的時候畫布全白、連工具列的按鈕都按不動。前緩衝那條路
    // 還沒在實機上驗過，不能讓它擋在使用者與「能不能寫字」之間 ——
    // 已經驗過會動的那條路才該是預設值。
    val lowLatencyState = remember { mutableStateOf(false) }
    var lowLatency by lowLatencyState
    val showPalmThresholdsState = remember { mutableStateOf(false) }
    var showPalmThresholds by showPalmThresholdsState
    /// 已經產生、正在等使用者確認的匯出檔（S-100）。
    val pendingExportState = remember {
        mutableStateOf<Pair<java.io.File, Exporter.Format>?>(null)
    }
    var pendingExport by pendingExportState
    // PDF／PNG／列印都用畫布自己的元件算繪（見 `PageSnapshot`）：所見即所得。
    // PNG 匯出的是**目前停的這一頁**（原本不論在哪一頁都匯出第一頁）。
    val exportNow: (Exporter.Format) -> Unit = { format ->
        val session = notebook?.first
        if (session == null) {
            message = exportFailureMessage(
                IllegalStateException(L10n.t("err_core_not_ready")))
        } else {
            message = l10n("export_rendering")
            scope.launch {
                Exporter.exportWysiwyg(
                    activity, session, format, pageIndex, audioDirectory,
                    languageTag = deviceLanguageTag()
                ).fold(
                    onSuccess = { message = null; pendingExport = it to format },
                    onFailure = { message = exportFailureMessage(it) }
                )
            }
        }
    }
    val printNow: (PadnoteSession) -> Unit = { session ->
        scope.launch {
            runCatching {
                Exporter.printWysiwyg(activity, session, audioDirectory, deviceLanguageTag())
            }.onFailure { message = L10n.errorText(it) }
        }
    }
    /// 使用者是否調過掌拒門檻 —— 晶片要亮起來，不然沒有人知道自己改過。
    val palmTunedState = remember {
        mutableStateOf(PalmThresholdStore.radius(activity) != null)
    }
    var palmTuned by palmTunedState
    val showPenSettingsState = remember { mutableStateOf(false) }
    var showPenSettings by showPenSettingsState
    val penTunedState = remember {
        mutableStateOf(PenSettingsStore.floor(activity) != null)
    }
    var penTuned by penTunedState

    val lowLatencyUnavailableState = remember { mutableStateOf(false) }
    var lowLatencyUnavailable by lowLatencyUnavailableState
    val revisionState = remember { mutableIntStateOf(0) }
    var revision by revisionState
    /**
     * 連續模式裡任何一頁有變動就遞增（只給側欄縮圖用）。整頁模式的側欄也要加上它：
     * 縮圖快取以 revision 的總和為鍵，換回整頁模式時總和若退回舊值，會拿到搬動之前的快取圖。
     */
    val continuousContentRevisionState = remember { mutableIntStateOf(0) }
    var continuousContentRevision by continuousContentRevisionState

    /**
     * 把第 `from` 頁搬到 `to`（S-86／S-87）。
     *
     * 走核心的 `movePage` —— 它會記進 oplog，所以這個順序**跟著同步走到
     * 別台裝置**。Apple 端的頁面順序住在它自己的檔案裡，所以那邊不必用
     * 這一支；Android 的頁面住在核心裡，沒有它就搬不動。
     */
    fun movePage(from: Int, to: Int) {
        val session = notebook?.first ?: return
        if (from == to) return
        val pageId = runCatching { session.pageIdAt(from.toUInt()) }.getOrNull() ?: return
        runCatching { session.movePage(pageId, to.toUInt()) }
            .onSuccess {
                // **平台這一層按頁碼存的東西也要跟著搬。**
                // `movePage` 只動核心裡的頁面順序，紙張樣板與物件堆疊順序
                // 都是用頁碼當鍵的 —— 少了這一行，症狀是
                // 「我搬了一頁，它的版面留在原地」。
                meta.movePageData(session, from, to, pageCount)
                // 跟著搬過去 —— 停在原本的索引會變成「我搬了一頁，
                // 畫面卻跳到別頁」。
                switchToPage(to)
                revision++
                continuousContentRevision++
            }
    }

    /**
     * 複製一頁，新頁放在它正後方（與 Apple 頁面選單的「複製頁面」相同）。
     *
     * 核心在**同一個 session** 裡複製區塊、筆畫、形狀與連接線（`duplicatePage`）。
     * 平台這一層按頁碼或物件 id 存的東西（紙張、堆疊順序、筆跡下方名單、形狀樣式）
     * 用它回傳的 id 對照表跟著複製。
     */
    fun duplicatePage(index: Int) {
        val s = notebook?.first ?: return
        val sourceId = runCatching { s.pageIdAt(index.toUInt()) }.getOrNull() ?: return
        val result = runCatching { s.duplicatePage(sourceId) }.getOrNull() ?: return
        val newCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount + 1)
        val target = (index + 1).coerceAtMost(newCount - 1)
        val ids = result.idMap
        // 紙張：在新頁的位置插入同一張紙（後面的頁跟著往後挪）。
        meta.insertPageTemplate(s, target, meta.paperId(index), newCount - 1)
        // 以頁碼為鍵的東西：先把後面的頁往後挪一格，再填新頁。
        meta.shiftPageKeyedData(s, fromIndex = target, totalPagesBefore = newCount - 1)
        meta.objectOrder(index).mapNotNull { ids[it] }.takeIf { it.isNotEmpty() }
            ?.let { meta.setObjectOrder(s, target, it) }
        meta.explicitUnderInkObjectIds(index).mapNotNull { ids[it] }.toSet().takeIf { it.isNotEmpty() }
            ?.let { meta.setUnderInkObjectIds(s, target, it) }
        meta.explicitOverInkObjectIds(index).mapNotNull { ids[it] }.toSet().takeIf { it.isNotEmpty() }
            ?.let { meta.setOverInkObjectIds(s, target, it) }
        val shapeStyles = meta.shapeStyles().mapNotNull { (old, style) -> ids[old]?.let { it to style } }.toMap()
        val linkStyles = meta.connectionStyles().mapNotNull { (old, style) -> ids[old]?.let { it to style } }.toMap()
        meta.updateStyles(s, shapeUpserts = shapeStyles, connectionUpserts = linkStyles)
        pageCount = newCount
        switchToPage(target)
        revision++
        continuousContentRevision++
    }

    /**
     * 在指定頁面後插入新頁（S-93／S-86）。
     * 若 paperId != null 則套用指定樣板，否則為空白頁。
     */
    fun insertPageAfter(afterIndex: Int, paperId: String?) {
        val s = notebook?.first ?: return
        val tmpl = if (paperId != null) {
            uniffi.padnote_core.paperTemplates().firstOrNull { it.id == paperId }
        } else null
        val style = tmpl?.pageStyle ?: uniffi.padnote_core.PageStyle.BLANK
        val newPageId = runCatching { s.addPage(style) }.getOrNull() ?: return
        val newCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount + 1)
        val targetIndex = (afterIndex + 1).coerceAtMost(newCount - 1)
        if (targetIndex < newCount - 1) {
            runCatching { s.movePage(newPageId, targetIndex.toUInt()) }
        }
        if (paperId != null) {
            meta.insertPageTemplate(s, targetIndex, paperId, newCount)
        }
        // 後面的頁往後挪了一格，以頁碼為鍵的圖層設定也要跟著挪。
        if (targetIndex < newCount - 1) meta.shiftPageKeyedData(s, targetIndex, newCount - 1)
        pageCount = newCount
        switchToPage(targetIndex)
        revision++
    }

    /**
     * 整份 PDF 匯入：每一頁 PDF 成為一頁筆記內頁，縮放到整頁大小。
     *
     * 從目前這一頁後面開始插；目前這一頁完全空白（剛建好的筆記）的話，第一頁就放在它上面。
     *
     * # 為什麼整條路都在背景
     *
     * 原本的對話框在 Compose 的組合階段（主執行緒）算繪並編碼整頁 PNG，大小是「PDF 點數
     * × 2」—— 掃描版 PDF 一頁就是 4960×7016。現在算繪、編碼、寫進核心（`putBlob` 會寫檔）
     * 都在 [Dispatchers.IO]，一頁做完就放掉那張點陣圖；主執行緒只回報進度、最後收尾一次。
     * 以頁碼為鍵的中繼資料只挪一次、只落盤兩次（原本每插一頁就挪一次、寫一次）。
     *
     * @return 匯入的頁數與畫不出來而略過的頁數。
     */
    suspend fun importPdfAsPages(file: java.io.File, onProgress: (done: Int, total: Int) -> Unit): Pair<Int, Int> {
        val s = notebook?.first ?: return 0 to 0
        val anchor = pageIndex
        val countBefore = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount)
        val reuseCurrent = stackItems.isEmpty() && engine.strokes.isEmpty() &&
            audioCards.none { it.pageIndex == anchor } && links.none { it.pageIndex == anchor }
        val pageWidth = PageGeometry.width
        val pageHeight = PageGeometry.height
        val placed = mutableListOf<Pair<Int, String>>()
        var inserted = 0
        var skipped = 0
        try {
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                runCatching {
                    android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                        android.graphics.pdf.PdfRenderer(fd).use { renderer ->
                            val total = renderer.pageCount
                            for (i in 0 until total) {
                                kotlinx.coroutines.currentCoroutineContext().ensureActive()
                                val page = PageImageRenderer.renderPdfPageForImport(renderer, i, pageWidth, pageHeight)
                                if (page == null) {
                                    skipped++
                                } else {
                                    val target = if (reuseCurrent && placed.isEmpty()) anchor else {
                                        // 新頁一律接在上一張後面：第 k 張新頁的最終頁碼就是 anchor + 1 + k。
                                        val newId = s.addPage(uniffi.padnote_core.PageStyle.BLANK)
                                        val at = anchor + 1 + inserted
                                        if (at < countBefore + inserted) s.movePage(newId, at.toUInt())
                                        inserted++
                                        at
                                    }
                                    val pid = s.pageIdAt(target.toUInt())
                                    ImageStore(s, pid).insertPlaced(
                                        page.png, file.nameWithoutExtension, page.x, page.y, page.width, page.height
                                    )?.let { placed += target to it.id }
                                }
                                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) { onProgress(i + 1, total) }
                            }
                        }
                    }
                }.onFailure { if (it is kotlinx.coroutines.CancellationException) throw it }
            }
        } finally {
            // 取消（使用者按了取消）時也要收尾：已經插進去的頁面要讓中繼資料對齊，不然後面的頁
            // 的圖層設定、卡片會錯位。
            kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {
                // 後面的頁往後挪了 inserted 格：以頁碼為鍵的圖層設定、卡片、膠帶一次挪完。
                if (inserted > 0 && anchor + 1 < countBefore) meta.shiftPageKeyedData(s, anchor + 1, countBefore, by = inserted)
                meta.placePdfPages(s, placed)
                pageCount = runCatching { s.pageCount().toInt() }.getOrDefault(countBefore + inserted)
                placed.firstOrNull()?.let { switchToPage(it.first) }
                imageStore.load()
                imageRevision++
                stackRevision++
                revision++
                sessionRevision++
                // 匯入 PDF 是為了在上面寫字：停在手寫模式。
                editorMode = EditorMode.DRAW
                com.kairumo.padnote.sync.AutoSync.noteLocalEdit(activity)
            }
        }
        return placed.size to skipped
    }

    // 把解析好的文件排進**目前這一頁**：依文件順序由上往下，放不下的接到後面新插入的頁面。
    importedDocument?.let { parsed ->
        LaunchedEffect(parsed) {
            val s = notebook?.first
            if (s == null) { importedDocument = null; return@LaunchedEffect }
            val base = pageIndex
            val width = PageGeometry.width - PageGeometry.PRINTABLE_INSET * 2
            val heights = parsed.pieces.map { piece ->
                when (piece) {
                    is DocumentImport.TextPiece ->
                        DocumentImport.estimatedHeight(piece.text, 16f, width)
                    is DocumentImport.TablePiece -> piece.table.apply { this.width = width.coerceAtMost(440f) }
                        .layout().height.toFloat()
                    is DocumentImport.ImagePiece -> {
                        val bmp = android.graphics.BitmapFactory.decodeByteArray(piece.bytes, 0, piece.bytes.size)
                        val w = minOf(width, bmp?.width?.toFloat() ?: width)
                        if (bmp != null && bmp.width > 0) w * bmp.height / bmp.width else 180f
                    }
                }
            }
            val placements = DocumentImport.flow(heights)
            val extraPages = placements.maxOf { it.pageOffset }
            // 在目前這頁後面連續插入需要的頁數（每插一頁畫面會跳過去，最後跳回來）。
            for (k in 0 until extraPages) insertPageAfter(base + k, null)
            for ((piece, place) in parsed.pieces.zip(placements)) {
                val targetPage = runCatching { s.pageIdAt((base + place.pageOffset).toUInt()) }.getOrNull()
                    ?: continue
                val x = PageGeometry.PRINTABLE_INSET
                when (piece) {
                    is DocumentImport.TextPiece -> {
                        val box = TextBoxStore(s, targetPage).also { it.load() }.let { store ->
                            store.create(x, place.y)
                        }
                        box.text = piece.text
                        box.width = width
                        box.height = heights[parsed.pieces.indexOf(piece)]
                        // 與語音轉文字同一個外觀：無框線、透明底，像直接寫在紙上。
                        box.backgroundColorHex = "clear"
                        box.hasBorder = false
                        TextBoxStore(s, targetPage).persist(box)
                    }
                    is DocumentImport.TablePiece ->
                        TableStore(s, targetPage).create(
                            piece.table.copyTable().apply { this.x = x; this.y = place.y })
                    is DocumentImport.ImagePiece ->
                        ImageStore(s, targetPage).insert(piece.bytes, "import")?.let { img ->
                            img.x = x; img.y = place.y
                            ImageStore(s, targetPage).persist(img)
                        }
                }
            }
            importedDocument = null
            switchToPage(base)
            sessionRevision++
            message = l10n("import_document_done")
        }
    }

    /**
     * 刪除指定頁面（S-86）。
     */
    fun deletePageAt(atIndex: Int) {
        val s = notebook?.first ?: return
        if (pageCount <= 1) return
        val target = runCatching { s.pageIdAt(atIndex.toUInt()) }.getOrNull() ?: return
        runCatching { s.removePage(target) }
        meta.removePageTemplate(s, atIndex, pageCount)
        pageCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount - 1)
        if (pageIndex >= pageCount) {
            switchToPage((pageCount - 1).coerceAtLeast(0))
        }
        revision++
        continuousContentRevision++
    }

    val clearTokenState = remember { mutableIntStateOf(0) }
    var clearToken by clearTokenState
    // 改名對話框（頂列的標題點一下就開）。
    val renamingCurrentState = remember { mutableStateOf(false) }
    var renamingCurrent by renamingCurrentState
    // 跨本複製／搬移頁面（S-91）：(頁次, 是否為搬移)。
    val transferringPageState = remember { mutableStateOf<Pair<Int, Boolean>?>(null) }
    var transferringPage by transferringPageState
    // 特殊符號面板（S-97）。
    val showSymbolPickerState = remember { mutableStateOf(false) }
    var showSymbolPicker by showSymbolPickerState

    // 把這一頁已經存在檔案裡的筆畫讀回來。
    //
    // 少了這一步，使用者寫的字在重開筆記本之後就消失了 —— 資料其實還在
    // `.padnote` 裡，只是沒有人去讀。物件（文字方塊、表格、形狀）都有各自的
    // `load()`，只有墨跡沒有，所以症狀是「圖還在、字不見了」，
    // 看起來像渲染壞掉而不是少讀一份資料。
    LaunchedEffect(notebook, pageId, penOnly) {
        engine.setPenOnly(penOnly)
        engine.loadAsync()
        revision++
        clearToken++   // 低延遲路徑的前緩衝也要重畫，否則讀回來的筆畫不會出現
    }

    // ── 全域復原／重做（CanvasHistory）─────────────────────────────
    //
    // 筆跡與物件在同一條時間軸上：先畫一筆、再搬一張圖、再畫一筆，復原三次就是
    // 反過來三步。原本只有筆跡能復原 —— 搬圖、刪表格、改形狀顏色、調圖層都退不回去。
    // 以這一頁為單位：換頁或重新載入（含別台同步進來）就重新開始，別人的修改不會變成
    // 這台的復原步驟。
    // 換到連續頁面模式再換回來也重新開始：那段期間的修改由連續模式自己的時間軸記。
    val canvasHistory = remember(notebook, pageId, pageDisplayMode) { CanvasHistory() }
    // 連續頁面模式的復原由 ContinuousPagesView 處理（它自己的時間軸跨頁）；工具列的鈕照樣只有一組。
    val continuousUndo = remember { ContinuousUndoController() }
    fun canvasSnapshot() = CanvasSnapshot(
        texts = textStore.all.map { it.copy() },
        images = imageStore.all.map { it.copy() },
        shapes = shapeStore.all.map { it.copy() },
        connections = shapeStore.allConnections.map { it.copy() },
        tables = tableStore.all.map { it.copyTable() },
        charts = chartStore.all.map { it.copy() },
        links = links.map { it.copy() },
        models3D = models3D.map { it.copy() },
        audio = audioCards.map { it.copy() },
        order = meta.objectOrder(pageIndex)
    )
    val isRestoringHistoryState = remember { mutableStateOf(false) }
    var isRestoringHistory by isRestoringHistoryState
    fun applyCanvasSnapshot(snapshot: CanvasSnapshot) {
        canvasHistory.withoutRecording {
            isRestoringHistory = true
            textStore.restoreTo(snapshot.texts)
            imageStore.restoreTo(snapshot.images)
            shapeStore.restoreTo(snapshot.shapes, snapshot.connections)
            tableStore.restoreTo(snapshot.tables)
            chartStore.restoreTo(snapshot.charts)
            if (links != snapshot.links) {
                links = snapshot.links.map { it.copy() }.toMutableList()
                meta.setLinks(notebook?.first, links)
            }
            if (models3D != snapshot.models3D) {
                models3D = snapshot.models3D.map { it.copy() }.toMutableList()
                meta.setModels3D(notebook?.first, models3D)
            }
            if (audioCards != snapshot.audio) {
                audioCards = snapshot.audio.map { it.copy() }.toMutableList()
                meta.setAudioCards(notebook?.first, audioCards)
            }
            if (meta.objectOrder(pageIndex) != snapshot.order) {
                meta.setObjectOrder(notebook?.first, pageIndex, snapshot.order)
            }
            // 指向已經不存在的物件的選取要清掉，否則工具列與把手對著一個空殼。
            val alive = (snapshot.texts.map { it.id } + snapshot.images.map { it.id } + snapshot.shapes.map { it.id } +
                snapshot.connections.map { it.id } + snapshot.tables.map { it.id } + snapshot.charts.map { it.id } +
                snapshot.links.map { it.id } + snapshot.models3D.map { it.id } + snapshot.audio.map { it.id }).toSet()
            if (selectedTextId != null && selectedTextId !in alive) selectText(null)
            if (editingText != null && editingText?.id !in alive) editingText = null
            if (selectedImageId != null && selectedImageId !in alive) selectImage(null)
            if (selectedTableId != null && selectedTableId !in alive) selectedTableId = null
            if (selectedChartId != null && selectedChartId !in alive) selectedChartId = null
            if (selectedConnectionId != null && selectedConnectionId !in alive) selectedConnectionId = null
            if (selectedLinkId != null && selectedLinkId !in alive) selectedLinkId = null
            if (selectedAudioId != null && selectedAudioId !in alive) selectedAudioId = null
            if (selectedModel3DId != null && selectedModel3DId !in alive) selectedModel3DId = null
            selectedShapeIds = selectedShapeIds.filter { it in alive }.toSet()
            marqueeSelection = marqueeSelection.filter { it in alive }.toSet()
            textRevision++; imageRevision++; shapeRevision++; tableRevision++; chartRevision++
            linkRevision++; model3DRevision++; audioRevision++; stackRevision++
        }
    }
    fun globalUndo() {
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
            continuousUndo.undo()
            return
        }
        val did = canvasHistory.undo(::applyCanvasSnapshot) { engine.undo() }
        // 這次開啟之後還沒做過任何事：沿用原本的行為，收回檔案裡最後一筆。
        if (!did) engine.undo()
        revision++
        clearToken++
    }
    fun globalRedo() {
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
            continuousUndo.redo()
            return
        }
        val did = canvasHistory.redo(::applyCanvasSnapshot) { engine.redo() }
        if (!did) engine.redo()
        revision++
        clearToken++
    }
    // 基準一定要在所有物件 load() 之後才取（效果依宣告順序執行，這一段在它們後面）——
    // 先取的話，「讀進來」本身會被當成新增了所有物件，按一次復原整頁就空了。
    LaunchedEffect(canvasHistory) { canvasHistory.reset(canvasSnapshot()) }
    DisposableEffect(engine, canvasHistory) {
        engine.onUndoableAction = { canvasHistory.inkCommitted() }
        onDispose { engine.onUndoableAction = null }
    }
    // 物件有動就比對一次（各型別寫回之後都會遞增自己的 revision）。
    LaunchedEffect(
        canvasHistory, textRevision, imageRevision, shapeRevision, tableRevision, chartRevision,
        stackRevision, linkRevision, model3DRevision, audioRevision, links, models3D, audioCards
    ) {
        if (isRestoringHistory || canvasHistory.isSuppressing) {
            isRestoringHistory = false
            canvasHistory.reset(canvasSnapshot())
            return@LaunchedEffect
        }
        canvasHistory.observe(canvasSnapshot())
    }

    // 筆刷、顏色、筆寬。在此之前 Android 只有一支固定的黑色鋼筆，
    // 連橡皮擦都選不到 —— 核心一直支援，缺的只是 UI。
    val inkToolState = remember { mutableStateOf(InkTool.FOUNTAIN_PEN) }
    var inkTool by inkToolState

    // 最後用過的**筆刷**。觸控筆放開側鍵時要回到它（工作項 S-67）。
    // 記筆刷而不是「上一個工具」：後者在擦完之後可能回到套索。
    val lastBrushToolState = remember { mutableStateOf(InkTool.FOUNTAIN_PEN) }
    var lastBrushTool by lastBrushToolState
    // 按著側鍵之前選的是哪一支。放開時回到它。
    //
    // `null` 表示「這一次的橡皮擦不是側鍵切出來的」—— 使用者自己在工具列
    // 選的橡皮擦，不能因為他碰了一下側鍵就被換掉。
    val penHeldToolState = remember { mutableStateOf<InkTool?>(null) }
    var penHeldTool by penHeldToolState
    // 有東西正懸在畫布上等著放下（工作項 S-68）。一定要有這個回饋：
    // 拖放看不見目標的話，使用者分不出「這裡不能放」與「放了但沒反應」。
    val isImageDropTargetedState = remember { mutableStateOf(false) }
    var isImageDropTargeted by isImageDropTargetedState
    // 次世代 UI/UX Phase 5: 折疊立起雙屏模式 (Tabletop Mode / Stage Manager Posture)
    val isTabletopManualState = remember { mutableStateOf(false) }
    var isTabletopManual by isTabletopManualState
    // 次世代 UI/UX Phase 4: 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap)
    val isMagneticSnapActiveState = remember { mutableStateOf(false) }
    var isMagneticSnapActive by isMagneticSnapActiveState

    LaunchedEffect(isMagneticSnapActive) {
        engine.isMagneticSnapActive = isMagneticSnapActive
    }
    LaunchedEffect(magneticGuideActive) {
        if (magneticGuideActive) {
            kotlinx.coroutines.delay(1200)
            magneticGuideActive = false
        }
    }
    LaunchedEffect(inkTool) { if (inkTool.kind != null) lastBrushTool = inkTool }

    val view = LocalView.current

    // 換工具。工具列與筆身控制項走同一條路 —— 各寫一份的話，用側鍵切到
    // 橡皮擦時 `engine.isErasing` 會忘了跟著改，症狀是「側鍵選到橡皮擦了，
    // 但畫下去還是墨跡」。
    fun applyInkTool(picked: InkTool) {
        inkTool = picked // state-entry: 換工具的唯一正門
        engine.isErasing = picked.isEraser
        com.kairumo.padnote.platform.MainThreadStallMonitor.breadcrumb("select tool ${picked.kind}")
        picked.kind?.let { engine.tool = it }
        // 離開套索就清掉選取。留著的話，畫面上會浮著一個虛線框與
        // 一排按鈕，而它們作用的對象使用者早就看不出是什麼了。
        if (!picked.isLasso) {
            lasso.clear()
            continuousLasso.clear()
        }
    }

    // 使用者把正在用的那一支關掉時要換一支，否則畫面上沒有任何晶片是亮的，
    // 而畫布還在用那支筆 —— 他看到的是「我的筆不見了，但寫出來還是原本那支」。
    // 換成哪一支由核心決定（S-261），Apple 走同一條規則。
    LaunchedEffect(com.kairumo.padnote.ui.ToolbarSettings.hiddenIdentifiers) {
        val next = com.kairumo.padnote.ui.ToolbarSettings.identifierAfterHiding(
            activity, deviceLanguageTag(), inkTool.parityIdentifier
        )
        if (next != inkTool.parityIdentifier) {
            InkTool.entries.firstOrNull { it.parityIdentifier == next }?.let { applyInkTool(it) }
        }
    }

    // 觸控筆側鍵（或把筆倒過來）。
    //
    // **規則不在這裡** —— 「這個動作要做什麼」整張表在核心
    // （`padnote-input::pen`），與 Apple 共用同一份。這裡只把核心回的結果
    // 換成 Android 這一側的工具。
    val penControls = remember { PenHardware.controls(activity) }
    DisposableEffect(engine) {
        engine.onPenControlChanged = { control, pressed ->
            if (control != null) {
                val momentary = penControls.isMomentary(control)
                // 按著的控制項放開時，只還原**我們自己切過去的那一次**。
                // 使用者自己在工具列上選了橡皮擦、然後碰了一下側鍵，
                // 放開時把他的橡皮擦換掉是錯的。
                val shouldHandle = !momentary || pressed || penHeldTool != null
                if (shouldHandle) {
                    if (momentary && pressed) penHeldTool = inkTool

                    when (penControls.outcome(
                        control, pressed, inkTool.isEraser, inkTool.isLasso
                    )) {
                        FfiPenOutcome.NOTHING -> Unit
                        FfiPenOutcome.USE_ERASER -> applyInkTool(InkTool.ERASER)
                        // 放開時回到按下去之前那一支，而不是「最後用過的筆刷」
                        // —— 兩者通常一樣，但使用者若在按著側鍵的期間又換過筆，
                        // 他要的是回到他剛剛選的那一支。
                        FfiPenOutcome.USE_LAST_BRUSH ->
                            applyInkTool(penHeldTool ?: lastBrushTool)
                        FfiPenOutcome.USE_LASSO -> applyInkTool(InkTool.LASSO)
                        FfiPenOutcome.SHOW_INK_ATTRIBUTES -> showProColors = true
                        // **復原、重做與尺規在 Android 的手寫畫布上還不存在**
                        // （工具列沒有這三顆按鈕），所以指派到它們等於關掉。
                        // 這樣比硬湊一個行為好：按了沒反應，使用者會去換一個
                        // 指派；按了做出別的事，他會以為是壞的。
                        //
                        // 核心那張表是兩個平台共用的，有這三個選項是因為 Apple
                        // 那邊做得到 —— 之後 Android 補上時，這裡改成真的呼叫即可。
                        FfiPenOutcome.UNDO,
                        FfiPenOutcome.REDO,
                        FfiPenOutcome.TOGGLE_RULER -> Unit
                    }

                    if (momentary && !pressed) penHeldTool = null
                    // 筆身的動作是看不見的 —— 使用者當下正看著筆尖，
                    // 一下短回饋讓他知道剛剛那下有收到。
                    view.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
                }
            }
        }
        engine.onMagneticSnap = { start, end ->
            magneticGuideStart = start
            magneticGuideEnd = end
            magneticGuideActive = true
            view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
        }
        onDispose {
            engine.onPenControlChanged = null
            engine.onMagneticSnap = null
        }
    }
    // Ctrl+1–Ctrl+6 選工具。索引超過工具數就忽略 —— Apple 有九支、
    // Android 只有六支，按 Ctrl+7 不該讓 App 當掉。
    LaunchedEffect(Unit) {
        AppCommands.events.collect { command ->
            when (command) {
                is AppCommand.SelectTool ->
                    // 與工具列同一條路（applyInkTool），快捷鍵選到橡皮擦才真的會擦。
                    inkToolShortcutOrder.getOrNull(command.index)?.let { applyInkTool(it) }
                // 切回手寫時要清掉選取 —— 與工具列上那顆按鈕做的事一樣。
                // 只翻模式不清的話，畫面上會浮著一組在手寫模式下按不動的把手。
                is AppCommand.ToggleEditorMode ->
                    if (editorMode == EditorMode.DRAW) {
                        editorMode = EditorMode.DRAW
                    } else {
                        editorMode = EditorMode.DRAW
                        clearSelection()
                    }
                else -> Unit
            }
        }
    }
    // Ctrl+X／C／V：套索模式剪下／複製／貼上筆跡，或剪下／複製／貼上畫布物件（對齊 Apple 的 ⌘X/C/V）。
    // 連續頁面模式由 ContinuousPagesView 自己接。
    LaunchedEffect(lasso, engine, pageDisplayMode) {
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) return@LaunchedEffect
        AppCommands.events.collect { command ->
            if (inkTool.isLasso) {
                val changed = when (command) {
                    AppCommand.Cut -> lasso.cut(engine)
                    AppCommand.Copy -> lasso.copy(engine)
                    AppCommand.Paste -> lasso.paste(engine)
                    else -> return@collect
                }
                if (changed) revision++
            } else {
                val ids = currentSelectedObjectIds()
                when (command) {
                    AppCommand.Cut -> ids.firstOrNull()?.let { objectClipboardActions.cut(it) }
                    AppCommand.Copy -> ids.firstOrNull()?.let { objectClipboardActions.copy(it) }
                    AppCommand.Paste -> pasteSinglePageClipboard(null)
                    else -> Unit
                }
            }
        }
    }
    val inkColorHexState = remember { mutableStateOf("#000000") }
    var inkColorHex by inkColorHexState
    val inkWidthState = remember { mutableStateOf(3f) }
    var inkWidth by inkWidthState

    // 圖學：圖層顯示／鎖定逐本記；筆組、吸附與角度鎖定換了就同步到引擎。
    // 離開圖學工具時要把引擎還原成一般筆刷（圖層 0、實線、顏色與筆寬回到使用者選的）。
    LaunchedEffect(notebookId) {
        DraftingState.attach(activity)
        DraftingState.use(notebookId ?: "")
    }
    // 匯出／列印時略過這本筆記隱藏的圖層：PDF 與圖片要跟畫面上看到的一致。
    LaunchedEffect(notebook, DraftingState.version) {
        notebook?.first?.setExportHiddenLayers(DraftingState.hiddenLayers())
    }
    // 立體輔助與步驟編號。
    val showSolidStudioState = remember { mutableStateOf(false) }
    var showSolidStudio by showSolidStudioState
    // 圖學工具（標註、符號、圖框）。
    val showDraftingToolboxState = remember { mutableStateOf(false) }
    var showDraftingToolbox by showDraftingToolboxState
    LaunchedEffect(inkTool, DraftingState.tool) {
        DraftToolController.onChanged = { revision++ }
        com.kairumo.padnote.ink.DraftEditController.onChanged = { revision++ }
        engine.onToolTouch = if (inkTool.isDrafting && DraftingState.tool != DraftTool.NONE) { phase, x, y ->
            DraftToolController.handle(phase, x, y, engine)
        } else null
        if (engine.onToolTouch == null) DraftToolController.reset(engine) else DraftToolController.refreshHint()
    }
    LaunchedEffect(inkTool, DraftingState.markerMode) {
        engine.onMarkerTap = if (inkTool.isDrafting && DraftingState.markerMode) { x, y ->
            // 一次放一個「圈＋數字」，一次復原；放完編號加一。
            val n = DraftingState.stepNumber
            engine.insertDrafted(uniffi.padnote_core.draftStepMarker(n.toUInt(), x, y, 15f), 0f, 0f)
            DraftingState.stepNumber = (n + 1).coerceAtMost(99)
            revision++
        } else null
    }
    // 畫布的縮放平移在後面才宣告；用一個普通物件帶過來（巨大的 InkScreen 裡跨宣告捕捉狀態會讓編譯器產出壞位元碼）。
    val canvasInfo = remember { CanvasViewInfo() }
    if (showSolidStudio) {
        val density = LocalDensity.current.density
        com.kairumo.padnote.ink.SolidStudioDialog(
            languageTag = deviceLanguageTag(),
            pageWidth = PageGeometry.width,
            pageHeight = PageGeometry.height,
            sketchPolylines = { engine.sketchPolylines() },
            onInsert = { sheet ->
                val placed = placeSolidSheet(engine, sheet, canvasInfo.viewport, canvasInfo.scale, canvasInfo.offset, density)
                showSolidStudio = false
                revision++
                message = l10n("solid_place_hint")
                // 插入後直接用套索選住它，使用者拖一下就能搬（與 Apple 一致）。
                applyInkTool(InkTool.LASSO)
                lasso.select(placed.first, placed.second.map { it / density })
            },
            onDismiss = { showSolidStudio = false }
        )
    }
    if (showDraftingToolbox) {
        val density = LocalDensity.current.density
        val ctx = androidx.compose.ui.platform.LocalContext.current
        DraftingToolboxDialog(
            languageTag = deviceLanguageTag(),
            frameSupported = currentPaperId()?.let { uniffi.padnote_core.draftSheetFrame(it, "", true, false) != null } == true,
            onPickTool = { tool ->
                // 鏡射、陣列要處理套索選的那批線：在離開套索之前把它帶過來。
                if (tool.needsSelection && !captureEditSelection(lasso)) {
                    message = l10n("draft_edit_need_selection")
                    showDraftingToolbox = false
                } else {
                    DraftingState.selectTool(tool)
                    DraftToolController.reset(engine)
                    showDraftingToolbox = false
                }
            },
            onExport = { format ->
                showDraftingToolbox = false
                message = if (exportDraftingPage(ctx, engine, format)) null else l10n("draft_export_empty")
            },
            onStartPractice = { kind ->
                showDraftingToolbox = false
                startPractice(engine, kind)
                applyInkTool(InkTool.DRAFTING)
                revision++
            },
            onRectArray = { rows, cols, dx, dy ->
                showDraftingToolbox = false
                applyRectArrayToSelection(engine, lasso, rows, cols, dx, dy)
                revision++
                message = if (lasso.hasSelection) null else l10n("draft_edit_need_selection")
            },
            onInsertSymbol = { kit ->
                showDraftingToolbox = false
                val placed = placeDraftKit(engine, kit, canvasInfo.viewport, canvasInfo.scale, canvasInfo.offset, density)
                revision++
                message = l10n("draft_symbol_placed")
                if (placed != null) {
                    applyInkTool(InkTool.LASSO)
                    lasso.select(placed.first, placed.second.map { it / density })
                }
            },
            onInsertFrame = { thirdAngle ->
                showDraftingToolbox = false
                val kit = currentPaperId()?.let {
                    uniffi.padnote_core.draftSheetFrame(it, DraftingState.scaleLabel(), thirdAngle, true)
                }
                if (kit == null) {
                    message = l10n("draft_frame_unsupported")
                } else {
                    engine.insertDrafted(kit.strokes, 0f, 0f)
                    for (label in kit.texts) {
                        val box = textStore.create(label.x, label.y)
                        box.width = label.width
                        box.height = label.fontSize * 1.6f + 6f
                        box.text = l10n(label.key)
                        box.fontSize = label.fontSize
                        box.bold = label.bold
                        box.textColorHex = label.colorHex
                        box.backgroundColorHex = "clear"
                        box.hasBorder = false
                        textStore.persist(box)
                    }
                    textRevision++
                    revision++
                    message = l10n("draft_frame_inserted")
                }
            },
            onPlaceInstrument = { kind ->
                showDraftingToolbox = false
                placeDraftInstrument(kind, canvasInfo.viewport, canvasInfo.scale, canvasInfo.offset, density)
                applyInkTool(InkTool.DRAFTING)
                revision++
            },
            onDismiss = { showDraftingToolbox = false }
        )
    }
    // 製圖用的紙（三視圖、等角、作圖步驟…）一打開就選好「圖學」筆組。
    LaunchedEffect(notebook) {
        val session = notebook?.first ?: return@LaunchedEffect
        val paper = com.kairumo.padnote.library.NotebookMeta.load(session).paperId(0)
        if (uniffi.padnote_core.paperUsesDrafting(paper)) applyInkTool(InkTool.DRAFTING)
    }
    LaunchedEffect(
        inkTool, DraftingState.activePenId, DraftingState.layerOverride,
        DraftingState.snapEnabled, DraftingState.angleStep, DraftingState.reassignMode
    ) {
        if (inkTool.isDrafting) {
            engine.layer = DraftingState.activeLayerId
            engine.lineType = DraftingState.activeLineType
            engine.colorRgba = hexToRgba(DraftingState.activeColorHex)
            engine.baseWidth = DraftingState.activePen.width
            engine.snapStepDeg = if (DraftingState.snapEnabled) DraftingState.angleStep.toFloat() else null
            engine.reassignTarget = if (DraftingState.reassignMode) DraftingState.activeLayerId else null
        } else {
            engine.layer = 0
            engine.lineType = 0
            engine.colorRgba = hexToRgba(inkColorHex)
            engine.baseWidth = inkWidth
            engine.snapStepDeg = null
            engine.reassignTarget = null
        }
    }
    DisposableEffect(engine) {
        engine.onSnapped = { view.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK) }
        onDispose { engine.onSnapped = null }
    }

    val showStatusState = remember { mutableStateOf(false) }
    var showStatus by showStatusState
    /// 畫布上方那行輸入診斷（tool=/r=/p=/draw=/rej=/ges=）要不要顯示。
    ///
    /// 預設關。那一行是給開發看的，對使用者沒有任何意義，卻讓整個 App
    /// 看起來像個測試程式 —— 使用者就是這樣回報的。留一個開關是因為
    /// 掌拒與筆壓的問題只有實機重現得出來，屆時要能一鍵打開。
    val showInkDebugState = remember { mutableStateOf(false) }
    var showInkDebug by showInkDebugState
    val deletingPageState = remember { mutableStateOf(false) }
    var deletingPage by deletingPageState

    /// 草圖美化控制列。與 Apple 端一樣是**浮動列**而不是對話框：
    /// 調強度時要看得到畫布上的變化，對話框會把畫布蓋住。
    val showRefineBarState = remember { mutableStateOf(false) }
    var showRefineBar by showRefineBarState

    /// 主題專屬工具與它的兩個構圖輔助疊層。
    val showThemeToolsState = remember { mutableStateOf(false) }
    var showThemeTools by showThemeToolsState
    val showStickerLibraryState = remember { mutableStateOf(false) }
    var showStickerLibrary by showStickerLibraryState
    val showToolbarCustomizationState = remember { mutableStateOf(false) }
    var showToolbarCustomization by showToolbarCustomizationState
    val showAssetLibraryState = remember { mutableStateOf(false) }
    var showAssetLibrary by showAssetLibraryState

    /// 協同編輯。與 Apple 端講同一套協定（房號、邀請連結、端對端加密都在核心）。
    val showCollaborationState = remember { mutableStateOf(false) }
    var showCollaboration by showCollaborationState
    /// 語言選擇。Apple 端一直有，Android 原本只能跟著系統語系走 ——
    /// 而語言是跨裝置設定（G-04），在這台改了也要傳到別台。
    val showLanguagePickerState = remember { mutableStateOf(false) }
    var showLanguagePicker by showLanguagePickerState
    // 摘要與待辦（工作項 S-20）。
    val showNoteIntelligenceState = remember { mutableStateOf(false) }
    var showNoteIntelligence by showNoteIntelligenceState
    // 標題只在摘要時用得到，而編輯器畫面上不顯示它 —— 查一次存著，
    // 不要每次重組都去掃一遍筆記庫。
    val noteTitle = remember(notebookId, notebook) {
        notebookId?.let { id ->
            NotebookLibrary.liveIndexTitles(activity)[id.lowercase()]
                ?: runCatching { notebook?.first?.title() }.getOrNull()
                ?: FolderTree.titleOf(activity, id)
                ?: id
        }.orEmpty()
    }
    val collaboration = remember { CollaborationManager(activity) }

    // ── 即時協同（設計 §8，協定 3）─────────────────────────────
    //
    // 與 Apple 端同一套線上格式：物件欄位合併（最後寫入者勝）、文字方塊的字元 CRDT、
    // 逐筆的筆跡、頁面的增刪搬。iPad 與 Android 在同一個房間裡互相看得到對方的每一個修改。
    val collab = remember(notebookId) { AndroidCollabController(collaboration) }
    val continuousCollab = remember { ContinuousCollabBridge() }
    val collabRoom = (collaboration.status as? CollaborationManager.Status.Connected)?.roomId
    /** 以哪一個房間為基準 reset 過。斷線重連回同一個房間不算新的起點 —— 那段期間的本機修改還要送出去。 */
    val collabBaseRoomState = remember(collab) { mutableStateOf<String?>(null) }
    var collabBaseRoom by collabBaseRoomState
    /** 上一次要整份狀態的時間：加入時要過一次，緊接著的「補發不完整」就不必再要。 */
    val collabLastStateRequestState = remember(collab) { mutableStateOf(0L) }
    var collabLastStateRequest by collabLastStateRequestState
    /** 別人改了正在編輯的文字方塊：通知編輯框更新內容。 */
    val collabTextRevisionState = remember { mutableIntStateOf(0) }
    var collabTextRevision by collabTextRevisionState
    val collabActive = collabRoom != null && collabBaseRoom == collabRoom
    fun collabCanvas(): AndroidCollabCanvas? {
        val session = notebook?.first ?: return null
        return if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
            AndroidCollabCanvas(session, meta, continuousCollab.loadedPages(), continuousCollab.storesFor)
        } else {
            val live = CollabPageStores(textStore, imageStore, tableStore, chartStore, shapeStore)
            AndroidCollabCanvas(session, meta, listOfNotNull(pageId)) { if (it == pageId) live else null }
        }
    }
    fun collabEngineFor(page: String): InkEngine? =
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) continuousCollab.engineFor(page)
        else engine.takeIf { page == pageId }
    fun publishCollab() {
        if (!collabActive || collab.isApplyingRemote) return
        val session = notebook?.first ?: return
        collabCanvas()?.let { collab.publish(it, session) }
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
            for (page in continuousCollab.loadedPages()) continuousCollab.engineFor(page)?.let { collab.publishInk(page, it) }
        } else {
            pageId?.let { collab.publishInk(it, engine) }
        }
    }
    LaunchedEffect(collab, collabRoom) {
        val room = collabRoom ?: return@LaunchedEffect
        if (room == collabBaseRoom) return@LaunchedEffect
        val session = notebook?.first ?: return@LaunchedEffect
        // 進入（或換）房間：以目前的內容為大家共同的起點，再向房間裡的人要整份狀態（設計 §7）——
        // 這台的檔案可能比房間裡的舊。房間裡只有自己就不必要。
        collabCanvas()?.let { collab.reset(it, session) }
        collabBaseRoom = room
        if (collaboration.peers.isNotEmpty()) {
            collab.requestState()
            collabLastStateRequest = System.currentTimeMillis()
        }
    }
    // 本機的修改（各型別寫回之後都會遞增自己的 revision；頁面增刪搬會動 pageCount／revision）。
    LaunchedEffect(
        collabActive, textRevision, imageRevision, shapeRevision, tableRevision, chartRevision, stackRevision,
        linkRevision, model3DRevision, audioRevision, pinRevision, links, models3D, audioCards, pins, pageCount, revision
    ) { publishCollab() }
    // 回呼註冊一次、活得比這一格畫面久：一律呼叫「最新的那一份」，否則拿到的是舊的頁面與儲存。
    val latestPublishCollab by rememberUpdatedState<() -> Unit> { publishCollab() }
    DisposableEffect(engine) {
        val previous = engine.onContentCommitted
        engine.onContentCommitted = { previous?.invoke(); latestPublishCollab() }
        onDispose { engine.onContentCommitted = previous }
    }
    DisposableEffect(continuousCollab) {
        continuousCollab.onLocalChange = {
            latestPublishCollab()
            // 側欄縮圖跟著重畫。連續模式的變動不經過外層的 revision，不接的話縮圖
            // 要等重開筆記才更新（套索搬過的筆跡在縮圖上還在原位）。
            continuousContentRevision++
        }
        onDispose { continuousCollab.onLocalChange = null }
    }

    /** 放開一個被別人鎖住的選取。 */
    fun releaseSelection(id: String) {
        if (selectedTextId == id) selectText(null)
        if (editingText?.id == id) editingText = null
        if (selectedImageId == id) selectImage(null)
        if (selectedTableId == id) selectedTableId = null
        if (selectedChartId == id) selectedChartId = null
        if (selectedConnectionId == id) selectedConnectionId = null
        if (selectedLinkId == id) selectedLinkId = null
        if (selectedAudioId == id) selectedAudioId = null
        if (selectedModel3DId == id) selectedModel3DId = null
        selectedShapeIds = selectedShapeIds - id
        marqueeSelection = marqueeSelection - id
    }

    fun applyCollabOp(op: CollaborationManager.RemoteOplog) {
        if (!collabActive) return
        val session = notebook?.first ?: return
        // 先把本機還沒送出的修改送出去（送出排在下一格畫面）：否則別人的字套進來時，
        // 這台剛打、還沒進 CRDT 的字會被當成不存在而被蓋掉。
        publishCollab()
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        val result = collab.apply(op, session, meta, { collabCanvas()!! }, ::collabEngineFor) { delay, work ->
            main.postDelayed({ if (collabActive) work() }, delay)
        } ?: return
        if (result.pages) {
            // 留在原本那一頁（它的索引可能變了）；那一頁被刪了才退到最近的一頁。
            val stay = pageId
            pageCount = runCatching { session.pageCount().toInt() }.getOrDefault(pageCount)
            val moved = (0 until pageCount).firstOrNull {
                runCatching { session.pageIdAt(it.toUInt()) }.getOrNull() == stay
            }
            pageIndex = moved ?: pageIndex.coerceIn(0, maxOf(0, pageCount - 1)) // state-entry: 協同刪頁重算頁碼
        }
        if (result.objects) {
            meta.refresh(session)
            links = meta.links(); models3D = meta.models3D(); audioCards = meta.audioCards(); pins = meta.commentPins()
            // 對方刪掉的物件，本機的選取與編輯狀態要清掉。
            val alive = (textStore.all.map { it.id } + imageStore.all.map { it.id } + shapeStore.all.map { it.id } +
                shapeStore.allConnections.map { it.id } + tableStore.all.map { it.id } + chartStore.all.map { it.id } +
                links.map { it.id } + models3D.map { it.id } + audioCards.map { it.id }).toSet()
            if (pageDisplayMode != PageDisplayMode.CONTINUOUS) {
                listOfNotNull(selectedTextId, editingText?.id, selectedImageId, selectedTableId, selectedChartId,
                    selectedConnectionId, selectedLinkId, selectedAudioId, selectedModel3DId)
                    .plus(selectedShapeIds).filter { it !in alive }.forEach(::releaseSelection)
            }
            // 編輯框拿的是舊的那一份：換成寫回後的，之後的修改才不會把別人的改動蓋回去。
            editingText?.let { open -> textStore.find(open.id)?.let { editingText = it } }
            collabTextRevision++
            // 別人的修改不是這台的復原步驟。
            canvasHistory.reset(canvasSnapshot())
            continuousCollab.remoteApplied()
            textRevision++; imageRevision++; shapeRevision++; tableRevision++; chartRevision++
            linkRevision++; model3DRevision++; audioRevision++; pinRevision++; stackRevision++
        }
        if (result.ink) {
            continuousCollab.remoteApplied()
            clearToken++
        }
        revision++
        // 整份狀態套用完：只有這台有的物件補給房間。
        if (result.needsPublish) main.post { latestPublishCollab() }
    }
    val latestStateSyncNeeded by rememberUpdatedState<() -> Unit> {
        val now = System.currentTimeMillis()
        if (collabActive && now - collabLastStateRequest > 5_000) {
            collab.requestState()
            collabLastStateRequest = now
        }
    }
    val latestApplyCollabOp by rememberUpdatedState<(CollaborationManager.RemoteOplog) -> Unit> { applyCollabOp(it) }
    DisposableEffect(collaboration, collab) {
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        collaboration.onOplog = { op -> main.post { latestApplyCollabOp(op) } }
        // 中繼補不回漏掉的那一段：向其他成員要整份狀態（剛要過就不重複）。
        collaboration.onStateSyncNeeded = { main.post { latestStateSyncNeeded() } }
        // 兩人同時選了同一個物件、對方勝出：本機放手（設計 §5.3）。
        collaboration.onLeaseLost = { id, holder ->
            main.post {
                releaseSelection(id)
                collaboration.broadcastSelection(null)
                message = l10n("collab_object_locked").replace("%@", holder)
            }
        }
        onDispose {
            collaboration.onOplog = null; collaboration.onLeaseLost = null; collaboration.onStateSyncNeeded = null
        }
    }
    // 選取就是編輯鎖（設計 §5）：選到別人正在編輯的物件時放手並說明；打字（`text:`）不獨佔。
    val myCollabSelection = editingText?.let { CollaborationManager.TYPING_PREFIX + it.id }
        ?: selectedTextId ?: selectedImageId ?: selectedTableId ?: selectedChartId ?: selectedConnectionId
        ?: selectedShapeIds.firstOrNull() ?: selectedLinkId ?: selectedAudioId ?: selectedModel3DId
    LaunchedEffect(myCollabSelection, collabActive) {
        if (!collabActive) return@LaunchedEffect
        val id = myCollabSelection
        val holder = id?.takeUnless { it.startsWith(CollaborationManager.TYPING_PREFIX) }
            ?.let { collaboration.leaseHolder(it) }
        if (id != null && holder != null) {
            releaseSelection(id)
            collaboration.broadcastSelection(null)
            message = l10n("collab_object_locked").replace("%@", holder.userName)
            return@LaunchedEffect
        }
        collaboration.broadcastSelection(id)
    }
    val goldenSpiralState = remember { mutableStateOf(false) }
    var goldenSpiral by goldenSpiralState
    val ruleOfThirdsState = remember { mutableStateOf(false) }
    var ruleOfThirds by ruleOfThirdsState
    /// 美化後按鈕的可用狀態要跟著變（engine 才是真相來源，這只是重繪訊號）。
    val refineRevisionState = remember { mutableIntStateOf(0) }
    var refineRevision by refineRevisionState


    // 系統返回鍵＝回首頁。Android 使用者按的第一個東西就是它，
    // 不接的話按下去會直接把 App 關掉 —— 看起來像當掉。
    if (minimalistCanvasMode) {
        androidx.activity.compose.BackHandler {
            minimalistCanvasMode = false
            floatingPillExpanded = false
        }
    } else if (onBack != null) {
        // 系統返回鍵。Android 專有（規格裡標成 AndroidOnly）——
        // 沒有它的話，使用者按下返回鍵會直接離開 App 而不是回到首頁。
        // parity: editor.system_back
        androidx.activity.compose.BackHandler { onBack() }
    }
    val showMenuState = remember { mutableStateOf(false) }
    var showMenu by showMenuState
    // 頁面結構欄。平板預設展開，手機預設收起。
    val showPageSidebarState = remember { mutableStateOf(isTablet) }
    var showPageSidebar by showPageSidebarState
    // 畫布的縮放與平移。預設適應頁寬（響應式縮放，上限 200%）。換頁時歸位。
    val canvasScaleState = remember(pageId) { mutableFloatStateOf(1f) }
    var canvasScale by canvasScaleState
    val canvasOffsetState = remember(pageId) { mutableStateOf(Offset.Zero) }
    var canvasOffset by canvasOffsetState
    val canvasViewportState = remember { mutableStateOf(Size.Zero) }
    var canvasViewport by canvasViewportState
    val didInitialFitState = remember(pageId) { mutableStateOf(false) }
    var didInitialFit by didInitialFitState
    // 「顯示全頁」等整頁縮放（與捏合不同：捏合看某個區域，這個看整頁）。
    // 倍率與 Apple 端的 `PageViewportLayout.zoomScale` 同一套算法。
    val canvasDensityForFit = LocalDensity.current.density
    fun fitCanvas(mode: String) {
        val vw = canvasViewport.width
        val vh = canvasViewport.height
        if (vw <= 1f || vh <= 1f) return
        val cw = PageGeometry.width * canvasDensityForFit
        val ch = PageGeometry.height * canvasDensityForFit
        val raw = when (mode) {
            "page" -> minOf(vw / cw, vh / ch)
            "width" -> minOf(2f, vw / cw)
            else -> 1f
        }
        val scale = uniffi.padnote_core.clampZoom(raw)
        canvasScale = scale
        // 比視窗小就置中；比視窗大就貼齊左上角（可捲動）。
        canvasOffset = Offset(
            if (cw * scale < vw) (vw - cw * scale) / 2f else 0f,
            if (mode == "page" && ch * scale < vh) (vh - ch * scale) / 2f else 0f
        )
    }
    canvasInfo.viewport = canvasViewport
    canvasInfo.scale = canvasScale
    canvasInfo.offset = canvasOffset
    // 這一格畫面有多寬，決定側欄要並排還是覆蓋。**用實際寬度算**，
    // 不是查尺寸級別的表：摺疊機與分割視窗的寬度是連續變化的。
    val configuration = LocalConfiguration.current
    val layout = remember(configuration.screenWidthDp) {
        uniffi.padnote_core.layoutMetrics(configuration.screenWidthDp.toFloat())
    }
    // 折疊機的鉸鏈在哪（S-77）。Configuration 給得出寬度，給不出「畫面
    // 中間橫著一條摺痕」—— 而內容壓在摺痕上是折疊機最明顯的毛病。
    val posture = rememberFoldPosture(activity)
    val isTabletopActive = posture.separatingHorizontally || isTabletopManual

    val ctx = remember { EditorCanvasContext() }
    ctx.sessionRevisionState = sessionRevisionState
    ctx.openMarkIdState = openMarkIdState
    ctx.showRevertConfirmState = showRevertConfirmState
    ctx.pageCountState = pageCountState
    ctx.pageIndexState = pageIndexState
    ctx.continuousScrollRequestState = continuousScrollRequestState
    ctx.pageDisplayModeState = pageDisplayModeState
    ctx.recordingState = recordingState
    ctx.recordingPausedState = recordingPausedState
    ctx.recordSecondsState = recordSecondsState
    ctx.backlogUsState = backlogUsState
    ctx.messageState = messageState
    ctx.docsAssetState = docsAssetState
    ctx.textRevisionState = textRevisionState
    ctx.selectedTextIdState = selectedTextIdState
    ctx.editingTextState = editingTextState
    ctx.chartRevisionState = chartRevisionState
    ctx.selectedChartIdState = selectedChartIdState
    ctx.editingChartState = editingChartState
    ctx.insertingChartState = insertingChartState
    ctx.tableRevisionState = tableRevisionState
    ctx.selectedTableIdState = selectedTableIdState
    ctx.editingTableState = editingTableState
    ctx.editingShapeState = editingShapeState
    ctx.selectedConnectionIdState = selectedConnectionIdState
    ctx.editingConnectionState = editingConnectionState
    ctx.connectionDraftState = connectionDraftState
    ctx.insertingTableState = insertingTableState
    ctx.editorModeState = editorModeState
    ctx.snapToGridState = snapToGridState
    ctx.showProColorWheelState = showProColorWheelState
    ctx.minimalistCanvasModeState = minimalistCanvasModeState
    ctx.floatingPillExpandedState = floatingPillExpandedState
    ctx.strokeStabilizerState = strokeStabilizerState
    ctx.showSymmetryGuideState = showSymmetryGuideState
    ctx.showRadialMenuState = showRadialMenuState
    ctx.radialMenuCenterState = radialMenuCenterState
    ctx.magneticGuideActiveState = magneticGuideActiveState
    ctx.magneticGuideStartState = magneticGuideStartState
    ctx.magneticGuideEndState = magneticGuideEndState
    ctx.stackRevisionState = stackRevisionState
    ctx.showStackPanelState = showStackPanelState
    ctx.showCalculatorState = showCalculatorState
    ctx.showProColorsState = showProColorsState
    ctx.pinsState = pinsState
    ctx.isPlacingCommentPinState = isPlacingCommentPinState
    ctx.isRecognisingHandwritingState = isRecognisingHandwritingState
    ctx.pinRevisionState = pinRevisionState
    ctx.openPinState = openPinState
    ctx.models3DState = models3DState
    ctx.model3DRevisionState = model3DRevisionState
    ctx.linksState = linksState
    ctx.linkRevisionState = linkRevisionState
    ctx.selectedLinkIdState = selectedLinkIdState
    ctx.insertingLinkState = insertingLinkState
    ctx.editingLinkState = editingLinkState
    ctx.audioCardsState = audioCardsState
    ctx.audioRevisionState = audioRevisionState
    ctx.selectedAudioIdState = selectedAudioIdState
    ctx.playingAudioIdState = playingAudioIdState
    ctx.insertingAudioState = insertingAudioState
    ctx.marqueeActiveState = marqueeActiveState
    ctx.marqueeSelectionState = marqueeSelectionState
    ctx.marqueeAdditiveState = marqueeAdditiveState
    ctx.objectClipboardState = objectClipboardState
    ctx.isPlacingPasteObjectState = isPlacingPasteObjectState
    ctx.renamingAudioState = renamingAudioState
    ctx.selectedModel3DIdState = selectedModel3DIdState
    ctx.editingModel3DState = editingModel3DState
    ctx.insertingModel3DState = insertingModel3DState
    ctx.imageRevisionState = imageRevisionState
    ctx.selectedImageIdState = selectedImageIdState
    ctx.editingImageState = editingImageState
    ctx.pendingSaveBytesState = pendingSaveBytesState
    ctx.pdfToInsertState = pdfToInsertState
    ctx.importedDocumentState = importedDocumentState
    ctx.shapeRevisionState = shapeRevisionState
    ctx.selectedShapeIdsState = selectedShapeIdsState
    ctx.insertingShapeState = insertingShapeState
    ctx.showLayerPanelState = showLayerPanelState
    ctx.lockRevisionState = lockRevisionState
    ctx.lockPromptIdState = lockPromptIdState
    ctx.knownObjectIdsState = knownObjectIdsState
    ctx.micBlockedState = micBlockedState
    ctx.penOnlyState = penOnlyState
    ctx.lowLatencyState = lowLatencyState
    ctx.showPalmThresholdsState = showPalmThresholdsState
    ctx.pendingExportState = pendingExportState
    ctx.palmTunedState = palmTunedState
    ctx.showPenSettingsState = showPenSettingsState
    ctx.penTunedState = penTunedState
    ctx.lowLatencyUnavailableState = lowLatencyUnavailableState
    ctx.revisionState = revisionState
    ctx.continuousContentRevisionState = continuousContentRevisionState
    ctx.clearTokenState = clearTokenState
    ctx.renamingCurrentState = renamingCurrentState
    ctx.transferringPageState = transferringPageState
    ctx.showSymbolPickerState = showSymbolPickerState
    ctx.isRestoringHistoryState = isRestoringHistoryState
    ctx.inkToolState = inkToolState
    ctx.lastBrushToolState = lastBrushToolState
    ctx.penHeldToolState = penHeldToolState
    ctx.isImageDropTargetedState = isImageDropTargetedState
    ctx.isTabletopManualState = isTabletopManualState
    ctx.isMagneticSnapActiveState = isMagneticSnapActiveState
    ctx.inkColorHexState = inkColorHexState
    ctx.inkWidthState = inkWidthState
    ctx.showSolidStudioState = showSolidStudioState
    ctx.showDraftingToolboxState = showDraftingToolboxState
    ctx.showStatusState = showStatusState
    ctx.showInkDebugState = showInkDebugState
    ctx.deletingPageState = deletingPageState
    ctx.showRefineBarState = showRefineBarState
    ctx.showThemeToolsState = showThemeToolsState
    ctx.showStickerLibraryState = showStickerLibraryState
    ctx.showToolbarCustomizationState = showToolbarCustomizationState
    ctx.showAssetLibraryState = showAssetLibraryState
    ctx.showCollaborationState = showCollaborationState
    ctx.showSampleReadOnlyAlertState = showSampleReadOnlyAlertState
    ctx.showLanguagePickerState = showLanguagePickerState
    ctx.showNoteIntelligenceState = showNoteIntelligenceState
    ctx.collabBaseRoomState = collabBaseRoomState
    ctx.collabLastStateRequestState = collabLastStateRequestState
    ctx.collabTextRevisionState = collabTextRevisionState
    ctx.goldenSpiralState = goldenSpiralState
    ctx.ruleOfThirdsState = ruleOfThirdsState
    ctx.refineRevisionState = refineRevisionState
    ctx.showMenuState = showMenuState
    ctx.showPageSidebarState = showPageSidebarState
    ctx.canvasScaleState = canvasScaleState
    ctx.canvasOffsetState = canvasOffsetState
    ctx.canvasViewportState = canvasViewportState
    ctx.didInitialFitState = didInitialFitState
    ctx.activity = activity
    ctx.l10n = l10n
    ctx.notebook = notebook
    ctx.pageId = pageId
    ctx.engine = engine
    ctx.lasso = lasso
    ctx.continuousLasso = continuousLasso
    ctx.latency = latency
    ctx.audio = audio
    ctx.scope = scope
    ctx.textStore = textStore
    ctx.chartStore = chartStore
    ctx.tableStore = tableStore
    ctx.maskingTapes = maskingTapes
    ctx.contextualState = contextualState
    ctx.effectiveToolbarMode = effectiveToolbarMode
    ctx.meta = meta
    ctx.audioDirectory = audioDirectory
    ctx.insertAudioCard = insertAudioCard
    ctx.audioImportPicker = audioImportPicker
    ctx.imageStore = imageStore
    ctx.saveAsPicker = saveAsPicker
    ctx.imageMimeTypes = imageMimeTypes
    ctx.audioMimeTypes = audioMimeTypes
    ctx.photoPicker = photoPicker
    ctx.imagePicker = imagePicker
    ctx.pasteClipboardImageOrScreenshot = pasteClipboardImageOrScreenshot
    ctx.pdfMimeTypes = pdfMimeTypes
    ctx.documentMimeTypes = documentMimeTypes
    ctx.documentPicker = documentPicker
    ctx.pdfPicker = pdfPicker
    ctx.shapeStore = shapeStore
    ctx.stackItems = stackItems
    ctx.marqueeCandidates = marqueeCandidates
    ctx.marqueeCandidatesLatest = marqueeCandidatesLatest
    ctx.stackOrder = stackOrder
    ctx.stackOrderLatest = stackOrderLatest
    ctx.underInkIds = underInkIds
    ctx.kindOf = kindOf
    ctx.zIndexOf = zIndexOf
    ctx.lockedIds = lockedIds
    ctx.lockedIdsLatest = lockedIdsLatest
    ctx.objectLock = objectLock
    ctx.objectReorder = objectReorder
    ctx.currentSelectedObjectIds = currentSelectedObjectIds
    ctx.applySinglePageClipboardSelection = applySinglePageClipboardSelection
    ctx.pasteSinglePageClipboard = pasteSinglePageClipboard
    ctx.objectClipboardActions = objectClipboardActions
    ctx.backupPicker = backupPicker
    ctx.editorBackupCreatePicker = editorBackupCreatePicker
    ctx.folderPicker = folderPicker
    ctx.micPermission = micPermission
    ctx.exportNow = exportNow
    ctx.printNow = printNow
    ctx.continuousUndo = continuousUndo
    ctx.noteTitle = noteTitle
    ctx.collaboration = collaboration
    ctx.collab = collab
    ctx.continuousCollab = continuousCollab
    ctx.collabActive = collabActive
    ctx.layout = layout
    ctx.posture = posture
    ctx.isTabletopActive = isTabletopActive
    ctx.onOpenNotebook = onOpenNotebook
    ctx.notebookId = notebookId
    ctx.globalUndo = { globalUndo() }
    ctx.globalRedo = { globalRedo() }
    ctx.fitCanvas = { mode -> fitCanvas(mode) }
    ctx.applyInkTool = { picked -> applyInkTool(picked) }
    ctx.switchToPage = { target -> switchToPage(target) }
    ctx.selectText = { id -> selectText(id) }
    ctx.selectImage = { id -> selectImage(id) }
    ctx.clearSelection = { clearSelection() }
    ctx.moveMarqueeSelection = { dx, dy -> moveMarqueeSelection(dx, dy) }
    ctx.deleteMarqueeSelection = { deleteMarqueeSelection() }
    ctx.duplicateMarqueeSelection = { duplicateMarqueeSelection() }
    ctx.movePage = { from, to -> movePage(from, to) }
    ctx.duplicatePage = { index -> duplicatePage(index) }
    ctx.insertPageAfter = { afterIndex, paperId -> insertPageAfter(afterIndex, paperId) }
    ctx.importPdfAsPages = { file, progress -> importPdfAsPages(file, progress) }
    ctx.deletePageAt = { atIndex -> deletePageAt(atIndex) }
    ctx.canvasSnapshot = { canvasSnapshot() }
    ctx.applyCanvasSnapshot = { snap -> applyCanvasSnapshot(snap) }
    ctx.collabCanvas = { collabCanvas() }
    ctx.collabEngineFor = { page -> collabEngineFor(page) }
    ctx.publishCollab = { publishCollab() }
    ctx.releaseSelection = { id -> releaseSelection(id) }
    ctx.applyCollabOp = { op -> applyCollabOp(op) }
    return ctx
}

/**
 * 把格式套在畫布上選中的文字方塊（整個方塊）。頂端格式列與飛梭工具盤的螢光筆共用這一條。
 *
 * 頂端格式列在拆檔（EditorTopBar／EditorCanvasContainer）時漏接了 `onFormatAction`，
 * 落回預設的 `{}` —— 整排粗體、斜體、醒目提示按了都沒反應。回傳 false 表示沒有選中的方塊。
 */
internal fun EditorCanvasContext.applyFormatToSelectedText(action: com.kairumo.padnote.text.WordFormatAction): Boolean {
    val box = selectedTextId?.let { textStore.find(it) } ?: return false
    com.kairumo.padnote.text.applyWordFormat(box, action, com.kairumo.padnote.text.TextFormatScope.WholeBox)
    textStore.persist(box)
    textRevision++
    return true
}

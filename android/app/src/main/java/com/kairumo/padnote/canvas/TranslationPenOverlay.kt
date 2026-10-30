package com.kairumo.padnote.canvas

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.speech.tts.TextToSpeech
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.account.AccountManager
import com.kairumo.padnote.audio.TranscriptTranslator
import com.kairumo.padnote.comment.CommentMessage
import com.kairumo.padnote.comment.CommentPin
import com.kairumo.padnote.currentLanguageTag
import com.kairumo.padnote.deviceId
import com.kairumo.padnote.image.LinkObject
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.library.NotebookMeta
import com.kairumo.padnote.library.TranslationPenConfig
import com.kairumo.padnote.platform.Handwriting
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.sync.AutoSync
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.text.TextBoxStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.FfiScanAnalysis
import uniffi.padnote_core.FfiScanKind
import uniffi.padnote_core.FfiTranslationLangInfo
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.translationPenAnalyzeScan
import uniffi.padnote_core.translationPenDefaultConfig
import uniffi.padnote_core.translationPenFormatPinMessage
import uniffi.padnote_core.translationPenLanguages
import uniffi.padnote_core.translationPenStitchLines
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * 雙語 TTS 發音合成器（供掃描翻譯筆原音／慢速跟讀使用）。
 */
// profile-scope: device 系統語音合成器是整台裝置共用硬體資源，不含使用者個人資料
object TranslationPenSpeech {
    private var tts: TextToSpeech? = null
    private var ready: Boolean = false

    fun speak(context: Context, text: String, langCode: String, slow: Boolean) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        val engine = tts
        if (engine != null && ready) {
            playNow(engine, trimmed, langCode, slow)
            return
        }
        val appCtx = context.applicationContext
        var created: TextToSpeech? = null
        created = TextToSpeech(appCtx) { status ->
            if (status == TextToSpeech.SUCCESS) {
                ready = true
                created?.let { playNow(it, trimmed, langCode, slow) }
            }
        }
        tts = created
    }

    fun stop() {
        runCatching { tts?.stop() }
    }

    private fun playNow(engine: TextToSpeech, text: String, langCode: String, slow: Boolean) {
        runCatching {
            val matchedLocale = translationPenLanguages()
                .firstOrNull { it.tag.equals(langCode, ignoreCase = true) }
                ?.ttsLocale
                ?: langCode
            val locale = Locale.forLanguageTag(matchedLocale)
            engine.language = locale
            engine.setSpeechRate(if (slow) 0.72f else 1.0f)
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "trans_pen_tts")
        }
    }
}

/**
 * 掃描翻譯筆覆蓋層（Android）。
 *
 * 對應 Apple 端的 `TranslationPenOverlayView`：
 * 1. 首次在該筆記本啟動掃描翻譯筆時，自動彈出「目標掃描語系 & 輸出語系」選擇視窗；
 *    畫布頂端常駐語系膠囊，支援一鍵雙向對調（`⇄`）與跨行連掃開關。
 * 2. 筆尖或手指劃過一段文字或單字時，優先零延遲擷取畫布結構化文字（文字方塊、表格、形狀、連結），
 *    若無則擷取該區域手寫筆跡執行裝置端手寫辨識（ML Kit Digital Ink）或讀取該頁已辨識文字。
 * 3. 掃描放開後立即快顯懸浮翻譯卡：
 *    - 單字／片語／整句智慧分流（核心 `translationPenAnalyzeScan`）與字根詞綴提示、系統字典查閱
 *    - 雙語發音朗讀（`TranslationPenSpeech`）與原速／慢速跟讀切換
 *    - 跨行連掃自動拼接（核心 `translationPenStitchLines` 自動消除連字號斷詞並重譯）
 *    - 可直接編輯原文、修改翻譯結果、加入學習筆記
 *    - 一鍵轉為討論圖釘（`CommentPin`）、插入獨立文字方塊（`TextBox`）、
 *      一鍵螢光標記（`InkEngine.insertHighlightBeam`）、一鍵轉遮蔽膠帶（`NoteTape`）、複製或取消關閉。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TranslationPenOverlay(
    isActive: Boolean,
    pageIndex: Int,
    pageId: String?,
    density: Float,
    session: PadnoteSession?,
    engine: InkEngine,
    textStore: TextBoxStore,
    tableStore: TableStore,
    shapeStore: ShapeStore,
    links: List<LinkObject>,
    maskingTapes: MutableList<NoteTape>,
    pins: MutableList<CommentPin>,
    onChanged: () -> Unit,
    onShowMessage: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (!isActive) return

    val context = LocalContext.current
    val uiLang = currentLanguageTag()
    val scope = rememberCoroutineScope()
    fun l10n(key: String) = LocalizationStrings.localized(key, uiLang)

    val supportedLangs = remember { translationPenLanguages() }
    var config by remember(session) {
        val loaded = session?.let { NotebookMeta.load(it).translationPenConfig() }
        if (loaded != null) {
            mutableStateOf(loaded)
        } else {
            val def = translationPenDefaultConfig(uiLang)
            mutableStateOf(
                TranslationPenConfig(
                    sourceLang = def.sourceLang,
                    targetLang = def.targetLang,
                    multiLineStitch = def.multiLineStitch,
                    slowTts = def.slowTts,
                    configured = def.configured
                )
            )
        }
    }

    var showSetupDialog by remember { mutableStateOf(false) }
    var dragStartPx by remember { mutableStateOf<Offset?>(null) }
    var dragCurrentPx by remember { mutableStateOf<Offset?>(null) }
    var lastScanRectPage by remember { mutableStateOf<Rect?>(null) }
    var viewportSize by remember { mutableStateOf(IntSize.Zero) }

    var showPopover by remember { mutableStateOf(false) }
    var isScanning by remember { mutableStateOf(false) }
    var isTranslating by remember { mutableStateOf(false) }
    var isDownloadingModel by remember { mutableStateOf(false) }
    var sourceText by remember { mutableStateOf("") }
    var translatedText by remember { mutableStateOf("") }
    var noteText by remember { mutableStateOf("") }
    var scanAnalysis by remember { mutableStateOf<FfiScanAnalysis?>(null) }
    var statusError by remember { mutableStateOf<String?>(null) }

    fun saveConfig(updated: TranslationPenConfig) {
        config = updated
        if (session != null) {
            val meta = NotebookMeta.load(session)
            meta.setTranslationPenConfig(session, updated)
            AutoSync.noteLocalEdit(context)
        }
    }

    fun langShortName(code: String): String =
        supportedLangs.firstOrNull { it.tag == code }?.shortLabel ?: code.uppercase()

    fun langDisplayName(info: FfiTranslationLangInfo): String =
        "${info.endonym} (${info.shortLabel})"

    suspend fun translateNow(
        rawText: String,
        srcLang: String,
        tgtLang: String,
        forceManualRetranslate: Boolean = false
    ) {
        val cleaned = rawText.trim()
        if (cleaned.isEmpty()) {
            translatedText = ""
            scanAnalysis = null
            return
        }
        val analysis = translationPenAnalyzeScan(cleaned, srcLang)
        scanAnalysis = analysis
        sourceText = analysis.cleanedText

        // 當目標文字模糊、雜訊過高或系統難以判斷時，立即顯示快顯說明，絕不胡亂編造輸出語言
        if (!forceManualRetranslate && analysis.isLowConfidence) {
            isTranslating = false
            translatedText = ""
            statusError = l10n("trans_pen_blurry_warning")
            return
        }

        isTranslating = true
        statusError = null

        val result = withContext(Dispatchers.IO) {
            var res = TranscriptTranslator.finalize(listOf(analysis.cleanedText), srcLang, tgtLang)
            if (res.error == "model_missing") {
                withContext(Dispatchers.Main) { isDownloadingModel = true }
                val downloaded = runCatching { TranscriptTranslator.download(srcLang, tgtLang) }.isSuccess
                withContext(Dispatchers.Main) { isDownloadingModel = false }
                if (downloaded) {
                    res = TranscriptTranslator.finalize(listOf(analysis.cleanedText), srcLang, tgtLang)
                }
            }
            res
        }
        isTranslating = false
        translatedText = if (result.error == null) {
            result.texts.firstOrNull().orEmpty()
        } else {
            ""
        }
        statusError = result.error
    }

    fun extractStructuredText(scanRectPage: Rect): String? {
        val pieces = mutableListOf<String>()

        for (box in textStore.all) {
            if (box.pageIndex != pageIndex) continue
            val boxRect = Rect(box.x, box.y, box.x + box.width, box.y + box.height)
            if (boxRect.overlaps(scanRectPage)) {
                val trimmed = box.text.trim()
                if (trimmed.isNotEmpty()) {
                    val lines = trimmed.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
                    if (lines.size > 1 && box.height > 28f) {
                        val relMidY = ((scanRectPage.center.y - box.y) / max(1f, box.height)).coerceIn(0f, 0.99f)
                        val idx = (relMidY * lines.size).toInt().coerceIn(0, lines.size - 1)
                        pieces.add(lines[idx])
                    } else {
                        pieces.add(trimmed)
                    }
                }
            }
        }

        for (table in tableStore.all) {
            val tableRect = Rect(table.x, table.y, table.x + table.width, table.y + table.height)
            if (tableRect.overlaps(scanRectPage)) {
                val nonEmpty = table.cells.map { it.trim() }.filter { it.isNotEmpty() }
                if (nonEmpty.isNotEmpty()) {
                    pieces.add(nonEmpty.joinToString(" "))
                }
            }
        }

        for (shape in shapeStore.all) {
            val shapeRect = Rect(shape.x, shape.y, shape.x + shape.width, shape.y + shape.height)
            if (shapeRect.overlaps(scanRectPage)) {
                val trimmed = shape.label.trim()
                if (trimmed.isNotEmpty()) {
                    pieces.add(trimmed)
                }
            }
        }

        for (link in links) {
            if (link.pageIndex != pageIndex) continue
            val linkRect = Rect(link.x, link.y, link.x + link.width, link.y + link.height)
            if (linkRect.overlaps(scanRectPage)) {
                val combined = listOf(link.title, link.descriptionText)
                    .map { it.trim() }
                    .filter { it.isNotEmpty() }
                    .joinToString(" — ")
                if (combined.isNotEmpty()) {
                    pieces.add(combined)
                }
            }
        }

        if (pieces.isEmpty()) return null
        return pieces.joinToString(" ")
    }

    fun handleScanRectCompleted(scanRectPage: Rect) {
        lastScanRectPage = scanRectPage
        scope.launch {
            isScanning = true
            statusError = null

            var extracted = extractStructuredText(scanRectPage)
            var hadHandwritingStrokes = false
            var handwritingFailed = false
            if (extracted.isNullOrBlank()) {
                val expanded = scanRectPage.inflate(10f)
                val matchingStrokes = engine.strokes.filter { stroke ->
                    stroke.points.any { pt -> expanded.contains(Offset(pt.x, pt.y)) }
                }.map { it.points }

                if (matchingStrokes.isNotEmpty()) {
                    hadHandwritingStrokes = true
                    val hwrRes = withContext(Dispatchers.IO) {
                        Handwriting.recognize(matchingStrokes, config.sourceLang)
                    }
                    if (hwrRes.isFailure) {
                        handwritingFailed = true
                    }
                    extracted = hwrRes.getOrNull()?.trim()
                }
            }

            isScanning = false
            val finalPiece = extracted?.trim().orEmpty()
            if (finalPiece.isEmpty()) {
                val warningMsg = if (hadHandwritingStrokes || handwritingFailed) {
                    l10n("trans_pen_blurry_warning")
                } else {
                    l10n("trans_pen_empty_scan")
                }
                if (!showPopover) {
                    sourceText = ""
                    translatedText = ""
                    scanAnalysis = null
                    statusError = warningMsg
                    showPopover = true
                } else {
                    statusError = warningMsg
                }
                return@launch
            }

            val updatedSource = if (config.multiLineStitch && showPopover && sourceText.trim().isNotEmpty()) {
                translationPenStitchLines(sourceText, finalPiece, config.sourceLang)
            } else {
                finalPiece
            }
            sourceText = updatedSource
            showPopover = true
            translateNow(updatedSource, config.sourceLang, config.targetLang)
        }
    }

    LaunchedEffect(isActive, config.configured) {
        if (isActive && !config.configured) {
            showSetupDialog = true
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .onSizeChanged { viewportSize = it }
    ) {
        // 0. 專屬背景手勢接收層（不攔截頂端語系膠囊與懸浮快顯卡內的按鈕／輸入框）
        Box(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(pageIndex, density, config) {
                    detectDragGestures(
                        onDragStart = { startOffset ->
                            dragStartPx = startOffset
                            dragCurrentPx = startOffset
                        },
                        onDrag = { change, _ ->
                            change.consume()
                            dragCurrentPx = change.position
                        },
                        onDragCancel = {
                            dragStartPx = null
                            dragCurrentPx = null
                        },
                        onDragEnd = {
                            val s = dragStartPx
                            val e = dragCurrentPx
                            dragStartPx = null
                            dragCurrentPx = null
                            if (s != null && e != null) {
                                val minX = min(s.x, e.x) / density
                                val minY = min(s.y, e.y) / density
                                val rawW = abs(e.x - s.x) / density
                                val rawH = abs(e.y - s.y) / density
                                if (rawW >= 8f || rawH >= 8f) {
                                    val w = max(rawW, 36f)
                                    val h = max(rawH, 26f)
                                    val adjY = if (rawH < 26f) minY - (26f - rawH) / 2f else minY
                                    handleScanRectCompleted(Rect(minX, adjY, minX + w, adjY + h))
                                }
                            }
                        }
                    )
                }
        )

        // 1. 掃描光束即時框選預覽
        val sPx = dragStartPx
        val ePx = dragCurrentPx
        val activeRectPage = lastScanRectPage
        if ((sPx != null && ePx != null) || (showPopover && activeRectPage != null)) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val rectPx = if (sPx != null && ePx != null) {
                    val left = min(sPx.x, ePx.x)
                    val top = min(sPx.y, ePx.y)
                    val w = max(abs(ePx.x - sPx.x), 24.dp.toPx())
                    val h = max(abs(ePx.y - sPx.y), 24.dp.toPx())
                    val adjTop = if (abs(ePx.y - sPx.y) < 24.dp.toPx()) top - (24.dp.toPx() - abs(ePx.y - sPx.y)) / 2f else top
                    Rect(left, adjTop, left + w, adjTop + h)
                } else if (activeRectPage != null) {
                    Rect(
                        activeRectPage.left * density,
                        activeRectPage.top * density,
                        activeRectPage.right * density,
                        activeRectPage.bottom * density
                    )
                } else null

                if (rectPx != null) {
                    drawRoundRect(
                        color = Color(0xFF14B8A6).copy(alpha = 0.20f),
                        topLeft = rectPx.topLeft,
                        size = Size(rectPx.width, rectPx.height),
                        cornerRadius = CornerRadius(6.dp.toPx(), 6.dp.toPx())
                    )
                    drawRoundRect(
                        color = Color(0xFF0D9488),
                        topLeft = rectPx.topLeft,
                        size = Size(rectPx.width, rectPx.height),
                        cornerRadius = CornerRadius(6.dp.toPx(), 6.dp.toPx()),
                        style = Stroke(
                            width = 2.dp.toPx(),
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 8f))
                        )
                    )
                    val midY = rectPx.center.y
                    drawLine(
                        color = Color(0xFF14B8A6).copy(alpha = 0.7f),
                        start = Offset(rectPx.left + 4.dp.toPx(), midY),
                        end = Offset(rectPx.right - 4.dp.toPx(), midY),
                        strokeWidth = 1.5.dp.toPx()
                    )
                }
            }
        }

        // 2. 頂端常駐語系膠囊與跨行連掃開關
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
            tonalElevation = 4.dp,
            shadowElevation = 4.dp,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 10.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier
                        .testTag("editor.translationPen.languagePill")
                        .clickable { showSetupDialog = true }
                        .padding(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text("🌐", fontSize = 13.sp)
                    Text(
                        text = "${langShortName(config.sourceLang)} → ${langShortName(config.targetLang)} ▾",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                Text(
                    text = "⇄",
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .testTag("editor.translationPen.swapLanguages")
                        .clickable {
                            val swapped = config.copy(
                                sourceLang = config.targetLang,
                                targetLang = config.sourceLang,
                                configured = true
                            )
                            saveConfig(swapped)
                            if (showPopover && sourceText.isNotBlank()) {
                                scope.launch {
                                    translateNow(sourceText, swapped.sourceLang, swapped.targetLang)
                                }
                            }
                        }
                        .padding(horizontal = 4.dp, vertical = 2.dp)
                )

                Text(
                    text = if (config.multiLineStitch) l10n("trans_pen_stitch_active") else l10n("trans_pen_stitch_off"),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (config.multiLineStitch) Color(0xFF0D9488) else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .testTag("editor.translationPen.stitchToggle")
                        .background(
                            if (config.multiLineStitch) Color(0xFF14B8A6).copy(alpha = 0.15f)
                            else Color.Transparent,
                            CircleShape
                        )
                        .clickable {
                            saveConfig(config.copy(multiLineStitch = !config.multiLineStitch, configured = true))
                        }
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                )

                if (!showPopover) {
                    Text(
                        text = l10n("trans_pen_drag_hint"),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // 3. 掃描結果懸浮快顯卡
        if (showPopover) {
            val scanRect = lastScanRectPage ?: Rect(80f, 120f, 320f, 160f)
            val cardWidthPx = min(viewportSize.width - 24, (400 * density).toInt()).coerceAtLeast(280)
            val rawX = (scanRect.left * density).toInt()
            val clampedX = rawX.coerceIn(12, max(12, viewportSize.width - cardWidthPx - 12))
            val belowY = (scanRect.bottom * density + 12f * density).toInt()
            val clampedY = if (belowY + (290 * density).toInt() > viewportSize.height && viewportSize.height > 360) {
                max(54, (scanRect.top * density - 270f * density).toInt())
            } else {
                max(54, belowY)
            }

            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 8.dp,
                shadowElevation = 10.dp,
                modifier = Modifier
                    .offset { IntOffset(clampedX, clampedY) }
                    .width(380.dp)
                    .border(1.dp, Color(0xFF14B8A6).copy(alpha = 0.35f), RoundedCornerShape(16.dp))
                    .testTag("editor.translationPen.popover")
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(14.dp)
                ) {
                    // 標題列：單字/片語/整句智慧分流標籤 + 語速切換 + 系統字典 + 關閉
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        val badgeKey = when (scanAnalysis?.kind) {
                            FfiScanKind.WORD -> "trans_pen_kind_word"
                            FfiScanKind.PHRASE -> "trans_pen_kind_phrase"
                            FfiScanKind.SENTENCE, null -> "trans_pen_kind_sentence"
                        }
                        Text(
                            text = l10n(badgeKey),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .background(Color(0xFF0D9488), CircleShape)
                                .padding(horizontal = 8.dp, vertical = 3.dp)
                        )

                        val grammarKey = scanAnalysis?.grammarHintKey
                        if (!grammarKey.isNullOrEmpty()) {
                            Text(
                                text = l10n(grammarKey),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        val stem = scanAnalysis?.phoneticOrStemHint
                        if (!stem.isNullOrEmpty()) {
                            Text(
                                text = stem,
                                style = MaterialTheme.typography.labelSmall,
                                fontFamily = FontFamily.Monospace,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        Spacer(modifier = Modifier.weight(1f))

                        // 3-1 語速切換（1.0x 原速 / 0.72x 慢速跟讀）
                        Text(
                            text = "🐢 ${if (config.slowTts) l10n("trans_pen_slow_tts") else l10n("trans_pen_normal_tts")}",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (config.slowTts) Color(0xFFD97706) else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier
                                .background(
                                    if (config.slowTts) Color(0xFFF59E0B).copy(alpha = 0.16f) else Color.Transparent,
                                    CircleShape
                                )
                                .clickable {
                                    saveConfig(config.copy(slowTts = !config.slowTts, configured = true))
                                }
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )

                        // 單字/片語時提供系統文字處理 / 字典查詢入口
                        if (scanAnalysis?.kind == FfiScanKind.WORD && sourceText.isNotBlank()) {
                            Text(
                                text = "📖 ${l10n("trans_pen_lookup_dict")}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier
                                    .clickable {
                                        runCatching {
                                            val intent = Intent(Intent.ACTION_WEB_SEARCH).apply {
                                                putExtra("query", "define ${sourceText.trim()}")
                                            }
                                            context.startActivity(intent)
                                        }
                                    }
                                    .padding(horizontal = 4.dp, vertical = 2.dp)
                            )
                        }

                        Text(
                            text = "✕",
                            fontSize = 15.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier
                                .testTag("editor.translationPen.closePopover")
                                .clickable {
                                    TranslationPenSpeech.stop()
                                    showPopover = false
                                    lastScanRectPage = null
                                }
                                .padding(4.dp)
                        )
                    }

                    if (isScanning || isTranslating || isDownloadingModel) {
                        Text(
                            text = l10n("trans_pen_scanning"),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color(0xFF0D9488)
                        )
                    }

                    val err = statusError
                    if (!err.isNullOrEmpty()) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = Color(0xFFF59E0B).copy(alpha = 0.14f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = "⚠️ $err",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFFB45309),
                                modifier = Modifier.padding(8.dp)
                            )
                        }
                    }

                    // 原文區（可編輯 + 發音 + 重新翻譯 + 清空連掃）
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = "${l10n("trans_pen_source_label")} (${langShortName(config.sourceLang)})",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "🔊 ${l10n("trans_pen_speak_source")}",
                                fontSize = 12.sp,
                                modifier = Modifier
                                    .clickable {
                                        TranslationPenSpeech.speak(
                                            context,
                                            sourceText,
                                            config.sourceLang,
                                            config.slowTts
                                        )
                                    }
                                    .padding(2.dp)
                            )
                            Spacer(modifier = Modifier.weight(1f))
                            if (config.multiLineStitch && sourceText.isNotEmpty()) {
                                Text(
                                    text = l10n("trans_pen_clear_stitch"),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier
                                        .clickable {
                                            sourceText = ""
                                            translatedText = ""
                                            scanAnalysis = null
                                            statusError = null
                                        }
                                        .padding(horizontal = 4.dp)
                                )
                            }
                            Text(
                                text = "↻ ${l10n("trans_pen_retranslate")}",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF0D9488),
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .clickable {
                                        scope.launch {
                                            translateNow(
                                                sourceText,
                                                config.sourceLang,
                                                config.targetLang,
                                                forceManualRetranslate = true
                                            )
                                        }
                                    }
                                    .padding(horizontal = 4.dp)
                            )
                        }
                        OutlinedTextField(
                            value = sourceText,
                            onValueChange = { sourceText = it },
                            maxLines = 3,
                            textStyle = MaterialTheme.typography.bodySmall,
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("editor.translationPen.sourceField")
                        )
                    }

                    // 譯文區（可編輯修正 + 發音）
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = "${l10n("trans_pen_target_label")} (${langShortName(config.targetLang)})",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "🔊 ${l10n("trans_pen_speak_target")}",
                                fontSize = 12.sp,
                                modifier = Modifier
                                    .clickable {
                                        TranslationPenSpeech.speak(
                                            context,
                                            translatedText,
                                            config.targetLang,
                                            config.slowTts
                                        )
                                    }
                                    .padding(2.dp)
                            )
                            Spacer(modifier = Modifier.weight(1f))
                        }
                        OutlinedTextField(
                            value = translatedText,
                            onValueChange = { translatedText = it },
                            maxLines = 3,
                            textStyle = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("editor.translationPen.translatedField")
                        )
                    }

                    // 補充筆記欄
                    OutlinedTextField(
                        value = noteText,
                        onValueChange = { noteText = it },
                        placeholder = {
                            Text(
                                text = l10n("trans_pen_note_placeholder"),
                                style = MaterialTheme.typography.labelSmall
                            )
                        },
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodySmall,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("editor.translationPen.noteField")
                    )

                    HorizontalDivider()

                    // 動作按鈕列：📌 圖釘 / 📝 註解方塊 / 🖍️ 螢光標記 / 🩹 遮蔽膠帶 / 📋 複製
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        // 📌 釘為討論圖釘
                        OutlinedButton(
                            onClick = {
                                val formatted = translationPenFormatPinMessage(
                                    sourceText = sourceText,
                                    translatedText = translatedText,
                                    note = noteText,
                                    sourceLang = config.sourceLang,
                                    targetLang = config.targetLang
                                )
                                if (formatted.isNotEmpty() && session != null) {
                                    val profile = AccountManager.load(context, l10n("default_user_name"))
                                    val now = Date()
                                    val pin = CommentPin(
                                        id = UUID.randomUUID().toString(),
                                        pageIndex = pageIndex,
                                        x = scanRect.right + 8f,
                                        y = max(16f, scanRect.top),
                                        authorId = deviceId(context).toString(),
                                        authorName = profile.displayName,
                                        authorColor = profile.colorHex,
                                        createdAt = now,
                                        isResolved = false,
                                        messages = mutableListOf(
                                            CommentMessage(
                                                id = UUID.randomUUID().toString(),
                                                authorId = deviceId(context).toString(),
                                                authorName = profile.displayName,
                                                authorColor = profile.colorHex,
                                                text = formatted,
                                                createdAt = now
                                            )
                                        )
                                    )
                                    pins.add(pin)
                                    NotebookMeta.load(session).setCommentPins(session, pins)
                                    AutoSync.noteLocalEdit(context)
                                    onChanged()
                                    onShowMessage(l10n("trans_pen_action_pin"))
                                    showPopover = false
                                }
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier.height(30.dp).testTag("editor.translationPen.actionPin")
                        ) {
                            Text("📌 ${l10n("trans_pen_action_pin")}", fontSize = 11.sp)
                        }

                        // 📝 插入為文字方塊註解
                        OutlinedButton(
                            onClick = {
                                val formatted = translationPenFormatPinMessage(
                                    sourceText = sourceText,
                                    translatedText = translatedText,
                                    note = noteText,
                                    sourceLang = config.sourceLang,
                                    targetLang = config.targetLang
                                )
                                if (formatted.isNotEmpty()) {
                                    val box = textStore.create(
                                        max(20f, scanRect.left),
                                        scanRect.bottom + 8f
                                    )
                                    box.text = formatted
                                    box.fontSize = 14f
                                    box.width = max(220f, min(320f, scanRect.width + 60f))
                                    box.height = 88f
                                    box.backgroundColorHex = "#F0FDFA"
                                    box.borderColorHex = "#14B8A6"
                                    box.hasBorder = true
                                    textStore.persist(box)
                                    if (session != null) {
                                        val meta = NotebookMeta.load(session)
                                        val updatedOrder = ObjectStacking.bringToFront(
                                            setOf(box.id),
                                            meta.objectOrder(pageIndex)
                                        )
                                        meta.setObjectOrder(session, pageIndex, updatedOrder)
                                        AutoSync.noteLocalEdit(context)
                                    }
                                    onChanged()
                                    onShowMessage(l10n("trans_pen_action_textbox"))
                                    showPopover = false
                                }
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier.height(30.dp).testTag("editor.translationPen.actionTextBox")
                        ) {
                            Text("📝 ${l10n("trans_pen_action_textbox")}", fontSize = 11.sp)
                        }

                        // 🖍️ 一鍵螢光標記
                        OutlinedButton(
                            onClick = {
                                val rgba = byteArrayOf(
                                    0xFB.toByte(),
                                    0xBF.toByte(),
                                    0x24.toByte(),
                                    0x88.toByte()
                                )
                                engine.insertHighlightBeam(
                                    x1 = scanRect.left,
                                    x2 = scanRect.right,
                                    midY = scanRect.center.y,
                                    height = scanRect.height,
                                    colorRgba = rgba
                                )
                                AutoSync.noteLocalEdit(context)
                                onChanged()
                                onShowMessage(l10n("trans_pen_action_highlight"))
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier.height(30.dp).testTag("editor.translationPen.actionHighlight")
                        ) {
                            Text("🖍️ ${l10n("trans_pen_action_highlight")}", fontSize = 11.sp)
                        }

                        // 🩹 一鍵轉為遮蔽膠帶
                        OutlinedButton(
                            onClick = {
                                val tape = NoteTape(
                                    pageIndex = pageIndex,
                                    x = scanRect.left,
                                    y = scanRect.top,
                                    width = max(36f, scanRect.width),
                                    height = max(24f, scanRect.height),
                                    isRevealed = false,
                                    colorHex = "#FCEEAC"
                                )
                                maskingTapes.add(tape)
                                if (session != null) {
                                    val meta = NotebookMeta.load(session)
                                    val otherPages = meta.tapes().filter { it.pageIndex != pageIndex }
                                    meta.setTapes(session, otherPages + maskingTapes.filter { it.pageIndex == pageIndex })
                                    pageId?.let { pid ->
                                        NoteTapeCodec.writeEnvelopes(
                                            session,
                                            pid,
                                            maskingTapes.filter { it.pageIndex == pageIndex }
                                        )
                                    }
                                    AutoSync.noteLocalEdit(context)
                                }
                                onChanged()
                                onShowMessage(l10n("trans_pen_action_tape"))
                                showPopover = false
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier.height(30.dp).testTag("editor.translationPen.actionTape")
                        ) {
                            Text("🩹 ${l10n("trans_pen_action_tape")}", fontSize = 11.sp)
                        }

                        // 📋 複製
                        TextButton(
                            onClick = {
                                val formatted = translationPenFormatPinMessage(
                                    sourceText = sourceText,
                                    translatedText = translatedText,
                                    note = noteText,
                                    sourceLang = config.sourceLang,
                                    targetLang = config.targetLang
                                )
                                val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                                cm?.setPrimaryClip(ClipData.newPlainText("translation", formatted))
                                onShowMessage(l10n("trans_pen_action_copy"))
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier.height(30.dp).testTag("editor.translationPen.actionCopy")
                        ) {
                            Text("📋 ${l10n("trans_pen_action_copy")}", fontSize = 11.sp)
                        }
                    }
                }
            }
        }
    }

    // 4. 首次啟動與語系設定對話框
    if (showSetupDialog) {
        var draftSource by remember(config.sourceLang) { mutableStateOf(config.sourceLang) }
        var draftTarget by remember(config.targetLang) { mutableStateOf(config.targetLang) }
        var draftStitch by remember(config.multiLineStitch) { mutableStateOf(config.multiLineStitch) }
        var draftSlowTts by remember(config.slowTts) { mutableStateOf(config.slowTts) }

        AlertDialog(
            onDismissRequest = {
                saveConfig(config.copy(configured = true))
                showSetupDialog = false
            },
            title = { Text(l10n("trans_pen_setup_title")) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = l10n("trans_pen_setup_desc"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Text(
                        text = l10n("trans_pen_source_lang"),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        supportedLangs.forEach { lang ->
                            FilterChip(
                                selected = draftSource == lang.tag,
                                onClick = { draftSource = lang.tag },
                                label = { Text(langDisplayName(lang), fontSize = 12.sp) }
                            )
                        }
                    }

                    Row(
                        horizontalArrangement = Arrangement.Center,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedButton(
                            onClick = {
                                val tmp = draftSource
                                draftSource = draftTarget
                                draftTarget = tmp
                            },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                        ) {
                            Text("⇄ ${l10n("trans_pen_swap_lang")}", fontSize = 12.sp)
                        }
                    }

                    Text(
                        text = l10n("trans_pen_target_lang"),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        supportedLangs.forEach { lang ->
                            FilterChip(
                                selected = draftTarget == lang.tag,
                                onClick = { draftTarget = lang.tag },
                                label = { Text(langDisplayName(lang), fontSize = 12.sp) }
                            )
                        }
                    }

                    HorizontalDivider()

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = l10n("trans_pen_multiline_stitch"),
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = l10n("trans_pen_multiline_desc"),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = draftStitch,
                            onCheckedChange = { draftStitch = it }
                        )
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = l10n("trans_pen_slow_tts"),
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.weight(1f)
                        )
                        Switch(
                            checked = draftSlowTts,
                            onCheckedChange = { draftSlowTts = it }
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val updated = TranslationPenConfig(
                            sourceLang = draftSource,
                            targetLang = draftTarget,
                            multiLineStitch = draftStitch,
                            slowTts = draftSlowTts,
                            configured = true
                        )
                        saveConfig(updated)
                        showSetupDialog = false
                        if (showPopover && sourceText.isNotBlank()) {
                            scope.launch {
                                translateNow(sourceText, updated.sourceLang, updated.targetLang)
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0D9488)),
                    modifier = Modifier.testTag("editor.translationPen.confirmSetup")
                ) {
                    Text(l10n("trans_pen_start"))
                }
            }
        )
    }
}

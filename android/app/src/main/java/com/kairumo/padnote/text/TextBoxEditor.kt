package com.kairumo.padnote.text

import com.kairumo.padnote.ui.FloatingPanel
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Divider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.canvas.CanvasRotation
import uniffi.padnote_core.symbolCategories
import uniffi.padnote_core.symbolPalette

/**
 * 文字方塊的編輯面板（Android）。
 *
 * 控制項與分頁結構與 Apple 端的 `WordTextStudioView` 對齊：
 * 字體／段落／樣式／符號四頁。**改了就算數**，沒有確認按鈕。
 *
 * 分頁不是裝飾：原本是一條長 Column 塞進 AlertDialog，控制項一多就超出
 * 對話框高度被裁掉 —— 與 Apple 端浮動面板原本的毛病一模一樣。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TextBoxEditor(
    box: TextBox,
    languageTag: String,
    onReorder: ((com.kairumo.padnote.canvas.ObjectStacking.Reorder) -> Unit)? = null,
    /** 即時協同：別人改了這個方塊就遞增（`box` 已是寫回後的那一份）。 */
    remoteRevision: Int = 0,
    /** 即時協同：同時在這個方塊打字的人（顯示提示，不鎖 —— 兩邊的字都會留下）。 */
    typingPeerName: String? = null,
    onChanged: (TextBox) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var currentBox by remember(box.id) { mutableStateOf(box.copy()) }
    var text by remember(box.id) { mutableStateOf(box.text) }
    // 帶選取範圍的輸入值：Word 式的「選幾個字、按粗體」要知道選了哪幾個字。
    var field by remember(box.id) { mutableStateOf(TextFieldValue(box.text, TextRange(box.text.length))) }
    // 使用者有沒有點進過輸入框。**不用「目前有沒有焦點」**：字級、顏色的下拉選單是彈出視窗，
    // 一打開就把焦點從輸入框拿走 —— 等選單項目被按下時，選取範圍還在，焦點已經不在了，
    // 結果選了幾個字改字級，卻改到整個方塊。
    var fieldTouched by remember(box.id) { mutableStateOf(false) }
    // 只有游標時按了格式：留給接下來打的字（Word 的行為）。
    var caretStyle by remember(box.id) { mutableStateOf<Pair<Int, TextCharStyle>?>(null) }
    var revision by remember(box.id) { mutableStateOf(0) }
    var tab by remember(box.id) { mutableStateOf(0) }
    var symbolCategory by remember(box.id) { mutableStateOf(0) }

    LaunchedEffect(box) {
        currentBox = box.copy()
    }

    fun mutate(change: (TextBox) -> Unit) {
        val next = currentBox.copy()
        change(next)
        currentBox = next
        revision++
        onChanged(next.copy())
    }

    // 別人在同一個方塊打了字：換上新內容，游標跟著它原本旁邊的字走（變動在游標前面就平移）。
    LaunchedEffect(remoteRevision) {
        val incoming = currentBox.text
        if (incoming == text) return@LaunchedEffect
        val old = text
        var prefix = 0
        while (prefix < old.length && prefix < incoming.length && old[prefix] == incoming[prefix]) prefix++
        val delta = incoming.length - old.length
        fun shift(i: Int) = (if (i <= prefix) i else maxOf(prefix, i + delta)).coerceIn(0, incoming.length)
        text = incoming
        field = TextFieldValue(incoming, TextRange(shift(field.selection.start), shift(field.selection.end)))
        revision++
    }

    /** 這一次格式要套在哪：有選取 → 選取的字；游標在詞中 → 那個詞；只有游標 → 接下來打的字；沒在打字 → 整個方塊。 */
    fun scope(): TextFormatScope {
        val sel = field.selection
        if (!sel.collapsed) {
            return if (sel.min == 0 && sel.max == currentBox.text.length) TextFormatScope.WholeBox
            else TextFormatScope.Selection(sel.min, sel.max)
        }
        if (!fieldTouched) return TextFormatScope.WholeBox
        RichText.wordRange(currentBox.text, sel.start)?.let { return TextFormatScope.Selection(it.first, it.last + 1) }
        return TextFormatScope.Caret(sel.start)
    }

    fun displayedStyle(): ResolvedCharStyle = when (val sc = scope()) {
        is TextFormatScope.Selection -> RichText.resolvedStyleAt(currentBox, sc.start, sc.end)
        is TextFormatScope.Caret -> caretStyle?.takeIf { it.first == sc.location }
            ?.let { RichText.resolve(it.second, RichText.base(currentBox)) }
            ?: RichText.resolvedStyleAt(currentBox, sc.location, sc.location)
        TextFormatScope.WholeBox -> RichText.base(currentBox)
    }

    FloatingPanel(
        title = l("text_studio"),
        onClose = onDismiss
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
                typingPeerName?.let { name ->
                    Text(
                        l("collab_peer_typing").replace("%@", name),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                // 空的時候要看得出來這裡可以打字。原本是一個沒有邊框、
                // 沒有提示字的 BasicTextField —— 畫面上就是一塊空白，
                // 使用者不會知道那是輸入框（模擬器上實際看不出來）。
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            RoundedCornerShape(8.dp)
                        )
                        .padding(10.dp)
                ) {
                    if (text.isEmpty()) {
                        Text(
                            l("text_placeholder"),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    BasicTextField(
                        value = field,
                        onValueChange = { next ->
                            val old = currentBox.text
                            if (next.text != old) {
                                val pending = caretStyle
                                mutate { b ->
                                    b.text = next.text
                                    RichText.adjustRuns(b, old)
                                    // 游標處留著的格式套在剛打出來的字上。
                                    if (pending != null && next.selection.collapsed &&
                                        next.selection.start > pending.first &&
                                        next.text.length - old.length == next.selection.start - pending.first
                                    ) {
                                        RichText.apply(b, pending.second, pending.first, next.selection.start)
                                        caretStyle = next.selection.start to pending.second
                                    }
                                }
                                text = next.text
                            } else if (caretStyle != null && (next.selection.start != caretStyle?.first || !next.selection.collapsed)) {
                                caretStyle = null
                            }
                            field = next
                        },
                        // 編輯中就看得到逐字格式（字級、顏色、醒目提示），不是要關掉面板才知道套上了沒有。
                        visualTransformation = { input ->
                            TransformedText(
                                if (input.text == currentBox.text) RichText.annotated(currentBox)
                                else androidx.compose.ui.text.AnnotatedString(input.text),
                                OffsetMapping.Identity
                            )
                        },
                        textStyle = TextStyle(
                            fontSize = currentBox.fontSize.coerceIn(10f, 32f).sp,
                            fontWeight = if (currentBox.bold) androidx.compose.ui.text.font.FontWeight.Bold else null,
                            fontStyle = if (currentBox.italic) androidx.compose.ui.text.font.FontStyle.Italic else null,
                            fontFamily = resolveFontFamily(currentBox.fontFamily),
                            textDecoration = decoration(currentBox),
                            color = parseColor(currentBox.textColorHex) ?: MaterialTheme.colorScheme.onSurface,
                            textAlign = alignment(currentBox.alignment),
                            lineHeight = (currentBox.fontSize.coerceIn(10f, 32f) * 1.2f + (currentBox.lineSpacing ?: 0f)).sp
                        ),
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        modifier = Modifier
                            .fillMaxWidth()
                            .onFocusChanged { if (it.isFocused) fieldTouched = true }
                    )
                }

                // Word 式的格式列：有選取時只改選到的字，否則改整個方塊。
                if (revision >= 0) {
                    // 手機上的對話框很窄：格式列收成一條左右捲的列，否則會折成好幾排，
                    // 把下面可捲動的設定區擠到只剩一條縫。平板照樣換行。
                    val compact = androidx.compose.ui.platform.LocalConfiguration.current.screenWidthDp < 600
                    FlowRow(
                        modifier = if (compact) Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                        else Modifier.fillMaxWidth(),
                        // 在左右捲動的容器裡寬度沒有上限，FlowRow 自然排成一列。
                        horizontalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        WordFormatControls(
                            state = WordFormatState.of(currentBox, displayedStyle()),
                            l = { key -> l(key) },
                            languageTag = languageTag,
                            tagPrefix = "text_editor.format"
                        ) { action ->
                            val sc = scope()
                            var pending: TextCharStyle? = null
                            mutate { b -> pending = applyWordFormat(b, action, sc) }
                            pending?.let { edit ->
                                val loc = (sc as TextFormatScope.Caret).location
                                val merged = caretStyle?.takeIf { it.first == loc }?.second?.overlaid(edit) ?: edit
                                caretStyle = loc to merged
                            }
                            if (currentBox.text != field.text) {
                                text = currentBox.text
                                field = TextFieldValue(currentBox.text, TextRange(currentBox.text.length))
                            }
                        }
                    }
                }

                Divider()

                // ScrollableTabRow 而不是 TabRow：TabRow 會把寬度平均分給四個
                // 分頁，320dp 的螢幕上每個只有 80dp，「Paragraph」「Symbols」
                // 會被折成兩行（實機看到「Paragr aph」）。
                ScrollableTabRow(selectedTabIndex = tab, edgePadding = 0.dp) {
                    listOf("text_tab_font", "paragraph_style", "text_tab_style", "text_tab_symbols")
                        .forEachIndexed { index, key ->
                            Tab(
                                selected = tab == index,
                                onClick = { tab = index },
                                text = { Text(l(key), style = MaterialTheme.typography.labelSmall) }
                            )
                        }
                }

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    when (tab) {
                        0 -> {
                            label(l("font_size"))
                            chipRow(listOf(12f, 16f, 20f, 28f, 36f).map { size ->
                                ChipSpec("${size.toInt()}", currentBox.fontSize == size && revision >= 0) {
                                    // 這一頁是「整個方塊」的設定：同一項的逐字覆寫一併拿掉，否則看起來改不動。
                                    mutate { RichText.applyToWholeBox(it, TextCharStyle(fontSize = size)) }
                                }
                            })
                            label(l("alignment"))
                            chipRow(listOf("left", "center", "right", "justified").map { raw ->
                                ChipSpec(raw.take(1).uppercase(), currentBox.alignment == raw && revision >= 0) {
                                    mutate { it.alignment = raw }
                                }
                            })
                            label(l("font_style"))
                            chipRow(listOf(
                                ChipSpec("B", currentBox.bold && revision >= 0) { mutate { RichText.applyToWholeBox(it, TextCharStyle(bold = !it.bold)) } },
                                ChipSpec("I", currentBox.italic && revision >= 0) { mutate { RichText.applyToWholeBox(it, TextCharStyle(italic = !it.italic)) } },
                                ChipSpec("U", currentBox.underline && revision >= 0) { mutate { RichText.applyToWholeBox(it, TextCharStyle(underline = !it.underline)) } },
                                ChipSpec("S", currentBox.strikethrough && revision >= 0) { mutate { RichText.applyToWholeBox(it, TextCharStyle(strikethrough = !it.strikethrough)) } }
                            ))

                            // 文字顏色。Android 原本完全沒有這一項 —— textColorHex
                            // 欄位一直都在，也一直跟著同步走，但改不到。
                            // 在 iPad 上調成紅色的字，到 Android 上就再也變不回去。
                            label(l("text_color"))
                            chipRow(borderColors().map { hex ->
                                ChipSpec(hex, currentBox.textColorHex == hex && revision >= 0) {
                                    mutate { RichText.applyToWholeBox(it, TextCharStyle(textColorHex = hex)) }
                                }
                            })
                        }

                        1 -> {
                            stepperRow(l("line_spacing"), currentBox.lineSpacing ?: 0f, 0f..24f, 2f) { v ->
                                mutate { it.lineSpacing = v }
                            }
                            stepperRow(l("paragraph_spacing"), currentBox.paragraphSpacing ?: 0f, 0f..40f, 4f) { v ->
                                mutate { it.paragraphSpacing = v }
                            }
                            stepperRow(l("first_line_indent"), currentBox.firstLineIndent ?: 0f, 0f..64f, 8f) { v ->
                                mutate { it.firstLineIndent = v }
                            }
                            stepperRow(l("paragraph_indent"), currentBox.paragraphIndent ?: 0f, 0f..64f, 8f) { v ->
                                mutate { it.paragraphIndent = v }
                            }
                        }

                        2 -> {
                            if (onReorder != null) {
                                label(l("layers_panel"))
                                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    for (op in com.kairumo.padnote.canvas.ObjectStacking.Reorder.entries) {
                                        AssistChip(
                                            onClick = { onReorder(op) },
                                            label = { Text(l(op.labelKey)) }
                                        )
                                    }
                                }
                                Divider()
                            }

                            // 透明放最前面：那是使用者最常想要、原本完全做不到的一項。
                            label(l("card_style"))
                            chipRow(
                                listOf(
                                    ChipSpec(l("color_transparent"), currentBox.isBackgroundClear && revision >= 0) {
                                        mutate { it.backgroundColorHex = "clear" }
                                    }
                                ) + cardColors().map { (key, hex) ->
                                    ChipSpec(l(key), currentBox.backgroundColorHex == hex && revision >= 0) {
                                        mutate { it.backgroundColorHex = hex }
                                    }
                                }
                            )

                            // 邊框開關留在編輯面板裡，不放到畫布上當無標示的小圓鈕。
                            chipRow(listOf(
                                ChipSpec(l("object_show_border"), currentBox.hasBorder && revision >= 0) {
                                    mutate { it.hasBorder = !it.hasBorder }
                                }
                            ))

                            // 邊框顏色與粗細只在開了邊框時才有意義。
                            // 一直顯示的話，使用者會調了半天卻看不到任何變化。
                            if (currentBox.hasBorder) {
                                label(l("border_color"))
                                chipRow(borderColors().map { hex ->
                                    ChipSpec(
                                        hex,
                                        (currentBox.borderColorHex ?: "#8E8E93") == hex && revision >= 0
                                    ) { mutate { it.borderColorHex = hex } }
                                })
                                label(l("border_width"))
                                chipRow(listOf(1f, 2f, 3.5f).map { w ->
                                    ChipSpec(
                                        if (w == 3.5f) "3.5" else w.toInt().toString(),
                                        (currentBox.borderWidth ?: 1.5f) == w && revision >= 0
                                    ) { mutate { it.borderWidth = w } }
                                })
                            }

                            Divider()

                            // 圓角。三個級距與 Apple 端相同（0 / 8 / 18）——
                            // 兩邊的可選值不同的話，同一個方塊換平台就調不回原樣。
                            label(l("corner_style"))
                            chipRow(listOf(0f, 8f, 18f).map { r ->
                                ChipSpec(r.toInt().toString(), currentBox.cornerRadius == r && revision >= 0) {
                                    mutate { it.cornerRadius = r }
                                }
                            })

                            // 下限跟著縮放把手走。原本是 160 —— 比把手拉得到的
                            // 還大，於是拉小到格子大小的方塊只要開一次這個面板，
                            // 滑桿就把它彈回 160：使用者看到的是「我調好的寬度
                            // 自己變回去了」。
                            label("${l("box_width")}　${currentBox.width.toInt()}")
                            Slider(
                                value = currentBox.width.coerceIn(MIN_TEXT_BOX_WIDTH_DP, 900f),
                                onValueChange = { v -> mutate { it.width = v } },
                                valueRange = MIN_TEXT_BOX_WIDTH_DP..900f
                            )

                            Divider()

                            label(l("image_rotate"))
                            rotationRow(
                                degrees = CanvasRotation.normalized(currentBox.rotationDegrees ?: 0f),
                                resetLabel = l("reset")
                            ) { v -> mutate { it.rotationDegrees = v } }
                            Text(
                                l("rotation_free_hint"),
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                        else -> {
                            chipRow(
                                listOf("special_symbols", "punctuation_marks", "math_symbols", "roman_numerals")
                                    .mapIndexed { index, key ->
                                        ChipSpec(l(key), symbolCategory == index) { symbolCategory = index }
                                    }
                            )
                            LazyVerticalGrid(
                                columns = GridCells.Adaptive(44.dp),
                                modifier = Modifier.fillMaxWidth().heightIn(max = 180.dp)
                            ) {
                                items(SYMBOL_SETS[symbolCategory]) { symbol ->
                                    TextButton(onClick = {
                                        val old = currentBox.text
                                        text += symbol
                                        mutate {
                                            it.text = text
                                            RichText.adjustRuns(it, old)
                                        }
                                        field = TextFieldValue(text, TextRange(text.length))
                                    }) { Text(symbol) }
                                }
                            }
                        }
                    }
                }
                Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), thickness = 0.5.dp)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                ) {
                    TextButton(onClick = onDelete) {
                        Text(l("delete"), color = MaterialTheme.colorScheme.error)
                    }
                    TextButton(onClick = onDismiss) {
                        Text(l("close"))
                    }
                }
            }
    }
}

/**
 * 卡片底色與邊框顏色。
 *
 * **來源是核心的 `cardPalette()` / `borderPalette()`，不在這裡寫死。**
 *
 * 原本每個地方各寫一份，結果是同一個「淡藍」對到不同的 hex —— 不只跨平台，
 * Apple 自己的畫布快速選單與排版面板就是兩個值（#E3F2FD / #E1F5FE）。
 * 顏色是**會落盤的資料**，不是樣式偏好，所以它下沉到核心。
 */
private fun cardColors(): List<Pair<String, String>> =
    uniffi.padnote_core.cardPalette().map { it.key to it.hex }

private fun borderColors(): List<String> =
    uniffi.padnote_core.borderPalette().map { it.hex }

/**
 * 符號表。**來源是核心的 `symbolPalette()`，不在這裡寫死**（工作項 S-63）。
 *
 * 原本兩個平台各寫一份，靠一句「與 Apple 端逐字相同」的註解維持一致 ——
 * 註解攔不住任何東西。加一個符號時只改一邊，症狀會是「iPad 上插得到的
 * 符號在 Android 上找不到」，而且兩邊各自看起來都很完整，沒有人會發現。
 */
private val SYMBOL_SETS: List<List<String>> by lazy {
    symbolCategories().map { symbolPalette(it) }
}

private data class ChipSpec(val label: String, val selected: Boolean, val onClick: () -> Unit)

@Composable
private fun label(text: String) {
    Text(text, style = MaterialTheme.typography.labelSmall)
}

/**
 * 會換行的晶片列。
 *
 * 用 FlowRow 而不是固定格寬的格線：晶片標籤長度差很多（「12」對上
 * 「Transparent」），一個格寬不可能兩邊都合適 —— 窄了長標籤在晶片裡折成兩行，
 * 寬了「12」那種短標籤會佔掉半個螢幕（兩種都在實機上看過）。
 * FlowRow 讓每個晶片各自依內容取寬度，放不下才換行。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun chipRow(specs: List<ChipSpec>) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        for (spec in specs) {
            FilterChip(
                selected = spec.selected,
                onClick = spec.onClick,
                label = { Text(spec.label, style = MaterialTheme.typography.labelSmall) }
            )
        }
    }
}

/** 旋轉：滑桿 + 常用角度 + 歸零。角度規則與 Apple 端共用 `CanvasRotation`。 */
@Composable
private fun rotationRow(degrees: Float, resetLabel: String, onChange: (Float) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Slider(
                value = degrees,
                onValueChange = { onChange(CanvasRotation.normalized(it)) },
                valueRange = 0f..359f,
                modifier = Modifier.weight(1f)
            )
            Text("${degrees.toInt()}°", style = MaterialTheme.typography.labelMedium,
                 modifier = Modifier.padding(top = 12.dp))
        }
        // 用會換行的格線，不是 Row。Row 不換行，320dp 螢幕上四個角度加一個
        // Reset 放不下，Reset 會被整個推出畫面外 —— 而且沒有任何視覺提示。
        chipRow(
            listOf(0f, 90f, 180f, 270f).map { angle ->
                ChipSpec("${angle.toInt()}°", false) { onChange(angle) }
            } + ChipSpec(resetLabel, false) { onChange(0f) }
        )
    }
}

/**
 * 一個「標籤 + 減 / 數值 / 加」的小控制項。
 *
 * 用按鈕而不是滑桿：這些值的合理範圍很小（行距 0–24pt），滑桿在那種範圍下
 * 很難精準，而且看不到目前是多少。與 Apple 端同樣的取捨。
 */
@Composable
private fun stepperRow(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    step: Float,
    onChange: (Float) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall,
             modifier = Modifier.padding(top = 6.dp))
        TextButton(
            onClick = { onChange((value - step).coerceAtLeast(range.start)) },
            enabled = value > range.start
        ) { Text("−") }
        Text("${value.toInt()}", style = MaterialTheme.typography.labelMedium,
             modifier = Modifier.padding(top = 6.dp))
        TextButton(
            onClick = { onChange((value + step).coerceAtMost(range.endInclusive)) },
            enabled = value < range.endInclusive
        ) { Text("+") }
    }
}

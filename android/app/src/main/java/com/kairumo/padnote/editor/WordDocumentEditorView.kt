package com.kairumo.padnote.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Divider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.TableLayer
import com.kairumo.padnote.table.TableStore

/**
 * 仿 Office Word / Google Docs 的標準居中文件紙張編輯器（Android 版）。
 *
 * 對齊 Apple 端 `WordDocumentEditorView.swift`。
 * 具備標準文書處理工具列（樣式、粗斜底線、對齊、清單、色彩、表格插入），
 * 以及居中的標準 A4 白底流式紙張。
 */
@Composable
fun WordDocumentEditorView(
    documentText: String,
    onTextChange: (String) -> Unit,
    languageTag: String = "zh-Hant",
    tableStore: TableStore? = null,
    tableRevision: Int = 0,
    onInsertTable: (() -> Unit)? = null,
    onInsertImage: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var isBold by remember { mutableStateOf(false) }
    var isItalic by remember { mutableStateOf(false) }
    var isUnderline by remember { mutableStateOf(false) }
    var textAlign by remember { mutableStateOf(TextAlign.Start) }
    var selectedFontSize by remember { mutableStateOf(16.sp) }
    var selectedTextColor by remember { mutableStateOf(Color(0xFF1E293B)) }
    var selectedStyleName by remember { mutableStateOf("本文") }

    val palette = listOf(
        Color(0xFF0F172A),
        Color(0xFF2563EB),
        Color(0xFFDC2626),
        Color(0xFF16A34A),
        Color(0xFFD97706),
        Color(0xFF7C3AED)
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
    ) {
        // 🌟 Word 級專屬文書排版工具列
        Surface(
            tonalElevation = 2.dp,
            shadowElevation = 1.dp,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                // 樣式切換（本文 / 標題 1 / 標題 2）
                listOf("本文" to 16.sp, "標題 1" to 22.sp, "標題 2" to 18.sp).forEach { (name, size) ->
                    FilterChip(
                        selected = selectedStyleName == name,
                        onClick = {
                            selectedStyleName = name
                            selectedFontSize = size
                            if (name == "標題 1") isBold = true
                        },
                        label = { Text(name, fontSize = 12.sp) },
                        modifier = Modifier.height(32.dp)
                    )
                }

                Divider(
                    modifier = Modifier
                        .height(20.dp)
                        .width(1.dp)
                        .padding(horizontal = 2.dp)
                )

                // 粗體、斜體、底線
                IconButton(
                    onClick = { isBold = !isBold },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "B",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        color = if (isBold) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }

                IconButton(
                    onClick = { isItalic = !isItalic },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "I",
                        fontStyle = FontStyle.Italic,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 16.sp,
                        color = if (isItalic) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }

                IconButton(
                    onClick = { isUnderline = !isUnderline },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "U",
                        textDecoration = TextDecoration.Underline,
                        fontSize = 16.sp,
                        color = if (isUnderline) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }

                Divider(
                    modifier = Modifier
                        .height(20.dp)
                        .width(1.dp)
                        .padding(horizontal = 2.dp)
                )

                // 對齊控制
                IconButton(
                    onClick = { textAlign = TextAlign.Start },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "⇤",
                        fontSize = 18.sp,
                        color = if (textAlign == TextAlign.Start) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }

                IconButton(
                    onClick = { textAlign = TextAlign.Center },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "≡",
                        fontSize = 18.sp,
                        color = if (textAlign == TextAlign.Center) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }

                IconButton(
                    onClick = { textAlign = TextAlign.End },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "⇥",
                        fontSize = 18.sp,
                        color = if (textAlign == TextAlign.End) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }

                Divider(
                    modifier = Modifier
                        .height(20.dp)
                        .width(1.dp)
                        .padding(horizontal = 2.dp)
                )

                // 快速清單樣式
                IconButton(
                    onClick = {
                        onTextChange(if (documentText.isEmpty()) "• " else "$documentText\n• ")
                    },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "•—",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }

                IconButton(
                    onClick = {
                        onTextChange(if (documentText.isEmpty()) "1. " else "$documentText\n1. ")
                    },
                    modifier = Modifier.size(32.dp)
                ) {
                    Text(
                        "1—",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }

                Divider(
                    modifier = Modifier
                        .height(20.dp)
                        .width(1.dp)
                        .padding(horizontal = 2.dp)
                )

                // 文字顏色點
                palette.forEach { color ->
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .clip(CircleShape)
                            .background(color)
                            .border(
                                width = if (selectedTextColor == color) 2.dp else 0.5.dp,
                                color = if (selectedTextColor == color) MaterialTheme.colorScheme.primary else Color.Gray,
                                shape = CircleShape
                            )
                    )
                }

                if (onInsertTable != null) {
                    FilterChip(
                        selected = false,
                        onClick = onInsertTable,
                        label = { Text(l("wd_add_table"), fontSize = 12.sp) },
                        modifier = Modifier.height(32.dp)
                    )
                }
            }
        }

        // 🌟 居中標準文件紙張編輯區 (A4 模擬視圖)
        Box(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(vertical = 20.dp, horizontal = 12.dp),
            contentAlignment = Alignment.TopCenter
        ) {
            Surface(
                modifier = Modifier
                    .widthIn(max = 760.dp)
                    .fillMaxWidth()
                    .shadow(elevation = 4.dp, shape = RoundedCornerShape(4.dp)),
                color = Color.White,
                shape = RoundedCornerShape(4.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 36.dp, vertical = 40.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // 文件流式主要文字輸入框
                    BasicTextField(
                        value = documentText,
                        onValueChange = onTextChange,
                        textStyle = TextStyle(
                            fontSize = selectedFontSize,
                            fontWeight = if (isBold) FontWeight.Bold else FontWeight.Normal,
                            fontStyle = if (isItalic) FontStyle.Italic else FontStyle.Normal,
                            textDecoration = if (isUnderline) TextDecoration.Underline else TextDecoration.None,
                            textAlign = textAlign,
                            color = selectedTextColor,
                            lineHeight = (selectedFontSize.value * 1.55f).sp
                        ),
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 480.dp),
                        decorationBox = { innerTextField ->
                            if (documentText.isEmpty()) {
                                Text(
                                    text = "在此輸入文件內容...",
                                    style = TextStyle(
                                        fontSize = selectedFontSize,
                                        color = Color.LightGray
                                    )
                                )
                            }
                            innerTextField()
                        }
                    )

                    // 嵌入的表格展示（若該頁面有表格）
                    tableStore?.all?.forEach { table ->
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp)
                                .border(1.dp, Color(0xFFE2E8F0), RoundedCornerShape(4.dp))
                                .padding(8.dp)
                        ) {
                            Text(
                                "表格（${table.rows} × ${table.cols}）",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.Gray
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    // 底部文件字數統計欄
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "字數統計：${documentText.length} 字元",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.Gray
                        )
                        Text(
                            text = "A4 標準版面 · 100%",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.LightGray
                        )
                    }
                }
            }
        }
    }
}

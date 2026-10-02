package com.kairumo.padnote.math

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SecondaryTabRow
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings

/**
 * 算式計算機（Android）。
 *
 * 求值走核心的 `mathEvaluate` —— 與 Apple 端同一個實作，所以同一條算式在兩個
 * 平台得到同一個答案。
 *
 * 重構為具備工程科學計算機、微積分與工數快捷模板、完整特殊符號庫、物理/數學常數，
 * 結果以可編輯的文字方塊插入畫布。
 */
@OptIn(ExperimentalLayoutApi::class, androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun MathCalculatorDialog(
    languageTag: String,
    onInsert: (String) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var input by remember { mutableStateOf("125 * 8 + 45") }
    var selectedTab by remember { mutableIntStateOf(0) }

    val outcome = remember(input) {
        val trimmed = input.trim()
        if (trimmed.isBlank()) null else uniffi.padnote_core.mathEvaluate(trimmed)
    }

    val calcKeys = listOf(
        "sin(", "cos(", "tan(", "ln(", "log(",
        "asin(", "acos(", "atan(", "exp(", "sqrt(",
        "sinh(", "cosh(", "tanh(", "pow(", "cbrt(",
        "deg(", "rad(", "fact(", "ncr(", "npr(",
        "(", ")", "^", "!", "%",
        "7", "8", "9", "÷", "gcd(",
        "4", "5", "6", "×", "lcm(",
        "1", "2", "3", "-", "abs(",
        "0", ".", "=", "+", "π"
    )

    val calculusTemplates = listOf(
        "d/dx(3x^2 + 5x - 4) = 6x + 5",
        "∫(0 to 2) (3x^2) dx = 8",
        "∫(0 to ∞) e^(-x) dx = 1",
        "f(x) = a0/2 + ∑(an cos(nx) + bn sin(nx))",
        "L{e^(at)} = 1 / (s - a)",
        "y'' + 4y' + 13y = 0",
        "∇f = ∂f/∂x i + ∂f/∂y j + ∂f/∂z k",
        "∇·F = ∂P/∂x + ∂Q/∂y + ∂R/∂z",
        "∇×F = det |i j k; ∂x ∂y ∂z; P Q R|",
        "det(A - λI) = 0",
        "e^(iθ) = cos(θ) + i sin(θ)",
        "∫(-∞ to ∞) e^(-x^2) dx = √π",
        "∂u/∂t = α ∇²u",
        "∂²u/∂t² = c² ∇²u"
    )

    val symbolsList = listOf(
        "∫", "∬", "∭", "∮", "∂", "∇", "∆", "d", "dx", "dy", "dz", "dt", "′", "″",
        "×", "·", "⊗", "⊕", "⊙", "⊥", "∥", "∠", "∢", "°", "∇·", "∇×", "∇²",
        "±", "∓", "≠", "≈", "≡", "≤", "≥", "≪", "≫", "∝", "∞", "√", "∛", "∑", "∏",
        "∈", "∉", "⊂", "⊃", "⊆", "⊇", "∪", "∩", "∅", "∀", "∃", "∴", "∵", "⇒", "⇔",
        "α", "β", "γ", "δ", "ε", "θ", "λ", "μ", "π", "σ", "τ", "φ", "ω", "Γ", "Δ", "Θ", "Λ", "Σ", "Φ", "Ω"
    )

    val constantsList = listOf(
        "pi" to "3.14159...",
        "e" to "2.71828...",
        "phi" to "1.61803...",
        "c" to "299,792,458",
        "g" to "9.80665",
        "h" to "6.62607e-34",
        "k" to "1.38065e-23",
        "na" to "6.02214e23"
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("math_calc")) },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedTextField(
                    value = input,
                    onValueChange = { input = it },
                    label = { Text(l("math_expression")) },
                    placeholder = { Text(l("math_placeholder")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    TextButton(onClick = { input = "" }) {
                        Text(l("math_clear"))
                    }
                    TextButton(onClick = {
                        if (input.isNotEmpty()) input = input.dropLast(1)
                    }) {
                        Text(l("math_backspace"))
                    }
                }

                // 求值狀態
                when {
                    outcome == null -> Text(
                        l("math_input_hint"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    outcome.ok -> Text(
                        "${l("math_value_prefix")}: ${outcome.formatted}",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                    else -> Text(
                        l(outcome.errorKey.ifEmpty { "math_error_bad_expression" }),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }

                // 標籤頁
                SecondaryTabRow(selectedTabIndex = selectedTab) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text(l("math_tab_calc")) }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text(l("math_tab_calculus")) }
                    )
                    Tab(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        text = { Text(l("math_tab_symbols")) }
                    )
                    Tab(
                        selected = selectedTab == 3,
                        onClick = { selectedTab = 3 },
                        text = { Text(l("math_tab_units")) }
                    )
                }

                when (selectedTab) {
                    0 -> {
                        // 科學計算機按鍵
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.heightIn(max = 240.dp)
                        ) {
                            for (key in calcKeys) {
                                SuggestionChip(
                                    onClick = {
                                        if (key == "=") {
                                            // 觸發重新求值
                                        } else {
                                            input += key
                                        }
                                    },
                                    label = { Text(key) }
                                )
                            }
                        }
                    }
                    1 -> {
                        // 微積分與工數範本
                        Column(
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.heightIn(max = 240.dp).verticalScroll(rememberScrollState())
                        ) {
                            for (tmpl in calculusTemplates) {
                                SuggestionChip(
                                    onClick = { input = tmpl },
                                    label = { Text(tmpl) },
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }
                    }
                    2 -> {
                        // 數學特殊符號庫
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.heightIn(max = 240.dp).verticalScroll(rememberScrollState())
                        ) {
                            for (symbol in symbolsList) {
                                SuggestionChip(
                                    onClick = { input += symbol },
                                    label = { Text(symbol) }
                                )
                            }
                        }
                    }
                    3 -> {
                        // 常數與單位
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            for ((sym, desc) in constantsList) {
                                SuggestionChip(
                                    onClick = { input += sym },
                                    label = { Text("$sym ($desc)") }
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val trimmed = input.trim().removeSuffix("=").trim()
                    val toInsert = if (outcome?.ok == true) "$trimmed = ${outcome.formatted}" else trimmed
                    onInsert(toInsert)
                    onDismiss()
                }
            ) { Text(l("math_insert_editable")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

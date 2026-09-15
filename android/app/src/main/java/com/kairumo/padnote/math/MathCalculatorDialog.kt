package com.kairumo.padnote.math

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
 * 平台得到同一個答案。Apple 原本走 `NSExpression`，Android 沒有對應品，
 * 各寫一份的結果就是兩台裝置算出不同的數字。
 *
 * 結果以**文字方塊**插入畫布，不是算繪好的圖片 —— 算式之後還改得動。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MathCalculatorDialog(
    languageTag: String,
    onInsert: (String) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var input by remember { mutableStateOf("") }
    val outcome = remember(input) {
        if (input.isBlank()) null else uniffi.padnote_core.mathEvaluate(input)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("math_calc")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = input,
                    onValueChange = { input = it },
                    label = { Text(l("math_expression")) },
                    placeholder = { Text(l("math_placeholder")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                // 常用符號。手機鍵盤上 × ÷ π 都要翻好幾層才找得到。
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (symbol in listOf("+", "-", "×", "÷", "(", ")", "^", "%", "π", "sqrt(")) {
                        SuggestionChip(
                            onClick = { input += symbol },
                            label = { Text(symbol) }
                        )
                    }
                }

                when {
                    outcome == null -> Text(
                        l("math_input_hint"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    outcome.ok -> Text(
                        "${l("math_value_prefix")} ${outcome.formatted}",
                        style = MaterialTheme.typography.titleMedium
                    )
                    else -> Text(
                        // 錯誤訊息走字串表。核心回的是語系鍵，不是給人看的句子。
                        l(outcome.errorKey.ifEmpty { "math_error_bad_expression" }),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = outcome?.ok == true,
                onClick = {
                    val r = outcome ?: return@TextButton
                    onInsert("${input.trim().removeSuffix("=").trim()} = ${r.formatted}")
                    onDismiss()
                }
            ) { Text(l("math_insert")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

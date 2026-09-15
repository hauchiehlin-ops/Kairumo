package com.kairumo.padnote.ink

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings

/**
 * 草圖美化控制列（Android）。
 *
 * 與 Apple 端 `sketchRefineFloatingBar` 是同一組控制項：強度滑桿、套用、
 * 還原原草圖、重做美化、關閉。辨識與平滑都在核心（`sketchRefineStroke`），
 * 兩個平台判定完全一樣 —— 同一個歪圓不會在 iPad 上被拉正、在手機上還是歪的。
 *
 * 強度下限是 0.2 而不是 0：拉到 0 等於什麼都沒做，那個位置對使用者沒有意義
 * （要「什麼都沒做」按還原就好）。與 Apple 端的 `0.2...1.0` 一致。
 *
 * @param onApply 回傳實際換掉的筆數，供外層顯示結果訊息。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SketchRefineBar(
    languageTag: String,
    canRestore: Boolean,
    canRedo: Boolean,
    onApply: (Float) -> Unit,
    onRestore: () -> Unit,
    onRedo: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var intensity by remember { mutableFloatStateOf(0.85f) }

    Card(modifier.fillMaxWidth().padding(8.dp)) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    l("refine_sketch"),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )
                TextButton(onClick = onDismiss) { Text(l("done")) }
            }

            Text(
                "${l("refine_strength")}：${(intensity * 100).toInt()}%",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Slider(
                value = intensity,
                onValueChange = { intensity = it },
                valueRange = 0.2f..1.0f,
                // 16 段對應 0.2…1.0 每 0.05 一格，與 Apple 端的 step 相同。
                steps = 15
            )

            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { onApply(intensity) }) { Text(l("apply_refine")) }
                TextButton(onClick = onRestore, enabled = canRestore) { Text(l("restore_original")) }
                TextButton(onClick = onRedo, enabled = canRedo) { Text(l("redo_refine")) }
            }
        }
    }
}

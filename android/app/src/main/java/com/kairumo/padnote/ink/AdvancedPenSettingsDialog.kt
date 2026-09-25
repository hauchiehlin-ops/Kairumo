package com.kairumo.padnote.ink

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

@Composable
fun AdvancedPenSettingsDialog(
    languageTag: String,
    onApply: (floor: Float?, gamma: Float?) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

    // "Pressure Floor" (0.01f to 1.0f, default 0.1f)
    // "Pressure Gamma" (0.5f to 2.5f, default 1.0f)
    var floor by remember {
        mutableFloatStateOf(PenSettingsStore.floor(context) ?: 0.1f)
    }
    var gamma by remember {
        mutableFloatStateOf(PenSettingsStore.gamma(context) ?: 1.0f)
    }

    fun l(key: String): String {
        val map = mapOf(
            "pen_settings_title" to mapOf("en" to "Advanced Pen Settings", "zh" to "進階畫筆設定"),
            "pressure_floor" to mapOf("en" to "Pressure Floor", "zh" to "下筆起始壓力"),
            "pressure_gamma" to mapOf("en" to "Pressure Gamma", "zh" to "壓力敏感度曲線"),
            "confirm" to mapOf("en" to "Confirm", "zh" to "確定"),
            "cancel" to mapOf("en" to "Cancel", "zh" to "取消"),
            "reset" to mapOf("en" to "Reset", "zh" to "重設")
        )
        val lang = if (languageTag.startsWith("zh")) "zh" else "en"
        return map[key]?.get(lang) ?: key
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("pen_settings_title")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(l("pressure_floor"), style = MaterialTheme.typography.bodyMedium)
                    Text("%.2f".format(floor), style = MaterialTheme.typography.labelMedium)
                }
                Slider(
                    value = floor,
                    onValueChange = { floor = it },
                    valueRange = 0.01f..1.0f
                )

                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(l("pressure_gamma"), style = MaterialTheme.typography.bodyMedium)
                    Text("%.2f".format(gamma), style = MaterialTheme.typography.labelMedium)
                }
                Slider(
                    value = gamma,
                    onValueChange = { gamma = it },
                    valueRange = 0.5f..2.5f
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                PenSettingsStore.save(context, floor, gamma)
                onApply(floor, gamma)
                onDismiss()
            }) { Text(l("confirm")) }
        },
        dismissButton = {
            Row {
                TextButton(onClick = {
                    PenSettingsStore.clear(context)
                    onApply(null, null)
                    onDismiss()
                }) { Text(l("reset")) }
                TextButton(onClick = onDismiss) { Text(l("cancel")) }
            }
        }
    )
}

object PenSettingsStore {
    private const val PREFS = "kairumo_pen"
    private const val KEY_FLOOR = "pressureFloor"
    private const val KEY_GAMMA = "pressureGamma"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun floor(context: Context): Float? =
        prefs(context).let { if (it.contains(KEY_FLOOR)) it.getFloat(KEY_FLOOR, 0.1f) else null }

    fun gamma(context: Context): Float? =
        prefs(context).let { if (it.contains(KEY_GAMMA)) it.getFloat(KEY_GAMMA, 1.0f) else null }

    fun save(context: Context, floor: Float, gamma: Float) {
        prefs(context).edit()
            .putFloat(KEY_FLOOR, floor)
            .putFloat(KEY_GAMMA, gamma)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_FLOOR).remove(KEY_GAMMA).apply()
    }
}

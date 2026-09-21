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
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.palmRadiusClamped
import uniffi.padnote_core.palmRetractMsClamped
import uniffi.padnote_core.palmThresholdLimits
import kotlin.math.roundToInt

/**
 * 掌拒門檻的調整介面（工作項 S-101）。
 *
 * # 為什麼以前沒有
 *
 * 判定邏輯一直都在核心的 `InkArbiter`，兩個平台也都接了 —— 缺的只是
 * 「讓使用者調」。沒有它的後果是：握筆姿勢比較特別、或者螢幕特別大的人，
 * 手掌一放上去就是一道線，而他完全沒有辦法處理。
 *
 * # 為什麼一定要有「恢復預設」
 *
 * 門檻調錯會讓筆**完全畫不出來**（半徑調太低，連筆尖都被當成手掌）。
 * 那個狀態下使用者沒有辦法用畫布本身把它救回來 —— 所以恢復預設不是
 * 貼心功能，是這個設定能不能開放的前提。
 *
 * 範圍與預設值都來自核心（`palmThresholdLimits`），兩個平台同一組數字。
 */
@Composable
fun PalmThresholdDialog(
    languageTag: String,
    onApply: (radiusDp: Float?, retractMs: UInt?) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val context = LocalContext.current
    val limits = remember { palmThresholdLimits() }

    var radius by remember {
        mutableFloatStateOf(PalmThresholdStore.radius(context) ?: limits.defaultRadiusDp)
    }
    var retractMs by remember {
        mutableFloatStateOf(
            (PalmThresholdStore.retractMs(context) ?: limits.defaultRetractMs).toFloat()
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("palm_rejection_settings")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(l("palm_threshold_radius"), style = MaterialTheme.typography.bodyMedium)
                    Text("${radius.roundToInt()} dp", style = MaterialTheme.typography.labelMedium)
                }
                Slider(
                    value = radius,
                    onValueChange = { radius = it },
                    valueRange = limits.minRadiusDp..limits.maxRadiusDp
                )

                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(l("palm_threshold_retract"), style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "${retractMs.roundToInt()} ms",
                        style = MaterialTheme.typography.labelMedium
                    )
                }
                Slider(
                    value = retractMs,
                    onValueChange = { retractMs = it },
                    valueRange = limits.minRetractMs.toFloat()..limits.maxRetractMs.toFloat()
                )

                Text(
                    l("palm_threshold_retract_hint"),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    l("palm_threshold_hint"),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                // 夾制走核心 —— 滑桿的兩端本來就在範圍內，但值也可能來自
                // 舊版寫下的偏好設定，那些沒有經過任何檢查。
                val r = palmRadiusClamped(radius)
                val ms = palmRetractMsClamped(retractMs.roundToInt().toUInt())
                PalmThresholdStore.save(context, r, ms)
                onApply(r, ms)
                onDismiss()
            }) { Text(l("confirm")) }
        },
        dismissButton = {
            Row {
                TextButton(onClick = {
                    PalmThresholdStore.clear(context)
                    onApply(null, null)
                    onDismiss()
                }) { Text(l("palm_threshold_reset")) }
                TextButton(onClick = onDismiss) { Text(l("cancel")) }
            }
        }
    )
}

/**
 * 門檻存在**這台裝置**的偏好設定裡，不進同步。
 *
 * 理由與 `DeviceSettings` 一致：握筆姿勢、螢幕大小、觸控取樣率因裝置而異，
 * 把手機上調鬆的值同步到平板，平板的掌拒就形同虛設。
 */
object PalmThresholdStore {
    private const val PREFS = "kairumo"
    private const val KEY_RADIUS = "palmRadiusDp"
    private const val KEY_RETRACT = "palmRetractMs"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** `null` 表示使用者沒有自訂過，跟著核心的預設走。 */
    fun radius(context: Context): Float? =
        prefs(context).let { if (it.contains(KEY_RADIUS)) it.getFloat(KEY_RADIUS, 0f) else null }

    fun retractMs(context: Context): UInt? =
        prefs(context).let {
            if (it.contains(KEY_RETRACT)) it.getInt(KEY_RETRACT, 0).toUInt() else null
        }

    fun save(context: Context, radiusDp: Float, retractMs: UInt) {
        prefs(context).edit()
            .putFloat(KEY_RADIUS, radiusDp)
            .putInt(KEY_RETRACT, retractMs.toInt())
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_RADIUS).remove(KEY_RETRACT).apply()
    }
}

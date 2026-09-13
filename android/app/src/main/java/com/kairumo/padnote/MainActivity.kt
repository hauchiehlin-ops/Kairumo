package com.kairumo.padnote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import uniffi.padnote_core.appInfo
import uniffi.padnote_core.coreVersion

/**
 * Android 外殼的起點（工作包 WP2）。
 *
 * 現階段的唯一任務：證明 Kotlin ⇄ UniFFI ⇄ libpadnote_core.so 這條路是通的。
 * 筆跡引擎（WP5）與其餘平台功能（WP6）會在這之上長出來。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    CoreStatusScreen()
                }
            }
        }
    }
}

@Composable
private fun CoreStatusScreen() {
    // 真的呼叫 Rust —— 這裡回傳值出得來，就代表 .so 有被載入、JNA 綁定也對得上
    val status = remember { readCoreStatus() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("Kairumo", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Android 外殼 · WP2 骨架",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        status.forEach { (label, value) ->
            Text(
                "$label：$value",
                style = MaterialTheme.typography.bodyMedium,
                fontFamily = FontFamily.Monospace
            )
        }
    }
}

private fun readCoreStatus(): List<Pair<String, String>> = try {
    val info = appInfo()
    listOf(
        "核心版本" to coreVersion(),
        "目標平台" to "${info.targetOs}/${info.targetArch}",
        "介面版本" to "2.3.0 (11)"
    )
} catch (t: Throwable) {
    // 綁定或 .so 載入失敗時要講清楚，不要給一個空白畫面
    listOf("核心載入失敗" to (t.message ?: t.toString()))
}

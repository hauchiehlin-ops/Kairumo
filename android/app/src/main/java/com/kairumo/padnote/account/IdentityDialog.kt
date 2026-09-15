package com.kairumo.padnote.account

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * 編輯協作身分（名稱與顏色）。
 *
 * 與 Apple 端同一組顏色、同一組字串鍵。這不是帳號 —— 不需要註冊，
 * 也不會連到任何雲端，只是存在這台裝置上的一個名字與一個顏色。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun IdentityDialog(
    profile: AccountManager.Profile,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onSave: (String, String) -> Unit
) {
    var name by remember { mutableStateOf(profile.displayName) }
    var hex by remember { mutableStateOf(profile.colorHex) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("edit_identity")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(l("default_user_name")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Text(l("identity_desc"), style = MaterialTheme.typography.bodySmall)
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    for (option in AccountManager.PALETTE) {
                        val color = parseHex(option) ?: Color.Gray
                        Box(
                            // 命中區 40dp、色點 28dp —— 與其他色票同一套作法。
                            modifier = Modifier.size(40.dp).clickable { hex = option },
                            contentAlignment = Alignment.Center
                        ) {
                            Box(
                                Modifier
                                    .size(28.dp)
                                    .background(color, CircleShape)
                                    .border(
                                        if (hex == option) 3.dp else 1.dp,
                                        if (hex == option) MaterialTheme.colorScheme.primary
                                        else MaterialTheme.colorScheme.outline,
                                        CircleShape
                                    )
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(name, hex); onDismiss() }) { Text(l("confirm")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

private fun parseHex(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }

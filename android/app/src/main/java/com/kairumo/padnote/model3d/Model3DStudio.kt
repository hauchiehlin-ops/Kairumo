package com.kairumo.padnote.model3d

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.model3dKindRaw
import uniffi.padnote_core.model3dKinds
import uniffi.padnote_core.model3dMaterialLook
import uniffi.padnote_core.model3dMaterials

/**
 * 3D 模型面板（Android）。
 *
 * 與 Apple 的 `Model3DStudioView` 對應：六種立體、九種材質、三軸旋轉與縮放、
 * 自訂標題，加上一塊即時預覽。幾何與材質全部走核心，所以兩個平台選同一組
 * 設定會得到同一個模型。
 *
 * 同一個面板兼做**新增**與**編輯**：傳 `existing` 就是編輯。分成兩個面板的話，
 * 使用者插完之後就只能刪掉重做（文字方塊犯過這個錯）。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun Model3DStudio(
    languageTag: String,
    existing: Model3DObject? = null,
    onCommit: (Model3DObject) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    val base = existing ?: Model3DObject()
    var kindRaw by remember { mutableStateOf(base.modelTypeRaw) }
    var materialRaw by remember { mutableStateOf(base.materialRaw) }
    var title by remember { mutableStateOf(base.title) }
    var rotX by remember { mutableFloatStateOf(base.rotationX) }
    var rotY by remember { mutableFloatStateOf(base.rotationY) }
    var rotZ by remember { mutableFloatStateOf(base.rotationZ) }
    var scale by remember { mutableFloatStateOf(base.scale) }

    val preview = base.copy(
        modelTypeRaw = kindRaw,
        materialRaw = materialRaw,
        rotationX = rotX,
        rotationY = rotY,
        rotationZ = rotZ,
        scale = scale,
        title = title
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("model3d_studio")) },
        confirmButton = {
            TextButton(onClick = { onCommit(preview); onDismiss() }) { Text(l("confirm")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } },
        text = {
            Column(
                Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // 即時預覽。改一個滑桿立刻看到結果 —— 這是整個面板存在的理由，
                // 不然使用者是在盲調三個角度。
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(10.dp))
                ) {
                    Canvas(Modifier.fillMaxWidth().height(180.dp)) {
                        Model3DRenderer.draw(this, preview, size.width, size.height)
                    }
                }

                Text(l("geom_shape"), style = MaterialTheme.typography.labelMedium)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (kind in model3dKinds()) {
                        val raw = model3dKindRaw(kind)
                        FilterChip(
                            selected = raw == kindRaw,
                            onClick = { kindRaw = raw },
                            // 六種立體的名稱是英文專有名詞（Sphere / Torus…），
                            // 與 Apple 端的 displayName 一致，不另外翻譯。
                            label = { Text(raw.replaceFirstChar { it.uppercase() }) }
                        )
                    }
                }

                Text(l("material_style"), style = MaterialTheme.typography.labelMedium)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (m in model3dMaterials()) {
                        val look = model3dMaterialLook(m)
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.clickable { materialRaw = look.raw }
                        ) {
                            Box(
                                Modifier
                                    .size(34.dp)
                                    .background(Model3DRenderer.materialColor(m), CircleShape)
                                    .border(
                                        if (look.raw == materialRaw) 2.dp else 1.dp,
                                        if (look.raw == materialRaw) MaterialTheme.colorScheme.primary
                                        else Color.Black.copy(alpha = 0.12f),
                                        CircleShape
                                    )
                            )
                            Text(l(look.nameKey), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }

                AngleSlider("X", rotX) { rotX = it }
                AngleSlider("Y", rotY) { rotY = it }
                AngleSlider("Z", rotZ) { rotZ = it }

                Text("${l("model_scale")}：${"%.2f".format(scale)}", style = MaterialTheme.typography.labelMedium)
                Slider(value = scale, onValueChange = { scale = it }, valueRange = 0.4f..2.0f)

                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text(l("model_title")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    )
}

/** 旋轉滑桿。以弧度儲存（與核心、與 SceneKit 同單位），顯示成度數給人看。 */
@Composable
private fun AngleSlider(axis: String, value: Float, onChange: (Float) -> Unit) {
    Text(
        "$axis：${Math.toDegrees(value.toDouble()).toInt()}°",
        style = MaterialTheme.typography.labelMedium
    )
    Slider(
        value = value,
        onValueChange = onChange,
        valueRange = 0f..(2f * Math.PI.toFloat())
    )
}

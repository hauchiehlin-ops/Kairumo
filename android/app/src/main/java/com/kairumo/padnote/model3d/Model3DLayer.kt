package com.kairumo.padnote.model3d

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.kairumo.padnote.canvas.MIN_OBJECT_HEIGHT_DP
import com.kairumo.padnote.canvas.MIN_OBJECT_WIDTH_DP
import com.kairumo.padnote.canvas.ResizeHandle
import com.kairumo.padnote.canvas.StyleHandle
import com.kairumo.padnote.canvas.gesturesIf
import androidx.compose.ui.platform.testTag
import androidx.compose.foundation.layout.Arrangement

/**
 * 畫布上的 3D 模型圖層（Android）。
 *
 * 與 Apple 的 `Model3DCanvasItemView` 對應：拖曳搬動、拉右下角改大小、
 * 點一下選取、點兩下（或按樣式把手）回到編輯面板。
 *
 * 位置與大小是頁面座標（點），乘上 [density] 才是螢幕像素 —— 與其他
 * 圖層同一套規則。這一條踩過雷：把頁面點當成像素的話，在密度 3 的手機上
 * 物件會縮到三分之一並擠向左上角。
 */
@Composable
fun Model3DLayer(
    interactive: Boolean,
    models: List<Model3DObject>,
    density: Float,
    selectedId: String?,
    onSelect: (String?) -> Unit,
    onEdit: (Model3DObject) -> Unit,
    onChanged: (Model3DObject) -> Unit,
    zIndexOf: (String) -> Float
) {
    // 不包一層自己的 Box —— zIndex 只在同一個父容器的兄弟之間有效，
    // 包起來的話 3D 模型永遠只能跟 3D 模型比順序（見 ChartLayer 的說明）。
    for (model in models) {
        Model3DView(
            model = model,
            density = density,
            isSelected = model.id == selectedId,
            interactive = interactive,
            zIndex = zIndexOf(model.id),
            onSelect = onSelect,
            onEdit = onEdit,
            onChanged = onChanged
        )
    }
}

@Composable
private fun Model3DView(
    model: Model3DObject,
    density: Float,
    isSelected: Boolean,
    interactive: Boolean,
    zIndex: Float,
    onSelect: (String?) -> Unit,
    onEdit: (Model3DObject) -> Unit,
    onChanged: (Model3DObject) -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    Box(
        Modifier
            .offset(model.x.dp, model.y.dp)
            .zIndex(zIndex)
            .size(model.width.dp, model.height.dp)
            .border(
                if (isSelected) 1.5.dp else 0.dp,
                MaterialTheme.colorScheme.primary,
                RoundedCornerShape(8.dp)
            )
            .gesturesIf(interactive) {
                pointerInput(model.id) {
                    detectTapGestures(
                        onTap = { onSelect(model.id) },
                        onDoubleTap = { onEdit(model) }
                    )
                }
            }
            .gesturesIf(interactive) {
                pointerInput(model.id) {
                    detectDragGestures { change, drag ->
                        change.consume()
                        onChanged(
                            model.copy(
                                x = model.x + drag.x / density,
                                y = model.y + drag.y / density
                            )
                        )
                    }
                }
            }
    ) {
        // 匯入的模型現在**畫得出來**。
        //
        // 這裡原本是一張寫著檔名的卡片，註解寫的是「Android 沒有內建的
        // USDZ／GLB 算繪器」。那句話把問題描述錯了：核心裡一直都有一個
        // 完整的軟體算繪器（投影、明暗、深度排序），缺的只是「檔案 → 網格」
        // 那一段 —— 而 Apple 端當時是繞過核心、私接 SceneKit，所以只有
        // 那一邊看得到。現在兩端走同一條路。
        //
        // 卡片沒有拿掉，因為它還有一個真正的用途：檔案還沒從雲端同步下來
        // （或壞了）的時候，讓使用者看得到那個物件在那裡、搬得動、改得了
        // 邊框，而不是整個不見。
        val importedName = model.importedDisplayName ?: model.importedFileName
        val importedMesh = model.importedFileName?.let {
            ImportedModelCache.get(context, it)
        }
        if (importedMesh != null) {
            Canvas(Modifier.size(model.width.dp, model.height.dp)) {
                Model3DRenderer.draw(this, model, size.width, size.height, importedMesh)
            }
        } else if (importedName != null) {
            androidx.compose.foundation.layout.Column(
                modifier = Modifier
                    .size(model.width.dp, model.height.dp)
                    .testTag("model3d.imported_placeholder"),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("🧊", style = MaterialTheme.typography.headlineMedium)
                Text(
                    importedName,
                    style = MaterialTheme.typography.labelMedium,
                    maxLines = 2
                )
            }
        } else {
            Canvas(Modifier.size(model.width.dp, model.height.dp)) {
                Model3DRenderer.draw(this, model, size.width, size.height)
            }
        }

        if (model.title.isNotBlank()) {
            Text(
                model.title,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.align(Alignment.BottomCenter)
            )
        }

        if (isSelected && interactive) {
            // 樣式鈕：**既有**模型也要改得到設定。只有新增時才開得起編輯器的話，
            // 插完就等於定案了（文字方塊犯過一次這個錯）。
            StyleHandle(
                widthDp = model.width,
                heightDp = model.height,
                onTap = { onEdit(model) }
            )

            ResizeHandle(
                widthDp = model.width,
                heightDp = model.height,
                density = density,
                onResize = { dw, dh ->
                    model.width = maxOf(MIN_OBJECT_WIDTH_DP, model.width + dw)
                    model.height = maxOf(MIN_OBJECT_HEIGHT_DP, model.height + dh)
                },
                onCommit = { onChanged(model) }
            )
        }
    }
}

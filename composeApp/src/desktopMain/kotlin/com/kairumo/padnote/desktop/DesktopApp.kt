package com.kairumo.padnote.desktop

import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.input.key.*
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun DesktopWorkspace(
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onSearch: () -> Unit,
    onPointerEvent: (x: Float, y: Float, pressure: Float) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            // 1. 桌面版鍵盤快捷鍵 (Keyboard Shortcuts)
            .onPreviewKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown) {
                    when {
                        event.isCtrlPressed && event.key == Key.Z -> {
                            if (event.isShiftPressed) onRedo() else onUndo()
                            true
                        }
                        event.isCtrlPressed && event.key == Key.F -> {
                            onSearch()
                            true
                        }
                        else -> false
                    }
                } else {
                    false
                }
            }
            // 2. 桌面版外接繪圖板 / 滑鼠壓感 (Wacom/Tablet integration)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        if (event.type == PointerEventType.Move || event.type == PointerEventType.Press) {
                            val change = event.changes.firstOrNull()
                            if (change != null) {
                                // Extract position and pressure (Wacom tablets provide pressure on desktop)
                                val x = change.position.x
                                val y = change.position.y
                                val pressure = change.pressure
                                onPointerEvent(x, y, pressure)
                            }
                        }
                    }
                }
            }
    ) {
        // Render Canvas or other UI here
    }
}

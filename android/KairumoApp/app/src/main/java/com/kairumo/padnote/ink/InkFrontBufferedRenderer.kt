package com.kairumo.padnote.ink

import android.view.MotionEvent
import android.view.SurfaceView
import androidx.graphics.lowlatency.GLFrontBufferedRenderer
import androidx.graphics.opengl.egl.EGLManager

class InkFrontBufferedRenderer(surfaceView: SurfaceView) {
    private val callbacks = object : GLFrontBufferedRenderer.Callback<MotionEvent> {
        override fun onDrawFrontBufferedLayer(
            eglManager: EGLManager,
            bufferInfo: androidx.graphics.opengl.egl.EGLManager.BufferInfo,
            transform: FloatArray,
            param: MotionEvent
        ) {
            // Front buffer: render the *current* stroke as the user is drawing it.
            // This runs in a background thread and presents immediately.
            val x = param.x
            val y = param.y
            val pressure = param.pressure
            val tilt = param.getAxisValue(MotionEvent.AXIS_TILT)
            val orientation = param.getAxisValue(MotionEvent.AXIS_ORIENTATION)
            
            // TODO: Call into padnote-render (Rust via JNI/uniffi) to draw the raw stroke segment
        }

        override fun onDrawDoubleBufferedLayer(
            eglManager: EGLManager,
            bufferInfo: androidx.graphics.opengl.egl.EGLManager.BufferInfo,
            transform: FloatArray,
            params: Collection<MotionEvent>
        ) {
            // Double buffer: render *committed* strokes.
            // When the user lifts the stylus (ACTION_UP), we commit the stroke to the document,
            // and re-render the entire canvas here.
        }
    }

    private val frontBufferedRenderer = GLFrontBufferedRenderer(surfaceView, callbacks)

    fun onTouchEvent(event: MotionEvent): Boolean {
        // 辨識是否為觸控筆 (Stylus / S Pen)
        val isStylus = event.getToolType(0) == MotionEvent.TOOL_TYPE_STYLUS
        
        // 擷取 S Pen 側邊按鈕
        val isEraserButtonPressed = (event.buttonState and MotionEvent.BUTTON_STYLUS_PRIMARY) != 0

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                if (isStylus) {
                    // Send directly to the front buffer renderer for ultra low latency (<9ms target)
                    frontBufferedRenderer.renderFrontBufferedLayer(event)
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isStylus) {
                    frontBufferedRenderer.commit()
                }
            }
            MotionEvent.ACTION_HOVER_MOVE -> {
                // S Pen 懸停 (Hover)
                if (isStylus) {
                    // TODO: 顯示預覽游標或工具提示
                }
            }
        }
        return true
    }
}

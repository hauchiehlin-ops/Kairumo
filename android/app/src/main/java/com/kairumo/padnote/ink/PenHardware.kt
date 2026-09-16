package com.kairumo.padnote.ink

import android.content.Context
import android.view.MotionEvent
import uniffi.padnote_core.FfiPenControl
import uniffi.padnote_core.PenControls

/**
 * 觸控筆硬體：筆桿側鍵、反向筆頭、滾動角與懸停（工作項 S-40 / S-67 / S-69）。
 *
 * # 規則不在這裡
 *
 * 「按下去要發生什麼」整張表在核心的 `padnote-input::pen`，與 Apple 共用。
 * 這個檔案只做兩件事：把 `MotionEvent` 上的位元翻成核心認得的
 * [FfiPenControl]，以及把設定存進 SharedPreferences。
 *
 * 原本這裡有一份自己的規則（`StylusButton`），Apple 那邊有另一份
 * （`PencilDoubleTap.swift`）。同一支筆在兩台裝置上行為不同是遲早的事，
 * 所以那兩份都被核心那一張表取代了。
 *
 * # Android 沒有的、與 Android 才有的
 *
 * - **沒有雙擊與擠壓**：那是 Apple Pencil 的硬體特性，系統層不會產生事件。
 * - **有側鍵**：`BUTTON_STYLUS_PRIMARY` 與 `BUTTON_STYLUS_SECONDARY`。
 *   多數主動式觸控筆與數位板筆都有，這是 Android 這一側的主要入口。
 * - **有滾動角**：`AXIS_TILT` 旁邊沒有滾動角的標準軸，但部分數位板會透過
 *   `AXIS_GENERIC_*` 回報。**我們不猜** —— 沒有標準軸就當作沒有，猜錯的話
 *   扁頭筆的筆觸方向會被一個不相干的旋鈕控制。
 *
 * # 實機校準
 *
 * `buttonState` 要實體觸控筆才發得出來（模擬器沒有，`adb input` 也送不出），
 * 數位板還要接上才知道它把哪顆鍵送成哪個位元。見 TODO 的 S-40 / A-14。
 */
object PenHardware {

    private const val PREFS = "kairumo_pen"
    private const val KEY_CONTROLS = "controls_v1"

    /**
     * 核心那一份表。**唯一的來源** —— 這邊不另外快取一份 Kotlin 的副本，
     * 兩份狀態一定會有一個先改到。
     */
    fun controls(context: Context): PenControls {
        val saved = prefs(context).getString(KEY_CONTROLS, null)
        return if (saved.isNullOrBlank()) PenControls() else PenControls.decode(saved)
    }

    fun save(context: Context, controls: PenControls) {
        prefs(context).edit().putString(KEY_CONTROLS, controls.encode()).apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * 這個事件上按著哪一個筆身控制項。沒有的話回 `null`。
     *
     * 一次只回一個：兩顆鍵同時按著是誤觸，不是一個有意義的組合。同時處理
     * 兩個的話，工具會在兩種狀態之間跳。主鍵優先 —— 它是使用者真的會用的那顆。
     */
    fun control(toolType: Int, buttonState: Int): FfiPenControl? = when {
        // 反向筆頭排最前：筆倒過來的時候，就算側鍵也按著，使用者要的也是擦。
        toolType == MotionEvent.TOOL_TYPE_ERASER -> FfiPenControl.INVERT
        buttonState and MotionEvent.BUTTON_STYLUS_PRIMARY != 0 -> FfiPenControl.BARREL_PRIMARY
        buttonState and MotionEvent.BUTTON_STYLUS_SECONDARY != 0 -> FfiPenControl.BARREL_SECONDARY
        else -> null
    }

    fun control(event: MotionEvent): FfiPenControl? =
        control(event.getToolType(0), event.buttonState)

    /**
     * 這個事件是不是**懸停**（筆靠近但還沒碰到）。
     *
     * 核心的仲裁器早就有 `Verdict.HOVER`，說明寫著「顯示落筆預覽」——
     * 但在這之前沒有任何地方真的畫過那個預覽。
     */
    fun isHover(event: MotionEvent): Boolean = when (event.actionMasked) {
        MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE -> true
        else -> false
    }

    fun isHoverExit(event: MotionEvent): Boolean =
        event.actionMasked == MotionEvent.ACTION_HOVER_EXIT
}

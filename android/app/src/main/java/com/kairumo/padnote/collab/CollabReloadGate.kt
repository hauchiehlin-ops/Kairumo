package com.kairumo.padnote.collab

/**
 * 別台（Drive／區網）改了正開著的這一本時，要不要現在重開 session（設計 §7）。
 *
 * 協同中**不重開**：重開會把引擎與物件換成套件的合併結果，房間裡這台的內容跟著變，
 * 而協同的影子以為那些差異「大家都有」，不會送出 —— 這台從此與房間分歧。房間裡的內容本來就是即時的；
 * 檔案同步帶來的（不在房間裡的裝置寫的）記下來，離開房間時重開一次、合併進來。自己的檔照常上傳。
 */
class CollabReloadGate {
    /** 協同期間略過了重開。 */
    var owed: Boolean = false
        private set

    /** 別台同步改了這一本：回傳要不要現在重開。協同中只記下欠一次。 */
    fun onRemoteChange(collaborating: Boolean): Boolean {
        if (collaborating) {
            owed = true
            return false
        }
        return true
    }

    /** 協同狀態變了：剛離開房間而且欠著一次，回傳 `true`（現在補一次重開）。 */
    fun onCollaborationChanged(collaborating: Boolean): Boolean {
        if (collaborating || !owed) return false
        owed = false
        return true
    }
}

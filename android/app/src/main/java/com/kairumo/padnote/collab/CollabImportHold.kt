package com.kairumo.padnote.collab

/**
 * 正在即時協同的那一本：檔案同步（Drive 焦點通道、區網直連）**先不動它的套件**，離開房間再補（與 Apple 同名型別相同）。
 *
 * Android 的套件就是工作資料：同步一下載就直接寫進正開著的這一本。協同中編輯器不重開 session
 * （見 [CollabReloadGate]），畫布停在房間的即時內容；但側欄縮圖、匯出每次都重讀套件 ——
 * 別台較舊的筆畫檔一寫進來，縮圖就出現畫布上沒有的舊筆跡（實機：同一 Wi‑Fi 協作時，
 * 協作者 Android 的預覽頁出現以前版本的筆跡，與畫布不同，違反 I4）。
 *
 * 協同中這一本的同步整輪略過（自己的修改留在套件裡，離開房間後照常上傳），區網也不收、不送這一本。
 * 只記開著、正在協同的那一本。
 */
// profile-scope: device 只記開著、正在協同的那一本；切換設定檔會先關掉編輯器（onDispose 放掉）
object CollabImportHold {
    private val lock = Any()
    private val held = HashSet<String>()
    private val deferred = HashSet<String>()

    fun hold(notebookId: String) = synchronized(lock) { held += notebookId.lowercase() }

    /** 離開房間。回傳協同期間有沒有略過同步（有的話呼叫端要補一輪）。 */
    fun release(notebookId: String): Boolean = synchronized(lock) {
        val id = notebookId.lowercase()
        held -= id
        deferred.remove(id)
    }

    fun isHeld(notebookId: String): Boolean = synchronized(lock) { notebookId.lowercase() in held }

    /** 同步要動這一本時問一下：在協同中就記下「欠一次」並回 `true`（呼叫端略過）。 */
    fun deferIfHeld(notebookId: String): Boolean = synchronized(lock) {
        val id = notebookId.lowercase()
        if (id !in held) return false
        deferred += id
        true
    }
}

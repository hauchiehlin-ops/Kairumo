package com.kairumo.padnote.collab

import com.kairumo.padnote.ink.InkEngine

/**
 * 連續頁面模式把每一頁的筆跡引擎與物件儲存交給協同。
 *
 * 那些引擎與儲存住在 `ContinuousPagesView` 的快取裡（捲出畫面的頁面復原紀錄才不會不見）——
 * 協同寫回別人的修改要寫進**它們**，畫面才會變；比對本機的修改也要讀它們，否則讀到的是舊的。
 * 由 `ContinuousPagesView` 填上，編輯器讀用。
 */
class ContinuousCollabBridge {
    /** 已載入筆跡的那一頁的引擎。 */
    var engineFor: (String) -> InkEngine? = { null }
    /** 那一頁的物件儲存。 */
    var storesFor: (String) -> CollabPageStores? = { null }
    /** 畫面上載入過的頁面 id。 */
    var loadedPages: () -> List<String> = { emptyList() }
    /** 別人的修改寫回之後：以新內容為復原基準（不變成本機的復原步驟）並重畫。 */
    var remoteApplied: () -> Unit = {}
    /** 本機在連續模式裡改了東西（物件或筆跡）：編輯器據此送出。 */
    var onLocalChange: (() -> Unit)? = null
}

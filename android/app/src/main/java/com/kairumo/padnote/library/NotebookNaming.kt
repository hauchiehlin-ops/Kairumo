package com.kairumo.padnote.library

import java.util.Calendar
import java.util.Locale

/**
 * 新筆記本的預設名稱：建立時刻的「時-分-秒-New」，例如 `23-30-15-New`。
 *
 * 24 小時制、補零、以連字號分隔 —— 冒號在 exFAT／Windows／Finder 不能當檔名，
 * 匯出與同步時會出錯。「New」不翻譯：各語系同一個格式，跨裝置看到的名稱一致。
 * Apple 端 `NotebookStore.newNotebookTitle` 是同一條規則。
 */
object NotebookNaming {
    fun newTitle(calendar: Calendar = Calendar.getInstance()): String = String.format(
        Locale.ROOT, "%02d-%02d-%02d-New",
        calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), calendar.get(Calendar.SECOND)
    )
}

package com.kairumo.padnote.profile

import android.app.Activity
import android.content.Context
import com.kairumo.padnote.sync.FocusSync
import kotlinx.coroutines.withTimeoutOrNull

/**
 * 切換設定檔（Android）。
 *
 * # 為什麼 Android 是「重啟行程」，Apple 是「就地重設」
 *
 * iOS 不允許 App 自己重啟，所以 Apple 端要把 25 個單例逐一重設。Android 可以乾淨地重啟行程，
 * 而重啟是**唯一能保證**記憶體裡（92 個單例、Compose 的 `remember`、各種快取）沒有任何東西
 * 留給下一個使用者的做法 —— 不必證明「每一個都重設了」，因為它們根本不存在了。
 * 代價是切換要多一次冷啟動（約一兩秒）；換來的是這一整類錯誤不可能發生。
 *
 * # 順序
 *
 * 1. 盡量把還沒上傳的最後一筆推上去（最多 3 秒，不為它拖住切換）。
 * 2. **先寫名單、後改 context**，兩個都用同步寫入（`commit()`）；名單寫不進去就整個放棄，什麼都沒變。
 * 3. 重啟行程：新行程啟動時讀到的就是新的設定檔。
 *
 * 進行中的同步會被一起結束 —— 這與系統回收行程相同，同步協定本來就容許（每個檔案原子寫入）。
 */
class ProfileSwitcher(private val hooks: Hooks = Hooks.Default) {

    sealed class Result {
        object Switched : Result()
        object AlreadyActive : Result()
        object UnknownProfile : Result()
        object RegistryNotSaved : Result()
    }

    interface Hooks {
        /** 把還沒推上雲端的編輯盡量推出去。實作要自己限時。 */
        suspend fun flushPending(context: Context)
        fun saveRegistry(context: Context, registry: ProfileRegistry): Boolean
        fun setActive(context: Context, id: String)
        fun restart(activity: Activity)

        object Default : Hooks {
            override suspend fun flushPending(context: Context) {
                withTimeoutOrNull(FLUSH_TIMEOUT_MS) { FocusSync.flushUnpushed(context) }
            }

            override fun saveRegistry(context: Context, registry: ProfileRegistry) =
                ProfileManager.save(context, registry)

            override fun setActive(context: Context, id: String) = ProfileContext.setActive(context, id)

            override fun restart(activity: Activity) = ProfileRestartActivity.restart(activity)
        }
    }

    suspend fun switchTo(activity: Activity, id: String): Result {
        val current = ProfileManager.registry(activity)
        if (id == current.activeId) return Result.AlreadyActive
        if (current.profile(id) == null) return Result.UnknownProfile

        hooks.flushPending(activity)

        val next = ProfileRegistry.fromJson(current.toJson()) ?: return Result.RegistryNotSaved
        next.activate(id)
        if (!hooks.saveRegistry(activity, next)) return Result.RegistryNotSaved
        hooks.setActive(activity, id)

        hooks.restart(activity)
        return Result.Switched
    }

    companion object {
        /** 最後一筆編輯推上雲端的時間上限。 */
        const val FLUSH_TIMEOUT_MS = 3_000L
    }
}

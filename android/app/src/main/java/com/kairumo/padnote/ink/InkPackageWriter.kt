package com.kairumo.padnote.ink

import android.os.Handler
import android.os.Looper
import android.util.Log
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
import java.util.concurrent.Executors
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantReadWriteLock
import java.util.ArrayDeque

/** Serializes ink package mutations away from the UI thread. */
// profile-scope: device 只記寫入佇列裡還在路上的筆畫 id；切換設定檔時行程重啟，佇列跟著清空
internal object InkPackageWriter {
    private val executor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "kairumo-ink-package-writer").apply { isDaemon = true }
    }
    private val main = Handler(Looper.getMainLooper())
    private val packageGate = ReentrantReadWriteLock(true)

    // Accessed only on [executor]. Keep a failed operation at the head so a later
    // erase cannot overtake its add, and sync cannot pass an unfinished mutation.
    private val pendingMutations = ArrayDeque<() -> Unit>()

    // 已排進佇列、還沒寫進套件的筆畫 id。呼叫端（主執行緒）排入時登記，寫入成功後才拿掉。
    //
    // 重讀核心（換 session、套索之後、切回整頁）讀到的是**寫入之前**的套件：剛畫完的那幾筆
    // 不在裡面，剛擦掉的那幾筆還在裡面。不知道哪些還在路上的話，只能二選一 —— 全部照讀回來的
    // （剛寫的字消失、過一會兒再出現），或全部保留記憶體裡的（別台擦掉的筆畫永遠擦不掉）。
    // 有這兩份名單就能逐筆判斷，見 `InkEngine.applyLoaded`。
    private val pendingAdds: MutableSet<String> = java.util.concurrent.ConcurrentHashMap.newKeySet()
    private val pendingErases: MutableSet<String> = java.util.concurrent.ConcurrentHashMap.newKeySet()

    /** 排進佇列、還沒寫進套件的一筆（側欄縮圖先把它疊上去，見 [pendingStrokes]）。 */
    class PendingStroke(
        val pageId: String,
        val tool: ToolKind,
        val colorRgba: ByteArray,
        val baseWidth: Float,
        val points: List<StrokePoint>
    )

    // 還在路上的筆畫內容。縮圖是從套件算繪的：同步正拿著套件鎖時（上傳、整庫同步），剛畫完的筆畫
    // 要等鎖放開才寫得進去，縮圖跟著晚好幾秒。把還沒寫進去的筆畫疊在縮圖上，縮圖就不必等同步。
    private val pending = java.util.concurrent.ConcurrentHashMap<String, PendingStroke>()

    /** 有筆畫排進佇列就加一（主執行緒）。縮圖以它為鍵重畫；寫完之後由 `onContentCommitted` 再重畫一次。 */
    val pendingVersion = androidx.compose.runtime.mutableIntStateOf(0)

    /** 這一頁還沒寫進套件的筆畫，依排入順序。 */
    fun pendingStrokes(pageId: String): List<PendingStroke> =
        pendingOrder.mapNotNull { id -> pending[id]?.takeIf { it.pageId == pageId } }

    private val pendingOrder = java.util.concurrent.CopyOnWriteArrayList<String>()

    /** 這一筆的新增還沒寫進套件。 */
    fun isAddPending(strokeId: String): Boolean = strokeId in pendingAdds

    /** 這一筆的擦除還沒寫進套件。 */
    fun isErasePending(strokeId: String): Boolean = strokeId in pendingErases

    fun add(
        session: PadnoteSession,
        pageId: String,
        strokeId: String,
        tool: ToolKind,
        colorRgba: ByteArray,
        baseWidth: Float,
        points: List<StrokePoint>,
        layer: UByte,
        lineType: UByte,
    ) {
        val color = colorRgba.copyOf()
        val snapshot = points.toList()
        pendingAdds += strokeId
        pending[strokeId] = PendingStroke(pageId, tool, color, baseWidth, snapshot)
        pendingOrder += strokeId
        pendingVersion.intValue++
        enqueueMutation {
            packageGate.readLock().lock()
            try {
                session.addStrokeDraftedWithId(
                    pageId, strokeId, tool, color, baseWidth, snapshot, layer, lineType
                )
            } finally {
                packageGate.readLock().unlock()
            }
            pendingAdds -= strokeId
            pending.remove(strokeId)
            pendingOrder.remove(strokeId)
        }
    }

    fun erase(session: PadnoteSession, pageId: String, strokeId: String) {
        pendingErases += strokeId
        enqueueMutation {
            packageGate.readLock().lock()
            try {
                session.eraseStroke(pageId, strokeId)
            } finally {
                packageGate.readLock().unlock()
            }
            pendingErases -= strokeId
        }
    }

    /** Run a UI callback only after all earlier ink writes have completed. */
    fun afterWrites(callback: () -> Unit) {
        executor.execute {
            if (drainPendingMutations()) main.post(callback)
        }
    }

    /** Blocking counterpart for sync entry points that already run on Dispatchers.IO. */
    fun awaitIdleBlocking(timeoutMs: Long = 30_000L): Boolean {
        val done = CountDownLatch(1)
        var succeeded = false
        executor.execute {
            succeeded = drainPendingMutations()
            done.countDown()
        }
        if (!done.await(timeoutMs, TimeUnit.MILLISECONDS)) return false
        return succeeded
    }

    /** Excludes package mutation workers for the duration of a sync read/write pass. */
    fun <T> withSyncLock(action: () -> T): T {
        packageGate.writeLock().lock()
        return try {
            action()
        } finally {
            packageGate.writeLock().unlock()
        }
    }

    private fun recordFailure(error: Throwable) {
        Log.e("InkPackageWriter", "Failed to persist an ink package mutation", error)
    }

    private fun enqueueMutation(operation: () -> Unit) {
        executor.execute {
            pendingMutations.addLast(operation)
            drainPendingMutations()
        }
    }

    private fun drainPendingMutations(): Boolean {
        while (pendingMutations.isNotEmpty()) {
            val operation = pendingMutations.peekFirst() ?: break
            var failure: Throwable? = null
            var succeeded = false
            for (attempt in 0 until 3) {
                runCatching(operation)
                    .onSuccess { succeeded = true }
                    .onFailure { failure = it }
                if (succeeded) break
                if (!succeeded && attempt < 2) Thread.sleep(40L * (attempt + 1))
            }
            if (!succeeded) {
                recordFailure(failure ?: IllegalStateException("Ink write failed"))
                return false
            }
            pendingMutations.removeFirst()
        }
        return true
    }
}

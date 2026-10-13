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
internal object InkPackageWriter {
    private val executor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "kairumo-ink-package-writer").apply { isDaemon = true }
    }
    private val main = Handler(Looper.getMainLooper())
    private val packageGate = ReentrantReadWriteLock(true)

    // Accessed only on [executor]. Keep a failed operation at the head so a later
    // erase cannot overtake its add, and sync cannot pass an unfinished mutation.
    private val pendingMutations = ArrayDeque<() -> Unit>()

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
        enqueueMutation {
            packageGate.readLock().lock()
            try {
                session.addStrokeDraftedWithId(
                    pageId, strokeId, tool, color, baseWidth, snapshot, layer, lineType
                )
            } finally {
                packageGate.readLock().unlock()
            }
        }
    }

    fun erase(session: PadnoteSession, pageId: String, strokeId: String) {
        enqueueMutation {
            packageGate.readLock().lock()
            try {
                session.eraseStroke(pageId, strokeId)
            } finally {
                packageGate.readLock().unlock()
            }
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

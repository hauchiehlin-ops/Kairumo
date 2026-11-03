package com.kairumo.padnote.perf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class BackgroundSchedulerTest {
    @Test fun lowPriorityWaitsWhileInkIsBusyButInteractiveDoesNot() {
        val busy = AtomicBoolean(true)
        val scheduler = BackgroundScheduler(inkBusy = { busy.get() }, retryIntervalMs = 20L)
        val lowRan = CountDownLatch(1)
        val hiRan = CountDownLatch(1)
        val lowRanWhileBusy = AtomicBoolean(false)
        scheduler.submit(BackgroundPriority.Prefetch) { if (busy.get()) lowRanWhileBusy.set(true); lowRan.countDown() }
        scheduler.submit(BackgroundPriority.Interactive) { hiRan.countDown() }
        assertTrue("互動級不受書寫影響", hiRan.await(2, TimeUnit.SECONDS))
        Thread.sleep(150)
        busy.set(false)
        assertTrue("停手後預取要執行", lowRan.await(2, TimeUnit.SECONDS))
        assertFalse("書寫中預取必須暫停", lowRanWhileBusy.get())
    }

    @Test fun sameKeyIsNotQueuedTwiceWhileInFlight() {
        val scheduler = BackgroundScheduler(inkBusy = { false })
        val count = AtomicInteger()
        val gate = CountDownLatch(1)
        val done = CountDownLatch(1)
        scheduler.submit(BackgroundPriority.Prefetch, "k") { gate.await(); count.incrementAndGet(); done.countDown() }
        scheduler.submit(BackgroundPriority.Prefetch, "k") { count.incrementAndGet() }
        gate.countDown()
        assertTrue(done.await(2, TimeUnit.SECONDS))
        Thread.sleep(100)
        assertEquals(1, count.get())
    }

    @Test fun keyIsReleasedAfterTheWorkFinishes() {
        val scheduler = BackgroundScheduler(inkBusy = { false })
        val first = CountDownLatch(1)
        scheduler.submit(BackgroundPriority.Visible, "again") { first.countDown() }
        assertTrue(first.await(2, TimeUnit.SECONDS))
        Thread.sleep(50)
        val second = CountDownLatch(1)
        scheduler.submit(BackgroundPriority.Visible, "again") { second.countDown() }
        assertTrue("做完之後同一個 key 可以再排", second.await(2, TimeUnit.SECONDS))
    }
}

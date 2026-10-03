package com.kairumo.padnote.platform

import java.io.File
import java.nio.file.Files
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class StorageSweeperTest {
    private lateinit var dir: File
    private val now = 1_000_000_000_000L
    private val hour = 3_600_000L

    @Before fun setUp() { dir = Files.createTempDirectory("sweep").toFile() }
    @After fun tearDown() { dir.deleteRecursively() }

    private fun make(name: String, bytes: Int = 10, ageMs: Long): File =
        File(dir, name).apply { writeBytes(ByteArray(bytes)); setLastModified(now - ageMs) }

    @Test fun oldTempItemsAreStaleAndYoungOnesAreNot() {
        make("old.pdf", ageMs = 5 * hour)
        make("young.pdf", ageMs = hour / 5)
        assertEquals(listOf("old.pdf"), StorageSweeper.stale(dir, StorageSweeper.TEMP_MIN_AGE_MS, now).map { it.name })
    }

    @Test fun aFolderWithAFreshFileInsideIsNotStale() {
        val folder = File(dir, "import_active").apply { mkdirs() }
        File(folder, "a").apply { writeBytes(ByteArray(3)); setLastModified(now - hour / 10) }
        folder.setLastModified(now - 10 * hour)
        assertTrue(StorageSweeper.stale(dir, StorageSweeper.TEMP_MIN_AGE_MS, now).isEmpty())
    }

    @Test fun thumbnailsFolderIsSkippedByTheHourRule() {
        File(dir, "thumbnails").apply { mkdirs(); setLastModified(now - 99 * hour) }
        val stale = StorageSweeper.stale(dir, StorageSweeper.TEMP_MIN_AGE_MS, now, skip = { it == "thumbnails" })
        assertTrue(stale.isEmpty())
    }

    @Test fun onlyStalePartialsMatch() {
        make("m.partial", ageMs = 20 * 24 * hour)
        make("m2.partial", ageMs = 24 * hour)
        make("m.bin", ageMs = 90 * 24 * hour)
        val got = StorageSweeper.stale(dir, StorageSweeper.PARTIAL_MIN_AGE_MS, now) { it.endsWith(".partial") }
        assertEquals(listOf("m.partial"), got.map { it.name })
    }

    @Test fun thumbnailsOverBudgetAreEvictedOldestFirst() {
        val big = (StorageSweeper.THUMBNAIL_MAX_BYTES * 2 / 5).toInt()
        make("a.png", bytes = big, ageMs = 3 * 24 * hour)   // 最舊
        make("b.png", bytes = big, ageMs = 2 * 24 * hour)
        make("c.png", bytes = big, ageMs = 1 * 24 * hour)   // 最新
        val evict = StorageSweeper.overBudgetThumbnails(dir, now).map { it.name }
        assertEquals(listOf("a.png"), evict)
    }

    @Test fun thumbnailsOlderThanThirtyDaysAreEvicted() {
        make("old.png", ageMs = 31L * 24 * hour)
        make("new.png", ageMs = hour)
        assertEquals(listOf("old.png"), StorageSweeper.overBudgetThumbnails(dir, now).map { it.name })
    }
}

package com.kairumo.padnote.platform

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.util.UUID

class StorageJanitorTest {

    private lateinit var root: File
    private lateinit var attachments: File
    private lateinit var drawings: File
    private lateinit var baseline: File
    private val now = 1_000_000_000_000L
    private val day = 24 * 3600 * 1000L

    @Before
    fun setUp() {
        root = Files.createTempDirectory("janitor-test").toFile()
        attachments = File(root, "Attachments").apply { mkdirs() }
        drawings = File(root, "Drawings").apply { mkdirs() }
        baseline = File(root, "SyncBaseline").apply { mkdirs() }
    }

    @After
    fun tearDown() {
        root.deleteRecursively()
    }

    private fun write(name: String, inDir: File, bytes: Int = 100, ageDays: Double): File {
        val f = File(inDir, name)
        f.writeBytes(ByteArray(bytes))
        f.setLastModified((now - ageDays * day).toLong())
        return f
    }

    @Test
    fun testOnlyRecognisedFileNamesAreEverTouched() {
        val validUuid = UUID.randomUUID().toString()
        assertTrue(StorageJanitor.isAttachmentImageName("att_$validUuid.png"))
        assertFalse(StorageJanitor.isAttachmentImageName("imp_$validUuid.usdz"))
        assertFalse(StorageJanitor.isAttachmentImageName("att_notauuid.png"))
        assertFalse(StorageJanitor.isAttachmentImageName("photo.png"))

        assertEquals(StorageJanitor.PageFile("abc", 3), StorageJanitor.pageFile("abc_p3.drawing"))
        assertEquals(StorageJanitor.PageFile("a_b", 10), StorageJanitor.pageFile("a_b_p10.proink.json"))
        assertNull(StorageJanitor.pageFile("notes.json"))
        assertNull(StorageJanitor.pageFile("abc_pX.drawing"))
    }

    @Test
    fun testAnUnreferencedOldAttachmentImageIsCleaned() {
        val orphan = "att_${UUID.randomUUID()}.png"
        val used = "att_${UUID.randomUUID()}.png"
        write(orphan, attachments, bytes = 5_000, ageDays = 10.0)
        write(used, attachments, ageDays = 10.0)

        val nb = StorageJanitor.NotebookInfo(id = "nb1", pageCount = 2)
        val plan = StorageJanitor.plan(
            attachmentsDirectory = attachments,
            pageDirectories = listOf(drawings, baseline),
            notebooks = listOf(nb),
            protectedIds = emptySet(),
            referencedAttachments = setOf(used),
            nowMs = now
        )

        val names = plan.files.map { it.name }.toSet()
        assertEquals(setOf(orphan), names)
        assertEquals(5_000L, plan.bytes)

        val (count, freed) = StorageJanitor.execute(plan)
        assertEquals(1, count)
        assertEquals(5_000L, freed)
        assertFalse(File(attachments, orphan).exists())
        assertTrue(File(attachments, used).exists())
    }

    @Test
    fun testRecentAttachmentImageIsProtected() {
        val recent = "att_${UUID.randomUUID()}.png"
        write(recent, attachments, bytes = 5_000, ageDays = 0.5) // 0.5 day old < 3 days

        val nb = StorageJanitor.NotebookInfo(id = "nb1", pageCount = 2)
        val plan = StorageJanitor.plan(
            attachmentsDirectory = attachments,
            pageDirectories = listOf(drawings, baseline),
            notebooks = listOf(nb),
            protectedIds = emptySet(),
            referencedAttachments = emptySet(),
            nowMs = now
        )

        assertTrue(plan.files.isEmpty())
    }

    @Test
    fun testEmptyPageExceedingPageCountIsCleaned() {
        val emptyPage = "nb1_p5.proink.json" // page 5 > 2
        val f = File(drawings, emptyPage)
        f.writeText("[]")
        f.setLastModified(now - 5 * day)

        val activePage = "nb1_p1.proink.json" // page 1 <= 2
        val fActive = File(drawings, activePage)
        fActive.writeText("[]")
        fActive.setLastModified(now - 5 * day)

        val nb = StorageJanitor.NotebookInfo(id = "nb1", pageCount = 2)
        val plan = StorageJanitor.plan(
            attachmentsDirectory = attachments,
            pageDirectories = listOf(drawings, baseline),
            notebooks = listOf(nb),
            protectedIds = emptySet(),
            referencedAttachments = emptySet(),
            nowMs = now
        )

        val names = plan.files.map { it.name }.toSet()
        assertEquals(setOf(emptyPage), names)
    }
}

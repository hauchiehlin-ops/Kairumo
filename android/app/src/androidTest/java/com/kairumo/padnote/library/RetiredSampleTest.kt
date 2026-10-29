package com.kairumo.padnote.library

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.profile.ProfileContext
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 舊版「轉成一般筆記」把範例記進退役名單，範例改成唯讀之後名單沒人清 ——
 * 被轉過的那本從此補不回來（使用者回報：Mac 永遠少一本《Kairumo(功能範例)》）。
 */
@RunWith(AndroidJUnit4::class)
class RetiredSampleTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val device = 0xE8u
    private val showcaseId = "seed-feature-showcase-v1"

    @Before
    @After
    fun clean() {
        NotebookLibrary.directory(context).deleteRecursively()
        NotebookTrash.directory(context).deleteRecursively()
        File(context.filesDir, "Notebooks").deleteRecursively()
        AccountSyncStore.clearForTesting(context)
        ProfileContext.prefs(context, "kairumo.seed").edit().clear().commit()
        NotebookLibrary.invalidateCache()
    }

    private fun hasShowcase() = NotebookLibrary.all(context, device).any { it.id.equals(showcaseId, ignoreCase = true) }

    @Test
    fun aSampleRetiredByTheOldConvertFeatureComesBack() {
        NotebookLibrary.create(context, "我的筆記", device)
        SeedNotebooks.seedIfEmpty(context, device, "zh-Hant")
        assertTrue("前提：範例存在", hasShowcase())

        // 舊版轉換：範例套件拿掉、退役名單記下，轉出來的那本沿用同一個名字。
        File(NotebookLibrary.directory(context), "$showcaseId.${NotebookLibrary.EXTENSION}").deleteRecursively()
        SampleFork.retireForTesting(context, showcaseId)
        NotebookLibrary.create(context, LocalizationStrings.localized("seed_feature_showcase_title", "zh-Hant"), device)
        NotebookLibrary.invalidateCache()

        SeedNotebooks.seedIfEmpty(context, device, "zh-Hant")

        assertTrue("退役的範例沒有補回來", hasShowcase())
        assertTrue("退役名單沒有清掉", SampleFork.retiredForTesting(context).isEmpty())
    }

    @Test
    fun aRetiredSampleThatIsInTheTrashStaysThere() {
        NotebookLibrary.create(context, "我的筆記", device)
        SeedNotebooks.seedIfEmpty(context, device, "zh-Hant")
        assertTrue("前提：範例移進回收桶", NotebookTrash.moveToTrash(context, showcaseId))
        SampleFork.retireForTesting(context, showcaseId)
        NotebookLibrary.invalidateCache()

        SeedNotebooks.seedIfEmpty(context, device, "zh-Hant")

        assertFalse("回收桶裡的範例被補回清單", hasShowcase())
    }
}

package com.kairumo.padnote.library

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/**
 * 回收桶的檔案搬移（`docs/plans/expiry-purge.md`）。
 *
 * 與 Apple 端的 `NotebookTrashTests` 是同一組檢查。
 *
 * # 這組測試守的是什麼
 *
 * 軟刪除把套件**搬到 `trash/`**，而不是留在原地打記號。清單與同步都靠列舉
 * `notebooks/`，任何一處漏判「已在回收桶」，這本筆記就會被當成新筆記匯回來 ——
 * 刪掉的東西自己復活。所以最重要的一條性質是：**進了回收桶的套件，不在
 * `notebooks/` 底下。**
 *
 * 只測「搬檔案」這一層（[NotebookTrash.moveToTrash] / [NotebookTrash.restoreLocally] /
 * [NotebookTrash.purgeLocally]），不碰同步索引，所以測試跑完不會在裝置上留下墓碑。
 * 用一次性的隨機 id，測完自己清掉。
 */
@RunWith(AndroidJUnit4::class)
class NotebookTrashTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val created = mutableListOf<String>()

    private fun newId(): String = "trash-test-${UUID.randomUUID()}".also { created += it }

    /** 在 `notebooks/` 底下放一個有內容的套件目錄。 */
    private fun seed(id: String): File {
        val dir = File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}")
        dir.mkdirs()
        File(dir, "marker.txt").writeText("payload:$id")
        return dir
    }

    private fun live(id: String) =
        File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}")

    private fun trashed(id: String) =
        File(NotebookTrash.directory(context), "$id.${NotebookLibrary.EXTENSION}")

    @After
    fun cleanUp() {
        created.forEach { NotebookTrash.purgeLocally(context, it) }
    }

    @Test
    fun trashingMovesThePackageOutOfTheLiveDirectory() {
        val id = newId()
        seed(id)

        assertTrue(NotebookTrash.moveToTrash(context, id))

        assertFalse("套件要離開 notebooks/", live(id).exists())
        assertEquals("payload:$id", File(trashed(id), "marker.txt").readText())
        assertTrue(NotebookTrash.trashedIds(context).contains(id))
    }

    /** 最重要的一條。清單與同步靠列舉 notebooks/；回收桶裡的套件不能出現在裡面。 */
    @Test
    fun aTrashedPackageIsInvisibleToTheLibraryListing() {
        val id = newId()
        seed(id)
        NotebookTrash.moveToTrash(context, id)

        val listed = NotebookLibrary.directory(context).listFiles()?.map { it.name } ?: emptyList()
        assertFalse(
            "回收桶裡的套件出現在會被列舉的目錄裡 —— 它會被當成新筆記匯回來",
            listed.contains("$id.${NotebookLibrary.EXTENSION}")
        )
    }

    @Test
    fun trashingSomethingThatDoesNotExistDoesNothing() {
        assertFalse(NotebookTrash.moveToTrash(context, newId()))
    }

    @Test
    fun restoringPutsThePackageBackUnchanged() {
        val id = newId()
        seed(id)
        NotebookTrash.moveToTrash(context, id)

        assertTrue(NotebookTrash.restoreLocally(context, id))

        assertEquals("payload:$id", File(live(id), "marker.txt").readText())
        assertFalse("回收桶不該留殘骸", trashed(id).exists())
    }

    @Test
    fun restoringSomethingNotInTheTrashDoesNothing() {
        assertFalse(NotebookTrash.restoreLocally(context, newId()))
    }

    @Test
    fun restoringNeverOverwritesALiveNotebookWithTheSameId() {
        // 不該發生，但發生了：`notebooks/` 裡已經有同 id 的（例如重新抓下來的）。
        // 那是使用者正在用的那一本，不能被回收桶裡較舊的副本蓋掉。
        val id = newId()
        seed(id)
        NotebookTrash.moveToTrash(context, id)
        File(seed(id), "marker.txt").writeText("newer")

        assertFalse(NotebookTrash.restoreLocally(context, id))
        assertEquals("newer", File(live(id), "marker.txt").readText())
    }

    @Test
    fun purgingRemovesEveryCopy() {
        val id = newId()
        seed(id)
        NotebookTrash.moveToTrash(context, id)

        NotebookTrash.purgeLocally(context, id)

        assertFalse(trashed(id).exists())
        assertFalse(live(id).exists())
        assertFalse("永久刪除之後不可能還原", NotebookTrash.restoreLocally(context, id))
    }

    // **不測 `NotebookTrash.empty`。** 它會清空整個 App 的回收桶 —— 儀器測試跑在
    // 真正的 `filesDir` 上，那會把裝置上使用者真正在回收桶裡的東西一起刪掉。
    // Apple 端用獨立的暫存目錄 store，所以 `NotebookTrashTests` 有測。
}

package com.kairumo.padnote.collab

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 協同中收到檔案同步：不重開 session（不覆蓋房間裡的內容），離開房間補一次。 */
class CollabReloadGateTest {

    @Test fun outsideARoomASyncReloadsAtOnce() {
        val gate = CollabReloadGate()
        assertTrue(gate.onRemoteChange(collaborating = false))
        assertFalse("沒欠就不必補", gate.onCollaborationChanged(collaborating = false))
    }

    @Test fun inARoomASyncWaitsUntilLeaving() {
        val gate = CollabReloadGate()
        assertFalse("協同中重開會把房間裡的內容換成套件的合併結果", gate.onRemoteChange(collaborating = true))
        assertFalse(gate.onRemoteChange(collaborating = true))
        assertFalse("還在房間裡（例如斷線重連）不補", gate.onCollaborationChanged(collaborating = true))
        assertTrue("離開房間補一次", gate.onCollaborationChanged(collaborating = false))
        assertFalse("只補一次", gate.onCollaborationChanged(collaborating = false))
    }
}

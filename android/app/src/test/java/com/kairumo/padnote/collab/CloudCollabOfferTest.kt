package com.kairumo.padnote.collab

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CloudCollabOfferTest {
    @Test
    fun offerOnlyAcceptsLinksWithDriveAndNotebook() {
        // 沒有 drive 或 nb 的純房號或一般連結：不收
        assertFalse(CloudCollab.offer(null))
        assertFalse(CloudCollab.offer(""))
        assertFalse(CloudCollab.offer("kairumo://collab?room=ABC#key=xyz"))
        assertFalse(CloudCollab.offer("kairumo://collab?room=ABC&drive=FOLDER123#key=xyz"))
        assertFalse(CloudCollab.offer("kairumo://collab?room=ABC&nb=NOTEBOOK123#key=xyz"))

        // 兩者皆有才收
        assertTrue(CloudCollab.offer("kairumo://collab?room=ABC&drive=FOLDER123&nb=NOTEBOOK123#key=xyz"))
    }
}

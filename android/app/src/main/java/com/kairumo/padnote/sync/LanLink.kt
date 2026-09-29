package com.kairumo.padnote.sync

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import com.kairumo.padnote.library.NotebookLibrary
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uniffi.padnote_core.FfiLanHost
import uniffi.padnote_core.FfiLanNode
import uniffi.padnote_core.lanServiceType
import uniffi.padnote_core.lanShouldInitiate

/**
 * 區網節點的平台側：NSD（mDNS）發現，以及核心要的宿主回呼。
 *
 * **只有「發現」是平台的事** —— 協定、加密、去重、重連全部在核心的 [FfiLanNode]
 * （兩個平台一份實作）。這裡只把「這個位址有一台同帳號的裝置」交給核心。
 * Apple 端是 `FocusSyncController.swift` 裡的 `LanLink`，服務類型與 TXT 記錄的
 * 鍵（`d` 裝置 id、`t` 金鑰標籤）逐字相同。
 *
 * 核心從**自己的網路執行緒**呼叫宿主方法，所以回呼裡不能做重活。
 */
class LanLink(
    context: Context,
    key: ByteArray,
    private val deviceId: UInt
) : FfiLanHost {

    private val app = context.applicationContext
    private val nsd = app.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val node: FfiLanNode = FfiLanNode.start(key, deviceId, this)

    @Volatile private var focused: String? = null
    @Volatile private var peerCount = 0

    /** 發現到的對端：裝置 id → (位址, 埠)。斷線之後照這份重連。 */
    private val known = ConcurrentHashMap<UInt, Pair<String, UShort>>()

    private var registration: NsdManager.RegistrationListener? = null
    private var discovery: NsdManager.DiscoveryListener? = null
    private var retry: Job? = null

    /**
     * 舊版的 [NsdManager.resolveService] 同一時間只准一個（同時呼叫會回
     * `FAILURE_ALREADY_ACTIVE`），所以發現到的服務排隊一個一個解析。
     */
    private val resolveQueue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false

    fun start() {
        val tag = node.tagHex()
        val info = NsdServiceInfo().apply {
            serviceName = "kairumo-$deviceId"
            serviceType = lanServiceType()
            port = node.port().toInt()
            setAttribute("d", deviceId.toString())
            setAttribute("t", tag)
        }
        val reg = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) = Unit
            override fun onRegistrationFailed(info: NsdServiceInfo, code: Int) = Unit
            override fun onServiceUnregistered(info: NsdServiceInfo) = Unit
            override fun onUnregistrationFailed(info: NsdServiceInfo, code: Int) = Unit
        }
        registration = reg
        runCatching { nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, reg) }

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(type: String) = Unit
            override fun onDiscoveryStopped(type: String) = Unit
            override fun onStartDiscoveryFailed(type: String, code: Int) = Unit
            override fun onStopDiscoveryFailed(type: String, code: Int) = Unit
            override fun onServiceLost(info: NsdServiceInfo) = Unit
            override fun onServiceFound(found: NsdServiceInfo) {
                // 自己也會被發現：服務名稱就是 `kairumo-<我的裝置 id>`。
                if (found.serviceName.startsWith("kairumo-$deviceId")) return
                enqueueResolve(found)
            }
        }
        discovery = listener
        runCatching { nsd.discoverServices(lanServiceType(), NsdManager.PROTOCOL_DNS_SD, listener) }

        // 斷線之後照已知的位址重連。核心的 `connect` 可以重複呼叫 —— 已經連著的直接略過。
        retry = scope.launch {
            while (true) {
                delay(3_000)
                if (peerCount >= known.size) continue
                for ((peer, address) in known) {
                    node.connect(peer, address.first, address.second)
                }
            }
        }
    }

    fun stop() {
        retry?.cancel()
        retry = null
        discovery?.let { runCatching { nsd.stopServiceDiscovery(it) } }
        registration?.let { runCatching { nsd.unregisterService(it) } }
        discovery = null
        registration = null
        node.stop()
        scope.coroutineContext[Job]?.cancel()
    }

    fun setFocused(notebookId: String?) {
        focused = notebookId
    }

    fun announce(notebookId: String) {
        node.announce(notebookId)
    }

    // ── 發現 ─────────────────────────────────────────────────

    @Synchronized
    private fun enqueueResolve(info: NsdServiceInfo) {
        resolveQueue.addLast(info)
        drainResolves()
    }

    @Synchronized
    private fun drainResolves() {
        if (resolving) return
        val next = resolveQueue.removeFirstOrNull() ?: return
        resolving = true
        val done = {
            synchronized(this) {
                resolving = false
                drainResolves()
            }
        }
        val listener = object : NsdManager.ResolveListener {
            override fun onResolveFailed(info: NsdServiceInfo, code: Int) = done()
            override fun onServiceResolved(resolved: NsdServiceInfo) {
                try {
                    accept(resolved)
                } finally {
                    done()
                }
            }
        }
        runCatching { nsd.resolveService(next, listener) }.onFailure { done() }
    }

    private fun accept(resolved: NsdServiceInfo) {
        val attributes = resolved.attributes
        val peer = attributes["d"]?.toString(Charsets.UTF_8)?.toUIntOrNull() ?: return
        val tag = attributes["t"]?.toString(Charsets.UTF_8) ?: return
        // 別的帳號的裝置在發現階段就略過。
        if (tag != node.tagHex() || peer == deviceId) return
        // 只有裝置 id 較小的一方主動連（見核心 `should_initiate`）。
        if (!lanShouldInitiate(deviceId, peer)) return
        val host = resolved.host?.hostAddress ?: return
        val port = resolved.port.toUShort()
        known[peer] = host to port
        node.connect(peer, host, port)
    }

    // ── FfiLanHost（核心的網路執行緒呼叫）────────────────────

    override fun focusedNotebook(): String? = focused

    override fun packagePath(notebookId: String): String? =
        // 沒有這本就回 null：區網不負責建立整本筆記，那是整庫同步的事。
        findPackage(app, notebookId)?.absolutePath

    override fun onReceived(notebookId: String, files: UInt) {
        FocusSync.lanReceived(notebookId)
    }

    override fun onPeersChanged(count: UInt) {
        peerCount = count.toInt()
        FocusSync.lanPeersChanged(count.toInt())
    }

    companion object {
        /**
         * 套件目錄底下這本筆記本的檔案。**大小寫不敏感** —— Apple 端的雲端與區網
         * 訊息一律用小寫 id，而 Android 的檔名可能保留原本的大小寫；ext4 分大小寫，
         * 直接拼路徑會找不到。
         */
        fun findPackage(context: Context, notebookId: String): File? {
            val dir = NotebookLibrary.directory(context)
            File(dir, "$notebookId.padnote").takeIf { it.exists() }?.let { return it }
            File(dir, "${notebookId.lowercase()}.padnote").takeIf { it.exists() }?.let { return it }
            val wanted = "${notebookId.lowercase()}.padnote"
            return dir.listFiles { f -> f.name.lowercase() == wanted }?.firstOrNull()
        }
    }
}

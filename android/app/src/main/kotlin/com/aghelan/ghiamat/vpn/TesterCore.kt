package com.aghelan.ghiamat.vpn

import android.content.Context
import android.util.Log
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.TunOptions

/**
 * Second libbox instance used only for latency tests. It has no TUN
 * inbound; when the VPN is running its sockets are protected through the
 * VpnService so measurements do not go through the tunnel.
 */
object TesterCore {
    private var server: CommandServer? = null
    private var monitorAcquired = false

    @Synchronized
    fun start(context: Context, config: String) {
        stop()
        LibboxSetup.ensure(context)
        DefaultNetworkMonitor.acquire(context)
        monitorAcquired = true
        val platform = TesterPlatform(context.applicationContext)
        try {
            // Never call start(): that would bind the shared command socket
            // used by the VPN core's server.
            val commandServer = CommandServer(TesterHandler, platform)
            server = commandServer
            commandServer.startOrReloadService(config, OverrideOptions())
        } catch (e: Exception) {
            stop()
            throw e
        }
    }

    @Synchronized
    fun stop() {
        server?.let {
            runCatching { it.closeService() }.onFailure { e -> Log.w("TesterCore", "closeService", e) }
            runCatching { it.close() }
        }
        server = null
        if (monitorAcquired) {
            DefaultNetworkMonitor.release()
            monitorAcquired = false
        }
    }

    private class TesterPlatform(override val platformContext: Context) : CommonPlatform {
        override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

        override fun autoDetectInterfaceControl(fd: Int) {
            // Without a running VPN there is no tunnel to escape.
            AghelanVpnService.active?.protect(fd)
        }

        override fun openTun(options: TunOptions): Int = error("tester has no TUN inbound")
    }

    private object TesterHandler : CommandServerHandler {
        override fun serviceStop() {}

        override fun serviceReload() {}

        override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus()

        override fun setSystemProxyEnabled(isEnabled: Boolean) {}

        override fun triggerNativeCrash() {}

        override fun writeDebugMessage(message: String?) {
            Log.d("sing-box-tester", message ?: "")
        }

        override fun connectSSHAgent(): Int = -1
    }
}

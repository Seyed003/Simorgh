package com.aghelan.ghiamat.vpn

import android.os.Handler
import android.os.Looper

enum class VpnStatus(val wireName: String) {
    STARTING("starting"),
    STARTED("started"),
    STOPPING("stopping"),
    STOPPED("stopped"),
}

/**
 * Process-wide VPN status shared between [AghelanVpnService] and the
 * Flutter bridge. Listeners are always invoked on the main thread.
 */
object VpnStatusBus {
    fun interface Listener {
        fun onStatus(status: VpnStatus, error: String?)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = linkedSetOf<Listener>()

    @Volatile
    var status: VpnStatus = VpnStatus.STOPPED
        private set

    fun post(status: VpnStatus, error: String? = null) {
        this.status = status
        mainHandler.post {
            synchronized(listeners) { listeners.toList() }.forEach { it.onStatus(status, error) }
        }
    }

    fun addListener(listener: Listener) {
        synchronized(listeners) { listeners.add(listener) }
    }

    fun removeListener(listener: Listener) {
        synchronized(listeners) { listeners.remove(listener) }
    }
}

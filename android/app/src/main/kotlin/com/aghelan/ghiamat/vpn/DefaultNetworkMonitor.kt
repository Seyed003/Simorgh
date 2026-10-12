/*
 * Adapted from sing-box-for-android (GPL-3.0-or-later),
 * Copyright (C) SagerNet; originally derived from shadowsocks-android.
 */
package com.aghelan.ghiamat.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import io.nekohasekai.libbox.InterfaceUpdateListener
import java.net.NetworkInterface

/**
 * Tracks the underlying (non-VPN) default network and reports it to
 * sing-box so outbound sockets are bound to the right interface.
 */
object DefaultNetworkMonitor {
    @Volatile
    var defaultNetwork: Network? = null
        private set

    private var connectivity: ConnectivityManager? = null
    private val listeners = linkedSetOf<InterfaceUpdateListener>()
    private var users = 0
    private val handler by lazy { Handler(HandlerThread("network-monitor").apply { start() }.looper) }

    private val request = NetworkRequest.Builder()
        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
        .build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = update(network)

        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            if (network == defaultNetwork) update(network)
        }

        override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) {
            if (network == defaultNetwork) update(network)
        }

        override fun onLost(network: Network) {
            if (network == defaultNetwork) update(null)
        }
    }

    /**
     * Registers a user (the VPN core or the latency tester). The network
     * callback stays registered until every user has called [release].
     */
    @Synchronized
    fun acquire(context: Context) {
        users++
        if (users > 1) return
        val cm = context.getSystemService(ConnectivityManager::class.java)
        connectivity = cm
        defaultNetwork = cm.activeNetwork
        // registerDefaultNetworkCallback reports the VPN itself once it is up
        // (Android P+), so request the best non-VPN network explicitly.
        when {
            Build.VERSION.SDK_INT >= 31 -> cm.registerBestMatchingNetworkCallback(request, callback, handler)
            Build.VERSION.SDK_INT >= 28 -> cm.requestNetwork(request, callback, handler)
            Build.VERSION.SDK_INT >= 26 -> cm.registerDefaultNetworkCallback(callback, handler)
            else -> cm.registerDefaultNetworkCallback(callback)
        }
    }

    @Synchronized
    fun release() {
        if (users == 0) return
        users--
        if (users > 0) return
        runCatching { connectivity?.unregisterNetworkCallback(callback) }
        synchronized(listeners) { listeners.clear() }
        defaultNetwork = null
    }

    fun addListener(listener: InterfaceUpdateListener) {
        synchronized(listeners) { listeners.add(listener) }
        notifyListener(listener, defaultNetwork)
    }

    fun removeListener(listener: InterfaceUpdateListener) {
        synchronized(listeners) { listeners.remove(listener) }
    }

    private fun update(network: Network?) {
        defaultNetwork = network
        synchronized(listeners) { listeners.toList() }.forEach { notifyListener(it, network) }
    }

    private fun notifyListener(listener: InterfaceUpdateListener, network: Network?) {
        if (network == null) {
            listener.updateDefaultInterface("", -1, false, false)
            return
        }
        val cm = connectivity ?: return
        repeat(10) {
            val name = cm.getLinkProperties(network)?.interfaceName
            val index = name?.let { runCatching { NetworkInterface.getByName(it)?.index }.getOrNull() }
            if (name != null && index != null) {
                val caps = cm.getNetworkCapabilities(network)
                val expensive = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false
                listener.updateDefaultInterface(name, index, expensive, false)
                return
            }
            Thread.sleep(100)
        }
    }
}

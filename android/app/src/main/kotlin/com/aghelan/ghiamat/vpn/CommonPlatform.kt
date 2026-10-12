package com.aghelan.ghiamat.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.system.OsConstants
import android.util.Log
import io.nekohasekai.libbox.BridgeOptions
import io.nekohasekai.libbox.BridgeSession
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.PlatformUser
import io.nekohasekai.libbox.ShellSession
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.WIFIState
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.net.InterfaceAddress
import java.net.NetworkInterface
import io.nekohasekai.libbox.Notification as LibboxNotification
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface

/**
 * libbox PlatformInterface behaviour shared by the VPN core and the latency
 * tester. Implementations supply TUN handling and socket protection.
 */
interface CommonPlatform : PlatformInterface {
    val platformContext: Context

    private val connectivity: ConnectivityManager
        get() = platformContext.getSystemService(ConnectivityManager::class.java)

    override fun localDNSTransport(): LocalDNSTransport = LocalResolver

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): ConnectionOwner {
        val uid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivity.getConnectionOwnerUid(
                ipProtocol,
                InetSocketAddress(sourceAddress, sourcePort),
                InetSocketAddress(destinationAddress, destinationPort),
            )
        } else {
            error("android: connection owner lookup needs API 29")
        }
        if (uid == Process.INVALID_UID) error("android: connection owner not found")
        val packages = platformContext.packageManager.getPackagesForUid(uid)?.toList().orEmpty()
        return ConnectionOwner().apply {
            userId = uid
            userName = packages.firstOrNull() ?: ""
            setAndroidPackageNames(LibboxStrings(packages.iterator()))
        }
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.addListener(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.removeListener(listener)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val cm = connectivity
        val systemInterfaces = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
        val result = mutableListOf<LibboxNetworkInterface>()
        @Suppress("DEPRECATION")
        for (network in cm.allNetworks) {
            val link = cm.getLinkProperties(network) ?: continue
            val caps = cm.getNetworkCapabilities(network) ?: continue
            val system = systemInterfaces.find { it.name == link.interfaceName } ?: continue
            result += LibboxNetworkInterface().apply {
                name = link.interfaceName
                index = system.index
                runCatching { mtu = system.mtu }
                dnsServer = LibboxStrings(link.dnsServers.mapNotNull { it.hostAddress }.iterator())
                gateway = LibboxStrings(
                    link.routes.filter { it.destination.prefixLength == 0 }
                        .mapNotNull { it.gateway }
                        .filterNot { it.isAnyLocalAddress }
                        .mapNotNull { it.hostAddress }
                        .iterator(),
                )
                type = when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                addresses = LibboxStrings(system.interfaceAddresses.map { it.toPrefix() }.iterator())
                var dumpFlags = 0
                if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    dumpFlags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                }
                if (system.isLoopback) dumpFlags = dumpFlags or OsConstants.IFF_LOOPBACK
                if (system.isPointToPoint) dumpFlags = dumpFlags or OsConstants.IFF_POINTOPOINT
                if (system.supportsMulticast()) dumpFlags = dumpFlags or OsConstants.IFF_MULTICAST
                flags = dumpFlags
                metered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            }
        }
        return LibboxInterfaces(result.iterator())
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() {}

    override fun sendNotification(notification: LibboxNotification) {
        Log.i("AghelanVpn", "core notification: ${notification.title}: ${notification.body}")
    }

    override fun cancelNotification(identifier: String, typeID: Int) {}

    override fun startNeighborMonitor(listener: NeighborUpdateListener?) {}

    override fun closeNeighborMonitor(listener: NeighborUpdateListener?) {}

    override fun registerMyInterface(name: String?) {}

    override fun usePlatformShell(): Boolean = false

    override fun checkPlatformShell() {
        error("platform shell is not supported")
    }

    override fun openShellSession(
        user: PlatformUser?,
        command: String?,
        environ: StringIterator?,
        term: String?,
        rows: Int,
        cols: Int,
    ): ShellSession = error("platform shell is not supported")

    override fun lookupUser(username: String?): PlatformUser = error("user lookup is not supported")

    override fun lookupSFTPServer(): String = error("sftp is not supported")

    override fun readSystemSSHHostKey(): String = error("not supported")

    override fun tailscaleHostname(): String =
        Settings.Global.getString(platformContext.contentResolver, Settings.Global.DEVICE_NAME)
            ?.takeIf { it.isNotBlank() }
            ?: "${Build.MANUFACTURER} ${Build.MODEL}"

    override fun usePlatformBridge(): Boolean = false

    override fun createBridge(options: BridgeOptions?): BridgeSession = error("bridge is not supported")
}

class LibboxStrings(private val iterator: Iterator<String>) : StringIterator {
    override fun len(): Int = 0

    override fun hasNext(): Boolean = iterator.hasNext()

    override fun next(): String = iterator.next()
}

private class LibboxInterfaces(private val iterator: Iterator<LibboxNetworkInterface>) : NetworkInterfaceIterator {
    override fun hasNext(): Boolean = iterator.hasNext()

    override fun next(): LibboxNetworkInterface = iterator.next()
}

private fun InterfaceAddress.toPrefix(): String = if (address is Inet6Address) {
    "${Inet6Address.getByAddress(address.address).hostAddress}/$networkPrefixLength"
} else {
    "${address.hostAddress}/$networkPrefixLength"
}

package com.aghelan.ghiamat.vpn

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.IpPrefix
import android.net.NetworkCapabilities
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.system.OsConstants
import android.util.Log
import com.aghelan.ghiamat.MainActivity
import com.aghelan.ghiamat.R
import io.nekohasekai.libbox.BridgeOptions
import io.nekohasekai.libbox.BridgeSession
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.PlatformUser
import io.nekohasekai.libbox.RoutePrefix
import io.nekohasekai.libbox.ShellSession
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.io.File
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.InterfaceAddress
import java.net.NetworkInterface
import java.util.concurrent.Executors
import io.nekohasekai.libbox.Notification as LibboxNotification
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface

/**
 * Runs sing-box (libbox) inside Android's VpnService. The TUN file
 * descriptor is created here in [openTun] and handed to the core.
 */
class AghelanVpnService : VpnService(), PlatformInterface, CommandServerHandler {
    companion object {
        private const val TAG = "AghelanVpn"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_status"

        const val ACTION_START = "com.aghelan.ghiamat.START"
        const val ACTION_STOP = "com.aghelan.ghiamat.STOP"
        const val EXTRA_PROFILE_NAME = "profile_name"

        fun configFile(context: Context) = File(context.filesDir, "active_config.json")

        fun start(context: Context, profileName: String) {
            val intent = Intent(context, AghelanVpnService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_PROFILE_NAME, profileName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(Intent(context, AghelanVpnService::class.java).setAction(ACTION_STOP))
        }
    }

    // Libbox calls are blocking; keep them off the main thread and serialized.
    private val worker = Executors.newSingleThreadExecutor()
    private var commandServer: CommandServer? = null
    private var tunFd: android.os.ParcelFileDescriptor? = null
    private var profileName = ""

    private val connectivity by lazy { getSystemService(ConnectivityManager::class.java) }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                worker.execute { stopVpn(null) }
                return START_NOT_STICKY
            }
            // ACTION_START, or the system starting us for always-on VPN.
            else -> {
                profileName = intent?.getStringExtra(EXTRA_PROFILE_NAME)
                    ?: getSharedPreferences("vpn", MODE_PRIVATE).getString("profile_name", "") ?: ""
                getSharedPreferences("vpn", MODE_PRIVATE).edit().putString("profile_name", profileName).apply()
                showNotification(getString(R.string.vpn_status_connecting))
                worker.execute { startVpn() }
            }
        }
        return START_NOT_STICKY
    }

    private fun startVpn() {
        if (VpnStatusBus.status == VpnStatus.STARTED || VpnStatusBus.status == VpnStatus.STARTING) {
            // Already running: reload with the new config instead.
            reloadOrFail()
            return
        }
        VpnStatusBus.post(VpnStatus.STARTING)
        try {
            val config = configFile(this).readText()
            LibboxSetup.ensure(this)
            DefaultNetworkMonitor.start(this)
            val server = CommandServer(this, this)
            server.start()
            commandServer = server
            server.startOrReloadService(config, OverrideOptions())
            VpnStatusBus.post(VpnStatus.STARTED)
            showNotification(getString(R.string.vpn_status_connected))
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
            stopVpn(e.message ?: e.toString())
        }
    }

    private fun reloadOrFail() {
        try {
            commandServer?.startOrReloadService(configFile(this).readText(), OverrideOptions())
            VpnStatusBus.post(VpnStatus.STARTED)
            showNotification(getString(R.string.vpn_status_connected))
        } catch (e: Exception) {
            Log.e(TAG, "reload failed", e)
            stopVpn(e.message ?: e.toString())
        }
    }

    private fun stopVpn(error: String?) {
        if (VpnStatusBus.status == VpnStatus.STOPPED && commandServer == null) {
            VpnStatusBus.post(VpnStatus.STOPPED, error)
            stopSelfSafely()
            return
        }
        VpnStatusBus.post(VpnStatus.STOPPING)
        runCatching { tunFd?.close() }
        tunFd = null
        commandServer?.let { server ->
            runCatching { server.closeService() }.onFailure { Log.w(TAG, "closeService", it) }
            runCatching { server.close() }
        }
        commandServer = null
        DefaultNetworkMonitor.stop()
        VpnStatusBus.post(VpnStatus.STOPPED, error)
        stopSelfSafely()
    }

    private fun stopSelfSafely() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onRevoke() {
        // Another VPN took over or the user revoked the permission.
        worker.execute { stopVpn(null) }
    }

    override fun onDestroy() {
        worker.execute { if (commandServer != null) stopVpn(null) }
        worker.shutdown()
        super.onDestroy()
    }

    // region Notification

    private fun showNotification(status: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, getString(R.string.vpn_channel_name), NotificationManager.IMPORTANCE_LOW),
            )
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), flags)
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, AghelanVpnService::class.java).setAction(ACTION_STOP),
            flags,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_vpn)
            .setColor(getColor(R.color.notification_accent))
            .setContentTitle(profileName.ifEmpty { getString(R.string.app_name) })
            .setContentText(status)
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, getString(R.string.vpn_action_disconnect), stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    // endregion

    // region PlatformInterface

    override fun localDNSTransport(): LocalDNSTransport = LocalResolver

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) error("android: missing vpn permission")
        val builder = Builder()
            .setSession(profileName.ifEmpty { getString(R.string.app_name) })
            .setMtu(options.mtu)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) builder.setMetered(false)

        val inet4Address = options.inet4Address
        while (inet4Address.hasNext()) {
            val address = inet4Address.next()
            builder.addAddress(address.address(), address.prefix())
        }
        val inet6Address = options.inet6Address
        while (inet6Address.hasNext()) {
            val address = inet6Address.next()
            builder.addAddress(address.address(), address.prefix())
        }

        if (options.autoRoute) {
            if (options.dnsMode.value != Libbox.DNSModeDisabled) {
                val dns = options.dnsServerAddress
                while (dns.hasNext()) builder.addDnsServer(dns.next())
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val inet4Route = options.inet4RouteAddress
                if (inet4Route.hasNext()) {
                    while (inet4Route.hasNext()) builder.addRoute(inet4Route.next().toIpPrefix())
                } else if (options.inet4Address.hasNext()) {
                    builder.addRoute("0.0.0.0", 0)
                }
                val inet6Route = options.inet6RouteAddress
                if (inet6Route.hasNext()) {
                    while (inet6Route.hasNext()) builder.addRoute(inet6Route.next().toIpPrefix())
                } else if (options.inet6Address.hasNext()) {
                    builder.addRoute("::", 0)
                }
                val inet4Exclude = options.inet4RouteExcludeAddress
                while (inet4Exclude.hasNext()) builder.excludeRoute(inet4Exclude.next().toIpPrefix())
                val inet6Exclude = options.inet6RouteExcludeAddress
                while (inet6Exclude.hasNext()) builder.excludeRoute(inet6Exclude.next().toIpPrefix())
            } else {
                val inet4Range = options.inet4RouteRange
                while (inet4Range.hasNext()) {
                    val prefix = inet4Range.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
                val inet6Range = options.inet6RouteRange
                while (inet6Range.hasNext()) {
                    val prefix = inet6Range.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
            }

            val include = options.includePackage
            while (include.hasNext()) {
                try {
                    builder.addAllowedApplication(include.next())
                } catch (e: PackageManager.NameNotFoundException) {
                    Log.w(TAG, "addAllowedApplication", e)
                }
            }
            val exclude = options.excludePackage
            while (exclude.hasNext()) {
                try {
                    builder.addDisallowedApplication(exclude.next())
                } catch (e: PackageManager.NameNotFoundException) {
                    Log.w(TAG, "addDisallowedApplication", e)
                }
            }
        }

        if (options.isHTTPProxyEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val bypass = mutableListOf<String>()
            val domains = options.httpProxyBypassDomain
            while (domains.hasNext()) bypass.add(domains.next())
            builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(options.httpProxyServer, options.httpProxyServerPort, bypass),
            )
        }

        val pfd = builder.establish() ?: error("android: the application is not prepared or is revoked")
        tunFd = pfd
        return pfd.fd
    }

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
        val packages = packageManager.getPackagesForUid(uid)?.toList().orEmpty()
        return ConnectionOwner().apply {
            userId = uid
            userName = packages.firstOrNull() ?: ""
            setAndroidPackageNames(StringArray(packages.iterator()))
        }
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.setListener(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.setListener(null)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val systemInterfaces = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
        val result = mutableListOf<LibboxNetworkInterface>()
        for (network in connectivity.allNetworks) {
            val link = connectivity.getLinkProperties(network) ?: continue
            val caps = connectivity.getNetworkCapabilities(network) ?: continue
            val system = systemInterfaces.find { it.name == link.interfaceName } ?: continue
            result += LibboxNetworkInterface().apply {
                name = link.interfaceName
                index = system.index
                runCatching { mtu = system.mtu }
                dnsServer = StringArray(link.dnsServers.mapNotNull { it.hostAddress }.iterator())
                gateway = StringArray(
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
                addresses = StringArray(system.interfaceAddresses.map { it.toPrefix() }.iterator())
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
        return InterfaceArray(result.iterator())
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() {}

    override fun sendNotification(notification: LibboxNotification) {
        Log.i(TAG, "core notification: ${notification.title}: ${notification.body}")
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
        Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)?.takeIf { it.isNotBlank() }
            ?: "${Build.MANUFACTURER} ${Build.MODEL}"

    override fun usePlatformBridge(): Boolean = false

    override fun createBridge(options: BridgeOptions?): BridgeSession = error("bridge is not supported")

    // endregion

    // region CommandServerHandler

    override fun serviceStop() {
        worker.execute { stopVpn(null) }
    }

    override fun serviceReload() {
        worker.execute { reloadOrFail() }
    }

    override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus()

    override fun setSystemProxyEnabled(isEnabled: Boolean) {}

    override fun triggerNativeCrash() {}

    override fun writeDebugMessage(message: String?) {
        Log.d("sing-box", message ?: "")
    }

    override fun connectSSHAgent(): Int = -1

    // endregion

    class StringArray(private val iterator: Iterator<String>) : StringIterator {
        override fun len(): Int = 0

        override fun hasNext(): Boolean = iterator.hasNext()

        override fun next(): String = iterator.next()
    }

    private class InterfaceArray(private val iterator: Iterator<LibboxNetworkInterface>) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()

        override fun next(): LibboxNetworkInterface = iterator.next()
    }

    @SuppressLint("NewApi")
    private fun RoutePrefix.toIpPrefix() = IpPrefix(InetAddress.getByName(address()), prefix())

    private fun InterfaceAddress.toPrefix(): String = if (address is Inet6Address) {
        "${Inet6Address.getByAddress(address.address).hostAddress}/$networkPrefixLength"
    } else {
        "${address.hostAddress}/$networkPrefixLength"
    }
}

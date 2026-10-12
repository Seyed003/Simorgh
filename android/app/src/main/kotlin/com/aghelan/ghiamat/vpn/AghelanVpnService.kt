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
import android.net.IpPrefix
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.util.Log
import com.aghelan.ghiamat.MainActivity
import com.aghelan.ghiamat.R
import com.aghelan.ghiamat.surfaces.StatusSurfaces
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.RoutePrefix
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.TunOptions
import java.io.File
import java.net.InetAddress
import java.util.concurrent.Executors

/**
 * Runs sing-box (libbox) inside Android's VpnService. The TUN file
 * descriptor is created here in [openTun] and handed to the core.
 */
class AghelanVpnService : VpnService(), CommonPlatform, CommandServerHandler {
    companion object {
        private const val TAG = "AghelanVpn"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_status"

        const val ACTION_START = "com.aghelan.ghiamat.START"
        const val ACTION_STOP = "com.aghelan.ghiamat.STOP"

        /** Start or stop, whichever applies (quick settings tile, widget). */
        const val ACTION_TOGGLE = "com.aghelan.ghiamat.TOGGLE"
        const val EXTRA_PROFILE_NAME = "profile_name"

        /** The running service, used by the latency tester to protect sockets. */
        @Volatile
        var active: AghelanVpnService? = null
            private set

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

        fun lastProfileName(context: Context): String =
            context.getSharedPreferences("vpn", MODE_PRIVATE).getString("profile_name", "") ?: ""

        /**
         * Whether the tile/widget can (re)connect without the app: the app
         * has connected before (a config exists) and VPN permission holds.
         */
        fun canStartWithoutUi(context: Context): Boolean =
            configFile(context).exists() && prepare(context) == null
    }

    // Libbox calls are blocking; keep them off the main thread and serialized.
    private val worker = Executors.newSingleThreadExecutor()
    private var commandServer: CommandServer? = null
    private var monitorAcquired = false
    private var tunFd: android.os.ParcelFileDescriptor? = null
    private var profileName = ""

    override val platformContext: Context get() = this

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        val running = VpnStatusBus.status == VpnStatus.STARTED || VpnStatusBus.status == VpnStatus.STARTING
        if (action == ACTION_STOP) {
            worker.execute { stopVpn(null) }
        } else if (action == ACTION_TOGGLE && running) {
            // Started through startForegroundService: go foreground before
            // stopping, as Android requires.
            showNotification(getString(R.string.vpn_status_disconnecting))
            worker.execute { stopVpn(null) }
        } else {
            // ACTION_START, ACTION_TOGGLE while stopped, or the system
            // starting us for always-on VPN.
            profileName = intent?.getStringExtra(EXTRA_PROFILE_NAME) ?: lastProfileName(this)
            getSharedPreferences("vpn", MODE_PRIVATE).edit().putString("profile_name", profileName).apply()
            showNotification(getString(R.string.vpn_status_connecting))
            worker.execute { startVpn() }
        }
        return START_NOT_STICKY
    }

    private fun startVpn() {
        if (VpnStatusBus.status == VpnStatus.STARTED || VpnStatusBus.status == VpnStatus.STARTING) {
            // Already running: reload with the new config instead.
            reloadOrFail()
            return
        }
        postStatus(VpnStatus.STARTING)
        try {
            val config = configFile(this).readText()
            LibboxSetup.ensure(this)
            DefaultNetworkMonitor.acquire(this)
            monitorAcquired = true
            val server = CommandServer(this, this)
            server.start()
            commandServer = server
            server.startOrReloadService(config, OverrideOptions())
            active = this
            postStatus(VpnStatus.STARTED)
            showNotification(getString(R.string.vpn_status_connected))
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
            stopVpn(e.message ?: e.toString())
        }
    }

    private fun reloadOrFail() {
        try {
            commandServer?.startOrReloadService(configFile(this).readText(), OverrideOptions())
            postStatus(VpnStatus.STARTED)
            showNotification(getString(R.string.vpn_status_connected))
        } catch (e: Exception) {
            Log.e(TAG, "reload failed", e)
            stopVpn(e.message ?: e.toString())
        }
    }

    private fun stopVpn(error: String?) {
        if (VpnStatusBus.status == VpnStatus.STOPPED && commandServer == null) {
            postStatus(VpnStatus.STOPPED, error)
            stopSelfSafely()
            return
        }
        postStatus(VpnStatus.STOPPING)
        active = null
        runCatching { tunFd?.close() }
        tunFd = null
        commandServer?.let { server ->
            runCatching { server.closeService() }.onFailure { Log.w(TAG, "closeService", it) }
            runCatching { server.close() }
        }
        commandServer = null
        if (monitorAcquired) {
            DefaultNetworkMonitor.release()
            monitorAcquired = false
        }
        postStatus(VpnStatus.STOPPED, error)
        stopSelfSafely()
    }

    private fun postStatus(status: VpnStatus, error: String? = null) {
        VpnStatusBus.post(status, error)
        StatusSurfaces.refresh(this)
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

    @SuppressLint("NewApi")
    private fun RoutePrefix.toIpPrefix() = IpPrefix(InetAddress.getByName(address()), prefix())

}

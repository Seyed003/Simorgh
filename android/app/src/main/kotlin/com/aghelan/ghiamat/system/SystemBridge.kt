package com.aghelan.ghiamat.system

import android.app.Activity
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import com.aghelan.ghiamat.vpn.AghelanVpnService
import com.aghelan.ghiamat.vpn.DefaultNetworkMonitor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * System integration for Flutter.
 *
 * Methods (`com.aghelan.ghiamat/system`):
 * - openVpnSettings: Android's VPN settings (always-on / lockdown live there).
 * - openUrl {url}: the browser.
 * - networkInfo: {kind: wifi|cellular|ethernet|other, operator, mccMnc} of
 *   the network under the VPN.
 * - vpnLockdown: {alwaysOn, lockdown} of the running VPN, null when unknown.
 * - takeShared: links/text that opened the app before Flutter listened.
 * Events (`com.aghelan.ghiamat/shared`): text from later VIEW/SEND intents.
 */
class SystemBridge(private val activity: Activity) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val pending = mutableListOf<String>()
    private var sink: EventChannel.EventSink? = null

    fun attach(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "com.aghelan.ghiamat/system").setMethodCallHandler(this)
        EventChannel(messenger, "com.aghelan.ghiamat/shared").setStreamHandler(this)
    }

    /** A config link tapped elsewhere, or text shared to the app. */
    fun handleIntent(intent: Intent?) {
        val text = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.dataString
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            else -> null
        }?.trim()
        if (text.isNullOrEmpty()) return
        // Handled once, even if the activity is recreated with this intent.
        intent?.action = Intent.ACTION_MAIN
        val events = sink
        if (events != null) events.success(text) else pending.add(text)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openVpnSettings" -> {
                val opened = runCatching { activity.startActivity(Intent(Settings.ACTION_VPN_SETTINGS)) }
                if (opened.isFailure) runCatching { activity.startActivity(Intent(Settings.ACTION_SETTINGS)) }
                result.success(null)
            }
            "openUrl" -> {
                val url = call.argument<String>("url") ?: ""
                runCatching {
                    activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }
                result.success(null)
            }
            "vpnLockdown" -> {
                val service = AghelanVpnService.active
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || service == null) {
                    result.success(null)
                } else {
                    result.success(mapOf("alwaysOn" to service.isAlwaysOn, "lockdown" to service.isLockdownEnabled))
                }
            }
            "networkInfo" -> result.success(networkInfo())
            "takeShared" -> {
                result.success(pending.toList())
                pending.clear()
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun networkInfo(): Map<String, Any?> {
        val connectivity = activity.getSystemService(ConnectivityManager::class.java)
        // While connected the VPN is the active network; look underneath it.
        val networks = listOfNotNull(DefaultNetworkMonitor.defaultNetwork, connectivity.activeNetwork) +
            connectivity.allNetworks.toList()
        var kind = "other"
        for (network in networks) {
            val caps = connectivity.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) continue
            kind = when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }
            break
        }
        val telephony = activity.getSystemService(TelephonyManager::class.java)
        return mapOf(
            "kind" to kind,
            "operator" to telephony?.networkOperatorName,
            "mccMnc" to telephony?.networkOperator,
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}

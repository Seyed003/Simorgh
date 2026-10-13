package com.aghelan.ghiamat.system

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
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
 * - takeShared: what opened the app before Flutter listened.
 * - shareApp {title}: the share sheet with the app's own APK; false when
 *   it is installed as split APKs, which cannot travel as one file.
 * Events (`com.aghelan.ghiamat/shared`): what later VIEW/SEND intents carry.
 * Both as {text, name}: a link or shared text, or the contents of an opened
 * file (an OpenVPN profile) with its file name.
 */
class SystemBridge(private val activity: Activity) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val pending = mutableListOf<Map<String, String?>>()
    private var sink: EventChannel.EventSink? = null

    fun attach(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "com.aghelan.ghiamat/system").setMethodCallHandler(this)
        EventChannel(messenger, "com.aghelan.ghiamat/shared").setStreamHandler(this)
    }

    /**
     * A config link tapped elsewhere, text or a file shared to the app.
     * Any app can send these, so nothing here may crash or block the UI
     * thread (that would take the VPN down with the app): files are read
     * on a background thread, and only content:// files of other apps.
     */
    fun handleIntent(intent: Intent?) {
        try {
            when (intent?.action) {
                Intent.ACTION_VIEW -> {
                    val uri = intent.data ?: return
                    if (uri.scheme == "content") {
                        readInBackground(uri)
                    } else if (uri.scheme != "file") {
                        deliver(mapOf("text" to intent.dataString, "name" to null))
                    }
                }
                Intent.ACTION_SEND -> {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (text != null) {
                        deliver(mapOf("text" to text, "name" to null))
                    } else {
                        streamExtra(intent)?.takeIf { it.scheme == "content" }?.let(::readInBackground)
                    }
                }
                else -> return
            }
            // Handled once, even if the activity is recreated with this intent.
            intent?.action = Intent.ACTION_MAIN
        } catch (e: Throwable) {
            Log.w(TAG, "ignoring a malformed intent", e)
        }
    }

    private fun deliver(shared: Map<String, String?>) {
        if (shared["text"].isNullOrBlank()) return
        val events = sink
        if (events != null) events.success(shared) else pending.add(shared)
    }

    private fun readInBackground(uri: Uri) {
        // Our own providers (the shared APK) are nothing to import.
        if (uri.authority?.startsWith(activity.packageName) == true) return
        val main = Handler(Looper.getMainLooper())
        Thread {
            val shared = readFile(uri)
            if (shared != null) main.post { deliver(shared) }
        }.apply { isDaemon = true }.start()
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    /** A small text file (an .ovpn profile): its contents and name. */
    private fun readFile(uri: Uri): Map<String, String?>? = runCatching {
        val resolver = activity.contentResolver
        val bytes = resolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(MAX_FILE_BYTES + 1)
            var total = 0
            while (total < buffer.size) {
                val read = input.read(buffer, total, buffer.size - total)
                if (read < 0) break
                total += read
            }
            if (total > MAX_FILE_BYTES) null else buffer.copyOf(total)
        } ?: return@runCatching null
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
            ?: uri.lastPathSegment
        mapOf("text" to String(bytes, Charsets.UTF_8), "name" to name)
    }.getOrNull()

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
            "shareApp" -> result.success(shareApp(call.argument<String>("title")))
            "takeShared" -> {
                result.success(pending.toList())
                pending.clear()
            }
            else -> result.notImplemented()
        }
    }

    private fun shareApp(title: String?): Boolean {
        val info = activity.applicationInfo
        if (!info.splitSourceDirs.isNullOrEmpty()) return false
        @Suppress("DEPRECATION")
        val version = runCatching {
            activity.packageManager.getPackageInfo(activity.packageName, 0).versionName
        }.getOrNull()
        val name = if (version.isNullOrBlank()) "AghelanGhiamat.apk" else "AghelanGhiamat-$version.apk"
        val uri = ApkProvider.uri(activity.packageName, name)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = ApkProvider.MIME
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return runCatching { activity.startActivity(Intent.createChooser(send, title)) }.isSuccess
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

    private companion object {
        const val TAG = "SystemBridge"

        /** Profiles are a few KB; anything bigger is not one. */
        const val MAX_FILE_BYTES = 512 * 1024
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}

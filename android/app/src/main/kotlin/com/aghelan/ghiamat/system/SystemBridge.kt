package com.aghelan.ghiamat.system

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.aghelan.ghiamat.vpn.AghelanVpnService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * System integration for Flutter.
 *
 * Methods (`com.aghelan.ghiamat/system`):
 * - openVpnSettings: Android's VPN settings (always-on / lockdown live there).
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
            "vpnLockdown" -> {
                val service = AghelanVpnService.active
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || service == null) {
                    result.success(null)
                } else {
                    result.success(mapOf("alwaysOn" to service.isAlwaysOn, "lockdown" to service.isLockdownEnabled))
                }
            }
            "takeShared" -> {
                result.success(pending.toList())
                pending.clear()
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}

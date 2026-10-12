package com.aghelan.ghiamat.vpn

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.Libbox
import java.util.concurrent.Executors

/**
 * Flutter <-> VpnService bridge.
 *
 * Methods (`com.aghelan.ghiamat/vpn`): start {config, name}, stop,
 * isRunning, coreVersion, workingDirectory.
 * Events (`com.aghelan.ghiamat/vpn_events`): {status, error?}; core logs
 * on `com.aghelan.ghiamat/logs` (see [LogStream]).
 */
class VpnBridge(private val activity: Activity) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val VPN_PERMISSION_REQUEST = 4201
        private const val NOTIFICATION_PERMISSION_REQUEST = 4202
    }

    private val background = Executors.newSingleThreadExecutor()

    // Separate queue so a slow tester start never delays VPN start/stop.
    private val testerExecutor = Executors.newSingleThreadExecutor()
    private var pendingStart: Pair<String, MethodChannel.Result>? = null
    private var listener: VpnStatusBus.Listener? = null

    fun attach(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "com.aghelan.ghiamat/vpn").setMethodCallHandler(this)
        EventChannel(messenger, "com.aghelan.ghiamat/vpn_events").setStreamHandler(this)
        EventChannel(messenger, "com.aghelan.ghiamat/logs").setStreamHandler(LogStream())
    }

    fun detach() {
        listener?.let(VpnStatusBus::removeListener)
        listener = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "stop" -> {
                AghelanVpnService.stop(activity)
                result.success(null)
            }
            "isRunning" -> result.success(VpnStatusBus.status == VpnStatus.STARTED)
            "coreVersion" -> background.execute {
                val version = runCatching { Libbox.version() }.getOrNull()
                activity.runOnUiThread { result.success(version) }
            }
            "workingDirectory" -> result.success(LibboxSetup.workingDir(activity).path)
            "checkConfig" -> {
                val config = call.argument<String>("config") ?: ""
                background.execute {
                    val error = runCatching {
                        LibboxSetup.ensure(activity)
                        Libbox.checkConfig(config)
                    }.exceptionOrNull()
                    activity.runOnUiThread { result.success(error?.let { it.message ?: it.toString() }) }
                }
            }
            "startTester" -> {
                val config = call.argument<String>("config") ?: ""
                testerExecutor.execute {
                    val error = runCatching { TesterCore.start(activity.applicationContext, config) }.exceptionOrNull()
                    activity.runOnUiThread {
                        if (error == null) {
                            result.success(null)
                        } else {
                            result.error("TESTER_FAILED", error.message ?: error.toString(), null)
                        }
                    }
                }
            }
            "stopTester" -> testerExecutor.execute {
                TesterCore.stop()
                activity.runOnUiThread { result.success(null) }
            }
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val config = call.argument<String>("config")
        val name = call.argument<String>("name") ?: ""
        if (config.isNullOrBlank()) {
            result.error("INVALID_CONFIG", "empty config", null)
            return
        }
        background.execute {
            // Validate before touching the VPN so syntax errors surface
            // immediately instead of as a failed service start.
            val error = runCatching {
                LibboxSetup.ensure(activity)
                Libbox.checkConfig(config)
            }.exceptionOrNull()
            activity.runOnUiThread {
                if (error != null) {
                    result.error("INVALID_CONFIG", error.message, null)
                    return@runOnUiThread
                }
                AghelanVpnService.configFile(activity).writeText(config)
                requestNotificationPermission()
                val prepare = VpnService.prepare(activity)
                if (prepare == null) {
                    AghelanVpnService.start(activity, name)
                    result.success(null)
                } else {
                    pendingStart?.second?.error("PERMISSION_DENIED", "superseded", null)
                    pendingStart = name to result
                    activity.startActivityForResult(prepare, VPN_PERMISSION_REQUEST)
                }
            }
        }
    }

    /** Forwarded from MainActivity.onActivityResult. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != VPN_PERMISSION_REQUEST) return false
        val (name, result) = pendingStart ?: return true
        pendingStart = null
        if (resultCode == Activity.RESULT_OK) {
            AghelanVpnService.start(activity, name)
            result.success(null)
        } else {
            result.error("PERMISSION_DENIED", "VPN permission denied", null)
        }
        return true
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val l = VpnStatusBus.Listener { status, error ->
            events.success(mapOf("status" to status.wireName, "error" to error))
        }
        listener?.let(VpnStatusBus::removeListener)
        listener = l
        VpnStatusBus.addListener(l)
    }

    override fun onCancel(arguments: Any?) {
        listener?.let(VpnStatusBus::removeListener)
        listener = null
    }
}

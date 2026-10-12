package com.aghelan.ghiamat.vpn

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.nekohasekai.libbox.CommandClient
import io.nekohasekai.libbox.CommandClientHandler
import io.nekohasekai.libbox.CommandClientOptions
import io.nekohasekai.libbox.ConnectionEvents
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LogIterator
import io.nekohasekai.libbox.OutboundGroupItemIterator
import io.nekohasekai.libbox.OutboundGroupIterator
import io.nekohasekai.libbox.StatusMessage
import io.nekohasekai.libbox.StringIterator
import java.util.concurrent.Executors

/**
 * Log lines of the running core (`com.aghelan.ghiamat/logs`): {level,
 * message}. Subscribes to the in-process command server while Flutter
 * listens; the recent history arrives first.
 */
class LogStream : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var client: CommandClient? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val handler = object : CommandClientHandler {
            override fun writeLogs(messageList: LogIterator) {
                val lines = mutableListOf<Map<String, Any>>()
                while (messageList.hasNext()) {
                    val entry = messageList.next()
                    lines.add(mapOf("level" to entry.level, "message" to entry.message))
                }
                main.post { lines.forEach(events::success) }
            }

            override fun clearLogs() {}
            override fun connected() {}
            override fun disconnected(message: String?) {}
            override fun initializeClashMode(modeList: StringIterator?, currentMode: String?) {}
            override fun setDefaultLogLevel(level: Int) {}
            override fun updateClashMode(newMode: String?) {}
            override fun writeConnectionEvents(events: ConnectionEvents?) {}
            override fun writeGroups(message: OutboundGroupIterator?) {}
            override fun writeOutbounds(message: OutboundGroupItemIterator?) {}
            override fun writeStatus(message: StatusMessage?) {}
        }
        val options = CommandClientOptions().apply { addCommand(Libbox.CommandLog) }
        val newClient = CommandClient(handler, options)
        client = newClient
        worker.execute {
            // Not connected: nothing to show until the app listens again.
            runCatching { newClient.connect() }.onFailure { Log.d("AghelanLogs", "no core: ${it.message}") }
        }
    }

    override fun onCancel(arguments: Any?) {
        val old = client ?: return
        client = null
        worker.execute { runCatching { old.disconnect() } }
    }
}

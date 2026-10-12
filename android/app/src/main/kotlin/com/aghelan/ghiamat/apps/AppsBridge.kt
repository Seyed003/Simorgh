package com.aghelan.ghiamat.apps

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Installed apps for per-app split tunneling.
 *
 * Methods (`com.aghelan.ghiamat/apps`):
 * - list -> [{package, label, system}] of apps that can use the network
 * - icon {package, size} -> PNG bytes, or null
 */
class AppsBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newFixedThreadPool(2)
    private val main = android.os.Handler(android.os.Looper.getMainLooper())

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.aghelan.ghiamat/apps")
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "list" -> worker.execute {
                val apps = runCatching { listApps() }
                main.post {
                    apps.fold(
                        onSuccess = { result.success(it) },
                        onFailure = { result.error("APPS_FAILED", it.message, null) },
                    )
                }
            }
            "icon" -> {
                val pkg = call.argument<String>("package") ?: ""
                val size = call.argument<Int>("size") ?: 96
                worker.execute {
                    val png = runCatching { icon(pkg, size) }.getOrNull()
                    main.post { result.success(png) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun listApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        }
        return packages
            .asSequence()
            .filter { it.packageName != context.packageName }
            // Only apps that can reach the network matter for routing.
            .filter { info ->
                info.requestedPermissions?.contains(android.Manifest.permission.INTERNET) == true
            }
            .mapNotNull { info ->
                val app = info.applicationInfo ?: return@mapNotNull null
                mapOf(
                    "package" to info.packageName,
                    "label" to app.loadLabel(pm).toString(),
                    "system" to (app.flags and ApplicationInfo.FLAG_SYSTEM != 0),
                )
            }
            .toList()
    }

    private fun icon(pkg: String, size: Int): ByteArray? {
        val drawable = context.packageManager.getApplicationIcon(pkg)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }
}

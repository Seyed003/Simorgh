package com.aghelan.ghiamat

import android.content.Intent
import com.aghelan.ghiamat.vpn.VpnBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var vpnBridge: VpnBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vpnBridge = VpnBridge(this).also { it.attach(flutterEngine) }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        vpnBridge?.detach()
        vpnBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (vpnBridge?.onActivityResult(requestCode, resultCode) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}

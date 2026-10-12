package com.aghelan.ghiamat.surfaces

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.aghelan.ghiamat.MainActivity
import com.aghelan.ghiamat.R
import com.aghelan.ghiamat.vpn.AghelanVpnService
import com.aghelan.ghiamat.vpn.VpnStatus
import com.aghelan.ghiamat.vpn.VpnStatusBus

/**
 * Quick settings tile: connects with the last used config or disconnects.
 * Opens the app when it cannot connect on its own (never connected yet,
 * or VPN permission was revoked).
 */
class VpnTileService : TileService() {
    companion object {
        fun requestUpdate(context: Context) {
            runCatching {
                requestListeningState(context, ComponentName(context, VpnTileService::class.java))
            }
        }
    }

    private val listener = VpnStatusBus.Listener { _, _ -> refresh() }

    override fun onStartListening() {
        VpnStatusBus.addListener(listener)
        refresh()
    }

    override fun onStopListening() {
        VpnStatusBus.removeListener(listener)
    }

    override fun onClick() {
        when (VpnStatusBus.status) {
            VpnStatus.STARTED, VpnStatus.STARTING -> AghelanVpnService.stop(this)
            VpnStatus.STOPPING -> Unit
            VpnStatus.STOPPED ->
                if (AghelanVpnService.canStartWithoutUi(this)) {
                    AghelanVpnService.start(this, AghelanVpnService.lastProfileName(this))
                } else {
                    openApp()
                }
        }
    }

    private fun refresh() {
        val tile = qsTile ?: return
        val status = VpnStatusBus.status
        tile.state = when (status) {
            VpnStatus.STARTED -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        tile.label = getString(R.string.app_name)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = when (status) {
                VpnStatus.STARTED -> AghelanVpnService.lastProfileName(this)
                    .ifEmpty { getString(R.string.vpn_status_connected) }
                VpnStatus.STARTING -> getString(R.string.vpn_status_connecting)
                VpnStatus.STOPPING -> getString(R.string.vpn_status_disconnecting)
                VpnStatus.STOPPED -> getString(R.string.vpn_status_disconnected)
            }
        }
        tile.updateTile()
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}

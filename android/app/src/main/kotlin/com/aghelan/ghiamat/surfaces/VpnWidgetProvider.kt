package com.aghelan.ghiamat.surfaces

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import com.aghelan.ghiamat.MainActivity
import com.aghelan.ghiamat.R
import com.aghelan.ghiamat.vpn.AghelanVpnService
import com.aghelan.ghiamat.vpn.VpnStatus
import com.aghelan.ghiamat.vpn.VpnStatusBus

/** Home screen widget: status, active server and a connect button. */
class VpnWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, VpnWidgetProvider::class.java))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val status = VpnStatusBus.status
            val views = RemoteViews(context.packageName, R.layout.widget_vpn)
            views.setTextViewText(
                R.id.widget_status,
                context.getString(
                    when (status) {
                        VpnStatus.STARTED -> R.string.vpn_status_connected
                        VpnStatus.STARTING -> R.string.vpn_status_connecting
                        VpnStatus.STOPPING -> R.string.vpn_status_disconnecting
                        VpnStatus.STOPPED -> R.string.vpn_status_disconnected
                    },
                ),
            )
            views.setTextViewText(R.id.widget_profile, AghelanVpnService.lastProfileName(context))
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (status == VpnStatus.STARTED) R.drawable.widget_bg_connected else R.drawable.widget_bg,
            )

            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val openApp = PendingIntent.getActivity(context, 10, Intent(context, MainActivity::class.java), flags)
            val canToggle = status != VpnStatus.STOPPED || AghelanVpnService.canStartWithoutUi(context)
            val toggle = if (!canToggle) {
                openApp
            } else {
                val intent = Intent(context, AghelanVpnService::class.java)
                    .setAction(AghelanVpnService.ACTION_TOGGLE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    PendingIntent.getForegroundService(context, 11, intent, flags)
                } else {
                    PendingIntent.getService(context, 11, intent, flags)
                }
            }
            views.setOnClickPendingIntent(R.id.widget_toggle, toggle)
            views.setOnClickPendingIntent(R.id.widget_text, openApp)
            return views
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, views(context))
    }
}

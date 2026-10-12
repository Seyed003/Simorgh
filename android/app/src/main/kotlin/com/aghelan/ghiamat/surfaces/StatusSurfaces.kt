package com.aghelan.ghiamat.surfaces

import android.content.Context

/** Keeps the quick settings tile and home screen widgets in sync. */
object StatusSurfaces {
    fun refresh(context: Context) {
        VpnTileService.requestUpdate(context)
        VpnWidgetProvider.updateAll(context)
    }
}

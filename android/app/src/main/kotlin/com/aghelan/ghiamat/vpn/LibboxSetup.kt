package com.aghelan.ghiamat.vpn

import android.content.Context
import android.os.Build
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/** One-time libbox initialisation for the app process. */
object LibboxSetup {
    private val done = AtomicBoolean(false)

    fun workingDir(context: Context): File = File(context.filesDir, "singbox").apply { mkdirs() }

    fun ensure(context: Context) {
        if (!done.compareAndSet(false, true)) return
        val app = context.applicationContext
        val options = SetupOptions().apply {
            basePath = app.filesDir.path
            workingPath = workingDir(app).path
            tempPath = app.cacheDir.path
            // https://github.com/golang/go/issues/68760
            fixAndroidStack = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ||
                Build.VERSION.SDK_INT in Build.VERSION_CODES.N..Build.VERSION_CODES.N_MR1
            logMaxLines = 1000
            crashReportSource = "AghelanGhiamat"
        }
        Libbox.setup(options)
    }
}

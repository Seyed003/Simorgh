package com.aghelan.ghiamat.system

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File

/**
 * Hands the installed APK, read-only, to the app the user shares it with
 * (Bluetooth, Nearby Share, a messenger), so the app can travel from phone
 * to phone without the internet. Not exported: other apps only get the one
 * URI they were granted with the share.
 */
class ApkProvider : ContentProvider() {
    override fun onCreate() = true

    private fun apk() = File(context!!.applicationInfo.sourceDir)

    override fun getType(uri: Uri) = MIME

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("read-only")
        return ParcelFileDescriptor.open(apk(), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val row = columns.map {
            when (it) {
                OpenableColumns.DISPLAY_NAME -> uri.lastPathSegment
                OpenableColumns.SIZE -> apk().length()
                else -> null
            }
        }
        return MatrixCursor(columns, 1).apply { addRow(row) }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0

    companion object {
        const val MIME = "application/vnd.android.package-archive"

        /** content://<package>.apk/<fileName>; the name is what the receiver sees. */
        fun uri(packageName: String, fileName: String): Uri =
            Uri.Builder().scheme("content").authority("$packageName.apk").appendPath(fileName).build()
    }
}

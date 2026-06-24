package com.qumolangmo.wecho

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import java.io.File

class TccAssetsProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        context?.let { ctx ->
            val filesDir = ctx.filesDir
            val files = listOf(
                "libtcc.a", "libtcc1.a", "tcclib.h", "libtcc.h", "wecho_dsp_c_api.h"
            )
            val includeFiles = listOf(
                "stddef.h", "stdarg.h", "stdbool.h", "stdalign.h", "stdatomic.h",
                "stdnoreturn.h", "float.h", "tccdefs.h", "tgmath.h", "varargs.h"
            )
            
            for (file in files) {
                val dest = File(filesDir, file)
                ctx.assets.open("tcc/$file").use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                }
            }
            
            val includeDir = File(filesDir, "include")
            if (!includeDir.exists()) includeDir.mkdirs()
            
            for (file in includeFiles) {
                val dest = File(includeDir, file)
                ctx.assets.open("tcc/include/$file").use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
        return true
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}

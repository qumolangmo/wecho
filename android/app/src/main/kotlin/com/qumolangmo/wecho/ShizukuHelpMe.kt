/*
 * Copyright (C) 2026 qumolangmo
 *
 * This file is part of Wecho.
 *
 * Wecho is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Wecho is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Wecho.  If not, see <https://www.gnu.org/licenses/>.
 */

package com.qumolangmo.wecho

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import rikka.shizuku.Shizuku
import rikka.shizuku.Shizuku.OnRequestPermissionResultListener
import rikka.shizuku.ShizukuRemoteProcess
import java.io.OutputStream

class ShizukuHelpMe {
    companion object {
        private var shizukuPermissionGranted = false
        private const val TAG = "wecho-kotlin:ShizukuHelper"
        private const val SHIZUKU_PERMISSION_REQUEST_CODE = 1004

        fun isShizukuPermissionGranted(): Boolean {
            return Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        }

        fun checkShizukuStatusAndExecute(
            context: Context,
            onShizukuReady: (() -> Unit)? = null,
            onComplete: ((Boolean) -> Unit)? = null
        ) {
            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                Log.i(TAG, "Shizuku is running and permission is granted")
                shizukuPermissionGranted = true
                val ok = grantPermissionsAndAppOps(context)
                onShizukuReady?.invoke()
                onComplete?.invoke(ok)
                return
            }

            if (!Shizuku.pingBinder()) {
                Log.i(TAG, "Shizuku not running")
                shizukuPermissionGranted = false
                onComplete?.invoke(false)
                return
            }

            Shizuku.requestPermission(SHIZUKU_PERMISSION_REQUEST_CODE)

            Shizuku.addRequestPermissionResultListener(object : OnRequestPermissionResultListener {
                override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                    if (requestCode == SHIZUKU_PERMISSION_REQUEST_CODE) {
                        if (grantResult == PackageManager.PERMISSION_GRANTED) {
                            Log.i(TAG, "Shizuku permission granted")
                            shizukuPermissionGranted = true
                            val ok = grantPermissionsAndAppOps(context)
                            onShizukuReady?.invoke()
                            onComplete?.invoke(ok)
                        } else {
                            Log.w(TAG, "Shizuku permission denied")
                            shizukuPermissionGranted = false
                            onComplete?.invoke(false)
                        }
                    }
                    Shizuku.removeRequestPermissionResultListener(this)
                }
            })
        }

        fun grantPermissionsAndAppOps(context: Context): Boolean {
            if (!shizukuPermissionGranted) {
                Log.w(TAG, "Shizuku permission not granted, cannot grant permissions")
                return false
            }

            val packageName = context.packageName
            val r1 = exec(arrayOf("pm", "grant", packageName, "android.permission.DUMP"))
            Log.i(TAG, "Executed: pm grant $packageName android.permission.DUMP → exit=$r1")

            val r2 = exec(arrayOf("appops", "set", packageName, "PROJECT_MEDIA", "allow"))
            Log.i(TAG, "Executed: appops set $packageName PROJECT_MEDIA allow → exit=$r2")

            return r1 == 0 && r2 == 0
        }

        fun exec(args: Array<String> = arrayOf()): Int {
            return try {
                val newProcessMethod = Shizuku::class.java.getDeclaredMethod(
                    "newProcess",
                    Array<String>::class.java,
                    Array<String>::class.java,
                    String::class.java
                )
                newProcessMethod.isAccessible = true

                val process = newProcessMethod.invoke(
                    null,
                    args,
                    null,
                    null
                ) as ShizukuRemoteProcess

                val outputStream: OutputStream = process.outputStream
                outputStream.flush()
                outputStream.close()
                process.waitFor()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to execute cmd: ${args.joinToString(" ")}", e)
                -1
            }
        }

        private fun execRuntime(cmd: Array<String>): String? {
            return try {
                val proc = Runtime.getRuntime().exec(cmd)
                val out = proc.inputStream.bufferedReader().use { it.readText() }
                proc.waitFor()
                out
            } catch (e: Exception) {
                Log.e(TAG, "execRuntime failed: ${cmd.joinToString(" ")}", e)
                null
            }
        }

        fun dumpAudioPolicy(): String? {
            return execRuntime(arrayOf("dumpsys", "media.audio_policy"))
        }
    }
}
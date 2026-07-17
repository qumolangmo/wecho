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
import android.os.ParcelFileDescriptor
import android.util.Log
import rikka.shizuku.Shizuku
import rikka.shizuku.Shizuku.OnRequestPermissionResultListener
import rikka.shizuku.ShizukuRemoteProcess
import rikka.shizuku.SystemServiceHelper
import java.io.FileInputStream
import java.io.InputStreamReader
import java.io.OutputStream

class ShizukuHelpMe {
    companion object {
        private var shizukuPermissionGranted = false
        private const val TAG = "wecho-kotlin:ShizukuHelper"
        private const val SHIZUKU_PERMISSION_REQUEST_CODE = 1004

        fun isShizukuPermissionGranted(): Boolean {
            return shizukuPermissionGranted
        }

        fun grantPermissionsAndAppOps(context: Context) {
            if (!shizukuPermissionGranted) {
                Log.w(TAG, "Shizuku permission not granted, cannot grant permissions")
                return
            }

            val packageName = context.packageName

            exec(arrayOf("pm", "grant", "$packageName", "android.permission.DUMP"))
            Log.i(TAG, "Executed: pm grant $packageName android.permission.DUMP")

            exec(arrayOf("appops", "set", "$packageName", "PROJECT_MEDIA", "allow"))
            Log.i(TAG, "Executed: appops set $packageName PROJECT_MEDIA allow")
        }

        fun exec(args: Array<String> = arrayOf()) {
            try {
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
            }
        }

        fun checkShizukuStatusAndExecute(context: Context, onShizukuReady: (() -> Unit)? = null) {
            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                Log.i(TAG, "Shizuku is running and permission is granted")
                shizukuPermissionGranted = true
                grantPermissionsAndAppOps(context)
                onShizukuReady?.invoke()
                return
            }

            if (!Shizuku.pingBinder()) {
                Log.i(TAG, "Shizuku not running")
                shizukuPermissionGranted = false
                return
            }

            Shizuku.requestPermission(SHIZUKU_PERMISSION_REQUEST_CODE)

            Shizuku.addRequestPermissionResultListener(object: OnRequestPermissionResultListener {
                override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                    if (requestCode == SHIZUKU_PERMISSION_REQUEST_CODE) {
                        if (grantResult == PackageManager.PERMISSION_GRANTED) {
                            Log.i(TAG, "Shizuku permission granted")
                            shizukuPermissionGranted = true
                            grantPermissionsAndAppOps(context)
                            onShizukuReady?.invoke()
                        } else {
                            Log.w(TAG, "Shizuku permission denied")
                            shizukuPermissionGranted = false
                        }
                    }

                    Shizuku.removeRequestPermissionResultListener(this)
                }
            })
        }

        fun dumpAll2(context: Context, service: String = "media.audio_policy", arg: Array<String> = arrayOf()): String? {
            try {
                val pipe = ParcelFileDescriptor.createPipe()
                val readPipe = pipe[0]
                val writePipe= pipe[1]

                val serviceBinder = SystemServiceHelper.getSystemService(service) ?: return null

                serviceBinder.dumpAsync(writePipe.fileDescriptor, arg)
                writePipe.close()

                val fd = FileInputStream(readPipe.fileDescriptor)
                val reader = InputStreamReader(fd, "UTF-8")
                val dump = reader.readText()
                reader.close()
                readPipe.close()
                fd.close()

                return dump
            } catch (e: Exception) {
                return null
            }
        }
    }
}
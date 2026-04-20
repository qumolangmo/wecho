/**
 * Copyright (c) 2026 qumolangmo
 *
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 *
 * For commercial use, please contact: qumolangmo@gmail.com
 */

package com.qumolangmo.wecho

import android.util.Log
import rikka.shizuku.Shizuku
import rikka.shizuku.Shizuku.OnRequestPermissionResultListener

class ShizukuHelpMe {
    companion object {
        private var shizukuPermissionGranted = false

        fun isShizukuPermissionGranted(): Boolean {
            return shizukuPermissionGranted
        }

        fun checkShizukuStatusAndExecute() {
            if (Shizuku.checkSelfPermission() == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                Log.i(TAG, "shizuku is running and permission is granted")
                shizukuPermissionGranted = true
                return
            }

            if (!Shizuku.pingBinder()) {
                Log.i(TAG, "shizuku not running")
                shizukuPermissionGranted = false
                return
            }

            Shizuku.requestPermission(SHIZUKU_PERMISSION_REQUEST_CODE)

            Shizuku.addRequestPermissionResultListener(object: OnRequestPermissionResultListener {
                override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                    if (requestCode == SHIZUKU_PERMISSION_REQUEST_CODE) {
                        if (grantResult == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            Log.i(TAG, "shizuku permission granted")
                            shizukuPermissionGranted = true
                        } else {
                            Log.w(TAG, "Shizuku permission denied")
                            shizukuPermissionGranted = false
                        }
                    }

                    Shizuku.removeRequestPermissionResultListener(this)
                }
            })
        }

        private const val TAG = "shizuku"
        private const val SHIZUKU_PERMISSION_REQUEST_CODE = 1004
    }
}
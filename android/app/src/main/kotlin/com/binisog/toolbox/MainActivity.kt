package com.binisog.toolbox

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Camera LED control. Replies false where it is unavailable (no flash, or
        // Android 5.x, which has no torch API) so the app falls back to screen light.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "toolbox/torch")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") {
                    result.notImplemented()
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                        val id = cm.cameraIdList.firstOrNull {
                            cm.getCameraCharacteristics(it)
                                .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                        }
                        if (id == null) {
                            result.success(false)
                        } else {
                            cm.setTorchMode(id, call.arguments == true)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            }
    }
}

package com.binisog.toolbox

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.MediaRecorder
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var meter: MediaRecorder? = null
    private var pendingMic: MethodChannel.Result? = null
    private val micRequest = 7001

    private fun meterFile() = File(cacheDir, "meter.3gp")

    /** Starts the microphone for level metering only; the audio itself is discarded on stop. */
    private fun startMeter(): String {
        stopMeter()
        return try {
            @Suppress("DEPRECATION")
            val r = MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
            r.setOutputFile(meterFile().absolutePath)
            r.prepare()
            r.start()
            meter = r
            "ok"
        } catch (e: Exception) {
            "error"
        }
    }

    private fun stopMeter() {
        meter?.let {
            try {
                it.stop()
            } catch (e: Exception) {
            }
            it.release()
        }
        meter = null
        meterFile().delete()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == micRequest) {
            val reply = pendingMic
            pendingMic = null
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            reply?.success(if (granted) startMeter() else "denied")
        }
    }

    override fun onDestroy() {
        stopMeter()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Sound meter: "start" replies ok / denied / error, "level" replies loudness
        // relative to the microphone's maximum in decibels (0 = loudest, -160 = silence).
        MethodChannel(messenger, "toolbox/soundlevel").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                        checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingMic?.success("denied")
                        pendingMic = result
                        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), micRequest)
                    } else {
                        result.success(startMeter())
                    }
                }
                "level" -> {
                    val amp = try {
                        meter?.maxAmplitude ?: -1
                    } catch (e: Exception) {
                        -1
                    }
                    result.success(
                        if (amp < 0) null else if (amp == 0) -160.0 else 20.0 * Math.log10(amp / 32767.0)
                    )
                }
                "stop" -> {
                    stopMeter()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Camera LED control. Replies false where it is unavailable (no flash, or
        // Android 5.x, which has no torch API) so the app falls back to screen light.
        MethodChannel(messenger, "toolbox/torch").setMethodCallHandler { call, result ->
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

        // Wi-Fi signal strength in dBm, or null when Wi-Fi is off or not connected.
        MethodChannel(messenger, "toolbox/wifi").setMethodCallHandler { call, result ->
            if (call.method != "rssi") {
                result.notImplemented()
            } else {
                try {
                    val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                    @Suppress("DEPRECATION")
                    val rssi = wm.connectionInfo?.rssi
                    result.success(if (!wm.isWifiEnabled || rssi == null || rssi <= -127) null else rssi)
                } catch (e: Exception) {
                    result.success(null)
                }
            }
        }

        // Ambient light sensor readings in lux. Errors with "none" if there is no sensor.
        EventChannel(messenger, "toolbox/light").setStreamHandler(object : EventChannel.StreamHandler {
            private var listener: SensorEventListener? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val sensor = sm.getDefaultSensor(Sensor.TYPE_LIGHT)
                if (sensor == null) {
                    events.error("none", "No light sensor", null)
                    return
                }
                val l = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        events.success(event.values[0].toDouble())
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }
                listener = l
                sm.registerListener(l, sensor, SensorManager.SENSOR_DELAY_UI)
            }

            override fun onCancel(arguments: Any?) {
                listener?.let {
                    (getSystemService(Context.SENSOR_SERVICE) as SensorManager).unregisterListener(it)
                }
                listener = null
            }
        })
    }
}

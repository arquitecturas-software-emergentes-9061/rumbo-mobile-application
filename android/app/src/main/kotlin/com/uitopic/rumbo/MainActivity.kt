package com.uitopic.rumbo

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDemo" -> {
                    val heading = (call.argument<Number>("headingDegrees")?.toFloat() ?: 0f)
                    if (!heading.isFinite() || heading < 0f || heading >= 360f) {
                        result.error("INVALID_DIRECTION", "Dirección de prueba inválida.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val unityActivity = listOf(
                            "com.unity3d.player.UnityPlayerActivity",
                            "com.unity3d.player.UnityPlayerGameActivity",
                        ).firstNotNullOfOrNull { name ->
                            try { Class.forName(name) } catch (_: ClassNotFoundException) { null }
                        } ?: throw ClassNotFoundException("Unity activity not found")
                        startActivityForResult(Intent(this, unityActivity).apply {
                            putExtra("rumbo_demo_heading", heading)
                        }, AR_REQUEST)
                        result.success(null)
                    } catch (_: ClassNotFoundException) {
                        result.error("UNITY_NOT_LINKED", "Unity aún no está exportado e integrado en esta compilación.", null)
                    } catch (error: Exception) {
                        result.error("AR_START_FAILED", error.message ?: "No se pudo abrir AR.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$AR_CHANNEL/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    RumboArBridge.attach(events)
                }
                override fun onCancel(arguments: Any?) { RumboArBridge.attach(null) }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "androidSdkVersion" -> result.success(Build.VERSION.SDK_INT)
                "snapshot" -> result.success(BleScanBus.snapshot(applicationContext))
                "discover", "startCapture" -> {
                    if (!BleScanService.reserveStart()) {
                        result.error("ALREADY_RUNNING", "Ya hay un escaneo BLE activo.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(this, BleScanService::class.java).apply {
                            action = if (call.method == "discover") BleScanService.ACTION_DISCOVER else BleScanService.ACTION_CAPTURE
                            if (call.method == "startCapture") {
                                putExtra("referenceLocation", call.argument<String>("referenceLocation"))
                                putExtra("condition", call.argument<String>("condition"))
                                putStringArrayListExtra(
                                    "deviceAddresses",
                                    ArrayList(call.argument<List<String>>("deviceAddresses") ?: emptyList()),
                                )
                                putStringArrayListExtra(
                                    "serviceUuids",
                                    ArrayList(call.argument<List<String>>("serviceUuids") ?: emptyList()),
                                )
                            }
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        BleScanService.releaseStart()
                        result.error("START_FAILED", error.message, null)
                    }
                }
                "stop" -> {
                    if (BleScanService.isReserved()) {
                        startService(Intent(this, BleScanService::class.java).apply {
                            action = BleScanService.ACTION_STOP
                        })
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$CHANNEL/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    BleScanBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    BleScanBus.attach(null)
                }
            })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == AR_REQUEST) {
            RumboArBridge.reportStatus("closed", "returned_to_flutter", java.time.Instant.now().toString())
        }
    }

    companion object {
        private const val CHANNEL = "com.uitopic.rumbo/ble_scan"
        private const val AR_CHANNEL = "com.uitopic.rumbo/ar"
        private const val AR_REQUEST = 6103
    }
}

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

    companion object {
        private const val CHANNEL = "com.uitopic.rumbo/ble_scan"
    }
}

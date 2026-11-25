package com.uitopic.rumbo

import android.content.Intent
import android.os.Build
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var referenceAdvertiser: BleReferenceAdvertiser
    private var pendingCsvExport: MethodChannel.Result? = null
    private var pendingCsvFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        referenceAdvertiser = BleReferenceAdvertiser(applicationContext)

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
                "exportTrackingCsv" -> {
                    beginCsvExport(RumboArBridge.trackingLogFile(this), AR_CSV_FILE, result)
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
                "startReferenceAdvertiser" -> referenceAdvertiser.start(
                    call.argument<String>("beaconUuid").orEmpty(),
                ) { outcome ->
                    runOnUiThread {
                        outcome.fold(
                            onSuccess = { result.success(null) },
                            onFailure = { result.error("ADVERTISE_FAILED", it.message, null) },
                        )
                    }
                }
                "stopReferenceAdvertiser" -> {
                    referenceAdvertiser.stop()
                    result.success(null)
                }
                "snapshot" -> result.success(BleScanBus.snapshot(applicationContext))
                "exportCsv" -> {
                    if (BleScanService.isReserved()) {
                        result.error("CAPTURE_ACTIVE", "Detén la captura antes de exportar el CSV.", null)
                    } else {
                        beginCsvExport(File(filesDir, BleScanService.CSV_FILE), BleScanService.CSV_FILE, result)
                    }
                }
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

    override fun onDestroy() {
        if (::referenceAdvertiser.isInitialized) referenceAdvertiser.stop()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == AR_REQUEST) {
            RumboArBridge.reportStatus("closed", "returned_to_flutter", java.time.Instant.now().toString())
        } else if (requestCode == CSV_EXPORT_REQUEST) {
            val result = pendingCsvExport
            val file = pendingCsvFile
            pendingCsvExport = null
            pendingCsvFile = null
            if (resultCode != RESULT_OK || data?.data == null) {
                result?.success(false)
                return
            }
            if (file == null || !file.isFile) {
                result?.error("CSV_MISSING", "El archivo CSV ya no está disponible.", null)
                return
            }
            try {
                contentResolver.openOutputStream(data.data!!)?.use { output ->
                    file.inputStream().use { input -> input.copyTo(output) }
                } ?: throw IllegalStateException("No se pudo abrir el destino seleccionado.")
                result?.success(true)
            } catch (error: Exception) {
                result?.error("CSV_EXPORT_FAILED", error.message ?: "No se pudo exportar el CSV.", null)
            }
        }
    }

    private fun beginCsvExport(file: File?, name: String, result: MethodChannel.Result) {
        if (pendingCsvExport != null) {
            result.error("EXPORT_BUSY", "Ya hay una exportación en curso.", null)
            return
        }
        if (file == null || !file.isFile) {
            result.error("CSV_MISSING", "Todavía no hay registros CSV para exportar.", null)
            return
        }
        pendingCsvExport = result
        pendingCsvFile = file
        try {
            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "text/csv"
                putExtra(Intent.EXTRA_TITLE, name)
            }, CSV_EXPORT_REQUEST)
        } catch (error: Exception) {
            pendingCsvExport = null
            pendingCsvFile = null
            result.error("CSV_EXPORT_FAILED", error.message ?: "No se pudo abrir el selector de archivos.", null)
        }
    }

    companion object {
        private const val CHANNEL = "com.uitopic.rumbo/ble_scan"
        private const val AR_CHANNEL = "com.uitopic.rumbo/ar"
        private const val AR_REQUEST = 6103
        private const val CSV_EXPORT_REQUEST = 6104
        private const val AR_CSV_FILE = "rumbo_ar_tracking.csv"
    }
}

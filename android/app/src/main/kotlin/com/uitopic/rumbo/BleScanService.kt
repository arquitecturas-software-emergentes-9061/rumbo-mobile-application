package com.uitopic.rumbo

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelUuid
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** Foreground BLE scanning and CSV capture continue while Flutter is paused. */
class BleScanService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val writer = Executors.newSingleThreadExecutor()
    private var scanner: BluetoothLeScanner? = null
    private var scanning = false
    private var discovery = false
    private var navigation = false
    private var running = false
    private var windowResults = 0
    private var referenceLocation = ""
    private var condition = ""
    private var runId = ""
    private var scanFilters: List<ScanFilter> = emptyList()
    private val lastRecordedAt = mutableMapOf<String, Long>()
    private val lastEmittedAt = mutableMapOf<String, Long>()
    private var persistedCount = 0

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            handler.post { handleResult(result) }
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { result -> handler.post { handleResult(result) } }
        }

        override fun onScanFailed(errorCode: Int) {
            handler.post { fail("El escaneo BLE falló (código $errorCode).") }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val file = File(filesDir, CSV_FILE)
        persistedCount = if (file.exists()) {
            getSharedPreferences(PREFERENCES, MODE_PRIVATE).getInt("saved_count", 0)
        } else {
            0
        }
        BleScanBus.savedCount = persistedCount
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (running) return START_NOT_STICKY

        discovery = intent?.action == ACTION_DISCOVER
        navigation = intent?.action == ACTION_NAVIGATION
        if (!discovery && !navigation && intent?.action != ACTION_CAPTURE) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (!hasScanPermissions()) {
            BleScanBus.updateStatus("permissionsDenied", "Faltan permisos BLE o ubicación precisa.")
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            startForeground(NOTIFICATION_ID, buildNotification())
            if (navigation) {
                scanFilters = intent?.getStringArrayListExtra("beaconIdentities").orEmpty().distinct().map { identity ->
                    val parts = identity.split('/')
                    require(parts.size == 3) { "Identidad de baliza inválida." }
                    val uuid = UUID.fromString(parts[0])
                    val major = parts[1].toInt()
                    val minor = parts[2].toInt()
                    require(major in 0..65535 && minor in 0..65535)
                    val data = java.nio.ByteBuffer.allocate(22).put(0x02.toByte()).put(0x15.toByte())
                        .putLong(uuid.mostSignificantBits).putLong(uuid.leastSignificantBits)
                        .putShort(major.toShort()).putShort(minor.toShort()).array()
                    ScanFilter.Builder().setManufacturerData(0x004C, data, ByteArray(data.size) { 0xFF.toByte() }).build()
                }
                require(scanFilters.isNotEmpty()) { "No hay balizas registradas para navegar." }
            } else if (!discovery) {
                referenceLocation = intent?.getStringExtra("referenceLocation")?.trim().orEmpty()
                condition = intent?.getStringExtra("condition")?.trim().orEmpty()
                runId = UUID.randomUUID().toString()
                val addresses = intent?.getStringArrayListExtra("deviceAddresses").orEmpty()
                val serviceUuids = intent?.getStringArrayListExtra("serviceUuids").orEmpty()
                if (referenceLocation.isEmpty() || condition.isEmpty()) {
                    throw IllegalArgumentException("Faltan ubicación o condición de prueba.")
                }
                scanFilters = buildFilters(addresses, serviceUuids)
                if (scanFilters.isEmpty()) {
                    throw IllegalArgumentException("La captura con pantalla bloqueada requiere un filtro BLE.")
                }
            }
            running = true
            BleScanBus.updateStatus(if (discovery) "discovering" else "scanning")
            handler.post { startWindow() }
        } catch (error: Exception) {
            fail("No se pudo iniciar BLE: ${error.message}")
        }
        return START_NOT_STICKY
    }

    private fun buildFilters(addresses: List<String>, serviceUuids: List<String>): List<ScanFilter> {
        val filters = mutableListOf<ScanFilter>()
        addresses.distinct().forEach { address ->
            if (!BluetoothAdapter.checkBluetoothAddress(address)) {
                throw IllegalArgumentException("Dirección BLE inválida: $address")
            }
            filters.add(ScanFilter.Builder().setDeviceAddress(address).build())
        }
        serviceUuids.distinct().forEach { value ->
            filters.add(
                ScanFilter.Builder().setServiceUuid(ParcelUuid(UUID.fromString(value))).build(),
            )
        }
        return filters
    }

    private fun startWindow() {
        if (!running || scanning) return
        if (!hasScanPermissions()) {
            BleScanBus.updateStatus("permissionsDenied", "Faltan permisos BLE o ubicación precisa.")
            stopSelf()
            return
        }
        if (!locationEnabled()) {
            BleScanBus.updateStatus("locationOff", "Activa la ubicación del dispositivo.")
            stopSelf()
            return
        }
        try {
            val manager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = manager.adapter
            if (adapter == null) {
                BleScanBus.updateStatus("unsupported", "Este dispositivo no admite Bluetooth LE.")
                stopSelf()
                return
            }
            if (!adapter.isEnabled) {
                BleScanBus.updateStatus("bluetoothOff", "Activa Bluetooth para continuar.")
                stopSelf()
                return
            }
            scanner = adapter.bluetoothLeScanner
            if (scanner == null) {
                fail("No se pudo acceder al escáner BLE.")
                return
            }
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_BALANCED)
                .setReportDelay(0L)
                .build()
            windowResults = 0
            scanner!!.startScan(scanFilters, settings, scanCallback)
            scanning = true
            BleScanBus.updateStatus(if (discovery) "discovering" else "scanning")
            handler.postDelayed({ finishWindow() }, if (discovery) DISCOVERY_MS else SCAN_MS)
        } catch (error: SecurityException) {
            BleScanBus.updateStatus("permissionsDenied", "Permiso BLE revocado: ${error.message}")
            stopSelf()
        } catch (error: Exception) {
            fail("No se pudo escanear: ${error.message}")
        }
    }

    private fun finishWindow() {
        if (!running) return
        stopScan()
        if (windowResults == 0) {
            BleScanBus.updateStatus(
                if (discovery) "noDevices" else "empty",
                "No se detectaron balizas en esta ventana.",
            )
        }
        if (discovery) {
            stopSelf()
        } else {
            if (windowResults > 0) BleScanBus.updateStatus("paused", "Pausa para ahorrar batería.")
            handler.postDelayed({ startWindow() }, IDLE_MS)
        }
    }

    private fun handleResult(result: ScanResult) {
        if (!running || !scanning) return
        val now = System.currentTimeMillis()
        val deviceId = result.device.address ?: return
        val name = result.scanRecord?.deviceName.orEmpty()
        val manufacturerData = manufacturerDataHex(result)
        windowResults++

        if (now - (lastEmittedAt[deviceId] ?: 0L) >= EVENT_INTERVAL_MS) {
            lastEmittedAt[deviceId] = now
            BleScanBus.observation(deviceId, name, result.rssi, now, manufacturerData)
        }
        if (discovery || navigation || now - (lastRecordedAt[deviceId] ?: 0L) < SAMPLE_INTERVAL_MS) return

        lastRecordedAt[deviceId] = now
        val rssi = result.rssi
        val sampleLocation = referenceLocation
        val sampleCondition = condition
        val sampleRunId = runId
        writer.execute {
            try {
                appendCsv(now, deviceId, name, manufacturerData, rssi, sampleLocation, sampleCondition, sampleRunId)
                persistedCount++
                getSharedPreferences(PREFERENCES, MODE_PRIVATE)
                    .edit().putInt("saved_count", persistedCount).apply()
                BleScanBus.saved(persistedCount)
            } catch (error: Exception) {
                handler.post { fail("No se pudo guardar el CSV: ${error.message}") }
            }
        }
    }

    private fun appendCsv(
        timestampMs: Long,
        deviceId: String,
        name: String,
        manufacturerData: String,
        rssi: Int,
        sampleLocation: String,
        sampleCondition: String,
        sampleRunId: String,
    ) {
        val file = File(filesDir, CSV_FILE)
        val headerNeeded = !file.exists() || file.length() == 0L
        FileOutputStream(file, true).bufferedWriter(Charsets.UTF_8).use { output ->
            if (headerNeeded) {
                output.appendLine(BleCsvFormatter.HEADER)
            }
            output.appendLine(
                BleCsvFormatter.row(
                    timestampMs,
                    deviceId,
                    name,
                    manufacturerData,
                    rssi,
                    sampleLocation,
                    sampleCondition,
                    sampleRunId,
                ),
            )
        }
    }

    private fun manufacturerDataHex(result: ScanResult): String {
        val data = result.scanRecord?.manufacturerSpecificData ?: return ""
        return (0 until data.size()).joinToString(";") { index ->
            val id = data.keyAt(index)
            val bytes = data.valueAt(index)
            "%04X:%s".format(Locale.US, id, bytes.joinToString("") { "%02X".format(it) })
        }
    }

    private fun stopScan() {
        if (!scanning) return
        scanning = false
        try {
            scanner?.stopScan(scanCallback)
        } catch (_: Exception) {
            // The scan may already have stopped after permission revocation.
        }
        scanner = null
    }

    private fun hasScanPermissions(): Boolean {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    private fun locationEnabled(): Boolean {
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    private fun buildNotification(): Notification {
        val channelId = "rumbo_ble_capture"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Captura BLE de Rumbo",
                NotificationManager.IMPORTANCE_LOW,
            )
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
        val stopIntent = Intent(this, BleScanService::class.java).apply { action = ACTION_STOP }
        val stopAction = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Rumbo · diagnóstico BLE")
            .setContentText("Capturando señales RSSI de referencia")
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Detener", stopAction)
            .build()
    }

    private fun fail(message: String) {
        BleScanBus.updateStatus("error", message)
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        stopScan()
        writer.shutdown()
        try {
            writer.awaitTermination(3, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        releaseStart()
        if (BleScanBus.status == "scanning" || BleScanBus.status == "paused" ||
            BleScanBus.status == "discovering" || BleScanBus.status == "empty") {
            BleScanBus.updateStatus("idle", "Escaneo detenido.")
        }
        super.onDestroy()
    }

    companion object {
        const val ACTION_DISCOVER = "com.uitopic.rumbo.ble.DISCOVER"
        const val ACTION_CAPTURE = "com.uitopic.rumbo.ble.CAPTURE"
        const val ACTION_NAVIGATION = "com.uitopic.rumbo.ble.NAVIGATION"
        const val ACTION_STOP = "com.uitopic.rumbo.ble.STOP"
        const val CSV_FILE = "rumbo_rssi_reference_v2.csv"
        private const val PREFERENCES = "rumbo_ble_capture"
        private const val NOTIFICATION_ID = 4242
        private const val DISCOVERY_MS = 10_000L
        private const val SCAN_MS = 5_000L
        private const val IDLE_MS = 15_000L
        private const val SAMPLE_INTERVAL_MS = 500L
        private const val EVENT_INTERVAL_MS = 500L
        private val reserved = AtomicBoolean(false)

        fun reserveStart(): Boolean = reserved.compareAndSet(false, true)
        fun releaseStart() { reserved.set(false) }
        fun isReserved(): Boolean = reserved.get()
    }
}

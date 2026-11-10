package com.uitopic.rumbo

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import java.nio.ByteBuffer
import java.util.UUID

/** Debug experiment only: advertises an iBeacon identity for RSSI capture. */
class BleReferenceAdvertiser(context: Context) {
    private val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private var callback: AdvertiseCallback? = null

    fun start(beaconUuid: String, onResult: (Result<Unit>) -> Unit) {
        if (callback != null) {
            onResult(Result.failure(IllegalStateException("El emisor BLE ya está activo.")))
            return
        }
        val uuid = runCatching { UUID.fromString(beaconUuid.trim()) }.getOrElse {
            onResult(Result.failure(IllegalArgumentException("Ingresa un UUID de baliza válido.")))
            return
        }
        try {
            val adapter: BluetoothAdapter? = manager.adapter
            val advertiser = adapter?.bluetoothLeAdvertiser
            if (adapter == null || !adapter.isEnabled || advertiser == null) {
                onResult(Result.failure(IllegalStateException("Este dispositivo no puede anunciar BLE ahora.")))
                return
            }
            val active = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    onResult(Result.success(Unit))
                }

                override fun onStartFailure(errorCode: Int) {
                    callback = null
                    onResult(Result.failure(IllegalStateException("Android no inició el anuncio BLE (código $errorCode).")))
                }
            }
            callback = active
            advertiser.startAdvertising(
                AdvertiseSettings.Builder()
                    .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                    .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                    .setConnectable(false)
                    .build(),
                AdvertiseData.Builder()
                    .setIncludeTxPowerLevel(false)
                    .addManufacturerData(0x004C, beaconPayload(uuid))
                    .build(),
                active,
            )
        } catch (error: SecurityException) {
            callback = null
            onResult(Result.failure(IllegalStateException("Android denegó el permiso para anunciar BLE.", error)))
        }
    }

    private fun beaconPayload(uuid: UUID): ByteArray = ByteBuffer.allocate(23)
        .put(0x02.toByte())
        .put(0x15.toByte())
        .putLong(uuid.mostSignificantBits)
        .putLong(uuid.leastSignificantBits)
        .putShort(1.toShort())
        .putShort(1.toShort())
        .put((-59).toByte()) // Nominal reference power, not a measured calibration.
        .array()

    fun stop() {
        val active = callback ?: return
        callback = null
        try {
            manager.adapter?.bluetoothLeAdvertiser?.stopAdvertising(active)
        } catch (_: SecurityException) {
            // The advertising permission may have been revoked while the screen was open.
        }
    }
}

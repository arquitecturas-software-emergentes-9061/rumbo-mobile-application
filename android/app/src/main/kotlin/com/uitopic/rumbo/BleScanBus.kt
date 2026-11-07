package com.uitopic.rumbo

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.File

/** Delivers live events to Flutter while native capture persists independently. */
object BleScanBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    @Volatile var status: String = "idle"
        private set
    @Volatile var message: String = ""
        private set
    @Volatile var savedCount: Int = 0

    fun attach(events: EventChannel.EventSink?) {
        mainHandler.post { sink = events }
    }

    fun updateStatus(nextStatus: String, nextMessage: String = "") {
        status = nextStatus
        message = nextMessage
        emit(mapOf("type" to "status", "status" to nextStatus, "message" to nextMessage))
    }

    fun observation(
        deviceId: String,
        name: String,
        rssi: Int,
        timestampMs: Long,
        manufacturerData: String,
    ) {
        emit(
            mapOf(
                "type" to "observation",
                "deviceId" to deviceId,
                "name" to name,
                "rssi" to rssi,
                "timestampMs" to timestampMs,
                "manufacturerData" to manufacturerData,
            ),
        )
    }

    fun saved(total: Int) {
        savedCount = total
        emit(mapOf("type" to "saved", "total" to total))
    }

    fun snapshot(context: Context): Map<String, Any> {
        val file = File(context.filesDir, BleScanService.CSV_FILE)
        val count = if (file.exists()) {
            maxOf(
                savedCount,
                context.getSharedPreferences("rumbo_ble_capture", Context.MODE_PRIVATE)
                    .getInt("saved_count", 0),
            )
        } else {
            0
        }
        return mapOf(
            "status" to status,
            "message" to message,
            "savedCount" to count,
            "filePath" to file.absolutePath,
        )
    }

    private fun emit(event: Map<String, Any>) {
        mainHandler.post { sink?.success(event) }
    }
}

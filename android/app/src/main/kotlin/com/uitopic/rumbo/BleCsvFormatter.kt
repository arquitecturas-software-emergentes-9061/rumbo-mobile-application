package com.uitopic.rumbo

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** CSV rows are self-contained so each observation can be flushed immediately. */
object BleCsvFormatter {
    const val HEADER = "timestamp_utc,device_id,advertised_name,manufacturer_data,rssi_dbm,reference_location,condition"

    fun row(
        timestampMs: Long,
        deviceId: String,
        name: String,
        manufacturerData: String,
        rssi: Int,
        referenceLocation: String,
        condition: String,
    ): String {
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(timestampMs))
        return listOf(
            timestamp,
            deviceId,
            name,
            manufacturerData,
            rssi.toString(),
            referenceLocation,
            condition,
        ).joinToString(",") { cell(it) }
    }

    private fun cell(value: String): String {
        return "\"${value.replace("\r", " ").replace("\n", " ").replace("\"", "\"\"")}\""
    }
}

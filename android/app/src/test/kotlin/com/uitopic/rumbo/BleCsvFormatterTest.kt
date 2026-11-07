package com.uitopic.rumbo

import org.junit.Assert.assertEquals
import org.junit.Test

class BleCsvFormatterTest {
    @Test
    fun escapesReferenceLabelsAndUsesUtcTimestamp() {
        val row = BleCsvFormatter.row(
            timestampMs = 0L,
            deviceId = "AA:BB:CC:DD:EE:FF",
            name = "Beacon",
            manufacturerData = "004C:0102",
            rssi = -70,
            referenceLocation = "Piso 1, \"recepción\"",
            condition = "caminando\npuerta abierta",
        )

        assertEquals(
            "\"1970-01-01T00:00:00.000Z\",\"AA:BB:CC:DD:EE:FF\",\"Beacon\",\"004C:0102\",\"-70\",\"Piso 1, \"\"recepción\"\"\",\"caminando puerta abierta\"",
            row,
        )
    }
}

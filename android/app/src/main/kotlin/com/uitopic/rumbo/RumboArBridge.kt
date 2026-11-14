package com.uitopic.rumbo

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Unity calls this class only after its Android library has been exported and linked. */
object RumboArBridge {
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    fun attach(events: EventChannel.EventSink?) {
        handler.post { sink = events }
    }

    @JvmStatic
    fun reportStatus(state: String, reason: String, timestampUtc: String) {
        handler.post {
            sink?.success(mapOf("state" to state, "reason" to reason, "timestampUtc" to timestampUtc))
        }
    }
}

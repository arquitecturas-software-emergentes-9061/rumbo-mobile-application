package com.uitopic.rumbo

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.File

/** Unity calls this class only after its Android library has been exported and linked. */
object RumboArBridge {
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    @Volatile private var trackingLogPath: String? = null

    fun attach(events: EventChannel.EventSink?) {
        handler.post { sink = events }
    }

    @JvmStatic
    fun reportStatus(state: String, reason: String, timestampUtc: String) {
        handler.post {
            sink?.success(mapOf("state" to state, "reason" to reason, "timestampUtc" to timestampUtc))
        }
    }

    @JvmStatic
    fun reportLogPath(path: String) {
        trackingLogPath = path
    }

    fun trackingLogFile(context: Context): File? {
        val roots = listOfNotNull(context.filesDir, context.getExternalFilesDir(null))
        val candidates = mutableListOf<File>()
        trackingLogPath?.let { candidates.add(File(it)) }
        candidates.addAll(roots.map { File(it, "rumbo_ar_tracking.csv") })
        return candidates.firstOrNull { candidate ->
            candidate.isFile && roots.any { root ->
                val rootPath = root.canonicalFile.path + File.separator
                candidate.canonicalFile.path.startsWith(rootPath)
            }
        }
    }
}

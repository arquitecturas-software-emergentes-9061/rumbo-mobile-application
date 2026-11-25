package com.uitopic.rumbo

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.window.OnBackInvokedDispatcher
import androidx.annotation.Keep
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.lang.ref.WeakReference

/** Unity calls this class only after its Android library has been exported and linked. */
@Keep
object RumboArBridge {
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var hud: RumboArHud? = null
    private var player = WeakReference<Activity>(null)
    private var lifecycleRegistered = false
    private var requestedDestination: String? = null
    private var requestedHeading: Float? = null
    private var live = false
    private var sensorManager: SensorManager? = null
    @Volatile private var heading: Pair<Long, Double>? = null
    private val rotation = object : SensorEventListener {
        private val matrix = FloatArray(9)
        private var accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
        override fun onAccuracyChanged(sensor: Sensor, value: Int) { accuracy = value }
        override fun onSensorChanged(event: SensorEvent) {
            if (accuracy < SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM ||
                (event.values.size >= 5 && event.values[4] >= 0 && event.values[4] > .44f)) {
                heading = null
                return
            }
            SensorManager.getRotationMatrixFromVector(matrix, event.values)
            // The rear camera looks down device -Z. Project it onto magnetic east/north.
            val east = -matrix[2].toDouble()
            val north = -matrix[5].toDouble()
            heading = if (kotlin.math.hypot(east, north) > .35)
                System.currentTimeMillis() to Math.toDegrees(kotlin.math.atan2(east, north)) else null
        }
    }

    @JvmStatic
    fun cameraMagneticHeading(): Double {
        val sample = heading ?: return Double.NaN
        return if (System.currentTimeMillis() - sample.first in 0..1000) sample.second else Double.NaN
    }
    @Volatile private var trackingLogPath: String? = null

    fun attach(events: EventChannel.EventSink?) {
        handler.post { sink = events }
    }

    fun registerHost(activity: Activity) {
        if (lifecycleRegistered) return
        lifecycleRegistered = true
        activity.application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                if (activity == player.get()) {
                    if (requestedDestination != null || requestedHeading != null) present()
                    else if (live) startHeading(activity)
                }
            }
            override fun onActivityPaused(activity: Activity) {
                if (activity == player.get()) stopHeading()
            }
            override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) = Unit
            override fun onActivityStopped(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) {
                if (activity != player.get()) return
                hud?.remove()
                hud = null
                player.clear()
                stopHeading()
                if (live) event("closed", "activity_destroyed")
                live = false
            }
        })
    }

    fun requestNavigation(destination: String) {
        requestedDestination = destination
        requestedHeading = null
    }

    fun requestDemo(heading: Float) {
        requestedDestination = null
        requestedHeading = heading
    }

    @JvmStatic
    fun attachPlayer(activity: Activity) {
        handler.post {
            if (player.get() != activity && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.onBackInvokedDispatcher.registerOnBackInvokedCallback(
                    OnBackInvokedDispatcher.PRIORITY_DEFAULT
                ) {
                    event("closed", "android_back")
                    showFlutter()
                }
            }
            player = WeakReference(activity)
            if (requestedDestination != null || requestedHeading != null) present()
        }
    }

    private fun present() {
        val activity = player.get() ?: return
        requestedHeading?.let { heading ->
            hideNavigation()
            runCatching { unitySend("ResetDemo", heading.toString()) }
                .onFailure { event("error", "demo_message_failed") }
            return
        }
        val destination = requestedDestination ?: return
        requestedDestination = null
        requestedHeading = null
        live = true
        startHeading(activity)
        hud?.remove()
        hud = RumboArHud(activity, destination, { event("show_map", "user_requested"); showFlutter() },
            { event("end_navigation", "user_requested"); showFlutter() },
            { event("recalibrate", "user_requested") })
        event("navigation_ready", "android_host")
    }

    fun hideNavigation() {
        requestedDestination = null
        requestedHeading = null
        live = false
        hud?.remove()
        hud = null
        stopHeading()
    }

    private fun startHeading(activity: Activity) {
        stopHeading()
        val manager = activity.getSystemService(SensorManager::class.java) ?: return
        val sensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) ?: return
        if (manager.registerListener(rotation, sensor, SensorManager.SENSOR_DELAY_UI)) sensorManager = manager
    }

    private fun stopHeading() {
        sensorManager?.unregisterListener(rotation)
        sensorManager = null
        heading = null
    }

    private fun showFlutter() {
        val activity = player.get() ?: return
        hideNavigation()
        activity.startActivity(Intent(activity, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP))
    }

    @JvmStatic
    fun returnToFlutter() {
        handler.post { showFlutter() }
    }

    fun updateHud(status: String, progress: Int) { hud?.update(status, progress) }

    fun send(receiver: String, payload: String) {
        check(live)
        require(receiver in setOf("ReceiveRoute", "ReceivePositionFix", "ReceiveProgress",
            "InvalidateCalibration") && payload.length <= 524288)
        unitySend(receiver, payload)
    }

    private fun unitySend(receiver: String, payload: String) {
        val type = Class.forName("com.unity3d.player.UnityPlayer")
        type.getMethod("UnitySendMessage", String::class.java, String::class.java, String::class.java)
            .invoke(null, "RumboArController", receiver, payload)
    }

    private fun event(state: String, reason: String) {
        sink?.success(mapOf("state" to state, "reason" to reason,
            "timestampUtc" to java.time.Instant.now().toString()))
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

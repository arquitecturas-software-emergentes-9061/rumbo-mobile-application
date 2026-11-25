package com.uitopic.rumbo

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

/** Android controls layered over Unity's full-screen camera surface. */
internal class RumboArHud(
    private val activity: Activity,
    destination: String,
    showMap: () -> Unit,
    endRoute: () -> Unit,
    recalibrate: () -> Unit,
) {
    private val blue = Color.rgb(22, 62, 216)
    private val ink = Color.rgb(18, 30, 50)
    private val root = FrameLayout(activity)
    private val status = label("Buscando el suelo…", 20, ink, true)
    private val progress = ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal)
    private val back = if (android.os.Build.VERSION.SDK_INT >= 33) android.window.OnBackInvokedCallback {
        showMap()
    } else null

    init {
        val top = panel(0xEF19253A.toInt())
        top.addView(label("Rumbo", 13, 0xFFE0E8FF.toInt(), true))
        top.addView(label(destination, 19, Color.WHITE, true))
        root.addView(top, anchored(Gravity.TOP))

        val bottom = panel(0xFFF6F8FF.toInt())
        bottom.addView(status)
        progress.max = 100
        progress.progressTintList = ColorStateList.valueOf(blue)
        progress.contentDescription = "Progreso del recorrido"
        bottom.addView(progress, LinearLayout.LayoutParams(-1, dp(15)))
        val actions = LinearLayout(activity)
        actions.addView(button("Ver en 2D", showMap), LinearLayout.LayoutParams(0, -2, 1f))
        actions.addView(button("Calibrar", recalibrate), LinearLayout.LayoutParams(0, -2, 1f))
        actions.addView(button("Finalizar", endRoute), LinearLayout.LayoutParams(0, -2, 1f))
        bottom.addView(actions)
        root.addView(bottom, anchored(Gravity.BOTTOM))
        root.setOnApplyWindowInsetsListener { _, insets ->
            @Suppress("DEPRECATION")
            root.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
        activity.addContentView(root, ViewGroup.LayoutParams(-1, -1))
        if (android.os.Build.VERSION.SDK_INT >= 33 && back != null) {
            activity.onBackInvokedDispatcher.registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_OVERLAY, back)
        }
        root.requestApplyInsets()
    }

    fun update(message: String, percent: Int) {
        if (message.isNotBlank()) status.text = message
        progress.progress = percent.coerceIn(0, 100)
    }

    fun remove() {
        if (android.os.Build.VERSION.SDK_INT >= 33 && back != null) {
            activity.onBackInvokedDispatcher.unregisterOnBackInvokedCallback(back)
        }
        (root.parent as? ViewGroup)?.removeView(root)
    }

    private fun dp(value: Int) = (value * activity.resources.displayMetrics.density + .5f).toInt()
    private fun anchored(gravity: Int) = FrameLayout.LayoutParams(-1, -2, gravity).apply {
        setMargins(dp(12), dp(12), dp(12), dp(12))
    }

    private fun panel(color: Int) = LinearLayout(activity).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(14), dp(12), dp(14), dp(12))
        background = GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(16).toFloat()
        }
    }

    private fun label(value: String, size: Int, color: Int, bold: Boolean) = TextView(activity).apply {
        text = value
        textSize = size.toFloat()
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun button(title: String, action: () -> Unit) = Button(activity).apply {
        text = title
        isAllCaps = false
        setTextColor(if (title == "Finalizar") 0xFF9B242B.toInt() else blue)
        setPadding(dp(2), 0, dp(2), 0)
        minHeight = dp(48)
        setOnClickListener { action() }
    }
}

package com.slovofon.app

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Hardware capabilities, not display size: a landscape tablet is not a TV. */
data class SlovofonDeviceProfile(
    val uiModeType: Int,
    val hasLeanbackFeature: Boolean,
    val hasTouchscreen: Boolean,
) {
    val isTelevision: Boolean
        get() = uiModeType == Configuration.UI_MODE_TYPE_TELEVISION || hasLeanbackFeature

    fun toMap(): Map<String, Any> = mapOf(
        "isTelevision" to isTelevision,
        "uiModeType" to uiModeType,
        "hasLeanbackFeature" to hasLeanbackFeature,
        "hasTouchscreen" to hasTouchscreen,
    )

    companion object {
        fun read(context: Context): SlovofonDeviceProfile {
            val application = context.applicationContext
            val uiMode = application.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            val modeType = uiMode?.currentModeType
                ?: (application.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK)
            return SlovofonDeviceProfile(
                uiModeType = modeType,
                hasLeanbackFeature = application.packageManager.hasSystemFeature(
                    PackageManager.FEATURE_LEANBACK,
                ),
                hasTouchscreen = application.packageManager.hasSystemFeature(
                    PackageManager.FEATURE_TOUCHSCREEN,
                ),
            )
        }
    }
}

object SlovofonDeviceProfileChannel {
    const val CHANNEL_NAME = "com.slovofon.app/device_profile"

    fun attach(messenger: BinaryMessenger, context: Context) {
        val application = context.applicationContext
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceProfile" -> result.success(SlovofonDeviceProfile.read(application).toMap())
                else -> result.notImplemented()
            }
        }
    }
}

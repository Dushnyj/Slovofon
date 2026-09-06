package com.slovofon.app

import android.app.Activity
import android.app.Instrumentation
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle

/** Device-only profile and TV packaging checks; no audio or user-data access. */
class SlovofonTvInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val results = Bundle()
        try {
            for (mode in listOf(
                Configuration.UI_MODE_TYPE_NORMAL,
                Configuration.UI_MODE_TYPE_TELEVISION,
                Configuration.UI_MODE_TYPE_DESK,
                Configuration.UI_MODE_TYPE_CAR,
            )) {
                for (leanback in listOf(false, true)) {
                    for (touch in listOf(false, true)) {
                        val profile = SlovofonDeviceProfile(mode, leanback, touch)
                        check(profile.isTelevision ==
                            (mode == Configuration.UI_MODE_TYPE_TELEVISION || leanback))
                        check(profile.toMap()["hasTouchscreen"] == touch)
                        check(profile.toMap()["uiModeType"] == mode)
                    }
                }
            }
            val actual = SlovofonDeviceProfile.read(targetContext)
            val manager = targetContext.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
            val packages = targetContext.packageManager
            check(actual.uiModeType == manager.currentModeType)
            check(actual.hasLeanbackFeature == packages.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
            check(actual.hasTouchscreen == packages.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN))
            val launcher = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER)
                .setPackage(targetContext.packageName)
            val resolved = packages.resolveActivity(launcher, 0)
            check(resolved?.activityInfo?.name == MainActivity::class.java.name)
            check(packages.getApplicationInfo(targetContext.packageName, 0).banner != 0)
            results.putString("profile", actual.toMap().toString())
            results.putString("stream", "PASS: 16 profile signal combinations, current device capabilities, Leanback launcher and banner\n")
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString("stream", "FAIL: ${error.javaClass.simpleName}: ${error.message}\n")
            finish(Activity.RESULT_CANCELED, results)
        }
    }
}

package com.slovofon.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {
    private var updateInstallerChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SlovofonMediaSessionBridge.attach(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )
        updateInstallerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.slovofon.app/update_installer",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallApks" -> result.success(canInstallApks())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_path", "APK path is empty", null)
                        } else {
                            installApk(path, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        updateInstallerChannel?.setMethodCallHandler(null)
        updateInstallerChannel = null
        SlovofonMediaSessionBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun canInstallApks(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apk = File(path)
        if (!apk.exists()) {
            result.error("apk_missing", "APK file does not exist", null)
            return
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(intent)
        result.success(null)
    }

    override fun onDestroy() {
        val shouldTerminateProcess = isFinishing && !isChangingConfigurations

        super.onDestroy()

        if (shouldTerminateProcess) {
            Process.killProcess(Process.myPid())
            exitProcess(0)
        }
    }
}

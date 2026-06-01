package com.slovofon.app

import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SlovofonMediaSessionBridge.attach(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        SlovofonMediaSessionBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
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

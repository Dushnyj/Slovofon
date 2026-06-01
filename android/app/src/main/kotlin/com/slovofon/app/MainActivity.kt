package com.slovofon.app

import android.os.Process
import com.ryanheise.audioservice.AudioServiceActivity
import kotlin.system.exitProcess

class MainActivity : AudioServiceActivity() {
    override fun onDestroy() {
        val shouldTerminateProcess = isFinishing && !isChangingConfigurations

        super.onDestroy()

        if (shouldTerminateProcess) {
            Process.killProcess(Process.myPid())
            exitProcess(0)
        }
    }
}

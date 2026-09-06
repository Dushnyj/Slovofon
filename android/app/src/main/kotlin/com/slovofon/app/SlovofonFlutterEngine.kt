package com.slovofon.app

import android.content.Context
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/** One app-level Dart isolate shared by foreground playback and successive UI hosts. */
object SlovofonFlutterEngine {
    private var engine: FlutterEngine? = null

    fun getOrCreate(context: Context): FlutterEngine {
        check(Looper.myLooper() == Looper.getMainLooper())
        engine?.let { return it }
        val created = FlutterEngine(context.applicationContext)
        // Bootstrap selects the TV UI before runApp, including headless starts.
        // Register on the engine, not on an Activity that may attach later.
        SlovofonDeviceProfileChannel.attach(
            created.dartExecutor.binaryMessenger,
            context.applicationContext,
        )
        // Attach before executing main: initial restored-player snapshots can arrive
        // before an Activity is configured, or while no Activity is attached.
        SlovofonMediaSessionBridge.attach(
            created.dartExecutor.binaryMessenger,
            context.applicationContext,
        )
        engine = created
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }
}

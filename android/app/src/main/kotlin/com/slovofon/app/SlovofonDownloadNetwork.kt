package com.slovofon.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Only exposes booleans; never reads network identifiers. */
internal class SlovofonDownloadNetwork(context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val preferences = context.getSharedPreferences("slovofon_download_policy", Context.MODE_PRIVATE)
    private val main = Handler(Looper.getMainLooper())
    private var listener: EventChannel.EventSink? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var last: Map<String, Boolean>? = null

    init {
        EventChannel(messenger, "com.slovofon.app/download_network_events").setStreamHandler(this)
        MethodChannel(messenger, "com.slovofon.app/download_network").setMethodCallHandler { call, result ->
            when (call.method) {
                "setWifiOnly" -> {
                    val enabled = call.arguments as? Boolean
                    if (enabled == null) {
                        result.error("invalid_argument", null, null)
                    } else {
                        val before = preferences.getBoolean("wifi_only", false)
                        if (!preferences.edit().putBoolean("wifi_only", enabled).commit()) {
                            preferences.edit().putBoolean("wifi_only", before).apply()
                            result.error("save_failed", null, null)
                        } else {
                            result.success(publish())
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        onCancel(null)
        listener = events
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = refresh()
            override fun onLost(network: Network) = refresh()
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = refresh()

            private fun refresh() {
                main.post { if (callback === this) publish() }
            }
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                connectivity.registerDefaultNetworkCallback(networkCallback)
            } else {
                connectivity.registerNetworkCallback(
                    NetworkRequest.Builder()
                        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                        .build(),
                    networkCallback,
                )
            }
            callback = networkCallback
        } catch (_: RuntimeException) {
            // Fail closed if Android cannot report network changes.
            callback = null
        }
        publish()
    }

    override fun onCancel(arguments: Any?) {
        listener = null
        last = null
        callback?.let {
            runCatching { connectivity.unregisterNetworkCallback(it) }
        }
        callback = null
    }

    private fun publish(): Map<String, Boolean> {
        val caps = if (callback == null) null else connectivity.activeNetwork
            ?.let(connectivity::getNetworkCapabilities)
        val state = mapOf(
            "connected" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true),
            "wifi" to (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true &&
                !caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)),
            "wifiOnly" to preferences.getBoolean("wifi_only", false),
        )
        if (state != last) {
            last = state
            listener?.success(state)
        }
        return state
    }
}

package com.example.meatvo_official

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.meatvo.meatvo/maps_config",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMapsConfig" -> {
                    try {
                        val appInfo = packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.GET_META_DATA,
                        )
                        val apiKey =
                            appInfo.metaData?.getString("com.google.android.geo.API_KEY")
                                ?: ""
                        result.success(
                            mapOf(
                                "applicationId" to packageName,
                                "mapsApiKeyLength" to apiKey.length,
                                "mapsApiKeyConfigured" to apiKey.isNotEmpty(),
                            ),
                        )
                    } catch (e: Exception) {
                        result.error("MAPS_CONFIG", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

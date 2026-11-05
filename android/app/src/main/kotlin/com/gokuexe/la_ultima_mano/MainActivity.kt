package com.gokuexe.la_ultima_mano

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.gokuexe.la_ultima_mano/storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDirectory" -> result.success(filesDir.absolutePath)
                else -> result.notImplemented()
            }
        }
    }
}

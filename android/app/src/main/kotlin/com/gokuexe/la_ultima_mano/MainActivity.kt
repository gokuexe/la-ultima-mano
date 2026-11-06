package com.gokuexe.la_ultima_mano

import android.content.Intent
import android.content.ClipData
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.gokuexe.la_ultima_mano/share").setMethodCallHandler { call, result ->
            if (call.method != "sharePng") {
                result.notImplemented()
            } else {
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename")
                if (bytes == null || bytes.size > 4 * 1024 * 1024 || filename == null ||
                    !filename.matches(Regex("[a-zA-Z0-9_.-]+"))) {
                    result.error("invalid_card", "Invalid result card", null)
                } else {
                    try {
                        val directory = File(cacheDir, "shared-results").apply { mkdirs() }
                        val file = File(directory, "daily-result.png").apply { writeBytes(bytes) }
                        val uri = FileProvider.getUriForFile(this, "$packageName.share", file)
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newRawUri("Daily result", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "La Última Mano"))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("share_failed", "Could not share card", null)
                    }
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.gokuexe.la_ultima_mano/storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDirectory" -> result.success(filesDir.absolutePath)
                else -> result.notImplemented()
            }
        }
    }
}

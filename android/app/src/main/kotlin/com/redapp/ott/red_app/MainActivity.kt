package com.redapp.ott.red_app

import android.app.PictureInPictureParams
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val PIP_CHANNEL = "com.red.app/pip"
    private val SAVE_CHANNEL = "com.red.app/save"
    private val DEEPLINK_CHANNEL = "com.red.app/deeplink"

    private var initialDeepLink: String? = null
    private var deepLinkChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.dataString?.let { link ->
            initialDeepLink = link
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { link ->
            deepLinkChannel?.invokeMethod("onLink", link)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
        deepLinkChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialLink") {
                val link = initialDeepLink
                initialDeepLink = null
                result.success(link)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enterPip") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val params = PictureInPictureParams.Builder()
                        .setAspectRatio(Rational(16, 9))
                        .build()
                    enterPictureInPictureMode(params)
                    result.success(true)
                } else {
                    result.error("UNSUPPORTED", "PiP requires Android 8.0+", null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAVE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val path = call.argument<String>("path") ?: ""
                    val name = call.argument<String>("name") ?: "video.mp4"
                    val mime = call.argument<String>("mime") ?: "video/mp4"
                    result.success(saveToMediaStore(path, name, mime, Environment.DIRECTORY_DOWNLOADS))
                }
                "saveToMovies" -> {
                    val path = call.argument<String>("path") ?: ""
                    val name = call.argument<String>("name") ?: "video.mp4"
                    val mime = call.argument<String>("mime") ?: "video/mp4"
                    result.success(saveToMediaStore(path, name, mime, Environment.DIRECTORY_MOVIES))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToMediaStore(sourcePath: String, displayName: String, mime: String, relativeDir: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+: MediaStore — no permission required
                val resolver = contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativeDir)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return false
                resolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(File(sourcePath)).use { input -> input.copyTo(out) }
                } ?: return false
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                true
            } else {
                // Older Android: direct copy to public dir (WRITE_EXTERNAL_STORAGE required)
                val dir = Environment.getExternalStoragePublicDirectory(relativeDir)
                if (!dir.exists()) dir.mkdirs()
                val dest = File(dir, displayName)
                FileInputStream(File(sourcePath)).use { input ->
                    dest.outputStream().use { out -> input.copyTo(out) }
                }
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // PiP is only entered from the video player's explicit PiP button.
        // No auto-PiP here so the app never pops into PiP outside the player.
    }
}

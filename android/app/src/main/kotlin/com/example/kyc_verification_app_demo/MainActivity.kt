package com.example.kyc_verification_app_demo

import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kyc_debug_share"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> {
                    val subject = call.argument<String>("subject").orEmpty()
                    val text = call.argument<String>("text").orEmpty()

                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, subject)
                        putExtra(Intent.EXTRA_TEXT, text)
                    }

                    startActivity(
                        Intent.createChooser(
                            intent,
                            if (subject.isBlank()) "Share report" else subject
                        )
                    )
                    result.success(null)
                }

                "shareFiles" -> {
                    val subject = call.argument<String>("subject").orEmpty()
                    val text = call.argument<String>("text")
                    val rawPaths = call.argument<List<String>>("paths").orEmpty()
                    val fileUris = rawPaths
                        .map(::File)
                        .filter { it.exists() }
                        .map {
                            FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                it
                            )
                        }

                    if (fileUris.isEmpty()) {
                        result.error("no_files", "No shareable files were found.", null)
                        return@setMethodCallHandler
                    }

                    val intent = if (fileUris.size == 1) {
                        Intent(Intent.ACTION_SEND).apply {
                            type = "*/*"
                            putExtra(Intent.EXTRA_STREAM, fileUris.first())
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                            if (!text.isNullOrBlank()) {
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            clipData = ClipData.newRawUri("shared_file", fileUris.first())
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    } else {
                        Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                            type = "*/*"
                            putParcelableArrayListExtra(
                                Intent.EXTRA_STREAM,
                                ArrayList(fileUris)
                            )
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                            if (!text.isNullOrBlank()) {
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            clipData = ClipData.newRawUri("shared_files", fileUris.first())
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    }

                    startActivity(
                        Intent.createChooser(
                            intent,
                            if (subject.isBlank()) "Share report files" else subject
                        )
                    )
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

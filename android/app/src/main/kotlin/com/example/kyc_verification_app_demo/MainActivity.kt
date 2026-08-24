package com.example.kyc_verification_app_demo

import android.app.ActivityManager
import android.content.ContentValues
import android.content.ClipData
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kyc_device_diagnostics"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "collectSnapshot" -> {
                    try {
                        val activityManager =
                            getSystemService(ACTIVITY_SERVICE) as ActivityManager
                        val memoryInfo = ActivityManager.MemoryInfo()
                        activityManager.getMemoryInfo(memoryInfo)

                        result.success(
                            mapOf(
                                "platform" to "android",
                                "manufacturer" to Build.MANUFACTURER,
                                "brand" to Build.BRAND,
                                "model" to Build.MODEL,
                                "device" to Build.DEVICE,
                                "product" to Build.PRODUCT,
                                "hardware" to Build.HARDWARE,
                                "android_release" to Build.VERSION.RELEASE,
                                "sdk_int" to Build.VERSION.SDK_INT,
                                "supported_abis" to Build.SUPPORTED_ABIS.toList(),
                                "total_ram_bytes" to memoryInfo.totalMem,
                                "available_ram_bytes" to memoryInfo.availMem,
                                "low_memory" to memoryInfo.lowMemory
                            )
                        )
                    } catch (error: Exception) {
                        result.error("device_snapshot_failed", error.message, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kyc_debug_export"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportFilesToDownloads" -> {
                    try {
                        val directoryName = call.argument<String>("directoryName").orEmpty()
                        val rawPaths = call.argument<List<String>>("paths").orEmpty()
                        val sourceFiles = rawPaths.map(::File).filter { it.exists() }

                        if (sourceFiles.isEmpty()) {
                            result.error(
                                "no_files",
                                "No exportable files were found.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val exportedPaths = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            exportFilesToDownloadsMediaStore(sourceFiles, directoryName)
                        } else {
                            exportFilesToDownloadsLegacy(sourceFiles, directoryName)
                        }

                        result.success(
                            mapOf(
                                "directoryPath" to "Downloads/$directoryName",
                                "exportedFilePaths" to exportedPaths
                            )
                        )
                    } catch (error: Exception) {
                        result.error(
                            "download_export_failed",
                            error.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun exportFilesToDownloadsMediaStore(
        sourceFiles: List<File>,
        directoryName: String
    ): List<String> {
        val resolver = applicationContext.contentResolver
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$directoryName"
        val exported = mutableListOf<String>()

        sourceFiles.forEach { source ->
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, source.name)
                put(MediaStore.Downloads.MIME_TYPE, mimeTypeFor(source))
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val uri = resolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                contentValues
            ) ?: throw IllegalStateException("Unable to create download entry for ${source.name}")

            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("Unable to open download output stream for ${source.name}")

            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)
            exported.add("Downloads/$directoryName/${source.name}")
        }

        return exported
    }

    private fun exportFilesToDownloadsLegacy(
        sourceFiles: List<File>,
        directoryName: String
    ): List<String> {
        val downloadsRoot =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val exportDirectory = File(downloadsRoot, directoryName)
        if (!exportDirectory.exists() && !exportDirectory.mkdirs()) {
            throw IllegalStateException("Unable to create export directory in Downloads.")
        }

        return sourceFiles.map { source ->
            val target = File(exportDirectory, source.name)
            source.copyTo(target, overwrite = true)
            target.absolutePath
        }
    }

    private fun mimeTypeFor(file: File): String {
        return when (file.extension.lowercase()) {
            "json" -> "application/json"
            "md" -> "text/markdown"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            else -> "application/octet-stream"
        }
    }
}

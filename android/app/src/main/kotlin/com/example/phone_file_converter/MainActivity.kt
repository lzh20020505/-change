package com.example.phone_file_converter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegSession
import com.arthenica.ffmpegkit.ReturnCode
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val imageExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var imageChannel: MethodChannel? = null
    private var fileActionChannel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null
    private var audioProgressChannel: EventChannel? = null
    private var audioProgressSink: EventChannel.EventSink? = null
    private var audioSession: FFmpegSession? = null
    private var audioOutputFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        imageChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                IMAGE_PROCESSING_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    if (
                        call.method != "convertImage" &&
                        call.method != "compressImages" &&
                        call.method != "createPdf"
                    ) {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }

                    val arguments = call.arguments as? Map<*, *>
                    if (arguments == null) {
                        result.error("INVALID_ARGUMENTS", "缺少图片处理参数", null)
                        return@setMethodCallHandler
                    }

                    imageExecutor.execute {
                        try {
                            val value =
                                when (call.method) {
                                    "convertImage" -> convertImage(arguments)
                                    "compressImages" -> compressImages(arguments)
                                    "createPdf" -> createPdf(arguments)
                                    else -> error("不支持的图片处理方法")
                                }
                            mainHandler.post { result.success(value) }
                        } catch (error: Throwable) {
                            mainHandler.post {
                                result.error(
                                    "IMAGE_PROCESSING_FAILED",
                                    error.message ?: "图片处理失败",
                                    null,
                                )
                            }
                        }
                    }
                }
            }

        fileActionChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                FILE_ACTION_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    try {
                        when (call.method) {
                            "openFile" ->
                                openFile(requireActionPath(call.argument<String>("path")))
                            "shareFile" ->
                                shareFile(requireActionPath(call.argument<String>("path")))
                            else -> {
                                result.notImplemented()
                                return@setMethodCallHandler
                            }
                        }
                        result.success(null)
                    } catch (_: ActivityNotFoundException) {
                        result.error("NO_APP", "没有可处理此文件的应用", null)
                    } catch (error: Throwable) {
                        result.error(
                            "FILE_ACTION_FAILED",
                            error.message ?: "文件操作失败",
                            null,
                        )
                    }
                }
            }

        audioProgressChannel =
            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                AUDIO_PROGRESS_CHANNEL,
            ).also { channel ->
                channel.setStreamHandler(
                    object : EventChannel.StreamHandler {
                        override fun onListen(
                            arguments: Any?,
                            events: EventChannel.EventSink?,
                        ) {
                            audioProgressSink = events
                        }

                        override fun onCancel(arguments: Any?) {
                            audioProgressSink = null
                        }
                    },
                )
            }

        audioChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                AUDIO_PROCESSING_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "extractAudio" -> {
                            val arguments = call.arguments as? Map<*, *>
                            if (arguments == null) {
                                result.error("INVALID_ARGUMENTS", "缺少音频处理参数", null)
                            } else {
                                startAudioExtraction(arguments, result)
                            }
                        }

                        "cancelAudioExtraction" -> {
                            cancelAudioExtraction()
                            result.success(null)
                        }

                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        imageChannel?.setMethodCallHandler(null)
        imageChannel = null
        fileActionChannel?.setMethodCallHandler(null)
        fileActionChannel = null
        audioChannel?.setMethodCallHandler(null)
        audioChannel = null
        audioProgressChannel?.setStreamHandler(null)
        audioProgressChannel = null
        audioProgressSink = null
        cancelAudioExtraction()
        imageExecutor.shutdown()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun startAudioExtraction(
        arguments: Map<*, *>,
        result: MethodChannel.Result,
    ) {
        if (audioSession != null) {
            result.error("TASK_RUNNING", "已有音频任务正在运行", null)
            return
        }

        val inputFile =
            try {
                requireInputFile(arguments["inputPath"])
            } catch (error: Throwable) {
                result.error("INVALID_INPUT", error.message, null)
                return
            }
        val outputDirectory =
            try {
                requireOutputDirectory(arguments["outputDirectory"])
            } catch (error: Throwable) {
                result.error("INVALID_OUTPUT", error.message, null)
                return
            }
        val format = (arguments["format"] as? String)?.lowercase() ?: "mp3"
        val bitrateKbps =
            ((arguments["bitrateKbps"] as? Number)?.toInt() ?: 192).coerceIn(64, 320)
        val sampleRate =
            ((arguments["sampleRate"] as? Number)?.toInt() ?: 44100)
                .coerceIn(8000, 48000)

        val durationMilliseconds =
            try {
                readMediaDuration(inputFile)
            } catch (error: Throwable) {
                result.error("INVALID_MEDIA", error.message, null)
                return
            }
        if (durationMilliseconds > MAX_AUDIO_DURATION_MILLISECONDS) {
            result.error("MEDIA_TOO_LONG", "暂不处理超过 12 小时的视频", null)
            return
        }

        val estimatedOutputBytes =
            estimateAudioOutputSize(
                durationMilliseconds = durationMilliseconds,
                format = format,
                bitrateKbps = bitrateKbps,
                sampleRate = sampleRate,
            )
        val requiredBytes = estimatedOutputBytes + OUTPUT_SPACE_RESERVE_BYTES
        if (StatFs(outputDirectory.path).availableBytes < requiredBytes) {
            result.error("NO_SPACE", "存储空间不足，无法安全生成音频文件", null)
            return
        }

        val outputFile =
            uniqueOutputFile(
                directory = outputDirectory,
                baseName = inputFile.nameWithoutExtension,
                suffix = "_audio",
                extension = format,
            )
        audioOutputFile = outputFile
        val command =
            buildAudioCommand(
                inputFile = inputFile,
                outputFile = outputFile,
                format = format,
                bitrateKbps = bitrateKbps,
                sampleRate = sampleRate,
            )

        try {
            audioSession =
                FFmpegKit.executeWithArgumentsAsync(
                    command,
                    { session ->
                        mainHandler.post {
                            val returnCode = session.returnCode
                            audioSession = null
                            audioOutputFile = null
                            when {
                                ReturnCode.isSuccess(returnCode) && outputFile.isFile -> {
                                    result.success(resultMap(inputFile, outputFile))
                                }

                                ReturnCode.isCancel(returnCode) -> {
                                    outputFile.delete()
                                    result.error("CANCELLED", "音频提取已取消", null)
                                }

                                else -> {
                                    outputFile.delete()
                                    val details =
                                        session.allLogsAsString
                                            ?.lineSequence()
                                            ?.lastOrNull { it.isNotBlank() }
                                    result.error(
                                        "AUDIO_PROCESSING_FAILED",
                                        details ?: "视频损坏、无音轨或格式不受支持",
                                        session.failStackTrace,
                                    )
                                }
                            }
                        }
                    },
                    null,
                    { statistics ->
                        val processedMilliseconds =
                            statistics.time.coerceAtLeast(0.0)
                        val progress =
                            (
                                processedMilliseconds /
                                    durationMilliseconds.toDouble()
                            ).coerceIn(0.0, 1.0)
                        mainHandler.post {
                            audioProgressSink?.success(
                                mapOf(
                                    "progress" to progress,
                                    "processedMilliseconds" to processedMilliseconds,
                                ),
                            )
                        }
                    },
                )
        } catch (error: Throwable) {
            audioSession = null
            audioOutputFile = null
            outputFile.delete()
            result.error(
                "AUDIO_PROCESSING_FAILED",
                error.message ?: "无法启动音频任务",
                null,
            )
        }
    }

    private fun cancelAudioExtraction() {
        val session = audioSession ?: return
        FFmpegKit.cancel(session.sessionId)
        audioOutputFile?.delete()
    }

    private fun readMediaDuration(inputFile: File): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(inputFile.absolutePath)
            val duration =
                retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull()
                    ?: 0L
            require(duration > 0) { "无法读取视频时长，文件可能已损坏" }
            duration
        } finally {
            retriever.release()
        }
    }

    private fun estimateAudioOutputSize(
        durationMilliseconds: Long,
        format: String,
        bitrateKbps: Int,
        sampleRate: Int,
    ): Long {
        val durationSeconds = durationMilliseconds / 1000.0
        return if (format == "wav") {
            (durationSeconds * sampleRate * 2 * 2).toLong()
        } else {
            (durationSeconds * bitrateKbps * 1000 / 8).toLong()
        }
    }

    private fun buildAudioCommand(
        inputFile: File,
        outputFile: File,
        format: String,
        bitrateKbps: Int,
        sampleRate: Int,
    ): Array<String> {
        val command =
            mutableListOf(
                "-hide_banner",
                "-nostdin",
                "-loglevel",
                "error",
                "-y",
                "-i",
                inputFile.absolutePath,
                "-map",
                "0:a:0",
                "-vn",
                "-threads",
                "1",
            )
        when (format) {
            "mp3" -> {
                command += listOf("-c:a", "libmp3lame", "-b:a", "${bitrateKbps}k")
            }

            "m4a" -> {
                command += listOf("-c:a", "aac", "-b:a", "${bitrateKbps}k")
            }

            "wav" -> {
                command +=
                    listOf(
                        "-c:a",
                        "pcm_s16le",
                        "-ar",
                        sampleRate.toString(),
                        "-ac",
                        "2",
                    )
            }

            else -> error("不支持的音频格式：$format")
        }
        command += outputFile.absolutePath
        return command.toTypedArray()
    }

    private fun openFile(path: String) {
        val file = requireResultFile(path)
        val intent =
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(fileUri(file), mimeType(file))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        startActivity(intent)
    }

    private fun requireActionPath(path: String?): String {
        require(!path.isNullOrBlank()) { "未指定结果文件" }
        return path
    }

    private fun shareFile(path: String) {
        val file = requireResultFile(path)
        val intent =
            Intent(Intent.ACTION_SEND).apply {
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_STREAM, fileUri(file))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        startActivity(Intent.createChooser(intent, "发送原文件"))
    }

    private fun requireResultFile(path: String): File {
        val file = File(path)
        require(file.isFile && file.canRead()) { "结果文件已不存在" }
        return file
    }

    private fun fileUri(file: File) =
        try {
            FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
        } catch (_: IllegalArgumentException) {
            error("无法授权访问结果文件，请更新应用后重试")
        }

    private fun mimeType(file: File): String {
        val extension = file.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    private fun convertImage(arguments: Map<*, *>): Map<String, Any> {
        val inputFile = requireInputFile(arguments["inputPath"])
        val outputDirectory = requireOutputDirectory(arguments["outputDirectory"])
        val outputFormat =
            requireNotNull(arguments["outputFormat"] as? String) {
                "未指定目标图片格式"
            }
        val format = imageFormat(outputFormat)
        val outputFile =
            uniqueOutputFile(
                directory = outputDirectory,
                baseName = inputFile.nameWithoutExtension,
                suffix = "_converted",
                extension = format.extension,
            )

        val bitmap = decodeBitmap(inputFile, null)
        try {
            writeBitmap(
                bitmap = bitmap,
                outputFile = outputFile,
                format = format.compressFormat,
                quality = if (format.compressFormat == Bitmap.CompressFormat.PNG) 100 else 92,
            )
        } finally {
            bitmap.recycle()
        }

        return resultMap(inputFile, outputFile)
    }

    private fun compressImages(arguments: Map<*, *>): List<Map<String, Any>> {
        val inputPaths =
            (arguments["inputPaths"] as? List<*>)
                ?.mapNotNull { it as? String }
                .orEmpty()
        require(inputPaths.isNotEmpty()) { "请至少选择一张图片" }

        val outputDirectory = requireOutputDirectory(arguments["outputDirectory"])
        val quality = ((arguments["quality"] as? Number)?.toInt() ?: 75).coerceIn(1, 100)
        val resizeMode = arguments["resizeMode"] as? String ?: "original"

        return inputPaths.map { inputPath ->
            val inputFile = requireInputFile(inputPath)
            val targetLongEdge = targetLongEdge(inputFile, resizeMode)
            val outputFile =
                uniqueOutputFile(
                    directory = outputDirectory,
                    baseName = inputFile.nameWithoutExtension,
                    suffix = "_compressed",
                    extension = "jpg",
                )

            val bitmap = decodeBitmap(inputFile, targetLongEdge)
            try {
                writeBitmap(
                    bitmap = bitmap,
                    outputFile = outputFile,
                    format = Bitmap.CompressFormat.JPEG,
                    quality = quality,
                )
            } finally {
                bitmap.recycle()
            }

            resultMap(inputFile, outputFile)
        }
    }

    private fun createPdf(arguments: Map<*, *>): Map<String, Any> {
        val inputFiles =
            (arguments["inputPaths"] as? List<*>)
                ?.mapNotNull { it as? String }
                ?.map(::requireInputFile)
                .orEmpty()
        require(inputFiles.isNotEmpty()) { "请至少选择一张图片" }

        val outputDirectory = requireOutputDirectory(arguments["outputDirectory"])
        val pageSize = arguments["pageSize"] as? String ?: "a4"
        val orientation = arguments["orientation"] as? String ?: "portrait"
        val fitPage = arguments["fitPage"] as? Boolean ?: true
        val outputFile =
            uniqueOutputFile(
                directory = outputDirectory,
                baseName = "image_export",
                suffix = "",
                extension = "pdf",
            )

        val document = PdfDocument()
        try {
            inputFiles.forEachIndexed { index, inputFile ->
                val fixedPageDimensions = fixedPdfPageDimensions(pageSize, orientation)
                val decodeLongEdge =
                    fixedPageDimensions?.let { max(it.first, it.second) * 2 } ?: 1600
                val bitmap = decodeBitmap(inputFile, decodeLongEdge)
                try {
                    val pageDimensions =
                        fixedPageDimensions ?: originalPdfPageDimensions(bitmap)
                    val pageInfo =
                        PdfDocument.PageInfo
                            .Builder(
                                pageDimensions.first,
                                pageDimensions.second,
                                index + 1,
                            ).create()
                    val page = document.startPage(pageInfo)
                    try {
                        drawBitmapOnPdfPage(
                            canvas = page.canvas,
                            bitmap = bitmap,
                            pageWidth = pageDimensions.first,
                            pageHeight = pageDimensions.second,
                            fitPage = fitPage,
                        )
                    } finally {
                        document.finishPage(page)
                    }
                } finally {
                    bitmap.recycle()
                }
            }

            FileOutputStream(outputFile).use { stream ->
                document.writeTo(stream)
                stream.flush()
            }
        } catch (error: Throwable) {
            outputFile.delete()
            throw error
        } finally {
            document.close()
        }

        return mapOf(
            "inputPath" to inputFiles.first().absolutePath,
            "outputPath" to outputFile.absolutePath,
            "inputSize" to inputFiles.sumOf { it.length() },
            "outputSize" to outputFile.length(),
        )
    }

    private fun fixedPdfPageDimensions(
        pageSize: String,
        orientation: String,
    ): Pair<Int, Int>? {
        val portraitDimensions =
            when (pageSize) {
                "a4" -> 595 to 842
                "letter" -> 612 to 792
                else -> return null
            }
        return if (orientation == "landscape") {
            portraitDimensions.second to portraitDimensions.first
        } else {
            portraitDimensions
        }
    }

    private fun originalPdfPageDimensions(bitmap: Bitmap): Pair<Int, Int> {
        val longEdge = max(bitmap.width, bitmap.height)
        val scale = 1080.0 / longEdge
        return max(1, (bitmap.width * scale).roundToInt()) to
            max(1, (bitmap.height * scale).roundToInt())
    }

    private fun drawBitmapOnPdfPage(
        canvas: Canvas,
        bitmap: Bitmap,
        pageWidth: Int,
        pageHeight: Int,
        fitPage: Boolean,
    ) {
        canvas.drawColor(Color.WHITE)

        val margin = if (fitPage) minOf(pageWidth, pageHeight) * 0.04f else 0f
        val content =
            RectF(
                margin,
                margin,
                pageWidth - margin,
                pageHeight - margin,
            )
        val widthScale = content.width() / bitmap.width
        val heightScale = content.height() / bitmap.height
        val scale =
            if (fitPage) {
                minOf(widthScale, heightScale)
            } else {
                maxOf(widthScale, heightScale)
            }
        val drawWidth = bitmap.width * scale
        val drawHeight = bitmap.height * scale
        val left = content.centerX() - drawWidth / 2
        val top = content.centerY() - drawHeight / 2
        val destination = RectF(left, top, left + drawWidth, top + drawHeight)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

        canvas.save()
        canvas.clipRect(content)
        canvas.drawBitmap(bitmap, null, destination, paint)
        canvas.restore()
    }

    private fun requireInputFile(value: Any?): File {
        val path = value as? String
        require(!path.isNullOrBlank()) { "无法读取所选文件路径" }

        val file = File(path)
        require(file.isFile && file.canRead()) { "无法读取文件：${file.name}" }
        return file
    }

    private fun requireOutputDirectory(value: Any?): File {
        val path = value as? String
        require(!path.isNullOrBlank()) { "未指定输出目录" }

        val directory = File(path)
        require(directory.exists() || directory.mkdirs()) { "无法创建输出目录" }
        require(directory.isDirectory && directory.canWrite()) { "输出目录不可写" }
        return directory
    }

    private fun targetLongEdge(
        inputFile: File,
        resizeMode: String,
    ): Int? {
        if (resizeMode == "original") {
            return null
        }

        val dimensions = readImageDimensions(inputFile)
        val longEdge = max(dimensions.first, dimensions.second)
        return when (resizeMode) {
            "half" -> max(1, longEdge / 2)
            "longEdge1080" -> minOf(longEdge, 1080)
            else -> null
        }
    }

    private fun readImageDimensions(inputFile: File): Pair<Int, Int> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(inputFile.absolutePath, options)
        require(options.outWidth > 0 && options.outHeight > 0) {
            "不支持的图片文件：${inputFile.name}"
        }
        return options.outWidth to options.outHeight
    }

    private fun decodeBitmap(
        inputFile: File,
        targetLongEdge: Int?,
    ): Bitmap {
        val dimensions = readImageDimensions(inputFile)
        if (targetLongEdge == null) {
            val pixelCount = dimensions.first.toLong() * dimensions.second
            require(pixelCount <= MAX_IMAGE_PIXELS) {
                "图片像素过大，原尺寸处理可能耗尽内存，请先缩小到 2400 万像素以内"
            }
        }
        val sourceLongEdge = max(dimensions.first, dimensions.second)
        var sampleSize = 1
        if (targetLongEdge != null) {
            while (sourceLongEdge / (sampleSize * 2) >= targetLongEdge) {
                sampleSize *= 2
            }
        }

        val options =
            BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
        var bitmap =
            requireNotNull(BitmapFactory.decodeFile(inputFile.absolutePath, options)) {
                "无法解码图片：${inputFile.name}"
            }

        val rotation = readExifRotation(inputFile)
        if (rotation != 0f) {
            val matrix = Matrix().apply { postRotate(rotation) }
            val rotated =
                Bitmap.createBitmap(
                    bitmap,
                    0,
                    0,
                    bitmap.width,
                    bitmap.height,
                    matrix,
                    true,
                )
            if (rotated !== bitmap) {
                bitmap.recycle()
                bitmap = rotated
            }
        }

        if (targetLongEdge != null) {
            val currentLongEdge = max(bitmap.width, bitmap.height)
            if (currentLongEdge > targetLongEdge) {
                val scale = targetLongEdge.toDouble() / currentLongEdge
                val targetWidth = max(1, (bitmap.width * scale).roundToInt())
                val targetHeight = max(1, (bitmap.height * scale).roundToInt())
                val resized =
                    Bitmap.createScaledBitmap(
                        bitmap,
                        targetWidth,
                        targetHeight,
                        true,
                    )
                if (resized !== bitmap) {
                    bitmap.recycle()
                    bitmap = resized
                }
            }
        }

        return bitmap
    }

    private fun readExifRotation(inputFile: File): Float {
        return try {
            when (
                ExifInterface(inputFile.absolutePath).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (_: Exception) {
            0f
        }
    }

    private fun writeBitmap(
        bitmap: Bitmap,
        outputFile: File,
        format: Bitmap.CompressFormat,
        quality: Int,
    ) {
        val bitmapToWrite =
            if (format == Bitmap.CompressFormat.JPEG && bitmap.hasAlpha()) {
                Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888).also {
                    val canvas = Canvas(it)
                    canvas.drawColor(Color.WHITE)
                    canvas.drawBitmap(bitmap, 0f, 0f, null)
                }
            } else {
                bitmap
            }

        try {
            FileOutputStream(outputFile).use { stream ->
                check(bitmapToWrite.compress(format, quality, stream)) {
                    "无法写入图片：${outputFile.name}"
                }
                stream.flush()
            }
        } catch (error: Throwable) {
            outputFile.delete()
            throw error
        } finally {
            if (bitmapToWrite !== bitmap) {
                bitmapToWrite.recycle()
            }
        }
    }

    private fun imageFormat(value: String): ImageFormat {
        return when (value.uppercase()) {
            "JPG", "JPEG" -> ImageFormat(Bitmap.CompressFormat.JPEG, "jpg")
            "PNG" -> ImageFormat(Bitmap.CompressFormat.PNG, "png")
            "WEBP" -> ImageFormat(webpCompressFormat(), "webp")
            else -> error("不支持的目标格式：$value")
        }
    }

    @Suppress("DEPRECATION")
    private fun webpCompressFormat(): Bitmap.CompressFormat {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            Bitmap.CompressFormat.WEBP
        }
    }

    private fun uniqueOutputFile(
        directory: File,
        baseName: String,
        suffix: String,
        extension: String,
    ): File {
        val safeBaseName =
            baseName
                .replace(Regex("""[\\/:*?"<>|]"""), "_")
                .ifBlank { "image" }
        var index = 1
        var outputFile = File(directory, "$safeBaseName$suffix.$extension")
        while (outputFile.exists()) {
            index += 1
            outputFile = File(directory, "${safeBaseName}${suffix}_$index.$extension")
        }
        return outputFile
    }

    private fun resultMap(
        inputFile: File,
        outputFile: File,
    ): Map<String, Any> {
        return mapOf(
            "inputPath" to inputFile.absolutePath,
            "outputPath" to outputFile.absolutePath,
            "inputSize" to inputFile.length(),
            "outputSize" to outputFile.length(),
        )
    }

    private data class ImageFormat(
        val compressFormat: Bitmap.CompressFormat,
        val extension: String,
    )

    companion object {
        private const val IMAGE_PROCESSING_CHANNEL =
            "phone_file_converter/image_processing"
        private const val FILE_ACTION_CHANNEL =
            "phone_file_converter/file_actions"
        private const val AUDIO_PROCESSING_CHANNEL =
            "phone_file_converter/audio_processing"
        private const val AUDIO_PROGRESS_CHANNEL =
            "phone_file_converter/audio_processing_progress"
        private const val MAX_AUDIO_DURATION_MILLISECONDS = 12L * 60 * 60 * 1000
        private const val OUTPUT_SPACE_RESERVE_BYTES = 16L * 1024 * 1024
        private const val MAX_IMAGE_PIXELS = 24_000_000L
    }
}

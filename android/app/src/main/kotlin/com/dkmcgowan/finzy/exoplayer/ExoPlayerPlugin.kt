package com.dkmcgowan.finzy.exoplayer

import android.app.Activity
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.dkmcgowan.finzy.mpv.MpvPlayerCore
import com.dkmcgowan.finzy.mpv.MpvPlayerDelegate
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ExoPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware, ExoPlayerDelegate, MpvPlayerDelegate {

    companion object {
        private const val TAG = "ExoPlayerPlugin"
        private const val METHOD_CHANNEL = "com.finzy/exo_player"
        private const val EVENT_CHANNEL = "com.finzy/exo_player/events"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var sessionGeneration = 0
    private var fallbackInProgress = false
    private var configuredBufferSizeBytes: Int? = null
    private val pendingMpvProperties = mutableListOf<Pair<String, String>>()
    private var playerCore: ExoPlayerCore? = null
    private var mpvCore: MpvPlayerCore? = null  // MPV fallback player
    private var usingMpvFallback: Boolean = false
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val nameToId = mutableMapOf<String, Int>()

    // FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)

        Log.d(TAG, "Attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        Log.d(TAG, "Detached from engine")
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        Log.d(TAG, "Attached to activity")
    }

    override fun onDetachedFromActivity() {
        sessionGeneration++
        playerCore?.dispose()
        playerCore = null
        mpvCore?.dispose()
        mpvCore = null
        usingMpvFallback = false
        activity = null
        activityBinding = null
        Log.d(TAG, "Detached from activity")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        Log.d(TAG, "Reattached to activity for config changes")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        sessionGeneration++
        fallbackInProgress = false
        activity = null
        activityBinding = null
        Log.d(TAG, "Detached from activity for config changes")
    }

    // EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "Event stream connected")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "Event stream disconnected")
    }

    // MethodChannel.MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getHeapSize" -> {
                val heapBytes = Runtime.getRuntime().maxMemory()
                result.success((heapBytes / 1024 / 1024).toInt())
            }
            "initialize" -> handleInitialize(call, result)
            "dispose" -> handleDispose(result)
            "open" -> handleOpen(call, result)
            "play" -> handlePlay(result)
            "pause" -> handlePause(result)
            "stop" -> handleStop(result)
            "seek" -> handleSeek(call, result)
            "setVolume" -> handleSetVolume(call, result)
            "setRate" -> handleSetRate(call, result)
            "selectAudioTrack" -> handleSelectAudioTrack(call, result)
            "selectSubtitleTrack" -> handleSelectSubtitleTrack(call, result)
            "addSubtitleTrack" -> handleAddSubtitleTrack(call, result)
            "setVisible" -> handleSetVisible(call, result)
            "setVideoFrameRate" -> handleSetVideoFrameRate(call, result)
            "clearVideoFrameRate" -> handleClearVideoFrameRate(result)
            "requestAudioFocus" -> handleRequestAudioFocus(result)
            "abandonAudioFocus" -> handleAbandonAudioFocus(result)
            "isInitialized" -> result.success(
                if (usingMpvFallback) mpvCore?.isInitialized ?: false
                else playerCore?.isInitialized ?: false
            )
            "getStats" -> handleGetStats(result)
            "getPlayerType" -> result.success(if (usingMpvFallback) "mpv" else "exoplayer")
            "setSubtitleStyle" -> handleSetSubtitleStyle(call, result)
            "observeProperty" -> handleObserveProperty(call, result)
            "setMpvProperty" -> handleSetMpvProperty(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        if (playerCore?.isInitialized == true) {
            Log.d(TAG, "Already initialized")
            result.success(true)
            return
        }

        val bufferSizeBytes = call.argument<Int>("bufferSizeBytes")
        configuredBufferSizeBytes = bufferSizeBytes

        sessionGeneration++
        if (mpvCore != null || fallbackInProgress) {
            mpvCore?.dispose()
            mpvCore = null
            usingMpvFallback = false
            fallbackInProgress = false
        }
        currentActivity.runOnUiThread {
            try {
                playerCore = ExoPlayerCore(currentActivity).apply {
                    delegate = this@ExoPlayerPlugin
                }
                val success = playerCore?.initialize(bufferSizeBytes = bufferSizeBytes) ?: false

                // Start hidden
                playerCore?.setVisible(false)

                Log.d(TAG, "Initialized: $success")
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize: ${e.message}", e)
                result.error("INIT_FAILED", e.message, null)
            }
        }
    }

    private fun handleDispose(result: MethodChannel.Result) {
        sessionGeneration++
        activity?.runOnUiThread {
            if (usingMpvFallback) {
                mpvCore?.dispose {
                    mpvCore = null
                    usingMpvFallback = false
                    Log.d(TAG, "Disposed")
                    result.success(null)
                } ?: run {
                    mpvCore = null
                    usingMpvFallback = false
                    result.success(null)
                }
            } else {
                playerCore?.dispose()
                playerCore = null
                usingMpvFallback = false
                Log.d(TAG, "Disposed")
                result.success(null)
            }
        } ?: result.success(null)
    }

    private fun handleOpen(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")
        val headers = call.argument<Map<String, String>>("headers")
        val startPositionMs = call.argument<Number>("startPositionMs")?.toLong() ?: 0L
        val autoPlay = call.argument<Boolean>("autoPlay") ?: true
        val isLive = call.argument<Boolean>("isLive") ?: false

        if (uri == null) {
            result.error("INVALID_ARGS", "Missing 'uri'", null)
            return
        }

        // New media = fresh slate for pending MPV properties
        pendingMpvProperties.clear()

        activity?.runOnUiThread {
            if (usingMpvFallback) {
                // MPV: Build loadfile command with options
                val startSeconds = startPositionMs / 1000.0
                val options = mutableListOf<String>()
                options.add("start=$startSeconds")
                if (!autoPlay) options.add("pause=yes")
                headers?.forEach { (key, value) ->
                    options.add("http-header-fields-append=$key: $value")
                }
                val optionsStr = options.joinToString(",")
                // Convert content:// URIs to fdclose:// for MPV (SAF SD card downloads)
                val mpvUri = openContentFd(uri)?.let { "fdclose://$it" } ?: uri
                mpvCore?.command(arrayOf("loadfile", mpvUri, "replace", "-1", optionsStr))
            } else {
                playerCore?.open(uri, headers, startPositionMs, autoPlay, isLive)
            }
            result.success(null)
        } ?: result.error("NO_ACTIVITY", "Activity not available", null)
    }

    private fun handlePlay(result: MethodChannel.Result) {
        activity?.runOnUiThread {
            if (usingMpvFallback) {
                mpvCore?.setProperty("pause", "no")
            } else {
                playerCore?.play()
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handlePause(result: MethodChannel.Result) {
        activity?.runOnUiThread {
            if (usingMpvFallback) {
                mpvCore?.setProperty("pause", "yes")
            } else {
                playerCore?.pause()
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleStop(result: MethodChannel.Result) {
        activity?.runOnUiThread {
            if (usingMpvFallback) {
                mpvCore?.command(arrayOf("stop"))
                mpvCore?.setVisible(false)
            } else {
                playerCore?.stop()
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleSeek(call: MethodCall, result: MethodChannel.Result) {
        val positionMs = call.argument<Number>("positionMs")?.toLong()

        if (positionMs == null) {
            result.error("INVALID_ARGS", "Missing 'positionMs'", null)
            return
        }

        activity?.runOnUiThread {
            if (usingMpvFallback) {
                val positionSeconds = positionMs / 1000.0
                mpvCore?.command(arrayOf("seek", positionSeconds.toString(), "absolute"))
            } else {
                playerCore?.seekTo(positionMs)
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        val volume = call.argument<Number>("volume")?.toFloat()

        if (volume == null) {
            result.error("INVALID_ARGS", "Missing 'volume'", null)
            return
        }

        activity?.runOnUiThread {
            if (usingMpvFallback) {
                mpvCore?.setProperty("volume", volume.toString())
            } else {
                playerCore?.setVolume(volume / 100f) // Convert 0-100 to 0-1
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleSetRate(call: MethodCall, result: MethodChannel.Result) {
        val rate = call.argument<Number>("rate")?.toFloat()

        if (rate == null) {
            result.error("INVALID_ARGS", "Missing 'rate'", null)
            return
        }

        activity?.runOnUiThread {
            if (usingMpvFallback) {
                mpvCore?.setProperty("speed", rate.toString())
            } else {
                playerCore?.setPlaybackSpeed(rate)
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleSelectAudioTrack(call: MethodCall, result: MethodChannel.Result) {
        val trackId = call.argument<String>("trackId")

        if (trackId == null) {
            result.error("INVALID_ARGS", "Missing 'trackId'", null)
            return
        }

        activity?.runOnUiThread {
            if (usingMpvFallback) {
                // MPV uses numeric track IDs - extract from string format
                val numericId = trackId.split("_").lastOrNull()?.toIntOrNull() ?: 1
                mpvCore?.setProperty("aid", numericId.toString())
            } else {
                playerCore?.selectAudioTrack(trackId)
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleSelectSubtitleTrack(call: MethodCall, result: MethodChannel.Result) {
        val trackId = call.argument<String>("trackId")

        // trackId can be null or "no" to disable subtitles
        activity?.runOnUiThread {
            if (usingMpvFallback) {
                if (trackId == null || trackId == "no") {
                    mpvCore?.setProperty("sid", "no")
                } else {
                    val numericId = trackId.split("_").lastOrNull()?.toIntOrNull() ?: 1
                    mpvCore?.setProperty("sid", numericId.toString())
                }
            } else {
                playerCore?.selectSubtitleTrack(trackId)
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleAddSubtitleTrack(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")
        val title = call.argument<String>("title")
        val language = call.argument<String>("language")
        val mimeType = call.argument<String>("mimeType")
        val select = call.argument<Boolean>("select") ?: false

        if (uri == null) {
            result.error("INVALID_ARGS", "Missing 'uri'", null)
            return
        }

        activity?.runOnUiThread {
            if (usingMpvFallback) {
                val selectFlag = if (select) "select" else "auto"
                mpvCore?.command(arrayOf("sub-add", uri, selectFlag, title ?: "External"))
            } else {
                playerCore?.addSubtitleTrack(uri, title, language, mimeType, select)
            }
            result.success(null)
        } ?: result.success(null)
    }

    private fun handleSetVisible(call: MethodCall, result: MethodChannel.Result) {
        val visible = call.argument<Boolean>("visible")

        if (visible == null) {
            result.error("INVALID_ARGS", "Missing 'visible'", null)
            return
        }

        if (usingMpvFallback) {
            mpvCore?.setVisible(visible)
        } else {
            playerCore?.setVisible(visible)
        }
        result.success(null)
    }

    private fun handleSetVideoFrameRate(call: MethodCall, result: MethodChannel.Result) {
        val fps = call.argument<Double>("fps")?.toFloat() ?: 0f
        val duration = call.argument<Number>("duration")?.toLong() ?: 0L

        Log.d(TAG, "setVideoFrameRate: fps=$fps, duration=$duration")
        if (usingMpvFallback) {
            mpvCore?.setVideoFrameRate(fps, duration)
        } else {
            playerCore?.setVideoFrameRate(fps, duration)
        }
        result.success(null)
    }

    private fun handleClearVideoFrameRate(result: MethodChannel.Result) {
        Log.d(TAG, "clearVideoFrameRate")
        if (usingMpvFallback) {
            mpvCore?.clearVideoFrameRate()
        } else {
            playerCore?.clearVideoFrameRate()
        }
        result.success(null)
    }

    private fun handleRequestAudioFocus(result: MethodChannel.Result) {
        Log.d(TAG, "requestAudioFocus")
        val granted = if (usingMpvFallback) {
            mpvCore?.requestAudioFocus() ?: false
        } else {
            playerCore?.requestAudioFocus() ?: false
        }
        result.success(granted)
    }

    private fun handleAbandonAudioFocus(result: MethodChannel.Result) {
        Log.d(TAG, "abandonAudioFocus")
        if (usingMpvFallback) {
            mpvCore?.abandonAudioFocus()
        } else {
            playerCore?.abandonAudioFocus()
        }
        result.success(null)
    }

    private fun handleObserveProperty(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val id = call.argument<Int>("id")

        if (name == null || id == null) {
            result.error("INVALID_ARGS", "Missing 'name' or 'id'", null)
            return
        }

        nameToId[name] = id
        result.success(null)
    }

    private fun handleSetMpvProperty(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val value = call.argument<String>("value")

        if (name == null || value == null) {
            result.error("INVALID_ARGS", "Missing 'name' or 'value'", null)
            return
        }

        if (usingMpvFallback) {
            mpvCore?.setProperty(name, value)
        } else {
            // Store for later application if ExoPlayer falls back to MPV
            pendingMpvProperties.add(Pair(name, value))
        }
        result.success(null)
    }

    private fun handleSetSubtitleStyle(call: MethodCall, result: MethodChannel.Result) {
        val fontSize = call.argument<Number>("fontSize")?.toFloat() ?: 55f
        val textColor = call.argument<String>("textColor") ?: "#FFFFFF"
        val borderSize = call.argument<Number>("borderSize")?.toFloat() ?: 3f
        val borderColor = call.argument<String>("borderColor") ?: "#000000"
        val bgColor = call.argument<String>("bgColor") ?: "#000000"
        val bgOpacity = call.argument<Number>("bgOpacity")?.toInt() ?: 0
        val subtitlePosition = call.argument<Number>("subtitlePosition")?.toInt() ?: 100

        if (usingMpvFallback) {
            // MPV fallback handles styling via setProperty, no-op here
            result.success(null)
            return
        }

        playerCore?.setSubtitleStyle(fontSize, textColor, borderSize, borderColor, bgColor, bgOpacity, subtitlePosition)
        result.success(null)
    }

    private fun handleGetStats(result: MethodChannel.Result) {
        activity?.runOnUiThread {
            val stats = if (usingMpvFallback) {
                // For MPV fallback, query MPV properties directly
                getMpvStats()
            } else {
                val coreStats = playerCore?.getStats() ?: emptyMap()
                coreStats + mapOf("playerType" to "exoplayer")
            }
            result.success(stats)
        } ?: result.success(mapOf("playerType" to "unknown"))
    }

    /**
     * Get playback stats from MPV when in fallback mode.
     * Queries relevant MPV properties and returns them in a map format
     * compatible with the performance overlay.
     */
    private fun getMpvStats(): Map<String, Any?> {
        val mpv = mpvCore ?: return mapOf("playerType" to "mpv")

        return mapOf(
            "playerType" to "mpv",
            // Video metrics
            "video-codec" to mpv.getProperty("video-codec"),
            "video-params/w" to mpv.getProperty("video-params/w"),
            "video-params/h" to mpv.getProperty("video-params/h"),
            "container-fps" to mpv.getProperty("container-fps"),
            "estimated-vf-fps" to mpv.getProperty("estimated-vf-fps"),
            "video-bitrate" to mpv.getProperty("video-bitrate"),
            "hwdec-current" to mpv.getProperty("hwdec-current"),
            // Audio metrics
            "audio-codec-name" to mpv.getProperty("audio-codec-name"),
            "audio-params/samplerate" to mpv.getProperty("audio-params/samplerate"),
            "audio-params/hr-channels" to mpv.getProperty("audio-params/hr-channels"),
            "audio-bitrate" to mpv.getProperty("audio-bitrate"),
            // Performance metrics
            "total-avsync-change" to mpv.getProperty("total-avsync-change"),
            "cache-used" to mpv.getProperty("cache-used"),
            "cache-speed" to mpv.getProperty("cache-speed"),
            "display-fps" to mpv.getProperty("display-fps"),
            "frame-drop-count" to mpv.getProperty("frame-drop-count"),
            "decoder-frame-drop-count" to mpv.getProperty("decoder-frame-drop-count"),
            "demuxer-cache-duration" to mpv.getProperty("demuxer-cache-duration"),
            // Color/Format properties
            "video-params/pixelformat" to mpv.getProperty("video-params/pixelformat"),
            "video-params/hw-pixelformat" to mpv.getProperty("video-params/hw-pixelformat"),
            "video-params/colormatrix" to mpv.getProperty("video-params/colormatrix"),
            "video-params/primaries" to mpv.getProperty("video-params/primaries"),
            "video-params/gamma" to mpv.getProperty("video-params/gamma"),
            // HDR metadata
            "video-params/max-luma" to mpv.getProperty("video-params/max-luma"),
            "video-params/min-luma" to mpv.getProperty("video-params/min-luma"),
            "video-params/max-cll" to mpv.getProperty("video-params/max-cll"),
            "video-params/max-fall" to mpv.getProperty("video-params/max-fall"),
            // Other
            "video-params/aspect-name" to mpv.getProperty("video-params/aspect-name"),
            "video-params/rotate" to mpv.getProperty("video-params/rotate")
        )
    }

    // PiP Mode handling

    fun onPipModeChanged(isInPipMode: Boolean) {
        activity?.runOnUiThread {
            if (usingMpvFallback) {
                mpvCore?.onPipModeChanged(isInPipMode)
            } else {
                playerCore?.onPipModeChanged(isInPipMode)
            }
        }
    }

    // ExoPlayerDelegate

    override fun onPropertyChange(name: String, value: Any?) {
        val propId = nameToId[name] ?: return
        eventSink?.success(listOf(propId, value))
    }

    override fun onEvent(name: String, data: Map<String, Any>?) {
        val event = mutableMapOf<String, Any>(
            "type" to "event",
            "name" to name
        )
        data?.let { event["data"] = it }
        eventSink?.success(event)
    }

    override fun onFormatUnsupported(
        uri: String,
        headers: Map<String, String>?,
        positionMs: Long,
        errorMessage: String
    ): Boolean {
        val currentActivity = activity ?: return false
        fallbackInProgress = true

        Log.i(TAG, "ExoPlayer error, switching to MPV fallback at ${positionMs}ms: $errorMessage")

        // Dispose ExoPlayer immediately
        playerCore?.dispose()
        playerCore = null

        val generation = sessionGeneration

        Handler(Looper.getMainLooper()).post {
            if (generation != sessionGeneration) {
                fallbackInProgress = false
                return@post
            }
            val act = activity
            if (act == null) {
                fallbackInProgress = false
                return@post
            }

            try {
                val core = MpvPlayerCore(act).apply {
                    delegate = this@ExoPlayerPlugin
                }
                mpvCore = core

                val success = core.initialize()

                if (generation != sessionGeneration) {
                    if (mpvCore === core) {
                        core.dispose()
                        mpvCore = null
                    }
                    fallbackInProgress = false
                    return@post
                }
                if (!success) {
                    if (mpvCore === core) {
                        core.dispose()
                        mpvCore = null
                    }
                    fallbackInProgress = false
                    Log.e(TAG, "Failed to initialize MPV fallback")
                    onEvent("end-file", mapOf("reason" to "error", "message" to "Fallback failed: $errorMessage"))
                    return@post
                }

                usingMpvFallback = true
                fallbackInProgress = false

                // Configure basic MPV properties for media playback
                core.setProperty("hwdec", "auto")
                core.setProperty("vo", "gpu")
                core.setProperty("ao", "audiotrack,opensles")

                // Forward buffer config to MPV fallback
                val bufferSize = configuredBufferSizeBytes
                if (bufferSize != null && bufferSize > 0) {
                    core.setProperty("demuxer-max-bytes", bufferSize.toString())
                    core.setProperty("demuxer-max-back-bytes", (bufferSize / 4).toString())
                } else {
                    // Cap based on heap when no explicit buffer (matches video_player_screen logic)
                    val heapMB = (Runtime.getRuntime().maxMemory() / 1024 / 1024).toInt()
                    if (heapMB > 0) {
                        val autoBackMB = if (heapMB <= 256) 16 else if (heapMB <= 512) 32 else 48
                        val autoForwardMB = if (heapMB <= 256) 32 else if (heapMB <= 512) 64 else 100
                        core.setProperty("demuxer-max-bytes", "${autoForwardMB * 1024 * 1024}")
                        core.setProperty("demuxer-max-back-bytes", "${autoBackMB * 1024 * 1024}")
                    }
                }

                // Apply any pending MPV properties from Dart (e.g. stream-lavf-o for VOD reconnect)
                for ((propName, propValue) in pendingMpvProperties) {
                    core.setProperty(propName, propValue)
                }
                pendingMpvProperties.clear()

                // Setup property observers
                core.observeProperty("time-pos", "double")
                core.observeProperty("duration", "double")
                core.observeProperty("pause", "flag")
                core.observeProperty("paused-for-cache", "flag")
                core.observeProperty("demuxer-cache-time", "double")
                core.observeProperty("eof-reached", "flag")
                core.observeProperty("track-list", "string")
                core.observeProperty("aid", "string")
                core.observeProperty("sid", "string")
                core.observeProperty("volume", "double")
                core.observeProperty("speed", "double")

                // Show the MPV surface
                core.setVisible(true)

                // Load media at the same position
                val startSeconds = positionMs / 1000.0
                val options = mutableListOf<String>()
                options.add("start=$startSeconds")
                headers?.forEach { (key, value) ->
                    options.add("http-header-fields-append=$key: $value")
                }
                val optionsStr = options.joinToString(",")
                val mpvUri = openContentFd(uri, act.contentResolver)?.let { "fdclose://$it" } ?: uri
                core.command(arrayOf("loadfile", mpvUri, "replace", "-1", optionsStr))

                // On GPUs without compute shaders, MPV can't do dynamic peak detection
                // and spline tone-mapping produces dim/washed-out results with extreme
                // static HDR peak metadata. Use reinhard which handles this better.
                val peakDetection = core.getProperty("hdr-compute-peak")
                if (peakDetection == "no") {
                    Log.i(TAG, "No compute shaders — overriding tone-mapping to reinhard")
                    core.setProperty("tone-mapping", "reinhard")
                    core.setProperty("tone-mapping-param", "0.7")
                    core.setProperty("tone-mapping-mode", "luma")
                }

                // Request audio focus
                core.requestAudioFocus()

                onEvent("backend-switched", null)
                Log.i(TAG, "Successfully switched to MPV fallback")
            } catch (e: Exception) {
                fallbackInProgress = false
                Log.e(TAG, "Failed to switch to MPV fallback", e)
                onEvent("end-file", mapOf("reason" to "error", "message" to "Fallback failed: ${e.message}"))
            }
        }

        return true // Fallback is being handled
    }

    private fun openContentFd(uriString: String, resolver: android.content.ContentResolver? = activity?.contentResolver): Int? {
        if (!uriString.startsWith("content://")) return null
        return try {
            val uri = Uri.parse(uriString)
            val pfd = resolver?.openFileDescriptor(uri, "r") ?: return null
            val fd = pfd.detachFd()
            Log.d(TAG, "Opened content FD $fd for $uriString")
            fd
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open content FD: ${e.message}", e)
            null
        }
    }
}

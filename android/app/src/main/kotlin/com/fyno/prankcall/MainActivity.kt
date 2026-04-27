package com.fynotech.prankcall

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.fynotech.prankcall.ads.NativeLayoutAdFactory

class MainActivity : FlutterActivity() {
  private val channelName = "prank_call/native_alarm"
  private val torchChannelName = "prank_call/torch"
  private var pendingLaunchFolderPath: String? = null
  private var activeTorchCameraId: String? = null
  private var cachedTorchCameraId: String? = null
  private var torchSupportedChecked = false
  private var torchSupported = true
  private val torchExecutor: ExecutorService = Executors.newSingleThreadExecutor()

  companion object {
    private const val TAG = "MainActivity"
  }

  /**
   * (Re-)registers native factories on this engine. Unregisters first so a second
   * [configureFlutterEngine] call (rare) cannot leave us with a missing factory.
   */
  private fun registerNativeAdFactories(flutterEngine: FlutterEngine) {
    val factories =
      listOf(
        "native_small_inline" to R.layout.native_small_inline,
        "native_small_button_bottom" to R.layout.native_small_button_bottom,
        "native_advance_button_bottom" to R.layout.native_advance_button_bottom,
        "native_full_screen" to R.layout.full_screen_native,
      )
    for ((id, layout) in factories) {
      GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, id)
      val ok =
        GoogleMobileAdsPlugin.registerNativeAdFactory(
          flutterEngine,
          id,
          NativeLayoutAdFactory(this, layout),
        )
      if (!ok) {
        Log.e(TAG, "registerNativeAdFactory failed for $id")
      }
    }
  }

  override fun onResume() {
    super.onResume()
    // Re-bind factories in case the engine was recreated or registration raced the first frame.
    flutterEngine?.let { registerNativeAdFactories(it) }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    ScheduledCallTorch.stopAll()
    pendingLaunchFolderPath = intent?.getStringExtra("open_video_call_folder")

    // Helps the “incoming call” screen show over lockscreen on supported Android versions.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
      setShowWhenLocked(true)
      setTurnScreenOn(true)
    } else {
      @Suppress("DEPRECATION")
      window.addFlags(
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
      )
    }

    // Warm-up torch capability lookup off UI thread (some MIUI devices are slow here).
    torchExecutor.execute {
      ensureTorchCapabilityChecked()
      if (torchSupported && cachedTorchCameraId == null) {
        cachedTorchCameraId = findTorchCameraIdBlocking()
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    ScheduledCallTorch.stopAll()
    pendingLaunchFolderPath = intent.getStringExtra("open_video_call_folder")
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Register native ad factories (must match Flutter `factoryId` strings).
    registerNativeAdFactories(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "scheduleExactCall" -> {
            // Foreground-only scheduling in Dart; legacy no-op for old builds.
            result.success(false)
          }
          "cancelExactCall" -> {
            cancelExactAlarm()
            result.success(true)
          }
          "consumeScheduledLaunchPayload" -> {
            val payload = pendingLaunchFolderPath
            pendingLaunchFolderPath = null
            if (payload.isNullOrBlank()) {
              result.success(null)
            } else {
              result.success(mapOf("storageFolderPath" to payload))
            }
          }
          else -> result.notImplemented()
        }
      }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, torchChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "setTorch" -> {
            val enabled = call.argument<Boolean>("enabled") ?: false
            torchExecutor.execute {
              val ok = setTorchBlocking(enabled)
              runOnUiThread { result.success(ok) }
            }
          }
          "isTorchAvailable" -> {
            torchExecutor.execute {
              ensureTorchCapabilityChecked()
              if (!torchSupported) {
                runOnUiThread { result.success(false) }
                return@execute
              }
              if (cachedTorchCameraId == null) {
                cachedTorchCameraId = findTorchCameraIdBlocking()
              }
              runOnUiThread { result.success(cachedTorchCameraId != null) }
            }
          }
          else -> result.notImplemented()
        }
      }
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    // Unregister factories to avoid leaks.
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "native_small_inline")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "native_small_button_bottom")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "native_advance_button_bottom")
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "native_full_screen")
    try {
      setTorchBlocking(false)
    } catch (_: Throwable) {}
    try {
      torchExecutor.shutdownNow()
    } catch (_: Throwable) {}
    super.cleanUpFlutterEngine(flutterEngine)
  }

  private fun cancelExactAlarm() {
    try {
      val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
      val intent = Intent(this, ScheduledCallAlarmReceiver::class.java)
      val pendingIntent = PendingIntent.getBroadcast(
        this,
        21041,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )
      alarmManager.cancel(pendingIntent)
    } catch (_: Throwable) {
    }
  }

  private fun ensureTorchCapabilityChecked() {
    if (torchSupportedChecked) return
    torchSupportedChecked = true
    // Allow torch checks on all Android OEMs.
    // Some devices may still fail at runtime; those failures are handled safely in setTorchBlocking().
    torchSupported = true
  }

  private fun findTorchCameraIdBlocking(): String? {
    return try {
      val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
      manager.cameraIdList.firstOrNull { id ->
        val chars = manager.getCameraCharacteristics(id)
        val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        val lensFacing = chars.get(CameraCharacteristics.LENS_FACING)
        hasFlash && lensFacing == CameraCharacteristics.LENS_FACING_BACK
      } ?: manager.cameraIdList.firstOrNull { id ->
        val chars = manager.getCameraCharacteristics(id)
        chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
      }
    } catch (t: Throwable) {
      Log.e(TAG, "findTorchCameraId failed", t)
      null
    }
  }

  private fun setTorchBlocking(enabled: Boolean): Boolean {
    return try {
      ensureTorchCapabilityChecked()
      if (!torchSupported) return false
      val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
      val cameraId = activeTorchCameraId ?: cachedTorchCameraId ?: findTorchCameraIdBlocking()
      if (cameraId.isNullOrBlank()) return false
      cachedTorchCameraId = cameraId
      manager.setTorchMode(cameraId, enabled)
      activeTorchCameraId = if (enabled) cameraId else null
      true
    } catch (t: Throwable) {
      Log.e(TAG, "setTorch failed enabled=$enabled", t)
      false
    }
  }
}

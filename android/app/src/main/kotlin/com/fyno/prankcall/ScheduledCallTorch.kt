package com.fynotech.prankcall

import android.hardware.camera2.CameraManager
import android.os.Handler

class IncomingCallTorchStrobe(
  private val cm: CameraManager,
  private val cameraId: String,
  private val handler: Handler,
) {
  private var lit = false
  private val tick = object : Runnable {
    override fun run() {
      try {
        lit = !lit
        cm.setTorchMode(cameraId, lit)
      } catch (_: Throwable) {
      }
      handler.postDelayed(this, 450L)
    }
  }

  fun start() {
    handler.post(tick)
  }

  fun silence() {
    handler.removeCallbacks(tick)
    try {
      cm.setTorchMode(cameraId, false)
    } catch (_: Throwable) {
    }
  }
}

object ScheduledCallTorch {
  @Volatile
  private var active: IncomingCallTorchStrobe? = null

  fun attach(strobe: IncomingCallTorchStrobe) {
    active?.silence()
    active = strobe
  }

  fun onStrobeEnded(strobe: IncomingCallTorchStrobe) {
    if (active === strobe) {
      active = null
    }
  }

  fun stopAll() {
    val s = active
    active = null
    s?.silence()
  }
}

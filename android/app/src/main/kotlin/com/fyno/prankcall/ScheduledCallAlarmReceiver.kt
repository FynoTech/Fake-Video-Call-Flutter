package com.fynotech.prankcall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Legacy component: same class name/Intent as older builds so MainActivity can cancel
 * any pending exact alarms. Not registered in the manifest; scheduling is foreground-only now.
 */
class ScheduledCallAlarmReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {}
}

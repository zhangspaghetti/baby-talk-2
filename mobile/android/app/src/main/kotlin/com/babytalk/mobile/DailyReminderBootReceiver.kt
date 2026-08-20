package com.babytalk.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores the persisted wall-clock reminder after Android restarts. */
class DailyReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        restoreDailyReminder(context)
    }
}

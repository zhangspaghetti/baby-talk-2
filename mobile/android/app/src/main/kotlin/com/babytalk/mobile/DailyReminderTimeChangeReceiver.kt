package com.babytalk.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Rebuilds the wall-clock alarm after system clock or timezone changes. */
class DailyReminderTimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        restoreDailyReminder(context)
    }
}

/** Rebuilds a persisted reminder without allowing malformed prefs to crash a receiver. */
internal fun restoreDailyReminder(context: Context) {
    val preferences = context.getSharedPreferences(
        REMINDER_PREFS_NAME,
        Context.MODE_PRIVATE,
    )
    if (!preferences.getBoolean(REMINDER_PREF_ENABLED, false)) {
        return
    }

    val hour = preferences.getInt(REMINDER_PREF_HOUR, 9)
    val minute = preferences.getInt(REMINDER_PREF_MINUTE, 0)
    if (!isValidReminderTime(hour, minute)) {
        cancelDailyReminder(context)
        return
    }

    try {
        scheduleDailyReminder(context, hour, minute)
    } catch (_: RuntimeException) {
        // Alarm/notification capability can be unavailable while the device is
        // booting. The next app open or system time change can retry safely.
    }
}

package com.babytalk.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Rebuilds the wall-clock alarm after system clock or timezone changes. */
class DailyReminderTimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val preferences = context.getSharedPreferences(
            REMINDER_PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        if (!preferences.getBoolean(REMINDER_PREF_ENABLED, false)) {
            return
        }

        scheduleDailyReminder(
            context,
            preferences.getInt(REMINDER_PREF_HOUR, 9),
            preferences.getInt(REMINDER_PREF_MINUTE, 0),
        )
    }
}

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
    val reminder = readReminderPreferences(context)
    if (reminder == null) {
        disableDailyReminderSafely(context)
        return
    }
    if (!reminder.enabled) {
        return
    }
    if (!isValidReminderTime(reminder.hour, reminder.minute)) {
        disableDailyReminderSafely(context)
        return
    }

    try {
        scheduleDailyReminder(context, reminder.hour, reminder.minute)
    } catch (_: RuntimeException) {
        // Alarm/notification capability can be unavailable while the device is
        // booting. The next app open or system time change can retry safely.
    }
}

internal data class ReminderPreferences(
    val enabled: Boolean,
    val hour: Int,
    val minute: Int,
)

/** Returns null for malformed preference types instead of crashing a receiver. */
internal fun readReminderPreferences(context: Context): ReminderPreferences? = try {
    val preferences = context.getSharedPreferences(
        REMINDER_PREFS_NAME,
        Context.MODE_PRIVATE,
    )
    ReminderPreferences(
        enabled = preferences.getBoolean(REMINDER_PREF_ENABLED, false),
        hour = preferences.getInt(REMINDER_PREF_HOUR, 9),
        minute = preferences.getInt(REMINDER_PREF_MINUTE, 0),
    )
} catch (_: RuntimeException) {
    null
}

/** Clears a malformed or stale reminder without letting cleanup break a receiver. */
internal fun disableDailyReminderSafely(context: Context) {
    try {
        cancelDailyReminder(context)
    } catch (_: RuntimeException) {
        try {
            context.getSharedPreferences(REMINDER_PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .apply()
        } catch (_: RuntimeException) {
            // The receiver must remain fail-safe even if the preference store is
            // unavailable during boot or process recovery.
        }
    }
}

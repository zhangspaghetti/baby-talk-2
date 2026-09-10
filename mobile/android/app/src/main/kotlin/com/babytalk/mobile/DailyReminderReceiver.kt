package com.babytalk.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminder = readReminderPreferences(context) ?: run {
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
        createChannel(context)
        // Cancellation clears the preference after cancelling the PendingIntent.
        // Re-read immediately before publishing so a stale alarm does not notify.
        val current = readReminderPreferences(context) ?: run {
            disableDailyReminderSafely(context)
            return
        }
        if (!current.enabled || !isValidReminderTime(current.hour, current.minute)) {
            if (current.enabled) {
                disableDailyReminderSafely(context)
            }
            return
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(com.babytalk.mobile.R.mipmap.ic_launcher)
            .setContentTitle("Baby Talk")
            .setContentText("今天也和宝宝说一句英文吧。")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        try {
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Notification permission can be revoked after scheduling.
        }
        // The scheduling API is intentionally one-shot so a near-term reminder
        // is not deferred into the broad window used by inexact repeats. Keep
        // the user-selected daily cadence by scheduling the next occurrence
        // only after this receiver has run.
        scheduleDailyReminder(context, current.hour, current.minute)
    }

    companion object {
        private const val CHANNEL_ID = "daily_reminder"
        private const val NOTIFICATION_ID = 7020
        fun intent(context: Context) = Intent(context, DailyReminderReceiver::class.java)
        fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                return
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "每日提醒", NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
}

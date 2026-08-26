package com.babytalk.mobile

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

private const val REMINDER_CHANNEL = "com.babytalk.mobile/reminder"
private const val AUDIO_SESSION_CHANNEL = "com.babytalk.mobile/audio-session"
private const val REMINDER_REQUEST_CODE = 7020
private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 7021

internal const val REMINDER_PREFS_NAME = "daily_reminder"
internal const val REMINDER_PREF_ENABLED = "enabled"
internal const val REMINDER_PREF_HOUR = "hour"
internal const val REMINDER_PREF_MINUTE = "minute"

private data class PendingReminderPermission(
    val hour: Int,
    val minute: Int,
    val result: MethodChannel.Result,
)

/** Publishes playback state for Android system evidence and media controls. */
private class NativeAudioPlaybackSession(context: Context) {
    private val session = MediaSession(context.applicationContext, "BabyTalkCareAudio")

    init {
        session.setFlags(
            MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS,
        )
        session.setCallback(object : MediaSession.Callback() {})
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, "BabyTalk care audio")
                .build(),
        )
    }

    fun update(state: String, playbackRate: Float) {
        val androidState = when (state) {
            "playing" -> PlaybackState.STATE_PLAYING
            "paused" -> PlaybackState.STATE_PAUSED
            "completed" -> PlaybackState.STATE_PAUSED
            "stopped" -> PlaybackState.STATE_STOPPED
            else -> throw IllegalArgumentException("未知音频状态。")
        }
        val rate = if (playbackRate > 0f && !playbackRate.isNaN()) {
            playbackRate
        } else {
            1f
        }
        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or
                        PlaybackState.ACTION_PAUSE or
                        PlaybackState.ACTION_PLAY_PAUSE or
                        PlaybackState.ACTION_STOP,
                )
                .setState(
                    androidState,
                    PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                    rate,
                )
                .build(),
        )
        session.isActive = state != "stopped"
    }

    fun release() {
        session.isActive = false
        session.release()
    }
}

class MainActivity : FlutterActivity() {
    private var pendingReminderPermission: PendingReminderPermission? = null
    private var nativeAudioSession: NativeAudioPlaybackSession? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleDaily" -> scheduleReminder(call, result)
                    "cancel" -> {
                        pendingReminderPermission?.result?.success(
                            "permissionDenied",
                        )
                        pendingReminderPermission = null
                        cancelDailyReminder(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val state = call.argument<String>("state")
                        if (state == null) {
                            result.error("invalid_state", "音频状态缺失。", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val playbackRate = call.argument<Double>("playbackRate")?.toFloat() ?: 1f
                            if (nativeAudioSession == null) {
                                nativeAudioSession = NativeAudioPlaybackSession(this)
                            }
                            nativeAudioSession!!.update(state, playbackRate)
                            result.success(null)
                        } catch (error: IllegalArgumentException) {
                            result.error("invalid_state", error.message, null)
                        }
                    }

                    "release" -> {
                        nativeAudioSession?.release()
                        nativeAudioSession = null
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun scheduleReminder(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val hour = call.argument<Int>("hour") ?: 9
        val minute = call.argument<Int>("minute") ?: 0
        if (hour !in 0..23 || minute !in 0..59) {
            result.error("invalid_time", "提醒时间不合法。", null)
            return
        }

        if (needsNotificationPermission()) {
            pendingReminderPermission?.result?.success("unavailable")
            pendingReminderPermission = PendingReminderPermission(hour, minute, result)
            try {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE,
                )
            } catch (_: SecurityException) {
                pendingReminderPermission = null
                result.success("permissionDenied")
            }
            return
        }

        result.success(scheduleReminderNow(hour, minute))
    }

    private fun needsNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED

    private fun scheduleReminderNow(hour: Int, minute: Int): String {
        return try {
            DailyReminderReceiver.createChannel(this)
            scheduleDailyReminder(this, hour, minute)
            "scheduled"
        } catch (_: RuntimeException) {
            "unavailable"
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) {
            return
        }

        val pending = pendingReminderPermission ?: return
        pendingReminderPermission = null
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED ||
            !needsNotificationPermission()
        if (!granted) {
            pending.result.success("permissionDenied")
            return
        }
        pending.result.success(scheduleReminderNow(pending.hour, pending.minute))
    }

    override fun onDestroy() {
        pendingReminderPermission?.result?.success("unavailable")
        pendingReminderPermission = null
        nativeAudioSession?.release()
        nativeAudioSession = null
        super.onDestroy()
    }
}

/**
 * Schedules one wall-clock occurrence in the device timezone.
 *
 * The receiver schedules the following day after delivery. A one-shot
 * allow-while-idle alarm keeps an imminent reminder eligible for delivery
 * without requiring the `SCHEDULE_EXACT_ALARM` special-access gate.
 */
fun scheduleDailyReminder(context: Context, hour: Int, minute: Int) {
    if (!isValidReminderTime(hour, minute)) {
        return
    }

    val calendar = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, hour)
        set(Calendar.MINUTE, minute)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        if (timeInMillis <= System.currentTimeMillis()) {
            add(Calendar.DAY_OF_YEAR, 1)
        }
    }
    val pending = reminderPendingIntent(
        context,
        PendingIntent.FLAG_UPDATE_CURRENT,
    ) ?: error("无法创建每日提醒 PendingIntent。")
    val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
    alarmManager.cancel(pending)
    alarmManager.setAndAllowWhileIdle(
        AlarmManager.RTC_WAKEUP,
        calendar.timeInMillis,
        pending,
    )
    context.getSharedPreferences(REMINDER_PREFS_NAME, Context.MODE_PRIVATE)
        .edit()
        .putBoolean(REMINDER_PREF_ENABLED, true)
        .putInt(REMINDER_PREF_HOUR, hour)
        .putInt(REMINDER_PREF_MINUTE, minute)
        .apply()
}

internal fun isValidReminderTime(hour: Int, minute: Int): Boolean =
    hour in 0..23 && minute in 0..59

fun cancelDailyReminder(context: Context) {
    val pending = reminderPendingIntent(context, PendingIntent.FLAG_NO_CREATE)
    if (pending != null) {
        context.getSystemService(AlarmManager::class.java)?.cancel(pending)
        pending.cancel()
    }
    context.getSharedPreferences(REMINDER_PREFS_NAME, Context.MODE_PRIVATE)
        .edit()
        .clear()
        .apply()
}

private fun reminderPendingIntent(
    context: Context,
    baseFlags: Int,
): PendingIntent? {
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        baseFlags or PendingIntent.FLAG_IMMUTABLE
    } else {
        baseFlags
    }
    return PendingIntent.getBroadcast(
        context,
        REMINDER_REQUEST_CODE,
        DailyReminderReceiver.intent(context),
        flags,
    )
}

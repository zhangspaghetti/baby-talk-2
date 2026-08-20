import 'package:flutter/services.dart';

/// Native daily-notification boundary. Android implementation deliberately
/// uses an inexact repeating alarm so Android 10–current does not require
/// exact-alarm permission.
abstract interface class ReminderScheduler {
  Future<ReminderScheduleResult> scheduleDaily({
    required int hour,
    required int minute,
  });

  Future<void> cancel();
}

enum ReminderScheduleResult { scheduled, permissionDenied, unavailable }

class PlatformReminderScheduler implements ReminderScheduler {
  const PlatformReminderScheduler();

  static const _channel = MethodChannel('com.babytalk.mobile/reminder');

  @override
  Future<ReminderScheduleResult> scheduleDaily({
    required int hour,
    required int minute,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('scheduleDaily', {
        'hour': hour,
        'minute': minute,
      });
      return switch (result) {
        'scheduled' => ReminderScheduleResult.scheduled,
        'permissionDenied' => ReminderScheduleResult.permissionDenied,
        _ => ReminderScheduleResult.unavailable,
      };
    } on MissingPluginException {
      return ReminderScheduleResult.unavailable;
    } on PlatformException {
      return ReminderScheduleResult.unavailable;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // The scheduler is optional on platforms without the native capability.
    } on PlatformException {
      // The persisted setting still remains the source of truth on failure.
    }
  }
}

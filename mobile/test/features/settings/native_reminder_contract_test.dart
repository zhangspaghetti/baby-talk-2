import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final receiver = File(
    'android/app/src/main/kotlin/com/babytalk/mobile/DailyReminderReceiver.kt',
  ).readAsStringSync();
  final restoreReceiver = File(
    'android/app/src/main/kotlin/com/babytalk/mobile/DailyReminderTimeChangeReceiver.kt',
  ).readAsStringSync();

  test(
    'native receiver gates notification on the persisted reminder state',
    () {
      final notifyIndex = receiver.indexOf('.notify(NOTIFICATION_ID');

      expect(notifyIndex, greaterThan(0));
      expect(
        receiver.indexOf('val reminder = readReminderPreferences(context)'),
        lessThan(notifyIndex),
      );
      expect(receiver, contains('if (!reminder.enabled)'));
      expect(
        receiver,
        contains('val current = readReminderPreferences(context)'),
      );
      expect(
        receiver.indexOf('val current = readReminderPreferences(context)'),
        lessThan(notifyIndex),
      );
    },
  );

  test('restore path quarantines malformed preference values', () {
    expect(restoreReceiver, contains('catch (_: RuntimeException)'));
    expect(restoreReceiver, contains('disableDailyReminderSafely(context)'));
    expect(
      restoreReceiver,
      contains('getBoolean(REMINDER_PREF_ENABLED, false)'),
    );
    expect(restoreReceiver, contains('getInt(REMINDER_PREF_HOUR, 9)'));
    expect(restoreReceiver, contains('getInt(REMINDER_PREF_MINUTE, 0)'));
  });
}

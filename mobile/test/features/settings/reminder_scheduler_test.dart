import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/data/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.babytalk.mobile/reminder');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the native channel contract for schedule and cancel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'scheduleDaily' ? 'scheduled' : null;
        });

    const scheduler = PlatformReminderScheduler();
    final result = await scheduler.scheduleDaily(hour: 8, minute: 30);
    await scheduler.cancel();

    expect(result, ReminderScheduleResult.scheduled);
    expect(calls, hasLength(2));
    expect(calls.first.method, 'scheduleDaily');
    expect(calls.first.arguments, {'hour': 8, 'minute': 30});
    expect(calls.last.method, 'cancel');
  });

  test(
    'maps native permission denial without persisting a local decision',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => 'permissionDenied',
          );

      const scheduler = PlatformReminderScheduler();

      expect(
        await scheduler.scheduleDaily(hour: 8, minute: 30),
        ReminderScheduleResult.permissionDenied,
      );
    },
  );

  test('maps unavailable schedule and propagates cancel failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });

    const scheduler = PlatformReminderScheduler();

    expect(
      await scheduler.scheduleDaily(hour: 8, minute: 30),
      ReminderScheduleResult.unavailable,
    );
    await expectLater(scheduler.cancel(), throwsA(isA<PlatformException>()));
  });
}

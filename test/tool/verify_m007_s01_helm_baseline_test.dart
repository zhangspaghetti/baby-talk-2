import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/verify_m007_s01_helm_baseline.dart' as m007;

void main() {
  group('M007 S01 helm baseline CLI contract', () {
    test('requires an explicit demo or smoke mode', () {
      final missingMode = m007.CliOptions.parse(const []);
      expect(missingMode.usageError, contains('Missing mode'));

      final demo = m007.CliOptions.parse(const ['demo']);
      expect(demo.mode, m007.ExecutionMode.demo);
      expect(demo.usageError, isNull);

      final smoke = m007.CliOptions.parse(const ['smoke']);
      expect(smoke.mode, m007.ExecutionMode.smoke);
      expect(smoke.usageError, isNull);

      final invalid = m007.CliOptions.parse(const ['verify']);
      expect(invalid.usageError, contains('Unknown argument'));
    });

    test('next wrapper command follows shell parity', () {
      expect(
        m007.nextWrapperCommand(
          environment: const {'BABY_TALK_FRONT_DOOR_SHELL': 'posix'},
          isWindows: true,
        ),
        './scripts/dev-verify-helm-demo.sh',
      );
      expect(
        m007.nextWrapperCommand(
          environment: const {'BABY_TALK_FRONT_DOOR_SHELL': 'cmd'},
          isWindows: false,
        ),
        r'scripts\dev-verify-helm-demo.cmd',
      );
    });
  });

  group('M007 S01 helm telemetry', () {
    test('appendHelmTelemetry keeps bounded JSONL history', () async {
      final tempDir = await Directory.systemTemp.createTemp('m007-s01-helm-');
      final historyPath =
          '${tempDir.path}${Platform.pathSeparator}metrics.jsonl';

      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      for (var i = 0; i < 52; i += 1) {
        await m007.appendHelmTelemetry(
          m007.HelmTelemetryEntry(
            mode: i.isEven ? 'demo' : 'smoke',
            shell: 'posix',
            success: i.isEven,
            tthwSeconds: i,
            firstFailureStage: i.isEven ? 'none' : 'gateway',
            likelyCause: i.isEven ? 'none' : 'gateway_not_healthy',
            nextAction: './scripts/dev-verify-helm-demo.sh',
            timestampIso8601: DateTime.utc(2026, 4, 26, 9, 0, i).toIso8601String(),
          ),
          historyPath: historyPath,
          maxEntries: 50,
        );
      }

      final lines = await File(historyPath).readAsLines();
      expect(lines, hasLength(50));

      final first = jsonDecode(lines.first) as Map<String, dynamic>;
      final last = jsonDecode(lines.last) as Map<String, dynamic>;

      expect(first['tthw_seconds'], 2);
      expect(last['tthw_seconds'], 51);
      expect(last['timestamp'], last['timestamp_iso8601']);
      expect(last['next_action'], './scripts/dev-verify-helm-demo.sh');
    });
  });
}

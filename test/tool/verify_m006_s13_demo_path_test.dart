import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m006_s12_control_plane_freshness.dart' as s12;
import '../../tool/verify_m006_s13_demo_path.dart' as s13;

void main() {
  group('M006 S13 front door contract', () {
    test(
      'S12 keeps full replay as default and exposes explicit live-stack-only flag',
      () {
        final defaultOptions = s12.S12CliOptions.parse(const []);
        expect(defaultOptions.mode, s12.S12ReplayMode.fullReplay);
        expect(defaultOptions.showHelp, isFalse);
        expect(defaultOptions.usageError, isNull);

        final thinOptions = s12.S12CliOptions.parse(const [
          s12.s12LiveStackOnlyFlag,
        ]);
        expect(thinOptions.mode, s12.S12ReplayMode.liveStackOnly);
        expect(thinOptions.usageError, isNull);

        final invalidOptions = s12.S12CliOptions.parse(const [
          '--unknown-flag',
        ]);
        expect(invalidOptions.usageError, contains('Unknown argument'));
      },
    );

    test('S13 smoke delegates to explicit live-stack-only S12 replay', () {
      final spec = s13.buildSmokeDelegateCommand();

      expect(spec.command, isNotEmpty);
      expect(
        spec.args,
        containsAllInOrder(<String>[
          'run',
          'tool/verify_m006_s12_control_plane_freshness.dart',
          s12.s12LiveStackOnlyFlag,
        ]),
      );
      expect(spec.displayCommand, contains(s12.s12LiveStackOnlyFlag));
      expect(spec.environment?['BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT'], '1');
    });
  });

  group('M006 S13 telemetry reducer', () {
    test('summarizeFrontDoorTelemetryLines uses a bounded recent window', () {
      final summary = s13.summarizeFrontDoorTelemetryLines(
        <String>[
          _telemetryLine(
            mode: 'smoke',
            shell: 'posix',
            success: false,
            tthwSeconds: 11,
            firstFailureStage: 'live_stack_precondition',
            likelyCause: 'compose_runtime_timeout',
            nextAction: 'rerun demo',
          ),
          'not-json',
          _telemetryLine(
            mode: 'demo',
            shell: 'posix',
            success: true,
            tthwSeconds: 42,
            firstFailureStage: 'none',
            likelyCause: 'none',
            nextAction: 'run smoke',
          ),
          '',
          _telemetryLine(
            mode: 'smoke',
            shell: 'posix',
            success: false,
            tthwSeconds: 13,
            firstFailureStage: 'fast_smoke',
            likelyCause: 'control_plane_smoke_failed',
            nextAction: 'inspect Playwright',
          ),
          _telemetryLine(
            mode: 'smoke',
            shell: 'cmd',
            success: false,
            tthwSeconds: 15,
            firstFailureStage: 'fast_smoke',
            likelyCause: 'control_plane_smoke_failed',
            nextAction: 'inspect Playwright',
          ),
          _telemetryLine(
            mode: 'smoke',
            shell: 'posix',
            success: true,
            tthwSeconds: 16,
            firstFailureStage: 'none',
            likelyCause: 'none',
            nextAction: 'release closure',
          ),
        ],
        historyPath: 'tmp/test-front-door.jsonl',
        windowSize: 5,
      );

      expect(summary.historyPath, 'tmp/test-front-door.jsonl');
      expect(summary.recentEntries, 4);
      expect(summary.ignoredLines, 1);
      expect(summary.smokeAttempts, 3);
      expect(summary.smokeSuccesses, 1);
      expect(summary.smokePassRateDisplay, '33% (1/3)');
      expect(summary.firstFailureHotspot, 'fast_smoke');
    });

    test('appendFrontDoorTelemetry persists redaction-safe records', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'm006-s13-front-door-',
      );
      final historyPath =
          '${tempDir.path}${Platform.pathSeparator}front-door.jsonl';

      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final firstSummary = await s13.appendFrontDoorTelemetry(
        s13.FrontDoorTelemetryEntry(
          mode: 'demo',
          shell: 'posix',
          success: true,
          tthwSeconds: 21,
          firstFailureStage: 'none',
          likelyCause: 'none',
          nextAction: 'run smoke',
          recordedAtUtc: DateTime.utc(2026, 4, 25, 1, 0, 0),
        ),
        historyPath: historyPath,
        maxBytes: 4096,
        windowSize: 4,
      );

      expect(firstSummary.recentEntries, 1);
      expect(firstSummary.ignoredLines, 0);
      expect(firstSummary.smokeAttempts, 0);
      expect(firstSummary.firstFailureHotspot, 'none');

      await File(
        historyPath,
      ).writeAsString('malformed-history-line\n', mode: FileMode.append);

      final secondSummary = await s13.appendFrontDoorTelemetry(
        s13.FrontDoorTelemetryEntry(
          mode: 'smoke',
          shell: 'cmd',
          success: false,
          tthwSeconds: 9,
          firstFailureStage: 'fast_smoke',
          likelyCause: 'token=abc123',
          nextAction: 'password=SuperAdmin123! Bearer eyJabc.def.ghi',
          recordedAtUtc: DateTime.utc(2026, 4, 25, 1, 2, 0),
        ),
        historyPath: historyPath,
        maxBytes: 4096,
        windowSize: 4,
      );

      final persistedLines = await File(historyPath).readAsLines();
      final latestRecord =
          jsonDecode(persistedLines.last) as Map<String, dynamic>;

      expect(latestRecord['likely_cause'], 'token=[REDACTED]');
      expect(latestRecord['next_action'], isNot(contains('SuperAdmin123!')));
      expect(latestRecord['next_action'], isNot(contains('eyJabc.def.ghi')));
      expect(latestRecord['next_action'], contains('[REDACTED]'));

      expect(secondSummary.recentEntries, 2);
      expect(secondSummary.ignoredLines, 1);
      expect(secondSummary.smokeAttempts, 1);
      expect(secondSummary.smokeSuccesses, 0);
      expect(secondSummary.firstFailureHotspot, 'fast_smoke');
    });
  });
}

String _telemetryLine({
  required String mode,
  required String shell,
  required bool success,
  required int tthwSeconds,
  required String firstFailureStage,
  required String likelyCause,
  required String nextAction,
}) {
  return jsonEncode(
    s13.FrontDoorTelemetryEntry(
      mode: mode,
      shell: shell,
      success: success,
      tthwSeconds: tthwSeconds,
      firstFailureStage: firstFailureStage,
      likelyCause: likelyCause,
      nextAction: nextAction,
      recordedAtUtc: DateTime.utc(2026, 4, 25, 0, 0, tthwSeconds),
    ).toJson(),
  );
}

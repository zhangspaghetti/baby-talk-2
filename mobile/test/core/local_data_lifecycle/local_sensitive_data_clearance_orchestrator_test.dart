import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';

void main() {
  group('RegistryLocalSensitiveDataClearanceOrchestrator', () {
    test('continues all selected targets when a middle step fails', () async {
      final calls = <LocalSensitiveDataTarget>[];
      final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
        steps: <LocalSensitiveDataClearanceStep>[
          _step(LocalSensitiveDataTarget.accountLocalSnapshot, calls),
          _step(LocalSensitiveDataTarget.onboardingSnapshot, calls),
          _step(LocalSensitiveDataTarget.householdSnapshot, calls),
          _step(
            LocalSensitiveDataTarget.practiceInteractionEvents,
            calls,
            error: const FormatException('raw local path C:/secret'),
          ),
          _step(LocalSensitiveDataTarget.mentorFactEvents, calls),
          _step(LocalSensitiveDataTarget.installationId, calls),
        ],
        clock: _incrementingClock(),
      );

      final report = await orchestrator.clear(
        LocalSensitiveDataClearanceRequest(
          trigger: LocalSensitiveDataClearanceTrigger.staffPlusVerificationOnly,
          authorization: const ReportOnlyAuthorization(
            reason: 'R020 contract test',
          ),
          correlationId: 'r020-test',
          requestedAt: DateTime.utc(2026, 5, 19),
          includeTargets: const LocalSensitiveDataTargetSet.explicit(
            <LocalSensitiveDataTarget>{
              LocalSensitiveDataTarget.accountLocalSnapshot,
              LocalSensitiveDataTarget.onboardingSnapshot,
              LocalSensitiveDataTarget.householdSnapshot,
              LocalSensitiveDataTarget.practiceInteractionEvents,
              LocalSensitiveDataTarget.mentorFactEvents,
              LocalSensitiveDataTarget.installationId,
            },
          ),
        ),
      );

      expect(calls, <LocalSensitiveDataTarget>[
        LocalSensitiveDataTarget.accountLocalSnapshot,
        LocalSensitiveDataTarget.onboardingSnapshot,
        LocalSensitiveDataTarget.householdSnapshot,
        LocalSensitiveDataTarget.practiceInteractionEvents,
        LocalSensitiveDataTarget.mentorFactEvents,
        LocalSensitiveDataTarget.installationId,
      ]);
      expect(
        report.overallStatus,
        LocalSensitiveDataClearanceOverallStatus.completedWithFailures,
      );

      final failed = report.results.singleWhere(
        (result) =>
            result.target == LocalSensitiveDataTarget.practiceInteractionEvents,
      );
      expect(failed.status, LocalSensitiveDataTargetStatus.attemptedAndFailed);
      expect(failed.errorType, 'FormatException');
      expect(failed.sanitizedErrorMessage, contains('raw local path'));
      expect(
        report.results.last.target,
        LocalSensitiveDataTarget.installationId,
      );
      expect(
        report.results.last.status,
        LocalSensitiveDataTargetStatus.attemptedAndSucceeded,
      );
    });

    test(
      'rejects destructive all-target triggers without Staff+ authorization',
      () async {
        final calls = <LocalSensitiveDataTarget>[];
        final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
          steps: _allSteps(calls),
          clock: _incrementingClock(),
        );

        final report = await orchestrator.clear(
          LocalSensitiveDataClearanceRequest(
            trigger:
                LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
            authorization: const ReportOnlyAuthorization(
              reason: 'missing destructive approval',
            ),
            correlationId: 'r020-rejected',
            requestedAt: DateTime.utc(2026, 5, 19),
          ),
        );

        expect(calls, isEmpty);
        expect(
          report.overallStatus,
          LocalSensitiveDataClearanceOverallStatus.rejectedByGovernance,
        );
        expect(
          report.results,
          hasLength(LocalSensitiveDataTarget.values.length),
        );
        expect(
          report.results.map((result) => result.status).toSet(),
          <LocalSensitiveDataTargetStatus>{
            LocalSensitiveDataTargetStatus.skippedByGovernanceRejection,
          },
        );
      },
    );

    test('records skipped targets for session-only clearance policy', () async {
      final calls = <LocalSensitiveDataTarget>[];
      final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
        steps: _allSteps(calls),
        clock: _incrementingClock(),
      );

      final report = await orchestrator.clear(
        LocalSensitiveDataClearanceRequest(
          trigger: LocalSensitiveDataClearanceTrigger.logoutSessionOnly,
          authorization: const ReportOnlyAuthorization(reason: 'session only'),
          correlationId: 'r020-session-only',
          requestedAt: DateTime.utc(2026, 5, 19),
        ),
      );

      expect(calls, <LocalSensitiveDataTarget>[
        LocalSensitiveDataTarget.accountLocalSnapshot,
        LocalSensitiveDataTarget.authContinuation,
        LocalSensitiveDataTarget.customSceneDraft,
        LocalSensitiveDataTarget.generatedCareMoments,
        LocalSensitiveDataTarget.generatedAudioMemory,
      ]);
      expect(
        report.overallStatus,
        LocalSensitiveDataClearanceOverallStatus.completed,
      );
      expect(
        report.results
            .singleWhere(
              (result) =>
                  result.target ==
                  LocalSensitiveDataTarget.accountLocalSnapshot,
            )
            .status,
        LocalSensitiveDataTargetStatus.attemptedAndSucceeded,
      );
      expect(
        report.results
            .where(
              (result) =>
                  result.target !=
                      LocalSensitiveDataTarget.accountLocalSnapshot &&
                  result.target != LocalSensitiveDataTarget.authContinuation &&
                  result.target != LocalSensitiveDataTarget.customSceneDraft &&
                  result.target !=
                      LocalSensitiveDataTarget.generatedCareMoments &&
                  result.target !=
                      LocalSensitiveDataTarget.generatedAudioMemory,
            )
            .map((result) => result.status)
            .toSet(),
        <LocalSensitiveDataTargetStatus>{
          LocalSensitiveDataTargetStatus.skippedByPolicy,
        },
      );
    });
  });
}

List<LocalSensitiveDataClearanceStep> _allSteps(
  List<LocalSensitiveDataTarget> calls,
) {
  return LocalSensitiveDataTarget.values
      .map((target) => _step(target, calls))
      .toList(growable: false);
}

LocalSensitiveDataClearanceStep _step(
  LocalSensitiveDataTarget target,
  List<LocalSensitiveDataTarget> calls, {
  Object? error,
}) {
  return LocalSensitiveDataClearanceStep(
    target: target,
    primitiveName: 'test.$target',
    clear: () async {
      calls.add(target);
      if (error != null) {
        throw error;
      }
    },
  );
}

DateTime Function() _incrementingClock() {
  var tick = 0;
  return () => DateTime.utc(2026, 5, 19, 0, 0, tick++);
}

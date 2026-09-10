import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';

void main() {
  group('RegistryLocalSensitiveDataClearanceOrchestrator', () {
    test('continues Staff+ clearance when a middle step fails', () async {
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
          authorization: _staffPlusAuthorization(),
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

    test('rejects non-Staff+ authorization for Staff+ triggers', () async {
      final triggers = <LocalSensitiveDataClearanceTrigger>[
        LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
        LocalSensitiveDataClearanceTrigger.staffPlusVerificationOnly,
      ];
      final authorizations = <LocalSensitiveDataClearanceAuthorization>[
        const ReportOnlyAuthorization(reason: 'missing destructive approval'),
        CaregiverConfirmedAuthorization(
          confirmedAt: DateTime.utc(2026, 5, 19),
          confirmationText: '清除本机数据',
        ),
      ];

      for (final trigger in triggers) {
        for (final authorization in authorizations) {
          final calls = <LocalSensitiveDataTarget>[];
          final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
            steps: _allSteps(calls),
            clock: _incrementingClock(),
          );
          final report = await orchestrator.clear(
            LocalSensitiveDataClearanceRequest(
              trigger: trigger,
              authorization: authorization,
              correlationId: 'r020-rejected-${trigger.name}',
              requestedAt: DateTime.utc(2026, 5, 19),
            ),
          );

          expect(
            calls,
            isEmpty,
            reason: '${trigger.name} must reject $authorization',
          );
          expect(
            report.overallStatus,
            LocalSensitiveDataClearanceOverallStatus.rejectedByGovernance,
          );
          expect(
            report.results,
            everyElement(
              predicate<LocalSensitiveDataTargetResult>(
                (result) =>
                    result.status ==
                    LocalSensitiveDataTargetStatus.skippedByGovernanceRejection,
              ),
            ),
          );
        }
      }
    });

    test('executes Staff+ triggers only with Staff+ authorization', () async {
      for (final trigger in <LocalSensitiveDataClearanceTrigger>[
        LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
        LocalSensitiveDataClearanceTrigger.staffPlusVerificationOnly,
      ]) {
        final calls = <LocalSensitiveDataTarget>[];
        final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
          steps: _allSteps(calls),
          clock: _incrementingClock(),
        );
        final report = await orchestrator.clear(
          LocalSensitiveDataClearanceRequest(
            trigger: trigger,
            authorization: _staffPlusAuthorization(),
            correlationId: 'r020-approved-${trigger.name}',
            requestedAt: DateTime.utc(2026, 5, 19),
          ),
        );

        expect(calls, LocalSensitiveDataTarget.values);
        expect(
          report.overallStatus,
          LocalSensitiveDataClearanceOverallStatus.completed,
        );
        expect(report.authorizationEvidence.kind, 'staff_plus_destructive');
      }
    });

    test(
      'executes caregiver-confirmed device erase without Staff+ approval',
      () async {
        final calls = <LocalSensitiveDataTarget>[];
        final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
          steps: _allSteps(calls),
          clock: _incrementingClock(),
        );

        final report = await orchestrator.clear(
          LocalSensitiveDataClearanceRequest(
            trigger: LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed,
            authorization: CaregiverConfirmedAuthorization(
              confirmedAt: DateTime.utc(2026, 5, 19),
              confirmationText: '清除本机数据',
            ),
            correlationId: 'r020-caregiver-device-erase',
            requestedAt: DateTime.utc(2026, 5, 19),
          ),
        );

        expect(calls, LocalSensitiveDataTarget.values);
        expect(
          report.overallStatus,
          LocalSensitiveDataClearanceOverallStatus.completed,
        );
        expect(report.authorizationEvidence.kind, 'caregiver_confirmed');
      },
    );

    test('executes Staff+ authorized device erase', () async {
      final calls = <LocalSensitiveDataTarget>[];
      final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
        steps: _allSteps(calls),
        clock: _incrementingClock(),
      );

      final report = await orchestrator.clear(
        LocalSensitiveDataClearanceRequest(
          trigger: LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed,
          authorization: _staffPlusAuthorization(),
          correlationId: 'r020-staff-device-erase',
          requestedAt: DateTime.utc(2026, 5, 19),
        ),
      );

      expect(calls, LocalSensitiveDataTarget.values);
      expect(
        report.overallStatus,
        LocalSensitiveDataClearanceOverallStatus.completed,
      );
      expect(report.authorizationEvidence.kind, 'staff_plus_destructive');
    });

    test('device erase rejects report-only authorization', () async {
      final calls = <LocalSensitiveDataTarget>[];
      final orchestrator = RegistryLocalSensitiveDataClearanceOrchestrator(
        steps: _allSteps(calls),
        clock: _incrementingClock(),
      );

      final report = await orchestrator.clear(
        LocalSensitiveDataClearanceRequest(
          trigger: LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed,
          authorization: const ReportOnlyAuthorization(
            reason: 'report-only cannot erase device data',
          ),
          correlationId: 'r020-device-erase-rejected',
          requestedAt: DateTime.utc(2026, 5, 19),
        ),
      );

      expect(calls, isEmpty);
      expect(
        report.overallStatus,
        LocalSensitiveDataClearanceOverallStatus.rejectedByGovernance,
      );
      expect(report.authorizationEvidence.kind, 'report_only');
    });

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

StaffPlusDestructiveAuthorization _staffPlusAuthorization() {
  return StaffPlusDestructiveAuthorization(
    decisionId: 'HDR-R4-003-test',
    approvedBy: 'automated-test',
    approvedAt: DateTime.utc(2026, 5, 19),
    confirmationText: 'Clear local sensitive data in test sandbox',
  );
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

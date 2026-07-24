typedef LocalSensitiveDataClearanceCallback = Future<void> Function();
typedef LocalSensitiveDataClock = DateTime Function();

enum LocalSensitiveDataClearanceTrigger {
  logoutSessionOnly,
  consentWithdrawalConfirmed,
  accountDeletionConfirmed,
  deviceEraseConfirmed,
  staffPlusVerificationOnly,
}

enum LocalSensitiveDataTarget {
  accountLocalSnapshot,
  authContinuation,
  onboardingSnapshot,
  householdSnapshot,
  practiceInteractionEvents,
  mentorFactEvents,
  installationId,
}

enum LocalSensitiveDataClearanceOverallStatus {
  completed,
  completedWithFailures,
  rejectedByGovernance,
}

enum LocalSensitiveDataTargetStatus {
  attemptedAndSucceeded,
  attemptedAndFailed,
  skippedByPolicy,
  skippedByGovernanceRejection,
}

extension LocalSensitiveDataTargetStatusX on LocalSensitiveDataTargetStatus {
  bool get isFailure =>
      this == LocalSensitiveDataTargetStatus.attemptedAndFailed;
}

sealed class LocalSensitiveDataClearanceAuthorization {
  const LocalSensitiveDataClearanceAuthorization();
}

final class ReportOnlyAuthorization
    extends LocalSensitiveDataClearanceAuthorization {
  const ReportOnlyAuthorization({required this.reason});

  final String reason;
}

final class StaffPlusDestructiveAuthorization
    extends LocalSensitiveDataClearanceAuthorization {
  const StaffPlusDestructiveAuthorization({
    required this.decisionId,
    required this.approvedBy,
    required this.approvedAt,
    required this.confirmationText,
  });

  final String decisionId;
  final String approvedBy;
  final DateTime approvedAt;
  final String confirmationText;
}

final class LocalSensitiveDataTargetSet {
  const LocalSensitiveDataTargetSet.policyDefault() : explicitTargets = null;

  const LocalSensitiveDataTargetSet.explicit(this.explicitTargets);

  final Set<LocalSensitiveDataTarget>? explicitTargets;
}

final class LocalSensitiveDataClearanceRequest {
  const LocalSensitiveDataClearanceRequest({
    required this.trigger,
    required this.authorization,
    required this.correlationId,
    required this.requestedAt,
    this.includeTargets = const LocalSensitiveDataTargetSet.policyDefault(),
  });

  final LocalSensitiveDataClearanceTrigger trigger;
  final LocalSensitiveDataClearanceAuthorization authorization;
  final String correlationId;
  final DateTime requestedAt;
  final LocalSensitiveDataTargetSet includeTargets;
}

final class LocalSensitiveDataClearanceStep {
  const LocalSensitiveDataClearanceStep({
    required this.target,
    required this.primitiveName,
    required this.clear,
  });

  final LocalSensitiveDataTarget target;
  final String primitiveName;
  final LocalSensitiveDataClearanceCallback clear;
}

final class LocalSensitiveDataAuthorizationEvidence {
  const LocalSensitiveDataAuthorizationEvidence._({
    required this.kind,
    this.reason,
    this.decisionId,
    this.approvedBy,
    this.approvedAt,
  });

  factory LocalSensitiveDataAuthorizationEvidence.from(
    LocalSensitiveDataClearanceAuthorization authorization,
  ) {
    return switch (authorization) {
      ReportOnlyAuthorization(:final reason) =>
        LocalSensitiveDataAuthorizationEvidence._(
          kind: 'report_only',
          reason: reason,
        ),
      StaffPlusDestructiveAuthorization(
        :final decisionId,
        :final approvedBy,
        :final approvedAt,
      ) =>
        LocalSensitiveDataAuthorizationEvidence._(
          kind: 'staff_plus_destructive',
          decisionId: decisionId,
          approvedBy: approvedBy,
          approvedAt: approvedAt,
        ),
    };
  }

  final String kind;
  final String? reason;
  final String? decisionId;
  final String? approvedBy;
  final DateTime? approvedAt;
}

final class LocalSensitiveDataTargetResult {
  const LocalSensitiveDataTargetResult({
    required this.target,
    required this.primitiveName,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    this.errorType,
    this.sanitizedErrorMessage,
  });

  final LocalSensitiveDataTarget target;
  final String primitiveName;
  final LocalSensitiveDataTargetStatus status;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String? errorType;
  final String? sanitizedErrorMessage;
}

final class LocalSensitiveDataClearanceReport {
  const LocalSensitiveDataClearanceReport({
    required this.correlationId,
    required this.trigger,
    required this.requestedAt,
    required this.startedAt,
    required this.finishedAt,
    required this.overallStatus,
    required this.authorizationEvidence,
    required this.results,
  });

  final String correlationId;
  final LocalSensitiveDataClearanceTrigger trigger;
  final DateTime requestedAt;
  final DateTime startedAt;
  final DateTime finishedAt;
  final LocalSensitiveDataClearanceOverallStatus overallStatus;
  final LocalSensitiveDataAuthorizationEvidence authorizationEvidence;
  final List<LocalSensitiveDataTargetResult> results;

  bool get hasFailures => results.any((result) => result.status.isFailure);
}

abstract interface class LocalSensitiveDataClearanceOrchestrator {
  Future<LocalSensitiveDataClearanceReport> clear(
    LocalSensitiveDataClearanceRequest request,
  );
}

final class RegistryLocalSensitiveDataClearanceOrchestrator
    implements LocalSensitiveDataClearanceOrchestrator {
  RegistryLocalSensitiveDataClearanceOrchestrator({
    required List<LocalSensitiveDataClearanceStep> steps,
    LocalSensitiveDataClock? clock,
  }) : _steps = _normalizeSteps(steps),
       _clock = clock ?? DateTime.now;

  final List<LocalSensitiveDataClearanceStep> _steps;
  final LocalSensitiveDataClock _clock;

  @override
  Future<LocalSensitiveDataClearanceReport> clear(
    LocalSensitiveDataClearanceRequest request,
  ) async {
    final startedAt = _clock().toUtc();
    final selectedTargets = _targetsFor(request);
    final authorizationEvidence = LocalSensitiveDataAuthorizationEvidence.from(
      request.authorization,
    );

    if (_requiresStaffPlusAuthorization(request) &&
        request.authorization is! StaffPlusDestructiveAuthorization) {
      return LocalSensitiveDataClearanceReport(
        correlationId: request.correlationId,
        trigger: request.trigger,
        requestedAt: request.requestedAt,
        startedAt: startedAt,
        finishedAt: _clock().toUtc(),
        overallStatus:
            LocalSensitiveDataClearanceOverallStatus.rejectedByGovernance,
        authorizationEvidence: authorizationEvidence,
        results: _steps
            .where((step) => selectedTargets.contains(step.target))
            .map(
              (step) => LocalSensitiveDataTargetResult(
                target: step.target,
                primitiveName: step.primitiveName,
                status:
                    LocalSensitiveDataTargetStatus.skippedByGovernanceRejection,
                startedAt: startedAt,
                finishedAt: startedAt,
              ),
            )
            .toList(growable: false),
      );
    }

    final results = <LocalSensitiveDataTargetResult>[];
    for (final step in _steps) {
      if (!selectedTargets.contains(step.target)) {
        results.add(
          LocalSensitiveDataTargetResult(
            target: step.target,
            primitiveName: step.primitiveName,
            status: LocalSensitiveDataTargetStatus.skippedByPolicy,
            startedAt: startedAt,
            finishedAt: startedAt,
          ),
        );
        continue;
      }

      final stepStartedAt = _clock().toUtc();
      try {
        await step.clear();
        results.add(
          LocalSensitiveDataTargetResult(
            target: step.target,
            primitiveName: step.primitiveName,
            status: LocalSensitiveDataTargetStatus.attemptedAndSucceeded,
            startedAt: stepStartedAt,
            finishedAt: _clock().toUtc(),
          ),
        );
      } catch (error) {
        results.add(
          LocalSensitiveDataTargetResult(
            target: step.target,
            primitiveName: step.primitiveName,
            status: LocalSensitiveDataTargetStatus.attemptedAndFailed,
            startedAt: stepStartedAt,
            finishedAt: _clock().toUtc(),
            errorType: error.runtimeType.toString(),
            sanitizedErrorMessage: _sanitizeErrorMessage(error),
          ),
        );
      }
    }

    return LocalSensitiveDataClearanceReport(
      correlationId: request.correlationId,
      trigger: request.trigger,
      requestedAt: request.requestedAt,
      startedAt: startedAt,
      finishedAt: _clock().toUtc(),
      overallStatus:
          results.any(
            (result) =>
                result.status ==
                LocalSensitiveDataTargetStatus.attemptedAndFailed,
          )
          ? LocalSensitiveDataClearanceOverallStatus.completedWithFailures
          : LocalSensitiveDataClearanceOverallStatus.completed,
      authorizationEvidence: authorizationEvidence,
      results: List.unmodifiable(results),
    );
  }

  static List<LocalSensitiveDataClearanceStep> _normalizeSteps(
    List<LocalSensitiveDataClearanceStep> steps,
  ) {
    final byTarget =
        <LocalSensitiveDataTarget, LocalSensitiveDataClearanceStep>{};
    for (final step in steps) {
      if (byTarget.containsKey(step.target)) {
        throw ArgumentError(
          'Duplicate local data lifecycle target: ${step.target}',
        );
      }
      byTarget[step.target] = step;
    }
    return List<LocalSensitiveDataClearanceStep>.unmodifiable(
      LocalSensitiveDataTarget.values
          .where(byTarget.containsKey)
          .map((target) => byTarget[target]!),
    );
  }

  Set<LocalSensitiveDataTarget> _targetsFor(
    LocalSensitiveDataClearanceRequest request,
  ) {
    final explicitTargets = request.includeTargets.explicitTargets;
    if (explicitTargets != null) {
      return Set<LocalSensitiveDataTarget>.unmodifiable(explicitTargets);
    }

    return switch (request.trigger) {
      LocalSensitiveDataClearanceTrigger.logoutSessionOnly =>
        const <LocalSensitiveDataTarget>{
          LocalSensitiveDataTarget.accountLocalSnapshot,
          LocalSensitiveDataTarget.authContinuation,
        },
      LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed =>
        const <LocalSensitiveDataTarget>{
          LocalSensitiveDataTarget.accountLocalSnapshot,
          LocalSensitiveDataTarget.authContinuation,
          LocalSensitiveDataTarget.householdSnapshot,
          LocalSensitiveDataTarget.mentorFactEvents,
        },
      LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed ||
      LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed ||
      LocalSensitiveDataClearanceTrigger.staffPlusVerificationOnly =>
        Set<LocalSensitiveDataTarget>.unmodifiable(
          LocalSensitiveDataTarget.values,
        ),
    };
  }

  bool _requiresStaffPlusAuthorization(
    LocalSensitiveDataClearanceRequest request,
  ) {
    return switch (request.trigger) {
      LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed ||
      LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed => true,
      LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed =>
        _targetsFor(request).any(
          (target) => target != LocalSensitiveDataTarget.accountLocalSnapshot,
        ),
      LocalSensitiveDataClearanceTrigger.logoutSessionOnly ||
      LocalSensitiveDataClearanceTrigger.staffPlusVerificationOnly => false,
    };
  }
}

String _sanitizeErrorMessage(Object error) {
  final singleLine = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= 240) {
    return singleLine;
  }
  return '${singleLine.substring(0, 240)}...';
}

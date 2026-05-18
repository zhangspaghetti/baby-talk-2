import 'dart:collection';
import 'dart:io';

const sensitiveLifecycleUsage =
    '''Usage: dart tool/verify_refactor_013_sensitive_lifecycle.dart [--help]

Verifies the REFACTOR-013 local sensitive data lifecycle matrix against the
current mobile local storage source files.

This verifier is report-only: missing deletion primitives and lifecycle gaps are
printed, but the command exits successfully so the migration baseline can be
tracked before hard enforcement is introduced.
''';

const sensitiveLifecycleSuccessMarker =
    'REFACTOR-013 local sensitive data lifecycle report-only scan completed.';

const sensitiveLifecyclePolicyPath =
    'ai/architecture/local-sensitive-data-lifecycle.md';

const expectedSensitiveSurfaces = <SensitiveLifecycleSpec>[
  SensitiveLifecycleSpec(
    id: 'account_local_snapshot',
    label: 'Account local snapshot',
    classification: 'sensitive_account_auth',
    sourcePath:
        'mobile/lib/features/account/data/local/account_local_store.dart',
    requiredSourceMarkers: <String>[
      'class AccountLocalStore',
      'FlutterSecureStorage',
    ],
    deletePrimitiveMarkers: <String>['Future<void> deleteIfExists()'],
  ),
  SensitiveLifecycleSpec(
    id: 'onboarding_snapshot',
    label: 'Onboarding snapshot',
    classification: 'sensitive_child_profile',
    sourcePath:
        'mobile/lib/features/onboarding/data/local/onboarding_snapshot_store.dart',
    requiredSourceMarkers: <String>['class OnboardingSnapshotStore'],
    deletePrimitiveMarkers: <String>['Future<void> deleteIfExists()'],
  ),
  SensitiveLifecycleSpec(
    id: 'household_snapshot',
    label: 'Household snapshot',
    classification: 'sensitive_household_context',
    sourcePath:
        'mobile/lib/features/household/data/local/household_local_store.dart',
    requiredSourceMarkers: <String>['class HouseholdLocalStore'],
    deletePrimitiveMarkers: <String>['Future<void> deleteIfExists()'],
  ),
  SensitiveLifecycleSpec(
    id: 'practice_interaction_events',
    label: 'Practice interaction events',
    classification: 'sensitive_child_behavior_history',
    sourcePath:
        'mobile/lib/features/practice/data/local/practice_local_data_source.dart',
    requiredSourceMarkers: <String>['class PracticeLocalDataSource'],
    deletePrimitiveMarkers: <String>['close({bool deleteFromDisk = false})'],
  ),
  SensitiveLifecycleSpec(
    id: 'mentor_fact_events',
    label: 'Mentor fact events',
    classification: 'sensitive_mentor_context',
    sourcePath:
        'mobile/lib/features/mentor/data/local/mentor_local_data_source.dart',
    requiredSourceMarkers: <String>['class MentorLocalDataSource'],
    deletePrimitiveMarkers: <String>['close({bool deleteFromDisk = false})'],
  ),
  SensitiveLifecycleSpec(
    id: 'installation_id',
    label: 'Installation ID',
    classification: 'sensitive_persistent_identifier',
    sourcePath: 'mobile/lib/core/device/installation_id_service.dart',
    requiredSourceMarkers: <String>['class InstallationIdService'],
    deletePrimitiveMarkers: <String>['Future<void> deleteIfExists()'],
  ),
];

Future<void> main(List<String> args) async {
  final options = SensitiveLifecycleCliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(sensitiveLifecycleUsage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(sensitiveLifecycleUsage);
    exit(64);
  }

  final report = scanSensitiveLifecycle(projectRoot: Directory.current.path);
  stdout.write(renderSensitiveLifecycleReport(report));
  stdout.writeln(sensitiveLifecycleSuccessMarker);
}

class SensitiveLifecycleCliOptions {
  const SensitiveLifecycleCliOptions({
    required this.showHelp,
    required this.usageError,
  });

  final bool showHelp;
  final String? usageError;

  static SensitiveLifecycleCliOptions parse(List<String> args) {
    var showHelp = false;
    for (final argument in args) {
      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;
        default:
          return SensitiveLifecycleCliOptions(
            showHelp: showHelp,
            usageError: 'Unknown argument: $argument',
          );
      }
    }

    return SensitiveLifecycleCliOptions(showHelp: showHelp, usageError: null);
  }
}

enum SensitiveLifecycleStatus {
  coveredDeletePrimitive('covered_delete_primitive'),
  missingDeletePrimitive('missing_delete_primitive'),
  missingSource('missing_source'),
  missingDocumentation('missing_documentation');

  const SensitiveLifecycleStatus(this.label);

  final String label;
}

class SensitiveLifecycleSpec {
  const SensitiveLifecycleSpec({
    required this.id,
    required this.label,
    required this.classification,
    required this.sourcePath,
    required this.requiredSourceMarkers,
    required this.deletePrimitiveMarkers,
  });

  final String id;
  final String label;
  final String classification;
  final String sourcePath;
  final List<String> requiredSourceMarkers;
  final List<String> deletePrimitiveMarkers;
}

class SensitiveLifecycleReport {
  const SensitiveLifecycleReport({
    required this.projectRoot,
    required this.policyPath,
    required this.findings,
  });

  final String projectRoot;
  final String policyPath;
  final List<SensitiveLifecycleFinding> findings;

  int countByStatus(SensitiveLifecycleStatus status) =>
      findings.where((finding) => finding.status == status).length;

  SplayTreeMap<String, int> get countsByClassification {
    final counts = SplayTreeMap<String, int>();
    for (final finding in findings) {
      counts[finding.spec.classification] =
          (counts[finding.spec.classification] ?? 0) + 1;
    }
    return counts;
  }
}

class SensitiveLifecycleFinding {
  const SensitiveLifecycleFinding({
    required this.spec,
    required this.documented,
    required this.sourceExists,
    required this.missingSourceMarkers,
    required this.missingDeletePrimitiveMarkers,
  });

  final SensitiveLifecycleSpec spec;
  final bool documented;
  final bool sourceExists;
  final List<String> missingSourceMarkers;
  final List<String> missingDeletePrimitiveMarkers;

  SensitiveLifecycleStatus get status {
    if (!documented) {
      return SensitiveLifecycleStatus.missingDocumentation;
    }
    if (!sourceExists || missingSourceMarkers.isNotEmpty) {
      return SensitiveLifecycleStatus.missingSource;
    }
    if (missingDeletePrimitiveMarkers.isNotEmpty) {
      return SensitiveLifecycleStatus.missingDeletePrimitive;
    }
    return SensitiveLifecycleStatus.coveredDeletePrimitive;
  }
}

SensitiveLifecycleReport scanSensitiveLifecycle({String? projectRoot}) {
  final resolvedProjectRoot = _normalizePath(
    projectRoot ?? Directory.current.path,
  );
  final policyFile = File('$resolvedProjectRoot/$sensitiveLifecyclePolicyPath');
  final policyText = policyFile.existsSync()
      ? policyFile.readAsStringSync()
      : '';

  final findings = <SensitiveLifecycleFinding>[];
  for (final spec in expectedSensitiveSurfaces) {
    final sourceFile = File('$resolvedProjectRoot/${spec.sourcePath}');
    final sourceExists = sourceFile.existsSync();
    final sourceText = sourceExists ? sourceFile.readAsStringSync() : '';
    findings.add(
      SensitiveLifecycleFinding(
        spec: spec,
        documented: _policyDocumentsSurface(policyText, spec),
        sourceExists: sourceExists,
        missingSourceMarkers: _missingMarkers(
          sourceText,
          spec.requiredSourceMarkers,
        ),
        missingDeletePrimitiveMarkers: _missingMarkers(
          sourceText,
          spec.deletePrimitiveMarkers,
        ),
      ),
    );
  }

  return SensitiveLifecycleReport(
    projectRoot: resolvedProjectRoot,
    policyPath: sensitiveLifecyclePolicyPath,
    findings: findings,
  );
}

String renderSensitiveLifecycleReport(SensitiveLifecycleReport report) {
  final buffer = StringBuffer();
  buffer.writeln('sensitive_lifecycle_scan_status=report_only');
  buffer.writeln('project_root=${report.projectRoot}');
  buffer.writeln('policy_document=${report.policyPath}');
  buffer.writeln('total_sensitive_surfaces=${report.findings.length}');
  for (final status in SensitiveLifecycleStatus.values) {
    buffer.writeln('${status.label}=${report.countByStatus(status)}');
  }

  buffer.writeln('');
  buffer.writeln('classifications:');
  for (final entry in report.countsByClassification.entries) {
    buffer.writeln('  ${entry.key}=${entry.value}');
  }

  buffer.writeln('');
  buffer.writeln('surfaces:');
  for (final finding in report.findings) {
    final details = <String>[];
    if (!finding.documented) {
      details.add('policy row missing');
    }
    if (!finding.sourceExists) {
      details.add('source missing');
    }
    if (finding.missingSourceMarkers.isNotEmpty) {
      details.add(
        'missing source markers: ${finding.missingSourceMarkers.join(', ')}',
      );
    }
    if (finding.missingDeletePrimitiveMarkers.isNotEmpty) {
      details.add(
        'missing delete primitive markers: '
        '${finding.missingDeletePrimitiveMarkers.join(', ')}',
      );
    }
    buffer.writeln(
      '  ${finding.status.label} ${finding.spec.id} '
      '${finding.spec.classification} ${finding.spec.sourcePath}'
      '${details.isEmpty ? '' : ' | ${details.join('; ')}'}',
    );
  }

  return buffer.toString();
}

bool _policyDocumentsSurface(String policyText, SensitiveLifecycleSpec spec) {
  return policyText.contains('| ${spec.id} |') &&
      policyText.contains(spec.classification);
}

List<String> _missingMarkers(String text, List<String> markers) {
  return markers
      .where((marker) => !text.contains(marker))
      .toList(growable: false);
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/services/account_external_link_opener.dart';

import '../../../tool/verify_refactor_011_feature_boundaries.dart'
    as feature_boundary;
import '../../../tool/verify_refactor_013_sensitive_lifecycle.dart'
    as sensitive_lifecycle;
import '../../../tool/verify_m2_11_custom_scene_gates.dart' as m2_11;

void main() {
  group('R4 release gate policy', () {
    test('feature-boundary debt budget does not regress', () {
      final report = feature_boundary.scanFeatureBoundaryImports(
        projectRoot: _repoRootPath(),
      );

      expect(
        report.edges.length,
        lessThanOrEqualTo(99),
        reason:
            'R4 feature-boundary hard gate allows the current baseline only.\n'
            '${feature_boundary.renderFeatureBoundaryReport(report)}',
      );
      expect(
        report.countByStatus(
          feature_boundary.FeatureBoundaryStatus.legacyBridge,
        ),
        lessThanOrEqualTo(69),
        reason:
            'Legacy bridge imports may decrease, but must not increase.\n'
            '${feature_boundary.renderFeatureBoundaryReport(report)}',
      );
      expect(
        report.countByStatus(
          feature_boundary.FeatureBoundaryStatus.forbiddenCandidate,
        ),
        lessThanOrEqualTo(30),
        reason:
            'Forbidden cross-feature candidates may decrease, but must not increase.\n'
            '${feature_boundary.renderFeatureBoundaryReport(report)}',
      );
    });

    test('sensitive lifecycle scanner has no primitive/doc/source gaps', () {
      final report = sensitive_lifecycle.scanSensitiveLifecycle(
        projectRoot: _repoRootPath(),
      );

      final blockingStatuses = <sensitive_lifecycle.SensitiveLifecycleStatus>{
        sensitive_lifecycle.SensitiveLifecycleStatus.missingDeletePrimitive,
        sensitive_lifecycle.SensitiveLifecycleStatus.missingSource,
        sensitive_lifecycle.SensitiveLifecycleStatus.missingDocumentation,
      };
      final blockers = report.findings
          .where((finding) => blockingStatuses.contains(finding.status))
          .toList();

      expect(
        blockers,
        isEmpty,
        reason:
            'R4 lifecycle hard gate requires every documented sensitive store '
            'to keep a source file and delete primitive.\n'
            '${sensitive_lifecycle.renderSensitiveLifecycleReport(report)}',
      );
    });

    test('M2-11 custom-scene privacy and architecture gates pass', () {
      final report = m2_11.scanM211CustomSceneGates(
        projectRoot: _repoRootPath(),
      );
      expect(
        report.violations,
        isEmpty,
        reason: m2_11.renderM211CustomSceneGateReport(report),
      );
    });

    test('destructive product-flow wiring stays within HDR-R4-003 scope', () {
      final offenders = _findOutOfScopeDestructiveProductFlowWiring(
        _repoRootPath(),
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'HDR-R4-003 approves only account deletion and consent-withdrawal '
            'product-flow entries; additional destructive local-data wiring needs '
            'a new approval.\n'
            '${offenders.join('\n')}',
      );
    });

    test('account upgrade links are https-only and host-allowlisted', () {
      expect(
        validateAccountUpgradeUrl(
          'https://download.example.com/upgrade?channel=stable&source=version_gate',
        ).isValid,
        isTrue,
      );
      expect(
        validateAccountUpgradeUrl(
          'https://updates.babytalk.example.com/upgrade',
        ).isValid,
        isTrue,
      );
      expect(
        validateAccountUpgradeUrl(
          Uri(
            scheme: 'http',
            host: 'download.example.com',
            path: '/upgrade',
          ).toString(),
        ).failureKind,
        AccountExternalLinkFailureKind.unsafeScheme,
      );
      expect(
        validateAccountUpgradeUrl(
          'https://download.example.net/upgrade',
        ).failureKind,
        AccountExternalLinkFailureKind.unapprovedHost,
      );
    });
  });
}

String _repoRootPath() {
  final current = Directory.current;
  if (File('${current.path}/pubspec.yaml').existsSync() &&
      Directory('${current.path}/lib').existsSync() &&
      Directory('${current.parent.path}/mobile/lib').existsSync()) {
    return current.parent.path;
  }
  return current.path;
}

List<String> _findOutOfScopeDestructiveProductFlowWiring(String repoRoot) {
  final featureRoot = Directory('$repoRoot/mobile/lib/features');
  if (!featureRoot.existsSync()) {
    return const <String>[];
  }

  const approvedAccountLifecyclePath =
      'mobile/lib/features/account/presentation/account_notifier.dart';
  const destructiveMarkers = <_DestructiveMarker>[
    _DestructiveMarker(
      text: 'LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed',
      allowedPaths: <String>{approvedAccountLifecyclePath},
    ),
    _DestructiveMarker(
      text: 'LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed',
    ),
    _DestructiveMarker(
      text: 'LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed',
      allowedPaths: <String>{approvedAccountLifecyclePath},
    ),
    _DestructiveMarker(text: 'LocalSensitiveDataClearanceRequest('),
    _DestructiveMarker(text: 'createLocalSensitiveDataClearanceOrchestrator('),
  ];

  final offenders = <String>[];
  for (final entity in featureRoot.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final path = entity.path.replaceAll('\\', '/');
    if (!path.endsWith('.dart') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart')) {
      continue;
    }

    final source = entity.readAsStringSync();
    final relativePath = _projectRelativePath(path, repoRoot);
    for (final marker in destructiveMarkers) {
      if (source.contains(marker.text) &&
          !marker.allowedPaths.contains(relativePath)) {
        offenders.add('$relativePath contains ${marker.text}');
      }
    }
  }
  offenders.sort();
  return offenders;
}

String _projectRelativePath(String path, String repoRoot) {
  final normalizedRoot = repoRoot.replaceAll('\\', '/');
  final rootPrefix = normalizedRoot.endsWith('/')
      ? normalizedRoot
      : '$normalizedRoot/';
  return path.startsWith(rootPrefix) ? path.substring(rootPrefix.length) : path;
}

class _DestructiveMarker {
  const _DestructiveMarker({
    required this.text,
    this.allowedPaths = const <String>{},
  });

  final String text;
  final Set<String> allowedPaths;
}

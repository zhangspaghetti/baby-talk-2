import 'dart:collection';
import 'dart:io';

const featureBoundaryScanUsage =
    '''Usage: dart tool/verify_refactor_011_feature_boundaries.dart [--help]

Scans mobile/lib/features for cross-feature import/export directives.
This verifier is report-only: legacy edges and forbidden candidates are printed,
but the command exits successfully so existing violations can be tracked before
hard enforcement is introduced.
''';

const featureBoundarySuccessMarker =
    'REFACTOR-011 feature boundary report-only scan completed.';

const knownMobileFeatures = <String>[
  'account',
  'household',
  'mentor',
  'onboarding',
  'practice',
  'share',
  'shell',
  'sync',
];

const approvedFeatureBoundaryRules = <FeatureBoundaryRule>[
  FeatureBoundaryRule(
    sourceFeature: 'shell',
    targetFeature: '*',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'shell owns current cross-feature screen composition until feature entry contracts exist',
  ),
  FeatureBoundaryRule(
    sourceFeature: 'mentor',
    targetFeature: 'account',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'mentor still reuses account session and authenticated client until auth moves behind a core contract',
  ),
  FeatureBoundaryRule(
    sourceFeature: 'account',
    targetFeature: 'practice',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'account lifecycle still coordinates practice export/delete until a practice lifecycle contract exists',
  ),
  FeatureBoundaryRule(
    sourceFeature: 'account',
    targetFeature: 'household',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'account surface still renders household cards until an account surface slot contract exists',
  ),
  FeatureBoundaryRule(
    sourceFeature: 'account',
    targetFeature: 'onboarding',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'account surface still derives phase from onboarding snapshot until a profile summary contract exists',
  ),
  FeatureBoundaryRule(
    sourceFeature: 'household',
    targetFeature: 'practice',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'household cards still deep-link into practice until a practice entry contract exists',
  ),
  FeatureBoundaryRule(
    sourceFeature: 'share',
    targetFeature: 'practice',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'share still reads practice summary models until a shareable progress contract exists',
  ),
  FeatureBoundaryRule(
    sourceFeature: 'sync',
    targetFeature: 'practice',
    status: FeatureBoundaryStatus.legacyBridge,
    reason:
        'sync currently uploads practice events until sync ownership is moved behind a practice sync contract',
  ),
];

final _directivePattern = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');

Future<void> main(List<String> args) async {
  final options = FeatureBoundaryScanCliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(featureBoundaryScanUsage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(featureBoundaryScanUsage);
    exit(64);
  }

  final report = scanFeatureBoundaryImports(
    projectRoot: Directory.current.path,
  );
  stdout.write(renderFeatureBoundaryReport(report));
  stdout.writeln(featureBoundarySuccessMarker);
}

class FeatureBoundaryScanCliOptions {
  const FeatureBoundaryScanCliOptions({
    required this.showHelp,
    required this.usageError,
  });

  final bool showHelp;
  final String? usageError;

  static FeatureBoundaryScanCliOptions parse(List<String> args) {
    var showHelp = false;
    for (final argument in args) {
      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;
        default:
          return FeatureBoundaryScanCliOptions(
            showHelp: showHelp,
            usageError: 'Unknown argument: $argument',
          );
      }
    }

    return FeatureBoundaryScanCliOptions(showHelp: showHelp, usageError: null);
  }
}

enum FeatureBoundaryStatus {
  legacyBridge('legacy_bridge'),
  forbiddenCandidate('forbidden_candidate');

  const FeatureBoundaryStatus(this.label);

  final String label;
}

class FeatureBoundaryRule {
  const FeatureBoundaryRule({
    required this.sourceFeature,
    required this.targetFeature,
    required this.status,
    required this.reason,
  });

  final String sourceFeature;
  final String targetFeature;
  final FeatureBoundaryStatus status;
  final String reason;

  bool matches(String sourceFeature, String targetFeature) {
    final sourceMatches = this.sourceFeature == sourceFeature;
    final targetMatches =
        this.targetFeature == '*' || this.targetFeature == targetFeature;
    return sourceMatches && targetMatches;
  }
}

class FeatureBoundaryScanReport {
  const FeatureBoundaryScanReport({
    required this.projectRoot,
    required this.edges,
  });

  final String projectRoot;
  final List<FeatureImportEdge> edges;

  int countByStatus(FeatureBoundaryStatus status) =>
      edges.where((edge) => edge.status == status).length;

  SplayTreeMap<String, int> get countsByPair {
    final counts = SplayTreeMap<String, int>();
    for (final edge in edges) {
      final pair = '${edge.sourceFeature}->${edge.targetFeature}';
      counts[pair] = (counts[pair] ?? 0) + 1;
    }
    return counts;
  }

  SplayTreeMap<String, int> get countsByStatusLabel {
    final counts = SplayTreeMap<String, int>();
    for (final edge in edges) {
      counts[edge.status.label] = (counts[edge.status.label] ?? 0) + 1;
    }
    return counts;
  }
}

class FeatureImportEdge {
  const FeatureImportEdge({
    required this.sourceFeature,
    required this.targetFeature,
    required this.sourcePath,
    required this.lineNumber,
    required this.directive,
    required this.importUri,
    required this.targetLayer,
    required this.status,
    required this.reason,
  });

  final String sourceFeature;
  final String targetFeature;
  final String sourcePath;
  final int lineNumber;
  final String directive;
  final String importUri;
  final String targetLayer;
  final FeatureBoundaryStatus status;
  final String reason;

  String get pair => '$sourceFeature->$targetFeature';
}

FeatureBoundaryScanReport scanFeatureBoundaryImports({String? projectRoot}) {
  final resolvedProjectRoot = _normalizePath(
    projectRoot ?? Directory.current.path,
  );
  final featureRoot = Directory('$resolvedProjectRoot/mobile/lib/features');

  if (!featureRoot.existsSync()) {
    throw FileSystemException(
      'Mobile feature root does not exist',
      featureRoot.path,
    );
  }

  final edges = <FeatureImportEdge>[];
  final dartFiles =
      featureRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .where((file) => !file.path.endsWith('.freezed.dart'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  for (final dartFile in dartFiles) {
    final sourcePath = _projectRelativePath(dartFile.path, resolvedProjectRoot);
    final sourceFeature = featureFromProjectPath(sourcePath);
    if (sourceFeature == null) {
      continue;
    }

    final lines = dartFile.readAsLinesSync();
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
      final directive = _parseDirective(lines[lineIndex]);
      if (directive == null) {
        continue;
      }

      final targetPath = projectPathForDartImport(
        directive.importUri,
        sourcePath: sourcePath,
      );
      if (targetPath == null) {
        continue;
      }

      final targetFeature = featureFromProjectPath(targetPath);
      if (targetFeature == null || targetFeature == sourceFeature) {
        continue;
      }

      final classification = classifyFeatureImport(
        sourceFeature,
        targetFeature,
      );
      edges.add(
        FeatureImportEdge(
          sourceFeature: sourceFeature,
          targetFeature: targetFeature,
          sourcePath: sourcePath,
          lineNumber: lineIndex + 1,
          directive: directive.keyword,
          importUri: directive.importUri,
          targetLayer: featureLayerFromProjectPath(targetPath) ?? 'unknown',
          status: classification.status,
          reason: classification.reason,
        ),
      );
    }
  }

  edges.sort((left, right) {
    final pathComparison = left.sourcePath.compareTo(right.sourcePath);
    if (pathComparison != 0) {
      return pathComparison;
    }
    return left.lineNumber.compareTo(right.lineNumber);
  });

  return FeatureBoundaryScanReport(
    projectRoot: resolvedProjectRoot,
    edges: edges,
  );
}

FeatureImportClassification classifyFeatureImport(
  String sourceFeature,
  String targetFeature,
) {
  for (final rule in approvedFeatureBoundaryRules) {
    if (rule.matches(sourceFeature, targetFeature)) {
      return FeatureImportClassification(
        status: rule.status,
        reason: rule.reason,
      );
    }
  }

  return const FeatureImportClassification(
    status: FeatureBoundaryStatus.forbiddenCandidate,
    reason:
        'no REFACTOR-011 feature boundary exception currently allows this edge',
  );
}

class FeatureImportClassification {
  const FeatureImportClassification({
    required this.status,
    required this.reason,
  });

  final FeatureBoundaryStatus status;
  final String reason;
}

String renderFeatureBoundaryReport(FeatureBoundaryScanReport report) {
  final buffer = StringBuffer();
  buffer.writeln('feature_boundary_import_scan_status=report_only');
  buffer.writeln('project_root=${report.projectRoot}');
  buffer.writeln('known_features=${knownMobileFeatures.join(',')}');
  buffer.writeln('total_cross_feature_imports=${report.edges.length}');
  for (final status in FeatureBoundaryStatus.values) {
    buffer.writeln('${status.label}=${report.countByStatus(status)}');
  }

  buffer.writeln('');
  buffer.writeln('pairs:');
  if (report.countsByPair.isEmpty) {
    buffer.writeln('  none');
  } else {
    for (final entry in report.countsByPair.entries) {
      buffer.writeln('  ${entry.key}=${entry.value}');
    }
  }

  buffer.writeln('');
  buffer.writeln('edges:');
  if (report.edges.isEmpty) {
    buffer.writeln('  none');
  } else {
    for (final edge in report.edges) {
      buffer.writeln(
        '  ${edge.status.label} ${edge.pair} ${edge.targetLayer} '
        '${edge.sourcePath}:${edge.lineNumber} ${edge.directive} '
        '${edge.importUri} | ${edge.reason}',
      );
    }
  }

  return buffer.toString();
}

String? projectPathForDartImport(
  String importUri, {
  required String sourcePath,
}) {
  if (importUri.startsWith('package:mobile/')) {
    return _normalizePath(
      'mobile/lib/${importUri.substring('package:mobile/'.length)}',
    );
  }

  if (importUri.startsWith('dart:') ||
      importUri.startsWith('package:') ||
      importUri.contains(':')) {
    return null;
  }

  final sourceDirectory = Uri.file(sourcePath).resolve('.');
  final resolvedPath = sourceDirectory.resolve(importUri).path;
  return _normalizePath(resolvedPath);
}

String? featureFromProjectPath(String projectPath) {
  final segments = _normalizePath(projectPath).split('/');
  final featureRootIndex = _featureRootIndex(segments);
  if (featureRootIndex == null || featureRootIndex + 3 >= segments.length) {
    return null;
  }
  final featureName = segments[featureRootIndex + 3];
  return knownMobileFeatures.contains(featureName) ? featureName : null;
}

String? featureLayerFromProjectPath(String projectPath) {
  final segments = _normalizePath(projectPath).split('/');
  final featureRootIndex = _featureRootIndex(segments);
  if (featureRootIndex == null || featureRootIndex + 4 >= segments.length) {
    return null;
  }
  return segments[featureRootIndex + 4];
}

int? _featureRootIndex(List<String> segments) {
  for (
    var segmentIndex = 0;
    segmentIndex <= segments.length - 3;
    segmentIndex += 1
  ) {
    if (segments[segmentIndex] == 'mobile' &&
        segments[segmentIndex + 1] == 'lib' &&
        segments[segmentIndex + 2] == 'features') {
      return segmentIndex;
    }
  }
  return null;
}

_DartImportDirective? _parseDirective(String line) {
  final match = _directivePattern.firstMatch(line);
  if (match == null) {
    return null;
  }

  return _DartImportDirective(
    keyword: match.group(1)!,
    importUri: match.group(2)!,
  );
}

class _DartImportDirective {
  const _DartImportDirective({required this.keyword, required this.importUri});

  final String keyword;
  final String importUri;
}

String _projectRelativePath(String path, String projectRoot) {
  final normalizedPath = _normalizePath(path);
  final normalizedRoot = _normalizePath(projectRoot);
  final rootPrefix = normalizedRoot.endsWith('/')
      ? normalizedRoot
      : '$normalizedRoot/';
  if (normalizedPath.startsWith(rootPrefix)) {
    return normalizedPath.substring(rootPrefix.length);
  }
  return normalizedPath;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

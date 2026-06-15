import 'dart:collection';
import 'dart:io';

const mobileV2SemanticFirewallUsage =
    '''Usage: dart tool/verify_mobile_v2_semantic_firewall.dart [--help]

Scans mobile_v2/lib for old mobile phrase/activity/completion/streak/Garden
semantics and imports. Reference material is allowed only in explicit
mobile_v2 quarantine paths that do not feed runtime product truth.
''';

const mobileV2SemanticFirewallSuccessMarker =
    'M010-P39 mobile_v2 semantic firewall verified.';

const mobileV2BannedRuntimeTerms = <String>[
  'phraseId',
  'activityId',
  'completedPhrase',
  'completedPhraseCount',
  'completedPhraseIds',
  'nextPhraseId',
  'currentStreakDays',
  'streak',
  'GardenGrowth',
  'starterPhraseId',
];

const _forbiddenOldMobileFeatures = <String>{
  'practice',
  'onboarding',
  'garden',
};

const _allowlistedReferencePrefixes = <String>[
  'mobile_v2/reference_assets/',
  'mobile_v2/legacy_reference/',
  'mobile_v2/docs/',
  'mobile_v2/test/fixtures/',
];

const _referenceTextExtensions = <String>{
  '.dart',
  '.json',
  '.md',
  '.txt',
  '.yaml',
  '.yml',
};

final _directivePattern = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');

Future<void> main(List<String> args) async {
  final options = MobileV2SemanticFirewallCliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(mobileV2SemanticFirewallUsage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(mobileV2SemanticFirewallUsage);
    exit(64);
  }

  final report = scanMobileV2SemanticFirewall(
    projectRoot: Directory.current.path,
  );
  stdout.write(renderMobileV2SemanticFirewallReport(report));
  if (report.hasBlockingViolations) {
    exit(1);
  }
  stdout.writeln(mobileV2SemanticFirewallSuccessMarker);
}

class MobileV2SemanticFirewallCliOptions {
  const MobileV2SemanticFirewallCliOptions({
    required this.showHelp,
    required this.usageError,
  });

  final bool showHelp;
  final String? usageError;

  static MobileV2SemanticFirewallCliOptions parse(List<String> args) {
    var showHelp = false;
    for (final argument in args) {
      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;
        default:
          return MobileV2SemanticFirewallCliOptions(
            showHelp: showHelp,
            usageError: 'Unknown argument: $argument',
          );
      }
    }

    return MobileV2SemanticFirewallCliOptions(
      showHelp: showHelp,
      usageError: null,
    );
  }
}

enum MobileV2SemanticFirewallViolationType {
  forbiddenImport('forbidden_import'),
  bannedRuntimeTerm('banned_runtime_term'),
  missingBoundary('missing_boundary');

  const MobileV2SemanticFirewallViolationType(this.label);

  final String label;
}

class MobileV2SemanticFirewallReport {
  const MobileV2SemanticFirewallReport({
    required this.projectRoot,
    required this.scannedRuntimeFileCount,
    required this.scannedReferenceFileCount,
    required this.violations,
    required this.allowlistedReferences,
  });

  final String projectRoot;
  final int scannedRuntimeFileCount;
  final int scannedReferenceFileCount;
  final List<MobileV2SemanticFirewallViolation> violations;
  final List<MobileV2SemanticFirewallAllowlistedReference>
  allowlistedReferences;

  bool get hasBlockingViolations => violations.isNotEmpty;

  int countByType(MobileV2SemanticFirewallViolationType type) =>
      violations.where((violation) => violation.type == type).length;

  SplayTreeMap<String, int> get countsByTypeLabel {
    final counts = SplayTreeMap<String, int>();
    for (final type in MobileV2SemanticFirewallViolationType.values) {
      counts[type.label] = countByType(type);
    }
    return counts;
  }
}

class MobileV2SemanticFirewallViolation {
  const MobileV2SemanticFirewallViolation({
    required this.type,
    required this.sourcePath,
    required this.lineNumber,
    required this.reason,
    this.directive,
    this.importUri,
    this.resolvedPath,
    this.term,
  });

  final MobileV2SemanticFirewallViolationType type;
  final String sourcePath;
  final int lineNumber;
  final String reason;
  final String? directive;
  final String? importUri;
  final String? resolvedPath;
  final String? term;
}

class MobileV2SemanticFirewallAllowlistedReference {
  const MobileV2SemanticFirewallAllowlistedReference({
    required this.sourcePath,
    required this.lineNumber,
    required this.term,
    required this.reason,
  });

  final String sourcePath;
  final int lineNumber;
  final String term;
  final String reason;
}

MobileV2SemanticFirewallReport scanMobileV2SemanticFirewall({
  String? projectRoot,
}) {
  final resolvedProjectRoot = _normalizePath(
    projectRoot ?? Directory.current.path,
  );
  final runtimeRoot = Directory('$resolvedProjectRoot/mobile_v2/lib');
  final violations = <MobileV2SemanticFirewallViolation>[];

  var scannedRuntimeFileCount = 0;
  if (!runtimeRoot.existsSync()) {
    violations.add(
      const MobileV2SemanticFirewallViolation(
        type: MobileV2SemanticFirewallViolationType.missingBoundary,
        sourcePath: 'mobile_v2/lib',
        lineNumber: 0,
        reason:
            'mobile_v2/lib is missing; semantic firewall must fail closed until the vNext runtime boundary exists',
      ),
    );
  } else {
    final runtimeFiles = _listRuntimeDartFiles(
      runtimeRoot,
      resolvedProjectRoot,
    );
    scannedRuntimeFileCount = runtimeFiles.length;
    for (final dartFile in runtimeFiles) {
      final sourcePath = _projectRelativePath(
        dartFile.path,
        resolvedProjectRoot,
      );
      _scanRuntimeFile(dartFile, sourcePath, violations);
    }
  }

  final allowlistedReferences =
      <MobileV2SemanticFirewallAllowlistedReference>[];
  var scannedReferenceFileCount = 0;
  for (final referenceFile in _listReferenceFiles(resolvedProjectRoot)) {
    scannedReferenceFileCount += 1;
    final sourcePath = _projectRelativePath(
      referenceFile.path,
      resolvedProjectRoot,
    );
    _scanAllowlistedReferenceFile(
      referenceFile,
      sourcePath,
      allowlistedReferences,
    );
  }

  violations.sort(_compareViolation);
  allowlistedReferences.sort(_compareAllowlistedReference);

  return MobileV2SemanticFirewallReport(
    projectRoot: resolvedProjectRoot,
    scannedRuntimeFileCount: scannedRuntimeFileCount,
    scannedReferenceFileCount: scannedReferenceFileCount,
    violations: violations,
    allowlistedReferences: allowlistedReferences,
  );
}

String renderMobileV2SemanticFirewallReport(
  MobileV2SemanticFirewallReport report,
) {
  final buffer = StringBuffer();
  buffer.writeln(
    'mobile_v2_semantic_firewall_status='
    '${report.hasBlockingViolations ? 'fail' : 'pass'}',
  );
  buffer.writeln('project_root=${report.projectRoot}');
  buffer.writeln('runtime_root=mobile_v2/lib');
  buffer.writeln('scanned_runtime_files=${report.scannedRuntimeFileCount}');
  buffer.writeln('scanned_reference_files=${report.scannedReferenceFileCount}');
  for (final entry in report.countsByTypeLabel.entries) {
    buffer.writeln('${entry.key}=${entry.value}');
  }
  buffer.writeln(
    'allowlisted_reference_terms='
    '${report.allowlistedReferences.length}',
  );

  buffer.writeln('');
  buffer.writeln('violations:');
  if (report.violations.isEmpty) {
    buffer.writeln('  none');
  } else {
    for (final violation in report.violations) {
      final details = <String>[
        violation.type.label,
        '${violation.sourcePath}:${violation.lineNumber}',
      ];
      if (violation.term != null) {
        details.add('term=${violation.term}');
      }
      if (violation.directive != null && violation.importUri != null) {
        details.add('${violation.directive}=${violation.importUri}');
      }
      if (violation.resolvedPath != null) {
        details.add('resolved=${violation.resolvedPath}');
      }
      buffer.writeln('  ${details.join(' ')} | ${violation.reason}');
    }
  }

  buffer.writeln('');
  buffer.writeln('allowlisted_reference_material:');
  if (report.allowlistedReferences.isEmpty) {
    buffer.writeln('  none');
  } else {
    for (final reference in report.allowlistedReferences) {
      buffer.writeln(
        '  ${reference.sourcePath}:${reference.lineNumber} '
        'term=${reference.term} | ${reference.reason}',
      );
    }
  }

  return buffer.toString();
}

void _scanRuntimeFile(
  File dartFile,
  String sourcePath,
  List<MobileV2SemanticFirewallViolation> violations,
) {
  final lines = dartFile.readAsLinesSync();
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final lineNumber = lineIndex + 1;
    final line = lines[lineIndex];
    final directive = _parseDirective(line);
    if (directive != null) {
      final targetPath = projectPathForDartImport(
        directive.importUri,
        sourcePath: sourcePath,
      );
      if (_isForbiddenRuntimeImportTarget(targetPath)) {
        violations.add(
          MobileV2SemanticFirewallViolation(
            type: MobileV2SemanticFirewallViolationType.forbiddenImport,
            sourcePath: sourcePath,
            lineNumber: lineNumber,
            directive: directive.keyword,
            importUri: directive.importUri,
            resolvedPath: targetPath,
            reason:
                'mobile_v2/lib cannot import old mobile product feature code or quarantined reference material as vNext runtime truth',
          ),
        );
      }
    }

    for (final term in mobileV2BannedRuntimeTerms) {
      if (_lineContainsTerm(line, term)) {
        violations.add(
          MobileV2SemanticFirewallViolation(
            type: MobileV2SemanticFirewallViolationType.bannedRuntimeTerm,
            sourcePath: sourcePath,
            lineNumber: lineNumber,
            term: term,
            reason:
                'old phrase/activity/completion/streak/Garden semantics are banned under mobile_v2/lib',
          ),
        );
      }
    }
  }
}

void _scanAllowlistedReferenceFile(
  File referenceFile,
  String sourcePath,
  List<MobileV2SemanticFirewallAllowlistedReference> references,
) {
  final lines = referenceFile.readAsLinesSync();
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final lineNumber = lineIndex + 1;
    final line = lines[lineIndex];
    for (final term in mobileV2BannedRuntimeTerms) {
      if (_lineContainsTerm(line, term)) {
        references.add(
          MobileV2SemanticFirewallAllowlistedReference(
            sourcePath: sourcePath,
            lineNumber: lineNumber,
            term: term,
            reason:
                'old semantic term is allowed only as reference/quarantine material outside mobile_v2/lib',
          ),
        );
      }
    }
  }
}

List<File> _listRuntimeDartFiles(Directory runtimeRoot, String projectRoot) {
  final files =
      runtimeRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !_isGeneratedDartFile(file.path))
          .toList()
        ..sort((left, right) {
          final leftPath = _projectRelativePath(left.path, projectRoot);
          final rightPath = _projectRelativePath(right.path, projectRoot);
          return leftPath.compareTo(rightPath);
        });
  return files;
}

List<File> _listReferenceFiles(String projectRoot) {
  final files = <File>[];
  for (final prefix in _allowlistedReferencePrefixes) {
    final directory = Directory(
      '$projectRoot/${prefix.substring(0, prefix.length - 1)}',
    );
    if (!directory.existsSync()) {
      continue;
    }
    files.addAll(
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => !_isGeneratedDartFile(file.path))
          .where((file) => _isReferenceTextFile(file.path)),
    );
  }
  files.sort((left, right) {
    final leftPath = _projectRelativePath(left.path, projectRoot);
    final rightPath = _projectRelativePath(right.path, projectRoot);
    return leftPath.compareTo(rightPath);
  });
  return files;
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

  final sourceDirectory = sourcePath.contains('/')
      ? sourcePath.substring(0, sourcePath.lastIndexOf('/'))
      : '.';
  return _normalizePath(Uri.parse('$sourceDirectory/').resolve(importUri).path);
}

bool _isForbiddenOldMobileProductPath(String? projectPath) {
  if (projectPath == null) {
    return false;
  }

  final segments = _normalizePath(projectPath).split('/');
  for (var index = 0; index <= segments.length - 4; index += 1) {
    if (segments[index] == 'mobile' &&
        segments[index + 1] == 'lib' &&
        segments[index + 2] == 'features' &&
        _forbiddenOldMobileFeatures.contains(segments[index + 3])) {
      return true;
    }
  }
  return false;
}

bool _isForbiddenRuntimeImportTarget(String? projectPath) =>
    _isForbiddenOldMobileProductPath(projectPath) ||
    _isQuarantinedReferencePath(projectPath);

bool _isQuarantinedReferencePath(String? projectPath) {
  if (projectPath == null) {
    return false;
  }
  final normalized = _normalizePath(projectPath);
  return _allowlistedReferencePrefixes.any(normalized.startsWith);
}

bool _isReferenceTextFile(String path) {
  final lowerPath = _normalizePath(path).toLowerCase();
  return _referenceTextExtensions.any(lowerPath.endsWith);
}

bool _lineContainsTerm(String line, String term) {
  final pattern = RegExp(
    '(?<![A-Za-z0-9_])${RegExp.escape(term)}(?![A-Za-z0-9_])',
  );
  return pattern.hasMatch(line);
}

bool _isGeneratedDartFile(String path) =>
    path.endsWith('.g.dart') || path.endsWith('.freezed.dart');

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

int _compareViolation(
  MobileV2SemanticFirewallViolation left,
  MobileV2SemanticFirewallViolation right,
) {
  final pathComparison = left.sourcePath.compareTo(right.sourcePath);
  if (pathComparison != 0) {
    return pathComparison;
  }
  final lineComparison = left.lineNumber.compareTo(right.lineNumber);
  if (lineComparison != 0) {
    return lineComparison;
  }
  return left.type.label.compareTo(right.type.label);
}

int _compareAllowlistedReference(
  MobileV2SemanticFirewallAllowlistedReference left,
  MobileV2SemanticFirewallAllowlistedReference right,
) {
  final pathComparison = left.sourcePath.compareTo(right.sourcePath);
  if (pathComparison != 0) {
    return pathComparison;
  }
  final lineComparison = left.lineNumber.compareTo(right.lineNumber);
  if (lineComparison != 0) {
    return lineComparison;
  }
  return left.term.compareTo(right.term);
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

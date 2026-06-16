import 'dart:collection';
import 'dart:io';

const activationGovernorContractUsage =
    '''Usage: dart tool/verify_activation_governor_contract.dart [--help]

Scans mobile_v2/lib and typed Activation Governor contract cases for Phase 40
authority seams: Explore stays open, Activate is governed, Runtime consumes
decisions, and Garden Memory uses parent-confirmed states without checklist
pressure.
''';

const activationGovernorContractSuccessMarker =
    'M010-P40 activation governor contract verified.';

const defaultActivationGovernorContractCases =
    <ActivationGovernorContractCase>[
      ActivationGovernorContractCase(
        id: 'default-explore-candidate-open',
        description: 'Explore may show candidate ideas without activation',
        surface: 'explore',
        producer: 'PackGraph',
        consumer: 'Parent',
        decisionSource: 'Explore',
        text: 'Here are gentle sound ideas to read later.',
        gardenAction: 'show_candidate',
        hasGovernorDecision: false,
        hasParentIntent: false,
        requiresGovernorDecision: false,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: true,
        expectedReason: 'Explore candidate generation is not activation',
      ),
      ActivationGovernorContractCase(
        id: 'default-runtime-consumes-governor',
        description: 'Runtime consumes an existing allow_activation decision',
        surface: 'runtime-agent',
        producer: 'Runtime',
        consumer: 'Parent',
        decisionSource: 'ActivationGovernor',
        text: 'Apply the existing allow_activation decision.',
        gardenAction: 'present_active',
        hasGovernorDecision: true,
        hasParentIntent: true,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: true,
        expectedReason: 'Runtime may consume an existing Governor decision',
      ),
      ActivationGovernorContractCase(
        id: 'default-pack-graph-shortcut-rejected',
        description: 'Pack/Graph direct activation shortcut is rejected',
        surface: 'strategy-pack',
        producer: 'PackGraph',
        consumer: 'Runtime',
        decisionSource: 'PackGraph',
        text: 'Matched this routine, start this micro-ritual today.',
        gardenAction: 'set_active',
        hasGovernorDecision: false,
        hasParentIntent: true,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Pack/Graph cannot create active micro-rituals',
      ),
      ActivationGovernorContractCase(
        id: 'default-runtime-self-governance-rejected',
        description: 'Runtime self-governance is rejected',
        surface: 'runtime-agent',
        producer: 'Runtime',
        consumer: 'Parent',
        decisionSource: 'Runtime',
        text: 'Runtime decided the parent should say this today.',
        gardenAction: 'set_active',
        hasGovernorDecision: false,
        hasParentIntent: true,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Runtime cannot self-govern activation',
      ),
      ActivationGovernorContractCase(
        id: 'default-garden-policy-rejected',
        description: 'Garden-owned activation policy is rejected',
        surface: 'garden',
        producer: 'Garden',
        consumer: 'Runtime',
        decisionSource: 'Garden',
        text: 'Garden policy says add this sound today.',
        gardenAction: 'activation_policy',
        hasGovernorDecision: false,
        hasParentIntent: true,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Garden cannot own activation policy',
      ),
    ];

final _activationIntentPatterns = <RegExp>[
  RegExp(r'\btoday\s+try\b', caseSensitive: false),
  RegExp(r'\btry\s+this\s+today\b', caseSensitive: false),
  RegExp(r'\badd\s+this\s+sound\b', caseSensitive: false),
  RegExp(r'\bstart\s+this\s+micro-?ritual\b', caseSensitive: false),
  RegExp(r'\bsay\s+this\s+during\b', caseSensitive: false),
  RegExp(r'\bsay\s+this\b.*\btoday\b', caseSensitive: false),
  RegExp(r'\bshould\s+say\b', caseSensitive: false),
];

final _gardenPressurePatterns = <RegExp>[
  RegExp(r'\bchecklist\b', caseSensitive: false),
  RegExp(r'\bstreak\b', caseSensitive: false),
  RegExp(r'\bcompletion\b', caseSensitive: false),
  RegExp(r'\bcompleted\b', caseSensitive: false),
  RegExp(r'\bscore\b', caseSensitive: false),
  RegExp(r'\bgrowth\b', caseSensitive: false),
  RegExp(r'\bfertilizer\b', caseSensitive: false),
  RegExp(r'\breward\b', caseSensitive: false),
  RegExp(r'\bunlock\b', caseSensitive: false),
  RegExp(r'\bpunishment\b', caseSensitive: false),
  RegExp(r'\bprogress\s+bar\b', caseSensitive: false),
  RegExp(r'\bGardenGrowth\b'),
  RegExp(r'\bcurrentStreakDays\b'),
];

const _suspiciousAuthorityNames = <String>{
  'markFamiliar',
  'setActive',
  'activationPolicy',
};

Future<void> main(List<String> args) async {
  final options = ActivationGovernorContractCliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(activationGovernorContractUsage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(activationGovernorContractUsage);
    exit(64);
  }

  final report = scanActivationGovernorContract(
    projectRoot: Directory.current.path,
  );
  stdout.write(renderActivationGovernorContractReport(report));
  if (report.hasBlockingViolations) {
    exit(1);
  }
  stdout.writeln(activationGovernorContractSuccessMarker);
}

class ActivationGovernorContractCliOptions {
  const ActivationGovernorContractCliOptions({
    required this.showHelp,
    required this.usageError,
  });

  final bool showHelp;
  final String? usageError;

  static ActivationGovernorContractCliOptions parse(List<String> args) {
    var showHelp = false;
    for (final argument in args) {
      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;
        default:
          return ActivationGovernorContractCliOptions(
            showHelp: showHelp,
            usageError: 'Unknown argument: $argument',
          );
      }
    }

    return ActivationGovernorContractCliOptions(
      showHelp: showHelp,
      usageError: null,
    );
  }
}

class ActivationGovernorContractCase {
  const ActivationGovernorContractCase({
    required this.id,
    required this.description,
    required this.surface,
    required this.producer,
    required this.consumer,
    required this.decisionSource,
    required this.text,
    required this.gardenAction,
    required this.hasGovernorDecision,
    required this.hasParentIntent,
    required this.requiresGovernorDecision,
    required this.requiresParentConfirmation,
    required this.weakSignalOnly,
    required this.expectedPass,
    required this.expectedReason,
  });

  final String id;
  final String description;
  final String surface;
  final String producer;
  final String consumer;
  final String decisionSource;
  final String text;
  final String gardenAction;
  final bool hasGovernorDecision;
  final bool hasParentIntent;
  final bool requiresGovernorDecision;
  final bool requiresParentConfirmation;
  final bool weakSignalOnly;
  final bool expectedPass;
  final String expectedReason;
}

enum ActivationGovernorContractViolationType {
  missingBoundary('missing_boundary'),
  contractFixture('contract_fixture'),
  authority('authority'),
  activationIntent('activation_intent'),
  parentConfirmation('parent_confirmation'),
  gardenMemory('garden_memory'),
  weakSignal('weak_signal'),
  sourceScan('source_scan');

  const ActivationGovernorContractViolationType(this.label);

  final String label;
}

class ActivationGovernorContractReport {
  const ActivationGovernorContractReport({
    required this.projectRoot,
    required this.scannedRuntimeFileCount,
    required this.evaluatedCaseCount,
    required this.expectedRejectedCaseCount,
    required this.violations,
  });

  final String projectRoot;
  final int scannedRuntimeFileCount;
  final int evaluatedCaseCount;
  final int expectedRejectedCaseCount;
  final List<ActivationGovernorContractViolation> violations;

  bool get hasBlockingViolations => violations.isNotEmpty;

  int countByType(ActivationGovernorContractViolationType type) =>
      violations.where((violation) => violation.type == type).length;

  SplayTreeMap<String, int> get countsByTypeLabel {
    final counts = SplayTreeMap<String, int>();
    for (final type in ActivationGovernorContractViolationType.values) {
      counts[type.label] = countByType(type);
    }
    return counts;
  }
}

class ActivationGovernorContractViolation {
  const ActivationGovernorContractViolation({
    required this.type,
    required this.sourcePath,
    required this.lineNumber,
    required this.reason,
    this.caseId,
    this.term,
  });

  final ActivationGovernorContractViolationType type;
  final String sourcePath;
  final int lineNumber;
  final String reason;
  final String? caseId;
  final String? term;
}

ActivationGovernorContractReport scanActivationGovernorContract({
  String? projectRoot,
  List<ActivationGovernorContractCase>? contractCases,
}) {
  final resolvedProjectRoot = _normalizePath(
    projectRoot ?? Directory.current.path,
  );
  final runtimeRoot = Directory('$resolvedProjectRoot/mobile_v2/lib');
  final violations = <ActivationGovernorContractViolation>[];

  var scannedRuntimeFileCount = 0;
  if (!runtimeRoot.existsSync()) {
    violations.add(
      const ActivationGovernorContractViolation(
        type: ActivationGovernorContractViolationType.missingBoundary,
        sourcePath: 'mobile_v2/lib',
        lineNumber: 0,
        reason:
            'mobile_v2/lib is missing; Activation Governor contract verifier must fail closed until the vNext runtime boundary exists',
      ),
    );
  } else {
    final runtimeFiles = _listRuntimeDartFiles(
      runtimeRoot,
      resolvedProjectRoot,
    );
    scannedRuntimeFileCount = runtimeFiles.length;
    for (final dartFile in runtimeFiles) {
      _scanRuntimeSourceFile(
        dartFile,
        _projectRelativePath(dartFile.path, resolvedProjectRoot),
        violations,
      );
    }
  }

  final cases = contractCases ?? defaultActivationGovernorContractCases;
  final usingDefaultProofCases = contractCases == null;
  var expectedRejectedCaseCount = 0;
  if (cases.isEmpty) {
    violations.add(
      const ActivationGovernorContractViolation(
        type: ActivationGovernorContractViolationType.contractFixture,
        sourcePath: 'typed-contract-cases',
        lineNumber: 0,
        reason:
            'typed Activation Governor contract cases are required; empty fixture sets cannot prove R063/R064/R065',
      ),
    );
  } else {
    for (final contractCase in cases) {
      final caseViolations = _evaluateContractCase(contractCase);
      final actualPass = caseViolations.isEmpty;
      if (usingDefaultProofCases &&
          !contractCase.expectedPass &&
          !actualPass) {
        expectedRejectedCaseCount += 1;
        continue;
      }
      violations.addAll(caseViolations);
      if (actualPass != contractCase.expectedPass) {
        violations.add(
          ActivationGovernorContractViolation(
            type: ActivationGovernorContractViolationType.contractFixture,
            sourcePath: 'typed-contract-cases',
            lineNumber: 0,
            caseId: contractCase.id,
            reason:
                'case expected ${contractCase.expectedPass ? 'pass' : 'fail'} but evaluated ${actualPass ? 'pass' : 'fail'}: ${contractCase.expectedReason}',
          ),
        );
      }
    }
  }

  violations.sort(_compareViolation);

  return ActivationGovernorContractReport(
    projectRoot: resolvedProjectRoot,
    scannedRuntimeFileCount: scannedRuntimeFileCount,
    evaluatedCaseCount: cases.length,
    expectedRejectedCaseCount: expectedRejectedCaseCount,
    violations: violations,
  );
}

String renderActivationGovernorContractReport(
  ActivationGovernorContractReport report,
) {
  final buffer = StringBuffer();
  buffer.writeln(
    'activation_governor_contract_status='
    '${report.hasBlockingViolations ? 'fail' : 'pass'}',
  );
  buffer.writeln('project_root=${report.projectRoot}');
  buffer.writeln('runtime_root=mobile_v2/lib');
  buffer.writeln('scanned_runtime_files=${report.scannedRuntimeFileCount}');
  buffer.writeln('evaluated_contract_cases=${report.evaluatedCaseCount}');
  buffer.writeln(
    'expected_rejected_contract_cases='
    '${report.expectedRejectedCaseCount}',
  );
  for (final entry in report.countsByTypeLabel.entries) {
    buffer.writeln('${entry.key}=${entry.value}');
  }

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
      if (violation.caseId != null) {
        details.add('case=${violation.caseId}');
      }
      if (violation.term != null) {
        details.add('term=${violation.term}');
      }
      buffer.writeln('  ${details.join(' ')} | ${violation.reason}');
    }
  }

  return buffer.toString();
}

List<ActivationGovernorContractViolation> _evaluateContractCase(
  ActivationGovernorContractCase contractCase,
) {
  final violations = <ActivationGovernorContractViolation>[];
  final producer = _normalizeToken(contractCase.producer);
  final decisionSource = _normalizeToken(contractCase.decisionSource);
  final gardenAction = _normalizeToken(contractCase.gardenAction);
  final text = contractCase.text;
  final hasActivationIntent = _hasActivationIntent(text);
  final meaningfulGardenAction = _isMeaningfulGardenStateAction(gardenAction);

  if (contractCase.requiresGovernorDecision &&
      (!_isGovernor(decisionSource) || !contractCase.hasGovernorDecision)) {
    violations.add(
      _caseViolation(
        contractCase,
        ActivationGovernorContractViolationType.authority,
        'Activation intent requires an Activation Governor decision',
      ),
    );
  }

  if (_isPackGraph(producer) &&
      (gardenAction == 'set_active' ||
          hasActivationIntent ||
          contractCase.requiresGovernorDecision)) {
    violations.add(
      _caseViolation(
        contractCase,
        ActivationGovernorContractViolationType.authority,
        'Pack/Graph may produce candidates only and cannot create active micro-rituals',
      ),
    );
  }

  if (producer == 'runtime' &&
      decisionSource == 'runtime' &&
      (contractCase.requiresGovernorDecision ||
          gardenAction == 'set_active' ||
          hasActivationIntent)) {
    violations.add(
      _caseViolation(
        contractCase,
        ActivationGovernorContractViolationType.authority,
        'Runtime may consume an existing Governor decision but cannot self-govern activation',
      ),
    );
  }

  if (producer == 'garden' &&
      (decisionSource == 'garden' ||
          gardenAction == 'activation_policy' ||
          gardenAction == 'set_active') &&
      (contractCase.requiresGovernorDecision ||
          gardenAction == 'activation_policy' ||
          gardenAction == 'set_active')) {
    violations.add(
      _caseViolation(
        contractCase,
        ActivationGovernorContractViolationType.authority,
        'Garden may present state and collect confirmation but cannot own activation policy',
      ),
    );
  }

  if (hasActivationIntent &&
      contractCase.requiresGovernorDecision &&
      !contractCase.hasGovernorDecision) {
    violations.add(
      _caseViolation(
        contractCase,
        ActivationGovernorContractViolationType.activationIntent,
        'Action-now activation copy must be backed by a Governor decision',
      ),
    );
  }

  if (gardenAction == 'set_active') {
    if (!contractCase.hasParentIntent) {
      violations.add(
        _caseViolation(
          contractCase,
          ActivationGovernorContractViolationType.parentConfirmation,
          'candidate -> active requires parent intent/readiness',
        ),
      );
    }
    if (!_isGovernor(decisionSource) || !contractCase.hasGovernorDecision) {
      violations.add(
        _caseViolation(
          contractCase,
          ActivationGovernorContractViolationType.authority,
          'candidate -> active requires Governor allow_activation',
        ),
      );
    }
  }

  if (meaningfulGardenAction) {
    if (contractCase.weakSignalOnly) {
      violations.add(
        _caseViolation(
          contractCase,
          ActivationGovernorContractViolationType.weakSignal,
          'weak signals may prompt review only and cannot write Garden Memory truth states',
        ),
      );
    }
    if (contractCase.requiresParentConfirmation &&
        !contractCase.hasParentIntent) {
      violations.add(
        _caseViolation(
          contractCase,
          ActivationGovernorContractViolationType.parentConfirmation,
          'meaningful Garden Memory states require parent confirmation',
        ),
      );
    }
  }

  if (_hasGardenPressureLanguage(text)) {
    violations.add(
      _caseViolation(
        contractCase,
        ActivationGovernorContractViolationType.gardenMemory,
        'Garden Memory cannot use checklist, streak, score, growth, reward, unlock, progress, or punishment semantics',
      ),
    );
  }

  return _dedupeCaseViolations(violations);
}

void _scanRuntimeSourceFile(
  File dartFile,
  String sourcePath,
  List<ActivationGovernorContractViolation> violations,
) {
  final lines = dartFile.readAsLinesSync();
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final lineNumber = lineIndex + 1;
    final line = lines[lineIndex];
    if (_hasActivationIntent(line) && !_lineMentionsGovernorDecision(line)) {
      violations.add(
        ActivationGovernorContractViolation(
          type: ActivationGovernorContractViolationType.sourceScan,
          sourcePath: sourcePath,
          lineNumber: lineNumber,
          reason:
              'mobile_v2/lib activation-intent copy must mention a Governor decision or stay outside runtime truth',
        ),
      );
    }

    if (_hasGardenPressureLanguage(line)) {
      violations.add(
        ActivationGovernorContractViolation(
          type: ActivationGovernorContractViolationType.sourceScan,
          sourcePath: sourcePath,
          lineNumber: lineNumber,
          reason:
              'mobile_v2/lib cannot introduce Garden checklist, streak, score, growth, reward, unlock, progress, or punishment semantics',
        ),
      );
    }

    for (final name in _suspiciousAuthorityNames) {
      if (_lineContainsTerm(line, name) &&
          !_lineMentionsGovernorDecision(line) &&
          !line.contains('ParentConfirmation')) {
        violations.add(
          ActivationGovernorContractViolation(
            type: ActivationGovernorContractViolationType.sourceScan,
            sourcePath: sourcePath,
            lineNumber: lineNumber,
            term: name,
            reason:
                'suspicious authority name requires an allowed Governor or Garden parent-confirmation boundary',
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

ActivationGovernorContractViolation _caseViolation(
  ActivationGovernorContractCase contractCase,
  ActivationGovernorContractViolationType type,
  String reason,
) =>
    ActivationGovernorContractViolation(
      type: type,
      sourcePath: 'typed-contract-cases',
      lineNumber: 0,
      caseId: contractCase.id,
      reason: reason,
    );

List<ActivationGovernorContractViolation> _dedupeCaseViolations(
  List<ActivationGovernorContractViolation> violations,
) {
  final seen = <String>{};
  final deduped = <ActivationGovernorContractViolation>[];
  for (final violation in violations) {
    final key =
        '${violation.type.label}|${violation.caseId}|${violation.reason}';
    if (seen.add(key)) {
      deduped.add(violation);
    }
  }
  return deduped;
}

bool _hasActivationIntent(String text) =>
    _activationIntentPatterns.any((pattern) => pattern.hasMatch(text));

bool _hasGardenPressureLanguage(String text) =>
    _gardenPressurePatterns.any((pattern) => pattern.hasMatch(text));

bool _lineMentionsGovernorDecision(String line) {
  final normalized = _normalizeToken(line);
  return normalized.contains('activationgovernor') ||
      normalized.contains('allowactivation') ||
      normalized.contains('allow_activation');
}

bool _isGovernor(String token) =>
    token == 'activationgovernor' || token == 'governor';

bool _isPackGraph(String token) =>
    token == 'packgraph' || token == 'pack' || token == 'graph';

bool _isMeaningfulGardenStateAction(String gardenAction) =>
    gardenAction == 'set_familiar' ||
    gardenAction == 'set_resting' ||
    gardenAction == 'set_belongs_to_family' ||
    gardenAction == 'belongs_to_family' ||
    gardenAction == 'family_transfer';

bool _lineContainsTerm(String line, String term) {
  final pattern = RegExp(
    '(?<![A-Za-z0-9_])${RegExp.escape(term)}(?![A-Za-z0-9_])',
  );
  return pattern.hasMatch(line);
}

bool _isGeneratedDartFile(String path) =>
    path.endsWith('.g.dart') || path.endsWith('.freezed.dart');

int _compareViolation(
  ActivationGovernorContractViolation left,
  ActivationGovernorContractViolation right,
) {
  final pathComparison = left.sourcePath.compareTo(right.sourcePath);
  if (pathComparison != 0) {
    return pathComparison;
  }
  final lineComparison = left.lineNumber.compareTo(right.lineNumber);
  if (lineComparison != 0) {
    return lineComparison;
  }
  final caseComparison = (left.caseId ?? '').compareTo(right.caseId ?? '');
  if (caseComparison != 0) {
    return caseComparison;
  }
  return left.type.label.compareTo(right.type.label);
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

String _normalizeToken(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');

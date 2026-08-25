import 'dart:io';

const customSceneProductionReleaseGateSuccessMarker =
    'Custom-scene production default release gate verified.';

const _mobileFeatureFlagPath =
    'mobile/lib/features/custom_scene/application/custom_scene_feature_flag.dart';
const _productionValuesPath = 'deploy/helm/babytalk-app/values-production.yaml';
const _practiceAiTemplatePath =
    'deploy/helm/babytalk-app/templates/practice-ai-configmap.yaml';
const _mobileBuildWorkflowPath = '.github/workflows/mobile-build.yml';

class CustomSceneProductionGateViolation {
  const CustomSceneProductionGateViolation({
    required this.rule,
    required this.sourcePath,
    required this.lineNumber,
    required this.detail,
  });

  final String rule;
  final String sourcePath;
  final int lineNumber;
  final String detail;

  @override
  String toString() => '$rule $sourcePath:$lineNumber | $detail';
}

class CustomSceneProductionGateReport {
  const CustomSceneProductionGateReport({required this.violations});

  final List<CustomSceneProductionGateViolation> violations;

  bool get passes => violations.isEmpty;
}

CustomSceneProductionGateReport scanCustomSceneProductionReleaseGate({
  String? projectRoot,
}) {
  final root = _normalize(projectRoot ?? Directory.current.path);
  final violations = <CustomSceneProductionGateViolation>[];

  final mobileFeatureFlag = _readRequired(
    root,
    _mobileFeatureFlagPath,
    violations,
  );
  if (mobileFeatureFlag != null) {
    _scanMobileFeatureFlag(mobileFeatureFlag, violations);
  }

  final productionValues = _readRequired(
    root,
    _productionValuesPath,
    violations,
  );
  if (productionValues != null) {
    _scanProductionValues(productionValues, violations);
  }

  final practiceAiTemplate = _readRequired(
    root,
    _practiceAiTemplatePath,
    violations,
  );
  if (practiceAiTemplate != null) {
    _scanPracticeAiTemplate(practiceAiTemplate, violations);
  }

  final mobileBuildWorkflow = _readRequired(
    root,
    _mobileBuildWorkflowPath,
    violations,
  );
  if (mobileBuildWorkflow != null) {
    _scanMobileBuildWorkflow(mobileBuildWorkflow, violations);
  }

  violations.sort((left, right) {
    final path = left.sourcePath.compareTo(right.sourcePath);
    if (path != 0) return path;
    final line = left.lineNumber.compareTo(right.lineNumber);
    if (line != 0) return line;
    return left.rule.compareTo(right.rule);
  });
  return CustomSceneProductionGateReport(
    violations: List.unmodifiable(violations),
  );
}

String renderCustomSceneProductionReleaseGateReport(
  CustomSceneProductionGateReport report,
) {
  final buffer = StringBuffer()
    ..writeln(
      'custom_scene_production_release_gate_status=${report.passes ? 'pass' : 'fail'}',
    )
    ..writeln('violations=${report.violations.length}');
  if (report.violations.isEmpty) {
    buffer.writeln('  none');
  } else {
    for (final violation in report.violations) {
      buffer.writeln('  $violation');
    }
  }
  return buffer.toString();
}

String? _readRequired(
  String root,
  String relativePath,
  List<CustomSceneProductionGateViolation> violations,
) {
  final file = File('$root/$relativePath');
  if (!file.existsSync()) {
    violations.add(
      CustomSceneProductionGateViolation(
        rule: 'required_source',
        sourcePath: relativePath,
        lineNumber: 0,
        detail: 'required production release source is missing',
      ),
    );
    return null;
  }
  try {
    return file.readAsStringSync();
  } on FileSystemException {
    violations.add(
      CustomSceneProductionGateViolation(
        rule: 'required_source',
        sourcePath: relativePath,
        lineNumber: 0,
        detail: 'required production release source cannot be read',
      ),
    );
    return null;
  }
}

void _scanMobileFeatureFlag(
  String source,
  List<CustomSceneProductionGateViolation> violations,
) {
  final defaultPattern = RegExp(
    r'''bool\.fromEnvironment\s*\(\s*['"]BABY_TALK_CUSTOM_SCENE_ENABLED['"]\s*,\s*defaultValue\s*:\s*true\s*,?\s*\)''',
    dotAll: true,
  );
  if (!defaultPattern.hasMatch(source)) {
    _add(
      violations,
      'mobile_default_enabled',
      _mobileFeatureFlagPath,
      source,
      'production mobile flag must default BABY_TALK_CUSTOM_SCENE_ENABLED to true',
    );
  }
  if (RegExp(r'defaultValue\s*:\s*false').hasMatch(source)) {
    _add(
      violations,
      'mobile_default_enabled',
      _mobileFeatureFlagPath,
      source,
      'production mobile flag must not retain a false default',
    );
  }
}

void _scanProductionValues(
  String source,
  List<CustomSceneProductionGateViolation> violations,
) {
  final clean = _withoutYamlComments(source);
  final practiceAi = _topLevelSection(clean, 'practiceAi');
  if (practiceAi == null) {
    _add(
      violations,
      'production_helm_profile',
      _productionValuesPath,
      source,
      'production values must define practiceAi',
    );
    return;
  }

  _requireSectionLine(
    practiceAi,
    'providerMode',
    'agentic',
    'production Practice AI provider mode must be agentic',
    violations,
  );
  _requireSectionLine(
    practiceAi,
    'routingPolicyVersion',
    'custom-scene-routing-v1',
    'production custom-scene routing policy must be pinned',
    violations,
  );
  _requireSectionLine(
    practiceAi,
    'custom-scene-generator',
    '[dashscope-qwen]',
    'production generator route must use dashscope-qwen',
    violations,
  );
  _requireSectionLine(
    practiceAi,
    'custom-scene-quality-judge',
    '[dashscope-qwen]',
    'production quality-judge route must use dashscope-qwen',
    violations,
  );
  _requireSectionLine(
    practiceAi,
    'custom-scene-repair',
    '[dashscope-qwen]',
    'production repair route must use dashscope-qwen',
    violations,
  );
  _requireSectionLine(
    practiceAi,
    'existingSecret',
    'babytalk-practice-ai',
    'production Practice AI credentials must use dedicated external Secret',
    violations,
  );
  final rollout = RegExp(
    r'''^\s*rolloutVersion:\s*['"]?[^\s#'"]+['"]?\s*$''',
    multiLine: true,
  );
  if (!rollout.hasMatch(practiceAi)) {
    _add(
      violations,
      'production_secret_rollout',
      _productionValuesPath,
      source,
      'production Practice AI Secret rotation must have a non-empty rolloutVersion',
    );
  }
  if (RegExp(
    r'^\s*springProfilesActive:\s*dev\s*$',
    multiLine: true,
  ).hasMatch(practiceAi)) {
    _add(
      violations,
      'production_profile_safety',
      _productionValuesPath,
      source,
      'production custom-scene runtime must not activate the dev Spring profile',
    );
  }
}

void _scanPracticeAiTemplate(
  String source,
  List<CustomSceneProductionGateViolation> violations,
) {
  if (!source.contains('enabled: {{ eq \$providerMode "agentic" }}')) {
    _add(
      violations,
      'backend_runtime_enabled',
      _practiceAiTemplatePath,
      source,
      'agentic production provider mode must render custom-scene enabled=true',
    );
  }
}

void _scanMobileBuildWorkflow(
  String source,
  List<CustomSceneProductionGateViolation> violations,
) {
  if (!source.contains('flutter build apk --release') ||
      !source.contains('flutter build appbundle --release')) {
    _add(
      violations,
      'mobile_release_build',
      _mobileBuildWorkflowPath,
      source,
      'production mobile workflow must build release APK and AAB',
    );
  }
  if (RegExp(
    r'--dart-define\s*=\s*BABY_TALK_CUSTOM_SCENE_ENABLED\s*=\s*false',
  ).hasMatch(source)) {
    _add(
      violations,
      'mobile_release_build',
      _mobileBuildWorkflowPath,
      source,
      'production mobile workflow must not disable custom-scene entry',
    );
  }
}

String? _topLevelSection(String source, String key) {
  final lines = source.split(RegExp(r'\r?\n'));
  var start = -1;
  for (var index = 0; index < lines.length; index += 1) {
    if (lines[index] == '$key:') {
      start = index;
      break;
    }
  }
  if (start < 0) return null;
  final section = <String>[lines[start]];
  for (var index = start + 1; index < lines.length; index += 1) {
    final line = lines[index];
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
      break;
    }
    section.add(line);
  }
  return section.join('\n');
}

void _requireSectionLine(
  String section,
  String key,
  String expectedValue,
  String detail,
  List<CustomSceneProductionGateViolation> violations,
) {
  final pattern = RegExp(
    '^\\s*${RegExp.escape(key)}:\\s*${RegExp.escape(expectedValue)}\\s*(?:#.*)?\$',
    multiLine: true,
  );
  if (!pattern.hasMatch(section)) {
    _add(
      violations,
      'production_helm_profile',
      _productionValuesPath,
      section,
      detail,
    );
  }
}

String _withoutYamlComments(String source) => source
    .split(RegExp(r'\r?\n'))
    .map((line) => line.trimLeft().startsWith('#') ? '' : line)
    .join('\n');

void _add(
  List<CustomSceneProductionGateViolation> violations,
  String rule,
  String sourcePath,
  String source,
  String detail,
) {
  violations.add(
    CustomSceneProductionGateViolation(
      rule: rule,
      sourcePath: sourcePath,
      lineNumber: _firstLineContaining(source, detail),
      detail: detail,
    ),
  );
}

int _firstLineContaining(String source, String value) {
  final lines = source.split(RegExp(r'\r?\n'));
  for (var index = 0; index < lines.length; index += 1) {
    if (lines[index].contains(value)) return index + 1;
  }
  return 0;
}

String _normalize(String value) => value.replaceAll('\\', '/');

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    stderr.writeln(
      'Usage: dart tool/verify_custom_scene_production_release.dart',
    );
    exitCode = 64;
    return;
  }
  final report = scanCustomSceneProductionReleaseGate();
  stdout.write(renderCustomSceneProductionReleaseGateReport(report));
  if (!report.passes) {
    exitCode = 1;
    return;
  }
  stdout.writeln(customSceneProductionReleaseGateSuccessMarker);
}

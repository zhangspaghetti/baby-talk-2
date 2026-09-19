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
    'custom-scene-safety-classifier',
    '[dashscope-qwen]',
    'production safety classifier route must use dashscope-qwen',
    violations,
  );
  _scanSafetyClassifierProvider(practiceAi, violations);
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

void _scanSafetyClassifierProvider(
  String section,
  List<CustomSceneProductionGateViolation> violations,
) {
  final routeValue = _sectionValue(section, 'custom-scene-safety-classifier');
  if (routeValue == null) {
    return;
  }
  final providerNames = _inlineProviderNames(routeValue);
  if (providerNames.isEmpty) {
    return;
  }

  final providerMap = _parseProviderMap(section);
  if (!providerMap.present) {
    _add(
      violations,
      'production_safety_provider',
      _productionValuesPath,
      section,
      'production safety classifier provider map must define providers',
    );
    return;
  }

  for (final providerName in providerNames) {
    final definition = providerMap.definitions[providerName];
    if (definition == null) {
      _add(
        violations,
        'production_safety_provider',
        _productionValuesPath,
        section,
        'production safety classifier route must reference a defined provider',
      );
      continue;
    }
    _validateSafetyProviderDefinition(definition, section, violations);
  }
}

void _validateSafetyProviderDefinition(
  Map<String, String> definition,
  String section,
  List<CustomSceneProductionGateViolation> violations,
) {
  const allowedFields = <String>{
    'type',
    'baseUrl',
    'apiKeyEnvironmentVariable',
    'model',
    'timeout',
    'maxTokens',
    'maxCompletionTokens',
    'temperature',
  };
  for (final field in definition.keys) {
    if (!allowedFields.contains(field)) {
      _add(
        violations,
        'production_safety_provider',
        _productionValuesPath,
        section,
        'production safety classifier provider has unsupported field',
      );
    }
  }
  if (definition['type'] != 'openai-compatible') {
    _add(
      violations,
      'production_safety_provider',
      _productionValuesPath,
      section,
      'production safety classifier provider must use openai-compatible type',
    );
  }
  if (!RegExp(r'^https?://[^\s]+$').hasMatch(definition['baseUrl'] ?? '')) {
    _add(
      violations,
      'production_safety_provider',
      _productionValuesPath,
      section,
      'production safety classifier provider must define an HTTP baseUrl',
    );
  }
  if (!RegExp(
    r'^BABY_TALK_AI_PROVIDER_[A-Z0-9_]+_API_KEY$',
  ).hasMatch(definition['apiKeyEnvironmentVariable'] ?? '')) {
    _add(
      violations,
      'production_safety_provider',
      _productionValuesPath,
      section,
      'production safety classifier provider must define a dedicated API key environment variable',
    );
  }
  if ((definition['model'] ?? '').trim().isEmpty) {
    _add(
      violations,
      'production_safety_provider',
      _productionValuesPath,
      section,
      'production safety classifier provider must define a model',
    );
  }
  if (!RegExp(
    r'^[1-9][0-9]*(ms|s|m|h)$',
  ).hasMatch(definition['timeout'] ?? '')) {
    _add(
      violations,
      'production_safety_provider',
      _productionValuesPath,
      section,
      'production safety classifier provider timeout must be positive',
    );
  }

  final hasMaxTokens = definition.containsKey('maxTokens');
  final hasMaxCompletionTokens = definition.containsKey('maxCompletionTokens');
  if (hasMaxTokens == hasMaxCompletionTokens) {
    _add(
      violations,
      'production_safety_provider',
      _productionValuesPath,
      section,
      'production safety classifier provider must set exactly one token limit',
    );
  } else {
    final tokenLimit = hasMaxTokens
        ? definition['maxTokens']
        : definition['maxCompletionTokens'];
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(tokenLimit ?? '')) {
      _add(
        violations,
        'production_safety_provider',
        _productionValuesPath,
        section,
        'production safety classifier provider token limit must be positive',
      );
    }
  }
}

String? _sectionValue(String section, String key) {
  final pattern = RegExp(
    '^\\s*${RegExp.escape(key)}:\\s*(.*?)\\s*\$',
    multiLine: true,
  );
  return pattern.firstMatch(section)?.group(1);
}

List<String> _inlineProviderNames(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
    return const <String>[];
  }
  return trimmed
      .substring(1, trimmed.length - 1)
      .split(',')
      .map((name) => _unquoteYamlValue(name.trim()))
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
}

_ParsedProviderMap _parseProviderMap(String section) {
  final lines = section.split(RegExp(r'\r?\n'));
  var providersIndent = -1;
  var providersIndex = -1;
  var present = false;
  for (var index = 0; index < lines.length; index += 1) {
    final rawLine = lines[index];
    final line = rawLine.trim();
    if (line.startsWith('providers:')) {
      providersIndent = rawLine.length - rawLine.trimLeft().length;
      providersIndex = index;
      present = true;
      break;
    }
  }
  if (!present) {
    return const _ParsedProviderMap(
      present: false,
      definitions: <String, Map<String, String>>{},
    );
  }

  final definitions = <String, Map<String, String>>{};
  String? providerName;
  for (var index = providersIndex + 1; index < lines.length; index += 1) {
    final rawLine = lines[index];
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final indent = rawLine.length - rawLine.trimLeft().length;
    if (indent <= providersIndent) {
      break;
    }
    if (indent == providersIndent + 2 && line.endsWith(':')) {
      providerName = line.substring(0, line.length - 1).trim();
      definitions.putIfAbsent(providerName, () => <String, String>{});
      continue;
    }
    if (providerName != null && indent == providersIndent + 4) {
      final match = RegExp(
        r'^([A-Za-z][A-Za-z0-9-]*):\s*(.*)$',
      ).firstMatch(line);
      if (match != null) {
        definitions[providerName]![match.group(1)!] = _unquoteYamlValue(
          match.group(2)!,
        );
      }
    }
  }
  return _ParsedProviderMap(present: true, definitions: definitions);
}

String _unquoteYamlValue(String value) {
  final withoutComment = value.split('#').first.trim();
  if (withoutComment.length >= 2 &&
      ((withoutComment.startsWith('"') && withoutComment.endsWith('"')) ||
          (withoutComment.startsWith("'") && withoutComment.endsWith("'")))) {
    return withoutComment.substring(1, withoutComment.length - 1);
  }
  return withoutComment;
}

class _ParsedProviderMap {
  const _ParsedProviderMap({required this.present, required this.definitions});

  final bool present;
  final Map<String, Map<String, String>> definitions;
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

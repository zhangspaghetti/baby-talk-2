import 'dart:io';

const _runtimeFileName = 'practice-ai-runtime.yml';
const _runtimeMountPath = '/config/practice-ai-runtime.yml';
const _requiredCapabilities = <String>{
  'custom-scene-generator',
  'custom-scene-quality-judge',
  'custom-scene-repair',
};
const _ownerKeySecretEnvironmentVariable =
    'BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET';
const _agenticRenderOwnerKeyPlaceholder =
    'm2-public-agentic-owner-key-placeholder-0123456789';
const _safeMinimumCompleteBundleOutputTokens = 8192;
const _minimumCompleteBundleProviderTimeout = Duration(seconds: 120);

enum PracticeAiHelmProfile { disabledDefault, kindFake, agenticQa, production }

extension on PracticeAiHelmProfile {
  String get providerMode => switch (this) {
    PracticeAiHelmProfile.disabledDefault => 'disabled',
    PracticeAiHelmProfile.kindFake => 'fake',
    PracticeAiHelmProfile.agenticQa ||
    PracticeAiHelmProfile.production => 'agentic',
  };

  bool get needsAgenticRoutes => switch (this) {
    PracticeAiHelmProfile.agenticQa || PracticeAiHelmProfile.production => true,
    PracticeAiHelmProfile.disabledDefault ||
    PracticeAiHelmProfile.kindFake => false,
  };

  bool get needsDevProfile => this == PracticeAiHelmProfile.kindFake;

  bool get needsRenderedDedicatedSecret =>
      this == PracticeAiHelmProfile.agenticQa;
}

class PracticeAiHelmVerificationException implements Exception {
  PracticeAiHelmVerificationException(this.message);

  final String message;

  @override
  String toString() => 'Practice AI Helm verification failed: $message';
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    stderr.writeln('Usage: dart run tool/verify_practice_ai_helm.dart');
    exitCode = 64;
    return;
  }

  try {
    await verifyPracticeAiHelmRepository(Directory.current.path);
    stdout.writeln('Practice AI Helm verification passed.');
  } on PracticeAiHelmVerificationException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<void> verifyPracticeAiHelmRepository(String repositoryRoot) async {
  final root = Directory(repositoryRoot);
  final appYaml = File(
    '${root.path}${Platform.pathSeparator}backend${Platform.pathSeparator}app-api${Platform.pathSeparator}src${Platform.pathSeparator}main${Platform.pathSeparator}resources${Platform.pathSeparator}application.yml',
  );
  if (!appYaml.existsSync()) {
    _fail('Missing backend app-api application.yml.');
  }
  verifyBundledApplicationYaml(appYaml.readAsStringSync());

  const chart = 'deploy/helm/babytalk-app';
  final renders =
      <
        ({
          PracticeAiHelmProfile profile,
          List<String> values,
          Set<String> forbidden,
        })
      >[
        (
          profile: PracticeAiHelmProfile.disabledDefault,
          values: const <String>[],
          forbidden: const <String>{},
        ),
        (
          profile: PracticeAiHelmProfile.kindFake,
          values: const <String>['deploy/helm/babytalk-app/values-kind.yaml'],
          forbidden: const <String>{},
        ),
        (
          profile: PracticeAiHelmProfile.agenticQa,
          values: const <String>[
            'deploy/helm/babytalk-app/values-kind-qa.yaml',
          ],
          forbidden: const <String>{'change-me-kind-qa-practice-ai-api-key'},
        ),
        (
          profile: PracticeAiHelmProfile.production,
          values: const <String>[
            'deploy/helm/babytalk-app/values-production.yaml',
          ],
          forbidden: const <String>{},
        ),
      ];

  for (final render in renders) {
    await _verifyPracticeAiHelmRender(
      root: root,
      chart: chart,
      profile: render.profile,
      values: render.values,
      forbiddenCredentialValues: render.forbidden,
    );
  }
}

Future<void> _verifyPracticeAiHelmRender({
  required Directory root,
  required String chart,
  required PracticeAiHelmProfile profile,
  required List<String> values,
  required Set<String> forbiddenCredentialValues,
}) async {
  final result = await Process.run(
    'helm',
    <String>[
      'template',
      'practice-ai-verify',
      chart,
      ...values.expand((path) => <String>['-f', path]),
      if (profile.needsAgenticRoutes) ...<String>[
        '--set-string',
        'secret.$_ownerKeySecretEnvironmentVariable='
            '$_agenticRenderOwnerKeyPlaceholder',
      ],
    ],
    workingDirectory: root.path,
    runInShell: false,
  );
  if (result.exitCode != 0) {
    _fail(
      'helm template for ${profile.name} failed: '
      '${_trimOutput('${result.stdout}\n${result.stderr}')}',
    );
  }
  final renderedForbiddenCredentialValues = <String>{
    ...forbiddenCredentialValues,
    if (profile.needsAgenticRoutes) _agenticRenderOwnerKeyPlaceholder,
  };
  verifyRenderedPracticeAiManifest(
    result.stdout as String,
    profile: profile,
    forbiddenCredentialValues: renderedForbiddenCredentialValues,
  );
}

void verifyBundledApplicationYaml(String yaml) {
  final lines = yaml
      .split(RegExp(r'\r?\n'))
      .map(_stripYamlComment)
      .toList(growable: false);
  int? appIndent;
  int? appChildIndent;

  for (var index = 0; index < lines.length; index++) {
    final rawLine = lines[index];
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line == '---' || line == '...') {
      appIndent = null;
      appChildIndent = null;
      continue;
    }

    final indent = rawLine.length - rawLine.trimLeft().length;
    if (indent == 0 && line.startsWith('{')) {
      if (_flowMappingDefinesPath(
        lines.sublist(index).join('\n'),
        const <String>['app', 'ai'],
      )) {
        _failBundledApplicationRegistry();
      }
      appIndent = null;
      appChildIndent = null;
      continue;
    }

    final entry = _yamlMappingEntry(line);
    if (indent == 0) {
      appIndent = null;
      appChildIndent = null;
      if (entry == null) {
        continue;
      }
      if (_keyDefinesPath(entry.$1, const <String>['app', 'ai'])) {
        _failBundledApplicationRegistry();
      }
      if (entry.$1 != 'app') {
        continue;
      }

      final value = _stripYamlDecorators(entry.$2);
      if (value.startsWith('*')) {
        _failBundledApplicationRegistry();
      }
      if (value.startsWith('{') &&
          _flowMappingDefinesPath(
            <String>[value, ...lines.sublist(index + 1)].join('\n'),
            const <String>['ai'],
          )) {
        _failBundledApplicationRegistry();
      }
      if (value.isEmpty ||
          RegExp(r'^(?:[!&][^\s]+\s*)+$').hasMatch(entry.$2.trim())) {
        appIndent = indent;
      }
      continue;
    }

    if (appIndent == null) {
      continue;
    }
    if (indent <= appIndent) {
      appIndent = null;
      appChildIndent = null;
      continue;
    }
    if (entry == null) {
      continue;
    }
    appChildIndent ??= indent;
    if (indent < appChildIndent) {
      appChildIndent = indent;
    }
    if (indent == appChildIndent &&
        (entry.$1 == '<<' || _keyDefinesPath(entry.$1, const <String>['ai']))) {
      _failBundledApplicationRegistry();
    }
  }
}

Never _failBundledApplicationRegistry() => _fail(
  'Bundled application.yml must not define app.ai providers or routes; '
  'the mounted practice-ai-runtime.yml is the only registry source.',
);

String _stripYamlComment(String line) {
  String? quote;
  var escaped = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quote == '"' && character == r'\') {
      escaped = true;
      continue;
    }
    if (quote != null) {
      if (character == quote) {
        if (quote == "'" && index + 1 < line.length && line[index + 1] == "'") {
          index++;
        } else {
          quote = null;
        }
      }
      continue;
    }
    if (character == '"' || character == "'") {
      quote = character;
      continue;
    }
    if (character == '#') {
      return line.substring(0, index);
    }
  }
  return line;
}

(String, String)? _yamlMappingEntry(String line) {
  final colon = _topLevelColon(line);
  if (colon < 0) {
    return null;
  }
  final key = _yamlKey(line.substring(0, colon));
  if (key.isEmpty) {
    return null;
  }
  return (key, line.substring(colon + 1).trim());
}

String _stripYamlDecorators(String value) {
  var result = value.trimLeft();
  while (true) {
    final decorator = RegExp(
      r'^(?:![^\s]+|&[^\s]+)(?:\s+|$)',
    ).firstMatch(result);
    if (decorator == null) {
      return result;
    }
    result = result.substring(decorator.end).trimLeft();
  }
}

bool _flowMappingDefinesPath(String source, List<String> path) {
  final trimmed = source.trimLeft();
  if (!trimmed.startsWith('{')) {
    return false;
  }
  final closingBrace = _matchingFlowBrace(trimmed);
  if (closingBrace < 0) {
    return false;
  }
  final body = trimmed.substring(1, closingBrace);
  for (final item in _splitTopLevelFlowItems(body)) {
    final entry = _yamlMappingEntry(item.trim());
    if (entry == null) {
      continue;
    }
    if (entry.$1 == '<<') {
      return true;
    }
    if (_keyDefinesPath(entry.$1, path)) {
      return true;
    }
    if (entry.$1 != path.first || path.length == 1) {
      continue;
    }
    final value = _stripYamlDecorators(entry.$2);
    if (value.startsWith('*')) {
      return true;
    }
    if (_flowMappingDefinesPath(value, path.sublist(1))) {
      return true;
    }
  }
  return false;
}

bool _keyDefinesPath(String key, List<String> path) {
  final dottedPath = path.join('.');
  return key == dottedPath || key.startsWith('$dottedPath.');
}

int _matchingFlowBrace(String source) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quote == '"' && character == r'\') {
      escaped = true;
      continue;
    }
    if (quote != null) {
      if (character == quote) {
        if (quote == "'" &&
            index + 1 < source.length &&
            source[index + 1] == "'") {
          index++;
        } else {
          quote = null;
        }
      }
      continue;
    }
    if (character == '"' || character == "'") {
      quote = character;
      continue;
    }
    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) {
        return index;
      }
    }
  }
  return -1;
}

List<String> _splitTopLevelFlowItems(String source) {
  final items = <String>[];
  var start = 0;
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quote == '"' && character == r'\') {
      escaped = true;
      continue;
    }
    if (quote != null) {
      if (character == quote) {
        if (quote == "'" &&
            index + 1 < source.length &&
            source[index + 1] == "'") {
          index++;
        } else {
          quote = null;
        }
      }
      continue;
    }
    if (character == '"' || character == "'") {
      quote = character;
      continue;
    }
    if (character == '{' || character == '[') {
      depth++;
    } else if (character == '}' || character == ']') {
      depth--;
    } else if (character == ',' && depth == 0) {
      items.add(source.substring(start, index));
      start = index + 1;
    }
  }
  items.add(source.substring(start));
  return items;
}

int _topLevelColon(String source) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quote == '"' && character == r'\') {
      escaped = true;
      continue;
    }
    if (quote != null) {
      if (character == quote) {
        if (quote == "'" &&
            index + 1 < source.length &&
            source[index + 1] == "'") {
          index++;
        } else {
          quote = null;
        }
      }
      continue;
    }
    if (character == '"' || character == "'") {
      quote = character;
      continue;
    }
    if (character == '{' || character == '[') {
      depth++;
    } else if (character == '}' || character == ']') {
      depth--;
    } else if (character == ':' && depth == 0) {
      return index;
    }
  }
  return -1;
}

String _yamlKey(String source) {
  final key = _stripYamlDecorators(source.trim());
  if (key.length >= 2 && key.startsWith("'") && key.endsWith("'")) {
    return key.substring(1, key.length - 1).replaceAll("''", "'");
  }
  if (key.length >= 2 && key.startsWith('"') && key.endsWith('"')) {
    return key.substring(1, key.length - 1);
  }
  return key;
}

void verifyRenderedPracticeAiManifest(
  String manifest, {
  required PracticeAiHelmProfile profile,
  Set<String> forbiddenCredentialValues = const <String>{},
}) {
  final documents = _splitDocuments(manifest);
  final runtimeDocuments = documents
      .where(
        (document) =>
            _kindOf(document) == 'ConfigMap' &&
            document.contains('$_runtimeFileName: |'),
      )
      .toList(growable: false);
  if (runtimeDocuments.length != 1) {
    _fail('Expected exactly one $_runtimeFileName ConfigMap.');
  }

  final runtimeDocument = runtimeDocuments.single;
  final runtimeConfigMapName = _metadataName(runtimeDocument);
  if (runtimeConfigMapName == null || runtimeConfigMapName.isEmpty) {
    _fail('Practice AI runtime ConfigMap has no metadata.name.');
  }
  final runtimeYaml = _runtimeYaml(runtimeDocument);
  _verifyCustomSceneProviderMode(runtimeYaml, profile);
  final runtime = _parseRuntimeConfiguration(runtimeYaml);
  _verifyRuntime(runtime, profile);

  final appApiDocuments = documents
      .where(
        (document) =>
            _kindOf(document) == 'Deployment' &&
            RegExp(
              r'^    app\.kubernetes\.io/component: app-api\s*$',
              multiLine: true,
            ).hasMatch(document),
      )
      .toList(growable: false);
  if (appApiDocuments.length != 1) {
    _fail('Expected exactly one app-api Deployment.');
  }
  final appApi = appApiDocuments.single;
  _verifyRuntimeMount(appApi, runtimeConfigMapName, profile);
  _verifyAgenticOwnerKeySecret(documents, appApi, profile);

  _verifyCredentialIsolation(
    documents,
    appApi: appApi,
    providerEnvironmentVariables: runtime.providers.values
        .map((provider) => provider.apiKeyEnvironmentVariable)
        .toSet(),
    profile: profile,
  );
  _verifyNoPlaintextCredentialLeak(documents, forbiddenCredentialValues);
}

void _verifyAgenticOwnerKeySecret(
  List<String> documents,
  String appApi,
  PracticeAiHelmProfile profile,
) {
  if (!profile.needsAgenticRoutes) {
    if (documents.any(
      (document) => document.contains(_ownerKeySecretEnvironmentVariable),
    )) {
      _fail(
        'Non-agentic manifests must not render $_ownerKeySecretEnvironmentVariable.',
      );
    }
    return;
  }

  final ownerKeyReferences = RegExp(
    '^\\s*- name: ${RegExp.escape(_ownerKeySecretEnvironmentVariable)}\\s*\\r?\\n'
    r'\s*valueFrom:\s*\r?\n'
    r'\s*secretKeyRef:\s*\r?\n'
    r'\s*name: ([^\s#]+)\s*\r?\n'
    '^\\s*key: ${RegExp.escape(_ownerKeySecretEnvironmentVariable)}\\s*\$',
    multiLine: true,
  ).allMatches(appApi).toList(growable: false);
  if (ownerKeyReferences.length != 1) {
    _fail(
      'Agentic app-api must map $_ownerKeySecretEnvironmentVariable from one dedicated Secret.',
    );
  }
  final ownerKeySecretName = ownerKeyReferences.single.group(1)!;
  if (RegExp(
    '^\\s*- secretRef:\s*\\r?\\n\\s*name: ${RegExp.escape(ownerKeySecretName)}\\s*\$',
    multiLine: true,
  ).hasMatch(appApi)) {
    _fail(
      'Agentic app-api must not use envFrom for $_ownerKeySecretEnvironmentVariable.',
    );
  }
  final ownerKeySecretDocuments = documents
      .where(
        (document) =>
            _kindOf(document) == 'Secret' &&
            _metadataName(document) == ownerKeySecretName,
      )
      .toList(growable: false);
  if (ownerKeySecretDocuments.length != 1) {
    _fail(
      'Agentic owner-key Secret $ownerKeySecretName must render exactly once.',
    );
  }
  final ownerKeySecret = ownerKeySecretDocuments.single;
  if (!RegExp(
    '^  ${RegExp.escape(_ownerKeySecretEnvironmentVariable)}: '
    '(?:[A-Za-z0-9+/]+={0,2}|"[A-Za-z0-9+/]+={0,2}")\\s*\$',
    multiLine: true,
  ).hasMatch(ownerKeySecret)) {
    _fail(
      'Agentic owner-key Secret must render $_ownerKeySecretEnvironmentVariable.',
    );
  }
  for (final document in documents.where(
    (document) => document != appApi && document != ownerKeySecret,
  )) {
    if (document.contains(_ownerKeySecretEnvironmentVariable) ||
        document.contains(ownerKeySecretName)) {
      final kind = _kindOf(document) ?? 'unknown';
      final name = _metadataName(document) ?? 'unnamed';
      _fail(
        '$_ownerKeySecretEnvironmentVariable must not appear outside '
        'app-api and Secret/$ownerKeySecretName; found on $kind/$name.',
      );
    }
  }
}

void _verifyCustomSceneProviderMode(
  String runtimeYaml,
  PracticeAiHelmProfile profile,
) {
  final expectedProviderMode = RegExp(
    '^        provider-mode: "?${RegExp.escape(profile.providerMode)}"?\$',
    multiLine: true,
  );
  if (!expectedProviderMode.hasMatch(runtimeYaml)) {
    _fail(
      'practice-ai-runtime.yml must set custom-scene provider-mode '
      'to ${profile.providerMode}.',
    );
  }
  if (!profile.needsAgenticRoutes) {
    return;
  }

  final agenticRuntime = RegExp(
    r'^babytalk:\s*$\r?\n'
    r'^  practice:\s*$\r?\n'
    r'^    discovery:\s*$\r?\n'
    r'^      custom-scene:\s*$\r?\n'
    r'^        enabled: "?true"?\s*$\r?\n'
    r'^        provider-mode: "?agentic"?\s*$',
    multiLine: true,
  );
  if (!agenticRuntime.hasMatch(runtimeYaml)) {
    _fail(
      'Agentic practice-ai-runtime.yml must enable custom-scene discovery '
      'at babytalk.practice.discovery.custom-scene.',
    );
  }
}

void _verifyRuntime(
  _RuntimeConfiguration runtime,
  PracticeAiHelmProfile profile,
) {
  if (runtime.providers.isEmpty && profile.needsAgenticRoutes) {
    _fail('${profile.name} must configure named Practice AI providers.');
  }
  if (!profile.needsAgenticRoutes && runtime.providers.isNotEmpty) {
    _fail('${profile.name} must not configure network Practice AI providers.');
  }

  final providerEnvironmentVariables = <String>{};
  for (final provider in runtime.providers.values) {
    if (provider.type != 'openai-compatible') {
      _fail('Provider ${provider.name} has unsupported type ${provider.type}.');
    }
    if (provider.baseUrl == null || provider.baseUrl!.isEmpty) {
      _fail('Provider ${provider.name} has no base-url.');
    }
    if (!RegExp(
      r'^BABY_TALK_AI_PROVIDER_[A-Z0-9_]+_API_KEY$',
    ).hasMatch(provider.apiKeyEnvironmentVariable)) {
      _fail(
        'Provider ${provider.name} has an invalid dedicated API-key environment variable.',
      );
    }
    if (!providerEnvironmentVariables.add(provider.apiKeyEnvironmentVariable)) {
      _fail(
        'Duplicate provider API-key environment variable ${provider.apiKeyEnvironmentVariable}.',
      );
    }
    if (provider.model == null || provider.model!.isEmpty) {
      _fail('Provider ${provider.name} has no model.');
    }
    final providerTimeout = _parsePositiveProviderTimeout(provider.timeout);
    if (providerTimeout == null) {
      _fail('Provider ${provider.name} timeout must be positive.');
    }
    if (profile.needsAgenticRoutes &&
        providerTimeout! < _minimumCompleteBundleProviderTimeout) {
      _fail(
        'Provider ${provider.name} timeout must satisfy the complete-bundle '
        'minimum of ${_minimumCompleteBundleProviderTimeout.inSeconds}s.',
      );
    }
    final tokenFields = <String>[
      if (provider.values.containsKey('max-tokens')) 'max-tokens',
      if (provider.values.containsKey('max-completion-tokens'))
        'max-completion-tokens',
    ];
    if (tokenFields.length != 1) {
      _fail(
        'Provider ${provider.name} must set exactly one token limit field.',
      );
    }
    final tokenValue = provider.values[tokenFields.single];
    if (tokenValue == null || !RegExp(r'^[1-9][0-9]*$').hasMatch(tokenValue)) {
      _fail('Provider ${provider.name} token limit must be positive.');
    }
    if (profile.needsAgenticRoutes &&
        int.parse(tokenValue!) < _safeMinimumCompleteBundleOutputTokens) {
      _fail(
        'Provider ${provider.name} token limit must satisfy the safe '
        'complete-bundle minimum of $_safeMinimumCompleteBundleOutputTokens.',
      );
    }
    for (final field in provider.values.keys) {
      if (RegExp(
        r'(retry|attempt|backoff)',
        caseSensitive: false,
      ).hasMatch(field)) {
        _fail(
          'Provider ${provider.name} contains prohibited retry field $field.',
        );
      }
    }
  }

  for (final route in runtime.routes.entries) {
    if (!_requiredCapabilities.contains(route.key)) {
      _fail('Unknown Practice AI capability route ${route.key}.');
    }
    final seen = <String>{};
    for (final providerName in route.value) {
      if (!seen.add(providerName)) {
        _fail(
          'Capability route ${route.key} has duplicate provider $providerName.',
        );
      }
      if (!runtime.providers.containsKey(providerName)) {
        _fail(
          'Capability route ${route.key} references unknown provider $providerName.',
        );
      }
    }
  }

  if (profile.needsAgenticRoutes) {
    for (final capability in _requiredCapabilities) {
      final route = runtime.routes[capability];
      if (route == null || route.isEmpty) {
        _fail('${profile.name} must configure route $capability.');
      }
    }
    _verifyDashscopeQwenRuntime(runtime, profile);
  } else {
    for (final route in runtime.routes.entries) {
      if (route.value.isNotEmpty) {
        _fail(
          '${profile.name} must not route capability ${route.key} to a provider.',
        );
      }
    }
  }
}

void _verifyDashscopeQwenRuntime(
  _RuntimeConfiguration runtime,
  PracticeAiHelmProfile profile,
) {
  if (runtime.providers.length != 1 ||
      !runtime.providers.containsKey('dashscope-qwen')) {
    _fail('Agentic environments must use only named provider dashscope-qwen.');
  }
  final provider = runtime.providers['dashscope-qwen']!;
  final expected = <String, String>{
    'type': 'openai-compatible',
    'base-url': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'api-key-environment-variable':
        'BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY',
    'model': profile == PracticeAiHelmProfile.agenticQa
        ? 'glm-5.2'
        : 'qwen3.6-flash',
  };
  for (final entry in expected.entries) {
    if (provider.values[entry.key] != entry.value) {
      _fail('dashscope-qwen ${entry.key} must be ${entry.value}.');
    }
  }
  if (provider.values.containsKey('temperature')) {
    _fail('dashscope-qwen must omit temperature.');
  }
  for (final capability in _requiredCapabilities) {
    if (runtime.routes[capability]!.length != 1 ||
        runtime.routes[capability]!.single != 'dashscope-qwen') {
      _fail('$capability must route only to dashscope-qwen in order.');
    }
  }
}

Duration? _parsePositiveProviderTimeout(String? value) {
  final match = value == null
      ? null
      : RegExp(r'^([1-9][0-9]*)(ms|s|m|h)$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final amount = int.parse(match.group(1)!);
  return switch (match.group(2)!) {
    'ms' => Duration(milliseconds: amount),
    's' => Duration(seconds: amount),
    'm' => Duration(minutes: amount),
    'h' => Duration(hours: amount),
    _ => null,
  };
}

void _verifyRuntimeMount(
  String appApi,
  String runtimeConfigMapName,
  PracticeAiHelmProfile profile,
) {
  if (!RegExp(
    r'^\s*- name: SPRING_CONFIG_ADDITIONAL_LOCATION\s*\r?\n\s*value: "?'
    r'/config/practice-ai-runtime\.yml"?\s*$',
    multiLine: true,
    dotAll: true,
  ).hasMatch(appApi)) {
    _fail(
      'app-api must set SPRING_CONFIG_ADDITIONAL_LOCATION=$_runtimeMountPath.',
    );
  }
  if (!RegExp(
    r'^\s*- name: practice-ai-runtime\s*\r?\n\s*mountPath: '
    r'/config/practice-ai-runtime\.yml\s*\r?\n\s*subPath: practice-ai-runtime\.yml\s*$',
    multiLine: true,
    dotAll: true,
  ).hasMatch(appApi)) {
    _fail('app-api must mount $_runtimeFileName at $_runtimeMountPath.');
  }
  if (!RegExp(
    '^\\s*- name: practice-ai-runtime\\s*\\r?\\n\\s*configMap:\\s*\\r?\\n'
    '\\s*name: ${RegExp.escape(runtimeConfigMapName)}\\s*\$',
    multiLine: true,
  ).hasMatch(appApi)) {
    _fail('app-api runtime volume must reference its Practice AI ConfigMap.');
  }
  if (!appApi.contains('checksum/practice-ai-runtime:')) {
    _fail('app-api must checksum the Practice AI runtime ConfigMap.');
  }
  if (profile.needsDevProfile &&
      !RegExp(
        r'^\s*- name: SPRING_PROFILES_ACTIVE\s*\r?\n\s*value: "?dev"?\s*$',
        multiLine: true,
        dotAll: true,
      ).hasMatch(appApi)) {
    _fail('Kind fake mode must set SPRING_PROFILES_ACTIVE=dev on app-api.');
  }
}

void _verifyCredentialIsolation(
  List<String> documents, {
  required String appApi,
  required Set<String> providerEnvironmentVariables,
  required PracticeAiHelmProfile profile,
}) {
  if (providerEnvironmentVariables.isEmpty) {
    return;
  }

  final secretNames = <String>{};
  for (final environmentVariable in providerEnvironmentVariables) {
    final match = RegExp(
      '^\\s*- name: ${RegExp.escape(environmentVariable)}\\s*\\r?\\n'
      '\\s*valueFrom:\\s*\\r?\\n\\s*secretKeyRef:\\s*\\r?\\n'
      '\\s*name: ([^\\s#]+)\\s*\\r?\\n\\s*key: ([^\\s#]+)\\s*\$',
      multiLine: true,
    ).firstMatch(appApi);
    if (match == null || match.group(2) != environmentVariable) {
      _fail(
        'app-api must map $environmentVariable from exact secretKeyRef key.',
      );
    }
    secretNames.add(match.group(1)!);
  }
  if (secretNames.length != 1) {
    _fail('Practice AI providers must use one dedicated Secret.');
  }
  final secretName = secretNames.single;
  if (RegExp(
    'secretRef:\\s*\\r?\\n\\s*name: ${RegExp.escape(secretName)}',
  ).hasMatch(appApi)) {
    _fail('app-api must not use envFrom for the dedicated Practice AI Secret.');
  }

  for (final document in documents.where((document) => document != appApi)) {
    for (final environmentVariable in providerEnvironmentVariables) {
      if (document.contains(environmentVariable)) {
        final kind = _kindOf(document) ?? 'unknown';
        final name = _metadataName(document) ?? 'unnamed';
        final isRuntimeConfigMap =
            kind == 'ConfigMap' && document.contains('$_runtimeFileName: |');
        if ((kind != 'Secret' || name != secretName) && !isRuntimeConfigMap) {
          _fail('$environmentVariable must not appear on $kind/$name.');
        }
      }
    }
    if (_kindOf(document) != 'Secret' && document.contains(secretName)) {
      _fail(
        'Dedicated Practice AI Secret must not be referenced outside app-api.',
      );
    }
  }

  final dedicatedSecrets = documents
      .where(
        (document) =>
            _kindOf(document) == 'Secret' &&
            _metadataName(document) == secretName,
      )
      .toList(growable: false);
  if (profile.needsRenderedDedicatedSecret && dedicatedSecrets.length != 1) {
    _fail('QA must render the dedicated Practice AI Secret.');
  }
  if (dedicatedSecrets.length > 1) {
    _fail('Practice AI Secret rendered more than once.');
  }
  if (profile == PracticeAiHelmProfile.production &&
      dedicatedSecrets.isNotEmpty) {
    _fail('Production must use an externally managed Practice AI Secret.');
  }
  if (dedicatedSecrets.length == 1) {
    final checksum = _podAnnotationValue(appApi, 'checksum/practice-ai-secret');
    if (checksum == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      _fail(
        'Managed Practice AI Secret must have a SHA-256 app-api rollout checksum.',
      );
    }
    for (final environmentVariable in providerEnvironmentVariables) {
      if (!RegExp(
        '^  ${RegExp.escape(environmentVariable)}:',
        multiLine: true,
      ).hasMatch(dedicatedSecrets.single)) {
        _fail(
          'Dedicated Practice AI Secret is missing key $environmentVariable.',
        );
      }
    }
  } else if (profile == PracticeAiHelmProfile.production) {
    final rolloutVersion = _podAnnotationValue(
      appApi,
      'rollout/practice-ai-secret',
    );
    if (rolloutVersion == null ||
        rolloutVersion.trim().isEmpty ||
        rolloutVersion == 'null' ||
        rolloutVersion == '~') {
      _fail(
        'Production external Practice AI Secret requires a non-empty rollout version.',
      );
    }
  }
}

String? _podAnnotationValue(String deployment, String annotation) {
  final match = RegExp(
    '^\\s*${RegExp.escape(annotation)}:\\s*(.*?)\\s*\$',
    multiLine: true,
  ).firstMatch(deployment);
  if (match == null) {
    return null;
  }
  return _unquote(match.group(1)!).trim();
}

void _verifyNoPlaintextCredentialLeak(
  List<String> documents,
  Set<String> forbiddenCredentialValues,
) {
  for (final document in documents) {
    if (_kindOf(document) == 'Secret') {
      continue;
    }
    if (RegExp(r'^\s+api-key:\s*', multiLine: true).hasMatch(document)) {
      _fail('API key literal found outside a Secret.');
    }
    for (final credential in forbiddenCredentialValues) {
      if (credential.isNotEmpty && document.contains(credential)) {
        _fail('Configured credential leaked outside a Secret.');
      }
    }
  }
}

_RuntimeConfiguration _parseRuntimeConfiguration(String runtimeYaml) {
  final providers = <String, _ProviderConfiguration>{};
  final routes = <String, List<String>>{};
  String? section;
  String? providerName;
  String? routeName;

  for (final rawLine in runtimeYaml.split(RegExp(r'\r?\n'))) {
    if (rawLine.trim().isEmpty || rawLine.trimLeft().startsWith('#')) {
      continue;
    }
    final indent = rawLine.length - rawLine.trimLeft().length;
    final line = rawLine.trim();
    if (indent == 4 && line.startsWith('providers:')) {
      section = 'providers';
      providerName = null;
      continue;
    }
    if (indent == 4 && line.startsWith('capabilities:')) {
      section = 'capabilities';
      routeName = null;
      continue;
    }
    if (section == 'providers' && indent == 6 && line.endsWith(':')) {
      providerName = line.substring(0, line.length - 1);
      if (providerName.isEmpty || providers.containsKey(providerName)) {
        _fail('Duplicate or blank named provider $providerName.');
      }
      providers[providerName] = _ProviderConfiguration(providerName);
      continue;
    }
    if (section == 'providers' && indent == 8 && providerName != null) {
      final property = _keyValue(line);
      if (property == null) {
        _fail('Invalid provider property line $line.');
      }
      if (!providers[providerName]!.values.containsKey(property.$1)) {
        providers[providerName]!.values[property.$1] = property.$2;
      } else {
        _fail('Provider $providerName defines ${property.$1} more than once.');
      }
      continue;
    }
    if (section == 'capabilities' && indent == 6 && line.endsWith(':')) {
      routeName = line.substring(0, line.length - 1);
      if (routeName.isEmpty || routes.containsKey(routeName)) {
        _fail('Duplicate or blank capability route $routeName.');
      }
      routes[routeName] = <String>[];
      continue;
    }
    if (section == 'capabilities' && indent == 8 && routeName != null) {
      if (!line.startsWith('provider-names:')) {
        _fail('Capability route $routeName has unsupported property $line.');
      }
      final inline = line.substring('provider-names:'.length).trim();
      if (inline.isNotEmpty && inline != '[]') {
        if (!inline.startsWith('[') || !inline.endsWith(']')) {
          _fail('Capability route $routeName has invalid provider-names.');
        }
        for (final provider
            in inline
                .substring(1, inline.length - 1)
                .split(',')
                .map((name) => _unquote(name.trim()))
                .where((name) => name.isNotEmpty)) {
          routes[routeName]!.add(provider);
        }
      }
      continue;
    }
    if (section == 'capabilities' &&
        indent >= 10 &&
        line.startsWith('- ') &&
        routeName != null) {
      routes[routeName]!.add(_unquote(line.substring(2).trim()));
    }
  }

  return _RuntimeConfiguration(providers: providers, routes: routes);
}

String _runtimeYaml(String document) {
  final marker = RegExp(
    r'^  practice-ai-runtime\.yml: \|\s*$',
    multiLine: true,
  ).firstMatch(document);
  if (marker == null) {
    _fail('Runtime ConfigMap does not contain $_runtimeFileName.');
  }
  final content = document
      .substring(marker.end)
      .replaceFirst(RegExp(r'^\r?\n'), '');
  return content
      .split(RegExp(r'\r?\n'))
      .map((line) => line.startsWith('    ') ? line.substring(4) : line)
      .join('\n');
}

List<String> _splitDocuments(String manifest) => manifest
    .split(RegExp(r'^---\s*$', multiLine: true))
    .where((document) => document.trim().isNotEmpty)
    .toList(growable: false);

String? _kindOf(String document) => RegExp(
  r'^kind:\s*([^\s#]+)\s*$',
  multiLine: true,
).firstMatch(document)?.group(1);

String? _metadataName(String document) => RegExp(
  r'^metadata:\s*$.*?^  name:\s*([^\s#]+)\s*$',
  multiLine: true,
  dotAll: true,
).firstMatch(document)?.group(1);

(String, String)? _keyValue(String line) {
  final match = RegExp(r'^([a-z0-9-]+):\s*(.*)$').firstMatch(line);
  if (match == null) {
    return null;
  }
  return (match.group(1)!, _unquote(match.group(2)!));
}

String _unquote(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

String _trimOutput(String value) {
  final trimmed = value.trim();
  return trimmed.length <= 500 ? trimmed : '${trimmed.substring(0, 500)}…';
}

Never _fail(String message) =>
    throw PracticeAiHelmVerificationException(message);

class _RuntimeConfiguration {
  _RuntimeConfiguration({required this.providers, required this.routes});

  final Map<String, _ProviderConfiguration> providers;
  final Map<String, List<String>> routes;
}

class _ProviderConfiguration {
  _ProviderConfiguration(this.name);

  final String name;
  final Map<String, String> values = <String, String>{};

  String get type => values['type'] ?? '';
  String? get baseUrl => values['base-url'];
  String get apiKeyEnvironmentVariable =>
      values['api-key-environment-variable'] ?? '';
  String? get model => values['model'];
  String? get timeout => values['timeout'];
}

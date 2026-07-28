import 'dart:io';

const m211CustomSceneGateSuccessMarker =
    'M2-11 custom-scene privacy and architecture gates verified.';

const _customSceneRoot = 'mobile/lib/features/custom_scene';
const _presentationRoot = 'mobile/lib/features/custom_scene/presentation';
const _audioRoot = 'mobile/lib/features/care_path/data/audio';
const _generatedRegistryRoot = 'mobile/lib/features/practice/data/generated';

const _bannedUiTerms = <String>[
  '课程',
  '练习',
  '任务',
  '正确',
  '完成度',
  'ai 思考',
  'judge',
  'repair',
  'provider',
];

const _audioPersistenceTerms = <String>[
  'File(',
  'Directory(',
  'writeAs',
  'openWrite',
  'path_provider',
  'SharedPreferences',
  'Hive',
  'Isar',
];

class M211CustomSceneGateViolation {
  const M211CustomSceneGateViolation({
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

class M211CustomSceneGateReport {
  const M211CustomSceneGateReport({required this.violations});

  final List<M211CustomSceneGateViolation> violations;
  bool get passes => violations.isEmpty;
}

M211CustomSceneGateReport scanM211CustomSceneGates({String? projectRoot}) {
  final root = _normalize(projectRoot ?? Directory.current.path);
  final violations = <M211CustomSceneGateViolation>[];

  _scanPrivacySinks(root, violations);
  _scanOwnerHmac(root, violations);
  _scanGeneratedAudioPersistence(root, violations);
  _scanPresentationCopyAndDependencies(root, violations);
  _scanFakeProviderRouting(root, violations);
  _scanLifecycleCoverage(root, violations);

  violations.sort((left, right) {
    final path = left.sourcePath.compareTo(right.sourcePath);
    if (path != 0) return path;
    final line = left.lineNumber.compareTo(right.lineNumber);
    if (line != 0) return line;
    return left.rule.compareTo(right.rule);
  });
  return M211CustomSceneGateReport(violations: List.unmodifiable(violations));
}

String renderM211CustomSceneGateReport(M211CustomSceneGateReport report) {
  final buffer = StringBuffer()
    ..writeln(
      'm2_11_custom_scene_gate_status=${report.passes ? 'pass' : 'fail'}',
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

void _scanPrivacySinks(String root, List<M211CustomSceneGateViolation> out) {
  for (final file in _dartFiles(root, _customSceneRoot)) {
    final lines = file.readAsLinesSync();
    final runtimeSource = lines.where((line) => !_isComment(line)).join('\n');
    final hasSensitiveValue = RegExp(
      r'customSceneText|draft\.text|\btext\s*:',
    ).hasMatch(runtimeSource);
    final hasTelemetrySink = RegExp(
      r'\banalytics\b|\btelemetry\b|\bcrash\b|\bcaptureException\b|\blog\s*\(',
      caseSensitive: false,
    ).hasMatch(runtimeSource);
    if (hasSensitiveValue && hasTelemetrySink) {
      _add(
        out,
        'raw_scene_telemetry',
        root,
        file,
        0,
        'raw scene reaches telemetry/log/crash sink',
      );
    }
  }
}

void _scanOwnerHmac(String root, List<M211CustomSceneGateViolation> out) {
  for (final relativeRoot in [
    _customSceneRoot,
    _generatedRegistryRoot,
    _audioRoot,
  ]) {
    for (final file in _dartFiles(root, relativeRoot)) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        if (RegExp(
          r'hmac|ownerHmac|ownerKey|ownerScope',
          caseSensitive: false,
        ).hasMatch(lines[index])) {
          _add(
            out,
            'mobile_owner_hmac',
            root,
            file,
            index,
            'mobile model cannot carry server owner HMAC/key',
          );
        }
      }
    }
  }
}

void _scanGeneratedAudioPersistence(
  String root,
  List<M211CustomSceneGateViolation> out,
) {
  for (final file in _dartFiles(root, _audioRoot)) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      for (final term in _audioPersistenceTerms) {
        if (lines[index].contains(term)) {
          _add(
            out,
            'generated_audio_persistence',
            root,
            file,
            index,
            'generated audio cannot use $term',
          );
        }
      }
    }
  }
}

void _scanPresentationCopyAndDependencies(
  String root,
  List<M211CustomSceneGateViolation> out,
) {
  for (final file in _dartFiles(root, _presentationRoot)) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      for (final term in _bannedUiTerms) {
        if (line.toLowerCase().contains(term)) {
          _add(
            out,
            'custom_scene_ui_semantics',
            root,
            file,
            index,
            'UI contains banned semantic: $term',
          );
        }
      }
      if (!_isComment(line) &&
          RegExp(
            r'\bDio\b|custom_scene_.*dto|\bCustomScene\w*Mapper\b',
          ).hasMatch(line)) {
        _add(
          out,
          'ui_data_dependency',
          root,
          file,
          index,
          'presentation cannot depend directly on Dio/DTO/mapper',
        );
      }
    }
  }
  for (final file in _dartFiles(root, '$_customSceneRoot/application')) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      if (!_isComment(lines[index]) &&
          RegExp(
            r'\bDio\b|custom_scene_.*dto|\bCustomScene\w*Mapper\b',
          ).hasMatch(lines[index])) {
        _add(
          out,
          'controller_data_dependency',
          root,
          file,
          index,
          'controller cannot depend directly on Dio/DTO/mapper',
        );
      }
    }
  }
}

void _scanFakeProviderRouting(
  String root,
  List<M211CustomSceneGateViolation> out,
) {
  final expected = <String, List<String>>{
    'backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeCustomSceneGenerationService.java':
        ['@Profile({"dev", "test"})'],
    'backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/audio/GeneratedSpeechSynthesisConfiguration.java':
        [
          'anyMatch("dev"::equals)',
          'fake generated speech provider is restricted to the dev profile',
        ],
  };
  expected.forEach((relativePath, requiredMarkers) {
    final file = File('$root/$relativePath');
    if (!file.existsSync()) {
      out.add(
        M211CustomSceneGateViolation(
          rule: 'fake_provider_route',
          sourcePath: relativePath,
          lineNumber: 0,
          detail: 'required fake-provider restriction source missing',
        ),
      );
      return;
    }
    final source = file.readAsStringSync();
    for (final marker in requiredMarkers) {
      if (!source.contains(marker)) {
        out.add(
          M211CustomSceneGateViolation(
            rule: 'fake_provider_route',
            sourcePath: relativePath,
            lineNumber: 0,
            detail: 'missing fake-provider restriction: $marker',
          ),
        );
      }
    }
  });
}

void _scanLifecycleCoverage(
  String root,
  List<M211CustomSceneGateViolation> out,
) {
  final file = File(
    '$root/mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart',
  );
  if (!file.existsSync()) {
    out.add(
      const M211CustomSceneGateViolation(
        rule: 'lifecycle_coverage',
        sourcePath:
            'mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart',
        lineNumber: 0,
        detail: 'lifecycle policy source missing',
      ),
    );
    return;
  }
  final source = file.readAsStringSync();
  for (final trigger in [
    'logoutSessionOnly',
    'consentWithdrawalConfirmed',
    'accountDeletionConfirmed',
  ]) {
    for (final target in [
      'customSceneDraft',
      'generatedCareMoments',
      'generatedAudioMemory',
    ]) {
      final section = _triggerSection(source, trigger);
      final coversAllTargets =
          trigger == 'accountDeletionConfirmed' &&
          source.contains('LocalSensitiveDataTarget.values');
      if (!coversAllTargets &&
          (section == null ||
              !section.contains('LocalSensitiveDataTarget.$target'))) {
        out.add(
          M211CustomSceneGateViolation(
            rule: 'lifecycle_coverage',
            sourcePath:
                'mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart',
            lineNumber: 0,
            detail: '$trigger must clear $target',
          ),
        );
      }
    }
  }
  final notifier = File(
    '$root/mobile/lib/features/account/presentation/account_notifier.dart',
  );
  if (!notifier.existsSync() ||
      !notifier.readAsStringSync().contains(
        'LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed',
      )) {
    out.add(
      const M211CustomSceneGateViolation(
        rule: 'lifecycle_coverage',
        sourcePath:
            'mobile/lib/features/account/presentation/account_notifier.dart',
        lineNumber: 0,
        detail: 'consent withdrawal must invoke sensitive-state clearance',
      ),
    );
  }
}

String? _triggerSection(String source, String trigger) {
  final start = source.indexOf('LocalSensitiveDataClearanceTrigger.$trigger');
  if (start < 0) return null;
  final next = source.indexOf('LocalSensitiveDataClearanceTrigger.', start + 1);
  return source.substring(start, next < 0 ? source.length : next);
}

List<File> _dartFiles(String root, String relativePath) {
  final directory = Directory('$root/$relativePath');
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) =>
            file.path.endsWith('.dart') &&
            !file.path.endsWith('.g.dart') &&
            !file.path.endsWith('.freezed.dart'),
      )
      .toList();
}

void _add(
  List<M211CustomSceneGateViolation> out,
  String rule,
  String root,
  File file,
  int index,
  String detail,
) {
  out.add(
    M211CustomSceneGateViolation(
      rule: rule,
      sourcePath: _relative(root, file.path),
      lineNumber: index + 1,
      detail: detail,
    ),
  );
}

String _relative(String root, String path) {
  final normalizedRoot = _normalize(root);
  final normalizedPath = _normalize(path);
  return normalizedPath.startsWith('$normalizedRoot/')
      ? normalizedPath.substring(normalizedRoot.length + 1)
      : normalizedPath;
}

String _normalize(String value) => value.replaceAll('\\', '/');

bool _isComment(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('/*') ||
      trimmed.startsWith('*');
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    stderr.writeln('Usage: dart tool/verify_m2_11_custom_scene_gates.dart');
    exit(64);
  }
  final report = scanM211CustomSceneGates();
  stdout.write(renderM211CustomSceneGateReport(report));
  if (!report.passes) exit(1);
  stdout.writeln(m211CustomSceneGateSuccessMarker);
}

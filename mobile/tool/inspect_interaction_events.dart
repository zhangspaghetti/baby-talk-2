import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/sync/data/repositories/sync_repository.dart';

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed.showHelp) {
    stdout.writeln(_usage());
    return;
  }

  final resolvedDirectory =
      parsed.directory ?? Platform.environment['BABY_TALK_PRACTICE_DIR'];
  if (resolvedDirectory == null || resolvedDirectory.trim().isEmpty) {
    _fail('缺少 --directory，且环境变量 BABY_TALK_PRACTICE_DIR 未设置。', 64);
  }
  final directory = resolvedDirectory;

  if (Platform.isWindows) {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  }

  final phraseEnglishById = await _loadPhraseEnglishById(
    customSeedPath: parsed.seedContentPath,
  );

  PracticeLocalDataSource? localDataSource;
  try {
    localDataSource = await PracticeLocalDataSource.open(
      directory: directory,
      name: parsed.dbName,
    );
    final syncRepository = SyncRepository(
      localDataSource: localDataSource,
      installationIdReader: () => _readInstallationId(directory),
    );

    final rawEntities = await localDataSource.listRawEntities(
      activityId: parsed.activityId,
    );

    final validEvents = <InteractionEventPayload>[];
    final issues = <String>[];
    for (final entity in rawEntities) {
      try {
        validEvents.add(PracticeLocalDataSource.payloadFromEntity(entity));
      } catch (error) {
        issues.add(
          _redactSensitiveText(
            'eventKey=${entity.eventKey} @ ${entity.clientTimestamp.toIso8601String()} -> $error',
          )!,
        );
      }
    }

    final queueInspection = await syncRepository.inspectQueue(
      activityId: parsed.activityId,
      pendingLimit: parsed.limit,
    );
    final visibleEvents = parsed.limit >= validEvents.length
        ? validEvents
        : validEvents.sublist(validEvents.length - parsed.limit);

    stdout.writeln('installationId: ${queueInspection.installationId ?? '(missing)'}');
    stdout.writeln('dbName: ${parsed.dbName}');
    stdout.writeln('activityId: ${parsed.activityId ?? '(all)'}');
    stdout.writeln('storedEvents: ${rawEntities.length}');
    stdout.writeln('validEvents: ${validEvents.length}');
    stdout.writeln('pendingEvents: ${queueInspection.summary.pendingCount}');
    stdout.writeln('syncedEvents: ${queueInspection.summary.syncedCount}');
    stdout.writeln('failedEvents: ${queueInspection.summary.failedCount}');
    stdout.writeln(
      'lastSyncPhase: ${queueInspection.summary.lastSyncPhase ?? '(none)'}',
    );
    stdout.writeln(
      'lastSyncAt: ${queueInspection.summary.lastSyncAt?.toIso8601String() ?? '(none)'}',
    );
    stdout.writeln(
      'lastSyncError: ${_redactSensitiveText(queueInspection.summary.lastSyncError) ?? '(none)'}',
    );
    stdout.writeln('skippedEvents: ${issues.length}');
    stdout.writeln('showingLast: ${visibleEvents.length}');

    if (issues.isNotEmpty) {
      stdout.writeln('lastIssue: ${issues.last}');
    }

    if (visibleEvents.isEmpty) {
      stdout.writeln('events: (empty) 未找到本地记录。');
      return;
    }

    stdout.writeln('events:');
    for (final event in visibleEvents) {
      final phraseEnglish = phraseEnglishById[event.phraseId];
      final englishPart = phraseEnglish == null
          ? ''
          : ' phraseEnglish="$phraseEnglish"';
      final syncErrorPart = event.lastSyncError == null
          ? ''
          : ' lastSyncError="${_redactSensitiveText(event.lastSyncError)!}"';
      final syncPhasePart = event.lastSyncPhase == null
          ? ''
          : ' lastSyncPhase=${event.lastSyncPhase}';
      final syncAtPart = event.lastSyncAt == null
          ? ''
          : ' lastSyncAt=${event.lastSyncAt!.toIso8601String()}';
      stdout.writeln(
        '- ${event.clientTimestamp.toIso8601String()} '
        'eventKey=${event.eventKey} '
        'localEventId=${event.localEventId} '
        'installationId=${event.installationId} '
        'spaceId=${event.spaceId} '
        'activityId=${event.activityId} '
        'phraseId=${event.phraseId}$englishPart '
        'reactionType=${event.reactionType.wireValue} '
        'syncState=${event.syncState.wireValue}$syncPhasePart$syncAtPart$syncErrorPart',
      );
    }
  } catch (error) {
    _fail('读取本地事件失败：${_redactSensitiveText('$error')}', 1);
  } finally {
    await localDataSource?.close();
  }
}

class _ParsedArgs {
  const _ParsedArgs({
    required this.showHelp,
    required this.directory,
    required this.dbName,
    required this.activityId,
    required this.limit,
    required this.seedContentPath,
  });

  final bool showHelp;
  final String? directory;
  final String dbName;
  final String? activityId;
  final int limit;
  final String? seedContentPath;
}

_ParsedArgs _parseArgs(List<String> args) {
  String? directory;
  var dbName = 'practice_local';
  String? activityId;
  var limit = 20;
  String? seedContentPath;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    switch (arg) {
      case '--help':
      case '-h':
        return const _ParsedArgs(
          showHelp: true,
          directory: null,
          dbName: 'practice_local',
          activityId: null,
          limit: 20,
          seedContentPath: null,
        );
      case '--directory':
        directory = _readNextValue(args, ++index, '--directory');
        break;
      case '--db-name':
        dbName = _readNextValue(args, ++index, '--db-name');
        break;
      case '--activity':
        activityId = _readNextValue(args, ++index, '--activity');
        break;
      case '--limit':
        final rawLimit = _readNextValue(args, ++index, '--limit');
        final parsedLimit = int.tryParse(rawLimit);
        if (parsedLimit == null) {
          _fail('`--limit` 必须是正整数，收到: $rawLimit', 64);
        }
        limit = parsedLimit;
        if (limit <= 0) {
          _fail('`--limit` 必须大于 0，收到: $limit', 64);
        }
        break;
      case '--seed-content':
        seedContentPath = _readNextValue(args, ++index, '--seed-content');
        break;
      default:
        if (arg.startsWith('-')) {
          _fail('未知参数: $arg\n\n${_usage()}', 64);
        }
        _fail('不支持的位置参数: $arg\n\n${_usage()}', 64);
    }
  }

  return _ParsedArgs(
    showHelp: false,
    directory: directory,
    dbName: dbName,
    activityId: activityId,
    limit: limit,
    seedContentPath: seedContentPath,
  );
}

String _readNextValue(List<String> args, int index, String flag) {
  if (index >= args.length) {
    _fail('参数 $flag 缺少取值。\n\n${_usage()}', 64);
  }
  return args[index];
}

String _usage() {
  return [
    '用法: dart run tool/inspect_interaction_events.dart --directory <path> [options]',
    '',
    '选项:',
    '  --directory <path>    app 本地事件库所在目录；也可通过 BABY_TALK_PRACTICE_DIR 提供',
    '  --db-name <name>      Isar DB 名称，默认 practice_local',
    '  --activity <id>       仅查看指定 activityId',
    '  --limit <n>           仅输出最后 n 条有效事件，默认 20',
    '  --seed-content <path> 可选的 seed_content.json 路径，用于补充 phraseEnglish',
    '  --help, -h            显示帮助',
    '',
    '输出仅包含 eventKey、installationId、localEventId、spaceId、activityId、phraseId、reactionType、syncState、pending/synced/failed 计数与最近 sync phase/error/time；不会输出手机号、验证码、token 或同意前宝宝 PII。',
  ].join('\n');
}

Never _fail(String message, int code) {
  stderr.writeln(message);
  exit(code);
}

Future<String?> _readInstallationId(String directory) async {
  final file = File('$directory${Platform.pathSeparator}installation_id.txt');
  if (!await file.exists()) {
    return null;
  }
  final value = (await file.readAsString()).trim();
  return value.isEmpty ? null : value;
}

Future<Map<String, String>> _loadPhraseEnglishById({
  String? customSeedPath,
}) async {
  final defaultSeedFile = File.fromUri(
    Platform.script.resolve('../assets/content/seed_content.json'),
  );
  final seedFile = customSeedPath == null
      ? defaultSeedFile
      : File(customSeedPath);
  if (!await seedFile.exists()) {
    if (customSeedPath != null) {
      _fail('指定的 seed content 不存在: $seedFile.path', 64);
    }
    return const <String, String>{};
  }

  try {
    final decoded = jsonDecode(await seedFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('seed_content.json 顶层必须是对象。');
    }

    final spaces = decoded['spaces'];
    if (spaces is! List) {
      throw const FormatException('seed_content.json 缺少 spaces 数组。');
    }

    final phraseEnglishById = <String, String>{};
    for (final space in spaces) {
      if (space is! Map<String, dynamic>) {
        continue;
      }
      final activities = space['activities'];
      if (activities is! List) {
        continue;
      }
      for (final activity in activities) {
        if (activity is! Map<String, dynamic>) {
          continue;
        }
        final phrases = activity['phrases'];
        if (phrases is! List) {
          continue;
        }
        for (final phrase in phrases) {
          if (phrase is! Map<String, dynamic>) {
            continue;
          }
          final phraseId = phrase['id'];
          final english = phrase['english'];
          if (phraseId is String &&
              phraseId.trim().isNotEmpty &&
              english is String) {
            phraseEnglishById[phraseId] = english;
          }
        }
      }
    }
    return phraseEnglishById;
  } catch (error) {
    _fail('解析 seed content 失败：$error', 64);
  }
}

String _resolveBundledIsarLibraryPath() {
  final pubCacheRoot = Platform.environment['PUB_CACHE'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidateRoots = <Directory>[
    if (pubCacheRoot != null) Directory(pubCacheRoot),
    if (localAppData != null) Directory('$localAppData\\Pub\\Cache'),
  ];

  for (final root in candidateRoots) {
    final hostedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}hosted',
    );
    if (!hostedDirectory.existsSync()) {
      continue;
    }

    for (final host in hostedDirectory.listSync().whereType<Directory>()) {
      for (final packageDir in host.listSync().whereType<Directory>()) {
        final packageName = packageDir.path.split(RegExp(r'[\\/]')).last;
        if (!packageName.startsWith('isar_flutter_libs-')) {
          continue;
        }

        final dll = File(
          '${packageDir.path}${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll',
        );
        if (dll.existsSync()) {
          return dll.path;
        }
      }
    }
  }

  throw StateError('未在 pub cache 中找到 isar_flutter_libs/windows/isar.dll');
}

String? _redactSensitiveText(String? value) {
  if (value == null) {
    return null;
  }
  var redacted = value;
  redacted = redacted.replaceAllMapped(
    RegExp(r'\b(1\d{2})\d{4}(\d{4})\b'),
    (match) => '${match.group(1)}****${match.group(2)}',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'\b\d{4,8}\b'),
    (match) => match.group(0)!.length == 6 ? '******' : match.group(0)!,
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'(token|authorization|bearer)[=: ]+([^\s,;]+)', caseSensitive: false),
    (match) => '${match.group(1)}=[REDACTED]',
  );
  return redacted;
}

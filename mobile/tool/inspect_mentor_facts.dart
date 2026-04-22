import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  await _initializeIsarCoreIfNeeded();

  final dataDirectory = options.directoryPath == null
      ? Directory.current.path
      : Directory(options.directoryPath!).absolute.path;

  MentorLocalDataSource? dataSource;
  try {
    dataSource = await MentorLocalDataSource.open(
      directory: dataDirectory,
      name: options.databaseName,
    );
    final facts = await dataSource.listMentorFactEvents(
      eventType: options.eventType,
      limit: options.limit,
    );

    if (options.json) {
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert({
          'directory': dataDirectory,
          'databaseName': options.databaseName,
          'count': facts.length,
          'facts': facts.map(_factToJson).toList(growable: false),
        }),
      );
      return;
    }

    stdout.writeln('Mentor fact inspection');
    stdout.writeln('directory: $dataDirectory');
    stdout.writeln('database: ${options.databaseName}');
    stdout.writeln('count: ${facts.length}');
    if (options.eventType != null) {
      stdout.writeln('filter: ${options.eventType!.wireValue}');
    }
    stdout.writeln('');

    if (facts.isEmpty) {
      stdout.writeln('未找到 mentor facts。');
      stdout.writeln('提示：可通过 --directory 指向 app support / 临时测试目录。');
      return;
    }

    for (final fact in facts) {
      stdout.writeln(
        '- ${fact.createdAt.toIso8601String()}  ${fact.eventType.wireValue}  phase=${fact.phase}',
      );
      stdout.writeln('  installation=${fact.installationId}');
      if (fact.correlationId != null) {
        stdout.writeln('  correlationId=${fact.correlationId}');
      }
      if (fact.redactedSummary != null) {
        stdout.writeln('  redactedSummary=${fact.redactedSummary}');
      }
      if (fact.visibleStatus != null || fact.visibleDetail != null) {
        stdout.writeln(
          '  visible=${fact.visibleStatus ?? '-'} :: ${fact.visibleDetail ?? '-'}',
        );
      }
      stdout.writeln(
        '  retryable=${fact.retryable} contextFallbackUsed=${fact.contextFallbackUsed}',
      );
      stdout.writeln('');
    }
  } on FormatException catch (error) {
    stderr.writeln('参数错误：$error');
    stderr.writeln('');
    stderr.writeln(_usage);
    exitCode = 64;
  } on MentorPersistenceException catch (error) {
    stderr.writeln('读取 mentor facts 失败：$error');
    stderr.writeln('提示：确认 --directory 指向包含 mentor_local Isar 文件的目录。');
    exitCode = 1;
  } catch (error) {
    stderr.writeln('inspect_mentor_facts 失败：$error');
    exitCode = 1;
  } finally {
    await dataSource?.close();
  }
}

Map<String, Object?> _factToJson(MentorFactEvent fact) {
  return {
    'eventKey': fact.eventKey,
    'localEventId': fact.localEventId,
    'installationId': fact.installationId,
    'eventType': fact.eventType.wireValue,
    'phase': fact.phase,
    'createdAt': fact.createdAt.toIso8601String(),
    'correlationId': fact.correlationId,
    'redactedSummary': fact.redactedSummary,
    'visibleStatus': fact.visibleStatus,
    'visibleDetail': fact.visibleDetail,
    'retryable': fact.retryable,
    'contextFallbackUsed': fact.contextFallbackUsed,
  };
}

Future<void> _initializeIsarCoreIfNeeded() async {
  if (!Platform.isWindows) {
    return;
  }
  final libraryPath = _resolveBundledIsarLibraryPath();
  if (libraryPath == null) {
    return;
  }
  await Isar.initializeIsarCore(libraries: {Abi.current(): libraryPath});
}

String? _resolveBundledIsarLibraryPath() {
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

  return null;
}

class _CliOptions {
  const _CliOptions({
    required this.showHelp,
    required this.json,
    required this.databaseName,
    required this.directoryPath,
    required this.limit,
    required this.eventType,
  });

  final bool showHelp;
  final bool json;
  final String databaseName;
  final String? directoryPath;
  final int? limit;
  final MentorFactType? eventType;

  static _CliOptions parse(List<String> args) {
    var showHelp = false;
    var json = false;
    var databaseName = 'mentor_local';
    String? directoryPath;
    int? limit;
    MentorFactType? eventType;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--help':
        case '-h':
          showHelp = true;
          break;
        case '--json':
          json = true;
          break;
        case '--directory':
          index += 1;
          if (index >= args.length) {
            throw const FormatException('--directory 缺少路径参数。');
          }
          directoryPath = args[index];
          break;
        case '--name':
          index += 1;
          if (index >= args.length) {
            throw const FormatException('--name 缺少数据库名参数。');
          }
          databaseName = args[index];
          break;
        case '--limit':
          index += 1;
          if (index >= args.length) {
            throw const FormatException('--limit 缺少数值参数。');
          }
          limit = int.parse(args[index]);
          break;
        case '--event-type':
          index += 1;
          if (index >= args.length) {
            throw const FormatException('--event-type 缺少事件类型参数。');
          }
          eventType = parseMentorFactType(args[index]);
          break;
        default:
          throw FormatException('未知参数：$arg');
      }
    }

    return _CliOptions(
      showHelp: showHelp,
      json: json,
      databaseName: databaseName,
      directoryPath: directoryPath,
      limit: limit,
      eventType: eventType,
    );
  }
}

const String _usage = '''使用方法：
  dart run tool/inspect_mentor_facts.dart [--directory <path>] [--name mentor_local] [--limit 20] [--event-type panel_opened] [--json]

说明：
  --directory   Mentor Isar 数据目录；默认使用当前工作目录
  --name        Isar 数据库名，默认 mentor_local
  --limit       限制输出条数
  --event-type  过滤某一类 fact（例如 panel_opened / chat_failed / tts_unavailable）
  --json        输出 JSON
  --help        显示帮助

注意：
  该脚本只输出 redacted / visible diagnostics，不会回显 raw prompt 或 raw response。
''';

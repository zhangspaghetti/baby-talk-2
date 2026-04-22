import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultAppVersion = '1.2.0';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  _assertFilesExist(const [
    'docs/runbooks/s04-caregiver-practice.md',
    'backend/src/main/resources/sql/s04_caregiver_practice_queries.sql',
    'backend/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverPracticeAttributionWebTest.java',
    'mobile/test/features/mentor/mentor_repository_test.dart',
    'mobile/test/features/mentor/mentor_shell_panel_test.dart',
    'docs/runbooks/s03-caregiver-invite.md',
    'tool/verify_s03_invite.dart',
    'docs/runbooks/s01-release-distribution.md',
    'tool/verify_s01_distribution.dart',
    'backend/pom.xml',
    'mobile/pubspec.yaml',
  ]);

  if (!options.runSmoke) {
    stdout.writeln('✅ S04 caregiver practice proof pack 文件检查通过。');
    stdout.writeln(
      '如需验证 projection/shared surface，可追加 --smoke --route=shared-context --base-url=http://127.0.0.1:8080 --session-id=<session-id>。',
    );
    stdout.writeln(
      '如需验证 invite download fallback 仍接到 S01，可追加 --smoke --route=invite-download --base-url=http://127.0.0.1:8080 --token=<invite-token>。',
    );
    return;
  }

  if (options.baseUrl == null) {
    _fail('执行 --smoke 时必须提供 --base-url，例如 http://127.0.0.1:8080', 64);
  }

  switch (options.route) {
    case _RouteKind.sharedContext:
      if (options.sessionId == null) {
        _fail('执行 shared-context smoke 时必须提供 --session-id。', 64);
      }
      await _runSharedContextSmoke(options);
      return;
    case _RouteKind.inviteDownload:
      if (options.token == null) {
        _fail('执行 invite-download smoke 时必须提供 --token。', 64);
      }
      await _runInviteDownloadSmoke(options);
      return;
  }
}

Future<void> _runSharedContextSmoke(_CliOptions options) async {
  final client = HttpClient()..connectionTimeout = options.timeout;
  final uri = options.baseUrl!.replace(
    path: _joinPath(options.baseUrl!.path, '/api/v1/household/shared-context'),
  );

  stdout.writeln('==> S04 caregiver practice smoke');
  stdout.writeln('    GET $uri');
  stdout.writeln(
    '    route: shared-context, expect status=${options.expectStatus}, '
    'practice=${options.expectSpaceId ?? '(skip)'}/${options.expectActivityId ?? '(skip)'}, '
    'actor=${options.expectActorRole ?? '(skip)'}, '
    'nextStep=${options.expectNextStepActivityId ?? '(skip)'}',
  );

  try {
    final request = await client.getUrl(uri).timeout(options.timeout);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set('X-App-Version', options.appVersion);
    request.headers.set('X-Session-Id', options.sessionId!);

    final response = await request.close().timeout(options.timeout);
    final body = await utf8.decodeStream(response).timeout(options.timeout);

    stdout.writeln('    status: ${response.statusCode}');

    if (response.statusCode != options.expectStatus) {
      _fail(
        'shared-context smoke 失败：预期 status=${options.expectStatus}，实际为 ${response.statusCode}。',
        1,
      );
    }

    final json = _decodeJson(body);
    final snapshot = _readRequiredMap(json, 'snapshot');
    final practice = _readRequiredMap(snapshot, 'practice');
    final actor = _readOptionalMap(snapshot, 'actor');
    final nextStep = _readOptionalMap(snapshot, 'nextStep');

    final actualSpaceId = _readRequiredString(practice, 'spaceId');
    final actualActivityId = _readRequiredString(practice, 'activityId');
    final actualActorRole = actor == null
        ? null
        : _readOptionalString(actor, 'role');
    final actualNextStepActivityId = nextStep == null
        ? null
        : _readOptionalString(nextStep, 'activityId');

    stdout.writeln('    practice: $actualSpaceId/$actualActivityId');
    stdout.writeln('    actor role: ${actualActorRole ?? '(missing)'}');
    stdout.writeln(
      '    next-step activity: ${actualNextStepActivityId ?? '(missing)'}',
    );

    if (options.expectSpaceId != null &&
        actualSpaceId != options.expectSpaceId) {
      _fail(
        'shared-context smoke 失败：预期 practice.spaceId=${options.expectSpaceId}，实际为 $actualSpaceId。',
        1,
      );
    }
    if (options.expectActivityId != null &&
        actualActivityId != options.expectActivityId) {
      _fail(
        'shared-context smoke 失败：预期 practice.activityId=${options.expectActivityId}，实际为 $actualActivityId。',
        1,
      );
    }
    if (options.expectActorRole != null &&
        actualActorRole != options.expectActorRole) {
      _fail(
        'shared-context smoke 失败：预期 actor.role=${options.expectActorRole}，实际为 ${actualActorRole ?? '(missing)'}。',
        1,
      );
    }
    if (options.expectNextStepActivityId != null &&
        actualNextStepActivityId != options.expectNextStepActivityId) {
      _fail(
        'shared-context smoke 失败：预期 nextStep.activityId=${options.expectNextStepActivityId}，实际为 ${actualNextStepActivityId ?? '(missing)'}。',
        1,
      );
    }

    _assertBodyDoesNotLeak(body, const [
      'installationId',
      'sessionId',
      'rawPayload',
      'rawProviderOutput',
    ]);

    stdout.writeln('✅ S04 shared-context smoke 通过。');
  } on TimeoutException {
    _fail(
      'shared-context smoke 超时。请确认 backend 已启动、session 有效，或 projection 已刷新。',
      124,
    );
  } on SocketException catch (error) {
    _fail(
      '无法连接 `${options.baseUrl}`：${error.message}。请确认 backend 已启动；可先执行 `mvn -f backend/pom.xml spring-boot:run`。',
      69,
    );
  } on HttpException catch (error) {
    _fail('HTTP 调用失败：${error.message}', 1);
  } finally {
    client.close(force: true);
  }
}

Future<void> _runInviteDownloadSmoke(_CliOptions options) async {
  final client = HttpClient()..connectionTimeout = options.timeout;
  final resolvedPlatform = options.platform ?? 'android';
  final uri = options.baseUrl!.replace(
    path: _joinPath(
      options.baseUrl!.path,
      '/invite/${options.token!}/download',
    ),
    queryParameters: <String, String>{'platform': resolvedPlatform},
  );

  stdout.writeln('==> S04 caregiver practice smoke');
  stdout.writeln('    GET $uri');
  stdout.writeln(
    '    route: invite-download, expect status=${options.expectStatus}, '
    'result=${options.expectResult ?? '(skip)'}, '
    'location=${options.expectLocationContains ?? '(skip)'}',
  );

  try {
    final request = await client.getUrl(uri).timeout(options.timeout);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.userAgentHeader,
      _userAgentForPlatform(resolvedPlatform),
    );

    final response = await request.close().timeout(options.timeout);
    final body = await utf8.decodeStream(response).timeout(options.timeout);
    final resultHeader = response.headers.value('x-invite-result');
    final auditHeader = response.headers.value('x-invite-audit');
    final failureReasonHeader = response.headers.value(
      'x-invite-failure-reason',
    );
    final locationHeader = response.headers.value(HttpHeaders.locationHeader);

    stdout.writeln('    status: ${response.statusCode}');
    stdout.writeln('    result header: ${resultHeader ?? '(missing)'}');
    stdout.writeln('    audit header: ${auditHeader ?? '(missing)'}');
    stdout.writeln(
      '    failure reason header: ${failureReasonHeader ?? '(missing)'}',
    );
    if (locationHeader != null) {
      stdout.writeln('    location: $locationHeader');
    }

    if (response.statusCode != options.expectStatus) {
      _fail(
        'invite-download smoke 失败：预期 status=${options.expectStatus}，实际为 ${response.statusCode}。',
        1,
      );
    }
    if (options.expectResult != null && resultHeader != options.expectResult) {
      _fail(
        'invite-download smoke 失败：预期 X-Invite-Result=${options.expectResult}，实际为 ${resultHeader ?? '(missing)'}。',
        1,
      );
    }
    if (options.expectLocationContains != null) {
      final actualLocation = locationHeader ?? '';
      if (!actualLocation.contains(options.expectLocationContains!)) {
        _fail(
          'invite-download smoke 失败：Location 未包含 `${options.expectLocationContains}`。实际为 `${locationHeader ?? '(missing)'}`。',
          1,
        );
      }
    }

    _assertBodyDoesNotLeak(body, const [
      'installationId',
      'sessionId',
      'rawPayload',
    ]);
    stdout.writeln('✅ S04 invite-download smoke 通过。');
  } on TimeoutException {
    _fail(
      'invite-download smoke 超时。请确认 backend 已启动、token 有效，且 S03/S01 bridge 已就绪。',
      124,
    );
  } on SocketException catch (error) {
    _fail(
      '无法连接 `${options.baseUrl}`：${error.message}。请确认 backend 已启动；可先执行 `mvn -f backend/pom.xml spring-boot:run`。',
      69,
    );
  } on HttpException catch (error) {
    _fail('HTTP 调用失败：${error.message}', 1);
  } finally {
    client.close(force: true);
  }
}

void _assertBodyDoesNotLeak(String body, Iterable<String> forbiddenMarkers) {
  for (final marker in forbiddenMarkers) {
    if (body.contains(marker)) {
      _fail('smoke 失败：响应体不应包含 `$marker`。', 1);
    }
  }
}

void _assertFilesExist(Iterable<String> paths) {
  final missing = <String>[];
  for (final path in paths) {
    if (!File(path).existsSync()) {
      missing.add(path);
    }
  }

  if (missing.isEmpty) {
    return;
  }

  stderr.writeln('S04 caregiver practice proof pack 缺少必要文件：');
  for (final path in missing) {
    stderr.writeln('  - $path');
  }
  exit(64);
}

Never _fail(String message, int exitCode) {
  stderr.writeln(message);
  exit(exitCode);
}

Map<String, dynamic> _decodeJson(String rawBody) {
  if (rawBody.trim().isEmpty) {
    _fail('shared-context smoke 失败：响应体为空。', 1);
  }
  try {
    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    _fail('shared-context smoke 失败：响应顶层不是对象。', 1);
  } on FormatException catch (error) {
    _fail('shared-context smoke 失败：响应不是合法 JSON：$error', 1);
  } on Object {
    _fail('shared-context smoke 失败：响应不是合法 JSON。', 1);
  }
}

Map<String, dynamic> _readRequiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    _fail('shared-context smoke 失败：字段 `$key` 缺失或不是对象。', 1);
  }
  return value;
}

Map<String, dynamic>? _readOptionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    _fail('shared-context smoke 失败：字段 `$key` 不是对象。', 1);
  }
  return value;
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    _fail('shared-context smoke 失败：字段 `$key` 缺失或不是非空字符串。', 1);
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    _fail('shared-context smoke 失败：字段 `$key` 不是字符串。', 1);
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _userAgentForPlatform(String platform) {
  return switch (platform) {
    'android' => 'Mozilla/5.0 (Linux; Android 14) BabyTalkS04Verify/1.0',
    'ios' =>
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) BabyTalkS04Verify/1.0',
    _ => 'BabyTalkS04Verify/1.0',
  };
}

class _CliOptions {
  const _CliOptions({
    required this.showHelp,
    required this.runSmoke,
    required this.route,
    required this.baseUrl,
    required this.sessionId,
    required this.token,
    required this.platform,
    required this.expectStatus,
    required this.expectResult,
    required this.expectLocationContains,
    required this.expectSpaceId,
    required this.expectActivityId,
    required this.expectActorRole,
    required this.expectNextStepActivityId,
    required this.timeout,
    required this.appVersion,
  });

  final bool showHelp;
  final bool runSmoke;
  final _RouteKind route;
  final Uri? baseUrl;
  final String? sessionId;
  final String? token;
  final String? platform;
  final int expectStatus;
  final String? expectResult;
  final String? expectLocationContains;
  final String? expectSpaceId;
  final String? expectActivityId;
  final String? expectActorRole;
  final String? expectNextStepActivityId;
  final Duration timeout;
  final String appVersion;

  static _CliOptions parse(List<String> args) {
    var showHelp = false;
    var runSmoke = false;
    var sawSmokeSpecificArg = false;
    var route = _RouteKind.sharedContext;
    Uri? baseUrl;
    String? sessionId;
    String? token;
    String? platform;
    int? expectStatus;
    String? expectResult;
    var hasExpectResult = false;
    String? expectLocationContains;
    var hasExpectLocation = false;
    String? expectSpaceId;
    String? expectActivityId;
    String? expectActorRole;
    String? expectNextStepActivityId;
    var timeout = const Duration(seconds: 10);
    var appVersion = _defaultAppVersion;

    final iterator = args.iterator;
    while (iterator.moveNext()) {
      final arg = iterator.current;
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
        continue;
      }
      if (arg == '--smoke') {
        runSmoke = true;
        continue;
      }
      if (arg.startsWith('--route=')) {
        sawSmokeSpecificArg = true;
        route = _RouteKind.parse(arg.substring('--route='.length));
        continue;
      }
      if (arg == '--route') {
        sawSmokeSpecificArg = true;
        route = _RouteKind.parse(_nextValue(iterator, arg));
        continue;
      }
      if (arg.startsWith('--base-url=')) {
        sawSmokeSpecificArg = true;
        baseUrl = _parseBaseUrl(arg.substring('--base-url='.length));
        continue;
      }
      if (arg == '--base-url') {
        sawSmokeSpecificArg = true;
        baseUrl = _parseBaseUrl(_nextValue(iterator, arg));
        continue;
      }
      if (arg.startsWith('--session-id=')) {
        sawSmokeSpecificArg = true;
        sessionId = _normalizeOptionalValue(
          arg.substring('--session-id='.length),
          'session-id',
        );
        continue;
      }
      if (arg == '--session-id') {
        sawSmokeSpecificArg = true;
        sessionId = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'session-id',
        );
        continue;
      }
      if (arg.startsWith('--token=')) {
        sawSmokeSpecificArg = true;
        token = _normalizeOptionalValue(
          arg.substring('--token='.length),
          'token',
        );
        continue;
      }
      if (arg == '--token') {
        sawSmokeSpecificArg = true;
        token = _normalizeOptionalValue(_nextValue(iterator, arg), 'token');
        continue;
      }
      if (arg.startsWith('--platform=')) {
        sawSmokeSpecificArg = true;
        platform = _normalizeOptionalValue(
          arg.substring('--platform='.length),
          'platform',
        );
        continue;
      }
      if (arg == '--platform') {
        sawSmokeSpecificArg = true;
        platform = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'platform',
        );
        continue;
      }
      if (arg.startsWith('--expect-status=')) {
        sawSmokeSpecificArg = true;
        expectStatus = _parsePositiveInt(
          arg.substring('--expect-status='.length),
          'expect-status',
        );
        continue;
      }
      if (arg == '--expect-status') {
        sawSmokeSpecificArg = true;
        expectStatus = _parsePositiveInt(
          _nextValue(iterator, arg),
          'expect-status',
        );
        continue;
      }
      if (arg.startsWith('--expect-result=')) {
        sawSmokeSpecificArg = true;
        hasExpectResult = true;
        expectResult = _normalizeOptionalValue(
          arg.substring('--expect-result='.length),
          'expect-result',
        );
        continue;
      }
      if (arg == '--expect-result') {
        sawSmokeSpecificArg = true;
        hasExpectResult = true;
        expectResult = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'expect-result',
        );
        continue;
      }
      if (arg.startsWith('--expect-location-contains=')) {
        sawSmokeSpecificArg = true;
        hasExpectLocation = true;
        expectLocationContains = _normalizeOptionalValue(
          arg.substring('--expect-location-contains='.length),
          'expect-location-contains',
        );
        continue;
      }
      if (arg == '--expect-location-contains') {
        sawSmokeSpecificArg = true;
        hasExpectLocation = true;
        expectLocationContains = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'expect-location-contains',
        );
        continue;
      }
      if (arg.startsWith('--expect-space-id=')) {
        sawSmokeSpecificArg = true;
        expectSpaceId = _normalizeOptionalValue(
          arg.substring('--expect-space-id='.length),
          'expect-space-id',
        );
        continue;
      }
      if (arg == '--expect-space-id') {
        sawSmokeSpecificArg = true;
        expectSpaceId = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'expect-space-id',
        );
        continue;
      }
      if (arg.startsWith('--expect-activity-id=')) {
        sawSmokeSpecificArg = true;
        expectActivityId = _normalizeOptionalValue(
          arg.substring('--expect-activity-id='.length),
          'expect-activity-id',
        );
        continue;
      }
      if (arg == '--expect-activity-id') {
        sawSmokeSpecificArg = true;
        expectActivityId = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'expect-activity-id',
        );
        continue;
      }
      if (arg.startsWith('--expect-actor-role=')) {
        sawSmokeSpecificArg = true;
        expectActorRole = _normalizeOptionalValue(
          arg.substring('--expect-actor-role='.length),
          'expect-actor-role',
        );
        continue;
      }
      if (arg == '--expect-actor-role') {
        sawSmokeSpecificArg = true;
        expectActorRole = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'expect-actor-role',
        );
        continue;
      }
      if (arg.startsWith('--expect-next-step-activity-id=')) {
        sawSmokeSpecificArg = true;
        expectNextStepActivityId = _normalizeOptionalValue(
          arg.substring('--expect-next-step-activity-id='.length),
          'expect-next-step-activity-id',
        );
        continue;
      }
      if (arg == '--expect-next-step-activity-id') {
        sawSmokeSpecificArg = true;
        expectNextStepActivityId = _normalizeOptionalValue(
          _nextValue(iterator, arg),
          'expect-next-step-activity-id',
        );
        continue;
      }
      if (arg.startsWith('--timeout-seconds=')) {
        sawSmokeSpecificArg = true;
        timeout = Duration(
          seconds: _parsePositiveInt(
            arg.substring('--timeout-seconds='.length),
            'timeout-seconds',
          ),
        );
        continue;
      }
      if (arg == '--timeout-seconds') {
        sawSmokeSpecificArg = true;
        timeout = Duration(
          seconds: _parsePositiveInt(
            _nextValue(iterator, arg),
            'timeout-seconds',
          ),
        );
        continue;
      }
      if (arg.startsWith('--app-version=')) {
        sawSmokeSpecificArg = true;
        appVersion = _normalizeRequiredValue(
          arg.substring('--app-version='.length),
          'app-version',
        );
        continue;
      }
      if (arg == '--app-version') {
        sawSmokeSpecificArg = true;
        appVersion = _normalizeRequiredValue(
          _nextValue(iterator, arg),
          'app-version',
        );
        continue;
      }
      _fail('未知参数：$arg\n\n$_usage', 64);
    }

    if (sawSmokeSpecificArg && !runSmoke && !showHelp) {
      _fail('检测到 smoke 参数，但缺少 --smoke。请显式添加 --smoke 后再执行。', 64);
    }

    return _CliOptions(
      showHelp: showHelp,
      runSmoke: runSmoke,
      route: route,
      baseUrl: baseUrl,
      sessionId: sessionId,
      token: token,
      platform: platform,
      expectStatus: expectStatus ?? _defaultStatusForRoute(route),
      expectResult: hasExpectResult
          ? expectResult
          : _defaultResultForRoute(route),
      expectLocationContains: hasExpectLocation
          ? expectLocationContains
          : _defaultLocationForRoute(route),
      expectSpaceId: expectSpaceId,
      expectActivityId: expectActivityId,
      expectActorRole: expectActorRole,
      expectNextStepActivityId: expectNextStepActivityId,
      timeout: timeout,
      appVersion: appVersion,
    );
  }
}

enum _RouteKind {
  sharedContext,
  inviteDownload;

  static _RouteKind parse(String rawValue) {
    return switch (rawValue.trim()) {
      'shared-context' => _RouteKind.sharedContext,
      'invite-download' => _RouteKind.inviteDownload,
      _ => _fail(
        '不支持的 --route=`$rawValue`。允许值：shared-context, invite-download。',
        64,
      ),
    };
  }
}

int _defaultStatusForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.sharedContext => 200,
    _RouteKind.inviteDownload => 302,
  };
}

String? _defaultResultForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.sharedContext => null,
    _RouteKind.inviteDownload => 'download_fallback',
  };
}

String? _defaultLocationForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.sharedContext => null,
    _RouteKind.inviteDownload => '/download?source=caregiver_invite',
  };
}

Uri _parseBaseUrl(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    _fail('--base-url 不能为空。', 64);
  }
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    _fail('无效的 --base-url=`$rawValue`。示例：http://127.0.0.1:8080', 64);
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    _fail('--base-url 只支持 http 或 https。', 64);
  }
  return uri;
}

String _nextValue(Iterator<String> iterator, String optionName) {
  if (!iterator.moveNext()) {
    _fail('参数 `$optionName` 缺少取值。', 64);
  }
  return iterator.current;
}

String _normalizeRequiredValue(String rawValue, String optionName) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    _fail('参数 `$optionName` 不能为空。', 64);
  }
  return value;
}

String? _normalizeOptionalValue(String rawValue, String optionName) {
  final value = _normalizeRequiredValue(rawValue, optionName);
  if (value == 'skip' || value == '-') {
    return null;
  }
  return value;
}

int _parsePositiveInt(String rawValue, String optionName) {
  final value = int.tryParse(rawValue.trim());
  if (value == null || value <= 0) {
    _fail('参数 `$optionName` 必须是正整数。', 64);
  }
  return value;
}

String _joinPath(String basePath, String routePath) {
  final trimmed = basePath.trim();
  final normalizedBase = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  if (normalizedBase.isEmpty || normalizedBase == '/') {
    return routePath;
  }
  return '$normalizedBase$routePath';
}

const String _usage = '''用法：
  dart run tool/verify_s04_caregiver_practice.dart [--smoke --route=<route> --base-url=<url> [其它参数]]

说明：
  默认只检查 S04 caregiver practice proof pack 的必需文件是否存在：
    - docs/runbooks/s04-caregiver-practice.md
    - backend/src/main/resources/sql/s04_caregiver_practice_queries.sql
    - backend/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverPracticeAttributionWebTest.java
    - mobile/test/features/mentor/mentor_repository_test.dart
    - mobile/test/features/mentor/mentor_shell_panel_test.dart
    - docs/runbooks/s03-caregiver-invite.md
    - tool/verify_s03_invite.dart
    - docs/runbooks/s01-release-distribution.md
    - tool/verify_s01_distribution.dart

  --smoke                                执行一次 root-safe smoke
  --route=<value>                        shared-context | invite-download，默认 shared-context
  --base-url=<url>                       必填（仅在 --smoke 时），例如 http://127.0.0.1:8080
  --session-id=<value>                   shared-context smoke 必填
  --token=<value>                        invite-download smoke 必填
  --platform=<value>                     invite-download 可选；android / ios，默认 android
  --expect-status=<code>                 预期 HTTP 状态码；shared-context 默认 200，invite-download 默认 302
  --expect-result=<value>                仅 invite-download 使用；默认 download_fallback
                                         传 skip 或 - 可跳过该断言
  --expect-location-contains=<text>      仅 invite-download 使用；默认 /download?source=caregiver_invite
                                         传 skip 或 - 可跳过该断言
  --expect-space-id=<value>              shared-context 可选；断言 snapshot.practice.spaceId
  --expect-activity-id=<value>           shared-context 可选；断言 snapshot.practice.activityId
  --expect-actor-role=<value>            shared-context 可选；断言 snapshot.actor.role
  --expect-next-step-activity-id=<value> shared-context 可选；断言 snapshot.nextStep.activityId
  --app-version=<value>                  shared-context 的 X-App-Version，默认 1.2.0
  --timeout-seconds=<n>                  单次 smoke 超时秒数，默认 10
  --help, -h                             显示帮助

示例：
  dart run tool/verify_s04_caregiver_practice.dart --help

  dart run tool/verify_s04_caregiver_practice.dart \
    --smoke \
    --route=shared-context \
    --base-url=http://127.0.0.1:8080 \
    --session-id=session_1234 \
    --expect-status=200 \
    --expect-space-id=sleep_support \
    --expect-activity-id=bedtime_story \
    --expect-actor-role=caregiver \
    --expect-next-step-activity-id=bath_time

  dart run tool/verify_s04_caregiver_practice.dart \
    --smoke \
    --route=invite-download \
    --base-url=http://127.0.0.1:8080 \
    --token=invite_token_1234 \
    --platform=android \
    --expect-status=302 \
    --expect-result=download_fallback \
    --expect-location-contains="/download?source=caregiver_invite"

失败合同：
  - 缺文件、缺 --base-url / --session-id / --token 或参数非法：exit code 64
  - backend 不可达：返回非 0，并提示先执行 `mvn -f backend/pom.xml spring-boot:run`
  - smoke 超时：exit code 124，并提示确认 backend、token/session 与 projection 是否可用

redaction 红线：
  这个 wrapper 只围绕 `/api/v1/household/shared-context`、`/invite/{token}/download`、
  `interaction_events` / `household_shared_context` / `caregiver_invite_events` / `release_distribution_events`
  相关的 coarse-grained surface 做存在性与可达性验证；不要把 child name、installationId、sessionId、
  raw payload 或 provider raw output 混进命令输出或后续扩展中。
''';

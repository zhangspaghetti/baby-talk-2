import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  _assertFilesExist(const [
    'docs/runbooks/s02-growth-share.md',
    'backend/src/main/resources/sql/s02_share_landing_queries.sql',
    'backend/src/main/resources/db/migration/V6__create_share_landing_tables.sql',
    'backend/src/test/java/com/zhangspaghetti/babytalk/web/ShareLinkApiWebTest.java',
    'backend/src/test/java/com/zhangspaghetti/babytalk/web/ShareLandingWebTest.java',
    'mobile/test/app/share_reentry_coordinator_test.dart',
    'backend/pom.xml',
    'mobile/pubspec.yaml',
  ]);

  if (!options.runSmoke) {
    stdout.writeln('✅ S02 growth share proof pack 文件检查通过。');
    stdout.writeln(
      '如需验证 landing/open-app/download surface，可追加 --smoke --base-url=http://127.0.0.1:8080 --token=<share-token>。',
    );
    return;
  }

  if (options.baseUrl == null) {
    _fail('执行 --smoke 时必须提供 --base-url，例如 http://127.0.0.1:8080', 64);
  }
  if (options.token == null) {
    _fail('执行 --smoke 时必须提供 --token，例如 share_token_1234', 64);
  }

  await _runSmoke(options.toSmokeRequest());
}

Future<void> _runSmoke(_SmokeRequest request) async {
  final client = HttpClient()..connectionTimeout = request.timeout;
  final uri = request.uri;

  stdout.writeln('==> S02 growth share smoke');
  stdout.writeln('    GET $uri');
  stdout.writeln(
    '    expect: status=${request.expectStatus}, '
    'result=${request.expectResult ?? '(skip)'}, '
    'location=${request.expectLocationContains ?? '(skip)'}, '
    'body=${request.expectBody == null ? '(skip)' : 'contains `${request.expectBody}`'}',
  );

  try {
    final httpRequest = await client.getUrl(uri).timeout(request.timeout);
    httpRequest.followRedirects = false;
    httpRequest.headers.set(
      HttpHeaders.userAgentHeader,
      _userAgentForPlatform(request.platform),
    );

    final response = await httpRequest.close().timeout(request.timeout);
    final body = await utf8.decodeStream(response).timeout(request.timeout);
    final resultHeader = response.headers.value('x-share-landing-result');
    final auditHeader = response.headers.value('x-share-landing-audit');
    final failureReasonHeader = response.headers.value(
      'x-share-landing-failure-reason',
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

    if (response.statusCode != request.expectStatus) {
      _fail(
        'smoke 失败：预期 status=${request.expectStatus}，实际为 ${response.statusCode}。',
        1,
      );
    }

    if (request.expectResult != null && resultHeader != request.expectResult) {
      _fail(
        'smoke 失败：预期 X-Share-Landing-Result=${request.expectResult}，实际为 ${resultHeader ?? '(missing)'}。',
        1,
      );
    }

    if (request.expectLocationContains != null) {
      final actualLocation = locationHeader ?? '';
      if (!actualLocation.contains(request.expectLocationContains!)) {
        _fail(
          'smoke 失败：Location 未包含 `${request.expectLocationContains}`。实际为 `${locationHeader ?? '(missing)'}`。',
          1,
        );
      }
    }

    if (request.expectBody != null && !body.contains(request.expectBody!)) {
      _fail('smoke 失败：响应体未包含 `${request.expectBody}`。', 1);
    }

    stdout.writeln('✅ S02 growth share smoke 通过。');
  } on TimeoutException {
    _fail(
      '连接 `$uri` 超时。请确认 backend 已启动、token 仍有效，或先执行 `mvn -f backend/pom.xml spring-boot:run`。',
      124,
    );
  } on SocketException catch (error) {
    _fail(
      '无法连接 `$uri`：${error.message}。请确认 backend 已启动；可先执行 `mvn -f backend/pom.xml spring-boot:run`。',
      69,
    );
  } on HttpException catch (error) {
    _fail('HTTP 调用失败：${error.message}', 1);
  } finally {
    client.close(force: true);
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

  stderr.writeln('S02 growth share proof pack 缺少必要文件：');
  for (final path in missing) {
    stderr.writeln('  - $path');
  }
  exit(64);
}

Never _fail(String message, int exitCode) {
  stderr.writeln(message);
  exit(exitCode);
}

String _userAgentForPlatform(String? platform) {
  return switch (platform) {
    'android' => 'Mozilla/5.0 (Linux; Android 14) BabyTalkShareVerify/1.0',
    'ios' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) BabyTalkShareVerify/1.0',
    _ => 'BabyTalkShareVerify/1.0',
  };
}

int _defaultStatusForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.landing => 200,
    _RouteKind.openApp || _RouteKind.download => 302,
  };
}

String _defaultResultForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.landing => 'page_view',
    _RouteKind.openApp => 'open_app_redirect',
    _RouteKind.download => 'download_fallback',
  };
}

String? _defaultLocationForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.landing => null,
    _RouteKind.openApp => 'babytalk://share/open',
    _RouteKind.download => '/download?source=share_card',
  };
}

String? _defaultPlatformForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.landing => null,
    _RouteKind.openApp || _RouteKind.download => 'android',
  };
}

class _CliOptions {
  const _CliOptions({
    required this.showHelp,
    required this.runSmoke,
    required this.baseUrl,
    required this.token,
    required this.route,
    required this.platform,
    required this.expectStatus,
    required this.expectResult,
    required this.expectBody,
    required this.expectLocationContains,
    required this.timeout,
  });

  final bool showHelp;
  final bool runSmoke;
  final Uri? baseUrl;
  final String? token;
  final _RouteKind route;
  final String? platform;
  final int expectStatus;
  final String? expectResult;
  final String? expectBody;
  final String? expectLocationContains;
  final Duration timeout;

  _SmokeRequest toSmokeRequest() {
    final resolvedPlatform = platform ?? _defaultPlatformForRoute(route);
    final queryParameters = <String, String>{};
    if (resolvedPlatform != null && route != _RouteKind.landing) {
      queryParameters['platform'] = resolvedPlatform;
    }

    return _SmokeRequest(
      uri: baseUrl!.replace(
        path: _joinPath(baseUrl!.path, route.pathForToken(token!)),
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      ),
      platform: resolvedPlatform,
      expectStatus: expectStatus,
      expectResult: expectResult,
      expectBody: expectBody,
      expectLocationContains: expectLocationContains,
      timeout: timeout,
    );
  }

  static _CliOptions parse(List<String> args) {
    var showHelp = false;
    var runSmoke = false;
    var sawSmokeSpecificArg = false;
    Uri? baseUrl;
    String? token;
    var route = _RouteKind.landing;
    String? platform;
    var platformExplicitlySet = false;
    int? expectStatus;
    String? expectResult;
    var hasExpectResult = false;
    String? expectBody;
    String? expectLocationContains;
    var hasExpectLocation = false;
    var timeout = const Duration(seconds: 10);

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
      if (arg.startsWith('--token=')) {
        sawSmokeSpecificArg = true;
        token = _normalizeRequiredValue(arg.substring('--token='.length), 'token');
        continue;
      }
      if (arg == '--token') {
        sawSmokeSpecificArg = true;
        token = _normalizeRequiredValue(_nextValue(iterator, arg), 'token');
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
      if (arg.startsWith('--platform=')) {
        sawSmokeSpecificArg = true;
        platformExplicitlySet = true;
        platform = _normalizeOptionalValue(arg.substring('--platform='.length), 'platform');
        continue;
      }
      if (arg == '--platform') {
        sawSmokeSpecificArg = true;
        platformExplicitlySet = true;
        platform = _normalizeOptionalValue(_nextValue(iterator, arg), 'platform');
        continue;
      }
      if (arg.startsWith('--expect-status=')) {
        sawSmokeSpecificArg = true;
        expectStatus = _parsePositiveInt(arg.substring('--expect-status='.length), 'expect-status');
        continue;
      }
      if (arg == '--expect-status') {
        sawSmokeSpecificArg = true;
        expectStatus = _parsePositiveInt(_nextValue(iterator, arg), 'expect-status');
        continue;
      }
      if (arg.startsWith('--expect-result=')) {
        sawSmokeSpecificArg = true;
        hasExpectResult = true;
        expectResult = _normalizeOptionalValue(arg.substring('--expect-result='.length), 'expect-result');
        continue;
      }
      if (arg == '--expect-result') {
        sawSmokeSpecificArg = true;
        hasExpectResult = true;
        expectResult = _normalizeOptionalValue(_nextValue(iterator, arg), 'expect-result');
        continue;
      }
      if (arg.startsWith('--expect-body=')) {
        sawSmokeSpecificArg = true;
        expectBody = _normalizeRequiredValue(arg.substring('--expect-body='.length), 'expect-body');
        continue;
      }
      if (arg == '--expect-body') {
        sawSmokeSpecificArg = true;
        expectBody = _normalizeRequiredValue(_nextValue(iterator, arg), 'expect-body');
        continue;
      }
      if (arg.startsWith('--expect-location-contains=')) {
        sawSmokeSpecificArg = true;
        hasExpectLocation = true;
        expectLocationContains = _normalizeOptionalValue(arg.substring('--expect-location-contains='.length), 'expect-location-contains');
        continue;
      }
      if (arg == '--expect-location-contains') {
        sawSmokeSpecificArg = true;
        hasExpectLocation = true;
        expectLocationContains = _normalizeOptionalValue(_nextValue(iterator, arg), 'expect-location-contains');
        continue;
      }
      if (arg.startsWith('--timeout-seconds=')) {
        sawSmokeSpecificArg = true;
        timeout = Duration(seconds: _parsePositiveInt(arg.substring('--timeout-seconds='.length), 'timeout-seconds'));
        continue;
      }
      if (arg == '--timeout-seconds') {
        sawSmokeSpecificArg = true;
        timeout = Duration(seconds: _parsePositiveInt(_nextValue(iterator, arg), 'timeout-seconds'));
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
      baseUrl: baseUrl,
      token: token,
      route: route,
      platform: platformExplicitlySet ? platform : null,
      expectStatus: expectStatus ?? _defaultStatusForRoute(route),
      expectResult: hasExpectResult ? expectResult : _defaultResultForRoute(route),
      expectBody: expectBody,
      expectLocationContains: hasExpectLocation ? expectLocationContains : _defaultLocationForRoute(route),
      timeout: timeout,
    );
  }
}

class _SmokeRequest {
  const _SmokeRequest({
    required this.uri,
    required this.platform,
    required this.expectStatus,
    required this.expectResult,
    required this.expectBody,
    required this.expectLocationContains,
    required this.timeout,
  });

  final Uri uri;
  final String? platform;
  final int expectStatus;
  final String? expectResult;
  final String? expectBody;
  final String? expectLocationContains;
  final Duration timeout;
}

enum _RouteKind {
  landing,
  openApp,
  download;

  static _RouteKind parse(String value) {
    return switch (value.trim()) {
      'landing' => _RouteKind.landing,
      'open-app' => _RouteKind.openApp,
      'download' => _RouteKind.download,
      _ => _fail('不支持的 --route=`$value`。允许值：landing, open-app, download。', 64),
    };
  }

  String pathForToken(String token) {
    return switch (this) {
      _RouteKind.landing => '/share/$token',
      _RouteKind.openApp => '/share/$token/open-app',
      _RouteKind.download => '/share/$token/download',
    };
  }
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
  dart run tool/verify_s02_share.dart [--smoke --base-url=<url> --token=<token> [其它参数]]

说明：
  默认只检查 S02 growth share proof pack 的必需文件是否存在：
    - docs/runbooks/s02-growth-share.md
    - backend/src/main/resources/sql/s02_share_landing_queries.sql
    - backend/src/main/resources/db/migration/V6__create_share_landing_tables.sql
    - backend/src/test/java/com/zhangspaghetti/babytalk/web/ShareLinkApiWebTest.java
    - backend/src/test/java/com/zhangspaghetti/babytalk/web/ShareLandingWebTest.java
    - mobile/test/app/share_reentry_coordinator_test.dart

  --smoke                           从仓库根对 public share surface 发起一次 HTTP smoke
  --base-url=<url>                  必填（仅在 --smoke 时），例如 http://127.0.0.1:8080
  --token=<value>                   必填（仅在 --smoke 时），例如 share_token_1234
  --route=<value>                   landing | open-app | download，默认 landing
  --platform=<value>                可选；android / ios。open-app / download 默认 android
                                    传 skip 或 - 可显式跳过 platform 参数
  --expect-status=<code>            预期 HTTP 状态码；默认 landing=200，open-app/download=302
  --expect-result=<value>           预期 X-Share-Landing-Result；默认按 route 推导
                                    传 skip 或 - 可跳过该断言
  --expect-body=<text>              可选，要求响应体包含指定文案
  --expect-location-contains=<text> 可选，要求 Location 头包含指定文案
                                    默认 open-app=babytalk://share/open
                                    默认 download=/download?source=share_card
                                    传 skip 或 - 可跳过该断言
  --timeout-seconds=<n>             单次 smoke 超时秒数，默认 10
  --help, -h                        显示帮助

失败合同：
  - 缺文件、缺 --base-url / --token 或参数非法：exit code 64
  - backend 不可达：返回非 0，并提示先执行 `mvn -f backend/pom.xml spring-boot:run`
  - smoke 超时：exit code 124

redaction 红线：
  这个 wrapper 只围绕 /share/{token}、/share/{token}/open-app、/share/{token}/download、
  share_landing_events 与 release_distribution_events(source=share_card) 的 coarse-grained surface
  做存在性与可达性验证；不要把 installation/account/child、eventKey、fallbackReason、
  warning/debug 文案混进命令输出或后续扩展中。
''';

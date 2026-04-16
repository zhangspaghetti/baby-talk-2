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
    'docs/runbooks/s01-release-distribution.md',
    'backend/src/main/resources/sql/s01_release_distribution_queries.sql',
    'backend/src/main/resources/db/migration/V5__create_release_distribution_tables.sql',
    'backend/src/test/java/com/zhangspaghetti/babytalk/web/DistributionPageWebTest.java',
    'backend/pom.xml',
  ]);

  if (!options.runSmoke) {
    stdout.writeln('✅ S01 release distribution proof pack 文件检查通过。');
    stdout.writeln('如需验证 public page，可追加 --smoke --base-url=http://127.0.0.1:8080。');
    return;
  }

  if (options.baseUrl == null) {
    _fail('执行 --smoke 时必须提供 --base-url，例如 http://127.0.0.1:8080', 64);
  }

  final request = options.toSmokeRequest();
  await _runSmoke(request);
}

Future<void> _runSmoke(_SmokeRequest request) async {
  final uri = request.uri;
  stdout.writeln('==> S01 distribution smoke');
  stdout.writeln('    GET $uri');
  stdout.writeln(
    '    expect: status=${request.expectStatus}, '
    'result=${request.expectResult ?? '(skip)'}, '
    'body=${request.expectBody == null ? '(skip)' : 'contains `${request.expectBody}`'}',
  );

  final client = HttpClient()..connectionTimeout = request.timeout;

  try {
    final httpRequest = await client.getUrl(uri).timeout(request.timeout);
    httpRequest.followRedirects = false;
    httpRequest.headers.set(
      HttpHeaders.userAgentHeader,
      _userAgentForPlatform(request.platform),
    );

    final response = await httpRequest.close().timeout(request.timeout);
    final body = await utf8.decodeStream(response).timeout(request.timeout);
    final resultHeader = response.headers.value(
      'x-release-distribution-result',
    );
    final auditHeader = response.headers.value('x-release-distribution-audit');
    final locationHeader = response.headers.value(HttpHeaders.locationHeader);

    stdout.writeln('    status: ${response.statusCode}');
    stdout.writeln('    result header: ${resultHeader ?? '(missing)'}');
    stdout.writeln('    audit header: ${auditHeader ?? '(missing)'}');
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
        'smoke 失败：预期 X-Release-Distribution-Result=${request.expectResult}，实际为 ${resultHeader ?? '(missing)'}。',
        1,
      );
    }

    if (request.expectBody != null && !body.contains(request.expectBody!)) {
      _fail('smoke 失败：响应体未包含 `${request.expectBody}`。', 1);
    }

    stdout.writeln('✅ S01 distribution smoke 通过。');
  } on TimeoutException {
    _fail(
      '连接 `$uri` 超时。请确认 backend 已启动，或先执行 `mvn -f backend/pom.xml spring-boot:run`。',
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

  stderr.writeln('S01 release distribution proof pack 缺少必要文件：');
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
    'android' => 'Mozilla/5.0 (Linux; Android 14) BabyTalkVerify/1.0',
    'ios' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) BabyTalkVerify/1.0',
    _ => 'BabyTalkVerify/1.0',
  };
}

String _defaultSourceForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.download || _RouteKind.downloadRedirect => 'public_link',
    _RouteKind.upgrade || _RouteKind.upgradeRedirect => 'version_gate',
  };
}

int _defaultStatusForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.download || _RouteKind.upgrade => 200,
    _RouteKind.downloadRedirect || _RouteKind.upgradeRedirect => 302,
  };
}

String _defaultResultForRoute(_RouteKind route) {
  return switch (route) {
    _RouteKind.download || _RouteKind.upgrade => 'page_view',
    _RouteKind.downloadRedirect || _RouteKind.upgradeRedirect => 'redirect',
  };
}

class _CliOptions {
  const _CliOptions({
    required this.showHelp,
    required this.runSmoke,
    required this.baseUrl,
    required this.route,
    required this.channel,
    required this.source,
    required this.platform,
    required this.expectStatus,
    required this.expectResult,
    required this.expectBody,
    required this.timeout,
  });

  final bool showHelp;
  final bool runSmoke;
  final Uri? baseUrl;
  final _RouteKind route;
  final String channel;
  final String? source;
  final String? platform;
  final int expectStatus;
  final String? expectResult;
  final String? expectBody;
  final Duration timeout;

  _SmokeRequest toSmokeRequest() {
    final resolvedSource = source ?? _defaultSourceForRoute(route);
    final queryParameters = <String, String>{
      'channel': channel,
      'source': resolvedSource,
    };
    if (platform != null) {
      queryParameters['platform'] = platform!;
    }

    final uri = baseUrl!.replace(
      path: _joinPath(baseUrl!.path, route.path),
      queryParameters: queryParameters,
    );

    return _SmokeRequest(
      uri: uri,
      platform: platform,
      expectStatus: expectStatus,
      expectResult: expectResult,
      expectBody: expectBody,
      timeout: timeout,
    );
  }

  static _CliOptions parse(List<String> args) {
    var showHelp = false;
    var runSmoke = false;
    var sawSmokeSpecificArg = false;
    Uri? baseUrl;
    var route = _RouteKind.download;
    var channel = 'stable';
    String? source;
    String? platform;
    int? expectStatus;
    String? expectResult;
    var hasExpectResult = false;
    String? expectBody;
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
      if (arg.startsWith('--channel=')) {
        sawSmokeSpecificArg = true;
        channel = _normalizeRequiredValue(
          arg.substring('--channel='.length),
          'channel',
        );
        continue;
      }
      if (arg == '--channel') {
        sawSmokeSpecificArg = true;
        channel = _normalizeRequiredValue(_nextValue(iterator, arg), 'channel');
        continue;
      }
      if (arg.startsWith('--source=')) {
        sawSmokeSpecificArg = true;
        source = _normalizeRequiredValue(
          arg.substring('--source='.length),
          'source',
        );
        continue;
      }
      if (arg == '--source') {
        sawSmokeSpecificArg = true;
        source = _normalizeRequiredValue(_nextValue(iterator, arg), 'source');
        continue;
      }
      if (arg.startsWith('--platform=')) {
        sawSmokeSpecificArg = true;
        platform = _normalizeRequiredValue(
          arg.substring('--platform='.length),
          'platform',
        );
        continue;
      }
      if (arg == '--platform') {
        sawSmokeSpecificArg = true;
        platform = _normalizeRequiredValue(_nextValue(iterator, arg), 'platform');
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
        expectResult = _normalizeExpectationValue(
          arg.substring('--expect-result='.length),
          'expect-result',
        );
        continue;
      }
      if (arg == '--expect-result') {
        sawSmokeSpecificArg = true;
        hasExpectResult = true;
        expectResult = _normalizeExpectationValue(
          _nextValue(iterator, arg),
          'expect-result',
        );
        continue;
      }
      if (arg.startsWith('--expect-body=')) {
        sawSmokeSpecificArg = true;
        expectBody = _normalizeRequiredValue(
          arg.substring('--expect-body='.length),
          'expect-body',
        );
        continue;
      }
      if (arg == '--expect-body') {
        sawSmokeSpecificArg = true;
        expectBody = _normalizeRequiredValue(
          _nextValue(iterator, arg),
          'expect-body',
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
      _fail('未知参数：$arg\n\n$_usage', 64);
    }

    if (sawSmokeSpecificArg && !runSmoke && !showHelp) {
      _fail('检测到 smoke 参数，但缺少 --smoke。请显式添加 --smoke 后再执行。', 64);
    }

    return _CliOptions(
      showHelp: showHelp,
      runSmoke: runSmoke,
      baseUrl: baseUrl,
      route: route,
      channel: channel,
      source: source,
      platform: platform,
      expectStatus: expectStatus ?? _defaultStatusForRoute(route),
      expectResult: hasExpectResult
          ? expectResult
          : _defaultResultForRoute(route),
      expectBody: expectBody,
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
    required this.timeout,
  });

  final Uri uri;
  final String? platform;
  final int expectStatus;
  final String? expectResult;
  final String? expectBody;
  final Duration timeout;
}

enum _RouteKind {
  download('/download'),
  upgrade('/upgrade'),
  downloadRedirect('/download/redirect'),
  upgradeRedirect('/upgrade/redirect');

  const _RouteKind(this.path);

  final String path;

  static _RouteKind parse(String value) {
    return switch (value.trim()) {
      'download' => _RouteKind.download,
      'upgrade' => _RouteKind.upgrade,
      'download-redirect' => _RouteKind.downloadRedirect,
      'upgrade-redirect' => _RouteKind.upgradeRedirect,
      _ => _fail(
        '不支持的 --route=`$value`。允许值：download, upgrade, download-redirect, upgrade-redirect。',
        64,
      ),
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

String? _normalizeExpectationValue(String rawValue, String optionName) {
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
  final normalizedBase = basePath.trim().endsWith('/')
      ? basePath.trim().substring(0, basePath.trim().length - 1)
      : basePath.trim();
  if (normalizedBase.isEmpty || normalizedBase == '/') {
    return routePath;
  }
  return '$normalizedBase$routePath';
}

const String _usage = '''用法：
  dart run tool/verify_s01_distribution.dart [--smoke --base-url=<url> [其它参数]]

说明：
  默认只检查 S01 release distribution proof pack 的必需文件是否存在：
    - docs/runbooks/s01-release-distribution.md
    - backend/src/main/resources/sql/s01_release_distribution_queries.sql
    - backend/src/main/resources/db/migration/V5__create_release_distribution_tables.sql
    - backend/src/test/java/com/zhangspaghetti/babytalk/web/DistributionPageWebTest.java

  --smoke                 从仓库根对 public page / redirect 发起一次 HTTP smoke
  --base-url=<url>        必填（仅在 --smoke 时），例如 http://127.0.0.1:8080
  --route=<value>         download | upgrade | download-redirect | upgrade-redirect
                          默认：download
  --channel=<value>       release channel，默认 stable
  --source=<value>        入口来源；默认按 route 推导：download=public_link，upgrade=version_gate
  --platform=<value>      可选，常用 android / ios
  --expect-status=<code>  预期 HTTP 状态码；默认按 route 推导（page=200，redirect=302）
  --expect-result=<value> 预期 X-Release-Distribution-Result；默认按 route 推导
                          传 skip 或 - 可跳过该断言
  --expect-body=<text>    可选，要求响应体包含指定文案
  --timeout-seconds=<n>   单次 smoke 超时秒数，默认 10
  --help, -h              显示帮助

示例：
  dart run tool/verify_s01_distribution.dart --help

  dart run tool/verify_s01_distribution.dart \
    --smoke \
    --base-url=http://127.0.0.1:8080 \
    --route=download \
    --channel=stable \
    --source=public_link \
    --expect-status=200 \
    --expect-result=page_view \
    --expect-body="下载 Baby Talk"

  dart run tool/verify_s01_distribution.dart \
    --smoke \
    --base-url=http://127.0.0.1:8080 \
    --route=upgrade \
    --channel=stable \
    --source=version_gate \
    --expect-status=200 \
    --expect-result=page_view \
    --expect-body="升级 Baby Talk"

失败合同：
  - 缺文件、缺 --base-url 或参数非法：exit code 64
  - backend 不可达：返回非 0，并提示先执行 `mvn -f backend/pom.xml spring-boot:run`
  - smoke 超时：exit code 124

redaction 红线：
  这个 wrapper 只围绕 /download、/upgrade、release_distribution_events 的 coarse-grained surface
  做存在性与可达性验证；不要把 session、手机号、验证码、宝宝资料或原始 prompt/response
  混进命令输出或后续扩展中。
''';

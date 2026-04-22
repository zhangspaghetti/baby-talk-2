/// 委托测试文件：gate 从 worktree 根运行 `flutter test test/smoke/` 时
/// 本文件作为入口，将实际测试委托给 mobile/ 子工程的 smoke 测试。
///
/// 背景（KNOWLEDGE 条目）：
/// - Windows 上 `flutter test test/smoke/` 并行默认只跑第一个文件
/// - gate 从 worktree 根运行时找不到 pubspec.yaml — 本文件解决该问题
/// - mobile/dart_test.yaml 设置 concurrency:1 确保所有三个 smoke 文件都运行
library;

import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('mobile/test/smoke/ — 所有 smoke 测试通过', () async {
    // Directory.current 即 flutter test 运行时的 cwd（worktree 根）
    final mobileDir = Directory('${Directory.current.path}/mobile');

    if (!mobileDir.existsSync()) {
      // fallback: 尝试从脚本位置计算
      final altMobile =
          Directory('${Directory.current.path}/../../../mobile');
      if (altMobile.existsSync()) {
        await _runMobileTests(altMobile);
        return;
      }
      fail('找不到 mobile/ 目录：${mobileDir.path}');
    }

    await _runMobileTests(mobileDir);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _runMobileTests(Directory mobileDir) async {
  // 使用 flutter.bat (Windows) 或系统 flutter
  final flutterExe = Platform.isWindows ? 'flutter.bat' : 'flutter';

  final result = await Process.run(
    flutterExe,
    ['test', 'test/smoke/', '--concurrency=1'],
    workingDirectory: mobileDir.path,
    runInShell: true,
  );

  // 打印输出便于 gate 日志分析
  if (result.stdout.toString().isNotEmpty) {
    print(result.stdout);
  }
  if (result.stderr.toString().isNotEmpty) {
    print('stderr: ${result.stderr}');
  }

  expect(
    result.exitCode,
    0,
    reason: 'mobile smoke 测试失败 (exit code ${result.exitCode})',
  );
}

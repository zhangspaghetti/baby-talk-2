import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:path_provider/path_provider.dart';

typedef OnboardingDirectoryResolver = Future<Directory> Function();

class OnboardingSnapshotPersistenceException implements Exception {
  const OnboardingSnapshotPersistenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OnboardingSnapshotStore {
  OnboardingSnapshotStore({
    OnboardingDirectoryResolver? directoryResolver,
    this.fileName = 'onboarding_snapshot.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final OnboardingDirectoryResolver _directoryResolver;
  final String fileName;

  static const _obsoleteArtifactNames = <String>[
    'onboarding_flow_snapshot.json',
    'onboarding_flow_snapshot.json.tmp',
    'onboarding_flow_snapshot.m1_quarantine.json',
    'onboarding_snapshot.m1_quarantine.json',
  ];

  Future<OnboardingSnapshot?> read() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        throw const FormatException('onboarding snapshot 为空。');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('onboarding snapshot 顶层必须是对象。');
      }
      return OnboardingSnapshot.fromJsonMap(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw OnboardingSnapshotPersistenceException(
        '读取 onboarding snapshot 失败：$error',
      );
    }
  }

  Future<void> write(OnboardingSnapshot snapshot) async {
    try {
      final file = await _resolveFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshot.toJsonMap()), flush: true);
    } catch (error) {
      throw OnboardingSnapshotPersistenceException(
        '写入 onboarding snapshot 失败：$error',
      );
    }
  }

  Future<void> deleteIfExists() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      throw OnboardingSnapshotPersistenceException(
        '清理 onboarding snapshot 失败：$error',
      );
    }
  }

  Future<void> deleteAllArtifacts() async {
    try {
      final snapshot = await _resolveFile();
      final files = <File>[
        snapshot,
        for (final name in _obsoleteArtifactNames)
          File('${snapshot.parent.path}${Platform.pathSeparator}$name'),
      ];
      for (final file in files) {
        if (await file.exists()) await file.delete();
      }
    } catch (error) {
      throw OnboardingSnapshotPersistenceException(
        '清理 onboarding 本地状态失败：$error',
      );
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
}

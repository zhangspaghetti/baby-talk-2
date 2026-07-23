import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:path_provider/path_provider.dart';

typedef OnboardingFlowDirectoryResolver = Future<Directory> Function();

class OnboardingFlowPersistenceException implements Exception {
  const OnboardingFlowPersistenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OnboardingFlowStore {
  OnboardingFlowStore({
    OnboardingFlowDirectoryResolver? directoryResolver,
    this.fileName = 'onboarding_flow_snapshot.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final OnboardingFlowDirectoryResolver _directoryResolver;
  final String fileName;

  Future<OnboardingFlowSnapshot?> read() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        throw const FormatException('onboarding flow snapshot 为空。');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('onboarding flow snapshot 顶层必须是对象。');
      }
      return OnboardingFlowSnapshot.fromJsonMap(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw OnboardingFlowPersistenceException(
        '读取 onboarding flow snapshot 失败：$error',
      );
    }
  }

  Future<void> write(OnboardingFlowSnapshot snapshot) async {
    try {
      final file = await _resolveFile();
      final temporaryFile = File('${file.path}.tmp');
      await file.parent.create(recursive: true);
      await temporaryFile.writeAsString(
        jsonEncode(snapshot.toJsonMap()),
        flush: true,
      );
      if (Platform.isWindows && await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } catch (error) {
      throw OnboardingFlowPersistenceException(
        '写入 onboarding flow snapshot 失败：$error',
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
      throw OnboardingFlowPersistenceException(
        '清理 onboarding flow snapshot 失败：$error',
      );
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
}

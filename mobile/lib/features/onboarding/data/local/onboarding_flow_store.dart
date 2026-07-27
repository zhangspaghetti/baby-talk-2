import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  Future<void> _mutationTail = Future<void>.value();

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

  Future<void> write(OnboardingFlowSnapshot snapshot) {
    return _enqueueMutation(() => _writeInternal(snapshot));
  }

  Future<void> _writeInternal(OnboardingFlowSnapshot snapshot) async {
    File? flowFile;
    File? temporaryFile;
    try {
      flowFile = await _resolveFile();
      temporaryFile = File('${flowFile.path}.tmp');
      await flowFile.parent.create(recursive: true);
      await _deleteFileIfExists(temporaryFile);
      await temporaryFile.writeAsString(
        jsonEncode(snapshot.toJsonMap()),
        flush: true,
      );
      if (Platform.isWindows && await flowFile.exists()) {
        await flowFile.delete();
      }
      await temporaryFile.rename(flowFile.path);
    } catch (error) {
      await _recordWriteFailure(
        flowFile: flowFile,
        temporaryFile: temporaryFile,
        requestedSnapshot: snapshot,
        error: error,
      );
      if (temporaryFile != null) {
        try {
          await _deleteFileIfExists(temporaryFile);
        } catch (_) {}
      }
      throw OnboardingFlowPersistenceException(
        '写入 onboarding flow snapshot 失败：$error',
      );
    }
  }

  Future<void> _recordWriteFailure({
    required File? flowFile,
    required File? temporaryFile,
    required OnboardingFlowSnapshot requestedSnapshot,
    required Object error,
  }) async {
    if (!kDebugMode) {
      return;
    }
    var flowExists = false;
    var temporaryExists = false;
    String persistedStarter = 'unavailable';
    try {
      if (flowFile case final file?) {
        flowExists = await file.exists();
      }
      if (temporaryFile case final file?) {
        temporaryExists = await file.exists();
      }
      if (flowFile case final file? when flowExists) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          final phraseId = decoded['starterPhraseId']?.toString().trim();
          persistedStarter = phraseId?.isNotEmpty == true
              ? 'present'
              : 'absent';
        }
      }
    } catch (_) {}
    final requestedStarter =
        requestedSnapshot.starterPhraseId?.trim().isNotEmpty == true;
    debugPrint(
      'onboarding_flow_write '
      'stage=failed '
      'flowExists=$flowExists '
      'temporaryExists=$temporaryExists '
      'persistedStarter=$persistedStarter '
      'requestedStarter=$requestedStarter '
      'failureType=${error.runtimeType}',
    );
  }

  Future<void> deleteIfExists() {
    return _enqueueMutation(_deleteIfExistsInternal);
  }

  Future<void> _deleteIfExistsInternal() async {
    Object? firstError;
    try {
      final file = await _resolveFile();
      final files = <File>[file, File('${file.path}.tmp')];
      for (final candidate in files) {
        try {
          await _deleteFileIfExists(candidate);
        } catch (error) {
          firstError ??= error;
        }
      }
      if (firstError != null) {
        throw firstError;
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

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_) {});
    return running;
  }
}

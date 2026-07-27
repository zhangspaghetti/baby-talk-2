import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/account/domain/models/auth_continuation.dart';
import 'package:path_provider/path_provider.dart';

typedef AuthContinuationDirectoryResolver = Future<Directory> Function();

enum AuthContinuationReadStatus {
  notFound,
  expired,
  available,
  corrupt,
  ioFailure,
}

class AuthContinuationReadResult {
  const AuthContinuationReadResult({required this.status, this.continuation});

  final AuthContinuationReadStatus status;
  final AuthContinuation? continuation;
}

class AuthContinuationStore {
  AuthContinuationStore({
    AuthContinuationDirectoryResolver? directoryResolver,
    this.fileName = 'auth_continuation.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final AuthContinuationDirectoryResolver _directoryResolver;
  final String fileName;

  Future<void> _mutationTail = Future<void>.value();

  Future<AuthContinuation?> read({required DateTime now}) async {
    return (await readResult(now: now)).continuation;
  }

  Future<AuthContinuationReadResult> readResult({required DateTime now}) {
    return _enqueueMutation(() => _readResult(now: now));
  }

  Future<AuthContinuationReadResult> _readResult({
    required DateTime now,
  }) async {
    final File file;
    try {
      file = await _resolveFile();
      if (!await file.exists()) {
        return const AuthContinuationReadResult(
          status: AuthContinuationReadStatus.notFound,
        );
      }
    } on FileSystemException {
      return const AuthContinuationReadResult(
        status: AuthContinuationReadStatus.ioFailure,
      );
    } catch (_) {
      return const AuthContinuationReadResult(
        status: AuthContinuationReadStatus.ioFailure,
      );
    }

    final String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException {
      return const AuthContinuationReadResult(
        status: AuthContinuationReadStatus.ioFailure,
      );
    } catch (_) {
      return const AuthContinuationReadResult(
        status: AuthContinuationReadStatus.ioFailure,
      );
    }

    try {
      if (raw.trim().isEmpty) {
        throw const FormatException('Auth continuation is empty.');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Auth continuation root must be an object.',
        );
      }
      final continuation = AuthContinuation.fromJsonMap(decoded);
      if (!continuation.expiresAt.isAfter(now.toUtc())) {
        await _deleteFilesBestEffort(file);
        return const AuthContinuationReadResult(
          status: AuthContinuationReadStatus.expired,
        );
      }
      return AuthContinuationReadResult(
        status: AuthContinuationReadStatus.available,
        continuation: continuation,
      );
    } catch (_) {
      await _deleteFilesBestEffort(file);
      return const AuthContinuationReadResult(
        status: AuthContinuationReadStatus.corrupt,
      );
    }
  }

  Future<void> write(AuthContinuation continuation) {
    return _enqueueMutation(() => _write(continuation));
  }

  Future<void> _write(AuthContinuation continuation) async {
    File? temporaryFile;
    try {
      final file = await _resolveFile();
      temporaryFile = File('${file.path}.tmp');
      await file.parent.create(recursive: true);
      await _deleteFileIfExists(temporaryFile);
      await temporaryFile.writeAsString(
        jsonEncode(continuation.toJsonMap()),
        flush: true,
      );
      if (Platform.isWindows && await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } catch (error) {
      if (temporaryFile != null) {
        try {
          await _deleteFileIfExists(temporaryFile);
        } catch (_) {}
      }
      throw AuthContinuationStoreException(
        'Writing auth continuation failed: $error',
      );
    }
  }

  Future<void> deleteIfExists() {
    return _enqueueMutation(_deleteIfExists);
  }

  Future<void> _deleteIfExists() async {
    final file = await _resolveFile();
    await _deleteFiles(file);
  }

  Future<void> _deleteFiles(File file) async {
    await _deleteFileIfExists(file);
    await _deleteFileIfExists(File('${file.path}.tmp'));
  }

  Future<void> _deleteFilesBestEffort(File file) async {
    try {
      await _deleteFiles(file);
    } catch (_) {}
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
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
}

class AuthContinuationStoreException implements Exception {
  const AuthContinuationStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

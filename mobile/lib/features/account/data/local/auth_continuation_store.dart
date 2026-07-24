import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/account/domain/models/auth_continuation.dart';
import 'package:path_provider/path_provider.dart';

typedef AuthContinuationDirectoryResolver = Future<Directory> Function();

class AuthContinuationStore {
  AuthContinuationStore({
    AuthContinuationDirectoryResolver? directoryResolver,
    this.fileName = 'auth_continuation.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final AuthContinuationDirectoryResolver _directoryResolver;
  final String fileName;

  Future<AuthContinuation?> read({required DateTime now}) async {
    File? file;
    try {
      file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        throw const FormatException('Auth continuation is empty.');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Auth continuation root must be an object.');
      }
      final continuation = AuthContinuation.fromJsonMap(decoded);
      if (!continuation.expiresAt.isAfter(now.toUtc())) {
        await deleteIfExists();
        return null;
      }
      return continuation;
    } catch (_) {
      if (file != null) {
        await _deleteFileIfExists(file);
        await _deleteFileIfExists(File('${file.path}.tmp'));
      }
      return null;
    }
  }

  Future<void> write(AuthContinuation continuation) async {
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

  Future<void> deleteIfExists() async {
    final file = await _resolveFile();
    await _deleteFileIfExists(file);
    await _deleteFileIfExists(File('${file.path}.tmp'));
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

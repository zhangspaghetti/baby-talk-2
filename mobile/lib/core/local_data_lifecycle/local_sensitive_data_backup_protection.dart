import 'dart:io';

import 'package:flutter/services.dart';

typedef LocalSensitiveDataBackupNativeExcluder =
    Future<bool> Function(String directoryPath);

typedef LocalSensitiveDataBackupPlatformProbe = bool Function();

class LocalSensitiveDataBackupProtectionException implements Exception {
  const LocalSensitiveDataBackupProtectionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'LocalSensitiveDataBackupProtectionException: $message'
        : 'LocalSensitiveDataBackupProtectionException: $message ($cause)';
  }
}

class LocalSensitiveDataBackupProtection {
  const LocalSensitiveDataBackupProtection({
    LocalSensitiveDataBackupPlatformProbe? requiresNativeExclusion,
    LocalSensitiveDataBackupNativeExcluder? nativeExcluder,
  }) : _requiresNativeExclusion =
           requiresNativeExclusion ?? _defaultRequiresNativeExclusion,
       _nativeExcluder = nativeExcluder ?? _excludeDirectoryWithNativeChannel;

  static const MethodChannel _channel = MethodChannel(
    'baby_talk/local_sensitive_data_backup',
  );

  final LocalSensitiveDataBackupPlatformProbe _requiresNativeExclusion;
  final LocalSensitiveDataBackupNativeExcluder _nativeExcluder;

  Future<Directory> ensureDirectoryExcludedFromBackupIfRequired(
    Directory directory,
  ) async {
    if (!_requiresNativeExclusion()) {
      return directory;
    }

    try {
      final excluded = await _nativeExcluder(directory.path);
      if (!excluded) {
        throw const LocalSensitiveDataBackupProtectionException(
          '原生备份排除接口未确认敏感目录已排除。',
        );
      }
      return directory;
    } on LocalSensitiveDataBackupProtectionException {
      rethrow;
    } catch (error) {
      throw LocalSensitiveDataBackupProtectionException('设置敏感目录备份排除失败。', error);
    }
  }

  static bool _defaultRequiresNativeExclusion() {
    return Platform.isIOS;
  }

  static Future<bool> _excludeDirectoryWithNativeChannel(
    String directoryPath,
  ) async {
    final result = await _channel.invokeMethod<bool>('excludeFromBackup', {
      'path': directoryPath,
    });
    return result ?? false;
  }
}

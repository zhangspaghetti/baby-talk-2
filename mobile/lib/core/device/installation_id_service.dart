import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

typedef InstallationDirectoryResolver = Future<Directory> Function();
typedef InstallationIdGenerator = String Function();

final RegExp _safeInstallationIdPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$',
);
final RegExp _phoneLikeInstallationIdPattern = RegExp(r'[0-9]{11,}');

bool isBackendCompatibleInstallationId(String value) {
  final normalized = value.trim();
  return _safeInstallationIdPattern.hasMatch(normalized) &&
      !_phoneLikeInstallationIdPattern.hasMatch(normalized);
}

class InstallationIdService {
  InstallationIdService({
    InstallationDirectoryResolver? directoryResolver,
    InstallationIdGenerator? idGenerator,
    this.fileName = 'installation_id.txt',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory,
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final InstallationDirectoryResolver _directoryResolver;
  final InstallationIdGenerator _idGenerator;
  final String fileName;

  Future<String> getOrCreate() async {
    final file = await _resolveFile();
    if (await file.exists()) {
      final value = (await file.readAsString()).trim();
      if (isBackendCompatibleInstallationId(value)) {
        return value;
      }
    }

    final installationId = _idGenerator().trim();
    if (!isBackendCompatibleInstallationId(installationId)) {
      throw StateError('installation id generator returned an unsupported ID');
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(installationId, flush: true);
    return installationId;
  }

  Future<String?> readExisting() async {
    final file = await _resolveFile();
    if (!await file.exists()) {
      return null;
    }

    final value = (await file.readAsString()).trim();
    return isBackendCompatibleInstallationId(value) ? value : null;
  }

  Future<void> deleteIfExists() async {
    final file = await _resolveFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  static String _defaultIdGenerator() {
    final random = Random();
    final encodedEpoch = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(36);
    final splitAt = encodedEpoch.length > 8 ? encodedEpoch.length - 8 : 0;
    final safeEpoch = splitAt == 0
        ? encodedEpoch
        : '${encodedEpoch.substring(0, splitAt)}_'
              '${encodedEpoch.substring(splitAt)}';
    final entropy = List.generate(
      4,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join('_');
    return 'install_${safeEpoch}_$entropy';
  }
}

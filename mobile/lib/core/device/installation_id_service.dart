import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

typedef InstallationDirectoryResolver = Future<Directory> Function();
typedef InstallationIdGenerator = String Function();

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
      if (value.isNotEmpty) {
        return value;
      }
    }

    final installationId = _idGenerator();
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
    return value.isEmpty ? null : value;
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  static String _defaultIdGenerator() {
    final random = Random();
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entropy = List.generate(
      4,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join();
    return 'install_${timestamp}_$entropy';
  }
}

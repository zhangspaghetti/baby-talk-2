import 'dart:convert';
import 'dart:io';

import 'package:mobile/app/app_reentry_orchestrator.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';

typedef OnboardingV4DirectoryResolver = Future<Directory> Function();
typedef OnboardingV4MigrationClock = DateTime Function();

final class OnboardingV4Migration {
  OnboardingV4Migration({
    required OnboardingV4DirectoryResolver directoryResolver,
    required OnboardingConversationRepository conversationRepository,
    required OnboardingV4MigrationClock clock,
    this.legacyFlowFileName = 'onboarding_flow_snapshot.json',
    this.flowQuarantineFileName = 'onboarding_flow_snapshot.m1_quarantine.json',
    this.legacySnapshotFileName = 'onboarding_snapshot.json',
    this.snapshotQuarantineFileName = 'onboarding_snapshot.m1_quarantine.json',
  }) : _directoryResolver = directoryResolver,
       _conversationRepository = conversationRepository,
       _clock = clock;

  final OnboardingV4DirectoryResolver _directoryResolver;
  final OnboardingConversationRepository _conversationRepository;
  final OnboardingV4MigrationClock _clock;
  final String legacyFlowFileName;
  final String flowQuarantineFileName;
  final String legacySnapshotFileName;
  final String snapshotQuarantineFileName;

  Future<OnboardingConversationSnapshot?> run({
    required OnboardingSnapshot? legacySnapshot,
  }) async {
    var current = await _conversationRepository.read();
    final legacy = await _readLegacyFlow();
    final legacyFlowCompleted = legacy?.isCompleted == true;
    if (current == null &&
        (legacySnapshot?.isCompleted == true || legacyFlowCompleted)) {
      final completedAt =
          legacySnapshot?.completedAt ?? legacy?.updatedAt ?? _clock().toUtc();
      current = await _conversationRepository.save(
        OnboardingConversationSnapshot.legacyCompleted(
          completedAt: completedAt,
        ),
      );
    }
    if (legacySnapshot != null) {
      if (legacySnapshot.isCompleted) {
        await _deleteLegacyFile(legacySnapshotFileName);
      } else {
        await _quarantineAndDelete(
          sourceFileName: legacySnapshotFileName,
          quarantineFileName: snapshotQuarantineFileName,
          sourceSchemaVersion: legacySnapshot.schemaVersion,
        );
      }
    }
    if (legacy != null) {
      if (legacyFlowCompleted) {
        await _deleteLegacyFile(legacyFlowFileName);
      } else {
        await _quarantineAndDelete(
          sourceFileName: legacyFlowFileName,
          quarantineFileName: flowQuarantineFileName,
          sourceSchemaVersion: legacy.sourceSchemaVersion,
        );
      }
    }
    return current;
  }

  Future<_LegacyFlow?> _readLegacyFlow() async {
    final directory = await _directoryResolver();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$legacyFlowFileName',
    );
    if (!await file.exists()) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on Object {
      return const _LegacyFlow(sourceSchemaVersion: 'unknown');
    }
    if (decoded is! Map) {
      return const _LegacyFlow(sourceSchemaVersion: 'unknown');
    }
    final schemaVersion = decoded['schemaVersion'];
    final step = decoded['step'];
    final trace = decoded['traceEventKey'];
    final updatedAtRaw = decoded['updatedAt'];
    final updatedAt = updatedAtRaw is String
        ? DateTime.tryParse(updatedAtRaw)?.toUtc()
        : null;
    return _LegacyFlow(
      sourceSchemaVersion: schemaVersion is int ? schemaVersion : 'unknown',
      isCompleted:
          schemaVersion == 1 &&
          step == 'completing' &&
          trace is String &&
          trace.trim().isNotEmpty,
      updatedAt: updatedAt,
    );
  }

  Future<void> _quarantineAndDelete({
    required String sourceFileName,
    required String quarantineFileName,
    required Object sourceSchemaVersion,
  }) async {
    final directory = await _directoryResolver();
    final quarantine = File(
      '${directory.path}${Platform.pathSeparator}$quarantineFileName',
    );
    final temporary = File('${quarantine.path}.tmp');
    await directory.create(recursive: true);
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'reasonCode': 'legacy_m1_in_progress',
        'sourceSchemaVersion': sourceSchemaVersion,
        'quarantinedAt': _clock().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    if (Platform.isWindows && await quarantine.exists()) {
      await quarantine.delete();
    }
    await temporary.rename(quarantine.path);
    await _deleteLegacyFile(sourceFileName);
  }

  Future<void> _deleteLegacyFile(String fileName) async {
    final directory = await _directoryResolver();
    final legacy = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (await legacy.exists()) await legacy.delete();
    final temporary = File('${legacy.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  }
}

AppLaunchDestination resolveOnboardingLaunchDestination({
  required OnboardingSnapshot? completedSnapshot,
  required OnboardingConversationSnapshot? conversationSnapshot,
  bool hasExistingCareActivity = false,
}) {
  if (hasExistingCareActivity ||
      completedSnapshot != null ||
      conversationSnapshot?.status == OnboardingConversationStatus.deferred ||
      conversationSnapshot?.status == OnboardingConversationStatus.completed) {
    return AppLaunchDestination.shell;
  }
  return AppLaunchDestination.onboarding;
}

final class _LegacyFlow {
  const _LegacyFlow({
    required this.sourceSchemaVersion,
    this.isCompleted = false,
    this.updatedAt,
  });

  final Object sourceSchemaVersion;
  final bool isCompleted;
  final DateTime? updatedAt;
}

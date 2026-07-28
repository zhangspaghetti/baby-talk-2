import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';
import 'package:path_provider/path_provider.dart';

typedef CustomSceneDraftDirectoryResolver = Future<Directory> Function();

enum CustomSceneDraftReadStatus {
  notFound,
  expired,
  available,
  corrupt,
  ioFailure,
}

class CustomSceneDraftReadResult {
  const CustomSceneDraftReadResult({required this.status, this.draft});

  final CustomSceneDraftReadStatus status;
  final CustomSceneStoredDraft? draft;
}

class CustomSceneDraftStore {
  CustomSceneDraftStore({
    CustomSceneDraftDirectoryResolver? directoryResolver,
    this.fileName = 'custom_scene_draft.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final CustomSceneDraftDirectoryResolver _directoryResolver;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  Future<CustomSceneStoredDraft?> read({required DateTime now}) async {
    return (await readResult(now: now)).draft;
  }

  Future<CustomSceneDraftReadResult> readResult({required DateTime now}) {
    return _enqueueMutation(() => _readResult(now: now));
  }

  Future<CustomSceneDraftReadResult> _readResult({
    required DateTime now,
  }) async {
    final File file;
    try {
      file = await _resolveFile();
      if (!await file.exists()) {
        return const CustomSceneDraftReadResult(
          status: CustomSceneDraftReadStatus.notFound,
        );
      }
    } on Object {
      return const CustomSceneDraftReadResult(
        status: CustomSceneDraftReadStatus.ioFailure,
      );
    }

    final String raw;
    try {
      raw = await file.readAsString();
    } on Object {
      return const CustomSceneDraftReadResult(
        status: CustomSceneDraftReadStatus.ioFailure,
      );
    }

    try {
      if (raw.trim().isEmpty) {
        throw const FormatException('empty draft');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('draft root is not an object');
      }
      final draft = _decodeStoredDraft(decoded);
      if (!draft.expiresAt.isAfter(now.toUtc())) {
        await _deleteFilesBestEffort(file);
        return const CustomSceneDraftReadResult(
          status: CustomSceneDraftReadStatus.expired,
        );
      }
      return CustomSceneDraftReadResult(
        status: CustomSceneDraftReadStatus.available,
        draft: draft,
      );
    } on Object {
      await _deleteFilesBestEffort(file);
      return const CustomSceneDraftReadResult(
        status: CustomSceneDraftReadStatus.corrupt,
      );
    }
  }

  Future<void> write(CustomSceneStoredDraft draft) {
    return _enqueueMutation(() => _write(draft));
  }

  Future<void> _write(CustomSceneStoredDraft draft) async {
    File? temporaryFile;
    try {
      final file = await _resolveFile();
      temporaryFile = File('${file.path}.tmp');
      await file.parent.create(recursive: true);
      await _deleteFileIfExists(temporaryFile);
      await temporaryFile.writeAsString(
        jsonEncode(_encodeStoredDraft(draft)),
        flush: true,
      );
      if (Platform.isWindows && await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } on Object {
      if (temporaryFile != null) {
        try {
          await _deleteFileIfExists(temporaryFile);
        } on Object {
          // The primary storage failure is the only safe surface here.
        }
      }
      throw const CustomSceneDraftStoreException();
    }
  }

  Future<void> deleteIfExists() {
    return _enqueueMutation(() async {
      final file = await _resolveFile();
      await _deleteFiles(file);
    });
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

  Future<void> _deleteFilesBestEffort(File file) async {
    try {
      await _deleteFiles(file);
    } on Object {
      // Expired/corrupt content is already fail-closed for callers.
    }
  }

  Future<void> _deleteFiles(File file) async {
    await _deleteFileIfExists(file);
    await _deleteFileIfExists(File('${file.path}.tmp'));
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class CustomSceneDraftStoreException implements Exception {
  const CustomSceneDraftStoreException();

  @override
  String toString() => 'Custom scene draft storage unavailable.';
}

Map<String, Object?> _encodeStoredDraft(CustomSceneStoredDraft draft) {
  return <String, Object?>{
    'schemaVersion': 1,
    'draftId': draft.draftId,
    'text': draft.text,
    'entrySource': draft.entrySource.wireValue,
    'clientRequestId': draft.requestIdentity.clientRequestId,
    'state': _stateToWire(draft.state),
    'expectedAccountContext': draft.expectedAccountContext,
    'registeredContentId': draft.registeredContentId,
    'createdAt': draft.createdAt.toUtc().toIso8601String(),
    'expiresAt': draft.expiresAt.toUtc().toIso8601String(),
  };
}

CustomSceneStoredDraft _decodeStoredDraft(Map<String, dynamic> json) {
  _requireExactKeys(json, const <String>{
    'schemaVersion',
    'draftId',
    'text',
    'entrySource',
    'clientRequestId',
    'state',
    'expectedAccountContext',
    'registeredContentId',
    'createdAt',
    'expiresAt',
  });
  if (_requiredInt(json, 'schemaVersion') != 1) {
    throw const FormatException('unsupported custom scene draft schema');
  }
  return CustomSceneStoredDraft(
    draftId: _requiredString(json, 'draftId'),
    text: _requiredString(json, 'text'),
    entrySource: parseCustomSceneEntrySource(
      _requiredString(json, 'entrySource'),
    ),
    requestIdentity: CustomSceneRequestIdentity(
      clientRequestId: _requiredString(json, 'clientRequestId'),
    ),
    state: _stateFromWire(_requiredString(json, 'state')),
    expectedAccountContext: _optionalString(json, 'expectedAccountContext'),
    registeredContentId: _optionalString(json, 'registeredContentId'),
    createdAt: _requiredDateTime(json, 'createdAt'),
    expiresAt: _requiredDateTime(json, 'expiresAt'),
  );
}

String _stateToWire(CustomSceneStoredDraftState state) => switch (state) {
  CustomSceneStoredDraftState.editing => 'editing',
  CustomSceneStoredDraftState.awaitingAuthentication =>
    'awaiting_authentication',
  CustomSceneStoredDraftState.authenticationResolved =>
    'authentication_resolved',
  CustomSceneStoredDraftState.submitting => 'submitting',
  CustomSceneStoredDraftState.unknownOutcome => 'unknown_outcome',
  CustomSceneStoredDraftState.approvedPendingRegistration =>
    'approved_pending_registration',
  CustomSceneStoredDraftState.readyForHandoff => 'ready_for_handoff',
};

CustomSceneStoredDraftState _stateFromWire(String value) => switch (value) {
  'editing' => CustomSceneStoredDraftState.editing,
  'awaiting_authentication' =>
    CustomSceneStoredDraftState.awaitingAuthentication,
  'authentication_resolved' =>
    CustomSceneStoredDraftState.authenticationResolved,
  'submitting' => CustomSceneStoredDraftState.submitting,
  'unknown_outcome' => CustomSceneStoredDraftState.unknownOutcome,
  'approved_pending_registration' =>
    CustomSceneStoredDraftState.approvedPendingRegistration,
  'ready_for_handoff' => CustomSceneStoredDraftState.readyForHandoff,
  _ => throw const FormatException('unknown custom scene draft state'),
};

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException('invalid custom scene draft fields');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('invalid custom scene draft string');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('invalid custom scene draft optional string');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw const FormatException('invalid custom scene draft integer');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw const FormatException('invalid custom scene draft time');
  }
}

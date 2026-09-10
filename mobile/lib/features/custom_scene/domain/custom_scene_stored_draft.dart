import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';

enum CustomSceneStoredDraftState {
  editing,
  awaitingAuthentication,
  authenticationResolved,
  submitting,
  unknownOutcome,
  approvedPendingRegistration,
  readyForHandoff,
}

class CustomSceneStoredDraft {
  CustomSceneStoredDraft({
    required String draftId,
    required String text,
    required this.entrySource,
    required this.requestIdentity,
    required this.state,
    required DateTime createdAt,
    required DateTime expiresAt,
    String? expectedAccountContext,
    String? registeredContentId,
  }) : draftId = _required(draftId, 'draftId'),
       text = _required(text, 'text'),
       createdAt = createdAt.toUtc(),
       expiresAt = expiresAt.toUtc(),
       expectedAccountContext = _optional(expectedAccountContext),
       registeredContentId = _optional(registeredContentId) {
    if (!this.expiresAt.isAfter(this.createdAt)) {
      throw ArgumentError.value(expiresAt, 'expiresAt', '必须晚于 createdAt。');
    }
    if (state == CustomSceneStoredDraftState.readyForHandoff &&
        (this.registeredContentId == null ||
            this.expectedAccountContext == null)) {
      throw ArgumentError.value(
        registeredContentId,
        'registeredContentId',
        'readyForHandoff 必须保存 generated content identity 和账号上下文。',
      );
    }
  }

  final String draftId;
  final String text;
  final CustomSceneEntrySource entrySource;
  final CustomSceneRequestIdentity requestIdentity;
  final CustomSceneStoredDraftState state;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? expectedAccountContext;
  final String? registeredContentId;

  CustomSceneDraft toDraft() {
    return CustomSceneDraft(
      text: text,
      entrySource: entrySource,
      requestIdentity: requestIdentity,
    );
  }

  CustomSceneStoredDraft copyWith({
    CustomSceneStoredDraftState? state,
    String? expectedAccountContext,
    bool clearExpectedAccountContext = false,
    String? registeredContentId,
    bool clearRegisteredContentId = false,
  }) {
    return CustomSceneStoredDraft(
      draftId: draftId,
      text: text,
      entrySource: entrySource,
      requestIdentity: requestIdentity,
      state: state ?? this.state,
      createdAt: createdAt,
      expiresAt: expiresAt,
      expectedAccountContext: clearExpectedAccountContext
          ? null
          : (expectedAccountContext ?? this.expectedAccountContext),
      registeredContentId: clearRegisteredContentId
          ? null
          : (registeredContentId ?? this.registeredContentId),
    );
  }
}

String _required(String value, String fieldName) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, fieldName, '不能为空。');
  }
  return normalized;
}

String? _optional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

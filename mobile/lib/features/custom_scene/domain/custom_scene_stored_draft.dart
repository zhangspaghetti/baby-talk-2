import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';

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
    String? safetyPolicyVersion,
    int? contentRefreshEpoch,
  }) : draftId = _required(draftId, 'draftId'),
       text = _required(text, 'text'),
       createdAt = createdAt.toUtc(),
       expiresAt = expiresAt.toUtc(),
       expectedAccountContext = _optional(expectedAccountContext),
       registeredContentId = _optional(registeredContentId),
       safetyPolicyVersion = _storedSafetyPolicyVersion(
         state,
         safetyPolicyVersion,
       ),
       contentRefreshEpoch = _storedContentRefreshEpoch(
         state,
         contentRefreshEpoch,
       ) {
    if (!this.expiresAt.isAfter(this.createdAt)) {
      throw ArgumentError.value(expiresAt, 'expiresAt', '必须晚于 createdAt。');
    }
    final isGeneratedState = _isGeneratedState(state);
    if (isGeneratedState &&
        (this.registeredContentId == null ||
            this.expectedAccountContext == null ||
            this.safetyPolicyVersion != generatedCareSafetyPolicyVersion ||
            this.contentRefreshEpoch !=
                generatedCareMomentContentRefreshEpoch)) {
      throw ArgumentError.value(
        registeredContentId,
        'registeredContentId',
        'generated state 必须保存 content identity、账号上下文和 provenance。',
      );
    }
    if (!isGeneratedState &&
        (this.safetyPolicyVersion != null ||
            this.contentRefreshEpoch != null)) {
      throw ArgumentError.value(
        safetyPolicyVersion,
        'safetyPolicyVersion',
        'provenance 只能用于 generated state。',
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
  final String? safetyPolicyVersion;
  final int? contentRefreshEpoch;

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
    String? safetyPolicyVersion,
    bool clearSafetyPolicyVersion = false,
    int? contentRefreshEpoch,
    bool clearContentRefreshEpoch = false,
  }) {
    final nextState = state ?? this.state;
    final isGeneratedState = _isGeneratedState(nextState);
    return CustomSceneStoredDraft(
      draftId: draftId,
      text: text,
      entrySource: entrySource,
      requestIdentity: requestIdentity,
      state: nextState,
      createdAt: createdAt,
      expiresAt: expiresAt,
      expectedAccountContext: clearExpectedAccountContext
          ? null
          : (expectedAccountContext ?? this.expectedAccountContext),
      registeredContentId: clearRegisteredContentId
          ? null
          : (registeredContentId ?? this.registeredContentId),
      safetyPolicyVersion: isGeneratedState
          ? (clearSafetyPolicyVersion
                ? null
                : (safetyPolicyVersion ?? this.safetyPolicyVersion))
          : null,
      contentRefreshEpoch: isGeneratedState
          ? (clearContentRefreshEpoch
                ? null
                : (contentRefreshEpoch ?? this.contentRefreshEpoch))
          : null,
    );
  }
}

bool _isGeneratedState(CustomSceneStoredDraftState state) {
  return state == CustomSceneStoredDraftState.approvedPendingRegistration ||
      state == CustomSceneStoredDraftState.readyForHandoff;
}

String? _storedSafetyPolicyVersion(
  CustomSceneStoredDraftState state,
  String? value,
) {
  if (!_isGeneratedState(state)) {
    return value == null ? null : _optional(value);
  }
  final normalized = value?.trim();
  if (normalized != generatedCareSafetyPolicyVersion) {
    throw ArgumentError.value(
      value,
      'safetyPolicyVersion',
      'generated state 必须显式保存当前 safety policy。',
    );
  }
  return normalized;
}

int? _storedContentRefreshEpoch(CustomSceneStoredDraftState state, int? value) {
  if (!_isGeneratedState(state)) {
    return value;
  }
  if (value != generatedCareMomentContentRefreshEpoch) {
    throw ArgumentError.value(
      value,
      'contentRefreshEpoch',
      'generated state 必须显式保存当前 content refresh epoch。',
    );
  }
  return value;
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

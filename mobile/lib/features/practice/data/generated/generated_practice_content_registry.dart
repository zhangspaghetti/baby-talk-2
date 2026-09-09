import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/generated_care_turn_resume.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

typedef GeneratedPracticeAccountContextLoader = Future<String?> Function();
typedef GeneratedPracticeHouseholdScopeLoader = Future<String?> Function();

enum GeneratedPracticeProjectionUnavailableReason {
  accountUnavailable,
  accountLoadFailed,
  contentLoadFailed,
}

class GeneratedPracticeProjectionUnavailableException implements Exception {
  const GeneratedPracticeProjectionUnavailableException(this.reason);

  final GeneratedPracticeProjectionUnavailableReason reason;

  @override
  String toString() =>
      'Generated practice projection unavailable: ${reason.name}';
}

class GeneratedPracticeContentClearanceException implements Exception {
  GeneratedPracticeContentClearanceException(Iterable<String> failedTargets)
    : failedTargets = List<String>.unmodifiable(failedTargets);

  final List<String> failedTargets;

  @override
  String toString() =>
      'Generated practice content clearance failed: ${failedTargets.join(', ')}';
}

/// The only bridge from an approved custom-scene bundle into formal Practice
/// content. It never exposes raw scene input and only resolves current-account
/// records.
class GeneratedPracticeContentRegistry
    implements
        CustomSceneApprovedContentRegistrar,
        PracticeContentResolver,
        PublishedPracticeContentResolver {
  GeneratedPracticeContentRegistry({
    required GeneratedCareMomentLocalStore store,
    required GeneratedCareTurnResumeStore resumeStore,
    required GeneratedPracticeAccountContextLoader accountContextLoader,
    GeneratedPracticeHouseholdScopeLoader? householdScopeLoader,
  }) : _store = store,
       _resumeStore = resumeStore,
       _accountContextLoader = accountContextLoader,
       _householdScopeLoader = householdScopeLoader ?? (() async => null);

  final GeneratedCareMomentLocalStore _store;
  final GeneratedCareTurnResumeStore _resumeStore;
  final GeneratedPracticeAccountContextLoader _accountContextLoader;
  final GeneratedPracticeHouseholdScopeLoader _householdScopeLoader;

  Future<String?> loadCurrentAccountContext() => _loadCurrentAccountContext();

  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {
    final normalizedAccountContext = accountContext.trim();
    if (normalizedAccountContext.isEmpty) {
      throw ArgumentError.value(accountContext, 'accountContext', '不能为空。');
    }
    final currentAccountContext = await _loadCurrentAccountContext();
    if (currentAccountContext == null ||
        currentAccountContext != normalizedAccountContext) {
      throw StateError('当前账号与 approved generated content 不匹配。');
    }
    _validateMoment(moment);
    final householdScope = await _householdScopeLoader();
    await _store.upsert(
      StoredGeneratedCareMoment(
        accountContext: normalizedAccountContext,
        householdScopeFingerprint: householdScope == null
            ? null
            : householdScopeFingerprint(householdScope),
        moment: moment,
      ),
    );
    // Low-priority metadata maintenance must not turn a successful registration
    // into a failure. Quarantined display text was already removed atomically.
    try {
      await _store.purgeQuarantinedForAccount(normalizedAccountContext);
    } on Object {
      // The approved bundle remains available; a later registration retries it.
    }
  }

  @override
  Future<PracticeActivitySnapshot?> resolveActivity({
    required String spaceId,
    required String activityId,
    int? publishedVersion,
    bool enabled = true,
  }) async {
    if (!enabled || publishedVersion != null && publishedVersion < 1) {
      return null;
    }
    final accountContext = await _loadCurrentAccountContext();
    if (accountContext == null) {
      return null;
    }
    try {
      final records = (await _store.readAll())
          .where(
            (candidate) =>
                candidate.accountContext == accountContext &&
                candidate.moment.spaceId == spaceId.trim() &&
                candidate.moment.activityId == activityId.trim(),
          )
          .where(
            (candidate) =>
                publishedVersion == null ||
                candidate.moment.inputSource ==
                        SceneGenerationSourceType.preset &&
                    candidate.moment.presetSceneId == activityId.trim() &&
                    candidate.moment.presetSceneVersion == publishedVersion,
          )
          .toList(growable: false);
      if (records.isEmpty) {
        return null;
      }
      if (records.length == 1) {
        return _toSnapshot(records.single.moment);
      }
      final presetRecords =
          records
              .where(
                (candidate) =>
                    candidate.moment.inputSource ==
                    SceneGenerationSourceType.preset,
              )
              .toList(growable: false)
            ..sort((left, right) {
              final versionComparison = right.moment.presetSceneVersion!
                  .compareTo(left.moment.presetSceneVersion!);
              if (versionComparison != 0) {
                return versionComparison;
              }
              return left.moment.generatedContentId.compareTo(
                right.moment.generatedContentId,
              );
            });
      if (presetRecords.isEmpty) {
        return null;
      }
      return _toSnapshot(presetRecords.first.moment);
    } on Object {
      return null;
    }
  }

  @override
  Future<PracticeActivitySnapshot?> resolvePublishedActivity({
    required String spaceId,
    required String activityId,
    required int publishedVersion,
  }) async {
    if (publishedVersion < 1) {
      return null;
    }
    final accountContext = await _loadCurrentAccountContext();
    if (accountContext == null) {
      return null;
    }
    try {
      final candidates =
          (await _store.readAll())
              .where(
                (candidate) =>
                    candidate.accountContext == accountContext &&
                    candidate.moment.inputSource ==
                        SceneGenerationSourceType.preset &&
                    candidate.moment.spaceId == spaceId.trim() &&
                    candidate.moment.activityId == activityId.trim() &&
                    candidate.moment.presetSceneId == activityId.trim() &&
                    candidate.moment.presetSceneVersion == publishedVersion,
              )
              .toList(growable: false)
            ..sort(
              (left, right) => left.moment.generatedContentId.compareTo(
                right.moment.generatedContentId,
              ),
            );
      if (candidates.isEmpty) {
        return null;
      }
      return _toSnapshot(candidates.first.moment);
    } on Object {
      return null;
    }
  }

  @override
  Future<PracticeActivitySnapshot?> resolveGeneratedContent({
    required String generatedContentId,
  }) async {
    final accountContext = await _loadCurrentAccountContext();
    if (accountContext == null) {
      return null;
    }
    try {
      return _resolveGeneratedContentForAccount(
        accountContext: accountContext,
        generatedContentId: generatedContentId,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<List<PracticeActivitySnapshot>> listGeneratedActivities() async {
    final accountContext = await _requireCurrentAccountContextForProjection();
    try {
      final records =
          (await _store.readAll())
              .where((candidate) => candidate.accountContext == accountContext)
              .where(
                (candidate) =>
                    candidate.moment.inputSource ==
                    SceneGenerationSourceType.custom,
              )
              .map((candidate) => _toSnapshot(candidate.moment))
              .toList(growable: false)
            ..sort(
              (left, right) => (left.generatedContentId ?? '').compareTo(
                right.generatedContentId ?? '',
              ),
            );
      return List<PracticeActivitySnapshot>.unmodifiable(records);
    } on Object {
      throw const GeneratedPracticeProjectionUnavailableException(
        GeneratedPracticeProjectionUnavailableReason.contentLoadFailed,
      );
    }
  }

  @override
  Future<GeneratedCareTurnResumeMarker?>
  loadGeneratedCareTurnResumeMarker() async {
    final accountContext = await _loadCurrentAccountContext();
    if (accountContext == null) {
      return null;
    }
    try {
      final marker = await _resumeStore.readForAccount(accountContext);
      if (marker == null) {
        return null;
      }
      final content = await _resolveGeneratedContentForAccount(
        accountContext: accountContext,
        generatedContentId: marker.generatedContentId,
      );
      if (content != null) {
        return marker;
      }
      await _resumeStore.clearMatching(
        accountContext: accountContext,
        generatedContentId: marker.generatedContentId,
      );
      return null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> completeGeneratedCareTurnResume({
    required String generatedContentId,
  }) async {
    final accountContext = await _loadCurrentAccountContext();
    if (accountContext == null) {
      return;
    }
    await _resumeStore.clearMatching(
      accountContext: accountContext,
      generatedContentId: generatedContentId,
    );
  }

  @override
  Future<void> clearForLifecycle() {
    return _clearBoth(
      clearGeneratedCareMoments: _store.clearForLifecycle,
      clearResumeMarkers: _resumeStore.clearForLifecycle,
    );
  }

  Future<void> clearForAccount(String accountContext) {
    return _clearBoth(
      clearGeneratedCareMoments: () => _store.clearForAccount(accountContext),
      clearResumeMarkers: () => _resumeStore.clearForAccount(accountContext),
    );
  }

  Future<void> clearForHouseholdScope(String householdScope) {
    return clearForHouseholdScopeFingerprint(
      householdScopeFingerprint(householdScope),
    );
  }

  Future<void> clearForHouseholdScopeFingerprint(String scopeFingerprint) {
    return _clearBoth(
      clearGeneratedCareMoments: () =>
          _store.clearForHouseholdScopeFingerprint(scopeFingerprint),
      clearResumeMarkers: () =>
          _resumeStore.clearForHouseholdScopeFingerprint(scopeFingerprint),
    );
  }

  Future<void> _clearBoth({
    required Future<void> Function() clearGeneratedCareMoments,
    required Future<void> Function() clearResumeMarkers,
  }) async {
    final failedTargets = <String>[];
    try {
      await clearGeneratedCareMoments();
    } on Object {
      failedTargets.add('generated_care_moments');
    }
    try {
      await clearResumeMarkers();
    } on Object {
      failedTargets.add('generated_care_turn_resume');
    }
    if (failedTargets.isNotEmpty) {
      throw GeneratedPracticeContentClearanceException(failedTargets);
    }
  }

  Future<PracticeActivitySnapshot?> _resolveGeneratedContentForAccount({
    required String accountContext,
    required String generatedContentId,
  }) async {
    final records = (await _store.readAll()).where(
      (candidate) =>
          candidate.accountContext == accountContext &&
          candidate.moment.generatedContentId == generatedContentId.trim(),
    );
    if (records.length != 1) {
      return null;
    }
    return _toSnapshot(records.single.moment);
  }

  Future<String?> _loadCurrentAccountContext() async {
    try {
      final value = (await _accountContextLoader())?.trim();
      return value == null || value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  Future<String> _requireCurrentAccountContextForProjection() async {
    final String? value;
    try {
      value = (await _accountContextLoader())?.trim();
    } on Object {
      throw const GeneratedPracticeProjectionUnavailableException(
        GeneratedPracticeProjectionUnavailableReason.accountLoadFailed,
      );
    }
    if (value == null || value.isEmpty) {
      throw const GeneratedPracticeProjectionUnavailableException(
        GeneratedPracticeProjectionUnavailableReason.accountUnavailable,
      );
    }
    return value;
  }

  PracticeActivitySnapshot _toSnapshot(GeneratedCareMoment moment) {
    _validateMoment(moment);
    final utterances = <GeneratedCareUtterance>[
      moment.starter,
      for (final reaction in BabyReactionType.values)
        moment.reactionSupports[reaction],
    ];
    final phraseIds = utterances.map((utterance) => utterance.phraseId).toSet();
    final utteranceIds = utterances
        .map((utterance) => utterance.utteranceId)
        .toSet();
    if (phraseIds.length != utterances.length ||
        utteranceIds.length != utterances.length) {
      throw const FormatException('generated utterance identity is not unique');
    }
    return PracticeActivitySnapshot(
      spaceId: moment.spaceId,
      activityId: moment.activityId,
      title: moment.title,
      summary: '回应此刻',
      sceneTag: moment.sceneTag,
      coachTip: moment.coachTip,
      contentSource: PracticeContentSource.generated,
      generatedContentId: moment.generatedContentId,
      inputSource: moment.inputSource,
      presetSceneId: moment.presetSceneId,
      presetSceneVersion: moment.presetSceneVersion,
      utteranceIdsByPhraseId: <String, String>{
        for (final utterance in utterances)
          utterance.phraseId: utterance.utteranceId,
      },
      reactionSupportPhraseIds: <BabyReactionType, String>{
        for (final reaction in BabyReactionType.values)
          reaction: moment.reactionSupports[reaction].phraseId,
      },
      phrases: List<PracticePhrase>.unmodifiable(<PracticePhrase>[
        for (var index = 0; index < utterances.length; index++)
          _toPracticePhrase(
            utterance: utterances[index],
            spaceId: moment.spaceId,
            activityId: moment.activityId,
            step: index + 1,
          ),
      ]),
    );
  }

  PracticePhrase _toPracticePhrase({
    required GeneratedCareUtterance utterance,
    required String spaceId,
    required String activityId,
    required int step,
  }) {
    return PracticePhrase(
      spaceId: spaceId,
      activityId: activityId,
      phraseId: utterance.phraseId,
      step: step,
      english: utterance.english,
      chinese: utterance.chinese,
      pronunciation: utterance.pronunciation,
      difficulty: utterance.difficulty,
      audioAsset: '',
    );
  }

  void _validateMoment(GeneratedCareMoment moment) {
    if (moment.schemaVersion != generatedCareMomentSchemaVersion ||
        moment.source != 'generated' ||
        moment.generatedContentId.trim().isEmpty ||
        moment.spaceId.trim().isEmpty ||
        moment.activityId.trim().isEmpty) {
      throw const FormatException('invalid approved generated care moment');
    }
    if (moment.inputSource == SceneGenerationSourceType.preset &&
        (moment.presetSceneId?.trim() != moment.activityId ||
            moment.presetSceneVersion == null ||
            moment.presetSceneVersion! < 1)) {
      throw const FormatException('invalid approved preset scene identity');
    }
    if (moment.inputSource == SceneGenerationSourceType.custom &&
        (moment.presetSceneId != null || moment.presetSceneVersion != null)) {
      throw const FormatException('invalid approved custom scene identity');
    }
    final branches = <GeneratedCareUtterance>[
      moment.starter,
      for (final reaction in BabyReactionType.values)
        moment.reactionSupports[reaction],
    ];
    if (branches.length != 6 ||
        branches.any((branch) => branch.source != 'generated') ||
        branches.map((branch) => branch.phraseId).toSet().length != 6 ||
        branches.map((branch) => branch.utteranceId).toSet().length != 6) {
      throw const FormatException('generated utterance identity is not unique');
    }
    final starter = moment.starter;
    if (starter.source != 'generated' ||
        starter.role != GeneratedCareUtteranceRole.starter ||
        starter.reaction != null ||
        starter.displayOrder != 1) {
      throw const FormatException('invalid generated starter contract');
    }
    for (final reaction in BabyReactionType.values) {
      final support = moment.reactionSupports[reaction];
      if (support.source != 'generated' ||
          support.phraseId.trim().isEmpty ||
          support.utteranceId.trim().isEmpty ||
          support.role != GeneratedCareUtteranceRole.reactionSupport ||
          support.reaction != reaction ||
          support.displayOrder !=
              BabyReactionType.values.indexOf(reaction) + 2 ||
          support.providerProvenance.providerName.trim().isEmpty ||
          support.providerProvenance.modelName.trim().isEmpty) {
        throw const FormatException('invalid generated reaction support');
      }
    }
  }
}

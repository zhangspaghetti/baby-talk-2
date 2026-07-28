import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

typedef GeneratedPracticeAccountContextLoader = Future<String?> Function();

/// The only bridge from an approved custom-scene bundle into formal Practice
/// content. It never exposes raw scene input and only resolves current-account
/// records.
class GeneratedPracticeContentRegistry
    implements CustomSceneApprovedContentRegistrar, PracticeContentResolver {
  GeneratedPracticeContentRegistry({
    required GeneratedCareMomentLocalStore store,
    required GeneratedPracticeAccountContextLoader accountContextLoader,
  }) : _store = store,
       _accountContextLoader = accountContextLoader;

  final GeneratedCareMomentLocalStore _store;
  final GeneratedPracticeAccountContextLoader _accountContextLoader;

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
    await _store.upsert(
      StoredGeneratedCareMoment(
        accountContext: normalizedAccountContext,
        moment: moment,
      ),
    );
  }

  @override
  Future<PracticeActivitySnapshot?> resolveActivity({
    required String spaceId,
    required String activityId,
  }) async {
    final accountContext = await _loadCurrentAccountContext();
    if (accountContext == null) {
      return null;
    }
    try {
      final record = (await _store.readAll()).where(
        (candidate) =>
            candidate.accountContext == accountContext &&
            candidate.moment.spaceId == spaceId.trim() &&
            candidate.moment.activityId == activityId.trim(),
      );
      if (record.length != 1) {
        return null;
      }
      return _toSnapshot(record.single.moment);
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
      final record = (await _store.readAll()).where(
        (candidate) =>
            candidate.accountContext == accountContext &&
            candidate.moment.generatedContentId == generatedContentId.trim(),
      );
      if (record.length != 1) {
        return null;
      }
      return _toSnapshot(record.single.moment);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> clearForLifecycle() => _store.clearForLifecycle();

  Future<void> clearForAccount(String accountContext) {
    return _store.clearForAccount(accountContext);
  }

  Future<String?> _loadCurrentAccountContext() async {
    try {
      final value = (await _accountContextLoader())?.trim();
      return value == null || value.isEmpty ? null : value;
    } on Object {
      return null;
    }
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
      utteranceIdsByPhraseId: <String, String>{
        for (final utterance in utterances)
          utterance.phraseId: utterance.utteranceId,
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
    if (moment.source.trim().isEmpty ||
        moment.generatedContentId.trim().isEmpty ||
        moment.spaceId.trim().isEmpty ||
        moment.activityId.trim().isEmpty) {
      throw const FormatException('invalid approved generated care moment');
    }
    for (final reaction in BabyReactionType.values) {
      final support = moment.reactionSupports[reaction];
      if (support.phraseId.trim().isEmpty ||
          support.utteranceId.trim().isEmpty) {
        throw const FormatException('invalid generated reaction support');
      }
    }
  }
}

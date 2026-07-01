import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';

export 'package:mobile/features/practice/presentation/practice_audio_controller.dart';

enum PracticePlaybackStatus { idle, playing, completed, error }

enum PracticeSaveStatus { idle, saving, saved, error }

enum PracticeRecordOutcome { advanced, completed, failed, ignored }

class PracticeReactionOption {
  const PracticeReactionOption({
    required this.type,
    required this.label,
    required this.description,
  });

  final BabyReactionType type;
  final String label;
  final String description;
}

const List<PracticeReactionOption> practiceReactionOptions = [
  PracticeReactionOption(
    type: BabyReactionType.cooperating,
    label: '配合',
    description: '宝宝愿意配合这次练习。',
  ),
  PracticeReactionOption(
    type: BabyReactionType.hesitant,
    label: '犹豫',
    description: '宝宝有点犹豫，还在观察。',
  ),
  PracticeReactionOption(
    type: BabyReactionType.resisting,
    label: '不想',
    description: '宝宝现在不太想继续。',
  ),
  PracticeReactionOption(
    type: BabyReactionType.noResponse,
    label: '没反应',
    description: '宝宝暂时没有明显反应。',
  ),
  PracticeReactionOption(
    type: BabyReactionType.other,
    label: '其他',
    description: '这次反应不属于前面的几类。',
  ),
];

/// Controls the lifecycle of a single practice phrase (V21).
enum PhraseInteractionPhase {
  ready, // Waiting for user to say the phrase ("说完了")
  saved, // Phrase marked spoken; reaction chips visible
  advancing, // Reaction recorded; 1.35 s animation before next card
  complete, // All phrases done; completion view shown
}

/// Status of the "换一句" background load (V21).
enum NextPhraseLoadStatus { idle, loading, error }

class PracticeSessionNotifier extends ChangeNotifier {
  PracticeSessionNotifier({
    required PracticeRepository repository,
    required this.spaceId,
    required this.activityId,
    this.isDynamic = false,
    this.babyAgeMonths = 12,
    this.sceneTag,
    this.accessTokenLoader,
    PracticeAudioController? audioController,
    this.playbackTimeout = const Duration(seconds: 8),
  }) : _repository = repository,
       _audioController =
           audioController ?? AudioplayersPracticeAudioController() {
    _audioCompletionSubscription = _audioController.completionStream.listen((
      _,
    ) {
      _handlePlaybackCompleted();
    });
  }

  final PracticeRepository _repository;
  final PracticeAudioController _audioController;
  final String spaceId;
  final String activityId;
  final bool isDynamic;
  final int babyAgeMonths;
  final String? sceneTag;
  final String? Function()? accessTokenLoader;
  final Duration playbackTimeout;

  StreamSubscription<void>? _audioCompletionSubscription;
  Timer? _playbackTimeoutTimer;

  bool _isHomeLoading = false;
  bool _isSessionLoading = false;
  PracticeActivitySnapshot? _activitySnapshot;
  PracticeHomeSummary? _homeSummary;
  PracticeResumeInfo? _resumeInfo;
  int _currentPhraseIndex = 0;
  bool _sessionCompleted = false;
  String? _installationId;
  String? _restoreStatusMessage;
  bool _hasRecoverableRestoreIssue = false;
  String? _homeErrorMessage;
  String? _sessionErrorMessage;
  bool _hasPreparedSession = false;
  PracticePlaybackStatus _playbackStatus = PracticePlaybackStatus.idle;
  PracticeSaveStatus _saveStatus = PracticeSaveStatus.idle;
  String? _playbackMessage;
  String? _saveMessage;
  PhraseInteractionPhase _phrasePhase = PhraseInteractionPhase.ready;
  NextPhraseLoadStatus _nextPhraseLoadStatus = NextPhraseLoadStatus.idle;
  Timer? _autoAdvanceTimer;
  bool _skipCancelled = false;

  bool get isHomeLoading => _isHomeLoading;
  bool get isSessionLoading => _isSessionLoading;
  PracticeActivitySnapshot? get activitySnapshot => _activitySnapshot;
  PracticeHomeSummary? get homeSummary => _homeSummary;
  PracticeResumeInfo? get resumeInfo => _resumeInfo;
  int get currentPhraseIndex => _currentPhraseIndex;
  bool get sessionCompleted => _sessionCompleted;
  String? get installationId => _installationId;
  String? get restoreStatusMessage => _restoreStatusMessage;
  bool get hasRecoverableRestoreIssue => _hasRecoverableRestoreIssue;
  String? get homeErrorMessage => _homeErrorMessage;
  String? get sessionErrorMessage => _sessionErrorMessage;
  bool get hasPreparedSession => _hasPreparedSession;
  PracticePlaybackStatus get playbackStatus => _playbackStatus;
  PracticeSaveStatus get saveStatus => _saveStatus;
  String? get playbackMessage => _playbackMessage;
  String? get saveMessage => _saveMessage;
  PhraseInteractionPhase get phrasePhase => _phrasePhase;
  NextPhraseLoadStatus get nextPhraseLoadStatus => _nextPhraseLoadStatus;

  PracticePhrase? get currentPhrase {
    final snapshot = _activitySnapshot;
    if (snapshot == null || snapshot.phrases.isEmpty) {
      return null;
    }
    if (_currentPhraseIndex < 0 ||
        _currentPhraseIndex >= snapshot.phrases.length) {
      return null;
    }
    return snapshot.phrases[_currentPhraseIndex];
  }

  String get playbackStatusLabel {
    switch (_playbackStatus) {
      case PracticePlaybackStatus.idle:
        return 'idle';
      case PracticePlaybackStatus.playing:
        return 'playing';
      case PracticePlaybackStatus.completed:
        return 'completed';
      case PracticePlaybackStatus.error:
        return 'error';
    }
  }

  String get saveStatusLabel {
    switch (_saveStatus) {
      case PracticeSaveStatus.idle:
        return 'idle';
      case PracticeSaveStatus.saving:
        return 'saving';
      case PracticeSaveStatus.saved:
        return 'saved';
      case PracticeSaveStatus.error:
        return 'error';
    }
  }

  bool get canStartPractice =>
      !_isHomeLoading && _homeErrorMessage == null && _activitySnapshot != null;

  bool get canPlayCurrentPhrase =>
      !_isSessionLoading &&
      !_sessionCompleted &&
      currentPhrase != null &&
      _playbackStatus != PracticePlaybackStatus.playing;

  bool get canSubmitReaction =>
      !_isSessionLoading &&
      !_sessionCompleted &&
      currentPhrase != null &&
      _saveStatus != PracticeSaveStatus.saving;

  Future<void> initialize() async {
    await _loadHomeState();
  }

  Future<void> retryHomeLoad() {
    return _loadHomeState();
  }

  Future<bool> ensureSessionReady() async {
    if (_isSessionLoading) {
      return false;
    }

    _sessionErrorMessage = null;
    _isSessionLoading = true;
    notifyListeners();

    try {
      PracticeActivitySnapshot snapshot;
      PracticeResumeInfo resume;

      if (isDynamic && _activitySnapshot != null) {
        // 动态模式已在 _loadHomeState 中加载了 snapshot
        snapshot = _activitySnapshot!;
        resume =
            _resumeInfo ??
            PracticeResumeInfo(
              activityId: snapshot.activityId,
              totalPhrases: snapshot.phrases.length,
              completedPhraseIds: const [],
              nextPhraseId: snapshot.phrases.isNotEmpty
                  ? snapshot.phrases.first.phraseId
                  : null,
              lastEventTime: null,
            );
      } else {
        final restored = await _repository.restorePracticeState(
          spaceId: spaceId,
          activityId: activityId,
        );
        _applyRestoreSnapshot(restored);
        snapshot = restored.activitySnapshot;
        resume = restored.resumeInfo;
      }

      if (snapshot.phrases.isEmpty) {
        throw const FormatException('当前活动暂无可用短语，请返回首页重试。');
      }

      _currentPhraseIndex = _resolveCurrentPhraseIndex(
        phrases: snapshot.phrases,
        resume: resume,
      );
      _sessionCompleted = false;
      _saveStatus = PracticeSaveStatus.idle;
      _saveMessage = null;
      _sessionErrorMessage = null;
      _hasPreparedSession = true;
      _resetPlaybackState(clearMessage: true, notify: false);
      return true;
    } catch (error) {
      _sessionErrorMessage = '练习页加载失败：$error';
      _hasPreparedSession = false;
      return false;
    } finally {
      _isSessionLoading = false;
      notifyListeners();
    }
  }

  Future<void> playCurrentPhrase() async {
    final phrase = currentPhrase;
    if (phrase == null || !canPlayCurrentPhrase) {
      return;
    }

    final assetPath = phrase.audioPlayerAsset.trim();
    if (assetPath.isEmpty) {
      _playbackStatus = PracticePlaybackStatus.error;
      _playbackMessage = '音频资源缺失，当前短语保留在原位，可稍后重试。';
      notifyListeners();
      return;
    }

    _cancelPlaybackTimeout();
    _playbackStatus = PracticePlaybackStatus.playing;
    _playbackMessage = null;
    notifyListeners();

    try {
      await _audioController.stop();
      await _audioController.playAsset(assetPath);
      _playbackTimeoutTimer = Timer(playbackTimeout, _handlePlaybackTimeout);
    } catch (error) {
      _cancelPlaybackTimeout();
      _playbackStatus = PracticePlaybackStatus.error;
      _playbackMessage = '播放失败：$error';
      notifyListeners();
    }
  }

  Future<void> speakCurrentPhrase(
    Future<void> Function(String text) speak,
  ) async {
    final phrase = currentPhrase;
    if (phrase == null) {
      return;
    }

    _cancelPlaybackTimeout();
    _playbackStatus = PracticePlaybackStatus.playing;
    _playbackMessage = null;
    notifyListeners();

    try {
      await speak(phrase.english);
      _playbackStatus = PracticePlaybackStatus.completed;
      _playbackMessage = '播放完成，可以记录宝宝反应。';
      notifyListeners();
    } catch (error) {
      _playbackStatus = PracticePlaybackStatus.error;
      _playbackMessage = '语音合成失败：$error';
      notifyListeners();
    }
  }

  Future<PracticeRecordOutcome> recordReaction(
    BabyReactionType reactionType,
  ) async {
    final snapshot = _activitySnapshot;
    final phrase = currentPhrase;
    if (_saveStatus == PracticeSaveStatus.saving) {
      return PracticeRecordOutcome.ignored;
    }
    if (snapshot == null || phrase == null) {
      _saveStatus = PracticeSaveStatus.error;
      _saveMessage = '当前练习上下文缺失，未写入任何本地事件。';
      notifyListeners();
      return PracticeRecordOutcome.failed;
    }

    _sessionErrorMessage = null;
    _saveStatus = PracticeSaveStatus.saving;
    _saveMessage = '正在把宝宝反应写入本地记录…';
    notifyListeners();

    try {
      final isLastPhrase = _currentPhraseIndex >= snapshot.phrases.length - 1;

      // 动态模式不写 Isar 事件（避免临时 ID 污染统计）
      if (!isDynamic) {
        await _repository.recordReaction(
          spaceId: spaceId,
          activityId: activityId,
          phraseId: phrase.phraseId,
          reactionType: reactionType,
        );
        await _reloadDerivedState();
      }

      _resetPlaybackState(clearMessage: true, notify: false);
      _saveStatus = PracticeSaveStatus.saved;
      _saveMessage = isLastPhrase ? '已保存本地结果，当前活动已完成。' : '已保存本地结果，继续下一句。';

      // Advance index immediately so currentPhrase reflects next phrase.
      // phrasePhase stays "advancing" for 1.35 s (UI animation window).
      if (!isLastPhrase) {
        _currentPhraseIndex = (_currentPhraseIndex + 1).clamp(
          0,
          snapshot.phrases.length - 1,
        );
      } else {
        _sessionCompleted = true;
      }
      _phrasePhase = PhraseInteractionPhase.advancing;
      notifyListeners();

      // After 1.35 s, flip to the steady state.
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(const Duration(milliseconds: 1350), () {
        _autoAdvanceTimer = null;
        _phrasePhase = isLastPhrase
            ? PhraseInteractionPhase.complete
            : PhraseInteractionPhase.ready;
        notifyListeners();
      });

      return isLastPhrase
          ? PracticeRecordOutcome.completed
          : PracticeRecordOutcome.advanced;
    } catch (error) {
      _saveStatus = PracticeSaveStatus.error;
      _saveMessage = '保存失败：$error';
      notifyListeners();
      return PracticeRecordOutcome.failed;
    }
  }

  /// Marks the current phrase as spoken; transitions phase to [saved].
  /// Idempotent — calling while already in [saved] or [advancing] is a no-op.
  void saveCurrentPhrase() {
    if (_phrasePhase != PhraseInteractionPhase.ready) return;
    _phrasePhase = PhraseInteractionPhase.saved;
    notifyListeners();
  }

  /// Skips the reaction and advances to the next phrase.
  /// Cancels any pending auto-advance timer.
  void skipToNextPhrase() {
    cancelAutoAdvance();
    _advanceToNextPhrase();
  }

  /// Cancels the 1.35 s auto-advance timer.
  /// If the phase was [advancing], rolls it back to [saved].
  void cancelAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (_phrasePhase == PhraseInteractionPhase.advancing) {
      _phrasePhase = PhraseInteractionPhase.saved;
      notifyListeners();
    }
  }

  /// Ends the session immediately (e.g. user taps "结束").
  void endSession() {
    _skipCancelled = true;
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _sessionCompleted = true;
    _phrasePhase = PhraseInteractionPhase.complete;
    notifyListeners();
  }

  /// Calls the generate API to replace the current phrase ("换一句").
  Future<void> skipCurrentPhrase() async {
    if (_nextPhraseLoadStatus == NextPhraseLoadStatus.loading) return;
    _skipCancelled = false;
    _nextPhraseLoadStatus = NextPhraseLoadStatus.loading;
    _sessionErrorMessage = null;
    notifyListeners();

    final currentEnglish = currentPhrase?.english;

    try {
      final newSnapshot = await _repository.getActivitySnapshotDynamic(
        babyAgeMonths: babyAgeMonths,
        sceneTag: sceneTag,
        fallbackSpaceId: spaceId,
        fallbackActivityId: activityId,
        accessToken: accessTokenLoader?.call(),
      );

      if (_skipCancelled) return;

      // Client-side dedup: prefer a phrase with different English text.
      final candidates = newSnapshot.phrases;
      final newDynPhrase = candidates.firstWhere(
        (p) => p.english != currentEnglish,
        orElse: () => candidates.first,
      );

      final currentSnapshot = _activitySnapshot!;
      final updatedPhrases = List<PracticePhrase>.from(currentSnapshot.phrases);
      updatedPhrases[_currentPhraseIndex] = PracticePhrase(
        spaceId: newDynPhrase.spaceId,
        activityId: newDynPhrase.activityId,
        phraseId: 'dyn_replaced_${DateTime.now().microsecondsSinceEpoch}',
        step: currentSnapshot.phrases[_currentPhraseIndex].step,
        english: newDynPhrase.english,
        chinese: newDynPhrase.chinese,
        pronunciation: newDynPhrase.pronunciation,
        difficulty: newDynPhrase.difficulty,
        audioAsset: newDynPhrase.audioAsset,
      );

      _activitySnapshot = PracticeActivitySnapshot(
        spaceId: currentSnapshot.spaceId,
        activityId: currentSnapshot.activityId,
        title: currentSnapshot.title,
        summary: currentSnapshot.summary,
        sceneTag: currentSnapshot.sceneTag,
        coachTip: currentSnapshot.coachTip,
        phrases: List.unmodifiable(updatedPhrases),
      );

      _phrasePhase = PhraseInteractionPhase.ready;
      _nextPhraseLoadStatus = NextPhraseLoadStatus.idle;
      _resetPlaybackState(clearMessage: true, notify: false);
      notifyListeners();
    } catch (error) {
      if (_skipCancelled) return;
      _nextPhraseLoadStatus = NextPhraseLoadStatus.error;
      _sessionErrorMessage = '换一句没准备好，点我重试';
      notifyListeners();
    }
  }

  bool isPhraseCompleted(String phraseId) {
    final completed = _resumeInfo?.completedPhraseIds ?? const <String>[];
    return completed.contains(phraseId);
  }

  String labelForReaction(BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.cooperating:
        return '配合';
      case BabyReactionType.hesitant:
        return '犹豫';
      case BabyReactionType.resisting:
        return '不想';
      case BabyReactionType.noResponse:
        return '没反应';
      case BabyReactionType.other:
        return '其他';
    }
  }

  void _advanceToNextPhrase() {
    final snapshot = _activitySnapshot;
    if (snapshot == null) return;
    final isLast = _currentPhraseIndex >= snapshot.phrases.length - 1;
    if (isLast) {
      _sessionCompleted = true;
      _phrasePhase = PhraseInteractionPhase.complete;
    } else {
      _currentPhraseIndex++;
      _phrasePhase = PhraseInteractionPhase.ready;
      _saveStatus = PracticeSaveStatus.idle;
      _saveMessage = null;
      _resetPlaybackState(clearMessage: true, notify: false);
    }
    notifyListeners();
  }

  Future<void> _loadHomeState() async {
    if (_isHomeLoading) {
      return;
    }

    _homeErrorMessage = null;
    _isHomeLoading = true;
    notifyListeners();

    try {
      if (isDynamic) {
        // 动态模式：从 API 生成练习内容
        final snapshot = await _repository.getActivitySnapshotDynamic(
          babyAgeMonths: babyAgeMonths,
          sceneTag: sceneTag,
          fallbackSpaceId: spaceId,
          fallbackActivityId: activityId,
          accessToken: accessTokenLoader?.call(),
        );
        if (snapshot.phrases.isEmpty) {
          throw const FormatException('首页内容加载到空短语列表。');
        }
        _activitySnapshot = snapshot;
        _homeSummary = PracticeHomeSummary(
          spaceId: snapshot.spaceId,
          activityId: snapshot.activityId,
          activityTitle: snapshot.title,
          totalEvents: 0,
          lastEventTime: null,
          recentResult: null,
        );
        _resumeInfo = PracticeResumeInfo(
          activityId: snapshot.activityId,
          totalPhrases: snapshot.phrases.length,
          completedPhraseIds: const [],
          nextPhraseId: snapshot.phrases.isNotEmpty
              ? snapshot.phrases.first.phraseId
              : null,
          lastEventTime: null,
        );
        _restoreStatusMessage = '动态练习已就绪，内容由知识宫殿生成。';
        _hasRecoverableRestoreIssue = false;
      } else {
        final restored = await _repository.restorePracticeState(
          spaceId: spaceId,
          activityId: activityId,
        );
        if (restored.activitySnapshot.phrases.isEmpty) {
          throw const FormatException('首页内容加载到空短语列表。');
        }
        _applyRestoreSnapshot(restored);
      }
    } catch (error) {
      _homeErrorMessage = '首页加载失败：$error';
    } finally {
      _isHomeLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadDerivedState() async {
    final restored = await _repository.restorePracticeState(
      spaceId: spaceId,
      activityId: activityId,
    );
    _applyRestoreSnapshot(restored);
  }

  void _applyRestoreSnapshot(PracticeRestoreSnapshot restored) {
    _installationId = restored.installationId;
    _activitySnapshot = restored.activitySnapshot;
    _homeSummary = restored.homeSummary;
    _resumeInfo = restored.resumeInfo;
    _restoreStatusMessage = restored.restoreMessage;
    _hasRecoverableRestoreIssue = restored.hasRecoverableIssue;
  }

  int _resolveCurrentPhraseIndex({
    required List<PracticePhrase> phrases,
    required PracticeResumeInfo resume,
  }) {
    if (phrases.isEmpty) {
      throw const FormatException('当前活动缺少 phrase。');
    }

    final nextPhraseId = resume.nextPhraseId;
    if (nextPhraseId == null) {
      return 0;
    }

    final index = phrases.indexWhere(
      (phrase) => phrase.phraseId == nextPhraseId,
    );
    if (index == -1) {
      throw FormatException('恢复信息引用了未知 phraseId: $nextPhraseId');
    }
    return index;
  }

  void _handlePlaybackCompleted() {
    _cancelPlaybackTimeout();
    _playbackStatus = PracticePlaybackStatus.completed;
    _playbackMessage = '播放完成，可以记录宝宝反应。';
    notifyListeners();
  }

  void _handlePlaybackTimeout() {
    _playbackTimeoutTimer = null;
    _audioController.stop();
    _playbackStatus = PracticePlaybackStatus.idle;
    _playbackMessage = '播放超时了，短语还留在这里，可以再点一次播放。';
    notifyListeners();
  }

  void _resetPlaybackState({required bool clearMessage, required bool notify}) {
    _cancelPlaybackTimeout();
    _audioController.stop();
    _playbackStatus = PracticePlaybackStatus.idle;
    if (clearMessage) {
      _playbackMessage = null;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _cancelPlaybackTimeout() {
    _playbackTimeoutTimer?.cancel();
    _playbackTimeoutTimer = null;
  }

  @override
  void dispose() {
    _cancelPlaybackTimeout();
    _autoAdvanceTimer?.cancel();
    _audioCompletionSubscription?.cancel();
    unawaited(_audioController.dispose());
    super.dispose();
  }
}

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

abstract class PracticeAudioController {
  Stream<void> get completionStream;

  Future<void> playAsset(String assetPath);

  Future<void> stop();

  Future<void> dispose();
}

class AudioplayersPracticeAudioController implements PracticeAudioController {
  AudioplayersPracticeAudioController({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<void> get completionStream => _player.onPlayerComplete;

  @override
  Future<void> playAsset(String assetPath) {
    return _player.play(AssetSource(assetPath));
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}

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
    type: BabyReactionType.calm,
    label: '宝宝放松',
    description: '表情柔和，继续慢慢说。',
  ),
  PracticeReactionOption(
    type: BabyReactionType.engaged,
    label: '宝宝在看',
    description: '眼神跟着你，保持节奏。',
  ),
  PracticeReactionOption(
    type: BabyReactionType.imitated,
    label: '宝宝模仿',
    description: '嘴型或声音开始跟读。',
  ),
  PracticeReactionOption(
    type: BabyReactionType.needsBreak,
    label: '先休息',
    description: '停一下，给宝宝缓冲。',
  ),
];

class PracticeSessionViewModel extends ChangeNotifier {
  PracticeSessionViewModel({
    required PracticeRepository repository,
    required this.spaceId,
    required this.activityId,
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
      final restored = await _repository.restorePracticeState(
        spaceId: spaceId,
        activityId: activityId,
      );
      _applyRestoreSnapshot(restored);

      final snapshot = restored.activitySnapshot;
      if (snapshot.phrases.isEmpty) {
        throw const FormatException('当前活动暂无可用短语，请返回首页重试。');
      }

      _currentPhraseIndex = _resolveCurrentPhraseIndex(
        phrases: snapshot.phrases,
        resume: restored.resumeInfo,
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
      await _repository.recordReaction(
        spaceId: spaceId,
        activityId: activityId,
        phraseId: phrase.phraseId,
        reactionType: reactionType,
      );

      await _reloadDerivedState();
      _resetPlaybackState(clearMessage: true, notify: false);
      _saveStatus = PracticeSaveStatus.saved;
      _saveMessage = isLastPhrase ? '已保存本地结果，当前洗澡练习完成。' : '已保存本地结果，继续下一句。';
      _sessionCompleted = isLastPhrase;
      if (!isLastPhrase) {
        _currentPhraseIndex = (_currentPhraseIndex + 1).clamp(
          0,
          snapshot.phrases.length - 1,
        );
      }
      notifyListeners();
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

  bool isPhraseCompleted(String phraseId) {
    final completed = _resumeInfo?.completedPhraseIds ?? const <String>[];
    return completed.contains(phraseId);
  }

  String labelForReaction(BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.calm:
        return '宝宝放松';
      case BabyReactionType.engaged:
        return '宝宝在看';
      case BabyReactionType.imitated:
        return '宝宝模仿';
      case BabyReactionType.needsBreak:
        return '先休息';
    }
  }

  Future<void> _loadHomeState() async {
    if (_isHomeLoading) {
      return;
    }

    _homeErrorMessage = null;
    _isHomeLoading = true;
    notifyListeners();

    try {
      final restored = await _repository.restorePracticeState(
        spaceId: spaceId,
        activityId: activityId,
      );
      if (restored.activitySnapshot.phrases.isEmpty) {
        throw const FormatException('首页内容加载到空短语列表。');
      }
      _applyRestoreSnapshot(restored);
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
    _playbackMessage = '播放超时，已回到 idle，可再次点击播放。';
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
    _audioCompletionSubscription?.cancel();
    unawaited(_audioController.dispose());
    super.dispose();
  }
}

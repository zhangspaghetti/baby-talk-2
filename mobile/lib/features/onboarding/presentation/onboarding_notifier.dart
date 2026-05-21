import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

enum OnboardingFlowStep { welcome, name, age, preview }

enum OnboardingContentStatus { idle, loading, ready, error }

enum OnboardingSubmitStatus { idle, saving, success, error }

enum OnboardingFirstPhraseActionStatus { idle, recording, recorded, error }

typedef CompleteOnboardingAction =
    Future<OnboardingSnapshot> Function(
      String childDisplayName,
      OnboardingAgeBucket ageBucket,
    );

typedef RecordFirstPhraseAction =
    Future<void> Function(OnboardingStarterSeed starterSeed);

typedef PlayFirstPhraseAudio =
    Future<void> Function(OnboardingStarterSeed starterSeed);

Future<void> _noopRecordFirstPhraseAction(OnboardingStarterSeed starterSeed) {
  return SynchronousFuture<void>(null);
}

Future<void> _noopPlayFirstPhraseAudio(OnboardingStarterSeed starterSeed) {
  return SynchronousFuture<void>(null);
}

class OnboardingNotifier extends ChangeNotifier {
  OnboardingNotifier({
    OnboardingRepository? repository,
    Future<OnboardingStarterSeed> Function()? starterSeedLoader,
    CompleteOnboardingAction? completeOnboardingAction,
    RecordFirstPhraseAction? recordFirstPhraseAction,
    PlayFirstPhraseAudio? playFirstPhraseAudio,
    this.saveTimeout = const Duration(seconds: 4),
  }) : assert(
         repository != null ||
             (starterSeedLoader != null && completeOnboardingAction != null),
         '缺少 repository，必须同时提供 starterSeedLoader 与 completeOnboardingAction。',
       ),
       _starterSeedLoader = starterSeedLoader ?? repository!.resolveStarterSeed,
       _completeOnboardingAction =
           completeOnboardingAction ??
           ((String childDisplayName, OnboardingAgeBucket ageBucket) {
             return repository!.completeOnboarding(
               childDisplayName: childDisplayName,
               ageBucket: ageBucket,
             );
           }),
       _recordFirstPhraseAction =
           recordFirstPhraseAction ?? _noopRecordFirstPhraseAction,
       _playFirstPhraseAudio =
           playFirstPhraseAudio ?? _noopPlayFirstPhraseAudio;

  final Future<OnboardingStarterSeed> Function() _starterSeedLoader;
  final CompleteOnboardingAction _completeOnboardingAction;
  final RecordFirstPhraseAction _recordFirstPhraseAction;
  final PlayFirstPhraseAudio _playFirstPhraseAudio;
  final Duration saveTimeout;

  bool _initialized = false;
  bool _disposed = false;
  OnboardingFlowStep _currentStep = OnboardingFlowStep.welcome;
  OnboardingContentStatus _contentStatus = OnboardingContentStatus.idle;
  OnboardingSubmitStatus _submitStatus = OnboardingSubmitStatus.idle;
  OnboardingFirstPhraseActionStatus _firstPhraseActionStatus =
      OnboardingFirstPhraseActionStatus.idle;
  String _draftName = '';
  OnboardingAgeBucket? _selectedAgeBucket;
  OnboardingStarterSeed? _starterSeed;
  OnboardingSnapshot? _completedSnapshot;
  String? _nameErrorMessage;
  String? _ageErrorMessage;
  String? _contentErrorMessage;
  String? _submitErrorMessage;
  String? _firstPhraseActionErrorMessage;
  int _navigationRequestToken = 0;
  Future<void>? _submitFuture;
  Future<void>? _firstPhraseActionFuture;
  Future<void>? _firstPhrasePlayFuture;
  bool _hasPlayedFirstPhrase = false;
  bool _isPlayingFirstPhrase = false;

  static const int maxDisplayNameLength = 12;

  OnboardingFlowStep get currentStep => _currentStep;
  OnboardingContentStatus get contentStatus => _contentStatus;
  OnboardingSubmitStatus get submitStatus => _submitStatus;
  OnboardingFirstPhraseActionStatus get firstPhraseActionStatus =>
      _firstPhraseActionStatus;
  String get draftName => _draftName;
  OnboardingAgeBucket? get selectedAgeBucket => _selectedAgeBucket;
  OnboardingStarterSeed? get starterSeed => _starterSeed;
  OnboardingSnapshot? get completedSnapshot => _completedSnapshot;
  String? get nameErrorMessage => _nameErrorMessage;
  String? get ageErrorMessage => _ageErrorMessage;
  String? get contentErrorMessage => _contentErrorMessage;
  String? get submitErrorMessage => _submitErrorMessage;
  String? get firstPhraseActionErrorMessage => _firstPhraseActionErrorMessage;
  int get navigationRequestToken => _navigationRequestToken;

  bool get isContentLoading =>
      _contentStatus == OnboardingContentStatus.loading;
  bool get hasContentError => _contentStatus == OnboardingContentStatus.error;
  bool get isContentReady =>
      _contentStatus == OnboardingContentStatus.ready && _starterSeed != null;
  bool get isSaving => _submitStatus == OnboardingSubmitStatus.saving;
  bool get hasPlayedFirstPhrase => _hasPlayedFirstPhrase;
  bool get isPlayingFirstPhrase => _isPlayingFirstPhrase;
  bool get isRecordingFirstPhraseAction =>
      _firstPhraseActionStatus == OnboardingFirstPhraseActionStatus.recording;
  bool get hasRecordedFirstPhraseAction =>
      _firstPhraseActionStatus == OnboardingFirstPhraseActionStatus.recorded;
  bool get canSubmit =>
      hasRecordedFirstPhraseAction &&
      !isSaving &&
      !isRecordingFirstPhraseAction;

  StageMatch? get stageMatch {
    final bucket = _selectedAgeBucket;
    if (bucket == null) {
      return null;
    }
    return StageMatchCatalog.forAgeBucket(bucket);
  }

  String get selectedAgeLabel => selectedAgeBucket?.label ?? '';

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _loadStarterSeed();
  }

  Future<void> retryContentLoad() {
    return _loadStarterSeed(force: true);
  }

  void startFlow() {
    _currentStep = OnboardingFlowStep.name;
    _clearNameError();
    _clearAgeError();
    _clearSubmitError();
    _notifySafely();
  }

  void updateDraftName(String value) {
    if (_draftName == value) {
      return;
    }
    _draftName = value;
    if (_nameErrorMessage != null) {
      _nameErrorMessage = validateName(value);
    }
    if (_submitErrorMessage != null) {
      _submitErrorMessage = null;
      if (_submitStatus == OnboardingSubmitStatus.error) {
        _submitStatus = OnboardingSubmitStatus.idle;
      }
    }
    _notifySafely();
  }

  bool continueFromName() {
    final nameError = validateName(_draftName);
    _nameErrorMessage = nameError;
    if (nameError != null) {
      _notifySafely();
      return false;
    }

    _currentStep = OnboardingFlowStep.age;
    _clearSubmitError();
    _notifySafely();
    return true;
  }

  void selectAgeBucket(OnboardingAgeBucket ageBucket) {
    if (_selectedAgeBucket == ageBucket) {
      return;
    }
    _selectedAgeBucket = ageBucket;
    _clearAgeError();
    _clearSubmitError();
    _clearFirstPhraseActionError();
    _notifySafely();
  }

  bool continueFromAge() {
    final bucket = _selectedAgeBucket;
    if (bucket == null) {
      _ageErrorMessage = '先选一个月龄档，我再给你匹配当前阶段。';
      _notifySafely();
      return false;
    }

    final resolvedStageMatch = StageMatchCatalog.forAgeBucket(bucket);
    if (resolvedStageMatch.title.trim().isEmpty ||
        resolvedStageMatch.summary.trim().isEmpty) {
      _ageErrorMessage = '当前阶段说明暂时不可用，请稍后再试。';
      _notifySafely();
      return false;
    }

    switch (_contentStatus) {
      case OnboardingContentStatus.idle:
      case OnboardingContentStatus.loading:
        _ageErrorMessage = '第一颗种子正在准备，请稍等一下。';
        _notifySafely();
        return false;
      case OnboardingContentStatus.error:
        _ageErrorMessage = _contentErrorMessage ?? '第一颗种子暂时不可用，请重试。';
        _notifySafely();
        return false;
      case OnboardingContentStatus.ready:
        break;
    }

    if (_starterSeed == null ||
        (_starterSeed!.phraseEnglish.trim().isEmpty &&
            _starterSeed!.phraseChinese.trim().isEmpty)) {
      _ageErrorMessage = '第一颗种子暂时不可用，请重试。';
      _notifySafely();
      return false;
    }

    _currentStep = OnboardingFlowStep.preview;
    _clearAgeError();
    _clearSubmitError();
    _clearFirstPhraseActionError();
    _notifySafely();
    return true;
  }

  Future<void> playFirstPhrase() {
    final inFlight = _firstPhrasePlayFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final operation = _playFirstPhraseInternal();
    _firstPhrasePlayFuture = operation.whenComplete(() {
      _firstPhrasePlayFuture = null;
    });
    return _firstPhrasePlayFuture!;
  }

  Future<void> _playFirstPhraseInternal() async {
    final seed = _starterSeed;
    if (!isContentReady || seed == null) {
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.error;
      _firstPhraseActionErrorMessage = '第一句暂时不可用，请重试。';
      _notifySafely();
      return;
    }

    _isPlayingFirstPhrase = true;
    _clearFirstPhraseActionError();
    _notifySafely();

    try {
      await _playFirstPhraseAudio(seed).timeout(saveTimeout);
      _hasPlayedFirstPhrase = true;
    } on TimeoutException {
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.error;
      _firstPhraseActionErrorMessage = '播放超时了，请再试一次。';
    } catch (error) {
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.error;
      _firstPhraseActionErrorMessage = '播放失败，请重试。${_stripErrorPrefix(error)}';
    } finally {
      _isPlayingFirstPhrase = false;
      _notifySafely();
    }
  }

  Future<void> markFirstPhraseSaid() {
    final inFlight = _firstPhraseActionFuture;
    if (inFlight != null) {
      return inFlight;
    }
    if (hasRecordedFirstPhraseAction) {
      return SynchronousFuture<void>(null);
    }

    final operation = _markFirstPhraseSaidInternal();
    _firstPhraseActionFuture = operation.whenComplete(() {
      _firstPhraseActionFuture = null;
    });
    return _firstPhraseActionFuture!;
  }

  Future<void> _markFirstPhraseSaidInternal() async {
    final seed = _starterSeed;
    if (!isContentReady || seed == null) {
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.error;
      _firstPhraseActionErrorMessage = '第一句暂时不可用，请重试。';
      _notifySafely();
      return;
    }

    _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.recording;
    _firstPhraseActionErrorMessage = null;
    _hasPlayedFirstPhrase = true;
    _notifySafely();

    try {
      await _recordFirstPhraseAction(seed).timeout(saveTimeout);
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.recorded;
      _firstPhraseActionErrorMessage = null;
      _notifySafely();
    } on TimeoutException {
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.error;
      _firstPhraseActionErrorMessage = '本地记录超时，请再试一次。';
      _notifySafely();
    } catch (error) {
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.error;
      _firstPhraseActionErrorMessage =
          '第一句记录失败，请重试。${_stripErrorPrefix(error)}';
      _notifySafely();
    }
  }

  void goBack() {
    switch (_currentStep) {
      case OnboardingFlowStep.welcome:
        return;
      case OnboardingFlowStep.name:
        _currentStep = OnboardingFlowStep.welcome;
      case OnboardingFlowStep.age:
        _currentStep = OnboardingFlowStep.name;
      case OnboardingFlowStep.preview:
        _currentStep = OnboardingFlowStep.age;
    }
    _clearSubmitError();
    _notifySafely();
  }

  Future<void> submit() {
    final inFlight = _submitFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final operation = _submitInternal();
    _submitFuture = operation.whenComplete(() {
      _submitFuture = null;
    });
    return _submitFuture!;
  }

  Future<void> _submitInternal() async {
    if (isSaving) {
      return;
    }

    final nameError = validateName(_draftName);
    if (nameError != null) {
      _nameErrorMessage = nameError;
      _currentStep = OnboardingFlowStep.name;
      _notifySafely();
      return;
    }

    final bucket = _selectedAgeBucket;
    if (bucket == null) {
      _ageErrorMessage = '先选一个月龄档，我再给你匹配当前阶段。';
      _currentStep = OnboardingFlowStep.age;
      _notifySafely();
      return;
    }

    final resolvedStageMatch = StageMatchCatalog.forAgeBucket(bucket);
    if (resolvedStageMatch.title.trim().isEmpty ||
        resolvedStageMatch.summary.trim().isEmpty) {
      _submitStatus = OnboardingSubmitStatus.error;
      _submitErrorMessage = '当前阶段说明暂时不可用，请稍后再试。';
      _notifySafely();
      return;
    }

    if (!isContentReady || _starterSeed == null) {
      _submitStatus = OnboardingSubmitStatus.error;
      _submitErrorMessage = _contentErrorMessage ?? '第一颗种子暂时不可用，请重试。';
      _notifySafely();
      return;
    }

    if (!hasRecordedFirstPhraseAction) {
      _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.error;
      _firstPhraseActionErrorMessage = '先说一次这句，再进入首页继续。';
      _notifySafely();
      return;
    }

    _submitStatus = OnboardingSubmitStatus.saving;
    _submitErrorMessage = null;
    _notifySafely();

    try {
      final snapshot = await _completeOnboardingAction(
        _draftName.trim(),
        bucket,
      ).timeout(saveTimeout);
      if (!snapshot.isCompleted ||
          snapshot.childDisplayName.trim().isEmpty ||
          snapshot.currentStage.trim().isEmpty ||
          snapshot.starterPhraseId.trim().isEmpty) {
        throw const FormatException('onboarding snapshot 缺少完成字段。');
      }

      _completedSnapshot = snapshot;
      _submitStatus = OnboardingSubmitStatus.success;
      _submitErrorMessage = null;
      _navigationRequestToken += 1;
      _notifySafely();
    } on TimeoutException {
      _submitStatus = OnboardingSubmitStatus.error;
      _submitErrorMessage = '保存超时了，请再试一次。';
      _notifySafely();
    } catch (error) {
      _submitStatus = OnboardingSubmitStatus.error;
      _submitErrorMessage = '本地保存失败，请重试。${_stripErrorPrefix(error)}';
      _notifySafely();
    }
  }

  String? validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '先给宝宝填一个昵称吧。';
    }
    if (trimmed.length > maxDisplayNameLength) {
      return '昵称先控制在 $maxDisplayNameLength 个字内，之后还可以改。';
    }
    return null;
  }

  Future<void> _loadStarterSeed({bool force = false}) async {
    if (!force && _contentStatus == OnboardingContentStatus.loading) {
      return;
    }

    _contentStatus = OnboardingContentStatus.loading;
    _contentErrorMessage = null;
    _notifySafely();

    try {
      final seed = await _starterSeedLoader();
      if (seed.phraseEnglish.trim().isEmpty &&
          seed.phraseChinese.trim().isEmpty) {
        throw const FormatException('第一句缺失。');
      }
      _starterSeed = seed;
      _resetFirstPhraseAction();
      _contentStatus = OnboardingContentStatus.ready;
      _notifySafely();
    } catch (error) {
      _starterSeed = null;
      _contentStatus = OnboardingContentStatus.error;
      _contentErrorMessage = '第一颗种子暂时不可用：${_stripErrorPrefix(error)}';
      _notifySafely();
    }
  }

  void _clearNameError() {
    _nameErrorMessage = null;
  }

  void _clearAgeError() {
    _ageErrorMessage = null;
  }

  void _clearSubmitError() {
    _submitErrorMessage = null;
    if (_submitStatus == OnboardingSubmitStatus.error) {
      _submitStatus = OnboardingSubmitStatus.idle;
    }
  }

  void _clearFirstPhraseActionError() {
    _firstPhraseActionErrorMessage = null;
    if (_firstPhraseActionStatus == OnboardingFirstPhraseActionStatus.error) {
      _firstPhraseActionStatus = hasRecordedFirstPhraseAction
          ? OnboardingFirstPhraseActionStatus.recorded
          : OnboardingFirstPhraseActionStatus.idle;
    }
  }

  void _resetFirstPhraseAction() {
    _firstPhraseActionStatus = OnboardingFirstPhraseActionStatus.idle;
    _firstPhraseActionErrorMessage = null;
    _firstPhraseActionFuture = null;
    _firstPhrasePlayFuture = null;
    _hasPlayedFirstPhrase = false;
    _isPlayingFirstPhrase = false;
  }

  String _stripErrorPrefix(Object error) {
    final raw = error.toString().trim();
    return raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Bad state: ', '')
        .trim();
  }

  void _notifySafely() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

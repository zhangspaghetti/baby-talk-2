import 'package:baby_talk_mobile/data/app_api_client.dart';
import 'package:baby_talk_mobile/data/seed_content.dart';
import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:flutter/foundation.dart';

class BabyTalkAppState extends ChangeNotifier {
  BabyTalkAppState({BabyTalkSyncApi? apiClient})
    : _apiClient = apiClient ?? const HttpBabyTalkApiClient(),
      _selectedSpaceId = SeedContent.spaces.first.id,
      _caregiverName = '小明妈妈',
      _childName = '小明',
      _childAgeMonths = 8,
      _difficulty = AppDifficulty.balanced {
    _resetSeedContent();
  }

  final BabyTalkSyncApi _apiClient;
  final Map<String, double> _activityProgress = {};
  final Map<String, Set<String>> _activityMasteredPhraseIds = {};
  final Set<String> _earnedMilestones = <String>{};
  final List<DiaryEntry> _diaryEntries = [];
  final List<MilestoneEntry> _milestones = [];
  final List<CoachSuggestion> _coachSuggestions = [];
  final List<CoachChatMessage> _coachChatMessages = [];

  int _selectedTabIndex = 0;
  int _growthPoints = 42;
  String _selectedSpaceId;
  String _caregiverName;
  String _childName;
  int _childAgeMonths;
  AppDifficulty _difficulty;
  bool _onboardingComplete = false;
  bool _isOffline = false;
  bool _isSyncing = false;
  bool _isCoachReplying = false;
  bool _hasInitialized = false;
  int _weeklyPhraseCount = 23;
  int _streakDays = 5;
  int _coachMessageCounter = 0;
  List<SpaceItem> _spaceTemplates = [];
  CelebrationMoment? _pendingCelebration;

  int get selectedTabIndex => _selectedTabIndex;
  int get growthPoints => _growthPoints;
  String get caregiverName => _caregiverName;
  String get childName => _childName;
  AppDifficulty get difficulty => _difficulty;
  bool get needsOnboarding => !_onboardingComplete;
  bool get isOffline => _isOffline;
  bool get isSyncing => _isSyncing;
  bool get isCoachReplying => _isCoachReplying;
  RoadmapStage get currentRoadmapStage =>
      RoadmapStage.forAgeMonths(_childAgeMonths);
  String get phaseLabel => currentRoadmapStage.label;
  String get ageLabel => '$_childAgeMonths个月';
  String get coachHeadline => currentRoadmapStage.coachCopy;
  double get roadmapProgress {
    final activityCount = spaces.expand((space) => space.activities).length;
    if (activityCount == 0) {
      return 0;
    }

    final activityProgress =
        spaces
            .expand((space) => space.activities)
            .fold<double>(0, (sum, activity) => sum + activity.progress) /
        activityCount;
    final stageSpan =
        (currentRoadmapStage.maxMonths - currentRoadmapStage.minMonths + 1)
            .clamp(1, 36);
    final ageProgress =
        ((_childAgeMonths - currentRoadmapStage.minMonths + 1) / stageSpan)
            .clamp(0.0, 1.0);

    return (activityProgress * 0.75 + ageProgress * 0.25).clamp(0.0, 1.0);
  }

  List<RoadmapStage> get roadmapStages => RoadmapStage.values;

  List<SpaceItem> get spaces =>
      List.unmodifiable(_spaceTemplates.map(_spaceWithState));
  List<DiaryEntry> get diaryEntries => List.unmodifiable(_diaryEntries);
  List<MilestoneEntry> get milestones => List.unmodifiable(_milestones);
  List<CoachChatMessage> get coachChatMessages =>
      List.unmodifiable(_coachChatMessages);
  List<CoachSuggestion> get coachSuggestions => List.unmodifiable([
    CoachSuggestion(
      title: '${currentRoadmapStage.title} 当前最该做什么？',
      detail:
          '${currentRoadmapStage.coachCopy} 先用 ${difficulty.label} 难度去跑通今天的一次练习。',
    ),
    ..._coachSuggestions.take(4),
  ]);
  List<ActivityItem> get _seedActivities => _spaceTemplates
      .expand((space) => space.activities)
      .toList(growable: false);

  Future<void> initialize() async {
    if (_hasInitialized) {
      return;
    }

    _hasInitialized = true;
    _isSyncing = true;
    notifyListeners();

    try {
      final snapshot = await _apiClient.fetchBootstrap();
      _applySnapshot(snapshot);
      _isOffline = false;
    } catch (_) {
      _isOffline = true;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void selectTab(int index) {
    if (_selectedTabIndex == index) {
      return;
    }
    _selectedTabIndex = index;
    notifyListeners();
  }

  SpaceItem get selectedSpace {
    return spaces.firstWhere(
      (space) => space.id == _selectedSpaceId,
      orElse: () => spaces.first,
    );
  }

  SpaceItem get featuredSpace {
    final activity = featuredActivity;
    return spaces.firstWhere(
      (space) => space.activities.any((item) => item.id == activity.id),
      orElse: () => spaces.first,
    );
  }

  ActivityItem get featuredActivity {
    return recommendedActivities.first;
  }

  List<ActivityItem> get recommendedActivities {
    final activities = spaces.expand((space) => space.activities).toList();
    activities.sort((left, right) => left.progress.compareTo(right.progress));
    return activities;
  }

  List<SpaceItem> get gardenPreviewSpaces {
    final preview = [...spaces];
    preview.sort((left, right) => right.progress.compareTo(left.progress));
    return preview.take(3).toList();
  }

  int get weeklyPhraseCount => _weeklyPhraseCount;
  int get streakDays => _streakDays;

  ActivityItem activityById(String activityId) {
    return spaces
        .expand((space) => space.activities)
        .firstWhere((activity) => activity.id == activityId);
  }

  SpaceItem spaceForActivity(String activityId) {
    return spaces.firstWhere(
      (space) => space.activities.any((activity) => activity.id == activityId),
      orElse: () => spaces.first,
    );
  }

  Future<void> completeOnboarding({
    required String caregiverName,
    required String childName,
    required int childAgeMonths,
    required AppDifficulty difficulty,
  }) async {
    _isSyncing = true;
    notifyListeners();

    try {
      final snapshot = await _apiClient.completeOnboarding(
        caregiverName: caregiverName,
        childName: childName,
        childAgeMonths: childAgeMonths,
        difficulty: difficulty,
      );
      _applySnapshot(snapshot);
      _isOffline = false;
    } catch (_) {
      _completeOnboardingLocal(
        caregiverName: caregiverName,
        childName: childName,
        childAgeMonths: childAgeMonths,
        difficulty: difficulty,
      );
      _isOffline = true;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void selectDifficulty(AppDifficulty difficulty) {
    if (_difficulty == difficulty) {
      return;
    }

    _difficulty = difficulty;
    notifyListeners();
  }

  void setOfflineMode(bool isOffline) {
    if (_isOffline == isOffline) {
      return;
    }

    _isOffline = isOffline;
    notifyListeners();
  }

  Future<CelebrationMoment?> registerPhraseReaction({
    required String activityId,
    required String phraseId,
    required PhraseReaction reaction,
  }) async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _apiClient.submitPhraseReaction(
        activityId: activityId,
        phraseId: phraseId,
        reaction: reaction,
      );
      _applySnapshot(result.snapshot);
      _pendingCelebration = result.celebration;
      _isOffline = false;
      return result.celebration;
    } catch (_) {
      _isOffline = true;
      return _registerPhraseReactionLocal(
        activityId: activityId,
        phraseId: phraseId,
        reaction: reaction,
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  CelebrationMoment? consumePendingCelebration() {
    final celebration = _pendingCelebration;
    _pendingCelebration = null;
    return celebration;
  }

  Future<bool> waterSelectedPatch(String spaceId) async {
    if (_growthPoints < 5) {
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _apiClient.waterPatch(spaceId: spaceId);
      _applySnapshot(result.snapshot);
      _isOffline = false;
      return true;
    } catch (_) {
      _isOffline = true;
      return _waterSelectedPatchLocal(spaceId);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> askCoach(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || _isCoachReplying) {
      return;
    }

    _coachChatMessages.add(
      CoachChatMessage(
        id: _nextCoachMessageId(),
        role: CoachChatRole.caregiver,
        body: trimmed,
      ),
    );
    _isCoachReplying = true;
    notifyListeners();

    try {
      final reply = await _apiClient.askCoach(prompt: trimmed);
      _appendMentorReply(reply);
      _isOffline = false;
    } catch (_) {
      _appendMentorReply(_buildLocalCoachReply(trimmed));
      _isOffline = true;
    } finally {
      _isCoachReplying = false;
      notifyListeners();
    }
  }

  void _applySnapshot(AppSnapshot snapshot) {
    _caregiverName = snapshot.caregiverName;
    _childName = snapshot.childName;
    _childAgeMonths = snapshot.childAgeMonths;
    _difficulty = snapshot.difficulty;
    _onboardingComplete = snapshot.onboardingComplete;
    _growthPoints = snapshot.growthPoints;
    _weeklyPhraseCount = snapshot.weeklyPhraseCount;
    _streakDays = snapshot.streakDays;
    _spaceTemplates = snapshot.spaces;

    if (_spaceTemplates.isNotEmpty &&
        !_spaceTemplates.any((space) => space.id == _selectedSpaceId)) {
      _selectedSpaceId = _spaceTemplates.first.id;
    }

    _diaryEntries
      ..clear()
      ..addAll(snapshot.diaryEntries);
    _milestones
      ..clear()
      ..addAll(snapshot.milestones);
    _coachSuggestions
      ..clear()
      ..addAll(_stripDynamicCoachSuggestion(snapshot.coachSuggestions));
    _earnedMilestones
      ..clear()
      ..addAll(snapshot.earnedMilestoneIds);
    _rebuildActivityStateFromTemplates();
  }

  List<CoachSuggestion> _stripDynamicCoachSuggestion(
    List<CoachSuggestion> suggestions,
  ) {
    if (suggestions.isEmpty) {
      return const [];
    }

    final first = suggestions.first;
    if (first.title.contains('当前最该做什么')) {
      return suggestions.skip(1).toList(growable: false);
    }

    return suggestions;
  }

  void _resetSeedContent() {
    _spaceTemplates = List<SpaceItem>.from(SeedContent.spaces);
    _diaryEntries
      ..clear()
      ..addAll(SeedContent.diaryEntries);
    _milestones
      ..clear()
      ..addAll(SeedContent.milestones);
    _coachSuggestions
      ..clear()
      ..addAll(SeedContent.coachSuggestions);
    _coachChatMessages
      ..clear()
      ..add(
        CoachChatMessage(
          id: _nextCoachMessageId(),
          role: CoachChatRole.mentor,
          body: '我在。告诉我你现在最容易卡住的时刻，我先给你一句马上能用的话。',
          followUpPrompt: '比如：洗澡怎么开口？宝宝哭闹时说什么？',
        ),
      );
    _earnedMilestones.clear();
    _rebuildActivityStateFromTemplates();
  }

  void _appendMentorReply(CoachChatReply reply) {
    _coachChatMessages.add(
      CoachChatMessage(
        id: _nextCoachMessageId(),
        role: CoachChatRole.mentor,
        body: reply.answer,
        suggestedPhraseEnglish: reply.suggestedPhraseEnglish,
        suggestedPhraseChinese: reply.suggestedPhraseChinese,
        followUpPrompt: reply.followUpPrompt,
      ),
    );
  }

  CoachChatReply _buildLocalCoachReply(String prompt) {
    final normalized = prompt.toLowerCase();

    if (prompt.contains('洗澡') || normalized.contains('bath')) {
      return _replyForActivity(
        activityId: 'bath-time',
        answer: '洗澡时先别追求完整句。你先把水声、动作和一句英语绑在一起，宝宝比较容易接住。',
      );
    }
    if (prompt.contains('哭') || prompt.contains('安抚') || prompt.contains('抱')) {
      return _replyForActivity(
        activityId: 'comfort',
        answer: '哭闹时先把语速放慢。先用一小句让宝宝听见“你在”，再决定要不要补第二句。',
      );
    }
    if (prompt.contains('喂') || prompt.contains('饭') || prompt.contains('辅食')) {
      return _replyForActivity(
        activityId: 'feeding',
        answer: '喂饭是最好建立反馈的时刻。嘴巴张开、勺子靠近，这两个动作本身就能托住英文句子。',
      );
    }
    if (prompt.contains('睡') ||
        prompt.contains('晚安') ||
        prompt.contains('睡前')) {
      return _replyForActivity(
        activityId: 'lullaby',
        answer: '睡前别换太多花样。今晚只要把一句安稳的短语重复两三次，就已经很够用了。',
      );
    }

    return _replyForActivity(
      activityId: featuredActivity.id,
      answer:
          '先抓一个你今天一定会遇到的时刻，不要同时想三件事。${difficulty.label} 难度下，一句能说出口的话比完整流程更重要。',
    );
  }

  CoachChatReply _replyForActivity({
    required String activityId,
    required String answer,
  }) {
    final activity = activityById(activityId);
    final leadPhrase = activity.phrases.first;
    final followUpPhrase = activity.phrases.length > 1
        ? activity.phrases[1]
        : activity.phrases.first;

    return CoachChatReply(
      answer: answer,
      suggestedPhraseEnglish: leadPhrase.english,
      suggestedPhraseChinese: leadPhrase.chinese,
      followUpPrompt: '如果这一句顺了，再补一句 “${followUpPhrase.english}”。',
    );
  }

  String _nextCoachMessageId() => 'coach-${_coachMessageCounter++}';

  void _rebuildActivityStateFromTemplates() {
    _activityProgress.clear();
    _activityMasteredPhraseIds.clear();

    for (final activity in _seedActivities) {
      _activityProgress[activity.id] = activity.progress;
      _activityMasteredPhraseIds[activity.id] = {
        for (final phrase in activity.phrases.where((item) => item.mastered))
          phrase.id,
      };
    }
  }

  void _completeOnboardingLocal({
    required String caregiverName,
    required String childName,
    required int childAgeMonths,
    required AppDifficulty difficulty,
  }) {
    _caregiverName = caregiverName.trim().isEmpty
        ? '陪伴者'
        : caregiverName.trim();
    _childName = childName.trim().isEmpty ? '宝宝' : childName.trim();
    _childAgeMonths = childAgeMonths;
    _difficulty = difficulty;
    _onboardingComplete = true;
    _diaryEntries.insert(
      0,
      DiaryEntry(
        title: '小禾老师帮 $_caregiverName 完成了入门设定，今天从一句最容易说出口的英语开始。',
        subtitle: '自动日记 · 对话式 Onboarding',
        timeLabel: '刚刚',
        type: DiaryEntryType.autoNote,
      ),
    );
  }

  CelebrationMoment? _registerPhraseReactionLocal({
    required String activityId,
    required String phraseId,
    required PhraseReaction reaction,
  }) {
    final activity = activityById(activityId);
    final phrase = activity.phrases.firstWhere((item) => item.id == phraseId);
    final masteredPhrases = _activityMasteredPhraseIds.putIfAbsent(
      activityId,
      () => <String>{},
    );
    masteredPhrases.add(phraseId);

    final increment = switch (reaction) {
      PhraseReaction.listened => 0.08,
      PhraseReaction.babbled => 0.18,
      PhraseReaction.skipped => 0.04,
    };
    final pointGain = switch (reaction) {
      PhraseReaction.listened => 2,
      PhraseReaction.babbled => 6,
      PhraseReaction.skipped => 1,
    };

    _activityProgress[activityId] =
        ((_activityProgress[activityId] ?? activity.progress) + increment)
            .clamp(0.0, 1.0);
    _growthPoints += pointGain;
    _weeklyPhraseCount += 1;

    _diaryEntries.insert(
      0,
      DiaryEntry(
        title: _diaryCopyForReaction(activity, phrase, reaction),
        subtitle: '自动日记 · ${spaceForActivity(activityId).name}',
        timeLabel: '刚刚',
        type: DiaryEntryType.autoNote,
      ),
    );

    CelebrationMoment? celebration;
    if (reaction == PhraseReaction.babbled &&
        _earnedMilestones.add('first-babble-ever')) {
      _milestones.insert(
        0,
        MilestoneEntry(
          title: '第一次跟着发声',
          detail: '$_childName 在 ${activity.name} 里第一次跟着你发出了声音。',
          timeLabel: '刚刚',
        ),
      );
      celebration = CelebrationMoment(
        title: '$_childName 跟着你一起发声了',
        detail: '这不是 demo 路径，是第一次真正成立的反馈回路。继续把今天这一句说完。',
        activityName: activity.name,
        gainedPoints: pointGain,
      );
    }

    if (celebration == null &&
        (_activityProgress[activityId] ?? 0) >= 0.9 &&
        _earnedMilestones.add('activity-bloom-$activityId')) {
      _milestones.insert(
        0,
        MilestoneEntry(
          title: '${activity.name} 进入盛开态',
          detail: '${spaceForActivity(activityId).name} 这朵花已经被你练到接近稳定输出。',
          timeLabel: '刚刚',
        ),
      );
      celebration = CelebrationMoment(
        title: '${activity.name} 开花了',
        detail: '花园里会留下痕迹，用户就会相信每天说一句这件事值得做。',
        activityName: activity.name,
        gainedPoints: pointGain,
      );
    }

    _pendingCelebration = celebration;
    return celebration;
  }

  bool _waterSelectedPatchLocal(String spaceId) {
    if (_growthPoints < 5) {
      return false;
    }

    _growthPoints -= 5;
    _diaryEntries.insert(
      0,
      DiaryEntry(
        title:
            '你给 ${spaces.firstWhere((space) => space.id == spaceId).name} 浇了水，花园的反馈又清楚了一点。',
        subtitle: '自动日记 · 花园系统',
        timeLabel: '刚刚',
        type: DiaryEntryType.autoNote,
      ),
    );
    return true;
  }

  SpaceItem _spaceWithState(SpaceItem template) {
    return template.copyWith(
      activities: template.activities.map(_activityWithState).toList(),
    );
  }

  ActivityItem _activityWithState(ActivityItem template) {
    final progress = _activityProgress[template.id] ?? template.progress;
    final masteredPhrases =
        _activityMasteredPhraseIds[template.id] ?? const <String>{};

    return template.copyWith(
      progress: progress,
      growthStage: _growthStageFor(progress),
      phrases: template.phrases
          .map(
            (phrase) => phrase.copyWith(
              mastered: masteredPhrases.contains(phrase.id) || phrase.mastered,
            ),
          )
          .toList(),
    );
  }

  GrowthStage _growthStageFor(double progress) {
    if (progress >= 0.9) {
      return GrowthStage.bloom;
    }
    if (progress >= 0.6) {
      return GrowthStage.bud;
    }
    if (progress >= 0.25) {
      return GrowthStage.sprout;
    }

    return GrowthStage.seed;
  }

  String _diaryCopyForReaction(
    ActivityItem activity,
    PhraseItem phrase,
    PhraseReaction reaction,
  ) {
    switch (reaction) {
      case PhraseReaction.listened:
        return '在 ${activity.name} 里说出 “${phrase.english}” 时，$_childName 安静地听了进去。';
      case PhraseReaction.babbled:
        return '你说 “${phrase.english}” 时，$_childName 立刻给了声音回应。';
      case PhraseReaction.skipped:
        return '${activity.name} 这一句今天没有硬推，先把节奏稳住。';
    }
  }
}

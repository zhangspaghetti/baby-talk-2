import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:provider/provider.dart';

class AppBootState {
  const AppBootState._({required this.content, this.errorMessage});

  final SeedContentBundle? content;
  final String? errorMessage;

  bool get isReady => content != null && errorMessage == null;

  static Future<AppBootState> load(AssetBundle bundle) async {
    try {
      final rawJson = await bundle.loadString('assets/content/seed_content.json');
      final content = SeedContentBundle.fromJsonString(rawJson);
      await content.validateAssets(bundle);
      return AppBootState._(content: content);
    } catch (error) {
      return AppBootState._(
        content: null,
        errorMessage: 'Boot failed: $error',
      );
    }
  }
}

class SeedContentBundle {
  SeedContentBundle({required this.spaces});

  final List<SeedSpace> spaces;

  SeedActivity get primaryActivity {
    if (spaces.isEmpty || spaces.first.activities.isEmpty) {
      throw const FormatException('种子内容缺少可练习 activity。');
    }
    return spaces.first.activities.first;
  }

  static SeedContentBundle fromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('seed_content.json 顶层必须是对象。');
    }

    final spacesJson = decoded['spaces'];
    if (spacesJson is! List || spacesJson.isEmpty) {
      throw const FormatException('seed_content.json 必须至少包含一个 space。');
    }

    return SeedContentBundle(
      spaces: spacesJson
          .map((space) => SeedSpace.fromMap(space as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Future<void> validateAssets(AssetBundle bundle) async {
    for (final space in spaces) {
      for (final activity in space.activities) {
        for (final phrase in activity.phrases) {
          if (!phrase.audioAsset.startsWith('assets/audio/')) {
            throw FormatException(
              'audioAsset 必须以 assets/audio/ 开头: ${phrase.audioAsset}',
            );
          }
          await bundle.load(phrase.audioAsset);
        }
      }
    }
  }
}

class SeedSpace {
  SeedSpace({
    required this.id,
    required this.title,
    required this.description,
    required this.activities,
  });

  final String id;
  final String title;
  final String description;
  final List<SeedActivity> activities;

  factory SeedSpace.fromMap(Map<String, dynamic> json) {
    final activitiesJson = json['activities'];
    if (activitiesJson is! List || activitiesJson.isEmpty) {
      throw FormatException('space ${json['id']} 缺少 activities。');
    }

    return SeedSpace(
      id: json['id'] as String? ?? (throw const FormatException('space.id 缺失。')),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      activities: activitiesJson
          .map((activity) => SeedActivity.fromMap(activity as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class SeedActivity {
  SeedActivity({
    required this.id,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.phrases,
  });

  final String id;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final List<SeedPhrase> phrases;

  factory SeedActivity.fromMap(Map<String, dynamic> json) {
    final phrasesJson = json['phrases'];
    if (phrasesJson is! List || phrasesJson.isEmpty) {
      throw FormatException('activity ${json['id']} 缺少 phrases。');
    }

    return SeedActivity(
      id: json['id'] as String? ?? (throw const FormatException('activity.id 缺失。')),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sceneTag: json['sceneTag'] as String? ?? '',
      coachTip: json['coachTip'] as String? ?? '',
      phrases: phrasesJson
          .map((phrase) => SeedPhrase.fromMap(phrase as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class SeedPhrase {
  SeedPhrase({
    required this.id,
    required this.step,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.difficulty,
    required this.audioAsset,
  });

  final String id;
  final int step;
  final String english;
  final String chinese;
  final String pronunciation;
  final String difficulty;
  final String audioAsset;

  String get audioPlayerAsset =>
      audioAsset.startsWith('assets/') ? audioAsset.substring(7) : audioAsset;

  factory SeedPhrase.fromMap(Map<String, dynamic> json) {
    final audioAsset = json['audioAsset'] as String? ?? '';
    if (audioAsset.isEmpty) {
      throw FormatException('phrase ${json['id']} 缺少 audioAsset。');
    }

    return SeedPhrase(
      id: json['id'] as String? ?? (throw const FormatException('phrase.id 缺失。')),
      step: json['step'] as int? ?? 0,
      english: json['english'] as String? ?? '',
      chinese: json['chinese'] as String? ?? '',
      pronunciation: json['pronunciation'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      audioAsset: audioAsset,
    );
  }
}

class GuestShellController extends ChangeNotifier {
  GuestShellController({required this.content}) : recentResult = null;

  final SeedContentBundle content;
  String? recentResult;

  SeedActivity get activity => content.primaryActivity;
}

class BabyTalkApp extends StatelessWidget {
  const BabyTalkApp({super.key, required this.bootState});

  final AppBootState bootState;

  @override
  Widget build(BuildContext context) {
    if (!bootState.isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: BootFailureScreen(message: bootState.errorMessage ?? '未知启动错误'),
      );
    }

    return ChangeNotifierProvider<GuestShellController>(
      create: (_) => GuestShellController(content: bootState.content!),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Baby Talk 2',
        theme: AppTheme.build(),
        onGenerateRoute: AppRouter.onGenerateRoute(
          homeBuilder: (_) => const HomeScreen(),
          practiceBuilder: (_) => const PracticeScreen(),
        ),
      ),
    );
  }
}

class BootFailureScreen extends StatelessWidget {
  const BootFailureScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              key: const Key('boot-status-failed'),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GuestShellController>();
    final activity = controller.activity;

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        tooltip: '小禾老师',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('小禾老师入口已预留，后续任务接入。')),
          );
        },
        child: const Icon(Icons.auto_awesome),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Chip(label: Text('离线种子已就绪')),
                    Chip(label: Text('Guest 模式')),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '今晚试试把洗澡时间变成一句句自然的英文。',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bath time, baby.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppTheme.english,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Warm Paper 风格首页已就绪，后续 Home → Practice 的真实闭环将从这张今日场景卡继续扩展。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(label: Text(activity.sceneTag)),
                        const SizedBox(height: 16),
                        Text(
                          activity.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activity.summary,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRouteNames.practice);
                          },
                          child: const Text('开始练习'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSunken,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '最近一次本地结果',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.recentResult ?? '还没有本地练习记录，第一次打开也会看到安全空态。',
                        key: const Key('recent-result-empty'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'boot: ready',
                  key: const Key('boot-status-ready'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final AudioPlayer _audioPlayer;
  String? _playingPhraseId;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playingPhraseId = null;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPhrase(SeedPhrase phrase) async {
    setState(() {
      _playingPhraseId = phrase.id;
    });
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(phrase.audioPlayerAsset));
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<GuestShellController>().activity;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(activity.title),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                LinearProgressIndicator(
                  value: 1 / activity.phrases.length,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(999),
                  color: AppTheme.accent,
                  backgroundColor: const Color(0xFFD8CFC8),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgAccentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activity.coachTip,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 20),
                ...activity.phrases.map(
                  (phrase) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _playingPhraseId == phrase.id
                              ? AppTheme.english
                              : const Color(0xFFE7DDD6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STEP ${phrase.step}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              phrase.english,
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    fontSize: 28,
                                    color: AppTheme.english,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              phrase.pronunciation,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'JetBrains Mono',
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              phrase.chinese,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () => _playPhrase(phrase),
                                    child: Icon(
                                      _playingPhraseId == phrase.id
                                          ? Icons.graphic_eq
                                          : Icons.play_arrow,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    '已接入离线音频 asset，后续任务会在这里补上 ReactionChip 与本地记录。',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:provider/provider.dart';

export 'package:mobile/features/practice/data/services/asset_phrase_service.dart'
    show SeedActivity, SeedContentBundle, SeedPhrase, SeedSpace;

class AppBootState {
  const AppBootState._({required this.content, this.errorMessage});

  final SeedContentBundle? content;
  final String? errorMessage;

  bool get isReady => content != null && errorMessage == null;

  static Future<AppBootState> load(AssetBundle bundle) async {
    try {
      final content = await AssetPhraseService(
        bundle: bundle,
      ).loadSeedContent();
      return AppBootState._(content: content);
    } catch (error) {
      return AppBootState._(content: null, errorMessage: 'Boot failed: $error');
    }
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('小禾老师入口已预留，后续任务接入。')));
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
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(color: AppTheme.english),
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
                            Navigator.of(
                              context,
                            ).pushNamed(AppRouteNames.practice);
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
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    fontSize: 28,
                                    color: AppTheme.english,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              phrase.pronunciation,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontFamily: 'JetBrains Mono'),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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

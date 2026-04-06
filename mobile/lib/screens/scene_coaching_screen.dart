import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:baby_talk_mobile/screens/celebration_screen.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:baby_talk_mobile/widgets/sync_mode_banner.dart';
import 'package:baby_talk_mobile/widgets/upgrade_required_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SceneCoachingScreen extends StatefulWidget {
  const SceneCoachingScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<SceneCoachingScreen> createState() => _SceneCoachingScreenState();
}

class _SceneCoachingScreenState extends State<SceneCoachingScreen> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.78)
      ..addListener(() {
        setState(() {
          _page = _controller.page ?? _controller.initialPage.toDouble();
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();
    final activity = appState.activityById(widget.activityId);
    final space = appState.spaceForActivity(widget.activityId);
    final tone = Theme.of(context).extension<AppThemeTone>()!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(activity.name),
            Text(
              '${space.name} · C3 激活框练习',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appState.requiresUpgrade) ...[
                    UpgradeRequiredBanner(
                      message: appState.upgradeRequiredMessage,
                      compact: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (appState.isUsingLocalMode &&
                      !appState.requiresUpgrade) ...[
                    (appState.isOffline
                        ? const SyncModeBanner.offline(compact: true)
                        : const SyncModeBanner.local(compact: true)),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appState.coachHeadline,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        appState.difficulty.label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (_page.round() + 1) / activity.phrases.length,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppDifficulty.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final difficulty = AppDifficulty.values[index];
                        return ChoiceChip(
                          label: Text(difficulty.label),
                          selected: difficulty == appState.difficulty,
                          onSelected: appState.isSyncing
                              ? null
                              : (_) {
                                  context
                                      .read<BabyTalkAppState>()
                                      .selectDifficulty(difficulty);
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: activity.phrases.length,
                      itemBuilder: (context, index) {
                        final phrase = activity.phrases[index];
                        final distance = (_page - index).abs().clamp(0.0, 1.0);
                        final expanded = distance < 0.28;

                        return Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: expanded ? 24 : 88,
                            ),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: expanded
                                    ? Theme.of(context).colorScheme.secondary
                                    : tone.borderTone,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.07),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: expanded
                                ? _ExpandedPhraseCard(
                                    phrase: phrase,
                                    isBusy:
                                        appState.isSyncing ||
                                        appState.requiresUpgrade,
                                    onReactionSelected: (reaction) =>
                                        _handleReaction(
                                          context,
                                          activity.id,
                                          phrase.id,
                                          reaction,
                                          index,
                                          activity.phrases.length,
                                        ),
                                  )
                                : _CollapsedPhraseCard(
                                    index: index,
                                    phrase: phrase,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 26),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.45),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReaction(
    BuildContext context,
    String activityId,
    String phraseId,
    PhraseReaction reaction,
    int index,
    int total,
  ) async {
    final appState = context.read<BabyTalkAppState>();
    final celebration = await appState.registerPhraseReaction(
      activityId: activityId,
      phraseId: phraseId,
      reaction: reaction,
    );

    if (!context.mounted) {
      return;
    }

    if (celebration != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CelebrationScreen(moment: celebration),
        ),
      );
      return;
    }

    if (index == total - 1) {
      Navigator.of(context).pop();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }
}

class _CollapsedPhraseCard extends StatelessWidget {
  const _CollapsedPhraseCard({required this.index, required this.phrase});

  final int index;
  final PhraseItem phrase;

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).extension<AppThemeTone>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP ${index + 1}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 10),
        Text(
          phrase.english,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          phrase.chinese,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tone.paperSunken,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '向左滑到这张卡时，会进入完整反馈动作。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ExpandedPhraseCard extends StatelessWidget {
  const _ExpandedPhraseCard({
    required this.phrase,
    required this.isBusy,
    required this.onReactionSelected,
  });

  final PhraseItem phrase;
  final bool isBusy;
  final Future<void> Function(PhraseReaction) onReactionSelected;

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).extension<AppThemeTone>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '激活中',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.play_circle_outline_rounded),
              tooltip: '播放短语',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phrase.english,
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(color: tone.englishTone),
                ),
                const SizedBox(height: 10),
                Text(
                  phrase.chinese,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tone.paperSunken,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '先说一句，再看宝宝有没有安静听、跟着发声，或者今天只是先看你。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '这一轮你观察到了什么？',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 10),
                if (isBusy)
                  Text(
                    '正在同步这次反馈…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reaction in PhraseReaction.values)
              ActionChip(
                key: Key('scene-reaction-${reaction.name}'),
                label: Text(reaction.label),
                onPressed: isBusy ? null : () => onReactionSelected(reaction),
              ),
          ],
        ),
      ],
    );
  }
}

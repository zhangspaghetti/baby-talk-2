import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CelebrationScreen extends StatelessWidget {
  const CelebrationScreen({super.key, required this.moment});

  final CelebrationMoment moment;

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).extension<AppThemeTone>()!;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                tone.paperSurface,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const Spacer(),
              Container(
                key: const Key('celebration-screen'),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: tone.paperSurface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: const [
                        _BurstPill(label: '🌱 First Babble'),
                        _BurstPill(label: '✨ Loop Closed'),
                        _BurstPill(label: '🌸 Garden Updated'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      moment.title,
                      key: const Key('celebration-title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      moment.detail,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: tone.paperSunken,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppPalette.success,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.local_florist_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  moment.activityName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${moment.gainedPoints} 生长点已经到账',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  context.read<BabyTalkAppState>().selectTab(2);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.local_florist_outlined),
                label: const Text('去看看花园'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('继续练习'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BurstPill extends StatelessWidget {
  const _BurstPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

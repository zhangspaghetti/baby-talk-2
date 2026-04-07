import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PracticeSessionViewModel>();
    final activity = viewModel.activitySnapshot;
    final homeSummary = viewModel.homeSummary;

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
            child: viewModel.isHomeLoading && activity == null
                ? const _HomeLoadingState()
                : ListView(
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
                        activity?.phrases.first.english ?? 'Bath time, baby.',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: AppTheme.english),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '首页和练习页共用同一条本地事件链路：点播放、记反应、回到首页都能看到结果。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (viewModel.homeErrorMessage != null) ...[
                        const SizedBox(height: 20),
                        _HomeBanner(
                          key: const Key('home-error-banner'),
                          message: viewModel.homeErrorMessage!,
                          backgroundColor: AppTheme.errorSoft,
                          foregroundColor: AppTheme.error,
                          actionLabel: '重试',
                          onAction: viewModel.retryHomeLoad,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (activity != null)
                                Chip(label: Text(activity.sceneTag)),
                              const SizedBox(height: 16),
                              Text(
                                activity?.title ?? '洗澡时间',
                                key: const Key('home-hero-activity'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                activity?.summary ?? '正在加载今日活动摘要…',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                key: const Key('home-start-practice'),
                                onPressed: viewModel.canStartPractice
                                    ? () async {
                                        final ready = await context
                                            .read<PracticeSessionViewModel>()
                                            .ensureSessionReady();
                                        if (!context.mounted || !ready) {
                                          return;
                                        }
                                        Navigator.of(
                                          context,
                                        ).pushNamed(AppRouteNames.practice);
                                      }
                                    : null,
                                child: Text(
                                  homeSummary?.isEmpty ?? true
                                      ? '开始练习'
                                      : '继续练习',
                                ),
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
                            if (homeSummary == null || homeSummary.isEmpty)
                              Text(
                                '还没有本地练习记录，第一次打开也会看到安全空态。',
                                key: const Key('recent-result-empty'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              )
                            else
                              Column(
                                key: const Key('recent-result-summary'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${homeSummary.recentResult!.phraseEnglish} · ${viewModel.labelForReaction(homeSummary.recentResult!.reactionType)}',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${homeSummary.totalEvents} 条本地记录 · 最近一次 ${_formatTime(homeSummary.recentResult!.eventTime)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
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

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(key: Key('home-loading')),
      ),
    );
  }
}

class _HomeBanner extends StatelessWidget {
  const _HomeBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

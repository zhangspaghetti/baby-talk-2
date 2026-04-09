import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_view_model.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mentor_bubble.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mini_seed_card.dart';
import 'package:mobile/features/onboarding/presentation/widgets/quick_select_card.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  OnboardingViewModel? _viewModel;
  int _lastNavigationRequestToken = 0;
  OnboardingFlowStep? _lastHandledStep;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode();
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<OnboardingViewModel>();
    _attachViewModel(viewModel);
    if (_nameController.text != viewModel.draftName) {
      _nameController.value = TextEditingValue(
        text: viewModel.draftName,
        selection: TextSelection.collapsed(offset: viewModel.draftName.length),
      );
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_handleViewModelChanged);
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<OnboardingViewModel>();
    _syncFocusForStep(viewModel.currentStep);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Text('给你家宝宝准备第一次英文见面', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '只要昵称和月龄档，小禾老师就会先给你一颗适合现在阶段的 starter seed。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Container(
                  key: const Key('onboarding-local-only-banner'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.infoSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '同意前仅保存在这台设备，不需要精确生日。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildConversation(theme, viewModel),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.outlineSoft),
                    boxShadow: AppTheme.warmShadowSm,
                  ),
                  child: _StepComposer(
                    nameController: _nameController,
                    nameFocusNode: _nameFocusNode,
                    viewModel: viewModel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConversation(
    ThemeData theme,
    OnboardingViewModel viewModel,
  ) {
    final widgets = <Widget>[
      const MentorBubble(
        caption: '小禾老师',
        message: '你好，我会先帮你把英语放进今天就能开口的照护节奏里。',
      ),
    ];

    if (viewModel.currentStep.index >= OnboardingFlowStep.name.index ||
        viewModel.draftName.trim().isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(const MentorBubble(message: '我先怎么称呼宝宝？先用一个你最顺口的小昵称就好。'));
    }

    if (viewModel.draftName.trim().isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 12))
        ..add(_UserBubble(message: viewModel.draftName.trim()));
    }

    if (viewModel.currentStep.index >= OnboardingFlowStep.age.index ||
        viewModel.selectedAgeBucket != null) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(const MentorBubble(message: '现在大概几个月？我会用月龄档给你匹配阶段，不会要求精确生日。'));
    }

    final selectedAgeBucket = viewModel.selectedAgeBucket;
    final stageMatch = viewModel.stageMatch;
    if (selectedAgeBucket != null && stageMatch != null) {
      widgets
        ..add(const SizedBox(height: 12))
        ..add(
          _UserBubble(
            message: '${selectedAgeBucket.label} · ${stageMatch.title}',
          ),
        );
    }

    if (viewModel.currentStep == OnboardingFlowStep.preview &&
        selectedAgeBucket != null &&
        stageMatch != null) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(
          MentorBubble(
            message:
                '${viewModel.draftName.trim()} 现在更适合从这个阶段开始，先用一句真实 starter phrase 试试看。',
          ),
        )
        ..add(const SizedBox(height: 16))
        ..add(
          _StageMatchCard(
            key: const Key('onboarding-stage-match-card'),
            stageMatch: stageMatch,
          ),
        );

      final starterSeed = viewModel.starterSeed;
      if (starterSeed != null) {
        widgets
          ..add(const SizedBox(height: 16))
          ..add(
            MiniSeedCard(
              english: starterSeed.phraseEnglish,
              chinese: starterSeed.phraseChinese,
            ),
          );
      }
    }

    return widgets;
  }

  void _attachViewModel(OnboardingViewModel viewModel) {
    if (identical(_viewModel, viewModel)) {
      return;
    }
    _viewModel?.removeListener(_handleViewModelChanged);
    _viewModel = viewModel;
    _lastNavigationRequestToken = viewModel.navigationRequestToken;
    _lastHandledStep = viewModel.currentStep;
    viewModel.addListener(_handleViewModelChanged);
  }

  void _handleNameChanged() {
    _viewModel?.updateDraftName(_nameController.text);
  }

  void _handleViewModelChanged() {
    final viewModel = _viewModel;
    if (!mounted || viewModel == null) {
      return;
    }

    if (viewModel.navigationRequestToken != _lastNavigationRequestToken) {
      _lastNavigationRequestToken = viewModel.navigationRequestToken;
      final completedSnapshot = viewModel.completedSnapshot;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || completedSnapshot == null) {
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouteNames.shell,
          (route) => false,
          arguments: completedSnapshot,
        );
      });
    }
  }

  void _syncFocusForStep(OnboardingFlowStep step) {
    if (_lastHandledStep == step) {
      return;
    }
    _lastHandledStep = step;
    if (step == OnboardingFlowStep.name) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nameFocusNode.requestFocus();
        }
      });
      return;
    }
    if (_nameFocusNode.hasFocus) {
      _nameFocusNode.unfocus();
    }
  }
}

class _StepComposer extends StatelessWidget {
  const _StepComposer({
    required this.nameController,
    required this.nameFocusNode,
    required this.viewModel,
  });

  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.currentStep) {
      case OnboardingFlowStep.welcome:
        return _WelcomeStep(viewModel: viewModel);
      case OnboardingFlowStep.name:
        return _NameStep(
          viewModel: viewModel,
          nameController: nameController,
          nameFocusNode: nameFocusNode,
        );
      case OnboardingFlowStep.age:
        return _AgeStep(viewModel: viewModel);
      case OnboardingFlowStep.preview:
        return _PreviewStep(viewModel: viewModel);
    }
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.viewModel});

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '先准备两条信息：宝宝昵称 + 月龄档。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '完成后我会把阶段匹配和第一句 starter seed 一起交给你。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const Key('onboarding-start-button'),
          onPressed: viewModel.startFlow,
          child: const Text('开始建档'),
        ),
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.viewModel,
    required this.nameController,
    required this.nameFocusNode,
  });

  final OnboardingViewModel viewModel;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('onboarding-name-input'),
          controller: nameController,
          focusNode: nameFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => viewModel.continueFromName(),
          decoration: const InputDecoration(
            labelText: '宝宝昵称',
            hintText: '例如：米米、果果',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '先用一个顺口的小名就够了，之后还可以再改。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (viewModel.nameErrorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineErrorBanner(
            key: const Key('onboarding-name-error'),
            message: viewModel.nameErrorMessage!,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding-back-button'),
                onPressed: viewModel.goBack,
                child: const Text('上一步'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const Key('onboarding-name-continue'),
                onPressed: viewModel.continueFromName,
                child: const Text('继续'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgeStep extends StatelessWidget {
  const _AgeStep({required this.viewModel});

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('月龄快选', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('不需要精确到哪一天，先选最接近的一档就可以。', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        GridView.builder(
          key: const Key('onboarding-age-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: OnboardingAgeBucket.values.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.76,
          ),
          itemBuilder: (context, index) {
            final bucket = OnboardingAgeBucket.values[index];
            final stageMatch = StageMatchCatalog.forAgeBucket(bucket);
            return QuickSelectCard(
              key: Key('onboarding-age-card-${bucket.wireValue}'),
              label: bucket.label,
              caption: '${stageMatch.approxMonths}月左右',
              isSelected: viewModel.selectedAgeBucket == bucket,
              onTap: () => viewModel.selectAgeBucket(bucket),
            );
          },
        ),
        if (viewModel.isContentLoading) ...[
          const SizedBox(height: 12),
          Row(
            key: const Key('onboarding-content-loading'),
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '正在准备第一颗 starter seed…',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        if (viewModel.contentErrorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('onboarding-content-error-banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.contentErrorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('onboarding-content-retry'),
                  onPressed: viewModel.retryContentLoad,
                  child: const Text('重新准备'),
                ),
              ],
            ),
          ),
        ],
        if (viewModel.ageErrorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineErrorBanner(
            key: const Key('onboarding-age-error'),
            message: viewModel.ageErrorMessage!,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding-back-button'),
                onPressed: viewModel.goBack,
                child: const Text('上一步'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const Key('onboarding-age-continue'),
                onPressed: viewModel.continueFromAge,
                child: const Text('看看现在更适合什么'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.viewModel});

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final starterSeed = viewModel.starterSeed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '确认后会先写入本地档案，再带你进入首页。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text('如果保存失败，我会保留刚才的输入，方便你直接重试。', style: theme.textTheme.bodySmall),
        if (starterSeed != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('onboarding-preview-seed-text'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgSunken,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '准备先这样开口',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.english,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  starterSeed.phraseEnglish,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (starterSeed.phraseChinese.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    starterSeed.phraseChinese,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (viewModel.submitErrorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('onboarding-save-error-banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.errorSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              viewModel.submitErrorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding-back-button'),
                onPressed: viewModel.isSaving ? null : viewModel.goBack,
                child: const Text('返回调整'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const Key('onboarding-submit-button'),
                onPressed: viewModel.isSaving ? null : viewModel.submit,
                child: viewModel.isSaving
                    ? Row(
                        key: const Key('onboarding-submit-saving'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              '正在保存到本地',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : const Text('进入首页'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StageMatchCard extends StatelessWidget {
  const _StageMatchCard({super.key, required this.stageMatch});

  final StageMatch stageMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.bgAccentSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阶段匹配',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.accentDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stageMatch.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stageMatch.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            boxShadow: AppTheme.warmShadowSm,
          ),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }
}

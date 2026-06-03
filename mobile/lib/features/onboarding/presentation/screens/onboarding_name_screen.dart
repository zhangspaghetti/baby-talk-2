import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/l10n/app_localizations.dart';

class OnboardingNameScreen extends HookConsumerWidget {
  const OnboardingNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final name = useState('');
    final selectedAge = useState<OnboardingAgeBucket?>(null);

    useEffect(() {
      void listener() {
        name.value = controller.text;
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, const []);

    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: AppLayoutConstants.screenPadding,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      key: const Key('onboarding-name-skip-top'),
                      onPressed: () => _submit(context, ref, name.value.trim()),
                      child: Text(l.onboardingV21SkipButton),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayoutConstants.spacingSm),
                AppMentorBubble(
                  message: l.onboardingV21MentorGreeting,
                  caption: '小禾老师',
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                TextField(
                  key: const Key('onboarding-name-input'),
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: l.onboardingV21NameLabel,
                    hintText: l.onboardingV21NameHint,
                  ),
                  onSubmitted: (_) {
                    _submit(context, ref, name.value.trim());
                  },
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                Text(
                  l.onboardingV21AgeTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingSm),
                ...OnboardingAgeBucket.values.map((bucket) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppLayoutConstants.spacingXs,
                    ),
                    child: RadioListTile<OnboardingAgeBucket>(
                      key: Key('onboarding-age-${bucket.name}'),
                      value: bucket,
                      groupValue: selectedAge.value,
                      onChanged: (value) {
                        selectedAge.value = value;
                      },
                      title: Text(bucket.label),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: colors.accent,
                    ),
                  );
                }),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                ElevatedButton(
                  key: const Key('onboarding-name-next'),
                  onPressed: () => _submit(context, ref, name.value.trim()),
                  child: Text(l.onboardingV21SaveButton),
                ),
                const SizedBox(height: AppLayoutConstants.spacingMd),
                TextButton(
                  key: const Key('onboarding-name-skip-bottom'),
                  onPressed: () => _submit(context, ref, name.value.trim()),
                  child: Text(l.onboardingV21SkipButton),
                ),
                const SizedBox(height: AppLayoutConstants.spacingMd),
                Text(
                  key: const Key('onboarding-local-only-banner'),
                  l.onboardingLocalOnly,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context, WidgetRef ref, String name) {
    final notifier = ref.read(onboardingSessionProvider.notifier);
    if (name.isNotEmpty) {
      notifier.setChildName(name);
    }
    context.push('/onboarding/garden-welcome');
  }
}

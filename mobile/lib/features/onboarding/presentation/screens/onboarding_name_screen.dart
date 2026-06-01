import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/l10n/app_localizations.dart';

class OnboardingNameScreen extends HookConsumerWidget {
  const OnboardingNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final name = useState('');

    useEffect(() {
      void listener() {
        name.value = controller.text;
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, const []);

    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);

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
                const SizedBox(height: AppLayoutConstants.spacingXl),
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
                    if (name.value.trim().isNotEmpty) {
                      _submit(context, ref, name.value.trim());
                    }
                  },
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                ElevatedButton(
                  key: const Key('onboarding-name-next'),
                  onPressed: name.value.trim().isNotEmpty
                      ? () => _submit(context, ref, name.value.trim())
                      : null,
                  child: Text(l.onboardingV21NextButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context, WidgetRef ref, String name) {
    ref.read(onboardingSessionProvider.notifier).setChildName(name);
    context.push('/onboarding/scene');
  }
}

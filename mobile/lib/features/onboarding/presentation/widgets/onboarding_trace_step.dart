import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';

class OnboardingTraceStep extends StatelessWidget {
  const OnboardingTraceStep({super.key, required this.gardenTraceDegraded});

  final bool gardenTraceDegraded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l.onboardingTraceTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (gardenTraceDegraded) ...<Widget>[
          const SizedBox(height: 12),
          Text(l.onboardingTraceDegraded),
        ],
      ],
    );
  }
}

class OnboardingAccountInvitationStep extends StatelessWidget {
  const OnboardingAccountInvitationStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l.onboardingAccountTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          l.onboardingAccountBody,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

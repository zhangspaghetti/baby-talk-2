import 'package:flutter/material.dart';

class OnboardingFlowShell extends StatelessWidget {
  const OnboardingFlowShell({
    super.key,
    required this.progress,
    required this.body,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.isBusy = false,
  });

  final double progress;
  final Widget body;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final hasActions = primaryLabel != null || secondaryLabel != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: LinearProgressIndicator(value: progress.clamp(0, 1)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: body,
              ),
            ),
            if (hasActions)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (primaryLabel != null)
                        FilledButton(
                          key: const Key('onboarding-primary-action'),
                          onPressed: isBusy ? null : onPrimaryPressed,
                          child: isBusy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(primaryLabel!),
                        ),
                      if (secondaryLabel != null) ...<Widget>[
                        const SizedBox(height: 8),
                        TextButton(
                          key: const Key('onboarding-secondary-action'),
                          onPressed: isBusy ? null : onSecondaryPressed,
                          child: Text(secondaryLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

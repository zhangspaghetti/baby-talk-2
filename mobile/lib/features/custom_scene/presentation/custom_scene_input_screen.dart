import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_route_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

typedef CustomSceneAccountEntryOpener =
    Future<AccountEntryResult?> Function(BuildContext context);

typedef CustomScenePresetFallback = Future<void> Function();
typedef CustomScenePreparedContentOpener = Future<void> Function();

enum CustomSceneInputExit { presetFallback }

AppLocalizations _customSceneLocalizations(BuildContext context) {
  return AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
}

class CustomSceneInputScreen extends StatefulWidget {
  const CustomSceneInputScreen({
    super.key,
    required this.routeArgs,
    this.controller,
    this.accountEntryOpener,
    this.onPresetFallback,
    this.onOpenPreparedContent,
    this.clientRequestIdGenerator,
  });

  final CustomSceneRouteArgs routeArgs;
  final CustomSceneSubmissionController? controller;
  final CustomSceneAccountEntryOpener? accountEntryOpener;
  final CustomScenePresetFallback? onPresetFallback;
  final CustomScenePreparedContentOpener? onOpenPreparedContent;
  final String Function()? clientRequestIdGenerator;

  @override
  State<CustomSceneInputScreen> createState() => _CustomSceneInputScreenState();
}

class _CustomSceneInputScreenState extends State<CustomSceneInputScreen> {
  final _textController = TextEditingController();
  final _fieldFocusNode = FocusNode();
  String? _inputError;
  bool _authPrompted = false;
  bool _canPop = false;

  CustomSceneSubmissionController? get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller?.addListener(_handleSubmissionChange);
  }

  @override
  void didUpdateWidget(covariant CustomSceneInputScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleSubmissionChange);
      widget.controller?.addListener(_handleSubmissionChange);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleSubmissionChange);
    _textController.dispose();
    _fieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _customSceneLocalizations(context);
    final controller = _controller;
    final state = controller?.state;
    final busy = state?.isBusy ?? false;
    final message =
        _inputError ??
        _failureMessage(l, state?.failure) ??
        _submissionMessage(l, state?.message);
    final isAvailable = controller != null;
    final canOpenPreparedContent = state?.canOpenPreparedContent ?? false;
    final canCancelRetainedDraft = state?.canCancelRetainedDraft ?? false;
    final recoveryAction = state?.recoveryAction;

    return PopScope<Object?>(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_fieldFocusNode.hasFocus) {
          _fieldFocusNode.unfocus();
          return;
        }
        setState(() => _canPop = true);
        Navigator.of(context).pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(l.customSceneTitle)),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                key: const Key('custom-scene-input-scroll'),
                padding: EdgeInsets.fromLTRB(
                  AppLayoutConstants.spacingLg,
                  AppLayoutConstants.spacingLg,
                  AppLayoutConstants.spacingLg,
                  MediaQuery.viewInsetsOf(context).bottom +
                      AppLayoutConstants.spacingLg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.customSceneHeading,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Text(
                        l.customSceneDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingLg),
                      TextField(
                        key: const Key('custom-scene-text-field'),
                        controller: _textController,
                        focusNode: _fieldFocusNode,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 240,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: l.customSceneFieldLabel,
                          hintText: l.customSceneFieldHint,
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) {
                          if (_inputError != null) {
                            setState(() => _inputError = null);
                          }
                        },
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Semantics(
                        container: true,
                        label: l.customScenePrivacySemantics,
                        child: Text(
                          l.customScenePrivacyNote,
                          key: const Key('custom-scene-privacy-note'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.appColors.textMuted,
                                height: 1.45,
                              ),
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: AppLayoutConstants.spacingMd),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            key: const Key('custom-scene-input-message'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.appColors.error),
                          ),
                        ),
                      ],
                      if (recoveryAction != null) ...[
                        const SizedBox(height: AppLayoutConstants.spacingMd),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            key: const Key('custom-scene-recovery-action'),
                            onPressed: busy
                                ? null
                                : () => _openRecoveryAction(recoveryAction),
                            child: Text(
                              _recoveryActionLabel(l, recoveryAction),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppLayoutConstants.spacingXl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('custom-scene-submit-button'),
                          onPressed: !isAvailable || busy
                              ? null
                              : canOpenPreparedContent
                              ? (widget.onOpenPreparedContent == null
                                    ? null
                                    : () => unawaited(
                                        widget.onOpenPreparedContent!(),
                                      ))
                              : _submitOrContinueAuthentication,
                          child: Text(
                            canOpenPreparedContent
                                ? l.customSceneOpenPrepared
                                : busy
                                ? l.customScenePreparing
                                : state?.phase ==
                                      CustomSceneSubmissionPhase
                                          .needsAuthentication
                                ? l.customSceneContinueAfterLogin
                                : state?.phase ==
                                      CustomSceneSubmissionPhase.unknownOutcome
                                ? l.customSceneConfirmResult
                                : l.customSceneSubmit,
                          ),
                        ),
                      ),
                      if (canCancelRetainedDraft) ...[
                        const SizedBox(height: AppLayoutConstants.spacingSm),
                        Center(
                          child: TextButton(
                            key: const Key(
                              'custom-scene-cancel-retained-draft',
                            ),
                            onPressed: busy
                                ? null
                                : _confirmCancelRetainedDraft,
                            child: Text(l.customSceneCancelRetainedDraft),
                          ),
                        ),
                      ],
                      if (canOpenPreparedContent) ...[
                        const SizedBox(height: AppLayoutConstants.spacingSm),
                        Center(
                          child: TextButton(
                            key: const Key('custom-scene-abandon-prepared'),
                            onPressed: busy ? null : _confirmAbandonPrepared,
                            child: Text(l.customSceneAbandonPrepared),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Center(
                        child: TextButton(
                          key: const Key('custom-scene-preset-fallback'),
                          onPressed: busy ? null : _returnToPresetScenes,
                          child: Text(l.customSceneViewExisting),
                        ),
                      ),
                      if (!isAvailable) ...[
                        const SizedBox(height: AppLayoutConstants.spacingSm),
                        Text(
                          l.customSceneUnavailable,
                          key: const Key('custom-scene-unavailable-note'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.appColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrContinueAuthentication() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.state.phase ==
        CustomSceneSubmissionPhase.needsAuthentication) {
      await _openAuthentication();
      return;
    }
    if (controller.state.phase == CustomSceneSubmissionPhase.unknownOutcome) {
      await controller.retry();
      return;
    }
    if (controller.state.canOpenPreparedContent) {
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(
        () => _inputError = _customSceneLocalizations(
          context,
        ).customSceneEmptyInput,
      );
      _fieldFocusNode.requestFocus();
      return;
    }
    _fieldFocusNode.unfocus();
    await controller.submit(
      CustomSceneDraft(
        text: text,
        entrySource: widget.routeArgs.entrySource,
        requestIdentity: widget.clientRequestIdGenerator == null
            ? CustomSceneRequestIdentity.create()
            : CustomSceneRequestIdentity(
                clientRequestId: widget.clientRequestIdGenerator!.call(),
              ),
      ),
    );
  }

  void _handleSubmissionChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
    final state = _controller?.state;
    if (state?.phase == CustomSceneSubmissionPhase.needsAuthentication &&
        !_authPrompted) {
      _authPrompted = true;
      unawaited(_openAuthentication());
    }
  }

  Future<void> _openAuthentication() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final result = await (widget.accountEntryOpener ?? _defaultAccountOpener)(
      context,
    );
    if (!mounted || result != AccountEntryResult.signedIn) {
      return;
    }
    // Account-stable recovery is app-owned. This page only resumes rendering.
  }

  Future<void> _openRecoveryAction(CustomSceneRecoveryAction action) async {
    if (!mounted) {
      return;
    }
    switch (action) {
      case CustomSceneRecoveryAction.householdStatus:
        await GoRouter.of(
          context,
        ).push(AppRouteNames.account, extra: AccountEntryOrigin.settings);
      case CustomSceneRecoveryAction.babyProfile:
        await GoRouter.of(context).push(AppRouteNames.meBabyProfile);
    }
  }

  String _recoveryActionLabel(
    AppLocalizations l,
    CustomSceneRecoveryAction action,
  ) {
    return switch (action) {
      CustomSceneRecoveryAction.householdStatus =>
        l.customSceneViewHouseholdStatus,
      CustomSceneRecoveryAction.babyProfile => l.customSceneCompleteProfile,
    };
  }

  String? _failureMessage(AppLocalizations l, CustomSceneFailure? failure) {
    final kind = failure?.kind;
    if (kind == null) {
      return null;
    }
    return switch (kind) {
      CustomSceneFailureKind.authenticationRequired =>
        l.customSceneAuthenticationRequired,
      CustomSceneFailureKind.profileUnavailable =>
        l.customSceneProfileUnavailable,
      CustomSceneFailureKind.householdAccessRequired =>
        l.customSceneHouseholdAccessRequired,
      CustomSceneFailureKind.sharedProfileUnavailable =>
        l.customSceneSharedProfileUnavailable,
      CustomSceneFailureKind.presetSceneUnavailable =>
        l.customScenePresetSceneUnavailable,
      CustomSceneFailureKind.invalidDraft => l.customSceneInvalidDraft,
      CustomSceneFailureKind.requestConflict => l.customSceneRequestConflict,
      CustomSceneFailureKind.requestTerminal => l.customSceneRequestTerminal,
      CustomSceneFailureKind.generationInProgress =>
        l.customSceneGenerationInProgress,
      CustomSceneFailureKind.rateLimited => l.customSceneRateLimited,
      CustomSceneFailureKind.unavailable => l.customSceneUnavailableError,
      CustomSceneFailureKind.timeout => l.customSceneTimeout,
      CustomSceneFailureKind.network => l.customSceneNetwork,
      CustomSceneFailureKind.malformedResponse =>
        l.customSceneMalformedResponse,
      CustomSceneFailureKind.rejected => l.customSceneRejected,
      CustomSceneFailureKind.unexpected => l.customSceneUnexpected,
    };
  }

  String? _submissionMessage(
    AppLocalizations l,
    CustomSceneSubmissionMessage? message,
  ) {
    final key = message?.key;
    if (key == null) {
      return null;
    }
    return switch (key) {
      CustomSceneSubmissionMessageKey.anotherDraftPending =>
        l.customSceneSubmissionAnotherDraftPending,
      CustomSceneSubmissionMessageKey.authenticationRequired =>
        l.customSceneAuthenticationRequired,
      CustomSceneSubmissionMessageKey.restoreUnavailable =>
        l.customSceneSubmissionRestoreUnavailable,
      CustomSceneSubmissionMessageKey.accountChanged =>
        l.customSceneSubmissionAccountChanged,
      CustomSceneSubmissionMessageKey.unknownOutcome =>
        l.customSceneSubmissionUnknownOutcome,
      CustomSceneSubmissionMessageKey.previousRequestUnknown =>
        l.customSceneSubmissionPreviousRequestUnknown,
      CustomSceneSubmissionMessageKey.retryUnavailable =>
        l.customSceneSubmissionRetryUnavailable,
      CustomSceneSubmissionMessageKey.handoffRouteFailed =>
        l.customSceneSubmissionHandoffRouteFailed,
      CustomSceneSubmissionMessageKey.saveUnavailable =>
        l.customSceneSubmissionSaveUnavailable,
      CustomSceneSubmissionMessageKey.preparedContentSaveFailed =>
        l.customSceneSubmissionPreparedContentSaveFailed,
      CustomSceneSubmissionMessageKey.requestTerminal =>
        l.customSceneRequestTerminal,
      CustomSceneSubmissionMessageKey.draftExpired =>
        l.customSceneSubmissionDraftExpired,
      CustomSceneSubmissionMessageKey.draftRecoveryUnavailable =>
        l.customSceneSubmissionDraftRecoveryUnavailable,
      CustomSceneSubmissionMessageKey.draftInconsistent =>
        l.customSceneSubmissionDraftInconsistent,
    };
  }

  Future<AccountEntryResult?> _defaultAccountOpener(BuildContext context) {
    return GoRouter.of(context).push<AccountEntryResult>(
      '/account',
      extra: AccountEntryOrigin.customSceneContinuation,
    );
  }

  Future<void> _returnToPresetScenes() async {
    final fallback = widget.onPresetFallback;
    if (fallback != null) {
      await fallback();
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(CustomSceneInputExit.presetFallback);
  }

  Future<void> _confirmAbandonPrepared() async {
    final controller = _controller;
    if (controller == null || !controller.state.canOpenPreparedContent) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_customSceneLocalizations(context).customSceneAbandonTitle),
        content: Text(
          _customSceneLocalizations(context).customSceneAbandonBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_customSceneLocalizations(context).customSceneKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _customSceneLocalizations(context).customSceneConfirmAbandon,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await controller.abandonPreparedContent();
  }

  Future<void> _confirmCancelRetainedDraft() async {
    final controller = _controller;
    if (controller == null || !controller.state.canCancelRetainedDraft) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_customSceneLocalizations(context).customSceneCancelTitle),
        content: Text(_customSceneLocalizations(context).customSceneCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_customSceneLocalizations(context).customSceneKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _customSceneLocalizations(context).customSceneConfirmCancel,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await controller.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _textController.clear();
      _inputError = null;
    });
  }
}

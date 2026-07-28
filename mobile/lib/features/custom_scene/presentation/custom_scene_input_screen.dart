import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_route_args.dart';

typedef CustomSceneAccountEntryOpener =
    Future<AccountEntryResult?> Function(BuildContext context);

typedef CustomScenePresetFallback = Future<void> Function();
typedef CustomScenePreparedContentOpener = Future<void> Function();

enum CustomSceneInputExit { presetFallback }

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
    final controller = _controller;
    final state = controller?.state;
    final busy = state?.isBusy ?? false;
    final message = _inputError ?? state?.message;
    final isAvailable = controller != null;
    final canOpenPreparedContent = state?.canOpenPreparedContent ?? false;

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
        appBar: AppBar(title: const Text('描述一下此刻')),
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
                        '说说现在正在发生什么',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Text(
                        '写下你想回应的此刻，我们会帮你准备一句自然的表达。',
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
                        decoration: const InputDecoration(
                          labelText: '此刻发生了什么？',
                          hintText: '例如：洗澡时宝宝不想碰水。',
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
                        label: '隐私说明：请不要填写姓名、电话、地址或其他私密信息。',
                        child: Text(
                          '请不要填写姓名、电话、地址或其他私密信息。',
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
                                ? '打开已准备内容'
                                : busy
                                ? '正在准备…'
                                : state?.phase ==
                                      CustomSceneSubmissionPhase
                                          .needsAuthentication
                                ? '登录后继续'
                                : '帮我准备一句',
                          ),
                        ),
                      ),
                      if (canOpenPreparedContent) ...[
                        const SizedBox(height: AppLayoutConstants.spacingSm),
                        Center(
                          child: TextButton(
                            key: const Key('custom-scene-abandon-prepared'),
                            onPressed: busy ? null : _confirmAbandonPrepared,
                            child: const Text('放弃这条内容'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Center(
                        child: TextButton(
                          key: const Key('custom-scene-preset-fallback'),
                          onPressed: busy ? null : _returnToPresetScenes,
                          child: const Text('查看已有场景'),
                        ),
                      ),
                      if (!isAvailable) ...[
                        const SizedBox(height: AppLayoutConstants.spacingSm),
                        Text(
                          '这个入口正在准备中。',
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
    if (controller.state.canOpenPreparedContent) {
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _inputError = '请先描述一下此刻。');
      _fieldFocusNode.requestFocus();
      return;
    }
    _fieldFocusNode.unfocus();
    await controller.submit(
      CustomSceneDraft(
        text: text,
        entrySource: widget.routeArgs.entrySource,
        requestIdentity: CustomSceneRequestIdentity(
          clientRequestId:
              widget.clientRequestIdGenerator?.call() ?? _defaultRequestId(),
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
        title: const Text('放弃已准备内容？'),
        content: const Text('放弃后需要重新描述，才会准备新内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认放弃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await controller.abandonPreparedContent();
  }

  String _defaultRequestId() {
    return 'custom_scene_${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}

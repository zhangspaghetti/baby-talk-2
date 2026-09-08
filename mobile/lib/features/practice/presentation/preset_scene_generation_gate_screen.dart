import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/scene_generation/application/scene_generation_controller.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

typedef PresetSceneBundledFallbackLoader =
    Future<bool> Function(PracticeRouteArgs args);
typedef PresetSceneGeneratedRouteHandler =
    Future<void> Function(GeneratedCareTurnRouteArgs args);
typedef PresetSceneFallbackBuilder =
    Widget Function(BuildContext context, PracticeRouteEntry routeEntry);

/// Entry gate for signed-in preset practice.
///
/// The gate starts generation before rendering a practice session. A generic
/// bundled fallback is rendered in place when available, so it never pushes a
/// second preset route and cannot recursively re-enter this gate.
class PresetSceneGenerationGateScreen extends ConsumerStatefulWidget {
  const PresetSceneGenerationGateScreen({
    super.key,
    required this.routeEntry,
    this.controller,
    this.clientRequestId,
    this.bundledFallbackLoader,
    this.fallbackBuilder,
    this.onGenerated,
  });

  final PracticeRouteEntry routeEntry;
  final SceneGenerationController? controller;
  final String? clientRequestId;
  final PresetSceneBundledFallbackLoader? bundledFallbackLoader;
  final PresetSceneFallbackBuilder? fallbackBuilder;
  final PresetSceneGeneratedRouteHandler? onGenerated;

  @override
  ConsumerState<PresetSceneGenerationGateScreen> createState() =>
      _PresetSceneGenerationGateScreenState();
}

class _PresetSceneGenerationGateScreenState
    extends ConsumerState<PresetSceneGenerationGateScreen> {
  SceneGenerationController? _controller;
  Object? _controllerError;
  Future<bool>? _fallbackFuture;
  bool _fallbackAvailable = false;
  bool _useGenericFallback = false;
  bool _started = false;
  bool _navigationScheduled = false;

  String get _clientRequestId =>
      widget.clientRequestId?.trim().isNotEmpty == true
      ? widget.clientRequestId!.trim()
      : _defaultClientRequestId();

  PracticeRouteArgs? get _presetArgs => widget.routeEntry.args?.normalized();

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    if (injected != null) {
      _bindController(injected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startGeneration();
        }
      });
      return;
    }
    _resolveController();
  }

  void _resolveController() {
    ref
        .read(sceneGenerationControllerProvider.future)
        .then(
          (controller) {
            if (!mounted) {
              return;
            }
            _bindController(controller);
            _startGeneration();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) {
              return;
            }
            setState(() => _controllerError = error);
            _loadFallbackAvailability();
          },
        );
  }

  void _bindController(SceneGenerationController controller) {
    _controller = controller;
    controller.addListener(_handleControllerChange);
    _handleControllerChange();
  }

  void _handleControllerChange() {
    if (!mounted) {
      return;
    }
    final state = _controller?.state;
    if (state == null) {
      return;
    }
    if (state.status == SceneGenerationControllerStatus.recoverableError ||
        state.status == SceneGenerationControllerStatus.unknownOutcome) {
      _loadFallbackAvailability();
    }
    if (state.status == SceneGenerationControllerStatus.success) {
      _scheduleGeneratedRoute(state.moment?.generatedContentId);
    }
    setState(() {});
  }

  void _startGeneration() {
    if (_started || !mounted) {
      return;
    }
    final args = _presetArgs;
    final controller = _controller;
    if (args == null || controller == null) {
      if (args == null) {
        setState(
          () => _controllerError = const FormatException(
            'preset practice route args are invalid',
          ),
        );
        _loadFallbackAvailability();
      }
      return;
    }
    if (controller.state.status != SceneGenerationControllerStatus.idle) {
      _started = true;
      return;
    }
    _started = true;
    unawaited(
      controller.generate(
        source: PresetSceneGenerationSource(args.normalizedActivityId),
        clientRequestId: _clientRequestId,
      ),
    );
  }

  void _loadFallbackAvailability() {
    if (_fallbackFuture != null) {
      return;
    }
    final args = _presetArgs;
    if (args == null) {
      return;
    }
    final future = (widget.bundledFallbackLoader ?? _defaultFallbackLoader)(
      args,
    );
    _fallbackFuture = future;
    future.then(
      (available) {
        if (!mounted || !identical(_fallbackFuture, future)) {
          return;
        }
        setState(() => _fallbackAvailable = available);
      },
      onError: (Object _, StackTrace _) {
        if (!mounted || !identical(_fallbackFuture, future)) {
          return;
        }
        setState(() => _fallbackAvailable = false);
      },
    );
  }

  Future<bool> _defaultFallbackLoader(PracticeRouteArgs args) async {
    try {
      final repository = await ref.read(practiceRepositoryProvider.future);
      final snapshot = await repository.getBundledActivitySnapshot(
        spaceId: args.normalizedSpaceId,
        activityId: args.normalizedActivityId,
      );
      return snapshot.phrases.isNotEmpty &&
          snapshot.phrases.every(
            (phrase) => phrase.audioAsset.trim().isNotEmpty,
          );
    } on Object {
      return false;
    }
  }

  void _scheduleGeneratedRoute(String? generatedContentId) {
    final normalized = generatedContentId?.trim();
    if (_navigationScheduled || normalized == null || normalized.isEmpty) {
      return;
    }
    _navigationScheduled = true;
    final generatedArgs = GeneratedCareTurnRouteArgs(
      generatedContentId: normalized,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final handler = widget.onGenerated;
      if (handler != null) {
        await handler(generatedArgs);
        return;
      }
      context.pushReplacement(AppRouteNames.practice, extra: generatedArgs);
    });
  }

  Future<void> _retry() async {
    final controller = _controller;
    if (controller == null) {
      ref.invalidate(sceneGenerationControllerProvider);
      if (mounted) {
        setState(() => _controllerError = null);
        _resolveController();
      }
      return;
    }
    await controller.retry();
  }

  void _selectGenericFallback() {
    if (!_fallbackAvailable || !mounted) {
      return;
    }
    setState(() => _useGenericFallback = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_useGenericFallback) {
      final builder = widget.fallbackBuilder;
      return builder?.call(context, widget.routeEntry) ??
          PracticeSessionScreen(routeEntry: widget.routeEntry);
    }

    final controllerState = _controller?.state;
    if (_controllerError != null) {
      return _PresetGenerationFailureScaffold(
        failure: _controllerError is SceneGenerationFailure
            ? _controllerError as SceneGenerationFailure
            : const SceneGenerationFailure(
                kind: SceneGenerationFailureKind.unavailable,
                retryable: true,
              ),
        fallbackAvailable: _fallbackAvailable,
        onRetry: _retry,
        onGenericFallback: _selectGenericFallback,
      );
    }

    if (controllerState == null ||
        controllerState.status == SceneGenerationControllerStatus.idle ||
        controllerState.status == SceneGenerationControllerStatus.submitting) {
      return const _PresetGenerationProgressScaffold();
    }

    if (controllerState.status == SceneGenerationControllerStatus.success) {
      return const SizedBox.shrink();
    }

    final failure = controllerState.failure;
    return _PresetGenerationFailureScaffold(
      failure: failure,
      fallbackAvailable: _fallbackAvailable,
      onRetry: _retry,
      onGenericFallback: _selectGenericFallback,
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChange);
    super.dispose();
  }
}

class _PresetGenerationProgressScaffold extends StatelessWidget {
  const _PresetGenerationProgressScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(key: Key('preset-generation-progress')),
              SizedBox(height: 16),
              Text(
                '正在为宝宝准备个性化练习…',
                key: Key('preset-generation-progress-text'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetGenerationFailureScaffold extends StatelessWidget {
  const _PresetGenerationFailureScaffold({
    required this.failure,
    required this.fallbackAvailable,
    required this.onRetry,
    required this.onGenericFallback,
  });

  final SceneGenerationFailure? failure;
  final bool fallbackAvailable;
  final Future<void> Function() onRetry;
  final VoidCallback onGenericFallback;

  @override
  Widget build(BuildContext context) {
    final message = failure?.presentationMessage ?? '个性化练习暂时不可用，请重试。';
    return Scaffold(
      key: const Key('preset-generation-error'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: const Key('preset-generation-retry'),
                  child: FilledButton(
                    key: const Key('preset-generation-retry-button'),
                    onPressed: onRetry,
                    child: const Text('重试'),
                  ),
                ),
                if (fallbackAvailable) ...[
                  const SizedBox(height: 8),
                  KeyedSubtree(
                    key: const Key('preset-generation-generic-fallback'),
                    child: OutlinedButton(
                      key: const Key(
                        'preset-generation-generic-fallback-button',
                      ),
                      onPressed: onGenericFallback,
                      child: const Text('使用通用内容'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _defaultClientRequestId() {
  final nonce = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
  return 'preset_$nonce';
}

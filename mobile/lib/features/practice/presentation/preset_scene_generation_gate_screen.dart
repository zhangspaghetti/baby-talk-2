import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';
import 'package:mobile/features/scene_generation/application/scene_generation_controller.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/l10n/app_localizations_zh.dart';

typedef PresetSceneBundledFallbackLoader =
    Future<bool> Function(PracticeRouteArgs args);
typedef PresetSceneGeneratedRouteHandler =
    Future<void> Function(GeneratedCareTurnRouteArgs args);
typedef PresetSceneFallbackBuilder =
    Widget Function(BuildContext context, PracticeRouteEntry routeEntry);
typedef PresetSceneDefinitionLoader =
    Future<PresetSceneDefinition?> Function(PracticeRouteArgs args);

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
    this.presetDefinitionLoader,
    this.refreshCatalog,
    this.fallbackBuilder,
    this.onGenerated,
  });

  final PracticeRouteEntry routeEntry;
  final SceneGenerationController? controller;
  final String? clientRequestId;
  final PresetSceneBundledFallbackLoader? bundledFallbackLoader;
  final PresetSceneDefinitionLoader? presetDefinitionLoader;
  final Future<void> Function()? refreshCatalog;
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
  bool _providerResolutionScheduled = false;
  bool _controllerAttachScheduled = false;
  bool _retryAfterCatalogRefresh = false;
  PresetSceneDefinition? _presetDefinition;
  PresetSceneGenerationSource? _generationSource;
  int _routeGeneration = 0;

  String get _clientRequestId =>
      widget.clientRequestId?.trim().isNotEmpty == true
      ? widget.clientRequestId!.trim()
      : _defaultClientRequestId();

  PracticeRouteArgs? get _presetArgs => widget.routeEntry.args?.normalized();

  String get _controllerProviderKey => _presetArgs == null
      ? widget.routeEntry.scopeLabel
      : '${_presetArgs!.scopeLabel}@v${_presetDefinition?.publishedVersion ?? _presetArgs!.publishedVersion ?? 0}';

  @override
  void initState() {
    super.initState();
    _schedulePreparation();
  }

  @override
  void didUpdateWidget(covariant PresetSceneGenerationGateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged =
        oldWidget.routeEntry.scopeLabel != widget.routeEntry.scopeLabel ||
        oldWidget.routeEntry.args?.publishedVersion !=
            widget.routeEntry.args?.publishedVersion ||
        oldWidget.controller != widget.controller ||
        oldWidget.clientRequestId != widget.clientRequestId;
    if (!routeChanged) {
      return;
    }

    _routeGeneration += 1;
    _controller?.removeListener(_handleControllerChange);
    _controller = null;
    _controllerError = null;
    _fallbackFuture = null;
    _fallbackAvailable = false;
    _useGenericFallback = false;
    _started = false;
    _navigationScheduled = false;
    _providerResolutionScheduled = false;
    _controllerAttachScheduled = false;
    _retryAfterCatalogRefresh = false;
    _presetDefinition = null;
    _generationSource = null;
    _schedulePreparation();
  }

  void _schedulePreparation() {
    if (_providerResolutionScheduled) {
      return;
    }
    _providerResolutionScheduled = true;
    final routeGeneration = _routeGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || routeGeneration != _routeGeneration) {
        return;
      }
      _providerResolutionScheduled = false;
      unawaited(_prepareAndAttachController(routeGeneration: routeGeneration));
    });
  }

  Future<void> _prepareAndAttachController({
    required int routeGeneration,
  }) async {
    final args = _presetArgs;
    if (args == null) {
      if (mounted) {
        setState(
          () => _controllerError = const FormatException(
            'preset practice route args are invalid',
          ),
        );
        _loadFallbackAvailability();
      }
      return;
    }

    final definitionLoader =
        widget.presetDefinitionLoader ?? _defaultPresetDefinitionLoader;
    final PresetSceneDefinition? definition;
    try {
      definition = await definitionLoader(args);
      if (definition == null ||
          definition.spaceId != args.normalizedSpaceId ||
          definition.presetSceneId != args.normalizedActivityId ||
          args.publishedVersion != null &&
              definition.publishedVersion != args.publishedVersion) {
        throw const FormatException('preset route catalog identity mismatch');
      }
    } on Object {
      if (!mounted || routeGeneration != _routeGeneration) {
        return;
      }
      setState(
        () => _controllerError = const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.presetSceneUnavailable,
          retryable: true,
        ),
      );
      _loadFallbackAvailability();
      return;
    }

    if (!mounted || routeGeneration != _routeGeneration) {
      return;
    }
    setState(() {
      _presetDefinition = definition;
      _generationSource = _sourceFor(args, definition: definition);
      _controllerError = null;
    });

    final injectedController = widget.controller;
    if (injectedController != null) {
      _bindController(injectedController);
      _startGeneration();
    }
  }

  void _bindController(SceneGenerationController controller) {
    if (identical(_controller, controller)) {
      _handleControllerChange();
      return;
    }
    _controller?.removeListener(_handleControllerChange);
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
      final moment = state.moment;
      if (moment == null || !_matchesGeneratedMoment(moment)) {
        _navigationScheduled = false;
        _controllerError = _generatedIdentityFailure();
        _loadFallbackAvailability();
      } else {
        _controllerError = null;
        _scheduleGeneratedRoute(moment.generatedContentId);
      }
    }
    setState(() {});
  }

  Future<void> _startGeneration() async {
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
      final existingSource = controller.source;
      _started = true;
      if (existingSource is! PresetSceneGenerationSource ||
          !existingSource.hasCompleteIdentity ||
          !_sourceMatchesRoute(existingSource, args)) {
        _controllerError = _generatedIdentityFailure();
        _loadFallbackAvailability();
        setState(() {});
        return;
      }
      _generationSource = existingSource;
      if (_retryAfterCatalogRefresh &&
          controller.failure?.kind ==
              SceneGenerationFailureKind.presetSceneUnavailable) {
        _retryAfterCatalogRefresh = false;
        await controller.retry();
        return;
      }
      _handleControllerChange();
      return;
    }
    _started = true;
    _retryAfterCatalogRefresh = false;
    final source = _generationSource ?? _sourceFor(args);
    _generationSource = source;
    await controller.generate(
      source: source,
      clientRequestId: _clientRequestId,
    );
  }

  PresetSceneGenerationSource _sourceFor(
    PracticeRouteArgs args, {
    PresetSceneDefinition? definition,
  }) {
    return PresetSceneGenerationSource(
      args.normalizedActivityId,
      presetSceneVersion:
          definition?.publishedVersion ?? _presetDefinition?.publishedVersion,
      spaceId: args.normalizedSpaceId,
      activityId: args.normalizedActivityId,
    );
  }

  Future<PresetSceneDefinition?> _defaultPresetDefinitionLoader(
    PracticeRouteArgs args,
  ) async {
    final catalog = await ref
        .read(presetSceneCatalogRepositoryProvider)
        .loadCatalog();
    for (final definition in catalog.scenes) {
      if (definition.spaceId == args.normalizedSpaceId &&
          definition.presetSceneId == args.normalizedActivityId) {
        return definition;
      }
    }
    return null;
  }

  bool _matchesGeneratedMoment(GeneratedCareMoment moment) {
    final source = _generationSource;
    if (source == null) {
      return false;
    }
    return switch (source) {
      PresetSceneGenerationSource(
        :final presetSceneId,
        :final presetSceneVersion,
        :final spaceId,
        :final activityId,
      ) =>
        source.hasCompleteIdentity &&
            moment.inputSource == SceneGenerationSourceType.preset &&
            moment.presetSceneId == presetSceneId.trim() &&
            moment.presetSceneVersion == presetSceneVersion &&
            moment.spaceId == spaceId!.trim() &&
            moment.activityId == activityId!.trim(),
    };
  }

  bool _sourceMatchesRoute(
    PresetSceneGenerationSource source,
    PracticeRouteArgs args,
  ) {
    final expectedVersion =
        _presetDefinition?.publishedVersion ?? args.publishedVersion;
    return source.presetSceneId.trim() == args.normalizedActivityId &&
        source.presetSceneVersion == expectedVersion &&
        source.spaceId?.trim() == args.normalizedSpaceId &&
        source.activityId?.trim() == args.normalizedActivityId;
  }

  SceneGenerationFailure _generatedIdentityFailure() {
    return const SceneGenerationFailure(
      kind: SceneGenerationFailureKind.malformedResponse,
      retryable: false,
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
    final routeGeneration = _routeGeneration;
    final scopeLabel = widget.routeEntry.scopeLabel;
    final generatedArgs = GeneratedCareTurnRouteArgs(
      generatedContentId: normalized,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          routeGeneration != _routeGeneration ||
          widget.routeEntry.scopeLabel != scopeLabel ||
          _controller?.state.status !=
              SceneGenerationControllerStatus.success ||
          _controller?.state.moment?.generatedContentId != normalized) {
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
      if (_controllerError is SceneGenerationFailure &&
          (_controllerError as SceneGenerationFailure).kind ==
              SceneGenerationFailureKind.presetSceneUnavailable) {
        await _refreshCatalogAndRetry();
        return;
      }
      ref.invalidate(sceneGenerationControllerProvider(_controllerProviderKey));
      if (mounted) {
        setState(() {
          _controllerError = null;
          _providerResolutionScheduled = false;
          _controllerAttachScheduled = false;
          _presetDefinition = null;
          _generationSource = null;
          _started = false;
        });
        _schedulePreparation();
      }
      return;
    }
    if (controller.failure?.kind ==
        SceneGenerationFailureKind.presetSceneUnavailable) {
      await _refreshCatalogAndRetry();
      return;
    }
    if (controller.state.status == SceneGenerationControllerStatus.idle) {
      setState(() {
        _controllerError = null;
        _presetDefinition = null;
        _generationSource = null;
        _started = false;
      });
      _schedulePreparation();
      return;
    }
    await controller.retry();
  }

  Future<void> _refreshCatalogAndRetry() async {
    final routeGeneration = _routeGeneration;
    final args = _presetArgs;
    if (args == null) {
      return;
    }
    setState(() {
      _controller?.removeListener(_handleControllerChange);
      _controller = null;
      _controllerError = null;
      _fallbackFuture = null;
      _fallbackAvailable = false;
      _presetDefinition = null;
      _generationSource = null;
      _started = false;
      _controllerAttachScheduled = false;
      _retryAfterCatalogRefresh = true;
    });
    try {
      final refreshCatalog = widget.refreshCatalog;
      if (refreshCatalog != null) {
        await refreshCatalog();
      } else {
        await ref.read(presetSceneCatalogRepositoryProvider).refreshCatalog();
      }
    } on Object {
      // A custom definition loader or an offline cache may still resolve the
      // current published definition below.
    }
    if (!mounted || routeGeneration != _routeGeneration) {
      return;
    }
    _schedulePreparation();
  }

  void _selectGenericFallback() {
    if (!_fallbackAvailable || !mounted) {
      return;
    }
    setState(() => _useGenericFallback = true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller == null && _presetDefinition != null) {
      // Keep identity-keyed provider alive while preparation awaits it. The
      // preparation path resolves the catalog definition before binding.
      final providerValue = ref.watch(
        sceneGenerationControllerProvider(_controllerProviderKey),
      );
      if (!_controllerAttachScheduled &&
          _controller == null &&
          _controllerError == null) {
        final providerController = providerValue.valueOrNull;
        if (providerController != null) {
          _controllerAttachScheduled = true;
          final routeGeneration = _routeGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || routeGeneration != _routeGeneration) {
              return;
            }
            _bindController(providerController);
            _startGeneration();
          });
        } else if (providerValue.hasError) {
          _controllerAttachScheduled = true;
          final providerError = providerValue.error;
          final routeGeneration = _routeGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || routeGeneration != _routeGeneration) {
              return;
            }
            setState(() => _controllerError = providerError);
            _loadFallbackAvailability();
          });
        }
      }
    }

    if (_useGenericFallback) {
      final builder = widget.fallbackBuilder;
      if (builder != null) {
        return builder(context, widget.routeEntry);
      }
      final args = widget.routeEntry.args;
      return PracticeSessionScreen(
        routeEntry: widget.routeEntry,
        genericFallbackArgs: args == null
            ? null
            : GenericFallbackPracticeRouteArgs(presetArgs: args),
      );
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
    final l = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(key: Key('preset-generation-progress')),
              SizedBox(height: 16),
              Text(
                l.presetGenerationProgress,
                key: const Key('preset-generation-progress-text'),
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
    final l = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final message = _localizedFailureMessage(l, failure);
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
                    child: Text(l.retry),
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
                      child: Text(l.presetGenerationGenericFallback),
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

String _localizedFailureMessage(
  AppLocalizations l,
  SceneGenerationFailure? failure,
) {
  final kind = failure?.kind;
  return switch (kind) {
    null => l.presetGenerationUnavailable,
    SceneGenerationFailureKind.authenticationRequired =>
      l.sceneGenerationAuthenticationRequired,
    SceneGenerationFailureKind.profileUnavailable =>
      l.sceneGenerationProfileUnavailable,
    SceneGenerationFailureKind.sharedProfileUnavailable =>
      l.sceneGenerationSharedProfileUnavailable,
    SceneGenerationFailureKind.householdAccessRequired =>
      l.sceneGenerationHouseholdAccessRequired,
    SceneGenerationFailureKind.presetSceneUnavailable =>
      l.sceneGenerationPresetUnavailable,
    SceneGenerationFailureKind.invalidInput => l.sceneGenerationInvalidInput,
    SceneGenerationFailureKind.requestConflict =>
      l.sceneGenerationRequestConflict,
    SceneGenerationFailureKind.requestTerminal =>
      l.sceneGenerationRequestTerminal,
    SceneGenerationFailureKind.generationInProgress =>
      l.sceneGenerationInProgress,
    SceneGenerationFailureKind.rateLimited => l.sceneGenerationRateLimited,
    SceneGenerationFailureKind.unavailable => l.sceneGenerationUnavailable,
    SceneGenerationFailureKind.timeout => l.sceneGenerationTimeout,
    SceneGenerationFailureKind.network => l.sceneGenerationNetwork,
    SceneGenerationFailureKind.malformedResponse =>
      l.sceneGenerationMalformedResponse,
    SceneGenerationFailureKind.rejected => l.sceneGenerationRejected,
    SceneGenerationFailureKind.unexpected => l.sceneGenerationUnexpected,
  };
}

String _defaultClientRequestId() {
  final nonce = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
  return 'preset_$nonce';
}

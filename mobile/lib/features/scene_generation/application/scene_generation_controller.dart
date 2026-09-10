import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

enum SceneGenerationControllerStatus {
  idle,
  submitting,
  success,
  recoverableError,
  unknownOutcome,
}

typedef SceneGenerationControllerPhase = SceneGenerationControllerStatus;
typedef SceneGenerationStatus = SceneGenerationControllerStatus;
typedef SceneGenerationPhase = SceneGenerationControllerStatus;

@immutable
class SceneGenerationControllerState {
  const SceneGenerationControllerState({
    required this.status,
    this.moment,
    this.failure,
  });

  const SceneGenerationControllerState.idle()
    : status = SceneGenerationControllerStatus.idle,
      moment = null,
      failure = null;

  final SceneGenerationControllerStatus status;
  final GeneratedCareMoment? moment;
  final SceneGenerationFailure? failure;

  SceneGenerationControllerStatus get phase => status;

  SceneGenerationFailure? get error => failure;

  String? get generatedContentId =>
      moment?.generatedContentId ?? failure?.generatedContentId;

  String? get message => failure?.presentationMessage;

  bool get isBusy => status == SceneGenerationControllerStatus.submitting;

  bool get canRetry =>
      status == SceneGenerationControllerStatus.recoverableError ||
      status == SceneGenerationControllerStatus.unknownOutcome;
}

typedef SceneGenerationApprovedBundleRegistrar =
    Future<void> Function(GeneratedCareMoment moment);
typedef SceneGenerationRequestIdGenerator = String Function();

/// Owns one preset-generation attempt and its durable approved-content handoff.
///
/// A request identity is captured on the first [generate] call and reused by
/// [retry]. Registration completes before [state] becomes [success]. If
/// registration fails after generation, the approved moment stays pending so a
/// retry repairs registration without issuing another logical generation.
class SceneGenerationController extends ChangeNotifier {
  SceneGenerationController({
    required SceneGenerationRepository repository,
    required SceneGenerationApprovedBundleRegistrar approvedBundleRegistrar,
    SceneGenerationRequestIdGenerator? clientRequestIdGenerator,
  }) : _repository = repository,
       _approvedBundleRegistrar = approvedBundleRegistrar,
       _clientRequestIdGenerator =
           clientRequestIdGenerator ?? _defaultSceneGenerationClientRequestId;

  final SceneGenerationRepository _repository;
  final SceneGenerationApprovedBundleRegistrar _approvedBundleRegistrar;
  final SceneGenerationRequestIdGenerator _clientRequestIdGenerator;

  SceneGenerationControllerState _state =
      const SceneGenerationControllerState.idle();
  SceneGenerationSource? _source;
  String? _clientRequestId;
  GeneratedCareMoment? _pendingRegistration;
  Future<void>? _activeOperation;
  bool _requiresNewClientRequestIdOnRetry = false;
  bool _disposed = false;

  SceneGenerationControllerState get state => _state;

  SceneGenerationControllerStatus get status => _state.status;

  SceneGenerationControllerStatus get phase => _state.status;

  SceneGenerationFailure? get failure => _state.failure;

  SceneGenerationSource? get source => _source;

  String? get clientRequestId => _clientRequestId;

  Future<void> generate({
    required SceneGenerationSource source,
    required String clientRequestId,
  }) {
    final active = _activeOperation;
    if (active != null) {
      return active;
    }
    if (_source != null && !_sameSourceIdentity(_source!, source)) {
      _setFailure(
        const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.malformedResponse,
          retryable: false,
        ),
      );
      return Future<void>.value();
    }
    if (_state.status == SceneGenerationControllerStatus.success) {
      return Future<void>.value();
    }

    _source ??= source;
    _clientRequestId ??= clientRequestId;
    final operation = _run();
    _activeOperation = operation;
    operation.then<void>(
      (_) => _clearActive(operation),
      onError: (Object _, StackTrace _) => _clearActive(operation),
    );
    return operation;
  }

  Future<void> retry() {
    final active = _activeOperation;
    if (active != null) {
      return active;
    }
    final source = _source;
    final clientRequestId = _clientRequestId;
    if (source == null || clientRequestId == null) {
      return Future<void>.value();
    }
    if (_state.status == SceneGenerationControllerStatus.success) {
      return Future<void>.value();
    }

    if (_requiresNewClientRequestIdOnRetry && _pendingRegistration == null) {
      _clientRequestId = _nextRequestId(clientRequestId);
      _requiresNewClientRequestIdOnRetry = false;
    }

    final operation = _run();
    _activeOperation = operation;
    operation.then<void>(
      (_) => _clearActive(operation),
      onError: (Object _, StackTrace _) => _clearActive(operation),
    );
    return operation;
  }

  Future<void> _run() async {
    _setState(
      const SceneGenerationControllerState(
        status: SceneGenerationControllerStatus.submitting,
      ),
    );

    var moment = _pendingRegistration;
    if (moment == null) {
      final source = _source;
      final clientRequestId = _clientRequestId;
      if (source == null || clientRequestId == null) {
        _setFailure(
          const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.invalidInput,
          ),
        );
        return;
      }
      if (source is PresetSceneGenerationSource &&
          !source.hasCompleteIdentity) {
        _setFailure(
          const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.malformedResponse,
          ),
        );
        return;
      }
      try {
        final generatedMoment = await _repository.generate(
          source: source,
          clientRequestId: clientRequestId,
        );
        final identityFailure = _identityFailure(
          source: source,
          moment: generatedMoment,
        );
        if (identityFailure != null) {
          _setFailure(identityFailure);
          return;
        }
        moment = generatedMoment;
        _pendingRegistration = moment;
      } on SceneGenerationFailure catch (failure) {
        _requiresNewClientRequestIdOnRetry = _shouldAllocateNewClientRequestId(
          failure,
        );
        _setFailure(failure);
        return;
      } on Object {
        _setFailure(
          const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.unexpected,
            retryable: true,
          ),
        );
        return;
      }
    }

    try {
      await _approvedBundleRegistrar(moment);
    } on SceneGenerationFailure catch (failure) {
      _setState(
        SceneGenerationControllerState(
          status: SceneGenerationControllerStatus.unknownOutcome,
          failure: SceneGenerationFailure(
            kind: failure.kind,
            generatedContentId: moment.generatedContentId,
            retryable: true,
            requiresNewClientRequestId: failure.requiresNewClientRequestId,
          ),
        ),
      );
      return;
    } on Object {
      _setState(
        SceneGenerationControllerState(
          status: SceneGenerationControllerStatus.unknownOutcome,
          failure: SceneGenerationFailure(
            kind: SceneGenerationFailureKind.unexpected,
            generatedContentId: moment.generatedContentId,
            retryable: true,
          ),
        ),
      );
      return;
    }

    _pendingRegistration = null;
    _setState(
      SceneGenerationControllerState(
        status: SceneGenerationControllerStatus.success,
        moment: moment,
      ),
    );
  }

  void _setFailure(SceneGenerationFailure failure) {
    _requiresNewClientRequestIdOnRetry = _shouldAllocateNewClientRequestId(
      failure,
    );
    final unknownOutcome =
        failure.kind == SceneGenerationFailureKind.timeout ||
        failure.kind == SceneGenerationFailureKind.network ||
        failure.kind == SceneGenerationFailureKind.generationInProgress ||
        (failure.kind == SceneGenerationFailureKind.unavailable &&
            failure.retryable) ||
        failure.kind == SceneGenerationFailureKind.unexpected;
    _setState(
      SceneGenerationControllerState(
        status: unknownOutcome
            ? SceneGenerationControllerStatus.unknownOutcome
            : SceneGenerationControllerStatus.recoverableError,
        failure: failure,
      ),
    );
  }

  bool _shouldAllocateNewClientRequestId(SceneGenerationFailure failure) {
    return _pendingRegistration == null &&
        failure.kind == SceneGenerationFailureKind.requestTerminal &&
        failure.requiresNewClientRequestId;
  }

  SceneGenerationFailure? _identityFailure({
    required SceneGenerationSource source,
    required GeneratedCareMoment moment,
  }) {
    final matches = switch (source) {
      CustomSceneGenerationSource() =>
        moment.inputSource == SceneGenerationSourceType.custom,
      PresetSceneGenerationSource(
        :final presetSceneId,
        :final presetSceneVersion,
        :final spaceId,
        :final activityId,
      ) =>
        moment.inputSource == SceneGenerationSourceType.preset &&
            moment.presetSceneId == presetSceneId.trim() &&
            moment.presetSceneVersion == presetSceneVersion &&
            moment.spaceId == spaceId!.trim() &&
            moment.activityId == activityId!.trim(),
    };
    if (matches) {
      return null;
    }
    return const SceneGenerationFailure(
      kind: SceneGenerationFailureKind.malformedResponse,
      retryable: false,
    );
  }

  bool _sameSourceIdentity(
    SceneGenerationSource left,
    SceneGenerationSource right,
  ) {
    if (left is CustomSceneGenerationSource &&
        right is CustomSceneGenerationSource) {
      return left.text == right.text;
    }
    if (left is PresetSceneGenerationSource &&
        right is PresetSceneGenerationSource) {
      return left.presetSceneId.trim() == right.presetSceneId.trim() &&
          left.presetSceneVersion == right.presetSceneVersion &&
          left.spaceId?.trim() == right.spaceId?.trim() &&
          left.activityId?.trim() == right.activityId?.trim();
    }
    return false;
  }

  String _nextRequestId(String previous) {
    final candidate = _clientRequestIdGenerator().trim();
    if (candidate.isNotEmpty && candidate != previous) {
      return candidate;
    }
    const suffix = '_retry';
    if (previous.length + suffix.length <= 96) {
      return '$previous$suffix';
    }
    return '${previous.substring(0, 96 - suffix.length)}$suffix';
  }

  void _setState(SceneGenerationControllerState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  void _clearActive(Future<void> operation) {
    if (identical(_activeOperation, operation)) {
      _activeOperation = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Default route-scoped controller. Each preset route identity gets an
/// independent auto-disposed controller. Tests and embedded flows can inject
/// a controller directly into [PresetSceneGenerationGateScreen].
final sceneGenerationControllerProvider = FutureProvider.autoDispose
    .family<SceneGenerationController, String>((ref, _) async {
      final repository = await ref.watch(
        sceneGenerationRepositoryProvider.future,
      );
      final registry = ref.watch(generatedPracticeContentRegistryProvider);
      final controller = SceneGenerationController(
        repository: repository,
        approvedBundleRegistrar: (moment) async {
          final accountContext = await registry.loadCurrentAccountContext();
          if (accountContext == null) {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.authenticationRequired,
            );
          }
          await registry.register(
            accountContext: accountContext,
            moment: moment,
          );
        },
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

String _defaultSceneGenerationClientRequestId() {
  final nonce = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
  return 'scene_$nonce';
}

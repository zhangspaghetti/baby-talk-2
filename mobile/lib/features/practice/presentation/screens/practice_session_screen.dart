import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/widgets/care_turn_surface.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

class PracticeSessionScreen extends ConsumerWidget {
  const PracticeSessionScreen({
    super.key,
    required this.routeEntry,
    this.audioControllerFactory,
  });

  final PracticeRouteEntry routeEntry;
  final PracticeAudioController Function()? audioControllerFactory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    if (!routeEntry.hasValidArgs) {
      return PracticeFallbackScaffold(
        message: _careTurnFallbackCopy(
          routeEntry.errorMessage ?? l.practiceInvalidParams,
        ),
      );
    }

    final repositoryValue = ref.watch(practiceRepositoryProvider);
    return repositoryValue.when(
      data: (_) => _PracticeSessionBody(
        routeArgs: routeEntry.args!,
        audioControllerFactory: audioControllerFactory,
      ),
      loading: () => const _PracticeLoadingScaffold(),
      error: (error, stackTrace) => PracticeFallbackScaffold(
        message: _careTurnFallbackCopy(l.homePracticeUnavailable),
      ),
    );
  }

  String _careTurnFallbackCopy(String message) {
    return message
        .replaceAll('练习', '照护')
        .replaceAll('课程', '场景')
        .replaceAll('进度', '节奏')
        .replaceAll('完成', '收尾');
  }
}

class _PracticeLoadingScaffold extends StatelessWidget {
  const _PracticeLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            key: Key('practice-repository-loading'),
          ),
        ),
      ),
    );
  }
}

class _PracticeSessionBody extends ConsumerStatefulWidget {
  const _PracticeSessionBody({
    required this.routeArgs,
    required this.audioControllerFactory,
  });

  final PracticeRouteArgs routeArgs;
  final PracticeAudioController Function()? audioControllerFactory;

  @override
  ConsumerState<_PracticeSessionBody> createState() =>
      _PracticeSessionBodyState();
}

class _PracticeSessionBodyState extends ConsumerState<_PracticeSessionBody> {
  String? _requestedMomentKey;
  String? _completedMomentKey;
  int _startGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scheduleStartMoment();
  }

  @override
  void didUpdateWidget(covariant _PracticeSessionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routeScopeKey(oldWidget.routeArgs) !=
        _routeScopeKey(widget.routeArgs)) {
      _scheduleStartMoment();
    }
  }

  String _routeScopeKey(PracticeRouteArgs routeArgs) {
    final normalized = routeArgs.normalized();
    return '${normalized.normalizedSpaceId}/${normalized.normalizedActivityId}';
  }

  void _scheduleStartMoment() {
    final normalized = widget.routeArgs.normalized();
    final scopeKey = _routeScopeKey(widget.routeArgs);
    if (_requestedMomentKey == scopeKey && _completedMomentKey == scopeKey) {
      return;
    }
    _requestedMomentKey = scopeKey;
    _completedMomentKey = null;
    final generation = ++_startGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _requestedMomentKey != scopeKey ||
          generation != _startGeneration) {
        return;
      }
      final future = ref
          .read(carePathNotifierProvider)
          .startMoment(
            spaceId: normalized.normalizedSpaceId,
            activityId: normalized.normalizedActivityId,
          );
      unawaited(
        future.whenComplete(() {
          if (!mounted ||
              _requestedMomentKey != scopeKey ||
              generation != _startGeneration) {
            return;
          }
          setState(() {
            _completedMomentKey = scopeKey;
          });
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(carePathNotifierProvider);
    final snapshot = notifier.snapshot;
    final normalizedArgs = widget.routeArgs.normalized();
    final scopeKey = _routeScopeKey(widget.routeArgs);
    final hasMatchingSnapshot =
        snapshot?.moment.spaceId == normalizedArgs.normalizedSpaceId &&
        snapshot?.moment.activityId == normalizedArgs.normalizedActivityId;

    if (!hasMatchingSnapshot ||
        _completedMomentKey != scopeKey ||
        notifier.phase == CareTurnPhase.idle ||
        notifier.phase == CareTurnPhase.loading) {
      return const _PracticeLoadingScaffold();
    }

    return CareTurnSurface(
      notifier: notifier,
      audioControllerFactory: widget.audioControllerFactory,
      onQuietExit: () => Navigator.of(context).maybePop(),
    );
  }
}

class PracticeFallbackScaffold extends StatelessWidget {
  const PracticeFallbackScaffold({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(l.practiceUnavailable),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _PracticeFallback(message: message),
        ),
      ),
    );
  }
}

class _PracticeFallback extends StatelessWidget {
  const _PracticeFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('practice-safe-fallback'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.errorSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.practiceBackHome),
          ),
        ],
      ),
    );
  }
}

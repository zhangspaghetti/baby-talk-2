import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/custom_scene_recovery_coordinator.dart';
import 'package:mobile/app/providers/repository_providers.dart';

/// Coordinates work that must wait for a stable persisted account identity.
class AccountReadinessBootstrap extends ConsumerWidget {
  const AccountReadinessBootstrap({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountNotifierProvider);
    final accountContext = account.stableAccountContext;
    final shouldResetProjection =
        account.isSignedOut || account.isRevoked || account.isDeleted;

    return _AccountScopedGeneratedProjectionBootstrap(
      accountContext: accountContext,
      scopedAccountContext: account.scopedAccountContext,
      shouldReset: shouldResetProjection,
      child: _CustomSceneRecoveryBootstrap(
        accountContext: accountContext,
        child: child,
      ),
    );
  }
}

class _CustomSceneRecoveryBootstrap extends ConsumerWidget {
  const _CustomSceneRecoveryBootstrap({
    required this.accountContext,
    this.child,
  });

  final String? accountContext;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = ref.watch(customSceneRecoveryCoordinatorProvider);
    final continuity = ref.watch(practiceContinuityNotifierProvider);
    final coordinator = recovery is AsyncData<CustomSceneRecoveryCoordinator>
        ? recovery.value
        : null;
    if (coordinator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          coordinator.recoverForAuthenticatedAccount(
            accountContext: accountContext,
            resumableGeneratedContentId:
                continuity.generatedRecommendedArgs?.generatedContentId,
          ),
        );
      });
    }
    return child ?? const SizedBox.shrink();
  }
}

/// Reprojects durable generated activity once the persisted account identity
/// becomes stable. Boot-time account unavailability is not a valid empty
/// projection, so both consumers retry from this shared lifecycle edge.
class _AccountScopedGeneratedProjectionBootstrap
    extends ConsumerStatefulWidget {
  const _AccountScopedGeneratedProjectionBootstrap({
    required this.accountContext,
    required this.scopedAccountContext,
    required this.shouldReset,
    this.child,
  });

  final String? accountContext;
  final String? scopedAccountContext;
  final bool shouldReset;
  final Widget? child;

  @override
  ConsumerState<_AccountScopedGeneratedProjectionBootstrap> createState() =>
      _AccountScopedGeneratedProjectionBootstrapState();
}

class _AccountScopedGeneratedProjectionBootstrapState
    extends ConsumerState<_AccountScopedGeneratedProjectionBootstrap> {
  String? _scheduledAccountContext;
  String? _refreshedAccountContext;
  String? _boundAccountContext;

  @override
  Widget build(BuildContext context) {
    _bindProjectionAccountContext(widget.scopedAccountContext);
    final accountContext = widget.accountContext;
    if (accountContext == null) {
      if (widget.shouldReset) {
        _scheduledAccountContext = null;
        _refreshedAccountContext = null;
      }
    } else if (_scheduledAccountContext != accountContext &&
        _refreshedAccountContext != accountContext) {
      _scheduledAccountContext = accountContext;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshForStableAccount(accountContext);
      });
    }
    return widget.child ?? const SizedBox.shrink();
  }

  void _refreshForStableAccount(String expectedAccountContext) {
    if (!mounted || _scheduledAccountContext != expectedAccountContext) {
      return;
    }
    final account = ref.read(accountNotifierProvider);
    if (account.stableAccountContext != expectedAccountContext) {
      _scheduledAccountContext = null;
      return;
    }
    _scheduledAccountContext = null;
    _refreshedAccountContext = expectedAccountContext;
    unawaited(
      Future.wait<void>(<Future<void>>[
        ref
            .read(practiceContinuityNotifierProvider)
            .refresh(reason: 'account_projection_ready'),
        ref.read(gardenGrowthNotifierProvider).refreshForAccountProjection(),
      ]),
    );
  }

  void _bindProjectionAccountContext(String? accountContext) {
    if (_boundAccountContext == accountContext) {
      return;
    }
    _boundAccountContext = accountContext;
    ref
        .read(practiceContinuityNotifierProvider)
        .bindAccountContext(accountContext, notify: false);
    ref
        .read(gardenGrowthNotifierProvider)
        .bindAccountContext(accountContext, notify: false);
  }
}

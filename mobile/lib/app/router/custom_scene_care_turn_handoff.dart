import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/router/root_navigator_key.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

/// App-layer handoff; custom_scene owns no Care Turn widget or repository.
class AppCustomSceneCareTurnHandoffSink
    implements CustomSceneCareTurnHandoffSink {
  const AppCustomSceneCareTurnHandoffSink();

  @override
  Future<void> handoff(CustomSceneCareTurnHandoff handoff) {
    final context = appRootNavigatorKey.currentContext;
    if (context == null) {
      throw StateError('Care Turn navigator is unavailable.');
    }
    unawaited(
      GoRouter.of(context).push<void>(
        AppRouteNames.practice,
        extra: GeneratedCareTurnRouteArgs(
          generatedContentId: handoff.generatedContentId,
        ),
      ),
    );
    // `push` completes only after destination exit. Starting navigation is
    // deliberately not a durable-handoff acknowledgement.
    return Future<void>.value();
  }
}

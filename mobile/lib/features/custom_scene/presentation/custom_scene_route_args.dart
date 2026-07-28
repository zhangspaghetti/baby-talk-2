import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';

class CustomSceneRouteArgs {
  const CustomSceneRouteArgs({required this.entrySource});

  final CustomSceneEntrySource entrySource;

  static CustomSceneRouteArgs? maybeFromObject(Object? value) {
    return value is CustomSceneRouteArgs ? value : null;
  }

  Future<T?> push<T>(BuildContext context) {
    return GoRouter.of(context).push<T>(AppRouteNames.customScene, extra: this);
  }
}

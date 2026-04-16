import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';

class PracticeRouteArgs {
  const PracticeRouteArgs({required this.spaceId, required this.activityId});

  final String spaceId;
  final String activityId;

  String get normalizedSpaceId => spaceId.trim();
  String get normalizedActivityId => activityId.trim();
  String get scopeLabel => '$normalizedSpaceId/$normalizedActivityId';

  bool get isValid =>
      normalizedSpaceId.isNotEmpty && normalizedActivityId.isNotEmpty;

  PracticeRouteArgs normalized() {
    return PracticeRouteArgs(
      spaceId: normalizedSpaceId,
      activityId: normalizedActivityId,
    );
  }

  static PracticeRouteArgs? maybeCreate({
    required String? spaceId,
    required String? activityId,
  }) {
    final resolvedSpaceId = (spaceId ?? '').trim();
    final resolvedActivityId = (activityId ?? '').trim();
    if (resolvedSpaceId.isEmpty || resolvedActivityId.isEmpty) {
      return null;
    }
    return PracticeRouteArgs(
      spaceId: resolvedSpaceId,
      activityId: resolvedActivityId,
    );
  }

  static PracticeRouteArgs? maybeFromObject(Object? raw) {
    if (raw is PracticeRouteArgs) {
      return raw.isValid ? raw.normalized() : null;
    }
    return null;
  }

  Future<T?> push<T>(BuildContext context) {
    return Navigator.of(
      context,
    ).pushNamed<T>(AppRouteNames.practice, arguments: normalized());
  }
}

class PracticeRouteEntry {
  const PracticeRouteEntry._({this.args, this.errorMessage});

  final PracticeRouteArgs? args;
  final String? errorMessage;

  bool get hasValidArgs => args != null && errorMessage == null;

  static PracticeRouteEntry fromObject(Object? raw) {
    final resolvedArgs = PracticeRouteArgs.maybeFromObject(raw);
    if (resolvedArgs != null) {
      return PracticeRouteEntry._(args: resolvedArgs);
    }

    return const PracticeRouteEntry._(
      errorMessage: '缺少或损坏 practice route 参数；请从首页、发现或花园重新进入。',
    );
  }
}

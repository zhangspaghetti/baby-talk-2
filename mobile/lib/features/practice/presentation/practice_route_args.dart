import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';

enum PracticeRouteEntrySource { inApp, shareReentry, inviteReentry }

class PracticeRouteArgs {
  const PracticeRouteArgs({
    required this.spaceId,
    required this.activityId,
    this.shareToken,
    this.entrySource = PracticeRouteEntrySource.inApp,
  });

  final String spaceId;
  final String activityId;
  final String? shareToken;
  final PracticeRouteEntrySource entrySource;

  String get normalizedSpaceId => spaceId.trim();
  String get normalizedActivityId => activityId.trim();
  String? get normalizedShareToken => _trimToNull(shareToken);
  String? get reentryToken => normalizedShareToken;
  String get scopeLabel => '$normalizedSpaceId/$normalizedActivityId';

  bool get isValid =>
      normalizedSpaceId.isNotEmpty && normalizedActivityId.isNotEmpty;

  bool isSupportedBy(SeedContentBundle content) {
    for (final space in content.spaces) {
      if (space.id != normalizedSpaceId) {
        continue;
      }
      for (final activity in space.activities) {
        if (activity.id == normalizedActivityId) {
          return true;
        }
      }
    }
    return false;
  }

  PracticeRouteArgs normalized() {
    return PracticeRouteArgs(
      spaceId: normalizedSpaceId,
      activityId: normalizedActivityId,
      shareToken: normalizedShareToken,
      entrySource: entrySource,
    );
  }

  static PracticeRouteArgs? maybeCreate({
    required String? spaceId,
    required String? activityId,
    String? shareToken,
    PracticeRouteEntrySource entrySource = PracticeRouteEntrySource.inApp,
  }) {
    final resolvedSpaceId = (spaceId ?? '').trim();
    final resolvedActivityId = (activityId ?? '').trim();
    if (resolvedSpaceId.isEmpty || resolvedActivityId.isEmpty) {
      return null;
    }
    return PracticeRouteArgs(
      spaceId: resolvedSpaceId,
      activityId: resolvedActivityId,
      shareToken: _trimToNull(shareToken),
      entrySource: entrySource,
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

  static String? _trimToNull(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
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

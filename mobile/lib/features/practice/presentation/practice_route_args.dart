import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';

enum PracticeRouteEntrySource { inApp, shareReentry, inviteReentry }

abstract interface class PracticeRouteTarget {
  String get scopeLabel;

  Future<T?> push<T>(BuildContext context);
}

class PracticeRouteArgs implements PracticeRouteTarget {
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
  @override
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

  @override
  Future<T?> push<T>(BuildContext context) {
    return GoRouter.of(
      context,
    ).push<T>(AppRouteNames.practice, extra: normalized());
  }

  static String? _trimToNull(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}

/// The generated Care Turn route carries only durable approved-content
/// identity. The formal Practice resolver supplies all display content.
class GeneratedCareTurnRouteArgs implements PracticeRouteTarget {
  GeneratedCareTurnRouteArgs({required String generatedContentId})
    : generatedContentId = _required(generatedContentId);

  final String generatedContentId;

  @override
  String get scopeLabel => 'generated:$generatedContentId';

  static GeneratedCareTurnRouteArgs? maybeFromObject(Object? raw) {
    return raw is GeneratedCareTurnRouteArgs ? raw : null;
  }

  @override
  Future<T?> push<T>(BuildContext context) {
    return GoRouter.of(context).push<T>(AppRouteNames.practice, extra: this);
  }

  static String _required(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'generatedContentId', '不能为空。');
    }
    return normalized;
  }
}

class PracticeRouteEntry {
  const PracticeRouteEntry._({
    this.args,
    this.generatedArgs,
    this.errorMessage,
  });

  final PracticeRouteArgs? args;
  final GeneratedCareTurnRouteArgs? generatedArgs;
  final String? errorMessage;

  bool get hasValidArgs =>
      (args != null || generatedArgs != null) && errorMessage == null;

  bool get isGeneratedCareTurn => generatedArgs != null;

  static PracticeRouteEntry fromObject(Object? raw) {
    final resolvedArgs = PracticeRouteArgs.maybeFromObject(raw);
    if (resolvedArgs != null) {
      return PracticeRouteEntry._(args: resolvedArgs);
    }

    final generatedArgs = GeneratedCareTurnRouteArgs.maybeFromObject(raw);
    if (generatedArgs != null) {
      return PracticeRouteEntry._(generatedArgs: generatedArgs);
    }

    return const PracticeRouteEntry._(
      errorMessage: '练习入口暂时打不开，请从首页、发现或花园重新进入。',
    );
  }
}

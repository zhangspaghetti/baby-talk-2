// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../../features/practice/domain/models/practice_continuity_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$PracticeContinuityRecommendation {
  String get spaceId => throw _privateConstructorUsedError;
  String get activityId => throw _privateConstructorUsedError;
  String get activityTitle => throw _privateConstructorUsedError;
  PracticeContinuityReason get reason => throw _privateConstructorUsedError;
  String get reasonLabel => throw _privateConstructorUsedError;
  String? get fallbackReason => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PracticeContinuityRecommendationCopyWith<PracticeContinuityRecommendation>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PracticeContinuityRecommendationCopyWith<$Res> {
  factory $PracticeContinuityRecommendationCopyWith(
    PracticeContinuityRecommendation value,
    $Res Function(PracticeContinuityRecommendation) then,
  ) =
      _$PracticeContinuityRecommendationCopyWithImpl<
        $Res,
        PracticeContinuityRecommendation
      >;
  @useResult
  $Res call({
    String spaceId,
    String activityId,
    String activityTitle,
    PracticeContinuityReason reason,
    String reasonLabel,
    String? fallbackReason,
  });
}

/// @nodoc
class _$PracticeContinuityRecommendationCopyWithImpl<
  $Res,
  $Val extends PracticeContinuityRecommendation
>
    implements $PracticeContinuityRecommendationCopyWith<$Res> {
  _$PracticeContinuityRecommendationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? activityId = null,
    Object? activityTitle = null,
    Object? reason = null,
    Object? reasonLabel = null,
    Object? fallbackReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            spaceId: null == spaceId
                ? _value.spaceId
                : spaceId // ignore: cast_nullable_to_non_nullable
                      as String,
            activityId: null == activityId
                ? _value.activityId
                : activityId // ignore: cast_nullable_to_non_nullable
                      as String,
            activityTitle: null == activityTitle
                ? _value.activityTitle
                : activityTitle // ignore: cast_nullable_to_non_nullable
                      as String,
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as PracticeContinuityReason,
            reasonLabel: null == reasonLabel
                ? _value.reasonLabel
                : reasonLabel // ignore: cast_nullable_to_non_nullable
                      as String,
            fallbackReason: freezed == fallbackReason
                ? _value.fallbackReason
                : fallbackReason // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PracticeContinuityRecommendationImplCopyWith<$Res>
    implements $PracticeContinuityRecommendationCopyWith<$Res> {
  factory _$$PracticeContinuityRecommendationImplCopyWith(
    _$PracticeContinuityRecommendationImpl value,
    $Res Function(_$PracticeContinuityRecommendationImpl) then,
  ) = __$$PracticeContinuityRecommendationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String spaceId,
    String activityId,
    String activityTitle,
    PracticeContinuityReason reason,
    String reasonLabel,
    String? fallbackReason,
  });
}

/// @nodoc
class __$$PracticeContinuityRecommendationImplCopyWithImpl<$Res>
    extends
        _$PracticeContinuityRecommendationCopyWithImpl<
          $Res,
          _$PracticeContinuityRecommendationImpl
        >
    implements _$$PracticeContinuityRecommendationImplCopyWith<$Res> {
  __$$PracticeContinuityRecommendationImplCopyWithImpl(
    _$PracticeContinuityRecommendationImpl _value,
    $Res Function(_$PracticeContinuityRecommendationImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? activityId = null,
    Object? activityTitle = null,
    Object? reason = null,
    Object? reasonLabel = null,
    Object? fallbackReason = freezed,
  }) {
    return _then(
      _$PracticeContinuityRecommendationImpl(
        spaceId: null == spaceId
            ? _value.spaceId
            : spaceId // ignore: cast_nullable_to_non_nullable
                  as String,
        activityId: null == activityId
            ? _value.activityId
            : activityId // ignore: cast_nullable_to_non_nullable
                  as String,
        activityTitle: null == activityTitle
            ? _value.activityTitle
            : activityTitle // ignore: cast_nullable_to_non_nullable
                  as String,
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as PracticeContinuityReason,
        reasonLabel: null == reasonLabel
            ? _value.reasonLabel
            : reasonLabel // ignore: cast_nullable_to_non_nullable
                  as String,
        fallbackReason: freezed == fallbackReason
            ? _value.fallbackReason
            : fallbackReason // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$PracticeContinuityRecommendationImpl
    implements _PracticeContinuityRecommendation {
  const _$PracticeContinuityRecommendationImpl({
    required this.spaceId,
    required this.activityId,
    required this.activityTitle,
    required this.reason,
    required this.reasonLabel,
    this.fallbackReason,
  });

  @override
  final String spaceId;
  @override
  final String activityId;
  @override
  final String activityTitle;
  @override
  final PracticeContinuityReason reason;
  @override
  final String reasonLabel;
  @override
  final String? fallbackReason;

  @override
  String toString() {
    return 'PracticeContinuityRecommendation(spaceId: $spaceId, activityId: $activityId, activityTitle: $activityTitle, reason: $reason, reasonLabel: $reasonLabel, fallbackReason: $fallbackReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PracticeContinuityRecommendationImpl &&
            (identical(other.spaceId, spaceId) || other.spaceId == spaceId) &&
            (identical(other.activityId, activityId) ||
                other.activityId == activityId) &&
            (identical(other.activityTitle, activityTitle) ||
                other.activityTitle == activityTitle) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.reasonLabel, reasonLabel) ||
                other.reasonLabel == reasonLabel) &&
            (identical(other.fallbackReason, fallbackReason) ||
                other.fallbackReason == fallbackReason));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    spaceId,
    activityId,
    activityTitle,
    reason,
    reasonLabel,
    fallbackReason,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PracticeContinuityRecommendationImplCopyWith<
    _$PracticeContinuityRecommendationImpl
  >
  get copyWith =>
      __$$PracticeContinuityRecommendationImplCopyWithImpl<
        _$PracticeContinuityRecommendationImpl
      >(this, _$identity);
}

abstract class _PracticeContinuityRecommendation
    implements PracticeContinuityRecommendation {
  const factory _PracticeContinuityRecommendation({
    required final String spaceId,
    required final String activityId,
    required final String activityTitle,
    required final PracticeContinuityReason reason,
    required final String reasonLabel,
    final String? fallbackReason,
  }) = _$PracticeContinuityRecommendationImpl;

  @override
  String get spaceId;
  @override
  String get activityId;
  @override
  String get activityTitle;
  @override
  PracticeContinuityReason get reason;
  @override
  String get reasonLabel;
  @override
  String? get fallbackReason;
  @override
  @JsonKey(ignore: true)
  _$$PracticeContinuityRecommendationImplCopyWith<
    _$PracticeContinuityRecommendationImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PracticeContinuityCadenceSummary {
  int get totalKnownEvents => throw _privateConstructorUsedError;
  int get startedActivityCount => throw _privateConstructorUsedError;
  DateTime? get lastEventTime => throw _privateConstructorUsedError;
  String get headline => throw _privateConstructorUsedError;
  String get detail => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PracticeContinuityCadenceSummaryCopyWith<PracticeContinuityCadenceSummary>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PracticeContinuityCadenceSummaryCopyWith<$Res> {
  factory $PracticeContinuityCadenceSummaryCopyWith(
    PracticeContinuityCadenceSummary value,
    $Res Function(PracticeContinuityCadenceSummary) then,
  ) =
      _$PracticeContinuityCadenceSummaryCopyWithImpl<
        $Res,
        PracticeContinuityCadenceSummary
      >;
  @useResult
  $Res call({
    int totalKnownEvents,
    int startedActivityCount,
    DateTime? lastEventTime,
    String headline,
    String detail,
  });
}

/// @nodoc
class _$PracticeContinuityCadenceSummaryCopyWithImpl<
  $Res,
  $Val extends PracticeContinuityCadenceSummary
>
    implements $PracticeContinuityCadenceSummaryCopyWith<$Res> {
  _$PracticeContinuityCadenceSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalKnownEvents = null,
    Object? startedActivityCount = null,
    Object? lastEventTime = freezed,
    Object? headline = null,
    Object? detail = null,
  }) {
    return _then(
      _value.copyWith(
            totalKnownEvents: null == totalKnownEvents
                ? _value.totalKnownEvents
                : totalKnownEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            startedActivityCount: null == startedActivityCount
                ? _value.startedActivityCount
                : startedActivityCount // ignore: cast_nullable_to_non_nullable
                      as int,
            lastEventTime: freezed == lastEventTime
                ? _value.lastEventTime
                : lastEventTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            headline: null == headline
                ? _value.headline
                : headline // ignore: cast_nullable_to_non_nullable
                      as String,
            detail: null == detail
                ? _value.detail
                : detail // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PracticeContinuityCadenceSummaryImplCopyWith<$Res>
    implements $PracticeContinuityCadenceSummaryCopyWith<$Res> {
  factory _$$PracticeContinuityCadenceSummaryImplCopyWith(
    _$PracticeContinuityCadenceSummaryImpl value,
    $Res Function(_$PracticeContinuityCadenceSummaryImpl) then,
  ) = __$$PracticeContinuityCadenceSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int totalKnownEvents,
    int startedActivityCount,
    DateTime? lastEventTime,
    String headline,
    String detail,
  });
}

/// @nodoc
class __$$PracticeContinuityCadenceSummaryImplCopyWithImpl<$Res>
    extends
        _$PracticeContinuityCadenceSummaryCopyWithImpl<
          $Res,
          _$PracticeContinuityCadenceSummaryImpl
        >
    implements _$$PracticeContinuityCadenceSummaryImplCopyWith<$Res> {
  __$$PracticeContinuityCadenceSummaryImplCopyWithImpl(
    _$PracticeContinuityCadenceSummaryImpl _value,
    $Res Function(_$PracticeContinuityCadenceSummaryImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalKnownEvents = null,
    Object? startedActivityCount = null,
    Object? lastEventTime = freezed,
    Object? headline = null,
    Object? detail = null,
  }) {
    return _then(
      _$PracticeContinuityCadenceSummaryImpl(
        totalKnownEvents: null == totalKnownEvents
            ? _value.totalKnownEvents
            : totalKnownEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        startedActivityCount: null == startedActivityCount
            ? _value.startedActivityCount
            : startedActivityCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastEventTime: freezed == lastEventTime
            ? _value.lastEventTime
            : lastEventTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        headline: null == headline
            ? _value.headline
            : headline // ignore: cast_nullable_to_non_nullable
                  as String,
        detail: null == detail
            ? _value.detail
            : detail // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$PracticeContinuityCadenceSummaryImpl
    extends _PracticeContinuityCadenceSummary {
  const _$PracticeContinuityCadenceSummaryImpl({
    required this.totalKnownEvents,
    required this.startedActivityCount,
    required this.lastEventTime,
    required this.headline,
    required this.detail,
  }) : super._();

  @override
  final int totalKnownEvents;
  @override
  final int startedActivityCount;
  @override
  final DateTime? lastEventTime;
  @override
  final String headline;
  @override
  final String detail;

  @override
  String toString() {
    return 'PracticeContinuityCadenceSummary(totalKnownEvents: $totalKnownEvents, startedActivityCount: $startedActivityCount, lastEventTime: $lastEventTime, headline: $headline, detail: $detail)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PracticeContinuityCadenceSummaryImpl &&
            (identical(other.totalKnownEvents, totalKnownEvents) ||
                other.totalKnownEvents == totalKnownEvents) &&
            (identical(other.startedActivityCount, startedActivityCount) ||
                other.startedActivityCount == startedActivityCount) &&
            (identical(other.lastEventTime, lastEventTime) ||
                other.lastEventTime == lastEventTime) &&
            (identical(other.headline, headline) ||
                other.headline == headline) &&
            (identical(other.detail, detail) || other.detail == detail));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalKnownEvents,
    startedActivityCount,
    lastEventTime,
    headline,
    detail,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PracticeContinuityCadenceSummaryImplCopyWith<
    _$PracticeContinuityCadenceSummaryImpl
  >
  get copyWith =>
      __$$PracticeContinuityCadenceSummaryImplCopyWithImpl<
        _$PracticeContinuityCadenceSummaryImpl
      >(this, _$identity);
}

abstract class _PracticeContinuityCadenceSummary
    extends PracticeContinuityCadenceSummary {
  const factory _PracticeContinuityCadenceSummary({
    required final int totalKnownEvents,
    required final int startedActivityCount,
    required final DateTime? lastEventTime,
    required final String headline,
    required final String detail,
  }) = _$PracticeContinuityCadenceSummaryImpl;
  const _PracticeContinuityCadenceSummary._() : super._();

  @override
  int get totalKnownEvents;
  @override
  int get startedActivityCount;
  @override
  DateTime? get lastEventTime;
  @override
  String get headline;
  @override
  String get detail;
  @override
  @JsonKey(ignore: true)
  _$$PracticeContinuityCadenceSummaryImplCopyWith<
    _$PracticeContinuityCadenceSummaryImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PracticeContinuitySnapshot {
  PracticeActivityCatalog get catalog => throw _privateConstructorUsedError;
  PracticeCatalogActivitySummary get recommendedActivity =>
      throw _privateConstructorUsedError;
  PracticeCatalogActivitySummary? get recentActivity =>
      throw _privateConstructorUsedError;
  PracticeCatalogActivitySummary? get nextIncompleteActivity =>
      throw _privateConstructorUsedError;
  PracticeCatalogActivitySummary? get starterActivity =>
      throw _privateConstructorUsedError;
  PracticeContinuityRecommendation get recommendation =>
      throw _privateConstructorUsedError;
  PracticeContinuityCadenceSummary get cadence =>
      throw _privateConstructorUsedError;
  String? get warningMessage => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PracticeContinuitySnapshotCopyWith<PracticeContinuitySnapshot>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PracticeContinuitySnapshotCopyWith<$Res> {
  factory $PracticeContinuitySnapshotCopyWith(
    PracticeContinuitySnapshot value,
    $Res Function(PracticeContinuitySnapshot) then,
  ) =
      _$PracticeContinuitySnapshotCopyWithImpl<
        $Res,
        PracticeContinuitySnapshot
      >;
  @useResult
  $Res call({
    PracticeActivityCatalog catalog,
    PracticeCatalogActivitySummary recommendedActivity,
    PracticeCatalogActivitySummary? recentActivity,
    PracticeCatalogActivitySummary? nextIncompleteActivity,
    PracticeCatalogActivitySummary? starterActivity,
    PracticeContinuityRecommendation recommendation,
    PracticeContinuityCadenceSummary cadence,
    String? warningMessage,
  });

  $PracticeActivityCatalogCopyWith<$Res> get catalog;
  $PracticeCatalogActivitySummaryCopyWith<$Res> get recommendedActivity;
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get recentActivity;
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get nextIncompleteActivity;
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get starterActivity;
  $PracticeContinuityRecommendationCopyWith<$Res> get recommendation;
  $PracticeContinuityCadenceSummaryCopyWith<$Res> get cadence;
}

/// @nodoc
class _$PracticeContinuitySnapshotCopyWithImpl<
  $Res,
  $Val extends PracticeContinuitySnapshot
>
    implements $PracticeContinuitySnapshotCopyWith<$Res> {
  _$PracticeContinuitySnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? catalog = null,
    Object? recommendedActivity = null,
    Object? recentActivity = freezed,
    Object? nextIncompleteActivity = freezed,
    Object? starterActivity = freezed,
    Object? recommendation = null,
    Object? cadence = null,
    Object? warningMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            catalog: null == catalog
                ? _value.catalog
                : catalog // ignore: cast_nullable_to_non_nullable
                      as PracticeActivityCatalog,
            recommendedActivity: null == recommendedActivity
                ? _value.recommendedActivity
                : recommendedActivity // ignore: cast_nullable_to_non_nullable
                      as PracticeCatalogActivitySummary,
            recentActivity: freezed == recentActivity
                ? _value.recentActivity
                : recentActivity // ignore: cast_nullable_to_non_nullable
                      as PracticeCatalogActivitySummary?,
            nextIncompleteActivity: freezed == nextIncompleteActivity
                ? _value.nextIncompleteActivity
                : nextIncompleteActivity // ignore: cast_nullable_to_non_nullable
                      as PracticeCatalogActivitySummary?,
            starterActivity: freezed == starterActivity
                ? _value.starterActivity
                : starterActivity // ignore: cast_nullable_to_non_nullable
                      as PracticeCatalogActivitySummary?,
            recommendation: null == recommendation
                ? _value.recommendation
                : recommendation // ignore: cast_nullable_to_non_nullable
                      as PracticeContinuityRecommendation,
            cadence: null == cadence
                ? _value.cadence
                : cadence // ignore: cast_nullable_to_non_nullable
                      as PracticeContinuityCadenceSummary,
            warningMessage: freezed == warningMessage
                ? _value.warningMessage
                : warningMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $PracticeActivityCatalogCopyWith<$Res> get catalog {
    return $PracticeActivityCatalogCopyWith<$Res>(_value.catalog, (value) {
      return _then(_value.copyWith(catalog: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $PracticeCatalogActivitySummaryCopyWith<$Res> get recommendedActivity {
    return $PracticeCatalogActivitySummaryCopyWith<$Res>(
      _value.recommendedActivity,
      (value) {
        return _then(_value.copyWith(recommendedActivity: value) as $Val);
      },
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get recentActivity {
    if (_value.recentActivity == null) {
      return null;
    }

    return $PracticeCatalogActivitySummaryCopyWith<$Res>(
      _value.recentActivity!,
      (value) {
        return _then(_value.copyWith(recentActivity: value) as $Val);
      },
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get nextIncompleteActivity {
    if (_value.nextIncompleteActivity == null) {
      return null;
    }

    return $PracticeCatalogActivitySummaryCopyWith<$Res>(
      _value.nextIncompleteActivity!,
      (value) {
        return _then(_value.copyWith(nextIncompleteActivity: value) as $Val);
      },
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get starterActivity {
    if (_value.starterActivity == null) {
      return null;
    }

    return $PracticeCatalogActivitySummaryCopyWith<$Res>(
      _value.starterActivity!,
      (value) {
        return _then(_value.copyWith(starterActivity: value) as $Val);
      },
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $PracticeContinuityRecommendationCopyWith<$Res> get recommendation {
    return $PracticeContinuityRecommendationCopyWith<$Res>(
      _value.recommendation,
      (value) {
        return _then(_value.copyWith(recommendation: value) as $Val);
      },
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $PracticeContinuityCadenceSummaryCopyWith<$Res> get cadence {
    return $PracticeContinuityCadenceSummaryCopyWith<$Res>(_value.cadence, (
      value,
    ) {
      return _then(_value.copyWith(cadence: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PracticeContinuitySnapshotImplCopyWith<$Res>
    implements $PracticeContinuitySnapshotCopyWith<$Res> {
  factory _$$PracticeContinuitySnapshotImplCopyWith(
    _$PracticeContinuitySnapshotImpl value,
    $Res Function(_$PracticeContinuitySnapshotImpl) then,
  ) = __$$PracticeContinuitySnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    PracticeActivityCatalog catalog,
    PracticeCatalogActivitySummary recommendedActivity,
    PracticeCatalogActivitySummary? recentActivity,
    PracticeCatalogActivitySummary? nextIncompleteActivity,
    PracticeCatalogActivitySummary? starterActivity,
    PracticeContinuityRecommendation recommendation,
    PracticeContinuityCadenceSummary cadence,
    String? warningMessage,
  });

  @override
  $PracticeActivityCatalogCopyWith<$Res> get catalog;
  @override
  $PracticeCatalogActivitySummaryCopyWith<$Res> get recommendedActivity;
  @override
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get recentActivity;
  @override
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get nextIncompleteActivity;
  @override
  $PracticeCatalogActivitySummaryCopyWith<$Res>? get starterActivity;
  @override
  $PracticeContinuityRecommendationCopyWith<$Res> get recommendation;
  @override
  $PracticeContinuityCadenceSummaryCopyWith<$Res> get cadence;
}

/// @nodoc
class __$$PracticeContinuitySnapshotImplCopyWithImpl<$Res>
    extends
        _$PracticeContinuitySnapshotCopyWithImpl<
          $Res,
          _$PracticeContinuitySnapshotImpl
        >
    implements _$$PracticeContinuitySnapshotImplCopyWith<$Res> {
  __$$PracticeContinuitySnapshotImplCopyWithImpl(
    _$PracticeContinuitySnapshotImpl _value,
    $Res Function(_$PracticeContinuitySnapshotImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? catalog = null,
    Object? recommendedActivity = null,
    Object? recentActivity = freezed,
    Object? nextIncompleteActivity = freezed,
    Object? starterActivity = freezed,
    Object? recommendation = null,
    Object? cadence = null,
    Object? warningMessage = freezed,
  }) {
    return _then(
      _$PracticeContinuitySnapshotImpl(
        catalog: null == catalog
            ? _value.catalog
            : catalog // ignore: cast_nullable_to_non_nullable
                  as PracticeActivityCatalog,
        recommendedActivity: null == recommendedActivity
            ? _value.recommendedActivity
            : recommendedActivity // ignore: cast_nullable_to_non_nullable
                  as PracticeCatalogActivitySummary,
        recentActivity: freezed == recentActivity
            ? _value.recentActivity
            : recentActivity // ignore: cast_nullable_to_non_nullable
                  as PracticeCatalogActivitySummary?,
        nextIncompleteActivity: freezed == nextIncompleteActivity
            ? _value.nextIncompleteActivity
            : nextIncompleteActivity // ignore: cast_nullable_to_non_nullable
                  as PracticeCatalogActivitySummary?,
        starterActivity: freezed == starterActivity
            ? _value.starterActivity
            : starterActivity // ignore: cast_nullable_to_non_nullable
                  as PracticeCatalogActivitySummary?,
        recommendation: null == recommendation
            ? _value.recommendation
            : recommendation // ignore: cast_nullable_to_non_nullable
                  as PracticeContinuityRecommendation,
        cadence: null == cadence
            ? _value.cadence
            : cadence // ignore: cast_nullable_to_non_nullable
                  as PracticeContinuityCadenceSummary,
        warningMessage: freezed == warningMessage
            ? _value.warningMessage
            : warningMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$PracticeContinuitySnapshotImpl extends _PracticeContinuitySnapshot {
  const _$PracticeContinuitySnapshotImpl({
    required this.catalog,
    required this.recommendedActivity,
    required this.recentActivity,
    required this.nextIncompleteActivity,
    required this.starterActivity,
    required this.recommendation,
    required this.cadence,
    this.warningMessage,
  }) : super._();

  @override
  final PracticeActivityCatalog catalog;
  @override
  final PracticeCatalogActivitySummary recommendedActivity;
  @override
  final PracticeCatalogActivitySummary? recentActivity;
  @override
  final PracticeCatalogActivitySummary? nextIncompleteActivity;
  @override
  final PracticeCatalogActivitySummary? starterActivity;
  @override
  final PracticeContinuityRecommendation recommendation;
  @override
  final PracticeContinuityCadenceSummary cadence;
  @override
  final String? warningMessage;

  @override
  String toString() {
    return 'PracticeContinuitySnapshot(catalog: $catalog, recommendedActivity: $recommendedActivity, recentActivity: $recentActivity, nextIncompleteActivity: $nextIncompleteActivity, starterActivity: $starterActivity, recommendation: $recommendation, cadence: $cadence, warningMessage: $warningMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PracticeContinuitySnapshotImpl &&
            (identical(other.catalog, catalog) || other.catalog == catalog) &&
            (identical(other.recommendedActivity, recommendedActivity) ||
                other.recommendedActivity == recommendedActivity) &&
            (identical(other.recentActivity, recentActivity) ||
                other.recentActivity == recentActivity) &&
            (identical(other.nextIncompleteActivity, nextIncompleteActivity) ||
                other.nextIncompleteActivity == nextIncompleteActivity) &&
            (identical(other.starterActivity, starterActivity) ||
                other.starterActivity == starterActivity) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            (identical(other.cadence, cadence) || other.cadence == cadence) &&
            (identical(other.warningMessage, warningMessage) ||
                other.warningMessage == warningMessage));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    catalog,
    recommendedActivity,
    recentActivity,
    nextIncompleteActivity,
    starterActivity,
    recommendation,
    cadence,
    warningMessage,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PracticeContinuitySnapshotImplCopyWith<_$PracticeContinuitySnapshotImpl>
  get copyWith =>
      __$$PracticeContinuitySnapshotImplCopyWithImpl<
        _$PracticeContinuitySnapshotImpl
      >(this, _$identity);
}

abstract class _PracticeContinuitySnapshot extends PracticeContinuitySnapshot {
  const factory _PracticeContinuitySnapshot({
    required final PracticeActivityCatalog catalog,
    required final PracticeCatalogActivitySummary recommendedActivity,
    required final PracticeCatalogActivitySummary? recentActivity,
    required final PracticeCatalogActivitySummary? nextIncompleteActivity,
    required final PracticeCatalogActivitySummary? starterActivity,
    required final PracticeContinuityRecommendation recommendation,
    required final PracticeContinuityCadenceSummary cadence,
    final String? warningMessage,
  }) = _$PracticeContinuitySnapshotImpl;
  const _PracticeContinuitySnapshot._() : super._();

  @override
  PracticeActivityCatalog get catalog;
  @override
  PracticeCatalogActivitySummary get recommendedActivity;
  @override
  PracticeCatalogActivitySummary? get recentActivity;
  @override
  PracticeCatalogActivitySummary? get nextIncompleteActivity;
  @override
  PracticeCatalogActivitySummary? get starterActivity;
  @override
  PracticeContinuityRecommendation get recommendation;
  @override
  PracticeContinuityCadenceSummary get cadence;
  @override
  String? get warningMessage;
  @override
  @JsonKey(ignore: true)
  _$$PracticeContinuitySnapshotImplCopyWith<_$PracticeContinuitySnapshotImpl>
  get copyWith => throw _privateConstructorUsedError;
}

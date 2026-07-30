// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../../features/practice/domain/models/practice_activity_catalog.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$PracticeCatalogRecentResultSummary {
  String get phraseId => throw _privateConstructorUsedError;
  String get phraseEnglish => throw _privateConstructorUsedError;
  BabyReactionType get reactionType => throw _privateConstructorUsedError;
  DateTime get eventTime => throw _privateConstructorUsedError;
  int get totalEvents => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PracticeCatalogRecentResultSummaryCopyWith<
    PracticeCatalogRecentResultSummary
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PracticeCatalogRecentResultSummaryCopyWith<$Res> {
  factory $PracticeCatalogRecentResultSummaryCopyWith(
    PracticeCatalogRecentResultSummary value,
    $Res Function(PracticeCatalogRecentResultSummary) then,
  ) =
      _$PracticeCatalogRecentResultSummaryCopyWithImpl<
        $Res,
        PracticeCatalogRecentResultSummary
      >;
  @useResult
  $Res call({
    String phraseId,
    String phraseEnglish,
    BabyReactionType reactionType,
    DateTime eventTime,
    int totalEvents,
  });
}

/// @nodoc
class _$PracticeCatalogRecentResultSummaryCopyWithImpl<
  $Res,
  $Val extends PracticeCatalogRecentResultSummary
>
    implements $PracticeCatalogRecentResultSummaryCopyWith<$Res> {
  _$PracticeCatalogRecentResultSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phraseId = null,
    Object? phraseEnglish = null,
    Object? reactionType = null,
    Object? eventTime = null,
    Object? totalEvents = null,
  }) {
    return _then(
      _value.copyWith(
            phraseId: null == phraseId
                ? _value.phraseId
                : phraseId // ignore: cast_nullable_to_non_nullable
                      as String,
            phraseEnglish: null == phraseEnglish
                ? _value.phraseEnglish
                : phraseEnglish // ignore: cast_nullable_to_non_nullable
                      as String,
            reactionType: null == reactionType
                ? _value.reactionType
                : reactionType // ignore: cast_nullable_to_non_nullable
                      as BabyReactionType,
            eventTime: null == eventTime
                ? _value.eventTime
                : eventTime // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalEvents: null == totalEvents
                ? _value.totalEvents
                : totalEvents // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PracticeCatalogRecentResultSummaryImplCopyWith<$Res>
    implements $PracticeCatalogRecentResultSummaryCopyWith<$Res> {
  factory _$$PracticeCatalogRecentResultSummaryImplCopyWith(
    _$PracticeCatalogRecentResultSummaryImpl value,
    $Res Function(_$PracticeCatalogRecentResultSummaryImpl) then,
  ) = __$$PracticeCatalogRecentResultSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String phraseId,
    String phraseEnglish,
    BabyReactionType reactionType,
    DateTime eventTime,
    int totalEvents,
  });
}

/// @nodoc
class __$$PracticeCatalogRecentResultSummaryImplCopyWithImpl<$Res>
    extends
        _$PracticeCatalogRecentResultSummaryCopyWithImpl<
          $Res,
          _$PracticeCatalogRecentResultSummaryImpl
        >
    implements _$$PracticeCatalogRecentResultSummaryImplCopyWith<$Res> {
  __$$PracticeCatalogRecentResultSummaryImplCopyWithImpl(
    _$PracticeCatalogRecentResultSummaryImpl _value,
    $Res Function(_$PracticeCatalogRecentResultSummaryImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phraseId = null,
    Object? phraseEnglish = null,
    Object? reactionType = null,
    Object? eventTime = null,
    Object? totalEvents = null,
  }) {
    return _then(
      _$PracticeCatalogRecentResultSummaryImpl(
        phraseId: null == phraseId
            ? _value.phraseId
            : phraseId // ignore: cast_nullable_to_non_nullable
                  as String,
        phraseEnglish: null == phraseEnglish
            ? _value.phraseEnglish
            : phraseEnglish // ignore: cast_nullable_to_non_nullable
                  as String,
        reactionType: null == reactionType
            ? _value.reactionType
            : reactionType // ignore: cast_nullable_to_non_nullable
                  as BabyReactionType,
        eventTime: null == eventTime
            ? _value.eventTime
            : eventTime // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalEvents: null == totalEvents
            ? _value.totalEvents
            : totalEvents // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$PracticeCatalogRecentResultSummaryImpl
    implements _PracticeCatalogRecentResultSummary {
  const _$PracticeCatalogRecentResultSummaryImpl({
    required this.phraseId,
    required this.phraseEnglish,
    required this.reactionType,
    required this.eventTime,
    required this.totalEvents,
  });

  @override
  final String phraseId;
  @override
  final String phraseEnglish;
  @override
  final BabyReactionType reactionType;
  @override
  final DateTime eventTime;
  @override
  final int totalEvents;

  @override
  String toString() {
    return 'PracticeCatalogRecentResultSummary(phraseId: $phraseId, phraseEnglish: $phraseEnglish, reactionType: $reactionType, eventTime: $eventTime, totalEvents: $totalEvents)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PracticeCatalogRecentResultSummaryImpl &&
            (identical(other.phraseId, phraseId) ||
                other.phraseId == phraseId) &&
            (identical(other.phraseEnglish, phraseEnglish) ||
                other.phraseEnglish == phraseEnglish) &&
            (identical(other.reactionType, reactionType) ||
                other.reactionType == reactionType) &&
            (identical(other.eventTime, eventTime) ||
                other.eventTime == eventTime) &&
            (identical(other.totalEvents, totalEvents) ||
                other.totalEvents == totalEvents));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    phraseId,
    phraseEnglish,
    reactionType,
    eventTime,
    totalEvents,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PracticeCatalogRecentResultSummaryImplCopyWith<
    _$PracticeCatalogRecentResultSummaryImpl
  >
  get copyWith =>
      __$$PracticeCatalogRecentResultSummaryImplCopyWithImpl<
        _$PracticeCatalogRecentResultSummaryImpl
      >(this, _$identity);
}

abstract class _PracticeCatalogRecentResultSummary
    implements PracticeCatalogRecentResultSummary {
  const factory _PracticeCatalogRecentResultSummary({
    required final String phraseId,
    required final String phraseEnglish,
    required final BabyReactionType reactionType,
    required final DateTime eventTime,
    required final int totalEvents,
  }) = _$PracticeCatalogRecentResultSummaryImpl;

  @override
  String get phraseId;
  @override
  String get phraseEnglish;
  @override
  BabyReactionType get reactionType;
  @override
  DateTime get eventTime;
  @override
  int get totalEvents;
  @override
  @JsonKey(ignore: true)
  _$$PracticeCatalogRecentResultSummaryImplCopyWith<
    _$PracticeCatalogRecentResultSummaryImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PracticeCatalogActivitySummary {
  String get spaceId => throw _privateConstructorUsedError;
  String get spaceTitle => throw _privateConstructorUsedError;
  String get activityId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  String get sceneTag => throw _privateConstructorUsedError;
  String get coachTip => throw _privateConstructorUsedError;
  int get totalPhraseCount => throw _privateConstructorUsedError;
  int get completedPhraseCount => throw _privateConstructorUsedError;
  List<String> get completedPhraseIds => throw _privateConstructorUsedError;
  String? get nextPhraseId => throw _privateConstructorUsedError;
  String? get nextPhraseEnglish => throw _privateConstructorUsedError;
  int get totalEvents => throw _privateConstructorUsedError;
  int get skippedUnknownPhraseCount => throw _privateConstructorUsedError;
  int get skippedMalformedEventCount => throw _privateConstructorUsedError;
  String? get generatedContentId => throw _privateConstructorUsedError;
  DateTime? get lastEventTime => throw _privateConstructorUsedError;
  PracticeCatalogRecentResultSummary? get recentResult =>
      throw _privateConstructorUsedError;
  String? get warningMessage => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PracticeCatalogActivitySummaryCopyWith<PracticeCatalogActivitySummary>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PracticeCatalogActivitySummaryCopyWith<$Res> {
  factory $PracticeCatalogActivitySummaryCopyWith(
    PracticeCatalogActivitySummary value,
    $Res Function(PracticeCatalogActivitySummary) then,
  ) =
      _$PracticeCatalogActivitySummaryCopyWithImpl<
        $Res,
        PracticeCatalogActivitySummary
      >;
  @useResult
  $Res call({
    String spaceId,
    String spaceTitle,
    String activityId,
    String title,
    String summary,
    String sceneTag,
    String coachTip,
    int totalPhraseCount,
    int completedPhraseCount,
    List<String> completedPhraseIds,
    String? nextPhraseId,
    String? nextPhraseEnglish,
    int totalEvents,
    int skippedUnknownPhraseCount,
    int skippedMalformedEventCount,
    String? generatedContentId,
    DateTime? lastEventTime,
    PracticeCatalogRecentResultSummary? recentResult,
    String? warningMessage,
  });

  $PracticeCatalogRecentResultSummaryCopyWith<$Res>? get recentResult;
}

/// @nodoc
class _$PracticeCatalogActivitySummaryCopyWithImpl<
  $Res,
  $Val extends PracticeCatalogActivitySummary
>
    implements $PracticeCatalogActivitySummaryCopyWith<$Res> {
  _$PracticeCatalogActivitySummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? spaceTitle = null,
    Object? activityId = null,
    Object? title = null,
    Object? summary = null,
    Object? sceneTag = null,
    Object? coachTip = null,
    Object? totalPhraseCount = null,
    Object? completedPhraseCount = null,
    Object? completedPhraseIds = null,
    Object? nextPhraseId = freezed,
    Object? nextPhraseEnglish = freezed,
    Object? totalEvents = null,
    Object? skippedUnknownPhraseCount = null,
    Object? skippedMalformedEventCount = null,
    Object? generatedContentId = freezed,
    Object? lastEventTime = freezed,
    Object? recentResult = freezed,
    Object? warningMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            spaceId: null == spaceId
                ? _value.spaceId
                : spaceId // ignore: cast_nullable_to_non_nullable
                      as String,
            spaceTitle: null == spaceTitle
                ? _value.spaceTitle
                : spaceTitle // ignore: cast_nullable_to_non_nullable
                      as String,
            activityId: null == activityId
                ? _value.activityId
                : activityId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            sceneTag: null == sceneTag
                ? _value.sceneTag
                : sceneTag // ignore: cast_nullable_to_non_nullable
                      as String,
            coachTip: null == coachTip
                ? _value.coachTip
                : coachTip // ignore: cast_nullable_to_non_nullable
                      as String,
            totalPhraseCount: null == totalPhraseCount
                ? _value.totalPhraseCount
                : totalPhraseCount // ignore: cast_nullable_to_non_nullable
                      as int,
            completedPhraseCount: null == completedPhraseCount
                ? _value.completedPhraseCount
                : completedPhraseCount // ignore: cast_nullable_to_non_nullable
                      as int,
            completedPhraseIds: null == completedPhraseIds
                ? _value.completedPhraseIds
                : completedPhraseIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            nextPhraseId: freezed == nextPhraseId
                ? _value.nextPhraseId
                : nextPhraseId // ignore: cast_nullable_to_non_nullable
                      as String?,
            nextPhraseEnglish: freezed == nextPhraseEnglish
                ? _value.nextPhraseEnglish
                : nextPhraseEnglish // ignore: cast_nullable_to_non_nullable
                      as String?,
            totalEvents: null == totalEvents
                ? _value.totalEvents
                : totalEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            skippedUnknownPhraseCount: null == skippedUnknownPhraseCount
                ? _value.skippedUnknownPhraseCount
                : skippedUnknownPhraseCount // ignore: cast_nullable_to_non_nullable
                      as int,
            skippedMalformedEventCount: null == skippedMalformedEventCount
                ? _value.skippedMalformedEventCount
                : skippedMalformedEventCount // ignore: cast_nullable_to_non_nullable
                      as int,
            generatedContentId: freezed == generatedContentId
                ? _value.generatedContentId
                : generatedContentId // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastEventTime: freezed == lastEventTime
                ? _value.lastEventTime
                : lastEventTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            recentResult: freezed == recentResult
                ? _value.recentResult
                : recentResult // ignore: cast_nullable_to_non_nullable
                      as PracticeCatalogRecentResultSummary?,
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
  $PracticeCatalogRecentResultSummaryCopyWith<$Res>? get recentResult {
    if (_value.recentResult == null) {
      return null;
    }

    return $PracticeCatalogRecentResultSummaryCopyWith<$Res>(
      _value.recentResult!,
      (value) {
        return _then(_value.copyWith(recentResult: value) as $Val);
      },
    );
  }
}

/// @nodoc
abstract class _$$PracticeCatalogActivitySummaryImplCopyWith<$Res>
    implements $PracticeCatalogActivitySummaryCopyWith<$Res> {
  factory _$$PracticeCatalogActivitySummaryImplCopyWith(
    _$PracticeCatalogActivitySummaryImpl value,
    $Res Function(_$PracticeCatalogActivitySummaryImpl) then,
  ) = __$$PracticeCatalogActivitySummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String spaceId,
    String spaceTitle,
    String activityId,
    String title,
    String summary,
    String sceneTag,
    String coachTip,
    int totalPhraseCount,
    int completedPhraseCount,
    List<String> completedPhraseIds,
    String? nextPhraseId,
    String? nextPhraseEnglish,
    int totalEvents,
    int skippedUnknownPhraseCount,
    int skippedMalformedEventCount,
    String? generatedContentId,
    DateTime? lastEventTime,
    PracticeCatalogRecentResultSummary? recentResult,
    String? warningMessage,
  });

  @override
  $PracticeCatalogRecentResultSummaryCopyWith<$Res>? get recentResult;
}

/// @nodoc
class __$$PracticeCatalogActivitySummaryImplCopyWithImpl<$Res>
    extends
        _$PracticeCatalogActivitySummaryCopyWithImpl<
          $Res,
          _$PracticeCatalogActivitySummaryImpl
        >
    implements _$$PracticeCatalogActivitySummaryImplCopyWith<$Res> {
  __$$PracticeCatalogActivitySummaryImplCopyWithImpl(
    _$PracticeCatalogActivitySummaryImpl _value,
    $Res Function(_$PracticeCatalogActivitySummaryImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? spaceTitle = null,
    Object? activityId = null,
    Object? title = null,
    Object? summary = null,
    Object? sceneTag = null,
    Object? coachTip = null,
    Object? totalPhraseCount = null,
    Object? completedPhraseCount = null,
    Object? completedPhraseIds = null,
    Object? nextPhraseId = freezed,
    Object? nextPhraseEnglish = freezed,
    Object? totalEvents = null,
    Object? skippedUnknownPhraseCount = null,
    Object? skippedMalformedEventCount = null,
    Object? generatedContentId = freezed,
    Object? lastEventTime = freezed,
    Object? recentResult = freezed,
    Object? warningMessage = freezed,
  }) {
    return _then(
      _$PracticeCatalogActivitySummaryImpl(
        spaceId: null == spaceId
            ? _value.spaceId
            : spaceId // ignore: cast_nullable_to_non_nullable
                  as String,
        spaceTitle: null == spaceTitle
            ? _value.spaceTitle
            : spaceTitle // ignore: cast_nullable_to_non_nullable
                  as String,
        activityId: null == activityId
            ? _value.activityId
            : activityId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        sceneTag: null == sceneTag
            ? _value.sceneTag
            : sceneTag // ignore: cast_nullable_to_non_nullable
                  as String,
        coachTip: null == coachTip
            ? _value.coachTip
            : coachTip // ignore: cast_nullable_to_non_nullable
                  as String,
        totalPhraseCount: null == totalPhraseCount
            ? _value.totalPhraseCount
            : totalPhraseCount // ignore: cast_nullable_to_non_nullable
                  as int,
        completedPhraseCount: null == completedPhraseCount
            ? _value.completedPhraseCount
            : completedPhraseCount // ignore: cast_nullable_to_non_nullable
                  as int,
        completedPhraseIds: null == completedPhraseIds
            ? _value._completedPhraseIds
            : completedPhraseIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        nextPhraseId: freezed == nextPhraseId
            ? _value.nextPhraseId
            : nextPhraseId // ignore: cast_nullable_to_non_nullable
                  as String?,
        nextPhraseEnglish: freezed == nextPhraseEnglish
            ? _value.nextPhraseEnglish
            : nextPhraseEnglish // ignore: cast_nullable_to_non_nullable
                  as String?,
        totalEvents: null == totalEvents
            ? _value.totalEvents
            : totalEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        skippedUnknownPhraseCount: null == skippedUnknownPhraseCount
            ? _value.skippedUnknownPhraseCount
            : skippedUnknownPhraseCount // ignore: cast_nullable_to_non_nullable
                  as int,
        skippedMalformedEventCount: null == skippedMalformedEventCount
            ? _value.skippedMalformedEventCount
            : skippedMalformedEventCount // ignore: cast_nullable_to_non_nullable
                  as int,
        generatedContentId: freezed == generatedContentId
            ? _value.generatedContentId
            : generatedContentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastEventTime: freezed == lastEventTime
            ? _value.lastEventTime
            : lastEventTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        recentResult: freezed == recentResult
            ? _value.recentResult
            : recentResult // ignore: cast_nullable_to_non_nullable
                  as PracticeCatalogRecentResultSummary?,
        warningMessage: freezed == warningMessage
            ? _value.warningMessage
            : warningMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$PracticeCatalogActivitySummaryImpl
    extends _PracticeCatalogActivitySummary {
  const _$PracticeCatalogActivitySummaryImpl({
    required this.spaceId,
    required this.spaceTitle,
    required this.activityId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.totalPhraseCount,
    required this.completedPhraseCount,
    required final List<String> completedPhraseIds,
    required this.nextPhraseId,
    required this.nextPhraseEnglish,
    required this.totalEvents,
    required this.skippedUnknownPhraseCount,
    required this.skippedMalformedEventCount,
    this.generatedContentId,
    this.lastEventTime,
    this.recentResult,
    this.warningMessage,
  }) : _completedPhraseIds = completedPhraseIds,
       super._();

  @override
  final String spaceId;
  @override
  final String spaceTitle;
  @override
  final String activityId;
  @override
  final String title;
  @override
  final String summary;
  @override
  final String sceneTag;
  @override
  final String coachTip;
  @override
  final int totalPhraseCount;
  @override
  final int completedPhraseCount;
  final List<String> _completedPhraseIds;
  @override
  List<String> get completedPhraseIds {
    if (_completedPhraseIds is EqualUnmodifiableListView)
      return _completedPhraseIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_completedPhraseIds);
  }

  @override
  final String? nextPhraseId;
  @override
  final String? nextPhraseEnglish;
  @override
  final int totalEvents;
  @override
  final int skippedUnknownPhraseCount;
  @override
  final int skippedMalformedEventCount;
  @override
  final String? generatedContentId;
  @override
  final DateTime? lastEventTime;
  @override
  final PracticeCatalogRecentResultSummary? recentResult;
  @override
  final String? warningMessage;

  @override
  String toString() {
    return 'PracticeCatalogActivitySummary(spaceId: $spaceId, spaceTitle: $spaceTitle, activityId: $activityId, title: $title, summary: $summary, sceneTag: $sceneTag, coachTip: $coachTip, totalPhraseCount: $totalPhraseCount, completedPhraseCount: $completedPhraseCount, completedPhraseIds: $completedPhraseIds, nextPhraseId: $nextPhraseId, nextPhraseEnglish: $nextPhraseEnglish, totalEvents: $totalEvents, skippedUnknownPhraseCount: $skippedUnknownPhraseCount, skippedMalformedEventCount: $skippedMalformedEventCount, generatedContentId: $generatedContentId, lastEventTime: $lastEventTime, recentResult: $recentResult, warningMessage: $warningMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PracticeCatalogActivitySummaryImpl &&
            (identical(other.spaceId, spaceId) || other.spaceId == spaceId) &&
            (identical(other.spaceTitle, spaceTitle) ||
                other.spaceTitle == spaceTitle) &&
            (identical(other.activityId, activityId) ||
                other.activityId == activityId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.sceneTag, sceneTag) ||
                other.sceneTag == sceneTag) &&
            (identical(other.coachTip, coachTip) ||
                other.coachTip == coachTip) &&
            (identical(other.totalPhraseCount, totalPhraseCount) ||
                other.totalPhraseCount == totalPhraseCount) &&
            (identical(other.completedPhraseCount, completedPhraseCount) ||
                other.completedPhraseCount == completedPhraseCount) &&
            const DeepCollectionEquality().equals(
              other._completedPhraseIds,
              _completedPhraseIds,
            ) &&
            (identical(other.nextPhraseId, nextPhraseId) ||
                other.nextPhraseId == nextPhraseId) &&
            (identical(other.nextPhraseEnglish, nextPhraseEnglish) ||
                other.nextPhraseEnglish == nextPhraseEnglish) &&
            (identical(other.totalEvents, totalEvents) ||
                other.totalEvents == totalEvents) &&
            (identical(
                  other.skippedUnknownPhraseCount,
                  skippedUnknownPhraseCount,
                ) ||
                other.skippedUnknownPhraseCount == skippedUnknownPhraseCount) &&
            (identical(
                  other.skippedMalformedEventCount,
                  skippedMalformedEventCount,
                ) ||
                other.skippedMalformedEventCount ==
                    skippedMalformedEventCount) &&
            (identical(other.generatedContentId, generatedContentId) ||
                other.generatedContentId == generatedContentId) &&
            (identical(other.lastEventTime, lastEventTime) ||
                other.lastEventTime == lastEventTime) &&
            (identical(other.recentResult, recentResult) ||
                other.recentResult == recentResult) &&
            (identical(other.warningMessage, warningMessage) ||
                other.warningMessage == warningMessage));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    spaceId,
    spaceTitle,
    activityId,
    title,
    summary,
    sceneTag,
    coachTip,
    totalPhraseCount,
    completedPhraseCount,
    const DeepCollectionEquality().hash(_completedPhraseIds),
    nextPhraseId,
    nextPhraseEnglish,
    totalEvents,
    skippedUnknownPhraseCount,
    skippedMalformedEventCount,
    generatedContentId,
    lastEventTime,
    recentResult,
    warningMessage,
  ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PracticeCatalogActivitySummaryImplCopyWith<
    _$PracticeCatalogActivitySummaryImpl
  >
  get copyWith =>
      __$$PracticeCatalogActivitySummaryImplCopyWithImpl<
        _$PracticeCatalogActivitySummaryImpl
      >(this, _$identity);
}

abstract class _PracticeCatalogActivitySummary
    extends PracticeCatalogActivitySummary {
  const factory _PracticeCatalogActivitySummary({
    required final String spaceId,
    required final String spaceTitle,
    required final String activityId,
    required final String title,
    required final String summary,
    required final String sceneTag,
    required final String coachTip,
    required final int totalPhraseCount,
    required final int completedPhraseCount,
    required final List<String> completedPhraseIds,
    required final String? nextPhraseId,
    required final String? nextPhraseEnglish,
    required final int totalEvents,
    required final int skippedUnknownPhraseCount,
    required final int skippedMalformedEventCount,
    final String? generatedContentId,
    final DateTime? lastEventTime,
    final PracticeCatalogRecentResultSummary? recentResult,
    final String? warningMessage,
  }) = _$PracticeCatalogActivitySummaryImpl;
  const _PracticeCatalogActivitySummary._() : super._();

  @override
  String get spaceId;
  @override
  String get spaceTitle;
  @override
  String get activityId;
  @override
  String get title;
  @override
  String get summary;
  @override
  String get sceneTag;
  @override
  String get coachTip;
  @override
  int get totalPhraseCount;
  @override
  int get completedPhraseCount;
  @override
  List<String> get completedPhraseIds;
  @override
  String? get nextPhraseId;
  @override
  String? get nextPhraseEnglish;
  @override
  int get totalEvents;
  @override
  int get skippedUnknownPhraseCount;
  @override
  int get skippedMalformedEventCount;
  @override
  String? get generatedContentId;
  @override
  DateTime? get lastEventTime;
  @override
  PracticeCatalogRecentResultSummary? get recentResult;
  @override
  String? get warningMessage;
  @override
  @JsonKey(ignore: true)
  _$$PracticeCatalogActivitySummaryImplCopyWith<
    _$PracticeCatalogActivitySummaryImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PracticeCatalogSpaceSummary {
  String get spaceId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<PracticeCatalogActivitySummary> get activities =>
      throw _privateConstructorUsedError;
  int get totalEvents => throw _privateConstructorUsedError;
  int get startedActivityCount => throw _privateConstructorUsedError;
  int get completedActivityCount => throw _privateConstructorUsedError;
  DateTime? get lastEventTime => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PracticeCatalogSpaceSummaryCopyWith<PracticeCatalogSpaceSummary>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PracticeCatalogSpaceSummaryCopyWith<$Res> {
  factory $PracticeCatalogSpaceSummaryCopyWith(
    PracticeCatalogSpaceSummary value,
    $Res Function(PracticeCatalogSpaceSummary) then,
  ) =
      _$PracticeCatalogSpaceSummaryCopyWithImpl<
        $Res,
        PracticeCatalogSpaceSummary
      >;
  @useResult
  $Res call({
    String spaceId,
    String title,
    String description,
    List<PracticeCatalogActivitySummary> activities,
    int totalEvents,
    int startedActivityCount,
    int completedActivityCount,
    DateTime? lastEventTime,
  });
}

/// @nodoc
class _$PracticeCatalogSpaceSummaryCopyWithImpl<
  $Res,
  $Val extends PracticeCatalogSpaceSummary
>
    implements $PracticeCatalogSpaceSummaryCopyWith<$Res> {
  _$PracticeCatalogSpaceSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? title = null,
    Object? description = null,
    Object? activities = null,
    Object? totalEvents = null,
    Object? startedActivityCount = null,
    Object? completedActivityCount = null,
    Object? lastEventTime = freezed,
  }) {
    return _then(
      _value.copyWith(
            spaceId: null == spaceId
                ? _value.spaceId
                : spaceId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            activities: null == activities
                ? _value.activities
                : activities // ignore: cast_nullable_to_non_nullable
                      as List<PracticeCatalogActivitySummary>,
            totalEvents: null == totalEvents
                ? _value.totalEvents
                : totalEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            startedActivityCount: null == startedActivityCount
                ? _value.startedActivityCount
                : startedActivityCount // ignore: cast_nullable_to_non_nullable
                      as int,
            completedActivityCount: null == completedActivityCount
                ? _value.completedActivityCount
                : completedActivityCount // ignore: cast_nullable_to_non_nullable
                      as int,
            lastEventTime: freezed == lastEventTime
                ? _value.lastEventTime
                : lastEventTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PracticeCatalogSpaceSummaryImplCopyWith<$Res>
    implements $PracticeCatalogSpaceSummaryCopyWith<$Res> {
  factory _$$PracticeCatalogSpaceSummaryImplCopyWith(
    _$PracticeCatalogSpaceSummaryImpl value,
    $Res Function(_$PracticeCatalogSpaceSummaryImpl) then,
  ) = __$$PracticeCatalogSpaceSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String spaceId,
    String title,
    String description,
    List<PracticeCatalogActivitySummary> activities,
    int totalEvents,
    int startedActivityCount,
    int completedActivityCount,
    DateTime? lastEventTime,
  });
}

/// @nodoc
class __$$PracticeCatalogSpaceSummaryImplCopyWithImpl<$Res>
    extends
        _$PracticeCatalogSpaceSummaryCopyWithImpl<
          $Res,
          _$PracticeCatalogSpaceSummaryImpl
        >
    implements _$$PracticeCatalogSpaceSummaryImplCopyWith<$Res> {
  __$$PracticeCatalogSpaceSummaryImplCopyWithImpl(
    _$PracticeCatalogSpaceSummaryImpl _value,
    $Res Function(_$PracticeCatalogSpaceSummaryImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? title = null,
    Object? description = null,
    Object? activities = null,
    Object? totalEvents = null,
    Object? startedActivityCount = null,
    Object? completedActivityCount = null,
    Object? lastEventTime = freezed,
  }) {
    return _then(
      _$PracticeCatalogSpaceSummaryImpl(
        spaceId: null == spaceId
            ? _value.spaceId
            : spaceId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        activities: null == activities
            ? _value._activities
            : activities // ignore: cast_nullable_to_non_nullable
                  as List<PracticeCatalogActivitySummary>,
        totalEvents: null == totalEvents
            ? _value.totalEvents
            : totalEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        startedActivityCount: null == startedActivityCount
            ? _value.startedActivityCount
            : startedActivityCount // ignore: cast_nullable_to_non_nullable
                  as int,
        completedActivityCount: null == completedActivityCount
            ? _value.completedActivityCount
            : completedActivityCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastEventTime: freezed == lastEventTime
            ? _value.lastEventTime
            : lastEventTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$PracticeCatalogSpaceSummaryImpl extends _PracticeCatalogSpaceSummary {
  const _$PracticeCatalogSpaceSummaryImpl({
    required this.spaceId,
    required this.title,
    required this.description,
    required final List<PracticeCatalogActivitySummary> activities,
    required this.totalEvents,
    required this.startedActivityCount,
    required this.completedActivityCount,
    this.lastEventTime,
  }) : _activities = activities,
       super._();

  @override
  final String spaceId;
  @override
  final String title;
  @override
  final String description;
  final List<PracticeCatalogActivitySummary> _activities;
  @override
  List<PracticeCatalogActivitySummary> get activities {
    if (_activities is EqualUnmodifiableListView) return _activities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activities);
  }

  @override
  final int totalEvents;
  @override
  final int startedActivityCount;
  @override
  final int completedActivityCount;
  @override
  final DateTime? lastEventTime;

  @override
  String toString() {
    return 'PracticeCatalogSpaceSummary(spaceId: $spaceId, title: $title, description: $description, activities: $activities, totalEvents: $totalEvents, startedActivityCount: $startedActivityCount, completedActivityCount: $completedActivityCount, lastEventTime: $lastEventTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PracticeCatalogSpaceSummaryImpl &&
            (identical(other.spaceId, spaceId) || other.spaceId == spaceId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(
              other._activities,
              _activities,
            ) &&
            (identical(other.totalEvents, totalEvents) ||
                other.totalEvents == totalEvents) &&
            (identical(other.startedActivityCount, startedActivityCount) ||
                other.startedActivityCount == startedActivityCount) &&
            (identical(other.completedActivityCount, completedActivityCount) ||
                other.completedActivityCount == completedActivityCount) &&
            (identical(other.lastEventTime, lastEventTime) ||
                other.lastEventTime == lastEventTime));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    spaceId,
    title,
    description,
    const DeepCollectionEquality().hash(_activities),
    totalEvents,
    startedActivityCount,
    completedActivityCount,
    lastEventTime,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PracticeCatalogSpaceSummaryImplCopyWith<_$PracticeCatalogSpaceSummaryImpl>
  get copyWith =>
      __$$PracticeCatalogSpaceSummaryImplCopyWithImpl<
        _$PracticeCatalogSpaceSummaryImpl
      >(this, _$identity);
}

abstract class _PracticeCatalogSpaceSummary
    extends PracticeCatalogSpaceSummary {
  const factory _PracticeCatalogSpaceSummary({
    required final String spaceId,
    required final String title,
    required final String description,
    required final List<PracticeCatalogActivitySummary> activities,
    required final int totalEvents,
    required final int startedActivityCount,
    required final int completedActivityCount,
    final DateTime? lastEventTime,
  }) = _$PracticeCatalogSpaceSummaryImpl;
  const _PracticeCatalogSpaceSummary._() : super._();

  @override
  String get spaceId;
  @override
  String get title;
  @override
  String get description;
  @override
  List<PracticeCatalogActivitySummary> get activities;
  @override
  int get totalEvents;
  @override
  int get startedActivityCount;
  @override
  int get completedActivityCount;
  @override
  DateTime? get lastEventTime;
  @override
  @JsonKey(ignore: true)
  _$$PracticeCatalogSpaceSummaryImplCopyWith<_$PracticeCatalogSpaceSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PracticeActivityCatalog {
  String? get installationId => throw _privateConstructorUsedError;
  List<PracticeCatalogSpaceSummary> get spaces =>
      throw _privateConstructorUsedError;
  List<PracticeCatalogActivitySummary> get activities =>
      throw _privateConstructorUsedError;
  int get totalStoredEvents => throw _privateConstructorUsedError;
  int get validEvents => throw _privateConstructorUsedError;
  int get knownEvents => throw _privateConstructorUsedError;
  int get skippedMalformedEvents => throw _privateConstructorUsedError;
  int get skippedUnknownContentEvents => throw _privateConstructorUsedError;
  String? get lastIssueMessage => throw _privateConstructorUsedError;
  String? get catalogWarning => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PracticeActivityCatalogCopyWith<PracticeActivityCatalog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PracticeActivityCatalogCopyWith<$Res> {
  factory $PracticeActivityCatalogCopyWith(
    PracticeActivityCatalog value,
    $Res Function(PracticeActivityCatalog) then,
  ) = _$PracticeActivityCatalogCopyWithImpl<$Res, PracticeActivityCatalog>;
  @useResult
  $Res call({
    String? installationId,
    List<PracticeCatalogSpaceSummary> spaces,
    List<PracticeCatalogActivitySummary> activities,
    int totalStoredEvents,
    int validEvents,
    int knownEvents,
    int skippedMalformedEvents,
    int skippedUnknownContentEvents,
    String? lastIssueMessage,
    String? catalogWarning,
  });
}

/// @nodoc
class _$PracticeActivityCatalogCopyWithImpl<
  $Res,
  $Val extends PracticeActivityCatalog
>
    implements $PracticeActivityCatalogCopyWith<$Res> {
  _$PracticeActivityCatalogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? installationId = freezed,
    Object? spaces = null,
    Object? activities = null,
    Object? totalStoredEvents = null,
    Object? validEvents = null,
    Object? knownEvents = null,
    Object? skippedMalformedEvents = null,
    Object? skippedUnknownContentEvents = null,
    Object? lastIssueMessage = freezed,
    Object? catalogWarning = freezed,
  }) {
    return _then(
      _value.copyWith(
            installationId: freezed == installationId
                ? _value.installationId
                : installationId // ignore: cast_nullable_to_non_nullable
                      as String?,
            spaces: null == spaces
                ? _value.spaces
                : spaces // ignore: cast_nullable_to_non_nullable
                      as List<PracticeCatalogSpaceSummary>,
            activities: null == activities
                ? _value.activities
                : activities // ignore: cast_nullable_to_non_nullable
                      as List<PracticeCatalogActivitySummary>,
            totalStoredEvents: null == totalStoredEvents
                ? _value.totalStoredEvents
                : totalStoredEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            validEvents: null == validEvents
                ? _value.validEvents
                : validEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            knownEvents: null == knownEvents
                ? _value.knownEvents
                : knownEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            skippedMalformedEvents: null == skippedMalformedEvents
                ? _value.skippedMalformedEvents
                : skippedMalformedEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            skippedUnknownContentEvents: null == skippedUnknownContentEvents
                ? _value.skippedUnknownContentEvents
                : skippedUnknownContentEvents // ignore: cast_nullable_to_non_nullable
                      as int,
            lastIssueMessage: freezed == lastIssueMessage
                ? _value.lastIssueMessage
                : lastIssueMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            catalogWarning: freezed == catalogWarning
                ? _value.catalogWarning
                : catalogWarning // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PracticeActivityCatalogImplCopyWith<$Res>
    implements $PracticeActivityCatalogCopyWith<$Res> {
  factory _$$PracticeActivityCatalogImplCopyWith(
    _$PracticeActivityCatalogImpl value,
    $Res Function(_$PracticeActivityCatalogImpl) then,
  ) = __$$PracticeActivityCatalogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? installationId,
    List<PracticeCatalogSpaceSummary> spaces,
    List<PracticeCatalogActivitySummary> activities,
    int totalStoredEvents,
    int validEvents,
    int knownEvents,
    int skippedMalformedEvents,
    int skippedUnknownContentEvents,
    String? lastIssueMessage,
    String? catalogWarning,
  });
}

/// @nodoc
class __$$PracticeActivityCatalogImplCopyWithImpl<$Res>
    extends
        _$PracticeActivityCatalogCopyWithImpl<
          $Res,
          _$PracticeActivityCatalogImpl
        >
    implements _$$PracticeActivityCatalogImplCopyWith<$Res> {
  __$$PracticeActivityCatalogImplCopyWithImpl(
    _$PracticeActivityCatalogImpl _value,
    $Res Function(_$PracticeActivityCatalogImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? installationId = freezed,
    Object? spaces = null,
    Object? activities = null,
    Object? totalStoredEvents = null,
    Object? validEvents = null,
    Object? knownEvents = null,
    Object? skippedMalformedEvents = null,
    Object? skippedUnknownContentEvents = null,
    Object? lastIssueMessage = freezed,
    Object? catalogWarning = freezed,
  }) {
    return _then(
      _$PracticeActivityCatalogImpl(
        installationId: freezed == installationId
            ? _value.installationId
            : installationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        spaces: null == spaces
            ? _value._spaces
            : spaces // ignore: cast_nullable_to_non_nullable
                  as List<PracticeCatalogSpaceSummary>,
        activities: null == activities
            ? _value._activities
            : activities // ignore: cast_nullable_to_non_nullable
                  as List<PracticeCatalogActivitySummary>,
        totalStoredEvents: null == totalStoredEvents
            ? _value.totalStoredEvents
            : totalStoredEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        validEvents: null == validEvents
            ? _value.validEvents
            : validEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        knownEvents: null == knownEvents
            ? _value.knownEvents
            : knownEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        skippedMalformedEvents: null == skippedMalformedEvents
            ? _value.skippedMalformedEvents
            : skippedMalformedEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        skippedUnknownContentEvents: null == skippedUnknownContentEvents
            ? _value.skippedUnknownContentEvents
            : skippedUnknownContentEvents // ignore: cast_nullable_to_non_nullable
                  as int,
        lastIssueMessage: freezed == lastIssueMessage
            ? _value.lastIssueMessage
            : lastIssueMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        catalogWarning: freezed == catalogWarning
            ? _value.catalogWarning
            : catalogWarning // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$PracticeActivityCatalogImpl extends _PracticeActivityCatalog {
  const _$PracticeActivityCatalogImpl({
    required this.installationId,
    required final List<PracticeCatalogSpaceSummary> spaces,
    required final List<PracticeCatalogActivitySummary> activities,
    required this.totalStoredEvents,
    required this.validEvents,
    required this.knownEvents,
    required this.skippedMalformedEvents,
    required this.skippedUnknownContentEvents,
    this.lastIssueMessage,
    this.catalogWarning,
  }) : _spaces = spaces,
       _activities = activities,
       super._();

  @override
  final String? installationId;
  final List<PracticeCatalogSpaceSummary> _spaces;
  @override
  List<PracticeCatalogSpaceSummary> get spaces {
    if (_spaces is EqualUnmodifiableListView) return _spaces;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_spaces);
  }

  final List<PracticeCatalogActivitySummary> _activities;
  @override
  List<PracticeCatalogActivitySummary> get activities {
    if (_activities is EqualUnmodifiableListView) return _activities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activities);
  }

  @override
  final int totalStoredEvents;
  @override
  final int validEvents;
  @override
  final int knownEvents;
  @override
  final int skippedMalformedEvents;
  @override
  final int skippedUnknownContentEvents;
  @override
  final String? lastIssueMessage;
  @override
  final String? catalogWarning;

  @override
  String toString() {
    return 'PracticeActivityCatalog(installationId: $installationId, spaces: $spaces, activities: $activities, totalStoredEvents: $totalStoredEvents, validEvents: $validEvents, knownEvents: $knownEvents, skippedMalformedEvents: $skippedMalformedEvents, skippedUnknownContentEvents: $skippedUnknownContentEvents, lastIssueMessage: $lastIssueMessage, catalogWarning: $catalogWarning)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PracticeActivityCatalogImpl &&
            (identical(other.installationId, installationId) ||
                other.installationId == installationId) &&
            const DeepCollectionEquality().equals(other._spaces, _spaces) &&
            const DeepCollectionEquality().equals(
              other._activities,
              _activities,
            ) &&
            (identical(other.totalStoredEvents, totalStoredEvents) ||
                other.totalStoredEvents == totalStoredEvents) &&
            (identical(other.validEvents, validEvents) ||
                other.validEvents == validEvents) &&
            (identical(other.knownEvents, knownEvents) ||
                other.knownEvents == knownEvents) &&
            (identical(other.skippedMalformedEvents, skippedMalformedEvents) ||
                other.skippedMalformedEvents == skippedMalformedEvents) &&
            (identical(
                  other.skippedUnknownContentEvents,
                  skippedUnknownContentEvents,
                ) ||
                other.skippedUnknownContentEvents ==
                    skippedUnknownContentEvents) &&
            (identical(other.lastIssueMessage, lastIssueMessage) ||
                other.lastIssueMessage == lastIssueMessage) &&
            (identical(other.catalogWarning, catalogWarning) ||
                other.catalogWarning == catalogWarning));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    installationId,
    const DeepCollectionEquality().hash(_spaces),
    const DeepCollectionEquality().hash(_activities),
    totalStoredEvents,
    validEvents,
    knownEvents,
    skippedMalformedEvents,
    skippedUnknownContentEvents,
    lastIssueMessage,
    catalogWarning,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PracticeActivityCatalogImplCopyWith<_$PracticeActivityCatalogImpl>
  get copyWith =>
      __$$PracticeActivityCatalogImplCopyWithImpl<
        _$PracticeActivityCatalogImpl
      >(this, _$identity);
}

abstract class _PracticeActivityCatalog extends PracticeActivityCatalog {
  const factory _PracticeActivityCatalog({
    required final String? installationId,
    required final List<PracticeCatalogSpaceSummary> spaces,
    required final List<PracticeCatalogActivitySummary> activities,
    required final int totalStoredEvents,
    required final int validEvents,
    required final int knownEvents,
    required final int skippedMalformedEvents,
    required final int skippedUnknownContentEvents,
    final String? lastIssueMessage,
    final String? catalogWarning,
  }) = _$PracticeActivityCatalogImpl;
  const _PracticeActivityCatalog._() : super._();

  @override
  String? get installationId;
  @override
  List<PracticeCatalogSpaceSummary> get spaces;
  @override
  List<PracticeCatalogActivitySummary> get activities;
  @override
  int get totalStoredEvents;
  @override
  int get validEvents;
  @override
  int get knownEvents;
  @override
  int get skippedMalformedEvents;
  @override
  int get skippedUnknownContentEvents;
  @override
  String? get lastIssueMessage;
  @override
  String? get catalogWarning;
  @override
  @JsonKey(ignore: true)
  _$$PracticeActivityCatalogImplCopyWith<_$PracticeActivityCatalogImpl>
  get copyWith => throw _privateConstructorUsedError;
}

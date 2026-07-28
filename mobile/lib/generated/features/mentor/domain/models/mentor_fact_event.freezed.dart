// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../../features/mentor/domain/models/mentor_fact_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MentorFactEvent {
  String get localEventId => throw _privateConstructorUsedError;
  String get installationId => throw _privateConstructorUsedError;
  MentorFactType get eventType => throw _privateConstructorUsedError;
  String get phase => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String? get correlationId => throw _privateConstructorUsedError;
  String? get redactedSummary => throw _privateConstructorUsedError;
  String? get visibleStatus => throw _privateConstructorUsedError;
  String? get visibleDetail => throw _privateConstructorUsedError;
  bool get retryable => throw _privateConstructorUsedError;
  bool get contextFallbackUsed => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MentorFactEventCopyWith<MentorFactEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MentorFactEventCopyWith<$Res> {
  factory $MentorFactEventCopyWith(
    MentorFactEvent value,
    $Res Function(MentorFactEvent) then,
  ) = _$MentorFactEventCopyWithImpl<$Res, MentorFactEvent>;
  @useResult
  $Res call({
    String localEventId,
    String installationId,
    MentorFactType eventType,
    String phase,
    DateTime createdAt,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable,
    bool contextFallbackUsed,
  });
}

/// @nodoc
class _$MentorFactEventCopyWithImpl<$Res, $Val extends MentorFactEvent>
    implements $MentorFactEventCopyWith<$Res> {
  _$MentorFactEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? localEventId = null,
    Object? installationId = null,
    Object? eventType = null,
    Object? phase = null,
    Object? createdAt = null,
    Object? correlationId = freezed,
    Object? redactedSummary = freezed,
    Object? visibleStatus = freezed,
    Object? visibleDetail = freezed,
    Object? retryable = null,
    Object? contextFallbackUsed = null,
  }) {
    return _then(
      _value.copyWith(
            localEventId: null == localEventId
                ? _value.localEventId
                : localEventId // ignore: cast_nullable_to_non_nullable
                      as String,
            installationId: null == installationId
                ? _value.installationId
                : installationId // ignore: cast_nullable_to_non_nullable
                      as String,
            eventType: null == eventType
                ? _value.eventType
                : eventType // ignore: cast_nullable_to_non_nullable
                      as MentorFactType,
            phase: null == phase
                ? _value.phase
                : phase // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            correlationId: freezed == correlationId
                ? _value.correlationId
                : correlationId // ignore: cast_nullable_to_non_nullable
                      as String?,
            redactedSummary: freezed == redactedSummary
                ? _value.redactedSummary
                : redactedSummary // ignore: cast_nullable_to_non_nullable
                      as String?,
            visibleStatus: freezed == visibleStatus
                ? _value.visibleStatus
                : visibleStatus // ignore: cast_nullable_to_non_nullable
                      as String?,
            visibleDetail: freezed == visibleDetail
                ? _value.visibleDetail
                : visibleDetail // ignore: cast_nullable_to_non_nullable
                      as String?,
            retryable: null == retryable
                ? _value.retryable
                : retryable // ignore: cast_nullable_to_non_nullable
                      as bool,
            contextFallbackUsed: null == contextFallbackUsed
                ? _value.contextFallbackUsed
                : contextFallbackUsed // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MentorFactEventImplCopyWith<$Res>
    implements $MentorFactEventCopyWith<$Res> {
  factory _$$MentorFactEventImplCopyWith(
    _$MentorFactEventImpl value,
    $Res Function(_$MentorFactEventImpl) then,
  ) = __$$MentorFactEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String localEventId,
    String installationId,
    MentorFactType eventType,
    String phase,
    DateTime createdAt,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable,
    bool contextFallbackUsed,
  });
}

/// @nodoc
class __$$MentorFactEventImplCopyWithImpl<$Res>
    extends _$MentorFactEventCopyWithImpl<$Res, _$MentorFactEventImpl>
    implements _$$MentorFactEventImplCopyWith<$Res> {
  __$$MentorFactEventImplCopyWithImpl(
    _$MentorFactEventImpl _value,
    $Res Function(_$MentorFactEventImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? localEventId = null,
    Object? installationId = null,
    Object? eventType = null,
    Object? phase = null,
    Object? createdAt = null,
    Object? correlationId = freezed,
    Object? redactedSummary = freezed,
    Object? visibleStatus = freezed,
    Object? visibleDetail = freezed,
    Object? retryable = null,
    Object? contextFallbackUsed = null,
  }) {
    return _then(
      _$MentorFactEventImpl(
        localEventId: null == localEventId
            ? _value.localEventId
            : localEventId // ignore: cast_nullable_to_non_nullable
                  as String,
        installationId: null == installationId
            ? _value.installationId
            : installationId // ignore: cast_nullable_to_non_nullable
                  as String,
        eventType: null == eventType
            ? _value.eventType
            : eventType // ignore: cast_nullable_to_non_nullable
                  as MentorFactType,
        phase: null == phase
            ? _value.phase
            : phase // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        correlationId: freezed == correlationId
            ? _value.correlationId
            : correlationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        redactedSummary: freezed == redactedSummary
            ? _value.redactedSummary
            : redactedSummary // ignore: cast_nullable_to_non_nullable
                  as String?,
        visibleStatus: freezed == visibleStatus
            ? _value.visibleStatus
            : visibleStatus // ignore: cast_nullable_to_non_nullable
                  as String?,
        visibleDetail: freezed == visibleDetail
            ? _value.visibleDetail
            : visibleDetail // ignore: cast_nullable_to_non_nullable
                  as String?,
        retryable: null == retryable
            ? _value.retryable
            : retryable // ignore: cast_nullable_to_non_nullable
                  as bool,
        contextFallbackUsed: null == contextFallbackUsed
            ? _value.contextFallbackUsed
            : contextFallbackUsed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$MentorFactEventImpl extends _MentorFactEvent {
  _$MentorFactEventImpl({
    required this.localEventId,
    required this.installationId,
    required this.eventType,
    required this.phase,
    required this.createdAt,
    this.correlationId,
    this.redactedSummary,
    this.visibleStatus,
    this.visibleDetail,
    this.retryable = false,
    this.contextFallbackUsed = false,
  }) : super._();

  @override
  final String localEventId;
  @override
  final String installationId;
  @override
  final MentorFactType eventType;
  @override
  final String phase;
  @override
  final DateTime createdAt;
  @override
  final String? correlationId;
  @override
  final String? redactedSummary;
  @override
  final String? visibleStatus;
  @override
  final String? visibleDetail;
  @override
  @JsonKey()
  final bool retryable;
  @override
  @JsonKey()
  final bool contextFallbackUsed;

  @override
  String toString() {
    return 'MentorFactEvent(localEventId: $localEventId, installationId: $installationId, eventType: $eventType, phase: $phase, createdAt: $createdAt, correlationId: $correlationId, redactedSummary: $redactedSummary, visibleStatus: $visibleStatus, visibleDetail: $visibleDetail, retryable: $retryable, contextFallbackUsed: $contextFallbackUsed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MentorFactEventImpl &&
            (identical(other.localEventId, localEventId) ||
                other.localEventId == localEventId) &&
            (identical(other.installationId, installationId) ||
                other.installationId == installationId) &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            (identical(other.phase, phase) || other.phase == phase) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.correlationId, correlationId) ||
                other.correlationId == correlationId) &&
            (identical(other.redactedSummary, redactedSummary) ||
                other.redactedSummary == redactedSummary) &&
            (identical(other.visibleStatus, visibleStatus) ||
                other.visibleStatus == visibleStatus) &&
            (identical(other.visibleDetail, visibleDetail) ||
                other.visibleDetail == visibleDetail) &&
            (identical(other.retryable, retryable) ||
                other.retryable == retryable) &&
            (identical(other.contextFallbackUsed, contextFallbackUsed) ||
                other.contextFallbackUsed == contextFallbackUsed));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    localEventId,
    installationId,
    eventType,
    phase,
    createdAt,
    correlationId,
    redactedSummary,
    visibleStatus,
    visibleDetail,
    retryable,
    contextFallbackUsed,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MentorFactEventImplCopyWith<_$MentorFactEventImpl> get copyWith =>
      __$$MentorFactEventImplCopyWithImpl<_$MentorFactEventImpl>(
        this,
        _$identity,
      );
}

abstract class _MentorFactEvent extends MentorFactEvent {
  factory _MentorFactEvent({
    required final String localEventId,
    required final String installationId,
    required final MentorFactType eventType,
    required final String phase,
    required final DateTime createdAt,
    final String? correlationId,
    final String? redactedSummary,
    final String? visibleStatus,
    final String? visibleDetail,
    final bool retryable,
    final bool contextFallbackUsed,
  }) = _$MentorFactEventImpl;
  _MentorFactEvent._() : super._();

  @override
  String get localEventId;
  @override
  String get installationId;
  @override
  MentorFactType get eventType;
  @override
  String get phase;
  @override
  DateTime get createdAt;
  @override
  String? get correlationId;
  @override
  String? get redactedSummary;
  @override
  String? get visibleStatus;
  @override
  String? get visibleDetail;
  @override
  bool get retryable;
  @override
  bool get contextFallbackUsed;
  @override
  @JsonKey(ignore: true)
  _$$MentorFactEventImplCopyWith<_$MentorFactEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

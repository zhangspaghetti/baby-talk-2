// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../../features/onboarding/domain/models/onboarding_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$OnboardingSnapshot {
  int get schemaVersion => throw _privateConstructorUsedError;
  String get childDisplayName => throw _privateConstructorUsedError;
  OnboardingAgeBucket get ageBucket => throw _privateConstructorUsedError;
  int get approxMonths => throw _privateConstructorUsedError;
  String get currentStage => throw _privateConstructorUsedError;
  String get starterSpaceId => throw _privateConstructorUsedError;
  String get starterActivityId => throw _privateConstructorUsedError;
  String get starterPhraseId => throw _privateConstructorUsedError;
  List<String> get selectedSceneIds => throw _privateConstructorUsedError;
  OnboardingSupportGoal get supportGoal => throw _privateConstructorUsedError;
  String? get firstTraceEventKey => throw _privateConstructorUsedError;
  OnboardingConsentState get consentState => throw _privateConstructorUsedError;
  DateTime? get birthDate => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $OnboardingSnapshotCopyWith<OnboardingSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OnboardingSnapshotCopyWith<$Res> {
  factory $OnboardingSnapshotCopyWith(
          OnboardingSnapshot value, $Res Function(OnboardingSnapshot) then) =
      _$OnboardingSnapshotCopyWithImpl<$Res, OnboardingSnapshot>;
  @useResult
  $Res call(
      {int schemaVersion,
      String childDisplayName,
      OnboardingAgeBucket ageBucket,
      int approxMonths,
      String currentStage,
      String starterSpaceId,
      String starterActivityId,
      String starterPhraseId,
      List<String> selectedSceneIds,
      OnboardingSupportGoal supportGoal,
      String? firstTraceEventKey,
      OnboardingConsentState consentState,
      DateTime? birthDate,
      DateTime? completedAt});
}

/// @nodoc
class _$OnboardingSnapshotCopyWithImpl<$Res, $Val extends OnboardingSnapshot>
    implements $OnboardingSnapshotCopyWith<$Res> {
  _$OnboardingSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? childDisplayName = null,
    Object? ageBucket = null,
    Object? approxMonths = null,
    Object? currentStage = null,
    Object? starterSpaceId = null,
    Object? starterActivityId = null,
    Object? starterPhraseId = null,
    Object? selectedSceneIds = null,
    Object? supportGoal = null,
    Object? firstTraceEventKey = freezed,
    Object? consentState = null,
    Object? birthDate = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(_value.copyWith(
      schemaVersion: null == schemaVersion
          ? _value.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      childDisplayName: null == childDisplayName
          ? _value.childDisplayName
          : childDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      ageBucket: null == ageBucket
          ? _value.ageBucket
          : ageBucket // ignore: cast_nullable_to_non_nullable
              as OnboardingAgeBucket,
      approxMonths: null == approxMonths
          ? _value.approxMonths
          : approxMonths // ignore: cast_nullable_to_non_nullable
              as int,
      currentStage: null == currentStage
          ? _value.currentStage
          : currentStage // ignore: cast_nullable_to_non_nullable
              as String,
      starterSpaceId: null == starterSpaceId
          ? _value.starterSpaceId
          : starterSpaceId // ignore: cast_nullable_to_non_nullable
              as String,
      starterActivityId: null == starterActivityId
          ? _value.starterActivityId
          : starterActivityId // ignore: cast_nullable_to_non_nullable
              as String,
      starterPhraseId: null == starterPhraseId
          ? _value.starterPhraseId
          : starterPhraseId // ignore: cast_nullable_to_non_nullable
              as String,
      selectedSceneIds: null == selectedSceneIds
          ? _value.selectedSceneIds
          : selectedSceneIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      supportGoal: null == supportGoal
          ? _value.supportGoal
          : supportGoal // ignore: cast_nullable_to_non_nullable
              as OnboardingSupportGoal,
      firstTraceEventKey: freezed == firstTraceEventKey
          ? _value.firstTraceEventKey
          : firstTraceEventKey // ignore: cast_nullable_to_non_nullable
              as String?,
      consentState: null == consentState
          ? _value.consentState
          : consentState // ignore: cast_nullable_to_non_nullable
              as OnboardingConsentState,
      birthDate: freezed == birthDate
          ? _value.birthDate
          : birthDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OnboardingSnapshotImplCopyWith<$Res>
    implements $OnboardingSnapshotCopyWith<$Res> {
  factory _$$OnboardingSnapshotImplCopyWith(_$OnboardingSnapshotImpl value,
          $Res Function(_$OnboardingSnapshotImpl) then) =
      __$$OnboardingSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int schemaVersion,
      String childDisplayName,
      OnboardingAgeBucket ageBucket,
      int approxMonths,
      String currentStage,
      String starterSpaceId,
      String starterActivityId,
      String starterPhraseId,
      List<String> selectedSceneIds,
      OnboardingSupportGoal supportGoal,
      String? firstTraceEventKey,
      OnboardingConsentState consentState,
      DateTime? birthDate,
      DateTime? completedAt});
}

/// @nodoc
class __$$OnboardingSnapshotImplCopyWithImpl<$Res>
    extends _$OnboardingSnapshotCopyWithImpl<$Res, _$OnboardingSnapshotImpl>
    implements _$$OnboardingSnapshotImplCopyWith<$Res> {
  __$$OnboardingSnapshotImplCopyWithImpl(_$OnboardingSnapshotImpl _value,
      $Res Function(_$OnboardingSnapshotImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? childDisplayName = null,
    Object? ageBucket = null,
    Object? approxMonths = null,
    Object? currentStage = null,
    Object? starterSpaceId = null,
    Object? starterActivityId = null,
    Object? starterPhraseId = null,
    Object? selectedSceneIds = null,
    Object? supportGoal = null,
    Object? firstTraceEventKey = freezed,
    Object? consentState = null,
    Object? birthDate = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(_$OnboardingSnapshotImpl(
      schemaVersion: null == schemaVersion
          ? _value.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      childDisplayName: null == childDisplayName
          ? _value.childDisplayName
          : childDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      ageBucket: null == ageBucket
          ? _value.ageBucket
          : ageBucket // ignore: cast_nullable_to_non_nullable
              as OnboardingAgeBucket,
      approxMonths: null == approxMonths
          ? _value.approxMonths
          : approxMonths // ignore: cast_nullable_to_non_nullable
              as int,
      currentStage: null == currentStage
          ? _value.currentStage
          : currentStage // ignore: cast_nullable_to_non_nullable
              as String,
      starterSpaceId: null == starterSpaceId
          ? _value.starterSpaceId
          : starterSpaceId // ignore: cast_nullable_to_non_nullable
              as String,
      starterActivityId: null == starterActivityId
          ? _value.starterActivityId
          : starterActivityId // ignore: cast_nullable_to_non_nullable
              as String,
      starterPhraseId: null == starterPhraseId
          ? _value.starterPhraseId
          : starterPhraseId // ignore: cast_nullable_to_non_nullable
              as String,
      selectedSceneIds: null == selectedSceneIds
          ? _value._selectedSceneIds
          : selectedSceneIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      supportGoal: null == supportGoal
          ? _value.supportGoal
          : supportGoal // ignore: cast_nullable_to_non_nullable
              as OnboardingSupportGoal,
      firstTraceEventKey: freezed == firstTraceEventKey
          ? _value.firstTraceEventKey
          : firstTraceEventKey // ignore: cast_nullable_to_non_nullable
              as String?,
      consentState: null == consentState
          ? _value.consentState
          : consentState // ignore: cast_nullable_to_non_nullable
              as OnboardingConsentState,
      birthDate: freezed == birthDate
          ? _value.birthDate
          : birthDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$OnboardingSnapshotImpl extends _OnboardingSnapshot {
  const _$OnboardingSnapshotImpl(
      {this.schemaVersion = 1,
      required this.childDisplayName,
      required this.ageBucket,
      required this.approxMonths,
      required this.currentStage,
      required this.starterSpaceId,
      required this.starterActivityId,
      required this.starterPhraseId,
      final List<String> selectedSceneIds = const <String>[],
      this.supportGoal = OnboardingSupportGoal.firstWords,
      this.firstTraceEventKey,
      required this.consentState,
      this.birthDate,
      this.completedAt})
      : _selectedSceneIds = selectedSceneIds,
        super._();

  @override
  @JsonKey()
  final int schemaVersion;
  @override
  final String childDisplayName;
  @override
  final OnboardingAgeBucket ageBucket;
  @override
  final int approxMonths;
  @override
  final String currentStage;
  @override
  final String starterSpaceId;
  @override
  final String starterActivityId;
  @override
  final String starterPhraseId;
  final List<String> _selectedSceneIds;
  @override
  @JsonKey()
  List<String> get selectedSceneIds {
    if (_selectedSceneIds is EqualUnmodifiableListView)
      return _selectedSceneIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedSceneIds);
  }

  @override
  @JsonKey()
  final OnboardingSupportGoal supportGoal;
  @override
  final String? firstTraceEventKey;
  @override
  final OnboardingConsentState consentState;
  @override
  final DateTime? birthDate;
  @override
  final DateTime? completedAt;

  @override
  String toString() {
    return 'OnboardingSnapshot(schemaVersion: $schemaVersion, childDisplayName: $childDisplayName, ageBucket: $ageBucket, approxMonths: $approxMonths, currentStage: $currentStage, starterSpaceId: $starterSpaceId, starterActivityId: $starterActivityId, starterPhraseId: $starterPhraseId, selectedSceneIds: $selectedSceneIds, supportGoal: $supportGoal, firstTraceEventKey: $firstTraceEventKey, consentState: $consentState, birthDate: $birthDate, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OnboardingSnapshotImpl &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.childDisplayName, childDisplayName) ||
                other.childDisplayName == childDisplayName) &&
            (identical(other.ageBucket, ageBucket) ||
                other.ageBucket == ageBucket) &&
            (identical(other.approxMonths, approxMonths) ||
                other.approxMonths == approxMonths) &&
            (identical(other.currentStage, currentStage) ||
                other.currentStage == currentStage) &&
            (identical(other.starterSpaceId, starterSpaceId) ||
                other.starterSpaceId == starterSpaceId) &&
            (identical(other.starterActivityId, starterActivityId) ||
                other.starterActivityId == starterActivityId) &&
            (identical(other.starterPhraseId, starterPhraseId) ||
                other.starterPhraseId == starterPhraseId) &&
            const DeepCollectionEquality()
                .equals(other._selectedSceneIds, _selectedSceneIds) &&
            (identical(other.supportGoal, supportGoal) ||
                other.supportGoal == supportGoal) &&
            (identical(other.firstTraceEventKey, firstTraceEventKey) ||
                other.firstTraceEventKey == firstTraceEventKey) &&
            (identical(other.consentState, consentState) ||
                other.consentState == consentState) &&
            (identical(other.birthDate, birthDate) ||
                other.birthDate == birthDate) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      schemaVersion,
      childDisplayName,
      ageBucket,
      approxMonths,
      currentStage,
      starterSpaceId,
      starterActivityId,
      starterPhraseId,
      const DeepCollectionEquality().hash(_selectedSceneIds),
      supportGoal,
      firstTraceEventKey,
      consentState,
      birthDate,
      completedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OnboardingSnapshotImplCopyWith<_$OnboardingSnapshotImpl> get copyWith =>
      __$$OnboardingSnapshotImplCopyWithImpl<_$OnboardingSnapshotImpl>(
          this, _$identity);
}

abstract class _OnboardingSnapshot extends OnboardingSnapshot {
  const factory _OnboardingSnapshot(
      {final int schemaVersion,
      required final String childDisplayName,
      required final OnboardingAgeBucket ageBucket,
      required final int approxMonths,
      required final String currentStage,
      required final String starterSpaceId,
      required final String starterActivityId,
      required final String starterPhraseId,
      final List<String> selectedSceneIds,
      final OnboardingSupportGoal supportGoal,
      final String? firstTraceEventKey,
      required final OnboardingConsentState consentState,
      final DateTime? birthDate,
      final DateTime? completedAt}) = _$OnboardingSnapshotImpl;
  const _OnboardingSnapshot._() : super._();

  @override
  int get schemaVersion;
  @override
  String get childDisplayName;
  @override
  OnboardingAgeBucket get ageBucket;
  @override
  int get approxMonths;
  @override
  String get currentStage;
  @override
  String get starterSpaceId;
  @override
  String get starterActivityId;
  @override
  String get starterPhraseId;
  @override
  List<String> get selectedSceneIds;
  @override
  OnboardingSupportGoal get supportGoal;
  @override
  String? get firstTraceEventKey;
  @override
  OnboardingConsentState get consentState;
  @override
  DateTime? get birthDate;
  @override
  DateTime? get completedAt;
  @override
  @JsonKey(ignore: true)
  _$$OnboardingSnapshotImplCopyWith<_$OnboardingSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

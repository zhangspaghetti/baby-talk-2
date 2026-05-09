// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'household_invite_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HouseholdInviteLink {
  String get householdId => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  String get inviteUrl => throw _privateConstructorUsedError;
  HouseholdRole get role => throw _privateConstructorUsedError;
  String get source => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $HouseholdInviteLinkCopyWith<HouseholdInviteLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HouseholdInviteLinkCopyWith<$Res> {
  factory $HouseholdInviteLinkCopyWith(
          HouseholdInviteLink value, $Res Function(HouseholdInviteLink) then) =
      _$HouseholdInviteLinkCopyWithImpl<$Res, HouseholdInviteLink>;
  @useResult
  $Res call(
      {String householdId,
      String token,
      String inviteUrl,
      HouseholdRole role,
      String source,
      DateTime expiresAt});
}

/// @nodoc
class _$HouseholdInviteLinkCopyWithImpl<$Res, $Val extends HouseholdInviteLink>
    implements $HouseholdInviteLinkCopyWith<$Res> {
  _$HouseholdInviteLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? householdId = null,
    Object? token = null,
    Object? inviteUrl = null,
    Object? role = null,
    Object? source = null,
    Object? expiresAt = null,
  }) {
    return _then(_value.copyWith(
      householdId: null == householdId
          ? _value.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      inviteUrl: null == inviteUrl
          ? _value.inviteUrl
          : inviteUrl // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as HouseholdRole,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HouseholdInviteLinkImplCopyWith<$Res>
    implements $HouseholdInviteLinkCopyWith<$Res> {
  factory _$$HouseholdInviteLinkImplCopyWith(_$HouseholdInviteLinkImpl value,
          $Res Function(_$HouseholdInviteLinkImpl) then) =
      __$$HouseholdInviteLinkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String householdId,
      String token,
      String inviteUrl,
      HouseholdRole role,
      String source,
      DateTime expiresAt});
}

/// @nodoc
class __$$HouseholdInviteLinkImplCopyWithImpl<$Res>
    extends _$HouseholdInviteLinkCopyWithImpl<$Res, _$HouseholdInviteLinkImpl>
    implements _$$HouseholdInviteLinkImplCopyWith<$Res> {
  __$$HouseholdInviteLinkImplCopyWithImpl(_$HouseholdInviteLinkImpl _value,
      $Res Function(_$HouseholdInviteLinkImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? householdId = null,
    Object? token = null,
    Object? inviteUrl = null,
    Object? role = null,
    Object? source = null,
    Object? expiresAt = null,
  }) {
    return _then(_$HouseholdInviteLinkImpl(
      householdId: null == householdId
          ? _value.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      inviteUrl: null == inviteUrl
          ? _value.inviteUrl
          : inviteUrl // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as HouseholdRole,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class _$HouseholdInviteLinkImpl extends _HouseholdInviteLink {
  const _$HouseholdInviteLinkImpl(
      {required this.householdId,
      required this.token,
      required this.inviteUrl,
      required this.role,
      required this.source,
      required this.expiresAt})
      : super._();

  @override
  final String householdId;
  @override
  final String token;
  @override
  final String inviteUrl;
  @override
  final HouseholdRole role;
  @override
  final String source;
  @override
  final DateTime expiresAt;

  @override
  String toString() {
    return 'HouseholdInviteLink(householdId: $householdId, token: $token, inviteUrl: $inviteUrl, role: $role, source: $source, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HouseholdInviteLinkImpl &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.inviteUrl, inviteUrl) ||
                other.inviteUrl == inviteUrl) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, householdId, token, inviteUrl, role, source, expiresAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HouseholdInviteLinkImplCopyWith<_$HouseholdInviteLinkImpl> get copyWith =>
      __$$HouseholdInviteLinkImplCopyWithImpl<_$HouseholdInviteLinkImpl>(
          this, _$identity);
}

abstract class _HouseholdInviteLink extends HouseholdInviteLink {
  const factory _HouseholdInviteLink(
      {required final String householdId,
      required final String token,
      required final String inviteUrl,
      required final HouseholdRole role,
      required final String source,
      required final DateTime expiresAt}) = _$HouseholdInviteLinkImpl;
  const _HouseholdInviteLink._() : super._();

  @override
  String get householdId;
  @override
  String get token;
  @override
  String get inviteUrl;
  @override
  HouseholdRole get role;
  @override
  String get source;
  @override
  DateTime get expiresAt;
  @override
  @JsonKey(ignore: true)
  _$$HouseholdInviteLinkImplCopyWith<_$HouseholdInviteLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

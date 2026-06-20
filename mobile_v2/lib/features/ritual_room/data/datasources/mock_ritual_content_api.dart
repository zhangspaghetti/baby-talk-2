import 'dart:convert';

import 'package:flutter/services.dart';

import '../dto/ritual_room_response.dart';
import 'ritual_content_api.dart';

/// Asset-backed asynchronous implementation of the stable content API.
final class MockRitualContentApi implements RitualContentApi {
  MockRitualContentApi({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const _supportedRoomId = 'shoes_on_room_v1';
  static const _fixturePath = 'assets/fixtures/ritual_rooms/shoes_on.json';

  final AssetBundle _assetBundle;

  @override
  Future<RitualRoomResponse> fetchRoom(String ritualRoomId) async {
    if (ritualRoomId != _supportedRoomId) {
      throw ArgumentError.value(
        ritualRoomId,
        'ritualRoomId',
        'unsupported ritual room',
      );
    }

    final raw = await _assetBundle.loadString(_fixturePath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('ritual room fixture must be an object');
    }
    final response = RitualRoomResponse.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (response.ritualRoomId != ritualRoomId) {
      throw const FormatException('fixture ritual identity mismatch');
    }
    return response;
  }
}

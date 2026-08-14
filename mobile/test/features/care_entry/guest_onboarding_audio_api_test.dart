import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_audio_api.dart';

void main() {
  test(
    'sends capability only in protected header and plays exact bytes',
    () async {
      final vault = GuestAudioCapabilityVault()
        ..register(
          conversationId: 'onbc_1',
          utteranceId: 'utterance-1',
          capability: 'secret-capability',
          expiresAt: DateTime.utc(2026, 8, 15),
        );
      final output = _RecordingOutput();
      final api = GuestOnboardingAudioApi(
        dio: _mockDio((options) async {
          expect(
            options.path,
            '/api/v1/onboarding/conversations/onbc_1/utterances/utterance-1/audio',
          );
          expect(options.uri.query, isEmpty);
          expect(
            options.headers['X-Onboarding-Audio-Capability'],
            'secret-capability',
          );
          expect(options.headers['X-App-Version'], '1.2.0');
          return Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            headers: Headers.fromMap(<String, List<String>>{
              Headers.contentTypeHeader: <String>['audio/mpeg'],
            }),
            data: <int>[1, 2, 3],
          );
        }),
        capabilities: vault,
        output: output,
        clock: () => DateTime.utc(2026, 8, 14),
      );
      addTearDown(api.dispose);

      await api.play(conversationId: 'onbc_1', utteranceId: 'utterance-1');

      expect(output.played, <List<int>>[
        <int>[1, 2, 3],
      ]);
    },
  );

  test('a newer play cancels stale response publication', () async {
    final firstResponse = Completer<Response<dynamic>>();
    final seenOptions = <RequestOptions>[];
    final vault = GuestAudioCapabilityVault()
      ..register(
        conversationId: 'onbc_1',
        utteranceId: 'utterance-1',
        capability: 'capability-1',
        expiresAt: DateTime.utc(2026, 8, 15),
      )
      ..register(
        conversationId: 'onbc_1',
        utteranceId: 'utterance-2',
        capability: 'capability-2',
        expiresAt: DateTime.utc(2026, 8, 15),
      );
    final output = _RecordingOutput();
    final api = GuestOnboardingAudioApi(
      dio: _mockDio((options) async {
        seenOptions.add(options);
        if (options.path.endsWith('utterance-1/audio')) {
          return firstResponse.future;
        }
        return _audioResponse(options, <int>[2]);
      }),
      capabilities: vault,
      output: output,
      clock: () => DateTime.utc(2026, 8, 14),
    );
    addTearDown(api.dispose);

    final first = api.play(
      conversationId: 'onbc_1',
      utteranceId: 'utterance-1',
    );
    await Future<void>.delayed(Duration.zero);
    await api.play(conversationId: 'onbc_1', utteranceId: 'utterance-2');
    firstResponse.complete(_audioResponse(seenOptions.first, <int>[1]));
    await first;

    expect(output.played, <List<int>>[
      <int>[2],
    ]);
  });

  test(
    'a newer play cannot be overwritten by stale output publication',
    () async {
      final vault = GuestAudioCapabilityVault()
        ..register(
          conversationId: 'onbc_1',
          utteranceId: 'utterance-1',
          capability: 'capability-1',
          expiresAt: DateTime.utc(2026, 8, 15),
        )
        ..register(
          conversationId: 'onbc_1',
          utteranceId: 'utterance-2',
          capability: 'capability-2',
          expiresAt: DateTime.utc(2026, 8, 15),
        );
      final output = _BlockingOutput();
      final api = GuestOnboardingAudioApi(
        dio: _mockDio(
          (options) async => _audioResponse(options, <int>[
            options.path.endsWith('utterance-1/audio') ? 1 : 2,
          ]),
        ),
        capabilities: vault,
        output: output,
        clock: () => DateTime.utc(2026, 8, 14),
      );
      addTearDown(api.dispose);

      final first = api.play(
        conversationId: 'onbc_1',
        utteranceId: 'utterance-1',
      );
      await output.firstPlayStarted.future;
      final second = api.play(
        conversationId: 'onbc_1',
        utteranceId: 'utterance-2',
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      output.releaseFirstPlay.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(output.played, <List<int>>[
        <int>[1],
        <int>[2],
      ]);
      expect(output.activeBytes, <int>[2]);
    },
  );

  test('output failure does not poison later stop or playback', () async {
    final vault = GuestAudioCapabilityVault()
      ..register(
        conversationId: 'onbc_1',
        utteranceId: 'utterance-1',
        capability: 'capability-1',
        expiresAt: DateTime.utc(2026, 8, 15),
      )
      ..register(
        conversationId: 'onbc_1',
        utteranceId: 'utterance-2',
        capability: 'capability-2',
        expiresAt: DateTime.utc(2026, 8, 15),
      );
    final output = _FailOnceOutput();
    final api = GuestOnboardingAudioApi(
      dio: _mockDio((options) async => _audioResponse(options, <int>[2])),
      capabilities: vault,
      output: output,
      clock: () => DateTime.utc(2026, 8, 14),
    );
    addTearDown(api.dispose);

    await expectLater(
      api.play(conversationId: 'onbc_1', utteranceId: 'utterance-1'),
      throwsStateError,
    );
    await api.stop().timeout(const Duration(seconds: 1));
    await api
        .play(conversationId: 'onbc_1', utteranceId: 'utterance-2')
        .timeout(const Duration(seconds: 1));

    expect(output.successfulPlays, 1);
  });
}

Response<dynamic> _audioResponse(RequestOptions options, List<int> bytes) =>
    Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      headers: Headers.fromMap(<String, List<String>>{
        Headers.contentTypeHeader: <String>['audio/mpeg'],
      }),
      data: bytes,
    );

Dio _mockDio(Future<Response<dynamic>> Function(RequestOptions) handler) => Dio(
  BaseOptions(baseUrl: 'http://localhost:8080', validateStatus: (_) => true),
)..interceptors.add(_MockInterceptor(handler));

final class _MockInterceptor extends Interceptor {
  _MockInterceptor(this.handler);
  final Future<Response<dynamic>> Function(RequestOptions) handler;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler next) async {
    next.resolve(await handler(options));
  }
}

final class _RecordingOutput implements GuestAudioOutput {
  final List<List<int>> played = <List<int>>[];

  @override
  Future<void> playBytes(List<int> bytes, String mimeType) async {
    played.add(List<int>.from(bytes));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _BlockingOutput implements GuestAudioOutput {
  final Completer<void> firstPlayStarted = Completer<void>();
  final Completer<void> releaseFirstPlay = Completer<void>();
  final List<List<int>> played = <List<int>>[];
  List<int>? activeBytes;

  @override
  Future<void> playBytes(List<int> bytes, String mimeType) async {
    played.add(List<int>.from(bytes));
    if (bytes.single == 1) {
      firstPlayStarted.complete();
      await releaseFirstPlay.future;
    }
    activeBytes = List<int>.from(bytes);
  }

  @override
  Future<void> stop() async {
    activeBytes = null;
  }

  @override
  Future<void> dispose() async {}
}

final class _FailOnceOutput implements GuestAudioOutput {
  bool _shouldFail = true;
  int successfulPlays = 0;

  @override
  Future<void> playBytes(List<int> bytes, String mimeType) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('simulated output failure');
    }
    successfulPlays += 1;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

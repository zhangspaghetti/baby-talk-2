import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('离线练习后登录同步，退出再登录仍能恢复 recent result', (WidgetTester tester) async {
    final backend = await _InMemoryAccountBackend.start();
    addTearDown(() async {
      await backend.dispose();
    });

    final bootState = await AppBootState.load(rootBundle);
    expect(bootState.isReady, isTrue);

    final tempDir = await Directory.systemTemp.createTemp(
      's03_account_sync_restore_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const dbName = 's03_account_sync_restore';
    final completedSnapshot = OnboardingSnapshot(
      childDisplayName: '米米',
      ageBucket: OnboardingAgeBucket.twelveToEighteen,
      approxMonths: 15,
      currentStage: 'gesture_plus_words',
      starterSpaceId: 'daily_care',
      starterActivityId: 'bath_time',
      starterPhraseId: 'bath_time_warm_water',
      consentState: OnboardingConsentState.localOnly,
      completedAt: DateTime.utc(2026, 4, 9, 8),
    );

    final firstRepository = await _openRepository(
      assetPhraseService: bootState.assetPhraseService!,
      directory: tempDir,
      dbName: dbName,
    );

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => firstRepository,
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(directoryResolver: () async => directory),
            practiceRepository: practiceRepository,
            apiService: AccountApiService(baseUri: backend.baseUri),
            connectivityChecker: () async => true,
          );
        },
        appDirectoryResolver: () async => tempDir,
        completedSnapshotLoader: () async => completedSnapshot,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

    await _scrollHomeTo(tester, find.byKey(const Key('home-start-practice')));
    await tester.tap(find.byKey(const Key('home-start-practice')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
    );

    await tester.tap(
      find.byKey(const Key('reaction-bath_time_warm_water-engaged')),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
    );

    final secondReaction = find.byKey(
      const Key('reaction-bath_time_splash_splash-imitated'),
    );
    await _scrollTo(tester, secondReaction);
    await tester.tap(secondReaction);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
    );

    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-calm'),
    );
    await _scrollTo(tester, thirdReaction);
    await tester.tap(thirdReaction);
    await _pumpUntilFound(tester, find.byKey(const Key('recent-result-summary')));

    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);

    await _scrollHomeTo(tester, find.byKey(const Key('home-account-open-entry')));
    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await _pumpUntilFound(tester, find.byKey(const Key('account-entry-surface')));

    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      '246810',
    );
    await tester.tap(find.byKey(const Key('account-submit-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 12),
    );

    expect(find.byKey(const Key('account-status-signed-in-synced')), findsOneWidget);
    expect(find.textContaining('登录已完成'), findsWidgets);
    expect(backend.bootstrapCount, 1);
    expect(backend.storedEventCount(_openRepositoryInstallationId), 3);

    await tester.tap(find.byKey(const Key('account-clear-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-out')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await firstRepository.close();

    final secondRepository = await _openRepository(
      assetPhraseService: bootState.assetPhraseService!,
      directory: tempDir,
      dbName: dbName,
    );
    addTearDown(() async {
      await secondRepository.close();
    });

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => secondRepository,
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(directoryResolver: () async => directory),
            practiceRepository: practiceRepository,
            apiService: AccountApiService(baseUri: backend.baseUri),
            connectivityChecker: () async => true,
          );
        },
        appDirectoryResolver: () async => tempDir,
        completedSnapshotLoader: () async => completedSnapshot,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);

    await _scrollHomeTo(tester, find.byKey(const Key('home-account-open-entry')));
    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await _pumpUntilFound(tester, find.byKey(const Key('account-entry-surface')));
    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      '246810',
    );
    await tester.tap(find.byKey(const Key('account-submit-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 12),
    );

    expect(backend.bootstrapCount, 2);
    expect(backend.storedEventCount(_openRepositoryInstallationId), 3);
    await tester.tap(find.byKey(const Key('account-close-button')));
    await tester.pumpAndSettle();
    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('已同步 3'), findsOneWidget);
  });
}

const _openRepositoryInstallationId = 'install_s03_integration_test';

Future<PracticeRepository> _openRepository({
  required AssetPhraseService assetPhraseService,
  required Directory directory,
  required String dbName,
}) async {
  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
    name: dbName,
  );
  return PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
      idGenerator: () => _openRepositoryInstallationId,
    ),
  );
}

Finder _homeScrollable() {
  return find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byType(Scrollable),
  );
}

Future<void> _scrollHomeTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180, scrollable: _homeScrollable());
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 8),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

class _InMemoryAccountBackend {
  _InMemoryAccountBackend._(this._server)
    : baseUri = Uri.parse(
        'http://${_server.address.address}:${_server.port}',
      ) {
    _subscription = _server.listen((request) async {
      await _handle(request);
    });
  }

  final HttpServer _server;
  late final StreamSubscription<HttpRequest> _subscription;
  final Uri baseUri;

  int _challengeCount = 0;
  int _sessionCount = 0;
  int bootstrapCount = 0;
  final Map<String, String> _challengePhoneById = {};
  final Map<String, String> _sessionAccountById = {};
  final Map<String, String> _sessionInstallationById = {};
  final Map<String, String> _consentStatusByAccountId = {'acct_1': 'signed_out'};
  final Map<String, List<Map<String, Object?>>> _eventsByInstallation = {};
  final Map<String, Set<String>> _eventKeysByInstallation = {};

  static Future<_InMemoryAccountBackend> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _InMemoryAccountBackend._(server);
  }

  int storedEventCount(String installationId) {
    return _eventsByInstallation[installationId]?.length ?? 0;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    try {
      if (request.method == 'POST' && path == '/api/v1/auth/challenges') {
        final body = await _readJsonBody(request);
        final phoneNumber = (body['phoneNumber'] as String?) ?? '13800138000';
        final challengeId = 'challenge_${++_challengeCount}';
        _challengePhoneById[challengeId] = phoneNumber;
        await _writeJson(
          request.response,
          HttpStatus.created,
          {
            'challengeId': challengeId,
            'maskedPhoneNumber': '138****8000',
            'codeLength': 6,
            'expiresAt': DateTime.utc(2026, 4, 9, 10).toIso8601String(),
          },
        );
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/auth/verify') {
        final body = await _readJsonBody(request);
        final challengeId = body['challengeId'] as String?;
        final verificationCode = body['verificationCode'] as String?;
        final installationId = body['installationId'] as String?;
        if (challengeId == null ||
            !_challengePhoneById.containsKey(challengeId) ||
            verificationCode != '246810' ||
            installationId == null) {
          await _writeJson(request.response, HttpStatus.badRequest, {
            'code': 'verification_failed',
            'message': 'challenge 或验证码非法。',
          });
          return;
        }

        final sessionId = 'sess_${++_sessionCount}';
        _sessionAccountById[sessionId] = 'acct_1';
        _sessionInstallationById[sessionId] = installationId;
        await _writeJson(request.response, HttpStatus.ok, {
          'accountId': 'acct_1',
          'sessionId': sessionId,
          'maskedPhoneNumber': '138****8000',
          'createdAt': DateTime.utc(2026, 4, 9, 10, _sessionCount).toIso8601String(),
          'consentStatus': _consentStatusByAccountId['acct_1'] ?? 'signed_out',
        });
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/consent/accept') {
        final sessionId = request.headers.value('X-Session-Id');
        final accountId = _sessionAccountById[sessionId];
        if (accountId == null) {
          await _writeJson(request.response, HttpStatus.unauthorized, {
            'code': 'invalid_session',
            'message': 'session 不存在。',
          });
          return;
        }
        _consentStatusByAccountId[accountId] = 'accepted';
        await _writeJson(request.response, HttpStatus.ok, {
          'applied': true,
          'result': 'applied',
          'consentStatus': 'accepted',
          'updatedAt': DateTime.utc(2026, 4, 9, 10, 5).toIso8601String(),
        });
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/bootstrap') {
        bootstrapCount += 1;
        final sessionId = request.headers.value('X-Session-Id');
        final accountId = _sessionAccountById[sessionId];
        final installationId = request.uri.queryParameters['installationId'];
        if (accountId == null || installationId == null) {
          await _writeJson(request.response, HttpStatus.unauthorized, {
            'code': 'invalid_session',
            'message': 'session 不存在。',
          });
          return;
        }
        if ((_consentStatusByAccountId[accountId] ?? 'signed_out') != 'accepted') {
          await _writeJson(request.response, HttpStatus.conflict, {
            'code': 'consent_required',
            'message': '尚未完成同意。',
          });
          return;
        }
        final events = List<Map<String, Object?>>.from(
          _eventsByInstallation[installationId] ?? const [],
        );
        await _writeJson(request.response, HttpStatus.ok, {
          'accountId': accountId,
          'sessionId': sessionId,
          'installationId': installationId,
          'consentStatus': 'accepted',
          'eventCount': events.length,
          'events': events,
          'bootstrapAt': DateTime.utc(2026, 4, 9, 10, 6, bootstrapCount)
              .toIso8601String(),
        });
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/sync/events') {
        final sessionId = request.headers.value('X-Session-Id');
        final accountId = _sessionAccountById[sessionId];
        final installationFromSession = _sessionInstallationById[sessionId];
        final body = await _readJsonBody(request);
        final installationId = body['installationId'] as String?;
        final rawEvents = body['events'] as List<Object?>? ?? const [];
        if (accountId == null ||
            installationId == null ||
            installationId != installationFromSession) {
          await _writeJson(request.response, HttpStatus.unauthorized, {
            'code': 'invalid_session',
            'message': 'session 或 installationId 非法。',
          });
          return;
        }
        final acceptedEventKeys = <String>[];
        final duplicateEventKeys = <String>[];
        final storedEvents = _eventsByInstallation.putIfAbsent(
          installationId,
          () => <Map<String, Object?>>[],
        );
        final seenKeys = _eventKeysByInstallation.putIfAbsent(
          installationId,
          () => <String>{},
        );
        for (final rawEvent in rawEvents) {
          final event = Map<String, Object?>.from(rawEvent as Map);
          final eventKey = event['eventKey'] as String;
          if (!seenKeys.add(eventKey)) {
            duplicateEventKeys.add(eventKey);
            continue;
          }
          storedEvents.add({
            'eventKey': eventKey,
            'localEventId': event['localEventId'],
            'installationId': event['installationId'],
            'spaceId': event['spaceId'],
            'activityId': event['activityId'],
            'phraseId': event['phraseId'],
            'reactionType': event['reactionType'],
            'clientTimestamp': event['clientTimestamp'],
            'receivedAt': DateTime.utc(2026, 4, 9, 10, 7, storedEvents.length)
                .toIso8601String(),
          });
          acceptedEventKeys.add(eventKey);
        }
        await _writeJson(request.response, HttpStatus.ok, {
          'receivedCount': rawEvents.length,
          'acceptedCount': acceptedEventKeys.length,
          'duplicateCount': duplicateEventKeys.length,
          'acceptedEventKeys': acceptedEventKeys,
          'duplicateEventKeys': duplicateEventKeys,
          'syncedAt': DateTime.utc(2026, 4, 9, 10, 8).toIso8601String(),
        });
        return;
      }

      await _writeJson(request.response, HttpStatus.notFound, {
        'code': 'not_found',
        'message': 'unsupported route',
      });
    } catch (error) {
      await _writeJson(request.response, HttpStatus.internalServerError, {
        'code': 'test_backend_error',
        'message': '$error',
      });
    }
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> json,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(json));
    await response.close();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';
import 'package:mobile/features/garden/presentation/garden_fertilizer_notifier.dart';
import 'package:mobile/features/garden/presentation/widgets/garden_fertilizer_panel.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';

void main() {
  Future<void> pump(WidgetTester tester, _FertilizerNotifierStub stub) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gardenFertilizerNotifierProvider.overrideWith((ref) => stub),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: GardenFertilizerPanel()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders loading shimmer when view is loading', (tester) async {
    final stub = _FertilizerNotifierStub(
      const GardenFertilizerViewState.loading(),
    );
    await pump(tester, stub);

    expect(find.byKey(const Key('garden-fertilizer-loading')), findsOneWidget);
    expect(find.byKey(const Key('garden-fertilizer-panel')), findsNothing);
  });

  testWidgets('renders empty state when there are no packs', (tester) async {
    final stub = _FertilizerNotifierStub(
      GardenFertilizerViewState(
        isLoading: false,
        pendingPacks: const [],
        claimedPacks: const [],
        backpackCount: 0,
        stageInfo: resolveFertilizerStage(0),
      ),
    );
    await pump(tester, stub);

    expect(find.byKey(const Key('garden-fertilizer-panel')), findsOneWidget);
    expect(find.byKey(const Key('garden-fertilizer-empty')), findsOneWidget);
    expect(
      find.byKey(const Key('garden-fertilizer-stage-label')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('garden-fertilizer-progress')), findsOneWidget);
  });

  testWidgets('renders pending pack and claim button invokes claim', (
    tester,
  ) async {
    final stub = _FertilizerNotifierStub(
      GardenFertilizerViewState(
        isLoading: false,
        pendingPacks: [
          FertilizerPack(
            eventKey: 'evt-1',
            title: '说了 hello',
            detail: '配合了 hello。',
            occurredAt: DateTime(2026, 6, 1, 9, 30),
            claimed: false,
          ),
        ],
        claimedPacks: const [],
        backpackCount: 0,
        stageInfo: resolveFertilizerStage(0),
      ),
    );
    await pump(tester, stub);

    final claimButton = find.byKey(
      const Key('garden-fertilizer-pending-evt-1'),
    );
    expect(claimButton, findsOneWidget);

    await tester.tap(
      find.descendant(of: claimButton, matching: find.byType(OutlinedButton)),
    );
    await tester.pump();

    expect(stub.claimedKeys, ['evt-1']);
  });

  testWidgets('apply button is enabled with backpack and invokes apply', (
    tester,
  ) async {
    final stub = _FertilizerNotifierStub(
      GardenFertilizerViewState(
        isLoading: false,
        pendingPacks: const [],
        claimedPacks: [
          FertilizerPack(
            eventKey: 'evt-1',
            title: '说了 hello',
            detail: '配合了 hello。',
            occurredAt: DateTime(2026, 6, 1, 9, 30),
            claimed: true,
          ),
        ],
        backpackCount: 2,
        stageInfo: resolveFertilizerStage(0),
      ),
    );
    await pump(tester, stub);

    expect(
      find.byKey(const Key('garden-fertilizer-backpack-count')),
      findsOneWidget,
    );
    final applyButton = find.byKey(const Key('garden-fertilizer-apply-button'));
    expect(applyButton, findsOneWidget);

    await tester.tap(applyButton);
    await tester.pump();

    expect(stub.applyCount, 1);
  });

  testWidgets('apply button is disabled when backpack is empty', (
    tester,
  ) async {
    final stub = _FertilizerNotifierStub(
      GardenFertilizerViewState(
        isLoading: false,
        pendingPacks: [
          FertilizerPack(
            eventKey: 'evt-1',
            title: '说了 hello',
            detail: '配合了 hello。',
            occurredAt: DateTime(2026, 6, 1, 9, 30),
            claimed: false,
          ),
        ],
        claimedPacks: const [],
        backpackCount: 0,
        stageInfo: resolveFertilizerStage(0),
      ),
    );
    await pump(tester, stub);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('garden-fertilizer-apply-button')),
    );
    expect(button.onPressed, isNull);
  });
}

class _FertilizerNotifierStub extends GardenFertilizerNotifier {
  _FertilizerNotifierStub(this._view)
    : super(
        repositoryFuture: Completer<GardenFertilizerRepository>().future,
        growthNotifier: _GrowthStub(),
      );

  final GardenFertilizerViewState _view;
  final List<String> claimedKeys = [];
  int applyCount = 0;

  @override
  GardenFertilizerViewState get view => _view;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> claim(String eventKey) async {
    claimedKeys.add(eventKey);
  }

  @override
  Future<void> apply() async {
    applyCount += 1;
  }
}

class _GrowthStub extends GardenGrowthNotifier {
  _GrowthStub() : super(repository: _GrowthRepoFake());

  @override
  GardenGrowthSnapshot get snapshot => GardenGrowthSnapshot.empty();

  @override
  GardenGrowthLoadStatus get status => GardenGrowthLoadStatus.ready;
}

class _GrowthRepoFake implements GardenGrowthRepository {
  @override
  Future<GardenGrowthSnapshot> buildSnapshot() async =>
      GardenGrowthSnapshot.empty();
}

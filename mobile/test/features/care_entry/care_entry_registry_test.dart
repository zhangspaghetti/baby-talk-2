import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/data/bundled_care_entry_registry.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'onboarding.primary resolves four ordered safe entries and recommends bedtime in the evening',
    () async {
      final registry = BundledCareEntryRegistry(bundle: rootBundle);

      final result = await registry.resolve(
        placement: const CareEntryPlacementId('onboarding.primary'),
        visibleSlots: 4,
        localTime: DateTime(2026, 8, 14, 20),
      );

      expect(result.entries.map((entry) => entry.id.value), <String>[
        'care.bedtime_soothing',
        'care.feeding_now',
        'care.post_cry_soothing',
        'care.diaper_change',
      ]);
      expect(result.recommendedEntryId?.value, 'care.bedtime_soothing');
      expect(
        result.entries.where((entry) => entry.isRecommended),
        hasLength(1),
      );

      for (final entry in result.entries) {
        expect(entry.seed.firstUtterance.english, isNotEmpty);
        expect(entry.seed.firstUtterance.chinese, isNotEmpty);
        expect(entry.seed.firstUtterance.pronunciation, isNotEmpty);
        expect(
          entry.seed.firstUtterance.audioAsset,
          startsWith('assets/audio/phrases/'),
        );
        expect(entry.seed.firstUtterance.audioReview, AudioReview.reviewed);
        expect(
          entry.seed.nextSupports.byReaction.keys,
          containsAll(CareReaction.values),
        );
        final supportIds = <CareSupportId>{
          entry.seed.nextSupports.whenAbsent.id,
          ...entry.seed.nextSupports.byReaction.values.map(
            (support) => support.id,
          ),
        };
        expect(supportIds, hasLength(CareReaction.values.length + 1));
        for (final support in <CareNextSupportUtterance>[
          entry.seed.nextSupports.whenAbsent,
          ...entry.seed.nextSupports.byReaction.values,
        ]) {
          expect(support.english, isNotEmpty);
          expect(support.chinese, isNotEmpty);
        }

        expect(entry.id.value, isNot(entry.seed.generationRef.id.value));
        expect(entry.id.value, isNot(entry.seed.fallback.id.value));
        expect(entry.id.toString(), isNot(entry.id.value));
        expect(
          entry.seed.generationRef.id.toString(),
          isNot(entry.seed.generationRef.id.value),
        );
        expect(
          entry.seed.fallback.id.toString(),
          isNot(entry.seed.fallback.id.value),
        );
      }
      expect(
        result.entries
            .map(
              (entry) => entry.seed.nextSupports
                  .resolve(CareReaction.hesitant)
                  .english,
            )
            .toSet(),
        hasLength(4),
      );
    },
  );

  test(
    'invalid optional manifest entry is isolated and replaced by a safe default',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/content/care_entry_registry.json',
                ),
              )
              as Map<String, dynamic>;
      final entries = manifest['entries'] as List<dynamic>;
      entries.add(<String, dynamic>{
        'id': 'care.invalid_optional',
        'optional': true,
        'placement': 'onboarding.primary',
        'order': 3,
        'title': '损坏入口',
      });
      final collection =
          (manifest['collections'] as List<dynamic>).single
              as Map<String, dynamic>;
      (collection['entryIds'] as List<dynamic>)[2] = 'care.invalid_optional';
      final bundle = _ManifestOverrideBundle(jsonEncode(manifest));

      final result = await BundledCareEntryRegistry(bundle: bundle).resolve(
        placement: const CareEntryPlacementId('onboarding.primary'),
        visibleSlots: 4,
        localTime: DateTime(2026, 8, 14, 13),
      );

      expect(result.entries, hasLength(4));
      expect(
        result.entries.map((entry) => entry.id.value),
        containsAll(<String>[
          'care.bedtime_soothing',
          'care.feeding_now',
          'care.post_cry_soothing',
          'care.diaper_change',
        ]),
      );
      expect(result.recommendedEntryId?.value, 'care.diaper_change');
    },
  );

  test(
    'a browse-only scene needs only manifest data and a catalog fallback',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/content/care_entry_registry.json',
                ),
              )
              as Map<String, dynamic>;
      final sourceEntry = Map<String, dynamic>.from(
        (manifest['entries'] as List<dynamic>).first as Map<String, dynamic>,
      );
      sourceEntry
        ..['id'] = 'care.browse_extra'
        ..['placement'] = 'browse.primary'
        ..['order'] = 1
        ..['visualToken'] = 'route.browse_extra'
        ..['recommendationHours'] = <int>[]
        ..['generation'] = <String, dynamic>{
          'id': 'generation.browse_extra',
          'schemaVersion': 1,
          'sceneType': 'browse_extra',
          'parentTonePreference': 'short_gentle',
        };
      (manifest['entries'] as List<dynamic>).add(sourceEntry);
      (manifest['collections'] as List<dynamic>).add(<String, dynamic>{
        'placement': 'browse.primary',
        'visibleSlots': 1,
        'entryIds': <String>['care.browse_extra'],
        'safeDefaultEntryIds': <String>['care.browse_extra'],
      });

      final result =
          await BundledCareEntryRegistry(
            bundle: _ManifestOverrideBundle(jsonEncode(manifest)),
          ).resolve(
            placement: const CareEntryPlacementId('browse.primary'),
            visibleSlots: 1,
            localTime: DateTime(2026, 8, 14, 12),
          );

      expect(result.entries.single.id.value, 'care.browse_extra');
      expect(result.entries.single.visualToken, 'route.browse_extra');
      expect(
        result.entries.single.seed.firstUtterance.english,
        'Time to sleep.',
      );
    },
  );
}

final class _ManifestOverrideBundle extends CachingAssetBundle {
  _ManifestOverrideBundle(this.manifest);

  final String manifest;

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key == 'assets/content/care_entry_registry.json') {
      return Future<String>.value(manifest);
    }
    return rootBundle.loadString(key, cache: cache);
  }
}

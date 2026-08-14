import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/care_entry/data/bundled_care_entry_registry.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_selection_controller.dart';

final careEntryRegistryProvider = Provider<CareEntryRegistry>((ref) {
  return BundledCareEntryRegistry(bundle: rootBundle);
});

final careEntrySelectionControllerProvider =
    ChangeNotifierProvider.autoDispose<CareEntrySelectionController>((ref) {
      final controller = CareEntrySelectionController(
        registry: ref.watch(careEntryRegistryProvider),
      );
      unawaited(controller.initialize(localTime: DateTime.now()));
      return controller;
    });

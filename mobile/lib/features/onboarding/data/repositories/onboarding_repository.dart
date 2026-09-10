import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';

class OnboardingRepository {
  OnboardingRepository({required OnboardingSnapshotStore snapshotStore})
    : _snapshotStore = snapshotStore;

  final OnboardingSnapshotStore _snapshotStore;

  Future<OnboardingSnapshot?> readSnapshot() async {
    try {
      return await _snapshotStore.read();
    } on FormatException {
      await _snapshotStore.deleteIfExists();
      return null;
    }
  }

  Future<OnboardingSnapshot?> readCompletedSnapshot() async {
    final snapshot = await readSnapshot();
    if (snapshot == null || !snapshot.isCompleted) {
      return null;
    }
    return snapshot;
  }

  Future<void> clearAllLocalState() => _snapshotStore.deleteAllArtifacts();

  Future<OnboardingSnapshot> saveSnapshot(OnboardingSnapshot snapshot) async {
    await _snapshotStore.write(snapshot);
    return snapshot;
  }

  Future<void> clearSnapshot() {
    return _snapshotStore.deleteIfExists();
  }
}

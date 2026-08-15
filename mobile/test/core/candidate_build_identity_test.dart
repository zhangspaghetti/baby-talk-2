import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/runtime/candidate_build_identity.dart';

void main() {
  test(
    'candidate identity always labels both APK build and frozen candidate',
    () {
      const identity = CandidateBuildIdentity(
        appVersion: '1.4.0+17',
        candidateId: 'btqa-2026-08-15',
      );

      expect(identity.appVersion, '1.4.0+17');
      expect(identity.candidateId, 'btqa-2026-08-15');
      expect(identity.supportLabel, '1.4.0+17 · btqa-2026-08-15');
    },
  );
}

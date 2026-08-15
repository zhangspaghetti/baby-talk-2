/// Immutable build identity supplied when the APK is assembled for a candidate.
class CandidateBuildIdentity {
  const CandidateBuildIdentity({
    required this.appVersion,
    required this.candidateId,
  });

  static const current = CandidateBuildIdentity(
    appVersion: String.fromEnvironment(
      'BABY_TALK_BUILD_VERSION',
      defaultValue: '未标记构建',
    ),
    candidateId: String.fromEnvironment(
      'BABY_TALK_CANDIDATE_ID',
      defaultValue: '未冻结候选',
    ),
  );

  final String appVersion;
  final String candidateId;

  String get supportLabel => '$appVersion · $candidateId';
}

enum SceneGenerationFailureKind {
  authenticationRequired,
  profileUnavailable,
  sharedProfileUnavailable,
  householdAccessRequired,
  presetSceneUnavailable,
  invalidInput,
  requestConflict,
  requestTerminal,
  generationInProgress,
  rateLimited,
  unavailable,
  timeout,
  network,
  malformedResponse,
  rejected,
  unexpected,
}

class SceneGenerationFailure implements Exception {
  const SceneGenerationFailure({
    required this.kind,
    this.generatedContentId,
    this.retryable = false,
    this.requiresNewClientRequestId = false,
  });

  final SceneGenerationFailureKind kind;
  final String? generatedContentId;
  final bool retryable;
  final bool requiresNewClientRequestId;

  String get presentationMessage => switch (kind) {
    SceneGenerationFailureKind.authenticationRequired => '请先登录后再生成。',
    SceneGenerationFailureKind.profileUnavailable => '宝宝档案暂不可用，请先完善宝宝档案后再试。',
    SceneGenerationFailureKind.sharedProfileUnavailable =>
      '共享宝宝档案暂不可用，请让主照护者先完成档案后再试。',
    SceneGenerationFailureKind.householdAccessRequired =>
      '请先加入共享照护家庭并接受邀请，再使用共享宝宝档案。',
    SceneGenerationFailureKind.presetSceneUnavailable => '预置场景暂不可用，请稍后再试。',
    SceneGenerationFailureKind.invalidInput => '请调整场景描述后再试。',
    SceneGenerationFailureKind.requestConflict => '这次场景描述已变更，请重新开始生成。',
    SceneGenerationFailureKind.requestTerminal => '这次生成已结束，请使用新的请求重新生成。',
    SceneGenerationFailureKind.generationInProgress => '场景正在生成，请稍后查看。',
    SceneGenerationFailureKind.rateLimited => '生成次数过多，请稍后再试。',
    SceneGenerationFailureKind.unavailable => '生成服务暂不可用，请稍后再试。',
    SceneGenerationFailureKind.timeout => '生成超时，请稍后重试。',
    SceneGenerationFailureKind.network => '网络暂不可用，请检查后重试。',
    SceneGenerationFailureKind.malformedResponse => '生成响应异常，请稍后再试。',
    SceneGenerationFailureKind.rejected => '这段场景描述暂不适合生成，请调整后再试。',
    SceneGenerationFailureKind.unexpected => '生成失败，请稍后再试。',
  };

  @override
  String toString() {
    return 'SceneGenerationFailure(kind: $kind, retryable: $retryable, '
        'generatedContentId: $generatedContentId, '
        'requiresNewClientRequestId: $requiresNewClientRequestId)';
  }
}

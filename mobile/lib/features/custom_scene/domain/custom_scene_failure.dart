enum CustomSceneFailureKind {
  authenticationRequired,
  profileUnavailable,
  householdAccessRequired,
  sharedProfileUnavailable,
  presetSceneUnavailable,
  invalidDraft,
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

class CustomSceneFailure implements Exception {
  const CustomSceneFailure({
    required this.kind,
    required this.retryable,
    this.generatedContentId,
    this.requiresNewClientRequestId = false,
  });

  final CustomSceneFailureKind kind;
  final bool retryable;
  final String? generatedContentId;
  final bool requiresNewClientRequestId;

  /// Stable, non-sensitive copy for a future application controller.
  String get presentationMessage => switch (kind) {
    CustomSceneFailureKind.authenticationRequired => '请先登录后再生成。',
    CustomSceneFailureKind.profileUnavailable =>
      '当前账号还没有可用于生成的宝宝档案；如果你是次照护者，请让主照护者先完成档案后再试。',
    CustomSceneFailureKind.householdAccessRequired =>
      '共享家庭权限暂不可用，请稍后再试。',
    CustomSceneFailureKind.sharedProfileUnavailable =>
      '共享宝宝档案暂不可用，请稍后再试。',
    CustomSceneFailureKind.presetSceneUnavailable => '预置场景暂不可用，请稍后再试。',
    CustomSceneFailureKind.invalidDraft => '请调整描述后再试。',
    CustomSceneFailureKind.requestConflict => '这次描述已变更，请重新开始生成。',
    CustomSceneFailureKind.requestTerminal => '这次生成已结束，请重新生成。',
    CustomSceneFailureKind.generationInProgress => '正在生成，请稍候。',
    CustomSceneFailureKind.rateLimited => '尝试次数较多，请稍后再试。',
    CustomSceneFailureKind.unavailable => '现在暂时无法生成，请稍后再试。',
    CustomSceneFailureKind.timeout => '等待超时，请稍后再试。',
    CustomSceneFailureKind.network => '网络暂不可用，请检查后重试。',
    CustomSceneFailureKind.malformedResponse => '服务响应异常，请稍后再试。',
    CustomSceneFailureKind.rejected => '这段描述暂时无法生成，请换个说法。',
    CustomSceneFailureKind.unexpected => '暂时无法生成，请稍后再试。',
  };

  @override
  String toString() {
    return 'CustomSceneFailure(kind: $kind, retryable: $retryable, '
        'requiresNewClientRequestId: $requiresNewClientRequestId)';
  }
}

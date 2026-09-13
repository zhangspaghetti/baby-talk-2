import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';

sealed class CustomSceneResult {
  const CustomSceneResult();
}

final class GeneratedSceneResult extends CustomSceneResult {
  const GeneratedSceneResult(this.moment, {required this.policyVersion});

  final GeneratedCareMoment moment;
  final String policyVersion;
}

final class HealthSafetyResult extends CustomSceneResult {
  const HealthSafetyResult(this.safety);

  final HealthSafetyNotice safety;
}

final class AssessmentUnavailableResult extends CustomSceneResult {
  const AssessmentUnavailableResult(this.safety);

  final HealthSafetyNotice safety;
}

class HealthSafetyNotice {
  const HealthSafetyNotice({
    required this.action,
    required this.templateId,
    required this.policyVersion,
    required this.locale,
    required this.titleZh,
    required this.messageZh,
  });

  final String action;
  final String templateId;
  final String policyVersion;
  final String locale;
  final String titleZh;
  final String messageZh;
}

const healthAssessmentUnavailableNotice = HealthSafetyNotice(
  action: 'uncertain',
  templateId: 'health-assessment-unavailable-v1',
  policyVersion: 'health-safety-v1',
  locale: 'zh-CN',
  titleZh: '暂时无法判断这段描述',
  messageZh:
      '暂时无法完成判断，已暂停生成。如果你正在担心宝宝身体不适，请联系儿科医生；如果情况紧急，请立即联系当地急救服务。',
);

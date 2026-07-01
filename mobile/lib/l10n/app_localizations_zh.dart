// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get mentorName => '小禾老师';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get viewAll => '查看全部';

  @override
  String get processing => '处理中…';

  @override
  String get localMode => '本地模式';

  @override
  String get guest => '访客';

  @override
  String get reactionCooperating => '配合';

  @override
  String get reactionHesitant => '犹豫';

  @override
  String get reactionResisting => '不想';

  @override
  String get reactionNoResponse => '没反应';

  @override
  String get reactionOther => '其他';

  @override
  String get sharedAttributionNextStep => '共享归因与下一步';

  @override
  String get enterSharedNextStep => '进入共享下一步';

  @override
  String get continueEntryUnavailable => '继续入口暂不可用';

  @override
  String get practiceEntryUnavailable => '练习入口暂时不可用。';

  @override
  String get bootErrorUnknown => '未知启动错误';

  @override
  String get bootErrorOnboardingRead => '本地档案读取失败，请重试。';

  @override
  String get bootErrorStartup => '应用启动失败，请重启后重试。';

  @override
  String get bootRetry => '重试';

  @override
  String get bootCloseTooltip => '关闭提示';

  @override
  String get homeContinuityNotConnected => '继续练习暂时还没准备好。';

  @override
  String get homeTonightTryActivity => '今晚试试把最近一次练习自然接起来。';

  @override
  String get homeWelcomeBack => '欢迎回来！稍后将为你推荐练习内容。';

  @override
  String get homeContinuitySharedNote => '首页和花园会一起记住这次练习，回来后同步更新。';

  @override
  String get homePracticeUnavailable => '暂时无法获取练习建议，请稍后重试。';

  @override
  String get homeReorganize => '重新整理';

  @override
  String get homeShareGrowthFamily => '把这次成长分享给家人';

  @override
  String get homeShareWaitStable => '等最近成长或继续建议整理稳定后，再生成一条脱敏分享链接。';

  @override
  String get homePracticeAdviceUnavailable => '暂时无法获取练习建议。';

  @override
  String get homeOrganizingContinuity => '正在整理适合继续的练习…';

  @override
  String get homeContinuityNoActivity => '暂时还没有下一条可继续的练习。';

  @override
  String get homeContinuityWarningNote => '有一小段练习记录暂时没整理好，当前建议仍可继续。';

  @override
  String get homeContinuityDisabledNote => '继续练习暂时没准备好，请稍后再试。';

  @override
  String get homeContinuityFallbackNote => '已经为你换到一条稳定可继续的练习。';

  @override
  String get homeStartPractice => '开始练习';

  @override
  String get homeContinuePractice => '继续练习';

  @override
  String homeTodaySceneSemantics(Object activityTitle) {
    return '今日场景：$activityTitle';
  }

  @override
  String homeLocalOnlyBanner(Object childName) {
    return '$childName 的昵称、月龄档和阶段在同意前仅保存在这台设备上。';
  }

  @override
  String homePersonalizedHeading(Object childName) {
    return '$childName，今天先从一句自然的英文开始。';
  }

  @override
  String get homeDailyPhraseCueLabel => '今天继续这一句';

  @override
  String get homeDailyPhraseCueBody => '回到照护场景时，再说一次就好；花园会从这颗种子继续长。';

  @override
  String get homeDefaultStageSummary => '先把英语放进照护动作里，保持真实、短句、可重复。';

  @override
  String get homeFirstSeed => '第一颗种子';

  @override
  String get homeStartBathTime => '先从洗澡时间这句开始。';

  @override
  String get homeContinuityUnavailable => '继续练习暂时不可用';

  @override
  String get homeContinuationRecent => '接着刚才练过的场景';

  @override
  String get homeContinuationNextIncomplete => '接上还没说完的活动';

  @override
  String get homeContinuationStarter => '回到第一颗种子';

  @override
  String get homeContinuationSafeFallback => '先从稳定活动开始';

  @override
  String homeNextAlternative(Object activityTitle) {
    return '下一步也可以切到 $activityTitle';
  }

  @override
  String get homeRecommendedActivity => '推荐活动';

  @override
  String get homeOrganizing => '整理中';

  @override
  String get homeWaitingContinuity => '等待下一次练习';

  @override
  String get homeCadence => '连续节奏';

  @override
  String get homeDerivingCadence => '正在整理最近一周的练习节奏';

  @override
  String get homeGardenOrganizing => '花园正在整理今天的变化';

  @override
  String get homeGardenProjecting => '花圃正在整理最近练习，马上就能看到结果。';

  @override
  String get homeGardenNotReady => '花园入口暂时没整理好';

  @override
  String get homeGardenKeepStable => '先保留最近一次稳定结果，你也可以稍后刷新。';

  @override
  String get homeGardenWarningNote => '有一小段练习记录暂时没整理好，花圃先保留可用结果。';

  @override
  String get homeGardenStartFirst => '你的花园会从第一句开口开始';

  @override
  String get homeGardenNoPractice => '还没有练习记录，先说出一句 Warm water.，花圃就会醒来。';

  @override
  String get homeGardenReady => '花园入口已准备好';

  @override
  String get homeGardenChanges => '花圃已经有变化，后续会继续接入完整花园页。';

  @override
  String homeGardenSpaceStage(Object spaceTitle, Object stageLabel) {
    return '$spaceTitle · $stageLabel';
  }

  @override
  String homeGardenActivityDetail(
    Object activityTitle,
    Object stageLabel,
    Object careNote,
  ) {
    return '$activityTitle 现在是\"$stageLabel\"，$careNote';
  }

  @override
  String get homeGrowthGarden => '🌱 成长花园';

  @override
  String get homeGrowthUnavailable => '最近成长摘要暂时不可用';

  @override
  String get homeGrowthFallback => '花圃暂时没整理好，会先保留当前结果。';

  @override
  String get homeGrowthPlaceholder => '最近成长会写在这里';

  @override
  String get homeGrowthAfterPractice => '完成一次练习后，这里会告诉你这次开口让什么发生了变化。';

  @override
  String get homeGrowthSummaryLabel => '最近成长摘要';

  @override
  String get homeRecentLocalResult => '最近一次本地结果';

  @override
  String get homeNoLocalRecords => '还没有本地练习记录，第一次打开也会看到安全空态。';

  @override
  String get homeRecentFallbackNote => '最近结果暂时没整理好，先为你保留一条可继续的练习。';

  @override
  String homeRecentResultDetail(Object totalEvents, Object time) {
    return '$totalEvents 条本地记录 · 最近一次 $time';
  }

  @override
  String get onboardingTitle => '先拿一句今天能和宝宝说的英文';

  @override
  String get onboardingSubtitle => '只要昵称和大概月龄，小禾老师会先在本机准备第一句。';

  @override
  String get onboardingLocalOnly => '同意前仅保存在这台设备，不需要精确生日。';

  @override
  String get onboardingMentorGreeting => '你好，我会先帮你把英语放进今天就能开口的照护节奏里。';

  @override
  String get onboardingAskName => '我先怎么称呼宝宝？先用一个你最顺口的小昵称就好。';

  @override
  String get onboardingAskAge => '现在大概几个月？我会用月龄档给你匹配阶段，不会要求精确生日。';

  @override
  String onboardingStagePreview(Object childName) {
    return '$childName 现在更适合从这一类短句开始，先用一句真实照护里的英文试试看。';
  }

  @override
  String get onboardingWelcomeInfo => '先准备两条信息：宝宝昵称 + 月龄档。';

  @override
  String get onboardingWelcomeDetail => '完成后会看到第一句英文、什么时候说，以及怎么接住宝宝反应。';

  @override
  String get onboardingStartButton => '先开始';

  @override
  String get onboardingNameLabel => '宝宝昵称';

  @override
  String get onboardingNameHint => '例如：米米、果果';

  @override
  String get onboardingNameHelp => '先用一个顺口的小名就够了，之后还可以再改。';

  @override
  String get onboardingBack => '上一步';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingAgeTitle => '月龄快选';

  @override
  String get onboardingAgeHelp => '不需要精确到哪一天，先选最接近的一档就可以。';

  @override
  String onboardingAgeMonths(Object months) {
    return '$months月左右';
  }

  @override
  String get onboardingContentLoading => '正在准备第一句…';

  @override
  String get onboardingContentRetry => '重新准备';

  @override
  String get onboardingAgeContinue => '准备第一句';

  @override
  String get onboardingPreviewConfirm => '先播放一下，再说一次；我会把这次开始保存在本机。';

  @override
  String get onboardingPreviewRetryHint => '说完可以点“我说了”，不用等宝宝立刻回应。';

  @override
  String get onboardingPreviewSeedLabel => '第一句可以先这样说';

  @override
  String get onboardingMiniSceneActionHint => '洗澡、换衣或抱起宝宝时，都可以先轻轻说这一句。';

  @override
  String get onboardingMiniScenePlay => '播放一下';

  @override
  String get onboardingMiniScenePlaying => '播放中';

  @override
  String get onboardingMiniSceneSaid => '我说了';

  @override
  String get onboardingMiniSceneRecording => '记录中';

  @override
  String get onboardingMiniSceneRecorded => '已在本机种下第一颗种子，首页会接着这句继续。';

  @override
  String get onboardingSayFirstBeforeHome => '先说一次';

  @override
  String get onboardingPreviewBack => '返回调整';

  @override
  String get onboardingSaving => '正在保存到本地';

  @override
  String get onboardingEnterHome => '进入首页继续';

  @override
  String get onboardingStageMatch => '现在适合这样开始';

  @override
  String get onboardingMentorCaption => '禾';

  @override
  String get onboardingFirstSeed => '第一颗种子';

  @override
  String onboardingMentorMessageSemantics(Object message) {
    return '小禾老师引导消息：$message';
  }

  @override
  String onboardingMiniSeedCardSemantics(Object phrase) {
    return '第一颗种子：$phrase';
  }

  @override
  String onboardingStageMatchSemantics(Object stageTitle, Object summary) {
    return '现在适合这样开始：$stageTitle。$summary';
  }

  @override
  String onboardingFirstPhraseActionErrorSemantics(Object message) {
    return '第一句记录失败：$message';
  }

  @override
  String onboardingSaveErrorSemantics(Object message) {
    return '保存失败：$message';
  }

  @override
  String get shellDrawerTooltip => '打开家庭抽屉';

  @override
  String get shellHome => '今天';

  @override
  String get shellDiscover => '场景';

  @override
  String get shellGarden => '花园';

  @override
  String get shellGrowth => '成长';

  @override
  String shellHomeName(Object name) {
    return '$name 的今天';
  }

  @override
  String get shellBabyName => '这位宝宝';

  @override
  String get shellFirstTimeDrawer => '第一次进入家庭档案';

  @override
  String get shellSharedNotConnected => '共享未接通';

  @override
  String get shellSharedStatusReady => '共享已接通';

  @override
  String get shellSharedStatusWaiting => '邀请待确认';

  @override
  String get shellSharedStatusUnavailable => '共享暂时不可用';

  @override
  String get shellSharedStatusReadOnly => '仅可查看共享';

  @override
  String get shellSharedStatusPending => '共享待同步';

  @override
  String get shellNoStageDescription => '完成首次设置后，这里会显示更合适的阶段说明。';

  @override
  String get shellLocalOnlyNote =>
      '同意前，这里的昵称、月龄档和阶段仅保存在这台设备上；共享照护只会显示脱敏后的角色和共享摘要。';

  @override
  String get shellSharedProfile => '共享家庭档案';

  @override
  String get shellFamilyProfile => '家庭档案';

  @override
  String get shellAgeBucket => '月龄档';

  @override
  String get shellNotFilled => '未填写';

  @override
  String get shellCurrentStage => '当前阶段';

  @override
  String get shellPendingMatch => '待匹配';

  @override
  String get shellSharedRole => '共享角色';

  @override
  String get shellPendingSync => '待同步';

  @override
  String get shellDrawerNote =>
      'Drawer 现在会直接显示 invite CTA、角色 badge、最近是谁完成了什么，以及共享下一步是否安全可进。';

  @override
  String get shellAvatarHome => '家';

  @override
  String get accountTitle => '账号与同步';

  @override
  String get accountViewStatus => '查看账号状态';

  @override
  String get accountRegisterLogin => '注册 / 登录';

  @override
  String get accountRetryRead => '重试读取';

  @override
  String get accountRetrySync => '重试同步';

  @override
  String get accountReading => '正在读取账号状态';

  @override
  String get accountLocalOnly => '仍是本机档案模式';

  @override
  String get accountNotLoggedIn => '当前未登录账号';

  @override
  String accountSignedIn(Object phone) {
    return '已登录 $phone';
  }

  @override
  String get accountSyncRetryNeeded => '同步仍需重试';

  @override
  String get accountConsentRevoked => '同意已撤回';

  @override
  String get accountDeleted => '账号已删除';

  @override
  String get accountUpgradeNeeded => '当前版本需要升级';

  @override
  String get accountStatusUnreadable => '账号状态暂时不可读';

  @override
  String get accountShellNote => '账号状态准备中；你仍可以先继续练习，稍后这里会显示同步进展。';

  @override
  String get accountCurrentProfile => '当前档案';

  @override
  String accountProfileName(Object name) {
    return '$name 的档案';
  }

  @override
  String accountLocalOnlyNote(Object prefix) {
    return '$prefix 仍只保存在本机；现在可以先继续练习，稍后再补账号与同意。';
  }

  @override
  String get accountEntryNote => '登录前，手机号和验证码只用于账号流程，不会影响本机练习记录。';

  @override
  String accountPendingSync(Object count) {
    return '仍有 $count 条练习记录待同步，打开应用、回到首页或手动重试时会继续尝试。';
  }

  @override
  String get accountAlignedNote => '最近状态已对齐；重新登录后会恢复最近结果和继续练习位置。';

  @override
  String get accountSyncIncomplete => '最近一次同步没有完成，但本机练习记录仍保留，可继续练习并稍后重试。';

  @override
  String get accountRevokedNote => '撤回后不会再上传或恢复远端数据；重新登录并再次同意后才会继续同步。';

  @override
  String get accountDeletedNote => '删除后账号不可恢复；本机仍可继续保留练习。';

  @override
  String get accountUpgradeNote => '服务端已拒绝当前版本；请先安装新版本，再返回这里继续同步。';

  @override
  String get accountUpgradeUnavailable => '服务端已拒绝当前版本；升级入口暂不可用，请稍后重试或联系支持。';

  @override
  String get accountUpgradeReassurance => '升级等待期间，本机练习记录仍会保留，你可以继续在本机使用。';

  @override
  String get accountReadFailed => '账号状态暂时没有读取成功；你仍可以继续当前练习，稍后再重试。';

  @override
  String get accountReadFailedPrimary => '账号状态暂时不可读；先重试读取即可，不会影响本机练习记录。';

  @override
  String get accountReadRetryGuidance => '重试只会重新读取账号状态，不会改动本机练习记录。';

  @override
  String accountPendingSyncCount(Object count) {
    return '待同步 $count';
  }

  @override
  String accountSyncedCount(Object count) {
    return '已同步 $count';
  }

  @override
  String accountFailedCount(Object count) {
    return '失败 $count';
  }

  @override
  String get accountSyncChipGuidance => '待同步和失败不会影响当前练习；有空时点“重试同步”即可继续推进。';

  @override
  String get accountLifecycleChipGuidance =>
      '状态已变更（如撤回同意或账号删除）；芯片仅展示本机统计，不代表可继续同步。';

  @override
  String get accountReadErrorChipGuidance => '当前账号状态读取异常；芯片仅供参考，可稍后重试读取。';

  @override
  String accountRecentTime(Object time) {
    return '最近 $time';
  }

  @override
  String get accountSyncPhaseUpdated => '同步状态已更新';

  @override
  String get accountEntryLabel => '账号入口';

  @override
  String get accountS03Label => '账号与同步设置';

  @override
  String get accountRetryReadStatus => '重试读取账号状态';

  @override
  String get accountPhoneLabel => '手机号';

  @override
  String get accountCodeLabel => '验证码';

  @override
  String get accountDevStub => '请输入 6 位验证码';

  @override
  String get accountRealLoginNote =>
      '登录只会接入账号同步，不会清空本机练习记录；如果出错，你仍会停留在账号页并可继续当前练习。';

  @override
  String accountLastError(Object error) {
    return '最近错误：$error';
  }

  @override
  String get accountLoginComplete => '登录已完成，可返回首页查看最近恢复结果。';

  @override
  String get accountLoginConsent => '登录并同意';

  @override
  String get accountRevokeConsent => '撤回同意';

  @override
  String get accountDeleteAccount => '删除账号';

  @override
  String get accountLogout => '退出为未登录';

  @override
  String get accountBackToLocal => '回到本机档案';

  @override
  String get accountPreparing => '正在准备账号状态';

  @override
  String get accountKeepLocalProfile => '先保留同意前本地档案';

  @override
  String get accountVisibleNotLoggedIn => '账号入口已可见，但你还没有登录';

  @override
  String accountSignedInPending(Object phone) {
    return '已用 $phone 登录，仍有练习记录待同步';
  }

  @override
  String accountSignedInAligned(Object phone) {
    return '已用 $phone 登录并完成最近一次对齐';
  }

  @override
  String get accountSignedInSyncRetry => '登录已完成，但最近同步仍需重试';

  @override
  String get accountReadFailedShell => '账号状态读取失败，但当前页面仍可继续使用';

  @override
  String accountSignedInPendingSyncStatus(Object count) {
    return '已登录 · 待同步 $count';
  }

  @override
  String get householdPrimaryCaregiver => '主照护者';

  @override
  String get householdCaregiver => '次照护者';

  @override
  String get householdMember => '家庭成员';

  @override
  String get householdSyncReflow => '同步回流';

  @override
  String get householdSharedSync => '共享同步';

  @override
  String get householdReactionCalm => '平静回应';

  @override
  String get householdReactionEngaged => '愿意看着你';

  @override
  String get householdReactionImitated => '开始模仿';

  @override
  String get householdReactionNeedsBreak => '需要先休息';

  @override
  String get householdRecorded => '已记录反馈';

  @override
  String get householdContinueActivity => '继续刚完成的 activity';

  @override
  String get householdResumeActivity => '先接上当前最该继续的 activity';

  @override
  String get householdSharedNextReady => '共享下一步已整理好';

  @override
  String get householdSharedPractice => '家庭刚完成一次共享练习';

  @override
  String householdActorSharedPractice(Object role) {
    return '$role刚完成一次共享练习';
  }

  @override
  String householdRecentInteractionMissing(Object time) {
    return '最近互动 $time · 归因字段缺失时仅保留脱敏共享摘要。';
  }

  @override
  String householdActorDetail(Object source, Object result, Object time) {
    return '$source · $result · 最近互动 $time';
  }

  @override
  String get householdNextStepMissing => '共享下一步暂时打不开，入口已保持安全禁用。';

  @override
  String householdRecentInteraction(Object interactionTime, Object updateTime) {
    return '最近互动 $interactionTime · 更新 $updateTime';
  }

  @override
  String get householdSharedRefreshedNoEntry =>
      '共享上下文已刷新，但下一步缺少安全入口；当前不会回退到错误默认 activity。';

  @override
  String get householdSharedAttribution => '共享归因';

  @override
  String get householdEntryPending => '入口待整理';

  @override
  String get householdNextStepReady => '下一步已就绪';

  @override
  String get householdSharedCare => '共享照护';

  @override
  String get householdSharedNotConnected => '共享未接通';

  @override
  String get householdSharedFeatureNotConnected => '共享功能暂未接通';

  @override
  String get householdFallbackNote => '共享档案和最近练习暂时不可用，已保留安全空态。';

  @override
  String householdLastAccepted(Object time) {
    return '最近接受：$time';
  }

  @override
  String get householdRetryAccept => '重试接受邀请';

  @override
  String get householdRetrySharedSync => '重试共享同步';

  @override
  String get householdRefreshContext => '刷新共享上下文';

  @override
  String get householdSharedConnected => '共享宝宝档案已接通';

  @override
  String get householdContextUnavailable => '共享上下文暂不可用';

  @override
  String get householdWaitingCaregiver => '等待次照护者加入';

  @override
  String get householdContextPreparing => '共享上下文正在准备';

  @override
  String get householdCareNotConnected => '共享照护尚未接通';

  @override
  String get householdPrimaryCaregiverNote =>
      '你当前是主照护者，可以管理邀请，并查看共享宝宝档案、最近归因与下一步入口。';

  @override
  String get householdCaregiverAccepted =>
      '你当前是次照护者；邀请接受成功后，这里会显示共享宝宝档案、最近归因与下一步入口。';

  @override
  String get householdCaregiverConnected => '你当前是次照护者；这里展示的是共享宝宝档案、最近归因与下一步入口。';

  @override
  String get householdRoleNotSynced =>
      '角色尚未同步；共享档案会继续停留在安全 fallback，不会把错误参数写进练习入口。';

  @override
  String get householdContextUnavailableNote => '共享上下文暂不可用；当前不会写入不完整的下一步。';

  @override
  String get householdPrimaryInviteNote => '生成邀请并等待次照护者接受后，这里会出现共享宝宝档案与下一步入口。';

  @override
  String get householdCaregiverWaitingNote => '接受邀请后，如果共享上下文尚未刷新完成，这里会保留只读等待态。';

  @override
  String get householdNotInitialized => 'household 尚未初始化；当前保持显式 disabled 状态。';

  @override
  String get householdRecentAttribution => '最近归因';

  @override
  String get householdAttributionPending => '归因待补全';

  @override
  String get householdSafeSummary => '安全摘要';

  @override
  String get householdSharedNextStep => '共享下一步';

  @override
  String get householdNextStepPending => '共享下一步待整理';

  @override
  String get householdSharedBabyProfile => '共享宝宝档案';

  @override
  String get householdRecentContinuity => '最近继续练习';

  @override
  String get householdGardenContext => '花园上下文';

  @override
  String get householdRolePendingSync => '角色待同步';

  @override
  String get discoverTitle => '发现';

  @override
  String get discoverSubtitle => '按活动和空间继续找下一句。';

  @override
  String get discoverNote =>
      '这里展示真实离线目录：你可以按 activity 挑一句，也可以按 space 找到现在最顺手的照护时刻。';

  @override
  String get discoverByActivity => '按活动';

  @override
  String get discoverBySpace => '按空间';

  @override
  String get discoverLoadingCatalog => '正在整理离线场景目录…';

  @override
  String get discoverLoadingNote => '加载只影响场景，不会阻塞今天、花园和成长 tab。';

  @override
  String get discoverLoadError => '目录暂时没有整理好';

  @override
  String get discoverRetryLoad => '重试加载';

  @override
  String get discoverEmpty => '目录还是空的';

  @override
  String get discoverEmptyNote => '目前没有可展示的场景。稍后重试即可重新读取本地目录。';

  @override
  String get discoverRetryRead => '重新读取目录';

  @override
  String get discoverBrowseByActivity => '按活动浏览';

  @override
  String get discoverActivityRouteNote => '每张活动卡都会打开对应练习。';

  @override
  String discoverActivityCardSemantics(Object title) {
    return '活动: $title';
  }

  @override
  String discoverSpaceActivitySemantics(Object title) {
    return '空间活动: $title';
  }

  @override
  String get discoverSummaryMissing => '摘要暂时缺失，但这张卡仍然可以安全进入练习。';

  @override
  String get discoverActivityWarningNote => '有一小段练习记录暂时没整理好，当前活动仍可继续。';

  @override
  String discoverNextPhrase(Object phrase) {
    return '下一句：$phrase';
  }

  @override
  String get discoverNoNextPhrase => '目录暂时没有下一句预览。';

  @override
  String discoverRecentResult(Object time, Object count) {
    return '最近一次 $time · $count 条记录';
  }

  @override
  String discoverProgress(Object completed, Object total, Object events) {
    return '$completed/$total 句已练 · $events 条记录';
  }

  @override
  String get discoverNeedsAttention => '需留意';

  @override
  String get discoverLatestProgress => '最近进度 / 结果';

  @override
  String get discoverStartActivity => '开始这个活动';

  @override
  String get discoverContinueActivity => '继续这个活动';

  @override
  String get discoverBrowseBySpace => '按空间浏览';

  @override
  String get discoverSpaceRouteNote => '每个空间会保留你点击的活动入口。';

  @override
  String discoverSpaceProgress(Object started, Object total, Object events) {
    return '$started/$total 个 activity 已开始 · $events 条记录';
  }

  @override
  String get discoverOpenActivity => '打开后查看这张活动卡里的短语';

  @override
  String discoverPhraseProgress(Object completed, Object total) {
    return '$completed/$total 句';
  }

  @override
  String discoverLoadErrorMsg(Object error) {
    return '目录读取失败：$error';
  }

  @override
  String get discoverInvalidCard => '这张活动卡暂时打不开，已为你保留在当前页面。';

  @override
  String discoverOpenError(Object title, Object error) {
    return '打开 $title 失败：$error';
  }

  @override
  String get gardenSharedAttributionTitle => '共享归因与花园下一步';

  @override
  String get gardenShareFamily => '把花园里的这次变化分享给家人';

  @override
  String get gardenShareWaitStable => '等最近成长和继续建议整理好后，再生成脱敏分享链接。';

  @override
  String get gardenRefreshFailed => '花园刷新失败，先保留上一次稳定结果。';

  @override
  String get gardenContinueFromShared => '从共享下一步继续';

  @override
  String get gardenTodayChanges => '花园今日变化';

  @override
  String get gardenEveryVoice => '每一次开口，花园都会记得。';

  @override
  String get gardenNoScores => '这里不会给分数，只会把真实发生过的照护练习慢慢长成花圃与花朵。';

  @override
  String get gardenOrganizing => '花园正在整理今天的变化';

  @override
  String get gardenProjectingNote => '正在把最近练习整理成花圃变化，稍等一下就会出现在这里。';

  @override
  String get gardenProjectionWarningNote => '有一小段练习记录暂时没整理好，花圃先保留可用结果。';

  @override
  String get gardenContinuityNotConnected => '继续练习暂时没准备好';

  @override
  String get gardenUnavailable => '花园暂时不可用，请稍后重试。';

  @override
  String get gardenComeBack => '回来继续';

  @override
  String gardenContinueActivity(Object activityTitle) {
    return '继续 $activityTitle';
  }

  @override
  String gardenImpactDetail(Object detail, Object activityTitle) {
    return '$detail 现在继续会回到 $activityTitle。';
  }

  @override
  String gardenImpactWithReason(
    Object impactTitle,
    Object activityTitle,
    Object reason,
  ) {
    return '上一次变化来自 $impactTitle；现在可以接着去 $activityTitle（$reason）。';
  }

  @override
  String get gardenContinuitySharedNote => '花园会和首页一起，把你带回刚才适合继续说的练习。';

  @override
  String get gardenSharedContinuity => '顺着刚才的练习';

  @override
  String get gardenContinuationRecent => '接着刚才练过的场景';

  @override
  String get gardenContinuationNextIncomplete => '接上还没说完的活动';

  @override
  String get gardenContinuationStarter => '回到第一颗种子';

  @override
  String get gardenContinuationSafeFallback => '先从稳定活动开始';

  @override
  String get gardenFallbackReassurance => '已经为你换到一条稳定可继续的练习。';

  @override
  String get gardenContinuationWarning => '有一小段练习记录暂时没整理好，当前建议仍可继续。';

  @override
  String get gardenContinueUnavailableNote => '这条继续练习暂时打不开，先回首页或稍后再试。';

  @override
  String get gardenFirstSeedNotPlanted => '第一颗种子还没落下';

  @override
  String get gardenFirstSeedNote => '先从一句 Warm water. 开始。花圃会先醒来，接着才慢慢长出花朵和节奏。';

  @override
  String gardenStartedProgress(Object started, Object total) {
    return '已开始 $started/$total';
  }

  @override
  String gardenCompletedProgress(Object completed, Object total) {
    return '已完成 $completed/$total';
  }

  @override
  String gardenTotalEvents(Object count) {
    return '$count 条练习记录';
  }

  @override
  String gardenActivityProgress(Object completed, Object total, Object events) {
    return '已连起 $completed/$total 句 · $events 次记录';
  }

  @override
  String gardenPatchSemantics(Object title, Object stage) {
    return '花圃：$title，阶段 $stage';
  }

  @override
  String gardenFlowerSemantics(Object title, Object stage) {
    return '活动：$title，阶段 $stage';
  }

  @override
  String get gardenSharedContinuityUnavailable => '暂时还没有下一句';

  @override
  String get gardenContinueWatering => '继续浇灌';

  @override
  String get gardenContinueNote => '继续练习后，首页和花园会一起记住这次变化。';

  @override
  String get gardenContinueToday => '继续今天的练习';

  @override
  String get practiceInvalidParams => '当前练习入口缺少有效参数，请返回上一个页面重试。';

  @override
  String get practiceContextMissing => '当前活动上下文缺失，请返回首页重试。';

  @override
  String practiceProgress(Object current, Object total) {
    return '第 $current / $total 句';
  }

  @override
  String get practiceLastSaved => '最后一句也已保存，本轮练习已完成。返回首页后会看到最近一次本地结果。';

  @override
  String get practiceCurrentPhrases => '现在试试这一句';

  @override
  String get practiceActivationKicker => '跟着宝宝节奏来';

  @override
  String practicePhraseStep(Object step) {
    return '第 $step 句';
  }

  @override
  String get practiceUnavailable => '练习暂不可用';

  @override
  String get practiceBackHome => '返回首页';

  @override
  String get mentorNotReady => 'Mentor 面板尚未装配完成。';

  @override
  String get mentorOfflineNote => '先给建议，再决定是否需要聊天。离线时也不会让你白点。';

  @override
  String get mentorClosePanel => '关闭 Mentor 面板';

  @override
  String get mentorSuggestionTab => '建议';

  @override
  String get mentorChatTab => '聊天';

  @override
  String get mentorChatNote => '导师只返回一条清晰回应，帮助你先稳住当下。';

  @override
  String get mentorReadStatus => '朗读状态';

  @override
  String get mentorChatPlaceholder => '说出你现在卡住的地方';

  @override
  String get mentorChatHint => '例如：宝宝一直哭，我现在该怎么开口安抚？';

  @override
  String get mentorSending => '发送中…';

  @override
  String get mentorSendRequest => '发起一次求助';

  @override
  String get mentorRecheck => '重新检查';

  @override
  String get mentorBackToSuggestion => '回到建议';

  @override
  String get mentorControlledResponse => '受控回应';

  @override
  String get mentorNotLoggedIn => '未登录';

  @override
  String get mentorLocalResponse => '本地回应';

  @override
  String get mentorReading => '朗读中…';

  @override
  String get mentorReadResponse => '朗读回应';

  @override
  String get mentorSuggestionIntro => '先给你几条现在就能说出口的建议。离线时也可以直接用，不需要等聊天连通。';

  @override
  String get mentorSuggestionLoading => '正在整理本地建议…';

  @override
  String get mentorSuggestionEmpty => '还没整理出建议';

  @override
  String get mentorSuggestionEmptyNote => '别担心，你重新打开或点一次刷新就好；面板本身不会失效。';

  @override
  String get mentorSuggestionRefresh => '刷新建议';

  @override
  String get mentorSuggestionRead => '朗读';

  @override
  String get phraseRecorded => '已记录';

  @override
  String get phrasePending => '待练习';

  @override
  String get phrasePlaybackReady => '听小禾读';

  @override
  String get phrasePlaybackPlaying => '播放中';

  @override
  String get phrasePlaybackCompleted => '再听一次';

  @override
  String get phrasePlaybackRetry => '这句没读出来，点我重试';

  @override
  String get phraseSaveAwaitingReaction => '等宝宝反应';

  @override
  String get phraseSaveSaving => '正在保存';

  @override
  String get phraseSaveSaved => '已记下反应';

  @override
  String get phraseSaveRetry => '保存需重试';

  @override
  String get phraseNote => '先听一遍，再跟着宝宝的节奏说。宝宝看你、安静听，或咿呀回应，都可以记录。';

  @override
  String get phraseReactionLabel => '宝宝现在的反应';

  @override
  String get growthRefreshFailed => '成长页刷新失败，先保留上次稳定结果。';

  @override
  String get growthAutoDiary => '自动日记';

  @override
  String get growthDiarySheetTitle => '全部成长日记';

  @override
  String get growthDiaryPracticeTag => '练习记录';

  @override
  String get growthDiaryMilestoneTag => '里程碑记录';

  @override
  String get growthNoDiary => '还没有自动日记，第一次练习完成后会在这里记下变化。';

  @override
  String get growthSceneProgress => '场景进展';

  @override
  String get growthNoScene => '花圃还没醒来，所以暂时没有场景进展。';

  @override
  String get growthMilestone => '里程碑';

  @override
  String get growthMilestoneSheetTitle => '全部里程碑';

  @override
  String get growthMilestoneAchieved => '已点亮';

  @override
  String get growthMilestoneLocked => '待点亮';

  @override
  String get growthMilestoneNote => '里程碑会在真实练习后逐步点亮。';

  @override
  String get growthDiaryLabel => '成长日记';

  @override
  String get growthNotScore => '成长不是分数，而是一串串被记住的变化。';

  @override
  String get growthNote => '这里会按时间整理自动日记、空间进展和里程碑，帮助你回看今天发生过什么。';

  @override
  String get growthOrganizing => '成长页正在整理练习记录';

  @override
  String get growthOrganizingNote => '准备好后，这里会出现最新一次变化、自动日记和里程碑。';

  @override
  String get growthEmptyTitle => '你的成长还没有开始。';

  @override
  String get growthEmptyDescription => '说完第一句英语后，这里会记录你的陪伴轨迹。';

  @override
  String get growthEmptyAction => '回到首页说一句';

  @override
  String get growthPlaceholder => '最近成长会写在这里';

  @override
  String get growthAfterPractice => '完成一次真实练习后，这里会告诉你哪朵花发芽了、哪条日记被写下来了。';

  @override
  String growthSpaceProgress(
    Object started,
    Object totalActivities,
    Object completed,
  ) {
    return '已开始 $started/$totalActivities 个活动 · 已完成 $completed/$totalActivities 个活动';
  }

  @override
  String growthLatestImpactSemantics(Object title) {
    return '最近成长：$title';
  }

  @override
  String growthDiaryEntrySemantics(Object title) {
    return '成长日记：$title';
  }

  @override
  String growthMilestoneSemantics(Object title) {
    return '成长里程碑：$title';
  }

  @override
  String growthPreviewCount(Object count) {
    return '共 $count 条记录';
  }

  @override
  String get inviteNotConnected => '共享功能暂未接通';

  @override
  String get inviteDisabledNote => '邀请入口已显式禁用，不会假装创建成功。';

  @override
  String get inviteLatestLink => '最新邀请链接';

  @override
  String inviteRoleExpiry(Object role, Object expiry) {
    return '角色：$role · 到期：$expiry';
  }

  @override
  String get inviteCreating => '创建中…';

  @override
  String get inviteGenerate => '生成照护邀请';

  @override
  String get inviteRegenerate => '重新生成邀请';

  @override
  String get inviteRetry => '重试邀请';

  @override
  String get inviteReadOnly => '当前角色只读：由主照护者发起邀请，你可以继续查看共享档案。';

  @override
  String get inviteCaregiver => '邀请次照护者加入';

  @override
  String get inviteManagedByPrimary => '邀请由主照护者管理';

  @override
  String get invitePermissionPending => '邀请权限待同步';

  @override
  String get inviteGenerateNote => '生成邀请链接后，次照护者可通过链接接受邀请并看到共享宝宝档案摘要。';

  @override
  String get inviteCaregiverNote => '你当前是次照护者，只读查看共享照护内容；如需新增成员，请让主照护者操作。';

  @override
  String get invitePermissionNote => '角色或权限尚未准备好；邀请入口保持禁用，并在失败时保留明确文案。';

  @override
  String get inviteLabel => '照护邀请';

  @override
  String get inviteTrustTitle => '邀请范围';

  @override
  String inviteTrustRole(Object role) {
    return '接收角色：$role';
  }

  @override
  String inviteTrustExpiry(Object expiry) {
    return '有效期至 $expiry';
  }

  @override
  String inviteTrustScope(Object role) {
    return '$role可查看共享宝宝档案摘要和照护进度，不会获得账号管理权限。';
  }

  @override
  String get inviteTrustPrivacy => '链接不会包含手机号、设备标识或内部记录编号。';

  @override
  String get shareNoContent => '当前还没有可分享的成长瞬间';

  @override
  String sharePhraseToday(Object phrase) {
    return '今天说的一句：$phrase';
  }

  @override
  String get shareGenerating => '正在生成分享链接…';

  @override
  String get shareButton => '分享给家人';

  @override
  String get sharePreviewButton => '预览后分享';

  @override
  String get shareWaiting => '等待可分享内容';

  @override
  String get shareGeneratingNote => '正在生成脱敏分享链接，请稍候。';

  @override
  String get shareWaitNote => '等最近成长或继续建议整理好后，再生成脱敏分享链接。';

  @override
  String get sharePanelOpened => '分享面板已打开。';

  @override
  String get shareCancelled => '已取消分享。';

  @override
  String get shareUnavailable => '分享暂时不可用，请稍后重试。';

  @override
  String get sharePrivacyNote => '分享内容会自动脱敏，只保留适合家人查看的成长片段。';

  @override
  String get sharePreviewTitle => '分享预览';

  @override
  String get sharePreviewIntro => '家人会看到这些脱敏后的内容。';

  @override
  String get sharePreviewIncludes => '将分享';

  @override
  String get sharePreviewPrivacyOmitted => '不会包含手机号、设备标识、账号信息或内部记录编号。';

  @override
  String get sharePreviewConfirm => '确认分享给家人';

  @override
  String get sharePreviewCancel => '先不分享';

  @override
  String get activationFrameLabel => '当前短语练习区';

  @override
  String get accountEntryLoading => '正在准备账号状态';

  @override
  String get accountEntryPreparingProfile => '先保留同意前本地档案';

  @override
  String get accountEntryVisibleNotLoggedIn => '账号入口已可见，但你还没有登录';

  @override
  String accountEntrySignedInSynced(Object phone) {
    return '已用 $phone 登录并完成最近一次对齐';
  }

  @override
  String get accountEntryReadFailedShell => '账号状态读取失败，但当前页面仍可继续使用';

  @override
  String get accountEntryTitle => '账号入口';

  @override
  String get accountEntryS03Label => '账号与同步设置';

  @override
  String get accountCurrentStatusSectionTitle => '当前账号状态';

  @override
  String get accountPrimaryActionSectionTitle => '登录与同意';

  @override
  String get accountPrimaryActionSectionHint => '需要登录或重新同意时，在这里完成手机号与验证码提交。';

  @override
  String get accountPrimaryActionSignedInHint => '已登录状态下不再重复展示登录表单。';

  @override
  String get accountPrimaryActionSignedInBody =>
      '当前账号已完成登录；如遇恢复或同步问题，请使用下方恢复区。';

  @override
  String get accountRecoverySectionTitle => '恢复与同步';

  @override
  String get accountRecoverySectionHint => '同步失败、版本受阻或恢复中断时，先从这里重试。';

  @override
  String get accountFamilyContextSectionTitle => '家庭共享上下文';

  @override
  String get accountFamilyContextSectionHint => '家庭共享入口会保持脱敏展示，并与账号状态分开处理。';

  @override
  String get accountManagementSectionTitle => '日常管理';

  @override
  String get accountManagementSectionHint => '退出或回到本机档案不会删除本机练习记录。';

  @override
  String get accountDangerZoneSectionTitle => '高风险操作';

  @override
  String get accountDangerZoneSectionHint => '撤回同意和删除账号会改变远端账号状态，确认前请核对影响范围。';

  @override
  String get accountDangerZoneRetentionNote => '本机记录仍会保留；删除账号只会在确认后清理本机敏感数据。';

  @override
  String get accountLifecycleCancel => '取消';

  @override
  String get accountDeleteConfirmTitle => '确认删除账号？';

  @override
  String get accountDeleteConfirmBody =>
      '删除后会清理本机账号、宝宝资料、家庭上下文、练习记录、导师事实和设备标识。此操作不可撤销。';

  @override
  String get accountDeleteConfirmAction => '确认删除';

  @override
  String get accountRevokeConfirmTitle => '确认撤回同意？';

  @override
  String get accountRevokeConfirmBody => '撤回后将停止账号同步；后续需重新登录并再次同意才能恢复。';

  @override
  String get accountRevokeConfirmAction => '确认撤回';

  @override
  String get accountClearConfirmTitle => '确认退出为未登录？';

  @override
  String get accountClearConfirmBody => '退出后账号会变为未登录状态，但本机练习记录仍会保留。';

  @override
  String get accountClearConfirmAction => '确认退出';

  @override
  String get accountLocalOnlyConfirmTitle => '确认回到本机档案？';

  @override
  String get accountLocalOnlyConfirmBody => '切换后将回到本机档案模式；本机练习记录仍会保留。';

  @override
  String get accountLocalOnlyConfirmAction => '确认切换';

  @override
  String get accountEntrySubmitMessage =>
      '登录已完成；你现在可以返回首页查看最近恢复结果，待同步记录也会继续尝试上传。';

  @override
  String get accountEntrySubmitButton => '提交';

  @override
  String get shellDiscoverTooltip => '场景';

  @override
  String get shellPractice => '今天';

  @override
  String shellPracticeName(Object name) {
    return '$name 的今天';
  }

  @override
  String get shellGrowthTab => '成长';

  @override
  String get shellFirstTimeDrawerStage => '第一次进入家庭档案';

  @override
  String get shellDrawerNoteText =>
      'Drawer 现在会直接显示 invite CTA、角色 badge、最近是谁完成了什么，以及共享下一步是否安全可进。';

  @override
  String get growthDiaryEmpty => '还没有自动日记，第一次练习完成后会在这里记下变化。';

  @override
  String get growthMilestoneEmpty => '里程碑会在真实练习后逐步点亮。';

  @override
  String get growthShareWaitStable => '等最近成长和继续建议整理稳定后，再生成一条脱敏分享链接。';

  @override
  String get growthSceneEmpty => '花圃还没醒来，所以暂时没有场景进展。';

  @override
  String get gardenContinueUnavailable => '继续入口暂不可用';

  @override
  String gardenContinueActivityTitle(Object activityTitle) {
    return '继续 $activityTitle';
  }

  @override
  String gardenImpactContinue(Object detail, Object activityTitle) {
    return '$detail 现在继续会回到 $activityTitle。';
  }

  @override
  String gardenImpactWithReasonDetail(
    Object impactTitle,
    Object activityTitle,
    Object reason,
  ) {
    return '上一次变化来自 $impactTitle；现在可以接着去 $activityTitle（$reason）。';
  }

  @override
  String get discoverInvalidCardError => '这个场景暂时打不开，已为你保留在当前页面。';

  @override
  String discoverOpenActivityError(Object title, Object error) {
    return '打开 $title 失败：$error';
  }

  @override
  String get discoverSearchHint => '搜索场景或照护时刻...';

  @override
  String get discoverSceneAll => '全部';

  @override
  String get discoverSceneMealtime => '喂饭';

  @override
  String get discoverSceneDrinking => '喝水';

  @override
  String get discoverSceneDiaper => '换尿布';

  @override
  String get discoverSceneBath => '洗澡';

  @override
  String get discoverSceneBedtime => '睡前';

  @override
  String get discoverSceneOuting => '出门';

  @override
  String get discoverSortMostUsed => '最常用';

  @override
  String get discoverSortNewest => '最新';

  @override
  String get discoverSortAll => '全部';

  @override
  String get discoverSortLabel => '排序';

  @override
  String get discoverPracticeThis => '现在说一句';

  @override
  String discoverUsageHint(Object scene) {
    return '适合在$scene时轻轻说一次';
  }

  @override
  String get discoverSearchEmpty => '没有找到匹配的场景，换个关键词试试';

  @override
  String get discoverSceneEmpty => '这个分类还没有场景，换个分类试试';

  @override
  String get discoverSceneTagMealtime => '喂饭';

  @override
  String get discoverSceneTagDrinking => '喝水';

  @override
  String get discoverSceneTagDiaper => '换尿布';

  @override
  String get discoverSceneTagBath => '洗澡';

  @override
  String get discoverSceneTagBedtime => '睡前';

  @override
  String get discoverSceneTagOuting => '出门';

  @override
  String get discoverSceneTagOther => '其他';

  @override
  String get discoverPracticePhraseHint => '点击卡片或按钮进入当前场景';

  @override
  String get discoverTrustSubtitle => '照护场景';

  @override
  String get discoverTrustPrivacy => '你的信息受到保护';

  @override
  String get discoverUnifiedLoginTitle => '欢迎使用 BabyTalk';

  @override
  String get discoverUnifiedLoginSubtitle => '输入手机号，自动识别新老用户';

  @override
  String get discoverPhoneLabel => '手机号';

  @override
  String get discoverPhoneHint => '用于登录或注册 BabyTalk';

  @override
  String get discoverGetCode => '获取验证码';

  @override
  String get discoverCodeLabel => '验证码';

  @override
  String get discoverCodeHint => '输入 6 位短信验证码';

  @override
  String get discoverCodeAutoHint => '支持自动填充和粘贴';

  @override
  String get discoverResendCode => '重新发送';

  @override
  String discoverResendCountdown(Object seconds) {
    return '${seconds}s 后可重发';
  }

  @override
  String get discoverResendReady => '没有收到？可以重新发送';

  @override
  String get discoverLoginButton => '登录 / 注册';

  @override
  String get discoverPasswordLabel => '密码';

  @override
  String get discoverPasswordHint => '至少 8 位，建议包含字母和数字';

  @override
  String get discoverConfirmPasswordLabel => '确认密码';

  @override
  String get discoverForgotPassword => '忘记密码？';

  @override
  String get discoverResetPasswordTitle => '重置密码';

  @override
  String get discoverResetPasswordSubtitle => '通过验证码确认身份后设置新密码';

  @override
  String get discoverNewPasswordLabel => '新密码';

  @override
  String get discoverSetPasswordLabel => '设置密码';

  @override
  String get discoverTermsPrefix => '我已阅读并同意';

  @override
  String get discoverTermsOfService => '《服务条款》';

  @override
  String get discoverPrivacyPolicy => '《隐私协议》';

  @override
  String get discoverPrivacyNote => '登录即表示同意我们的服务条款和隐私协议';

  @override
  String get discoverVerificationPassed => '人机校验已通过，验证码已发送';

  @override
  String get discoverVerificationPending => '验证码待发送';

  @override
  String get discoverCodeSentToast => '验证码已发送，请查看短信';

  @override
  String get discoverCaptchaTitle => '安全验证';

  @override
  String get discoverCaptchaDescription => '请先完成校验，验证通过后再发送验证码。';

  @override
  String get discoverCaptchaArea => 'CAPTCHA 校验区域';

  @override
  String get discoverCaptchaPass => '模拟验证通过';

  @override
  String get discoverCaptchaCancel => '取消';

  @override
  String get discoverModeCodeLogin => '验证码登录';

  @override
  String get discoverModePasswordLogin => '密码登录';

  @override
  String get discoverModeRegister => '注册';

  @override
  String get discoverReturnToLogin => '返回登录';

  @override
  String sharePhraseTodayLabel(Object phrase) {
    return '今天说的一句：$phrase';
  }

  @override
  String get mentorSuggestionTabSemantics => '建议标签页';

  @override
  String get mentorChatTabSemantics => '聊天标签页';

  @override
  String get shellMe => '我';

  @override
  String get meGardenEmpty => '还没有种下花圃';

  @override
  String meGardenSummary(Object count) {
    return '$count 个花圃正在成长';
  }

  @override
  String get meGrowthTitle => '成长数据';

  @override
  String get meStatEvents => '练习次数';

  @override
  String get meStatDiary => '成长日记';

  @override
  String get meStatMilestones => '里程碑';

  @override
  String get meStatPracticeTotal => '练习总量';

  @override
  String get meStatStreak => '坚持天数';

  @override
  String meGrowthPracticeTotalValue(Object count, Object scenes) {
    return '$count 句 · $scenes 场景';
  }

  @override
  String meGrowthStreakValue(Object days) {
    return '$days 天';
  }

  @override
  String get meAccountSignedOutHint => '登录后同步数据';

  @override
  String get meAccountSyncing => '同步中…';

  @override
  String get meReminders => '提醒设置';

  @override
  String get meBabyProfile => '宝宝档案';

  @override
  String get mePlaybackPrefs => '播放偏好';

  @override
  String get meHelp => '帮助与反馈';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsReminderSection => '提醒设置';

  @override
  String get settingsDailyReminder => '每日提醒';

  @override
  String get settingsNotEnabled => '未开启';

  @override
  String get settingsBabyProfileSection => '宝宝档案';

  @override
  String get settingsBabyInfo => '宝宝信息';

  @override
  String get settingsTapToSetBabyInfo => '点击设置宝宝信息';

  @override
  String get settingsCaregiverSection => '看护人偏好';

  @override
  String get settingsRoleAndLanguage => '角色与语言';

  @override
  String get settingsTapToSet => '点击设置';

  @override
  String get settingsPlaybackSection => '播放设置';

  @override
  String get settingsPlaybackPrefs => '播放偏好';

  @override
  String get settingsAutoPlayOn => '自动播放开启';

  @override
  String get settingsAutoPlayOff => '自动播放关闭';

  @override
  String get settingsSpeed => '语速';

  @override
  String get settingsHelpSection => '帮助与反馈';

  @override
  String get settingsHelpTitle => '帮助与反馈';

  @override
  String get settingsAboutSection => '关于';

  @override
  String get settingsAboutBabyTalk => '关于 BabyTalk';

  @override
  String settingsVersion(Object version) {
    return '版本 $version';
  }

  @override
  String settingsMonthSuffix(Object months) {
    return '$months个月';
  }

  @override
  String get settingsLanguageZh => '中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get onboardingV21MentorGreeting => '小禾想帮你记录这段珍贵的成长，可以告诉我一些关于宝宝的小信息吗？';

  @override
  String get onboardingV21NameLabel => '宝宝昵称（可选）';

  @override
  String get onboardingV21NameHint => '比如：小宝、小明...';

  @override
  String get onboardingV21AgeTitle => '宝宝月龄';

  @override
  String get onboardingV21SaveButton => '保存';

  @override
  String get onboardingV21SkipButton => '稍后再说';

  @override
  String get onboardingV21NextButton => '下一步';

  @override
  String get onboardingV21SceneTitle => '今天先说一句';

  @override
  String get onboardingV21SceneHint => '选个正在发生的场景';

  @override
  String get onboardingV21DirectPhrase => '直接给一句';

  @override
  String get onboardingV21AgeEntry => '宝宝多大？可稍后补';

  @override
  String get onboardingV21AgeSkip => '先跳过';

  @override
  String get onboardingV21PracticeSubtitle => '一句就够';

  @override
  String get onboardingV21SaidButton => '说完了';

  @override
  String get onboardingV21SwapButton => '换一句';

  @override
  String get onboardingV21EndButton => '结束';

  @override
  String get onboardingV21Saved => '已保存本句';

  @override
  String get onboardingV21SkipReaction => '跳过，下一句';

  @override
  String get onboardingV21PhrasesExhausted => '句子都试过了';

  @override
  String get onboardingV21CompleteTitle => '小禾老师 / 今天已完成';

  @override
  String get onboardingV21AgainButton => '再来一句';

  @override
  String get onboardingV21DoneButton => '先到这里';

  @override
  String get onboardingV21NextTime => '下次打开，小禾会给你新的一句。';

  @override
  String get practiceOneTurnTitle => '今日一句';

  @override
  String get practiceWhenToSay => '什么时候说';

  @override
  String get practiceListenOnce => '听一下';

  @override
  String get practiceSaid => '我说了';

  @override
  String get practiceAudioPlayedOnce => '已听过一次';

  @override
  String get practiceAudioMissingInline => '这句暂时没有音频，可以直接说。';

  @override
  String get practiceAudioMissingSnack => '这句暂时没有可播放的音频。';

  @override
  String get practiceAudioUnavailableInline => '音频暂时不可用';

  @override
  String get practiceAudioUnavailableSnack => '音频暂时不可用，请直接先说这一句。';

  @override
  String get practiceSavingTrace => '正在记下这次回应…';

  @override
  String get practiceReactionPrompt => '宝宝刚刚是什么反应？';

  @override
  String get practiceNextSupportTitle => '下一句照护支持';

  @override
  String get practiceQuietFallback => '先停在这里，等下一次再继续。';

  @override
  String get practiceGardenTraceTitle => '花园留痕';
}

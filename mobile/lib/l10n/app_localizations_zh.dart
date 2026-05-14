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
  String get processing => '处理中…';

  @override
  String get localMode => '本地模式';

  @override
  String get guest => '访客';

  @override
  String get reactionCalm => '宝宝放松';

  @override
  String get reactionEngaged => '宝宝在看';

  @override
  String get reactionImitated => '宝宝模仿';

  @override
  String get reactionNeedsBreak => '先休息';

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
  String bootErrorOnboardingRead(Object error) {
    return 'onboarding 本地档案读取失败：$error';
  }

  @override
  String get bootErrorStartup => '应用启动失败，请重启后重试。';

  @override
  String get bootRetry => '重试';

  @override
  String get bootCloseTooltip => '关闭提示';

  @override
  String get homeContinuityNotConnected => '共享 continuity 暂未接通。';

  @override
  String get homeTonightTryActivity => '今晚试试把最近一次 activity 自然接起来。';

  @override
  String get homeWelcomeBack => '欢迎回来！稍后将为你推荐练习内容。';

  @override
  String get homeContinuitySharedNote =>
      '首页和花园共用同一条 continuity recommendation；返回练习后会一起刷新。';

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
  String get homeOrganizingContinuity => '正在整理共享 continuity recommendation…';

  @override
  String get homeContinuityNoActivity => '共享 continuity 尚未给出可继续的 activity。';

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
  String get homeDefaultStageSummary => '先把英语放进照护动作里，保持真实、短句、可重复。';

  @override
  String get homeFirstSeed => '第一颗种子';

  @override
  String get homeStartBathTime => '先从洗澡时间这句开始。';

  @override
  String get homeContinuityUnavailable => '共享 continuity 暂不可用';

  @override
  String homeNextAlternative(Object activityTitle) {
    return '下一步也可以切到 $activityTitle';
  }

  @override
  String get homeRecommendedActivity => '推荐活动';

  @override
  String get homeOrganizing => '整理中';

  @override
  String get homeWaitingContinuity => '等待 continuity';

  @override
  String get homeCadence => '连续节奏';

  @override
  String get homeDerivingCadence => '正在从本地事件派生 cadence';

  @override
  String get homeGardenOrganizing => '花园正在整理今天的变化';

  @override
  String get homeGardenProjecting => '先把事件投影成花圃和花朵阶段，马上就能看到结果。';

  @override
  String get homeGardenNotReady => '花园入口暂时没整理好';

  @override
  String get homeGardenKeepStable => '先保留最近一次稳定结果，你也可以稍后刷新。';

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
  String get homeGrowthFallback => '投影失败时会保留安全空态，不会让首页白屏。';

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
  String homeRecentResultDetail(Object totalEvents, Object time) {
    return '$totalEvents 条本地记录 · 最近一次 $time';
  }

  @override
  String get onboardingTitle => '给你家宝宝准备第一次英文见面';

  @override
  String get onboardingSubtitle => '只要昵称和月龄档，小禾老师就会先给你一颗适合现在阶段的 starter seed。';

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
    return '$childName 现在更适合从这个阶段开始，先用一句真实 starter phrase 试试看。';
  }

  @override
  String get onboardingWelcomeInfo => '先准备两条信息：宝宝昵称 + 月龄档。';

  @override
  String get onboardingWelcomeDetail => '完成后我会把阶段匹配和第一句 starter seed 一起交给你。';

  @override
  String get onboardingStartButton => '开始建档';

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
  String get onboardingContentLoading => '正在准备第一颗 starter seed…';

  @override
  String get onboardingContentRetry => '重新准备';

  @override
  String get onboardingAgeContinue => '看看现在更适合什么';

  @override
  String get onboardingPreviewConfirm => '确认后会先写入本地档案，再带你进入首页。';

  @override
  String get onboardingPreviewRetryHint => '如果保存失败，我会保留刚才的输入，方便你直接重试。';

  @override
  String get onboardingPreviewSeedLabel => '准备先这样开口';

  @override
  String get onboardingPreviewBack => '返回调整';

  @override
  String get onboardingSaving => '正在保存到本地';

  @override
  String get onboardingEnterHome => '进入首页';

  @override
  String get onboardingStageMatch => '阶段匹配';

  @override
  String get onboardingMentorCaption => '禾';

  @override
  String get onboardingFirstSeed => '第一颗种子';

  @override
  String get shellDrawerTooltip => '打开家庭抽屉';

  @override
  String get shellHome => '首页';

  @override
  String get shellDiscover => '发现';

  @override
  String get shellGarden => '花园';

  @override
  String get shellGrowth => '成长';

  @override
  String shellHomeName(Object name) {
    return '$name 的首页';
  }

  @override
  String get shellBabyName => '这位宝宝';

  @override
  String get shellFirstTimeDrawer => '第一次进入家庭档案';

  @override
  String get shellSharedNotConnected => '共享未接通';

  @override
  String get shellNoStageDescription => '当前还没有完整阶段说明，后续完成 onboarding 后会显示这里。';

  @override
  String get shellLocalOnlyNote =>
      '同意前，这里的昵称、月龄档和阶段仅保存在这台设备上；共享照护只会显示脱敏后的角色、phase 和上下文摘要。';

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
  String get accountLocalOnly => '仍是 local-only 档案模式';

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
  String get accountShellNote => 'Shell 可继续进入，稍后会在这里显示 consent、待同步数量和最近状态。';

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
  String get accountEntryNote =>
      '账号入口已挂到真实 shell/home；登录前不会把手机号、验证码或 session 混进 onboarding / practice 状态。';

  @override
  String accountPendingSync(Object count) {
    return '仍有 $count 条 append-only 练习事件待同步，前台会在启动、回首页、回前台和手动重试时继续尝试。';
  }

  @override
  String get accountAlignedNote =>
      '最近状态已对齐；重登时会先 bootstrap，再恢复 recent result 与继续练习位置。';

  @override
  String get accountSyncIncomplete =>
      '最近一次同步没有完成，但本地 pending 事件仍保留，可继续练习并稍后重试。';

  @override
  String get accountRevokedNote => '撤回后不会再上传或恢复远端数据；重新登录并再次同意后才会继续同步。';

  @override
  String get accountDeletedNote => '删除后远端账号不可恢复；本机仍可继续 guest/local-only 使用。';

  @override
  String get accountUpgradeNote => '服务端已拒绝当前版本；请先打开升级页面安装新版本，再返回重试同步。';

  @override
  String get accountUpgradeUnavailable => '服务端已拒绝当前版本；当前会保留升级受阻提示，但升级入口暂不可用。';

  @override
  String get accountReadFailed => '账号状态读取失败，但 onboarding / practice 路由不会因此崩溃。';

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
  String accountRecentTime(Object time) {
    return '最近 $time';
  }

  @override
  String get accountEntryLabel => '账号入口';

  @override
  String get accountS03Label => 'S03 账号 / 同意 / 同步闭环';

  @override
  String get accountRetryReadStatus => '重试读取账号状态';

  @override
  String get accountPhoneLabel => '手机号';

  @override
  String get accountCodeLabel => '验证码';

  @override
  String get accountDevStub => '开发 stub 默认 246810';

  @override
  String get accountRealLoginNote =>
      '真实登录会调用 challenge → verify → consent accept → bootstrap → batch sync；错误会留在独立 account/sync seam 中，不回写 onboarding snapshot，也不让 PracticeSessionNotifier 直接发请求。';

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
  String get accountBackToLocal => '回到 local-only';

  @override
  String get accountPreparing => '正在准备账号状态';

  @override
  String get accountKeepLocalProfile => '先保留同意前本地档案';

  @override
  String get accountVisibleNotLoggedIn => '账号入口已可见，但你还没有登录';

  @override
  String accountSignedInPending(Object phone) {
    return '已用 $phone 登录，仍有待同步事件';
  }

  @override
  String accountSignedInAligned(Object phone) {
    return '已用 $phone 登录并完成最近一次对齐';
  }

  @override
  String get accountSignedInSyncRetry => '登录已完成，但最近同步仍需重试';

  @override
  String get accountReadFailedShell => '账号状态读取失败，但当前 shell 仍可继续使用';

  @override
  String accountSignedInPendingSyncStatus(Object count) {
    return 'signed-in-pending-sync · 待同步 $count';
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
  String get householdNextStepMissing => '共享下一步缺少安全 route args，入口已停留在安全禁用态。';

  @override
  String householdRecentInteraction(Object interactionTime, Object updateTime) {
    return '最近互动 $interactionTime · 投影刷新 $updateTime';
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
  String get householdFallbackNote =>
      '共享档案、角色和最近 continuity 已退回安全空态，不会回退到错误默认 activity。';

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
  String get householdContextUnavailableNote =>
      '共享上下文暂不可用；当前不会把缺字段或坏 route args 写进 Practice/Garden。';

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
  String get householdRecentContinuity => '最近 continuity';

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
  String get discoverLoadingCatalog => '正在整理离线 activity 目录…';

  @override
  String get discoverLoadingNote => '加载只影响 Discover，不会阻塞首页、花园和成长 tab。';

  @override
  String get discoverLoadError => '目录暂时没有整理好';

  @override
  String get discoverRetryLoad => '重试加载';

  @override
  String get discoverEmpty => '目录还是空的';

  @override
  String get discoverEmptyNote => '目前没有可展示的 activity。稍后重试即可重新读取本地目录。';

  @override
  String get discoverRetryRead => '重新读取目录';

  @override
  String get discoverBrowseByActivity => '按活动浏览';

  @override
  String get discoverActivityRouteNote =>
      '每张 ActivityCard 都带着自己的 spaceId/activityId 进入练习页。';

  @override
  String get discoverSummaryMissing => '摘要暂时缺失，但这张卡仍然可以安全进入练习。';

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
  String get discoverSpaceRouteNote =>
      '每个 SpaceGridItem 会保留被点击 activity 的 route 作用域。';

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
  String get discoverInvalidCard => '这张活动卡缺少有效的 spaceId/activityId，已禁止导航。';

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
  String get gardenProjectingNote => '事件会先被投影成花圃、花朵和阶段，再温柔地出现在这里。';

  @override
  String get gardenContinuityNotConnected => 'continuity 未接通';

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
    return '最新影响来自 $impactTitle；回来继续会去 $activityTitle（$reason';
  }

  @override
  String get gardenContinuitySharedNote =>
      '花园会和首页一起，把你带回同一条 continuity recommendation。';

  @override
  String get gardenSharedContinuity => '共享 continuity';

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
    return '$count 次练习事件';
  }

  @override
  String gardenActivityProgress(Object completed, Object total, Object events) {
    return '已连起 $completed/$total 句 · $events 次记录';
  }

  @override
  String get gardenSharedContinuityUnavailable => '共享 continuity 暂不可用';

  @override
  String get gardenContinueWatering => '继续浇灌';

  @override
  String get gardenContinueNote =>
      '如果你现在继续练习，Home 与 Garden 会沿着同一份 recommendation 一起更新。';

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
  String get practiceCurrentPhrases => '当前练习中的短语';

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
  String get mentorChatNote =>
      'Mentor 只返回一条 text-first 受控回应；不会在面板里展示 raw provider 输出。';

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
  String phraseAudioStatus(Object status) {
    return '音频 · $status';
  }

  @override
  String phraseSaveStatus(Object status) {
    return '保存 · $status';
  }

  @override
  String get phraseNote =>
      '点按播放真实本地音频，再选择宝宝反应。状态会直接暴露为 idle / playing / completed / error。';

  @override
  String get phraseReactionLabel => '宝宝现在的反应';

  @override
  String get growthRefreshFailed => '成长页刷新失败，先保留上次稳定结果。';

  @override
  String get growthAutoDiary => '自动日记';

  @override
  String get growthNoDiary => '还没有自动日记，第一次练习完成后会在这里记下变化。';

  @override
  String get growthSceneProgress => '场景进展';

  @override
  String get growthNoScene => '花圃还没醒来，所以暂时没有场景进展。';

  @override
  String get growthMilestone => '里程碑';

  @override
  String get growthMilestoneNote => '里程碑会在真实练习后逐步点亮。';

  @override
  String get growthNotScore => '成长不是分数，而是一串串被记住的变化。';

  @override
  String get growthNote => '这里会按时间整理自动日记、空间进展和里程碑，帮助你回看今天发生过什么。';

  @override
  String get growthOrganizing => '成长页正在整理练习记录';

  @override
  String get growthOrganizingNote => '等投影准备好后，这里会出现最新一次变化、自动日记和里程碑。';

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
  String get inviteGenerateNote =>
      '生成真实 invite link 后，次照护者可通过链接接受邀请并看到共享宝宝档案摘要。';

  @override
  String get inviteCaregiverNote => '你当前是次照护者，只读查看共享照护内容；如需新增成员，请让主照护者操作。';

  @override
  String get invitePermissionNote => '角色或权限尚未准备好；邀请入口保持禁用，并在失败时保留明确文案。';

  @override
  String get inviteLabel => '照护邀请';

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
  String get sharePrivacyNote => '分享内容会自动脱敏，不包含昵称、安装号或调试信息。';

  @override
  String get activationFrameLabel => 'C3 激活框';

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
  String get accountEntryReadFailedShell => '账号状态读取失败，但当前 shell 仍可继续使用';

  @override
  String get accountEntryTitle => '账号入口';

  @override
  String get accountEntryS03Label => 'S03 账号 / 同意 / 同步闭环';

  @override
  String get accountEntrySubmitMessage => '登录已完成，可返回首页查看最近恢复结果。';

  @override
  String get accountEntrySubmitButton => '提交';

  @override
  String get shellDiscoverTooltip => '发现活动';

  @override
  String get shellPractice => '练习';

  @override
  String shellPracticeName(Object name) {
    return '$name 的练习';
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
    return '最新影响来自 $impactTitle；回来继续会去 $activityTitle（$reason）。';
  }

  @override
  String get discoverInvalidCardError => '这张活动卡缺少有效的 spaceId/activityId，已禁止导航。';

  @override
  String discoverOpenActivityError(Object title, Object error) {
    return '打开 $title 失败：$error';
  }

  @override
  String sharePhraseTodayLabel(Object phrase) {
    return '今天说的一句：$phrase';
  }

  @override
  String get mentorSuggestionTabSemantics => '建议标签页';

  @override
  String get mentorChatTabSemantics => '聊天标签页';
}

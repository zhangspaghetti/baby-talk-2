import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @mentorName.
  ///
  /// In zh, this message translates to:
  /// **'小禾老师'**
  String get mentorName;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @viewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get viewAll;

  /// No description provided for @processing.
  ///
  /// In zh, this message translates to:
  /// **'处理中…'**
  String get processing;

  /// No description provided for @localMode.
  ///
  /// In zh, this message translates to:
  /// **'本地模式'**
  String get localMode;

  /// No description provided for @guest.
  ///
  /// In zh, this message translates to:
  /// **'访客'**
  String get guest;

  /// No description provided for @reactionCooperating.
  ///
  /// In zh, this message translates to:
  /// **'配合'**
  String get reactionCooperating;

  /// No description provided for @reactionHesitant.
  ///
  /// In zh, this message translates to:
  /// **'犹豫'**
  String get reactionHesitant;

  /// No description provided for @reactionResisting.
  ///
  /// In zh, this message translates to:
  /// **'不想'**
  String get reactionResisting;

  /// No description provided for @reactionNoResponse.
  ///
  /// In zh, this message translates to:
  /// **'没反应'**
  String get reactionNoResponse;

  /// No description provided for @reactionOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get reactionOther;

  /// No description provided for @sharedAttributionNextStep.
  ///
  /// In zh, this message translates to:
  /// **'共享归因与下一步'**
  String get sharedAttributionNextStep;

  /// No description provided for @enterSharedNextStep.
  ///
  /// In zh, this message translates to:
  /// **'进入共享下一步'**
  String get enterSharedNextStep;

  /// No description provided for @continueEntryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'继续入口暂不可用'**
  String get continueEntryUnavailable;

  /// No description provided for @practiceEntryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'照护入口暂时不可用。'**
  String get practiceEntryUnavailable;

  /// No description provided for @bootErrorUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知启动错误'**
  String get bootErrorUnknown;

  /// No description provided for @bootErrorOnboardingRead.
  ///
  /// In zh, this message translates to:
  /// **'本地档案读取失败，请重试。'**
  String get bootErrorOnboardingRead;

  /// No description provided for @bootErrorStartup.
  ///
  /// In zh, this message translates to:
  /// **'应用启动失败，请重启后重试。'**
  String get bootErrorStartup;

  /// No description provided for @bootRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get bootRetry;

  /// No description provided for @bootCloseTooltip.
  ///
  /// In zh, this message translates to:
  /// **'关闭提示'**
  String get bootCloseTooltip;

  /// No description provided for @homeContinuityNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'继续练习暂时还没准备好。'**
  String get homeContinuityNotConnected;

  /// No description provided for @homeTonightTryActivity.
  ///
  /// In zh, this message translates to:
  /// **'今晚试试把最近一次练习自然接起来。'**
  String get homeTonightTryActivity;

  /// No description provided for @homeWelcomeBack.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来！稍后将为你推荐练习内容。'**
  String get homeWelcomeBack;

  /// No description provided for @homeContinuitySharedNote.
  ///
  /// In zh, this message translates to:
  /// **'首页和花园会一起记住这次练习，回来后同步更新。'**
  String get homeContinuitySharedNote;

  /// No description provided for @homePracticeUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法获取照护建议，请稍后重试。'**
  String get homePracticeUnavailable;

  /// No description provided for @homeReorganize.
  ///
  /// In zh, this message translates to:
  /// **'重新整理'**
  String get homeReorganize;

  /// No description provided for @homeShareGrowthFamily.
  ///
  /// In zh, this message translates to:
  /// **'把这次成长分享给家人'**
  String get homeShareGrowthFamily;

  /// No description provided for @homeShareWaitStable.
  ///
  /// In zh, this message translates to:
  /// **'等最近成长或继续建议整理稳定后，再生成一条脱敏分享链接。'**
  String get homeShareWaitStable;

  /// No description provided for @homePracticeAdviceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法获取练习建议。'**
  String get homePracticeAdviceUnavailable;

  /// No description provided for @homeOrganizingContinuity.
  ///
  /// In zh, this message translates to:
  /// **'正在整理适合继续的练习…'**
  String get homeOrganizingContinuity;

  /// No description provided for @homeContinuityNoActivity.
  ///
  /// In zh, this message translates to:
  /// **'暂时还没有下一条可继续的练习。'**
  String get homeContinuityNoActivity;

  /// No description provided for @homeContinuityWarningNote.
  ///
  /// In zh, this message translates to:
  /// **'有一小段练习记录暂时没整理好，当前建议仍可继续。'**
  String get homeContinuityWarningNote;

  /// No description provided for @homeContinuityDisabledNote.
  ///
  /// In zh, this message translates to:
  /// **'继续练习暂时没准备好，请稍后再试。'**
  String get homeContinuityDisabledNote;

  /// No description provided for @homeContinuityFallbackNote.
  ///
  /// In zh, this message translates to:
  /// **'已经为你换到一条稳定可继续的练习。'**
  String get homeContinuityFallbackNote;

  /// No description provided for @homeStartPractice.
  ///
  /// In zh, this message translates to:
  /// **'开始照护'**
  String get homeStartPractice;

  /// No description provided for @homeContinuePractice.
  ///
  /// In zh, this message translates to:
  /// **'继续照护'**
  String get homeContinuePractice;

  /// No description provided for @homeTodaySceneSemantics.
  ///
  /// In zh, this message translates to:
  /// **'今日场景：{activityTitle}'**
  String homeTodaySceneSemantics(Object activityTitle);

  /// No description provided for @homeLocalOnlyBanner.
  ///
  /// In zh, this message translates to:
  /// **'{childName} 的昵称、月龄档和阶段在同意前仅保存在这台设备上。'**
  String homeLocalOnlyBanner(Object childName);

  /// No description provided for @homePersonalizedHeading.
  ///
  /// In zh, this message translates to:
  /// **'{childName}，今天先从一句自然的英文开始。'**
  String homePersonalizedHeading(Object childName);

  /// No description provided for @homeDailyPhraseCueLabel.
  ///
  /// In zh, this message translates to:
  /// **'今天继续这一句'**
  String get homeDailyPhraseCueLabel;

  /// No description provided for @homeDailyPhraseCueBody.
  ///
  /// In zh, this message translates to:
  /// **'回到照护场景时，再说一次就好；花园会从这颗种子继续长。'**
  String get homeDailyPhraseCueBody;

  /// No description provided for @homeDefaultStageSummary.
  ///
  /// In zh, this message translates to:
  /// **'先把英语放进照护动作里，保持真实、短句、可重复。'**
  String get homeDefaultStageSummary;

  /// No description provided for @homeFirstSeed.
  ///
  /// In zh, this message translates to:
  /// **'第一颗种子'**
  String get homeFirstSeed;

  /// No description provided for @homeStartBathTime.
  ///
  /// In zh, this message translates to:
  /// **'先从洗澡时间这句开始。'**
  String get homeStartBathTime;

  /// No description provided for @homeContinuityUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'继续照护暂时不可用'**
  String get homeContinuityUnavailable;

  /// No description provided for @homeContinuationRecent.
  ///
  /// In zh, this message translates to:
  /// **'接着刚才练过的场景'**
  String get homeContinuationRecent;

  /// No description provided for @homeContinuationNextIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'接上还没说完的活动'**
  String get homeContinuationNextIncomplete;

  /// No description provided for @homeContinuationStarter.
  ///
  /// In zh, this message translates to:
  /// **'回到第一颗种子'**
  String get homeContinuationStarter;

  /// No description provided for @homeContinuationSafeFallback.
  ///
  /// In zh, this message translates to:
  /// **'先从稳定活动开始'**
  String get homeContinuationSafeFallback;

  /// No description provided for @homeNextAlternative.
  ///
  /// In zh, this message translates to:
  /// **'下一步也可以切到 {activityTitle}'**
  String homeNextAlternative(Object activityTitle);

  /// No description provided for @homeRecommendedActivity.
  ///
  /// In zh, this message translates to:
  /// **'推荐活动'**
  String get homeRecommendedActivity;

  /// No description provided for @homeOrganizing.
  ///
  /// In zh, this message translates to:
  /// **'整理中'**
  String get homeOrganizing;

  /// No description provided for @homeWaitingContinuity.
  ///
  /// In zh, this message translates to:
  /// **'等待下一次练习'**
  String get homeWaitingContinuity;

  /// No description provided for @homeCadence.
  ///
  /// In zh, this message translates to:
  /// **'连续节奏'**
  String get homeCadence;

  /// No description provided for @homeDerivingCadence.
  ///
  /// In zh, this message translates to:
  /// **'正在整理最近一周的练习节奏'**
  String get homeDerivingCadence;

  /// No description provided for @homeGardenOrganizing.
  ///
  /// In zh, this message translates to:
  /// **'花园正在整理今天的变化'**
  String get homeGardenOrganizing;

  /// No description provided for @homeGardenProjecting.
  ///
  /// In zh, this message translates to:
  /// **'花圃正在整理最近练习，马上就能看到结果。'**
  String get homeGardenProjecting;

  /// No description provided for @homeGardenNotReady.
  ///
  /// In zh, this message translates to:
  /// **'花园入口暂时没整理好'**
  String get homeGardenNotReady;

  /// No description provided for @homeGardenKeepStable.
  ///
  /// In zh, this message translates to:
  /// **'先保留最近一次稳定结果，你也可以稍后刷新。'**
  String get homeGardenKeepStable;

  /// No description provided for @homeGardenWarningNote.
  ///
  /// In zh, this message translates to:
  /// **'有一小段练习记录暂时没整理好，花圃先保留可用结果。'**
  String get homeGardenWarningNote;

  /// No description provided for @homeGardenStartFirst.
  ///
  /// In zh, this message translates to:
  /// **'你的花园会从第一句开口开始'**
  String get homeGardenStartFirst;

  /// No description provided for @homeGardenNoPractice.
  ///
  /// In zh, this message translates to:
  /// **'还没有练习记录，先说出一句 Warm water.，花圃就会醒来。'**
  String get homeGardenNoPractice;

  /// No description provided for @homeGardenReady.
  ///
  /// In zh, this message translates to:
  /// **'花园入口已准备好'**
  String get homeGardenReady;

  /// No description provided for @homeGardenChanges.
  ///
  /// In zh, this message translates to:
  /// **'花圃已经有变化，后续会继续接入完整花园页。'**
  String get homeGardenChanges;

  /// No description provided for @homeGardenSpaceStage.
  ///
  /// In zh, this message translates to:
  /// **'{spaceTitle} · {stageLabel}'**
  String homeGardenSpaceStage(Object spaceTitle, Object stageLabel);

  /// No description provided for @homeGardenActivityDetail.
  ///
  /// In zh, this message translates to:
  /// **'{activityTitle} 现在是\"{stageLabel}\"，{careNote}'**
  String homeGardenActivityDetail(
    Object activityTitle,
    Object stageLabel,
    Object careNote,
  );

  /// No description provided for @homeGrowthGarden.
  ///
  /// In zh, this message translates to:
  /// **'🌱 成长花园'**
  String get homeGrowthGarden;

  /// No description provided for @homeGrowthUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'最近成长摘要暂时不可用'**
  String get homeGrowthUnavailable;

  /// No description provided for @homeGrowthFallback.
  ///
  /// In zh, this message translates to:
  /// **'花圃暂时没整理好，会先保留当前结果。'**
  String get homeGrowthFallback;

  /// No description provided for @homeGrowthPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'最近成长会写在这里'**
  String get homeGrowthPlaceholder;

  /// No description provided for @homeGrowthAfterPractice.
  ///
  /// In zh, this message translates to:
  /// **'完成一次练习后，这里会告诉你这次开口让什么发生了变化。'**
  String get homeGrowthAfterPractice;

  /// No description provided for @homeGrowthSummaryLabel.
  ///
  /// In zh, this message translates to:
  /// **'最近成长摘要'**
  String get homeGrowthSummaryLabel;

  /// No description provided for @homeRecentLocalResult.
  ///
  /// In zh, this message translates to:
  /// **'最近一次本地结果'**
  String get homeRecentLocalResult;

  /// No description provided for @homeNoLocalRecords.
  ///
  /// In zh, this message translates to:
  /// **'还没有本地练习记录，第一次打开也会看到安全空态。'**
  String get homeNoLocalRecords;

  /// No description provided for @homeRecentFallbackNote.
  ///
  /// In zh, this message translates to:
  /// **'最近结果暂时没整理好，先为你保留一条可继续的练习。'**
  String get homeRecentFallbackNote;

  /// No description provided for @homeRecentResultDetail.
  ///
  /// In zh, this message translates to:
  /// **'{totalEvents} 条本地记录 · 最近一次 {time}'**
  String homeRecentResultDetail(Object totalEvents, Object time);

  /// No description provided for @onboardingTitle.
  ///
  /// In zh, this message translates to:
  /// **'先拿一句今天能和宝宝说的英文'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只要昵称和大概月龄，小禾老师会先在本机准备第一句。'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'同意前仅保存在这台设备，不需要精确生日。'**
  String get onboardingLocalOnly;

  /// No description provided for @onboardingMentorGreeting.
  ///
  /// In zh, this message translates to:
  /// **'你好，我会先帮你把英语放进今天就能开口的照护节奏里。'**
  String get onboardingMentorGreeting;

  /// No description provided for @onboardingAskName.
  ///
  /// In zh, this message translates to:
  /// **'我先怎么称呼宝宝？先用一个你最顺口的小昵称就好。'**
  String get onboardingAskName;

  /// No description provided for @onboardingAskAge.
  ///
  /// In zh, this message translates to:
  /// **'现在大概几个月？我会用月龄档给你匹配阶段，不会要求精确生日。'**
  String get onboardingAskAge;

  /// No description provided for @onboardingStagePreview.
  ///
  /// In zh, this message translates to:
  /// **'{childName} 现在更适合从这一类短句开始，先用一句真实照护里的英文试试看。'**
  String onboardingStagePreview(Object childName);

  /// No description provided for @onboardingWelcomeInfo.
  ///
  /// In zh, this message translates to:
  /// **'先准备两条信息：宝宝昵称 + 月龄档。'**
  String get onboardingWelcomeInfo;

  /// No description provided for @onboardingWelcomeDetail.
  ///
  /// In zh, this message translates to:
  /// **'完成后会看到第一句英文、什么时候说，以及怎么接住宝宝反应。'**
  String get onboardingWelcomeDetail;

  /// No description provided for @onboardingStartButton.
  ///
  /// In zh, this message translates to:
  /// **'先开始'**
  String get onboardingStartButton;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'宝宝昵称'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：米米、果果'**
  String get onboardingNameHint;

  /// No description provided for @onboardingNameHelp.
  ///
  /// In zh, this message translates to:
  /// **'先用一个顺口的小名就够了，之后还可以再改。'**
  String get onboardingNameHelp;

  /// No description provided for @onboardingBack.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get onboardingBack;

  /// No description provided for @onboardingContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get onboardingContinue;

  /// No description provided for @onboardingAgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'月龄快选'**
  String get onboardingAgeTitle;

  /// No description provided for @onboardingAgeHelp.
  ///
  /// In zh, this message translates to:
  /// **'不需要精确到哪一天，先选最接近的一档就可以。'**
  String get onboardingAgeHelp;

  /// No description provided for @onboardingAgeMonths.
  ///
  /// In zh, this message translates to:
  /// **'{months}月左右'**
  String onboardingAgeMonths(Object months);

  /// No description provided for @onboardingContentLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在准备第一句…'**
  String get onboardingContentLoading;

  /// No description provided for @onboardingContentRetry.
  ///
  /// In zh, this message translates to:
  /// **'重新准备'**
  String get onboardingContentRetry;

  /// No description provided for @onboardingAgeContinue.
  ///
  /// In zh, this message translates to:
  /// **'准备第一句'**
  String get onboardingAgeContinue;

  /// No description provided for @onboardingPreviewConfirm.
  ///
  /// In zh, this message translates to:
  /// **'先播放一下，再说一次；我会把这次开始保存在本机。'**
  String get onboardingPreviewConfirm;

  /// No description provided for @onboardingPreviewRetryHint.
  ///
  /// In zh, this message translates to:
  /// **'说完可以点“我说了”，不用等宝宝立刻回应。'**
  String get onboardingPreviewRetryHint;

  /// No description provided for @onboardingPreviewSeedLabel.
  ///
  /// In zh, this message translates to:
  /// **'第一句可以先这样说'**
  String get onboardingPreviewSeedLabel;

  /// No description provided for @onboardingMiniSceneActionHint.
  ///
  /// In zh, this message translates to:
  /// **'洗澡、换衣或抱起宝宝时，都可以先轻轻说这一句。'**
  String get onboardingMiniSceneActionHint;

  /// No description provided for @onboardingMiniScenePlay.
  ///
  /// In zh, this message translates to:
  /// **'播放一下'**
  String get onboardingMiniScenePlay;

  /// No description provided for @onboardingMiniScenePlaying.
  ///
  /// In zh, this message translates to:
  /// **'播放中'**
  String get onboardingMiniScenePlaying;

  /// No description provided for @onboardingMiniSceneSaid.
  ///
  /// In zh, this message translates to:
  /// **'我说了'**
  String get onboardingMiniSceneSaid;

  /// No description provided for @onboardingMiniSceneRecording.
  ///
  /// In zh, this message translates to:
  /// **'记录中'**
  String get onboardingMiniSceneRecording;

  /// No description provided for @onboardingMiniSceneRecorded.
  ///
  /// In zh, this message translates to:
  /// **'已在本机种下第一颗种子，首页会接着这句继续。'**
  String get onboardingMiniSceneRecorded;

  /// No description provided for @onboardingSayFirstBeforeHome.
  ///
  /// In zh, this message translates to:
  /// **'先说一次'**
  String get onboardingSayFirstBeforeHome;

  /// No description provided for @onboardingPreviewBack.
  ///
  /// In zh, this message translates to:
  /// **'返回调整'**
  String get onboardingPreviewBack;

  /// No description provided for @onboardingSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存到本地'**
  String get onboardingSaving;

  /// No description provided for @onboardingEnterHome.
  ///
  /// In zh, this message translates to:
  /// **'进入首页继续'**
  String get onboardingEnterHome;

  /// No description provided for @onboardingStageMatch.
  ///
  /// In zh, this message translates to:
  /// **'现在适合这样开始'**
  String get onboardingStageMatch;

  /// No description provided for @onboardingMentorCaption.
  ///
  /// In zh, this message translates to:
  /// **'禾'**
  String get onboardingMentorCaption;

  /// No description provided for @onboardingFirstSeed.
  ///
  /// In zh, this message translates to:
  /// **'第一颗种子'**
  String get onboardingFirstSeed;

  /// No description provided for @onboardingMentorMessageSemantics.
  ///
  /// In zh, this message translates to:
  /// **'小禾老师引导消息：{message}'**
  String onboardingMentorMessageSemantics(Object message);

  /// No description provided for @onboardingMiniSeedCardSemantics.
  ///
  /// In zh, this message translates to:
  /// **'第一颗种子：{phrase}'**
  String onboardingMiniSeedCardSemantics(Object phrase);

  /// No description provided for @onboardingStageMatchSemantics.
  ///
  /// In zh, this message translates to:
  /// **'现在适合这样开始：{stageTitle}。{summary}'**
  String onboardingStageMatchSemantics(Object stageTitle, Object summary);

  /// No description provided for @onboardingFirstPhraseActionErrorSemantics.
  ///
  /// In zh, this message translates to:
  /// **'第一句记录失败：{message}'**
  String onboardingFirstPhraseActionErrorSemantics(Object message);

  /// No description provided for @onboardingSaveErrorSemantics.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{message}'**
  String onboardingSaveErrorSemantics(Object message);

  /// No description provided for @shellDrawerTooltip.
  ///
  /// In zh, this message translates to:
  /// **'打开家庭抽屉'**
  String get shellDrawerTooltip;

  /// No description provided for @shellHome.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get shellHome;

  /// No description provided for @shellDiscover.
  ///
  /// In zh, this message translates to:
  /// **'场景'**
  String get shellDiscover;

  /// No description provided for @shellGarden.
  ///
  /// In zh, this message translates to:
  /// **'花园'**
  String get shellGarden;

  /// No description provided for @shellGrowth.
  ///
  /// In zh, this message translates to:
  /// **'成长'**
  String get shellGrowth;

  /// No description provided for @shellHomeName.
  ///
  /// In zh, this message translates to:
  /// **'{name} 的今天'**
  String shellHomeName(Object name);

  /// No description provided for @shellBabyName.
  ///
  /// In zh, this message translates to:
  /// **'这位宝宝'**
  String get shellBabyName;

  /// No description provided for @shellFirstTimeDrawer.
  ///
  /// In zh, this message translates to:
  /// **'第一次进入家庭档案'**
  String get shellFirstTimeDrawer;

  /// No description provided for @shellSharedNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'共享未接通'**
  String get shellSharedNotConnected;

  /// No description provided for @shellSharedStatusReady.
  ///
  /// In zh, this message translates to:
  /// **'共享已接通'**
  String get shellSharedStatusReady;

  /// No description provided for @shellSharedStatusWaiting.
  ///
  /// In zh, this message translates to:
  /// **'邀请待确认'**
  String get shellSharedStatusWaiting;

  /// No description provided for @shellSharedStatusUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'共享暂时不可用'**
  String get shellSharedStatusUnavailable;

  /// No description provided for @shellSharedStatusReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅可查看共享'**
  String get shellSharedStatusReadOnly;

  /// No description provided for @shellSharedStatusPending.
  ///
  /// In zh, this message translates to:
  /// **'共享待同步'**
  String get shellSharedStatusPending;

  /// No description provided for @shellNoStageDescription.
  ///
  /// In zh, this message translates to:
  /// **'完成首次设置后，这里会显示更合适的阶段说明。'**
  String get shellNoStageDescription;

  /// No description provided for @shellLocalOnlyNote.
  ///
  /// In zh, this message translates to:
  /// **'同意前，这里的昵称、月龄档和阶段仅保存在这台设备上；共享照护只会显示脱敏后的角色和共享摘要。'**
  String get shellLocalOnlyNote;

  /// No description provided for @shellSharedProfile.
  ///
  /// In zh, this message translates to:
  /// **'共享家庭档案'**
  String get shellSharedProfile;

  /// No description provided for @shellFamilyProfile.
  ///
  /// In zh, this message translates to:
  /// **'家庭档案'**
  String get shellFamilyProfile;

  /// No description provided for @shellAgeBucket.
  ///
  /// In zh, this message translates to:
  /// **'月龄档'**
  String get shellAgeBucket;

  /// No description provided for @shellNotFilled.
  ///
  /// In zh, this message translates to:
  /// **'未填写'**
  String get shellNotFilled;

  /// No description provided for @shellCurrentStage.
  ///
  /// In zh, this message translates to:
  /// **'当前阶段'**
  String get shellCurrentStage;

  /// No description provided for @shellPendingMatch.
  ///
  /// In zh, this message translates to:
  /// **'待匹配'**
  String get shellPendingMatch;

  /// No description provided for @shellSharedRole.
  ///
  /// In zh, this message translates to:
  /// **'共享角色'**
  String get shellSharedRole;

  /// No description provided for @shellPendingSync.
  ///
  /// In zh, this message translates to:
  /// **'待同步'**
  String get shellPendingSync;

  /// No description provided for @shellDrawerNote.
  ///
  /// In zh, this message translates to:
  /// **'Drawer 现在会直接显示 invite CTA、角色 badge、最近是谁完成了什么，以及共享下一步是否安全可进。'**
  String get shellDrawerNote;

  /// No description provided for @shellAvatarHome.
  ///
  /// In zh, this message translates to:
  /// **'家'**
  String get shellAvatarHome;

  /// No description provided for @accountTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号与同步'**
  String get accountTitle;

  /// No description provided for @accountViewStatus.
  ///
  /// In zh, this message translates to:
  /// **'查看账号状态'**
  String get accountViewStatus;

  /// No description provided for @accountRegisterLogin.
  ///
  /// In zh, this message translates to:
  /// **'注册 / 登录'**
  String get accountRegisterLogin;

  /// No description provided for @accountRetryRead.
  ///
  /// In zh, this message translates to:
  /// **'重试读取'**
  String get accountRetryRead;

  /// No description provided for @accountRetrySync.
  ///
  /// In zh, this message translates to:
  /// **'重试同步'**
  String get accountRetrySync;

  /// No description provided for @accountReading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取账号状态'**
  String get accountReading;

  /// No description provided for @accountLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'仍是本机档案模式'**
  String get accountLocalOnly;

  /// No description provided for @accountNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'当前未登录账号'**
  String get accountNotLoggedIn;

  /// No description provided for @accountSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录 {phone}'**
  String accountSignedIn(Object phone);

  /// No description provided for @accountSyncRetryNeeded.
  ///
  /// In zh, this message translates to:
  /// **'同步仍需重试'**
  String get accountSyncRetryNeeded;

  /// No description provided for @accountConsentRevoked.
  ///
  /// In zh, this message translates to:
  /// **'同意已撤回'**
  String get accountConsentRevoked;

  /// No description provided for @accountDeleted.
  ///
  /// In zh, this message translates to:
  /// **'账号已删除'**
  String get accountDeleted;

  /// No description provided for @accountUpgradeNeeded.
  ///
  /// In zh, this message translates to:
  /// **'当前版本需要升级'**
  String get accountUpgradeNeeded;

  /// No description provided for @accountStatusUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'账号状态暂时不可读'**
  String get accountStatusUnreadable;

  /// No description provided for @accountShellNote.
  ///
  /// In zh, this message translates to:
  /// **'账号状态准备中；你仍可以先继续练习，稍后这里会显示同步进展。'**
  String get accountShellNote;

  /// No description provided for @accountCurrentProfile.
  ///
  /// In zh, this message translates to:
  /// **'当前档案'**
  String get accountCurrentProfile;

  /// No description provided for @accountProfileName.
  ///
  /// In zh, this message translates to:
  /// **'{name} 的档案'**
  String accountProfileName(Object name);

  /// No description provided for @accountLocalOnlyNote.
  ///
  /// In zh, this message translates to:
  /// **'{prefix} 仍只保存在本机；现在可以先继续练习，稍后再补账号与同意。'**
  String accountLocalOnlyNote(Object prefix);

  /// No description provided for @accountEntryNote.
  ///
  /// In zh, this message translates to:
  /// **'登录前，手机号和验证码只用于账号流程，不会影响本机练习记录。'**
  String get accountEntryNote;

  /// No description provided for @accountPendingSync.
  ///
  /// In zh, this message translates to:
  /// **'仍有 {count} 条练习记录待同步，打开应用、回到首页或手动重试时会继续尝试。'**
  String accountPendingSync(Object count);

  /// No description provided for @accountAlignedNote.
  ///
  /// In zh, this message translates to:
  /// **'最近状态已对齐；重新登录后会恢复最近结果和继续练习位置。'**
  String get accountAlignedNote;

  /// No description provided for @accountSyncIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'最近一次同步没有完成，但本机练习记录仍保留，可继续练习并稍后重试。'**
  String get accountSyncIncomplete;

  /// No description provided for @accountRevokedNote.
  ///
  /// In zh, this message translates to:
  /// **'撤回后不会再上传或恢复远端数据；重新登录并再次同意后才会继续同步。'**
  String get accountRevokedNote;

  /// No description provided for @accountDeletedNote.
  ///
  /// In zh, this message translates to:
  /// **'删除后账号不可恢复；本机仍可继续保留练习。'**
  String get accountDeletedNote;

  /// No description provided for @accountUpgradeNote.
  ///
  /// In zh, this message translates to:
  /// **'服务端已拒绝当前版本；请先安装新版本，再返回这里继续同步。'**
  String get accountUpgradeNote;

  /// No description provided for @accountUpgradeUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'服务端已拒绝当前版本；升级入口暂不可用，请稍后重试或联系支持。'**
  String get accountUpgradeUnavailable;

  /// No description provided for @accountUpgradeReassurance.
  ///
  /// In zh, this message translates to:
  /// **'升级等待期间，本机练习记录仍会保留，你可以继续在本机使用。'**
  String get accountUpgradeReassurance;

  /// No description provided for @accountReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'账号状态暂时没有读取成功；你仍可以继续当前练习，稍后再重试。'**
  String get accountReadFailed;

  /// No description provided for @accountReadFailedPrimary.
  ///
  /// In zh, this message translates to:
  /// **'账号状态暂时不可读；先重试读取即可，不会影响本机练习记录。'**
  String get accountReadFailedPrimary;

  /// No description provided for @accountReadRetryGuidance.
  ///
  /// In zh, this message translates to:
  /// **'重试只会重新读取账号状态，不会改动本机练习记录。'**
  String get accountReadRetryGuidance;

  /// No description provided for @accountPendingSyncCount.
  ///
  /// In zh, this message translates to:
  /// **'待同步 {count}'**
  String accountPendingSyncCount(Object count);

  /// No description provided for @accountSyncedCount.
  ///
  /// In zh, this message translates to:
  /// **'已同步 {count}'**
  String accountSyncedCount(Object count);

  /// No description provided for @accountFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'失败 {count}'**
  String accountFailedCount(Object count);

  /// No description provided for @accountSyncChipGuidance.
  ///
  /// In zh, this message translates to:
  /// **'待同步和失败不会影响当前练习；有空时点“重试同步”即可继续推进。'**
  String get accountSyncChipGuidance;

  /// No description provided for @accountLifecycleChipGuidance.
  ///
  /// In zh, this message translates to:
  /// **'状态已变更（如撤回同意或账号删除）；芯片仅展示本机统计，不代表可继续同步。'**
  String get accountLifecycleChipGuidance;

  /// No description provided for @accountReadErrorChipGuidance.
  ///
  /// In zh, this message translates to:
  /// **'当前账号状态读取异常；芯片仅供参考，可稍后重试读取。'**
  String get accountReadErrorChipGuidance;

  /// No description provided for @accountRecentTime.
  ///
  /// In zh, this message translates to:
  /// **'最近 {time}'**
  String accountRecentTime(Object time);

  /// No description provided for @accountSyncPhaseUpdated.
  ///
  /// In zh, this message translates to:
  /// **'同步状态已更新'**
  String get accountSyncPhaseUpdated;

  /// No description provided for @accountEntryLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号入口'**
  String get accountEntryLabel;

  /// No description provided for @accountS03Label.
  ///
  /// In zh, this message translates to:
  /// **'账号与同步设置'**
  String get accountS03Label;

  /// No description provided for @accountRetryReadStatus.
  ///
  /// In zh, this message translates to:
  /// **'重试读取账号状态'**
  String get accountRetryReadStatus;

  /// No description provided for @accountPhoneLabel.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get accountPhoneLabel;

  /// No description provided for @accountCodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get accountCodeLabel;

  /// No description provided for @accountDevStub.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位验证码'**
  String get accountDevStub;

  /// No description provided for @accountRealLoginNote.
  ///
  /// In zh, this message translates to:
  /// **'登录只会接入账号同步，不会清空本机练习记录；如果出错，你仍会停留在账号页并可继续当前练习。'**
  String get accountRealLoginNote;

  /// No description provided for @accountLastError.
  ///
  /// In zh, this message translates to:
  /// **'最近错误：{error}'**
  String accountLastError(Object error);

  /// No description provided for @accountLoginComplete.
  ///
  /// In zh, this message translates to:
  /// **'登录已完成，可返回首页查看最近恢复结果。'**
  String get accountLoginComplete;

  /// No description provided for @accountLoginConsent.
  ///
  /// In zh, this message translates to:
  /// **'登录并同意'**
  String get accountLoginConsent;

  /// No description provided for @accountRevokeConsent.
  ///
  /// In zh, this message translates to:
  /// **'撤回同意'**
  String get accountRevokeConsent;

  /// No description provided for @accountDeleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'删除账号'**
  String get accountDeleteAccount;

  /// No description provided for @accountLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出为未登录'**
  String get accountLogout;

  /// No description provided for @accountBackToLocal.
  ///
  /// In zh, this message translates to:
  /// **'回到本机档案'**
  String get accountBackToLocal;

  /// No description provided for @accountPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备账号状态'**
  String get accountPreparing;

  /// No description provided for @accountKeepLocalProfile.
  ///
  /// In zh, this message translates to:
  /// **'先保留同意前本地档案'**
  String get accountKeepLocalProfile;

  /// No description provided for @accountVisibleNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'账号入口已可见，但你还没有登录'**
  String get accountVisibleNotLoggedIn;

  /// No description provided for @accountSignedInPending.
  ///
  /// In zh, this message translates to:
  /// **'已用 {phone} 登录，仍有练习记录待同步'**
  String accountSignedInPending(Object phone);

  /// No description provided for @accountSignedInAligned.
  ///
  /// In zh, this message translates to:
  /// **'已用 {phone} 登录并完成最近一次对齐'**
  String accountSignedInAligned(Object phone);

  /// No description provided for @accountSignedInSyncRetry.
  ///
  /// In zh, this message translates to:
  /// **'登录已完成，但最近同步仍需重试'**
  String get accountSignedInSyncRetry;

  /// No description provided for @accountReadFailedShell.
  ///
  /// In zh, this message translates to:
  /// **'账号状态读取失败，但当前页面仍可继续使用'**
  String get accountReadFailedShell;

  /// No description provided for @accountSignedInPendingSyncStatus.
  ///
  /// In zh, this message translates to:
  /// **'已登录 · 待同步 {count}'**
  String accountSignedInPendingSyncStatus(Object count);

  /// No description provided for @householdPrimaryCaregiver.
  ///
  /// In zh, this message translates to:
  /// **'主照护者'**
  String get householdPrimaryCaregiver;

  /// No description provided for @householdCaregiver.
  ///
  /// In zh, this message translates to:
  /// **'次照护者'**
  String get householdCaregiver;

  /// No description provided for @householdMember.
  ///
  /// In zh, this message translates to:
  /// **'家庭成员'**
  String get householdMember;

  /// No description provided for @householdSyncReflow.
  ///
  /// In zh, this message translates to:
  /// **'同步回流'**
  String get householdSyncReflow;

  /// No description provided for @householdSharedSync.
  ///
  /// In zh, this message translates to:
  /// **'共享同步'**
  String get householdSharedSync;

  /// No description provided for @householdReactionCalm.
  ///
  /// In zh, this message translates to:
  /// **'平静回应'**
  String get householdReactionCalm;

  /// No description provided for @householdReactionEngaged.
  ///
  /// In zh, this message translates to:
  /// **'愿意看着你'**
  String get householdReactionEngaged;

  /// No description provided for @householdReactionImitated.
  ///
  /// In zh, this message translates to:
  /// **'开始模仿'**
  String get householdReactionImitated;

  /// No description provided for @householdReactionNeedsBreak.
  ///
  /// In zh, this message translates to:
  /// **'需要先休息'**
  String get householdReactionNeedsBreak;

  /// No description provided for @householdRecorded.
  ///
  /// In zh, this message translates to:
  /// **'已记录反馈'**
  String get householdRecorded;

  /// No description provided for @householdContinueActivity.
  ///
  /// In zh, this message translates to:
  /// **'继续刚完成的 activity'**
  String get householdContinueActivity;

  /// No description provided for @householdResumeActivity.
  ///
  /// In zh, this message translates to:
  /// **'先接上当前最该继续的 activity'**
  String get householdResumeActivity;

  /// No description provided for @householdSharedNextReady.
  ///
  /// In zh, this message translates to:
  /// **'共享下一步已整理好'**
  String get householdSharedNextReady;

  /// No description provided for @householdSharedPractice.
  ///
  /// In zh, this message translates to:
  /// **'家庭刚完成一次共享练习'**
  String get householdSharedPractice;

  /// No description provided for @householdActorSharedPractice.
  ///
  /// In zh, this message translates to:
  /// **'{role}刚完成一次共享练习'**
  String householdActorSharedPractice(Object role);

  /// No description provided for @householdRecentInteractionMissing.
  ///
  /// In zh, this message translates to:
  /// **'最近互动 {time} · 归因字段缺失时仅保留脱敏共享摘要。'**
  String householdRecentInteractionMissing(Object time);

  /// No description provided for @householdActorDetail.
  ///
  /// In zh, this message translates to:
  /// **'{source} · {result} · 最近互动 {time}'**
  String householdActorDetail(Object source, Object result, Object time);

  /// No description provided for @householdNextStepMissing.
  ///
  /// In zh, this message translates to:
  /// **'共享下一步暂时打不开，入口已保持安全禁用。'**
  String get householdNextStepMissing;

  /// No description provided for @householdRecentInteraction.
  ///
  /// In zh, this message translates to:
  /// **'最近互动 {interactionTime} · 更新 {updateTime}'**
  String householdRecentInteraction(Object interactionTime, Object updateTime);

  /// No description provided for @householdSharedRefreshedNoEntry.
  ///
  /// In zh, this message translates to:
  /// **'共享上下文已刷新，但下一步缺少安全入口；当前不会回退到错误默认 activity。'**
  String get householdSharedRefreshedNoEntry;

  /// No description provided for @householdSharedAttribution.
  ///
  /// In zh, this message translates to:
  /// **'共享归因'**
  String get householdSharedAttribution;

  /// No description provided for @householdEntryPending.
  ///
  /// In zh, this message translates to:
  /// **'入口待整理'**
  String get householdEntryPending;

  /// No description provided for @householdNextStepReady.
  ///
  /// In zh, this message translates to:
  /// **'下一步已就绪'**
  String get householdNextStepReady;

  /// No description provided for @householdSharedCare.
  ///
  /// In zh, this message translates to:
  /// **'共享照护'**
  String get householdSharedCare;

  /// No description provided for @householdSharedNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'共享未接通'**
  String get householdSharedNotConnected;

  /// No description provided for @householdSharedFeatureNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'共享功能暂未接通'**
  String get householdSharedFeatureNotConnected;

  /// No description provided for @householdFallbackNote.
  ///
  /// In zh, this message translates to:
  /// **'共享档案和最近练习暂时不可用，已保留安全空态。'**
  String get householdFallbackNote;

  /// No description provided for @householdLastAccepted.
  ///
  /// In zh, this message translates to:
  /// **'最近接受：{time}'**
  String householdLastAccepted(Object time);

  /// No description provided for @householdRetryAccept.
  ///
  /// In zh, this message translates to:
  /// **'重试接受邀请'**
  String get householdRetryAccept;

  /// No description provided for @householdRetrySharedSync.
  ///
  /// In zh, this message translates to:
  /// **'重试共享同步'**
  String get householdRetrySharedSync;

  /// No description provided for @householdRefreshContext.
  ///
  /// In zh, this message translates to:
  /// **'刷新共享上下文'**
  String get householdRefreshContext;

  /// No description provided for @householdSharedConnected.
  ///
  /// In zh, this message translates to:
  /// **'共享宝宝档案已接通'**
  String get householdSharedConnected;

  /// No description provided for @householdContextUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'共享上下文暂不可用'**
  String get householdContextUnavailable;

  /// No description provided for @householdWaitingCaregiver.
  ///
  /// In zh, this message translates to:
  /// **'等待次照护者加入'**
  String get householdWaitingCaregiver;

  /// No description provided for @householdContextPreparing.
  ///
  /// In zh, this message translates to:
  /// **'共享上下文正在准备'**
  String get householdContextPreparing;

  /// No description provided for @householdCareNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'共享照护尚未接通'**
  String get householdCareNotConnected;

  /// No description provided for @householdPrimaryCaregiverNote.
  ///
  /// In zh, this message translates to:
  /// **'你当前是主照护者，可以管理邀请，并查看共享宝宝档案、最近归因与下一步入口。'**
  String get householdPrimaryCaregiverNote;

  /// No description provided for @householdCaregiverAccepted.
  ///
  /// In zh, this message translates to:
  /// **'你当前是次照护者；邀请接受成功后，这里会显示共享宝宝档案、最近归因与下一步入口。'**
  String get householdCaregiverAccepted;

  /// No description provided for @householdCaregiverConnected.
  ///
  /// In zh, this message translates to:
  /// **'你当前是次照护者；这里展示的是共享宝宝档案、最近归因与下一步入口。'**
  String get householdCaregiverConnected;

  /// No description provided for @householdRoleNotSynced.
  ///
  /// In zh, this message translates to:
  /// **'角色尚未同步；共享档案会继续停留在安全 fallback，不会把错误参数写进练习入口。'**
  String get householdRoleNotSynced;

  /// No description provided for @householdContextUnavailableNote.
  ///
  /// In zh, this message translates to:
  /// **'共享上下文暂不可用；当前不会写入不完整的下一步。'**
  String get householdContextUnavailableNote;

  /// No description provided for @householdPrimaryInviteNote.
  ///
  /// In zh, this message translates to:
  /// **'生成邀请并等待次照护者接受后，这里会出现共享宝宝档案与下一步入口。'**
  String get householdPrimaryInviteNote;

  /// No description provided for @householdCaregiverWaitingNote.
  ///
  /// In zh, this message translates to:
  /// **'接受邀请后，如果共享上下文尚未刷新完成，这里会保留只读等待态。'**
  String get householdCaregiverWaitingNote;

  /// No description provided for @householdNotInitialized.
  ///
  /// In zh, this message translates to:
  /// **'household 尚未初始化；当前保持显式 disabled 状态。'**
  String get householdNotInitialized;

  /// No description provided for @householdRecentAttribution.
  ///
  /// In zh, this message translates to:
  /// **'最近归因'**
  String get householdRecentAttribution;

  /// No description provided for @householdAttributionPending.
  ///
  /// In zh, this message translates to:
  /// **'归因待补全'**
  String get householdAttributionPending;

  /// No description provided for @householdSafeSummary.
  ///
  /// In zh, this message translates to:
  /// **'安全摘要'**
  String get householdSafeSummary;

  /// No description provided for @householdSharedNextStep.
  ///
  /// In zh, this message translates to:
  /// **'共享下一步'**
  String get householdSharedNextStep;

  /// No description provided for @householdNextStepPending.
  ///
  /// In zh, this message translates to:
  /// **'共享下一步待整理'**
  String get householdNextStepPending;

  /// No description provided for @householdSharedBabyProfile.
  ///
  /// In zh, this message translates to:
  /// **'共享宝宝档案'**
  String get householdSharedBabyProfile;

  /// No description provided for @householdRecentContinuity.
  ///
  /// In zh, this message translates to:
  /// **'最近继续练习'**
  String get householdRecentContinuity;

  /// No description provided for @householdGardenContext.
  ///
  /// In zh, this message translates to:
  /// **'花园上下文'**
  String get householdGardenContext;

  /// No description provided for @householdRolePendingSync.
  ///
  /// In zh, this message translates to:
  /// **'角色待同步'**
  String get householdRolePendingSync;

  /// No description provided for @discoverTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get discoverTitle;

  /// No description provided for @discoverSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按活动和空间继续找下一句。'**
  String get discoverSubtitle;

  /// No description provided for @discoverNote.
  ///
  /// In zh, this message translates to:
  /// **'这里展示真实离线目录：你可以按 activity 挑一句，也可以按 space 找到现在最顺手的照护时刻。'**
  String get discoverNote;

  /// No description provided for @discoverByActivity.
  ///
  /// In zh, this message translates to:
  /// **'按活动'**
  String get discoverByActivity;

  /// No description provided for @discoverBySpace.
  ///
  /// In zh, this message translates to:
  /// **'按空间'**
  String get discoverBySpace;

  /// No description provided for @discoverLoadingCatalog.
  ///
  /// In zh, this message translates to:
  /// **'正在整理离线场景目录…'**
  String get discoverLoadingCatalog;

  /// No description provided for @discoverLoadingNote.
  ///
  /// In zh, this message translates to:
  /// **'加载只影响场景，不会阻塞今天、花园和成长 tab。'**
  String get discoverLoadingNote;

  /// No description provided for @discoverLoadError.
  ///
  /// In zh, this message translates to:
  /// **'目录暂时没有整理好'**
  String get discoverLoadError;

  /// No description provided for @discoverRetryLoad.
  ///
  /// In zh, this message translates to:
  /// **'重试加载'**
  String get discoverRetryLoad;

  /// No description provided for @discoverEmpty.
  ///
  /// In zh, this message translates to:
  /// **'目录还是空的'**
  String get discoverEmpty;

  /// No description provided for @discoverEmptyNote.
  ///
  /// In zh, this message translates to:
  /// **'目前没有可展示的场景。稍后重试即可重新读取本地目录。'**
  String get discoverEmptyNote;

  /// No description provided for @discoverRetryRead.
  ///
  /// In zh, this message translates to:
  /// **'重新读取目录'**
  String get discoverRetryRead;

  /// No description provided for @discoverBrowseByActivity.
  ///
  /// In zh, this message translates to:
  /// **'按活动浏览'**
  String get discoverBrowseByActivity;

  /// No description provided for @discoverActivityRouteNote.
  ///
  /// In zh, this message translates to:
  /// **'每张活动卡都会打开对应练习。'**
  String get discoverActivityRouteNote;

  /// No description provided for @discoverActivityCardSemantics.
  ///
  /// In zh, this message translates to:
  /// **'活动: {title}'**
  String discoverActivityCardSemantics(Object title);

  /// No description provided for @discoverSpaceActivitySemantics.
  ///
  /// In zh, this message translates to:
  /// **'空间活动: {title}'**
  String discoverSpaceActivitySemantics(Object title);

  /// No description provided for @discoverSummaryMissing.
  ///
  /// In zh, this message translates to:
  /// **'摘要暂时缺失，但这张卡仍然可以安全进入练习。'**
  String get discoverSummaryMissing;

  /// No description provided for @discoverActivityWarningNote.
  ///
  /// In zh, this message translates to:
  /// **'有一小段练习记录暂时没整理好，当前活动仍可继续。'**
  String get discoverActivityWarningNote;

  /// No description provided for @discoverNextPhrase.
  ///
  /// In zh, this message translates to:
  /// **'下一句：{phrase}'**
  String discoverNextPhrase(Object phrase);

  /// No description provided for @discoverNoNextPhrase.
  ///
  /// In zh, this message translates to:
  /// **'目录暂时没有下一句预览。'**
  String get discoverNoNextPhrase;

  /// No description provided for @discoverRecentResult.
  ///
  /// In zh, this message translates to:
  /// **'最近一次 {time} · {count} 条记录'**
  String discoverRecentResult(Object time, Object count);

  /// No description provided for @discoverProgress.
  ///
  /// In zh, this message translates to:
  /// **'{completed}/{total} 句已练 · {events} 条记录'**
  String discoverProgress(Object completed, Object total, Object events);

  /// No description provided for @discoverNeedsAttention.
  ///
  /// In zh, this message translates to:
  /// **'需留意'**
  String get discoverNeedsAttention;

  /// No description provided for @discoverLatestProgress.
  ///
  /// In zh, this message translates to:
  /// **'最近进度 / 结果'**
  String get discoverLatestProgress;

  /// No description provided for @discoverStartActivity.
  ///
  /// In zh, this message translates to:
  /// **'开始这个活动'**
  String get discoverStartActivity;

  /// No description provided for @discoverContinueActivity.
  ///
  /// In zh, this message translates to:
  /// **'继续这个活动'**
  String get discoverContinueActivity;

  /// No description provided for @discoverBrowseBySpace.
  ///
  /// In zh, this message translates to:
  /// **'按空间浏览'**
  String get discoverBrowseBySpace;

  /// No description provided for @discoverSpaceRouteNote.
  ///
  /// In zh, this message translates to:
  /// **'每个空间会保留你点击的活动入口。'**
  String get discoverSpaceRouteNote;

  /// No description provided for @discoverSpaceProgress.
  ///
  /// In zh, this message translates to:
  /// **'{started}/{total} 个 activity 已开始 · {events} 条记录'**
  String discoverSpaceProgress(Object started, Object total, Object events);

  /// No description provided for @discoverOpenActivity.
  ///
  /// In zh, this message translates to:
  /// **'打开后查看这张活动卡里的短语'**
  String get discoverOpenActivity;

  /// No description provided for @discoverPhraseProgress.
  ///
  /// In zh, this message translates to:
  /// **'{completed}/{total} 句'**
  String discoverPhraseProgress(Object completed, Object total);

  /// No description provided for @discoverLoadErrorMsg.
  ///
  /// In zh, this message translates to:
  /// **'目录读取失败：{error}'**
  String discoverLoadErrorMsg(Object error);

  /// No description provided for @discoverInvalidCard.
  ///
  /// In zh, this message translates to:
  /// **'这张活动卡暂时打不开，已为你保留在当前页面。'**
  String get discoverInvalidCard;

  /// No description provided for @discoverOpenError.
  ///
  /// In zh, this message translates to:
  /// **'打开 {title} 失败：{error}'**
  String discoverOpenError(Object title, Object error);

  /// No description provided for @gardenSharedAttributionTitle.
  ///
  /// In zh, this message translates to:
  /// **'共享归因与花园下一步'**
  String get gardenSharedAttributionTitle;

  /// No description provided for @gardenShareFamily.
  ///
  /// In zh, this message translates to:
  /// **'把花园里的这次变化分享给家人'**
  String get gardenShareFamily;

  /// No description provided for @gardenShareWaitStable.
  ///
  /// In zh, this message translates to:
  /// **'等最近成长和继续建议整理好后，再生成脱敏分享链接。'**
  String get gardenShareWaitStable;

  /// No description provided for @gardenRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'花园刷新失败，先保留上一次稳定结果。'**
  String get gardenRefreshFailed;

  /// No description provided for @gardenContinueFromShared.
  ///
  /// In zh, this message translates to:
  /// **'从共享下一步继续'**
  String get gardenContinueFromShared;

  /// No description provided for @gardenTodayChanges.
  ///
  /// In zh, this message translates to:
  /// **'花园今日变化'**
  String get gardenTodayChanges;

  /// No description provided for @gardenEveryVoice.
  ///
  /// In zh, this message translates to:
  /// **'每一次开口，花园都会记得。'**
  String get gardenEveryVoice;

  /// No description provided for @gardenNoScores.
  ///
  /// In zh, this message translates to:
  /// **'这里不会给分数，只会把真实发生过的照护练习慢慢长成花圃与花朵。'**
  String get gardenNoScores;

  /// No description provided for @gardenOrganizing.
  ///
  /// In zh, this message translates to:
  /// **'花园正在整理今天的变化'**
  String get gardenOrganizing;

  /// No description provided for @gardenProjectingNote.
  ///
  /// In zh, this message translates to:
  /// **'正在把最近练习整理成花圃变化，稍等一下就会出现在这里。'**
  String get gardenProjectingNote;

  /// No description provided for @gardenProjectionWarningNote.
  ///
  /// In zh, this message translates to:
  /// **'有一小段练习记录暂时没整理好，花圃先保留可用结果。'**
  String get gardenProjectionWarningNote;

  /// No description provided for @gardenContinuityNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'继续练习暂时没准备好'**
  String get gardenContinuityNotConnected;

  /// No description provided for @gardenUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'花园暂时不可用，请稍后重试。'**
  String get gardenUnavailable;

  /// No description provided for @gardenComeBack.
  ///
  /// In zh, this message translates to:
  /// **'回来继续'**
  String get gardenComeBack;

  /// No description provided for @gardenContinueActivity.
  ///
  /// In zh, this message translates to:
  /// **'继续 {activityTitle}'**
  String gardenContinueActivity(Object activityTitle);

  /// No description provided for @gardenImpactDetail.
  ///
  /// In zh, this message translates to:
  /// **'{detail} 现在继续会回到 {activityTitle}。'**
  String gardenImpactDetail(Object detail, Object activityTitle);

  /// No description provided for @gardenImpactWithReason.
  ///
  /// In zh, this message translates to:
  /// **'上一次变化来自 {impactTitle}；现在可以接着去 {activityTitle}（{reason}）。'**
  String gardenImpactWithReason(
    Object impactTitle,
    Object activityTitle,
    Object reason,
  );

  /// No description provided for @gardenContinuitySharedNote.
  ///
  /// In zh, this message translates to:
  /// **'花园会和首页一起，把你带回刚才适合继续说的练习。'**
  String get gardenContinuitySharedNote;

  /// No description provided for @gardenSharedContinuity.
  ///
  /// In zh, this message translates to:
  /// **'顺着刚才的练习'**
  String get gardenSharedContinuity;

  /// No description provided for @gardenContinuationRecent.
  ///
  /// In zh, this message translates to:
  /// **'接着刚才练过的场景'**
  String get gardenContinuationRecent;

  /// No description provided for @gardenContinuationNextIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'接上还没说完的活动'**
  String get gardenContinuationNextIncomplete;

  /// No description provided for @gardenContinuationStarter.
  ///
  /// In zh, this message translates to:
  /// **'回到第一颗种子'**
  String get gardenContinuationStarter;

  /// No description provided for @gardenContinuationSafeFallback.
  ///
  /// In zh, this message translates to:
  /// **'先从稳定活动开始'**
  String get gardenContinuationSafeFallback;

  /// No description provided for @gardenFallbackReassurance.
  ///
  /// In zh, this message translates to:
  /// **'已经为你换到一条稳定可继续的练习。'**
  String get gardenFallbackReassurance;

  /// No description provided for @gardenContinuationWarning.
  ///
  /// In zh, this message translates to:
  /// **'有一小段练习记录暂时没整理好，当前建议仍可继续。'**
  String get gardenContinuationWarning;

  /// No description provided for @gardenContinueUnavailableNote.
  ///
  /// In zh, this message translates to:
  /// **'这条继续练习暂时打不开，先回首页或稍后再试。'**
  String get gardenContinueUnavailableNote;

  /// No description provided for @gardenFirstSeedNotPlanted.
  ///
  /// In zh, this message translates to:
  /// **'第一颗种子还没落下'**
  String get gardenFirstSeedNotPlanted;

  /// No description provided for @gardenFirstSeedNote.
  ///
  /// In zh, this message translates to:
  /// **'先从一句 Warm water. 开始。花圃会先醒来，接着才慢慢长出花朵和节奏。'**
  String get gardenFirstSeedNote;

  /// No description provided for @gardenStartedProgress.
  ///
  /// In zh, this message translates to:
  /// **'已开始 {started}/{total}'**
  String gardenStartedProgress(Object started, Object total);

  /// No description provided for @gardenCompletedProgress.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {completed}/{total}'**
  String gardenCompletedProgress(Object completed, Object total);

  /// No description provided for @gardenTotalEvents.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条练习记录'**
  String gardenTotalEvents(Object count);

  /// No description provided for @gardenActivityProgress.
  ///
  /// In zh, this message translates to:
  /// **'已连起 {completed}/{total} 句 · {events} 次记录'**
  String gardenActivityProgress(Object completed, Object total, Object events);

  /// No description provided for @gardenPatchSemantics.
  ///
  /// In zh, this message translates to:
  /// **'花圃：{title}，阶段 {stage}'**
  String gardenPatchSemantics(Object title, Object stage);

  /// No description provided for @gardenFlowerSemantics.
  ///
  /// In zh, this message translates to:
  /// **'活动：{title}，阶段 {stage}'**
  String gardenFlowerSemantics(Object title, Object stage);

  /// No description provided for @gardenSharedContinuityUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时还没有下一句'**
  String get gardenSharedContinuityUnavailable;

  /// No description provided for @gardenContinueWatering.
  ///
  /// In zh, this message translates to:
  /// **'继续浇灌'**
  String get gardenContinueWatering;

  /// No description provided for @gardenContinueNote.
  ///
  /// In zh, this message translates to:
  /// **'继续练习后，首页和花园会一起记住这次变化。'**
  String get gardenContinueNote;

  /// No description provided for @gardenContinueToday.
  ///
  /// In zh, this message translates to:
  /// **'继续今天的练习'**
  String get gardenContinueToday;

  /// No description provided for @practiceInvalidParams.
  ///
  /// In zh, this message translates to:
  /// **'当前照护入口缺少有效参数，请返回上一个页面重试。'**
  String get practiceInvalidParams;

  /// No description provided for @practiceContextMissing.
  ///
  /// In zh, this message translates to:
  /// **'当前活动上下文缺失，请返回首页重试。'**
  String get practiceContextMissing;

  /// No description provided for @practiceProgress.
  ///
  /// In zh, this message translates to:
  /// **'第 {current} / {total} 句'**
  String practiceProgress(Object current, Object total);

  /// No description provided for @practiceLastSaved.
  ///
  /// In zh, this message translates to:
  /// **'最后一句也已保存，本轮练习已完成。返回首页后会看到最近一次本地结果。'**
  String get practiceLastSaved;

  /// No description provided for @practiceCurrentPhrases.
  ///
  /// In zh, this message translates to:
  /// **'现在试试这一句'**
  String get practiceCurrentPhrases;

  /// No description provided for @practiceActivationKicker.
  ///
  /// In zh, this message translates to:
  /// **'跟着宝宝节奏来'**
  String get practiceActivationKicker;

  /// No description provided for @practicePhraseStep.
  ///
  /// In zh, this message translates to:
  /// **'第 {step} 句'**
  String practicePhraseStep(Object step);

  /// No description provided for @practiceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'照护暂不可用'**
  String get practiceUnavailable;

  /// No description provided for @practiceBackHome.
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get practiceBackHome;

  /// No description provided for @mentorNotReady.
  ///
  /// In zh, this message translates to:
  /// **'Mentor 面板尚未装配完成。'**
  String get mentorNotReady;

  /// No description provided for @mentorOfflineNote.
  ///
  /// In zh, this message translates to:
  /// **'先给建议，再决定是否需要聊天。离线时也不会让你白点。'**
  String get mentorOfflineNote;

  /// No description provided for @mentorClosePanel.
  ///
  /// In zh, this message translates to:
  /// **'关闭 Mentor 面板'**
  String get mentorClosePanel;

  /// No description provided for @mentorSuggestionTab.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get mentorSuggestionTab;

  /// No description provided for @mentorChatTab.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get mentorChatTab;

  /// No description provided for @mentorChatNote.
  ///
  /// In zh, this message translates to:
  /// **'导师只返回一条清晰回应，帮助你先稳住当下。'**
  String get mentorChatNote;

  /// No description provided for @mentorReadStatus.
  ///
  /// In zh, this message translates to:
  /// **'朗读状态'**
  String get mentorReadStatus;

  /// No description provided for @mentorChatPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'说出你现在卡住的地方'**
  String get mentorChatPlaceholder;

  /// No description provided for @mentorChatHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：宝宝一直哭，我现在该怎么开口安抚？'**
  String get mentorChatHint;

  /// No description provided for @mentorSending.
  ///
  /// In zh, this message translates to:
  /// **'发送中…'**
  String get mentorSending;

  /// No description provided for @mentorSendRequest.
  ///
  /// In zh, this message translates to:
  /// **'发起一次求助'**
  String get mentorSendRequest;

  /// No description provided for @mentorRecheck.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get mentorRecheck;

  /// No description provided for @mentorBackToSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'回到建议'**
  String get mentorBackToSuggestion;

  /// No description provided for @mentorControlledResponse.
  ///
  /// In zh, this message translates to:
  /// **'受控回应'**
  String get mentorControlledResponse;

  /// No description provided for @mentorNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get mentorNotLoggedIn;

  /// No description provided for @mentorLocalResponse.
  ///
  /// In zh, this message translates to:
  /// **'本地回应'**
  String get mentorLocalResponse;

  /// No description provided for @mentorReading.
  ///
  /// In zh, this message translates to:
  /// **'朗读中…'**
  String get mentorReading;

  /// No description provided for @mentorReadResponse.
  ///
  /// In zh, this message translates to:
  /// **'朗读回应'**
  String get mentorReadResponse;

  /// No description provided for @mentorSuggestionIntro.
  ///
  /// In zh, this message translates to:
  /// **'先给你几条现在就能说出口的建议。离线时也可以直接用，不需要等聊天连通。'**
  String get mentorSuggestionIntro;

  /// No description provided for @mentorSuggestionLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在整理本地建议…'**
  String get mentorSuggestionLoading;

  /// No description provided for @mentorSuggestionEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没整理出建议'**
  String get mentorSuggestionEmpty;

  /// No description provided for @mentorSuggestionEmptyNote.
  ///
  /// In zh, this message translates to:
  /// **'别担心，你重新打开或点一次刷新就好；面板本身不会失效。'**
  String get mentorSuggestionEmptyNote;

  /// No description provided for @mentorSuggestionRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新建议'**
  String get mentorSuggestionRefresh;

  /// No description provided for @mentorSuggestionRead.
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get mentorSuggestionRead;

  /// No description provided for @phraseRecorded.
  ///
  /// In zh, this message translates to:
  /// **'已记录'**
  String get phraseRecorded;

  /// No description provided for @phrasePending.
  ///
  /// In zh, this message translates to:
  /// **'待练习'**
  String get phrasePending;

  /// No description provided for @phrasePlaybackReady.
  ///
  /// In zh, this message translates to:
  /// **'听小禾读'**
  String get phrasePlaybackReady;

  /// No description provided for @phrasePlaybackPlaying.
  ///
  /// In zh, this message translates to:
  /// **'播放中'**
  String get phrasePlaybackPlaying;

  /// No description provided for @phrasePlaybackCompleted.
  ///
  /// In zh, this message translates to:
  /// **'再听一次'**
  String get phrasePlaybackCompleted;

  /// No description provided for @phrasePlaybackRetry.
  ///
  /// In zh, this message translates to:
  /// **'这句没读出来，点我重试'**
  String get phrasePlaybackRetry;

  /// No description provided for @phraseSaveAwaitingReaction.
  ///
  /// In zh, this message translates to:
  /// **'等宝宝反应'**
  String get phraseSaveAwaitingReaction;

  /// No description provided for @phraseSaveSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存'**
  String get phraseSaveSaving;

  /// No description provided for @phraseSaveSaved.
  ///
  /// In zh, this message translates to:
  /// **'已记下反应'**
  String get phraseSaveSaved;

  /// No description provided for @phraseSaveRetry.
  ///
  /// In zh, this message translates to:
  /// **'保存需重试'**
  String get phraseSaveRetry;

  /// No description provided for @phraseNote.
  ///
  /// In zh, this message translates to:
  /// **'先听一遍，再跟着宝宝的节奏说。宝宝看你、安静听，或咿呀回应，都可以记录。'**
  String get phraseNote;

  /// No description provided for @phraseReactionLabel.
  ///
  /// In zh, this message translates to:
  /// **'宝宝现在的反应'**
  String get phraseReactionLabel;

  /// No description provided for @growthRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'成长页刷新失败，先保留上次稳定结果。'**
  String get growthRefreshFailed;

  /// No description provided for @growthAutoDiary.
  ///
  /// In zh, this message translates to:
  /// **'自动日记'**
  String get growthAutoDiary;

  /// No description provided for @growthDiarySheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'全部成长日记'**
  String get growthDiarySheetTitle;

  /// No description provided for @growthDiaryPracticeTag.
  ///
  /// In zh, this message translates to:
  /// **'练习记录'**
  String get growthDiaryPracticeTag;

  /// No description provided for @growthDiaryMilestoneTag.
  ///
  /// In zh, this message translates to:
  /// **'里程碑记录'**
  String get growthDiaryMilestoneTag;

  /// No description provided for @growthNoDiary.
  ///
  /// In zh, this message translates to:
  /// **'还没有自动日记，第一次练习完成后会在这里记下变化。'**
  String get growthNoDiary;

  /// No description provided for @growthSceneProgress.
  ///
  /// In zh, this message translates to:
  /// **'场景进展'**
  String get growthSceneProgress;

  /// No description provided for @growthNoScene.
  ///
  /// In zh, this message translates to:
  /// **'花圃还没醒来，所以暂时没有场景进展。'**
  String get growthNoScene;

  /// No description provided for @growthMilestone.
  ///
  /// In zh, this message translates to:
  /// **'里程碑'**
  String get growthMilestone;

  /// No description provided for @growthMilestoneSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'全部里程碑'**
  String get growthMilestoneSheetTitle;

  /// No description provided for @growthMilestoneAchieved.
  ///
  /// In zh, this message translates to:
  /// **'已点亮'**
  String get growthMilestoneAchieved;

  /// No description provided for @growthMilestoneLocked.
  ///
  /// In zh, this message translates to:
  /// **'待点亮'**
  String get growthMilestoneLocked;

  /// No description provided for @growthMilestoneNote.
  ///
  /// In zh, this message translates to:
  /// **'里程碑会在真实练习后逐步点亮。'**
  String get growthMilestoneNote;

  /// No description provided for @growthDiaryLabel.
  ///
  /// In zh, this message translates to:
  /// **'成长日记'**
  String get growthDiaryLabel;

  /// No description provided for @growthNotScore.
  ///
  /// In zh, this message translates to:
  /// **'成长不是分数，而是一串串被记住的变化。'**
  String get growthNotScore;

  /// No description provided for @growthNote.
  ///
  /// In zh, this message translates to:
  /// **'这里会按时间整理自动日记、空间进展和里程碑，帮助你回看今天发生过什么。'**
  String get growthNote;

  /// No description provided for @growthOrganizing.
  ///
  /// In zh, this message translates to:
  /// **'成长页正在整理练习记录'**
  String get growthOrganizing;

  /// No description provided for @growthOrganizingNote.
  ///
  /// In zh, this message translates to:
  /// **'准备好后，这里会出现最新一次变化、自动日记和里程碑。'**
  String get growthOrganizingNote;

  /// No description provided for @growthEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'你的成长还没有开始。'**
  String get growthEmptyTitle;

  /// No description provided for @growthEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'说完第一句英语后，这里会记录你的陪伴轨迹。'**
  String get growthEmptyDescription;

  /// No description provided for @growthEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'回到首页说一句'**
  String get growthEmptyAction;

  /// No description provided for @growthPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'最近成长会写在这里'**
  String get growthPlaceholder;

  /// No description provided for @growthAfterPractice.
  ///
  /// In zh, this message translates to:
  /// **'完成一次真实练习后，这里会告诉你哪朵花发芽了、哪条日记被写下来了。'**
  String get growthAfterPractice;

  /// No description provided for @growthSpaceProgress.
  ///
  /// In zh, this message translates to:
  /// **'已开始 {started}/{totalActivities} 个活动 · 已完成 {completed}/{totalActivities} 个活动'**
  String growthSpaceProgress(
    Object started,
    Object totalActivities,
    Object completed,
  );

  /// No description provided for @growthLatestImpactSemantics.
  ///
  /// In zh, this message translates to:
  /// **'最近成长：{title}'**
  String growthLatestImpactSemantics(Object title);

  /// No description provided for @growthDiaryEntrySemantics.
  ///
  /// In zh, this message translates to:
  /// **'成长日记：{title}'**
  String growthDiaryEntrySemantics(Object title);

  /// No description provided for @growthMilestoneSemantics.
  ///
  /// In zh, this message translates to:
  /// **'成长里程碑：{title}'**
  String growthMilestoneSemantics(Object title);

  /// No description provided for @growthPreviewCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条记录'**
  String growthPreviewCount(Object count);

  /// No description provided for @inviteNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'共享功能暂未接通'**
  String get inviteNotConnected;

  /// No description provided for @inviteDisabledNote.
  ///
  /// In zh, this message translates to:
  /// **'邀请入口已显式禁用，不会假装创建成功。'**
  String get inviteDisabledNote;

  /// No description provided for @inviteLatestLink.
  ///
  /// In zh, this message translates to:
  /// **'最新邀请链接'**
  String get inviteLatestLink;

  /// No description provided for @inviteRoleExpiry.
  ///
  /// In zh, this message translates to:
  /// **'角色：{role} · 到期：{expiry}'**
  String inviteRoleExpiry(Object role, Object expiry);

  /// No description provided for @inviteCreating.
  ///
  /// In zh, this message translates to:
  /// **'创建中…'**
  String get inviteCreating;

  /// No description provided for @inviteGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成照护邀请'**
  String get inviteGenerate;

  /// No description provided for @inviteRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成邀请'**
  String get inviteRegenerate;

  /// No description provided for @inviteRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试邀请'**
  String get inviteRetry;

  /// No description provided for @inviteReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'当前角色只读：由主照护者发起邀请，你可以继续查看共享档案。'**
  String get inviteReadOnly;

  /// No description provided for @inviteCaregiver.
  ///
  /// In zh, this message translates to:
  /// **'邀请次照护者加入'**
  String get inviteCaregiver;

  /// No description provided for @inviteManagedByPrimary.
  ///
  /// In zh, this message translates to:
  /// **'邀请由主照护者管理'**
  String get inviteManagedByPrimary;

  /// No description provided for @invitePermissionPending.
  ///
  /// In zh, this message translates to:
  /// **'邀请权限待同步'**
  String get invitePermissionPending;

  /// No description provided for @inviteGenerateNote.
  ///
  /// In zh, this message translates to:
  /// **'生成邀请链接后，次照护者可通过链接接受邀请并看到共享宝宝档案摘要。'**
  String get inviteGenerateNote;

  /// No description provided for @inviteCaregiverNote.
  ///
  /// In zh, this message translates to:
  /// **'你当前是次照护者，只读查看共享照护内容；如需新增成员，请让主照护者操作。'**
  String get inviteCaregiverNote;

  /// No description provided for @invitePermissionNote.
  ///
  /// In zh, this message translates to:
  /// **'角色或权限尚未准备好；邀请入口保持禁用，并在失败时保留明确文案。'**
  String get invitePermissionNote;

  /// No description provided for @inviteLabel.
  ///
  /// In zh, this message translates to:
  /// **'照护邀请'**
  String get inviteLabel;

  /// No description provided for @inviteTrustTitle.
  ///
  /// In zh, this message translates to:
  /// **'邀请范围'**
  String get inviteTrustTitle;

  /// No description provided for @inviteTrustRole.
  ///
  /// In zh, this message translates to:
  /// **'接收角色：{role}'**
  String inviteTrustRole(Object role);

  /// No description provided for @inviteTrustExpiry.
  ///
  /// In zh, this message translates to:
  /// **'有效期至 {expiry}'**
  String inviteTrustExpiry(Object expiry);

  /// No description provided for @inviteTrustScope.
  ///
  /// In zh, this message translates to:
  /// **'{role}可查看共享宝宝档案摘要和照护进度，不会获得账号管理权限。'**
  String inviteTrustScope(Object role);

  /// No description provided for @inviteTrustPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'链接不会包含手机号、设备标识或内部记录编号。'**
  String get inviteTrustPrivacy;

  /// No description provided for @shareNoContent.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有可分享的成长瞬间'**
  String get shareNoContent;

  /// No description provided for @sharePhraseToday.
  ///
  /// In zh, this message translates to:
  /// **'今天说的一句：{phrase}'**
  String sharePhraseToday(Object phrase);

  /// No description provided for @shareGenerating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成分享链接…'**
  String get shareGenerating;

  /// No description provided for @shareButton.
  ///
  /// In zh, this message translates to:
  /// **'分享给家人'**
  String get shareButton;

  /// No description provided for @sharePreviewButton.
  ///
  /// In zh, this message translates to:
  /// **'预览后分享'**
  String get sharePreviewButton;

  /// No description provided for @shareWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待可分享内容'**
  String get shareWaiting;

  /// No description provided for @shareGeneratingNote.
  ///
  /// In zh, this message translates to:
  /// **'正在生成脱敏分享链接，请稍候。'**
  String get shareGeneratingNote;

  /// No description provided for @shareWaitNote.
  ///
  /// In zh, this message translates to:
  /// **'等最近成长或继续建议整理好后，再生成脱敏分享链接。'**
  String get shareWaitNote;

  /// No description provided for @sharePanelOpened.
  ///
  /// In zh, this message translates to:
  /// **'分享面板已打开。'**
  String get sharePanelOpened;

  /// No description provided for @shareCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消分享。'**
  String get shareCancelled;

  /// No description provided for @shareUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'分享暂时不可用，请稍后重试。'**
  String get shareUnavailable;

  /// No description provided for @sharePrivacyNote.
  ///
  /// In zh, this message translates to:
  /// **'分享内容会自动脱敏，只保留适合家人查看的成长片段。'**
  String get sharePrivacyNote;

  /// No description provided for @sharePreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'分享预览'**
  String get sharePreviewTitle;

  /// No description provided for @sharePreviewIntro.
  ///
  /// In zh, this message translates to:
  /// **'家人会看到这些脱敏后的内容。'**
  String get sharePreviewIntro;

  /// No description provided for @sharePreviewIncludes.
  ///
  /// In zh, this message translates to:
  /// **'将分享'**
  String get sharePreviewIncludes;

  /// No description provided for @sharePreviewPrivacyOmitted.
  ///
  /// In zh, this message translates to:
  /// **'不会包含手机号、设备标识、账号信息或内部记录编号。'**
  String get sharePreviewPrivacyOmitted;

  /// No description provided for @sharePreviewConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认分享给家人'**
  String get sharePreviewConfirm;

  /// No description provided for @sharePreviewCancel.
  ///
  /// In zh, this message translates to:
  /// **'先不分享'**
  String get sharePreviewCancel;

  /// No description provided for @activationFrameLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前短语练习区'**
  String get activationFrameLabel;

  /// No description provided for @accountEntryLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在准备账号状态'**
  String get accountEntryLoading;

  /// No description provided for @accountEntryPreparingProfile.
  ///
  /// In zh, this message translates to:
  /// **'先保留同意前本地档案'**
  String get accountEntryPreparingProfile;

  /// No description provided for @accountEntryVisibleNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'账号入口已可见，但你还没有登录'**
  String get accountEntryVisibleNotLoggedIn;

  /// No description provided for @accountEntrySignedInSynced.
  ///
  /// In zh, this message translates to:
  /// **'已用 {phone} 登录并完成最近一次对齐'**
  String accountEntrySignedInSynced(Object phone);

  /// No description provided for @accountEntryReadFailedShell.
  ///
  /// In zh, this message translates to:
  /// **'账号状态读取失败，但当前页面仍可继续使用'**
  String get accountEntryReadFailedShell;

  /// No description provided for @accountEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号入口'**
  String get accountEntryTitle;

  /// No description provided for @accountEntryS03Label.
  ///
  /// In zh, this message translates to:
  /// **'账号与同步设置'**
  String get accountEntryS03Label;

  /// No description provided for @accountCurrentStatusSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前账号状态'**
  String get accountCurrentStatusSectionTitle;

  /// No description provided for @accountPrimaryActionSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录与同意'**
  String get accountPrimaryActionSectionTitle;

  /// No description provided for @accountPrimaryActionSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'需要登录或重新同意时，在这里完成手机号与验证码提交。'**
  String get accountPrimaryActionSectionHint;

  /// No description provided for @accountPrimaryActionSignedInHint.
  ///
  /// In zh, this message translates to:
  /// **'已登录状态下不再重复展示登录表单。'**
  String get accountPrimaryActionSignedInHint;

  /// No description provided for @accountPrimaryActionSignedInBody.
  ///
  /// In zh, this message translates to:
  /// **'当前账号已完成登录；如遇恢复或同步问题，请使用下方恢复区。'**
  String get accountPrimaryActionSignedInBody;

  /// No description provided for @accountRecoverySectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复与同步'**
  String get accountRecoverySectionTitle;

  /// No description provided for @accountRecoverySectionHint.
  ///
  /// In zh, this message translates to:
  /// **'同步失败、版本受阻或恢复中断时，先从这里重试。'**
  String get accountRecoverySectionHint;

  /// No description provided for @accountFamilyContextSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'家庭共享上下文'**
  String get accountFamilyContextSectionTitle;

  /// No description provided for @accountFamilyContextSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'家庭共享入口会保持脱敏展示，并与账号状态分开处理。'**
  String get accountFamilyContextSectionHint;

  /// No description provided for @accountManagementSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'日常管理'**
  String get accountManagementSectionTitle;

  /// No description provided for @accountManagementSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'退出或回到本机档案不会删除本机练习记录。'**
  String get accountManagementSectionHint;

  /// No description provided for @accountDangerZoneSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'高风险操作'**
  String get accountDangerZoneSectionTitle;

  /// No description provided for @accountDangerZoneSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'撤回同意和删除账号会改变远端账号状态，确认前请核对影响范围。'**
  String get accountDangerZoneSectionHint;

  /// No description provided for @accountDangerZoneRetentionNote.
  ///
  /// In zh, this message translates to:
  /// **'本机记录仍会保留；删除账号只会在确认后清理本机敏感数据。'**
  String get accountDangerZoneRetentionNote;

  /// No description provided for @accountLifecycleCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get accountLifecycleCancel;

  /// No description provided for @accountDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除账号？'**
  String get accountDeleteConfirmTitle;

  /// No description provided for @accountDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后会清理本机账号、宝宝资料、家庭上下文、练习记录、导师事实和设备标识。此操作不可撤销。'**
  String get accountDeleteConfirmBody;

  /// No description provided for @accountDeleteConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get accountDeleteConfirmAction;

  /// No description provided for @accountRevokeConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认撤回同意？'**
  String get accountRevokeConfirmTitle;

  /// No description provided for @accountRevokeConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'撤回后将停止账号同步；后续需重新登录并再次同意才能恢复。'**
  String get accountRevokeConfirmBody;

  /// No description provided for @accountRevokeConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认撤回'**
  String get accountRevokeConfirmAction;

  /// No description provided for @accountClearConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退出为未登录？'**
  String get accountClearConfirmTitle;

  /// No description provided for @accountClearConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'退出后账号会变为未登录状态，但本机练习记录仍会保留。'**
  String get accountClearConfirmBody;

  /// No description provided for @accountClearConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get accountClearConfirmAction;

  /// No description provided for @accountLocalOnlyConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认回到本机档案？'**
  String get accountLocalOnlyConfirmTitle;

  /// No description provided for @accountLocalOnlyConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'切换后将回到本机档案模式；本机练习记录仍会保留。'**
  String get accountLocalOnlyConfirmBody;

  /// No description provided for @accountLocalOnlyConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认切换'**
  String get accountLocalOnlyConfirmAction;

  /// No description provided for @accountEntrySubmitMessage.
  ///
  /// In zh, this message translates to:
  /// **'登录已完成；你现在可以返回首页查看最近恢复结果，待同步记录也会继续尝试上传。'**
  String get accountEntrySubmitMessage;

  /// No description provided for @accountEntrySubmitButton.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get accountEntrySubmitButton;

  /// No description provided for @shellDiscoverTooltip.
  ///
  /// In zh, this message translates to:
  /// **'场景'**
  String get shellDiscoverTooltip;

  /// No description provided for @shellPractice.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get shellPractice;

  /// No description provided for @shellPracticeName.
  ///
  /// In zh, this message translates to:
  /// **'{name} 的今天'**
  String shellPracticeName(Object name);

  /// No description provided for @shellGrowthTab.
  ///
  /// In zh, this message translates to:
  /// **'成长'**
  String get shellGrowthTab;

  /// No description provided for @shellFirstTimeDrawerStage.
  ///
  /// In zh, this message translates to:
  /// **'第一次进入家庭档案'**
  String get shellFirstTimeDrawerStage;

  /// No description provided for @shellDrawerNoteText.
  ///
  /// In zh, this message translates to:
  /// **'Drawer 现在会直接显示 invite CTA、角色 badge、最近是谁完成了什么，以及共享下一步是否安全可进。'**
  String get shellDrawerNoteText;

  /// No description provided for @growthDiaryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有自动日记，第一次练习完成后会在这里记下变化。'**
  String get growthDiaryEmpty;

  /// No description provided for @growthMilestoneEmpty.
  ///
  /// In zh, this message translates to:
  /// **'里程碑会在真实练习后逐步点亮。'**
  String get growthMilestoneEmpty;

  /// No description provided for @growthShareWaitStable.
  ///
  /// In zh, this message translates to:
  /// **'等最近成长和继续建议整理稳定后，再生成一条脱敏分享链接。'**
  String get growthShareWaitStable;

  /// No description provided for @growthSceneEmpty.
  ///
  /// In zh, this message translates to:
  /// **'花圃还没醒来，所以暂时没有场景进展。'**
  String get growthSceneEmpty;

  /// No description provided for @gardenContinueUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'继续入口暂不可用'**
  String get gardenContinueUnavailable;

  /// No description provided for @gardenContinueActivityTitle.
  ///
  /// In zh, this message translates to:
  /// **'继续 {activityTitle}'**
  String gardenContinueActivityTitle(Object activityTitle);

  /// No description provided for @gardenImpactContinue.
  ///
  /// In zh, this message translates to:
  /// **'{detail} 现在继续会回到 {activityTitle}。'**
  String gardenImpactContinue(Object detail, Object activityTitle);

  /// No description provided for @gardenImpactWithReasonDetail.
  ///
  /// In zh, this message translates to:
  /// **'上一次变化来自 {impactTitle}；现在可以接着去 {activityTitle}（{reason}）。'**
  String gardenImpactWithReasonDetail(
    Object impactTitle,
    Object activityTitle,
    Object reason,
  );

  /// No description provided for @discoverInvalidCardError.
  ///
  /// In zh, this message translates to:
  /// **'这个场景暂时打不开，已为你保留在当前页面。'**
  String get discoverInvalidCardError;

  /// No description provided for @discoverOpenActivityError.
  ///
  /// In zh, this message translates to:
  /// **'打开 {title} 失败：{error}'**
  String discoverOpenActivityError(Object title, Object error);

  /// No description provided for @discoverSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索场景或照护时刻...'**
  String get discoverSearchHint;

  /// No description provided for @discoverSceneAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get discoverSceneAll;

  /// No description provided for @discoverSceneMealtime.
  ///
  /// In zh, this message translates to:
  /// **'喂饭'**
  String get discoverSceneMealtime;

  /// No description provided for @discoverSceneDrinking.
  ///
  /// In zh, this message translates to:
  /// **'喝水'**
  String get discoverSceneDrinking;

  /// No description provided for @discoverSceneDiaper.
  ///
  /// In zh, this message translates to:
  /// **'换尿布'**
  String get discoverSceneDiaper;

  /// No description provided for @discoverSceneBath.
  ///
  /// In zh, this message translates to:
  /// **'洗澡'**
  String get discoverSceneBath;

  /// No description provided for @discoverSceneBedtime.
  ///
  /// In zh, this message translates to:
  /// **'睡前'**
  String get discoverSceneBedtime;

  /// No description provided for @discoverSceneOuting.
  ///
  /// In zh, this message translates to:
  /// **'出门'**
  String get discoverSceneOuting;

  /// No description provided for @discoverSortMostUsed.
  ///
  /// In zh, this message translates to:
  /// **'最常用'**
  String get discoverSortMostUsed;

  /// No description provided for @discoverSortNewest.
  ///
  /// In zh, this message translates to:
  /// **'最新'**
  String get discoverSortNewest;

  /// No description provided for @discoverSortAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get discoverSortAll;

  /// No description provided for @discoverSortLabel.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get discoverSortLabel;

  /// No description provided for @discoverPracticeThis.
  ///
  /// In zh, this message translates to:
  /// **'现在说一句'**
  String get discoverPracticeThis;

  /// No description provided for @discoverUsageHint.
  ///
  /// In zh, this message translates to:
  /// **'适合在{scene}时轻轻说一次'**
  String discoverUsageHint(Object scene);

  /// No description provided for @discoverSearchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的场景，换个关键词试试'**
  String get discoverSearchEmpty;

  /// No description provided for @discoverSceneEmpty.
  ///
  /// In zh, this message translates to:
  /// **'这个分类还没有场景，换个分类试试'**
  String get discoverSceneEmpty;

  /// No description provided for @discoverSceneTagMealtime.
  ///
  /// In zh, this message translates to:
  /// **'喂饭'**
  String get discoverSceneTagMealtime;

  /// No description provided for @discoverSceneTagDrinking.
  ///
  /// In zh, this message translates to:
  /// **'喝水'**
  String get discoverSceneTagDrinking;

  /// No description provided for @discoverSceneTagDiaper.
  ///
  /// In zh, this message translates to:
  /// **'换尿布'**
  String get discoverSceneTagDiaper;

  /// No description provided for @discoverSceneTagBath.
  ///
  /// In zh, this message translates to:
  /// **'洗澡'**
  String get discoverSceneTagBath;

  /// No description provided for @discoverSceneTagBedtime.
  ///
  /// In zh, this message translates to:
  /// **'睡前'**
  String get discoverSceneTagBedtime;

  /// No description provided for @discoverSceneTagOuting.
  ///
  /// In zh, this message translates to:
  /// **'出门'**
  String get discoverSceneTagOuting;

  /// No description provided for @discoverSceneTagOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get discoverSceneTagOther;

  /// No description provided for @discoverPracticePhraseHint.
  ///
  /// In zh, this message translates to:
  /// **'点击卡片或按钮进入当前场景'**
  String get discoverPracticePhraseHint;

  /// No description provided for @discoverTrustSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'照护场景'**
  String get discoverTrustSubtitle;

  /// No description provided for @discoverTrustPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'你的信息受到保护'**
  String get discoverTrustPrivacy;

  /// No description provided for @discoverUnifiedLoginTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 BabyTalk'**
  String get discoverUnifiedLoginTitle;

  /// No description provided for @discoverUnifiedLoginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'输入手机号，自动识别新老用户'**
  String get discoverUnifiedLoginSubtitle;

  /// No description provided for @discoverPhoneLabel.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get discoverPhoneLabel;

  /// No description provided for @discoverPhoneHint.
  ///
  /// In zh, this message translates to:
  /// **'用于登录或注册 BabyTalk'**
  String get discoverPhoneHint;

  /// No description provided for @discoverGetCode.
  ///
  /// In zh, this message translates to:
  /// **'获取验证码'**
  String get discoverGetCode;

  /// No description provided for @discoverCodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get discoverCodeLabel;

  /// No description provided for @discoverCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'输入 6 位短信验证码'**
  String get discoverCodeHint;

  /// No description provided for @discoverCodeAutoHint.
  ///
  /// In zh, this message translates to:
  /// **'支持自动填充和粘贴'**
  String get discoverCodeAutoHint;

  /// No description provided for @discoverResendCode.
  ///
  /// In zh, this message translates to:
  /// **'重新发送'**
  String get discoverResendCode;

  /// No description provided for @discoverResendCountdown.
  ///
  /// In zh, this message translates to:
  /// **'{seconds}s 后可重发'**
  String discoverResendCountdown(Object seconds);

  /// No description provided for @discoverResendReady.
  ///
  /// In zh, this message translates to:
  /// **'没有收到？可以重新发送'**
  String get discoverResendReady;

  /// No description provided for @discoverLoginButton.
  ///
  /// In zh, this message translates to:
  /// **'登录 / 注册'**
  String get discoverLoginButton;

  /// No description provided for @discoverPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get discoverPasswordLabel;

  /// No description provided for @discoverPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'至少 8 位，建议包含字母和数字'**
  String get discoverPasswordHint;

  /// No description provided for @discoverConfirmPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get discoverConfirmPasswordLabel;

  /// No description provided for @discoverForgotPassword.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get discoverForgotPassword;

  /// No description provided for @discoverResetPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get discoverResetPasswordTitle;

  /// No description provided for @discoverResetPasswordSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'通过验证码确认身份后设置新密码'**
  String get discoverResetPasswordSubtitle;

  /// No description provided for @discoverNewPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get discoverNewPasswordLabel;

  /// No description provided for @discoverSetPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'设置密码'**
  String get discoverSetPasswordLabel;

  /// No description provided for @discoverTermsPrefix.
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并同意'**
  String get discoverTermsPrefix;

  /// No description provided for @discoverTermsOfService.
  ///
  /// In zh, this message translates to:
  /// **'《服务条款》'**
  String get discoverTermsOfService;

  /// No description provided for @discoverPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'《隐私协议》'**
  String get discoverPrivacyPolicy;

  /// No description provided for @discoverPrivacyNote.
  ///
  /// In zh, this message translates to:
  /// **'登录即表示同意我们的服务条款和隐私协议'**
  String get discoverPrivacyNote;

  /// No description provided for @discoverVerificationPassed.
  ///
  /// In zh, this message translates to:
  /// **'人机校验已通过，验证码已发送'**
  String get discoverVerificationPassed;

  /// No description provided for @discoverVerificationPending.
  ///
  /// In zh, this message translates to:
  /// **'验证码待发送'**
  String get discoverVerificationPending;

  /// No description provided for @discoverCodeSentToast.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送，请查看短信'**
  String get discoverCodeSentToast;

  /// No description provided for @discoverCaptchaTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全验证'**
  String get discoverCaptchaTitle;

  /// No description provided for @discoverCaptchaDescription.
  ///
  /// In zh, this message translates to:
  /// **'请先完成校验，验证通过后再发送验证码。'**
  String get discoverCaptchaDescription;

  /// No description provided for @discoverCaptchaArea.
  ///
  /// In zh, this message translates to:
  /// **'CAPTCHA 校验区域'**
  String get discoverCaptchaArea;

  /// No description provided for @discoverCaptchaPass.
  ///
  /// In zh, this message translates to:
  /// **'模拟验证通过'**
  String get discoverCaptchaPass;

  /// No description provided for @discoverCaptchaCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get discoverCaptchaCancel;

  /// No description provided for @discoverModeCodeLogin.
  ///
  /// In zh, this message translates to:
  /// **'验证码登录'**
  String get discoverModeCodeLogin;

  /// No description provided for @discoverModePasswordLogin.
  ///
  /// In zh, this message translates to:
  /// **'密码登录'**
  String get discoverModePasswordLogin;

  /// No description provided for @discoverModeRegister.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get discoverModeRegister;

  /// No description provided for @discoverReturnToLogin.
  ///
  /// In zh, this message translates to:
  /// **'返回登录'**
  String get discoverReturnToLogin;

  /// No description provided for @sharePhraseTodayLabel.
  ///
  /// In zh, this message translates to:
  /// **'今天说的一句：{phrase}'**
  String sharePhraseTodayLabel(Object phrase);

  /// No description provided for @mentorSuggestionTabSemantics.
  ///
  /// In zh, this message translates to:
  /// **'建议标签页'**
  String get mentorSuggestionTabSemantics;

  /// No description provided for @mentorChatTabSemantics.
  ///
  /// In zh, this message translates to:
  /// **'聊天标签页'**
  String get mentorChatTabSemantics;

  /// No description provided for @shellMe.
  ///
  /// In zh, this message translates to:
  /// **'我'**
  String get shellMe;

  /// No description provided for @meGardenEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有种下花圃'**
  String get meGardenEmpty;

  /// No description provided for @meGardenSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个花圃正在成长'**
  String meGardenSummary(Object count);

  /// No description provided for @meGrowthTitle.
  ///
  /// In zh, this message translates to:
  /// **'成长数据'**
  String get meGrowthTitle;

  /// No description provided for @meStatEvents.
  ///
  /// In zh, this message translates to:
  /// **'练习次数'**
  String get meStatEvents;

  /// No description provided for @meStatDiary.
  ///
  /// In zh, this message translates to:
  /// **'成长日记'**
  String get meStatDiary;

  /// No description provided for @meStatMilestones.
  ///
  /// In zh, this message translates to:
  /// **'里程碑'**
  String get meStatMilestones;

  /// No description provided for @meStatPracticeTotal.
  ///
  /// In zh, this message translates to:
  /// **'练习总量'**
  String get meStatPracticeTotal;

  /// No description provided for @meStatStreak.
  ///
  /// In zh, this message translates to:
  /// **'坚持天数'**
  String get meStatStreak;

  /// No description provided for @meGrowthPracticeTotalValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 句 · {scenes} 场景'**
  String meGrowthPracticeTotalValue(Object count, Object scenes);

  /// No description provided for @meGrowthStreakValue.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天'**
  String meGrowthStreakValue(Object days);

  /// No description provided for @meAccountSignedOutHint.
  ///
  /// In zh, this message translates to:
  /// **'登录后同步数据'**
  String get meAccountSignedOutHint;

  /// No description provided for @meAccountSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中…'**
  String get meAccountSyncing;

  /// No description provided for @meReminders.
  ///
  /// In zh, this message translates to:
  /// **'提醒设置'**
  String get meReminders;

  /// No description provided for @meBabyProfile.
  ///
  /// In zh, this message translates to:
  /// **'宝宝档案'**
  String get meBabyProfile;

  /// No description provided for @mePlaybackPrefs.
  ///
  /// In zh, this message translates to:
  /// **'播放偏好'**
  String get mePlaybackPrefs;

  /// No description provided for @meHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get meHelp;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsReminderSection.
  ///
  /// In zh, this message translates to:
  /// **'提醒设置'**
  String get settingsReminderSection;

  /// No description provided for @settingsDailyReminder.
  ///
  /// In zh, this message translates to:
  /// **'每日提醒'**
  String get settingsDailyReminder;

  /// No description provided for @settingsNotEnabled.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get settingsNotEnabled;

  /// No description provided for @settingsBabyProfileSection.
  ///
  /// In zh, this message translates to:
  /// **'宝宝档案'**
  String get settingsBabyProfileSection;

  /// No description provided for @settingsBabyInfo.
  ///
  /// In zh, this message translates to:
  /// **'宝宝信息'**
  String get settingsBabyInfo;

  /// No description provided for @settingsTapToSetBabyInfo.
  ///
  /// In zh, this message translates to:
  /// **'点击设置宝宝信息'**
  String get settingsTapToSetBabyInfo;

  /// No description provided for @settingsCaregiverSection.
  ///
  /// In zh, this message translates to:
  /// **'看护人偏好'**
  String get settingsCaregiverSection;

  /// No description provided for @settingsRoleAndLanguage.
  ///
  /// In zh, this message translates to:
  /// **'角色与语言'**
  String get settingsRoleAndLanguage;

  /// No description provided for @settingsTapToSet.
  ///
  /// In zh, this message translates to:
  /// **'点击设置'**
  String get settingsTapToSet;

  /// No description provided for @settingsPlaybackSection.
  ///
  /// In zh, this message translates to:
  /// **'播放设置'**
  String get settingsPlaybackSection;

  /// No description provided for @settingsPlaybackPrefs.
  ///
  /// In zh, this message translates to:
  /// **'播放偏好'**
  String get settingsPlaybackPrefs;

  /// No description provided for @settingsAutoPlayOn.
  ///
  /// In zh, this message translates to:
  /// **'自动播放开启'**
  String get settingsAutoPlayOn;

  /// No description provided for @settingsAutoPlayOff.
  ///
  /// In zh, this message translates to:
  /// **'自动播放关闭'**
  String get settingsAutoPlayOff;

  /// No description provided for @settingsSpeed.
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get settingsSpeed;

  /// No description provided for @settingsHelpSection.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get settingsHelpSection;

  /// No description provided for @settingsHelpTitle.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get settingsHelpTitle;

  /// No description provided for @settingsAboutSection.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAboutSection;

  /// No description provided for @settingsAboutBabyTalk.
  ///
  /// In zh, this message translates to:
  /// **'关于 BabyTalk'**
  String get settingsAboutBabyTalk;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String settingsVersion(Object version);

  /// No description provided for @settingsMonthSuffix.
  ///
  /// In zh, this message translates to:
  /// **'{months}个月'**
  String settingsMonthSuffix(Object months);

  /// No description provided for @settingsLanguageZh.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get settingsLanguageZh;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// Mentor bubble on name input screen
  ///
  /// In zh, this message translates to:
  /// **'小禾想帮你记录这段珍贵的成长，可以告诉我一些关于宝宝的小信息吗？'**
  String get onboardingV21MentorGreeting;

  /// Name input label
  ///
  /// In zh, this message translates to:
  /// **'宝宝昵称（可选）'**
  String get onboardingV21NameLabel;

  /// Name input hint
  ///
  /// In zh, this message translates to:
  /// **'比如：小宝、小明...'**
  String get onboardingV21NameHint;

  /// Age selection title
  ///
  /// In zh, this message translates to:
  /// **'宝宝月龄'**
  String get onboardingV21AgeTitle;

  /// Save button on name screen
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get onboardingV21SaveButton;

  /// Skip button
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get onboardingV21SkipButton;

  /// Next button on name screen (deprecated)
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get onboardingV21NextButton;

  /// Scene selection title
  ///
  /// In zh, this message translates to:
  /// **'今天先说一句'**
  String get onboardingV21SceneTitle;

  /// Scene selection hint
  ///
  /// In zh, this message translates to:
  /// **'选个正在发生的场景'**
  String get onboardingV21SceneHint;

  /// Skip scene selection button
  ///
  /// In zh, this message translates to:
  /// **'直接给一句'**
  String get onboardingV21DirectPhrase;

  /// Age entry button
  ///
  /// In zh, this message translates to:
  /// **'宝宝多大？可稍后补'**
  String get onboardingV21AgeEntry;

  /// Skip age selection
  ///
  /// In zh, this message translates to:
  /// **'先跳过'**
  String get onboardingV21AgeSkip;

  /// Practice screen subtitle
  ///
  /// In zh, this message translates to:
  /// **'一句就够'**
  String get onboardingV21PracticeSubtitle;

  /// Said button on practice screen
  ///
  /// In zh, this message translates to:
  /// **'说完了'**
  String get onboardingV21SaidButton;

  /// Swap phrase button
  ///
  /// In zh, this message translates to:
  /// **'换一句'**
  String get onboardingV21SwapButton;

  /// End practice button
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get onboardingV21EndButton;

  /// Saved confirmation
  ///
  /// In zh, this message translates to:
  /// **'已保存本句'**
  String get onboardingV21Saved;

  /// Skip reaction button
  ///
  /// In zh, this message translates to:
  /// **'跳过，下一句'**
  String get onboardingV21SkipReaction;

  /// All phrases used
  ///
  /// In zh, this message translates to:
  /// **'句子都试过了'**
  String get onboardingV21PhrasesExhausted;

  /// Completion screen title
  ///
  /// In zh, this message translates to:
  /// **'小禾老师 / 今天已完成'**
  String get onboardingV21CompleteTitle;

  /// Practice again button
  ///
  /// In zh, this message translates to:
  /// **'再来一句'**
  String get onboardingV21AgainButton;

  /// Done button
  ///
  /// In zh, this message translates to:
  /// **'先到这里'**
  String get onboardingV21DoneButton;

  /// Next time copy
  ///
  /// In zh, this message translates to:
  /// **'下次打开，小禾会给你新的一句。'**
  String get onboardingV21NextTime;

  /// T4 one-turn practice screen title
  ///
  /// In zh, this message translates to:
  /// **'今日一句'**
  String get practiceOneTurnTitle;

  /// T4 one-turn timing label
  ///
  /// In zh, this message translates to:
  /// **'什么时候说'**
  String get practiceWhenToSay;

  /// T4 one-turn listen button
  ///
  /// In zh, this message translates to:
  /// **'听一下'**
  String get practiceListenOnce;

  /// T4 one-turn said button
  ///
  /// In zh, this message translates to:
  /// **'我说了'**
  String get practiceSaid;

  /// T4 one-turn audio completion status
  ///
  /// In zh, this message translates to:
  /// **'已听过一次'**
  String get practiceAudioPlayedOnce;

  /// T4 one-turn inline copy when current utterance has no audio asset
  ///
  /// In zh, this message translates to:
  /// **'这句暂时没有音频，可以直接说。'**
  String get practiceAudioMissingInline;

  /// T4 one-turn snackbar copy when current utterance has no audio asset
  ///
  /// In zh, this message translates to:
  /// **'这句暂时没有可播放的音频。'**
  String get practiceAudioMissingSnack;

  /// T4 one-turn inline copy when audio playback fails
  ///
  /// In zh, this message translates to:
  /// **'音频暂时不可用'**
  String get practiceAudioUnavailableInline;

  /// T4 one-turn snackbar copy when audio playback fails
  ///
  /// In zh, this message translates to:
  /// **'音频暂时不可用，请直接先说这一句。'**
  String get practiceAudioUnavailableSnack;

  /// T4 one-turn saving reaction trace status
  ///
  /// In zh, this message translates to:
  /// **'正在记下这次回应…'**
  String get practiceSavingTrace;

  /// T4 one-turn reaction prompt heading
  ///
  /// In zh, this message translates to:
  /// **'宝宝刚刚是什么反应？'**
  String get practiceReactionPrompt;

  /// T4 one-turn next support section title
  ///
  /// In zh, this message translates to:
  /// **'下一句照护支持'**
  String get practiceNextSupportTitle;

  /// T4 one-turn held fallback copy
  ///
  /// In zh, this message translates to:
  /// **'先停在这里，等下一次再继续。'**
  String get practiceQuietFallback;

  /// T4 one-turn garden trace section title
  ///
  /// In zh, this message translates to:
  /// **'花园留痕'**
  String get practiceGardenTraceTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

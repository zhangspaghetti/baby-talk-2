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
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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

  /// No description provided for @listen.
  ///
  /// In zh, this message translates to:
  /// **'听一下'**
  String get listen;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @playSentenceSemantics.
  ///
  /// In zh, this message translates to:
  /// **'播放这句话'**
  String get playSentenceSemantics;

  /// No description provided for @pauseSentenceSemantics.
  ///
  /// In zh, this message translates to:
  /// **'暂停播放'**
  String get pauseSentenceSemantics;

  /// No description provided for @loadingAudioSemantics.
  ///
  /// In zh, this message translates to:
  /// **'正在加载语音'**
  String get loadingAudioSemantics;

  /// No description provided for @audioUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时听不了，你也可以直接照着说。'**
  String get audioUnavailable;

  /// No description provided for @contextEntry.
  ///
  /// In zh, this message translates to:
  /// **'想让这句话更贴近一点吗？'**
  String get contextEntry;

  /// No description provided for @contextEntryHint.
  ///
  /// In zh, this message translates to:
  /// **'轻触告诉我'**
  String get contextEntryHint;

  /// No description provided for @contextPrompt.
  ///
  /// In zh, this message translates to:
  /// **'宝宝现在怎么了？'**
  String get contextPrompt;

  /// No description provided for @contextPromptHint.
  ///
  /// In zh, this message translates to:
  /// **'选一个最接近的就好'**
  String get contextPromptHint;

  /// No description provided for @collapseContext.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapseContext;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'再试一次'**
  String get retry;

  /// No description provided for @adjustingUtterance.
  ///
  /// In zh, this message translates to:
  /// **'正在让这句话更贴近一点…'**
  String get adjustingUtterance;

  /// No description provided for @recoverableFailure.
  ///
  /// In zh, this message translates to:
  /// **'这次没有换好，刚才那句话还可以继续用。'**
  String get recoverableFailure;

  /// No description provided for @unknownOutcome.
  ///
  /// In zh, this message translates to:
  /// **'刚才的调整还没有确认。'**
  String get unknownOutcome;

  /// No description provided for @loadingSentence.
  ///
  /// In zh, this message translates to:
  /// **'正在准备这句话…'**
  String get loadingSentence;

  /// No description provided for @loadFailure.
  ///
  /// In zh, this message translates to:
  /// **'这个小声音暂时没准备好。稍后再打开一次。'**
  String get loadFailure;

  /// No description provided for @timingSemantics.
  ///
  /// In zh, this message translates to:
  /// **'说这句话的时机：{timing}'**
  String timingSemantics(String timing);

  /// No description provided for @adjustedSentenceSemantics.
  ///
  /// In zh, this message translates to:
  /// **'说法已调整：{sentence}'**
  String adjustedSentenceSemantics(String sentence);
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

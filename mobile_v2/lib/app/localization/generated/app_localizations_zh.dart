// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get listen => '听一下';

  @override
  String get pause => '暂停';

  @override
  String get playSentenceSemantics => '播放这句话';

  @override
  String get pauseSentenceSemantics => '暂停播放';

  @override
  String get loadingAudioSemantics => '正在加载语音';

  @override
  String get audioUnavailable => '暂时听不了，你也可以直接照着说。';

  @override
  String get contextEntry => '想让这句话更贴近一点吗？';

  @override
  String get contextEntryHint => '轻触告诉我';

  @override
  String get contextPrompt => '宝宝现在怎么了？';

  @override
  String get contextPromptHint => '选一个最接近的就好';

  @override
  String get collapseContext => '收起';

  @override
  String get retry => '再试一次';

  @override
  String get adjustingUtterance => '正在让这句话更贴近一点…';

  @override
  String get recoverableFailure => '这次没有换好，刚才那句话还可以继续用。';

  @override
  String get unknownOutcome => '刚才的调整还没有确认。';

  @override
  String get loadingSentence => '正在准备这句话…';

  @override
  String get loadFailure => '这个小声音暂时没准备好。稍后再打开一次。';

  @override
  String timingSemantics(String timing) {
    return '说这句话的时机：$timing';
  }

  @override
  String adjustedSentenceSemantics(String sentence) {
    return '说法已调整：$sentence';
  }
}

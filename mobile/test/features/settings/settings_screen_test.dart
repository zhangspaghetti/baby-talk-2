import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';
import 'package:mobile/features/settings/presentation/settings_notifier.dart';
import 'package:mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('renders all six settings sections with correct titles', (
      tester,
    ) async {
      await _pumpSettingsScreen(tester);

      // Reminder section
      expect(find.text('提醒设置'), findsOneWidget);
      expect(find.text('每日提醒'), findsOneWidget);

      // Baby profile section
      expect(find.text('宝宝档案'), findsOneWidget);
      expect(find.text('宝宝信息'), findsOneWidget);

      // Caregiver preferences section
      expect(find.text('看护人偏好'), findsOneWidget);
      expect(find.text('角色与语言'), findsOneWidget);

      // Playback preferences section
      expect(find.text('播放设置'), findsOneWidget);
      expect(find.text('播放偏好'), findsOneWidget);

      // Help & feedback section
      expect(find.text('帮助与反馈'), findsWidgets);

      // About section
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('关于 BabyTalk'), findsOneWidget);
    });

    testWidgets('shows reminder switch with correct initial state', (
      tester,
    ) async {
      await _pumpSettingsScreen(
        tester,
        snapshot: const SettingsSnapshot(
          reminderEnabled: true,
          reminderHour: 20,
          reminderMinute: 30,
        ),
      );

      // Reminder shows time when enabled
      expect(find.text('20:30'), findsOneWidget);

      // Switch is present and on
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets('shows "未开启" when reminder is disabled', (tester) async {
      await _pumpSettingsScreen(
        tester,
        snapshot: const SettingsSnapshot(reminderEnabled: false),
      );

      expect(find.text('未开启'), findsOneWidget);
    });

    testWidgets('shows child name and age in baby profile subtitle', (
      tester,
    ) async {
      await _pumpSettingsScreen(
        tester,
        snapshot: const SettingsSnapshot(childName: '米米', childAgeMonths: 12),
      );

      expect(find.textContaining('米米'), findsOneWidget);
      expect(find.textContaining('12个月'), findsOneWidget);
    });

    testWidgets('shows default baby profile subtitle when name is empty', (
      tester,
    ) async {
      await _pumpSettingsScreen(tester);

      expect(find.text('点击设置宝宝信息'), findsOneWidget);
    });

    testWidgets('shows caregiver role and language in subtitle', (
      tester,
    ) async {
      await _pumpSettingsScreen(
        tester,
        snapshot: const SettingsSnapshot(
          caregiverRole: '妈妈',
          preferredLanguage: 'zh',
        ),
      );

      expect(find.textContaining('妈妈'), findsOneWidget);
      expect(find.textContaining('中文'), findsOneWidget);
    });

    testWidgets('localizes bilingual caregiver language in subtitle', (
      tester,
    ) async {
      await _pumpSettingsScreen(
        tester,
        snapshot: const SettingsSnapshot(
          caregiverRole: '妈妈',
          preferredLanguage: 'bilingual',
        ),
      );

      expect(find.textContaining('妈妈'), findsOneWidget);
      expect(find.textContaining('双语'), findsOneWidget);
      expect(find.textContaining('bilingual'), findsNothing);
    });

    testWidgets('shows playback auto-play and speed in subtitle', (
      tester,
    ) async {
      await _pumpSettingsScreen(
        tester,
        snapshot: const SettingsSnapshot(
          autoPlayEnabled: true,
          audioSpeed: 1.5,
        ),
      );

      expect(find.textContaining('自动播放开启'), findsOneWidget);
      expect(find.textContaining('1.5x'), findsOneWidget);
    });

    testWidgets('shows app version in about section', (tester) async {
      await _pumpSettingsScreen(
        tester,
        snapshot: const SettingsSnapshot(appVersion: '1.2.0'),
      );

      expect(find.textContaining('版本 1.2.0'), findsOneWidget);
    });

    testWidgets('shows loading spinner when notifier is loading', (
      tester,
    ) async {
      // Use a tall viewport so all sections are rendered without scrolling
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 3000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = _StubSettingsNotifier(
        snapshot: const SettingsSnapshot(),
        isLoading: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsNotifierProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.build(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      // The loading state shows CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('toggle reminder switch triggers updateReminder', (
      tester,
    ) async {
      bool? lastEnabledValue;
      int? lastHour;
      int? lastMinute;

      final notifier = _StubSettingsNotifier(
        snapshot: const SettingsSnapshot(
          reminderEnabled: false,
          reminderHour: 9,
          reminderMinute: 0,
        ),
        onReminderUpdate: (enabled, hour, minute) {
          lastEnabledValue = enabled;
          lastHour = hour;
          lastMinute = minute;
        },
      );

      await _pumpSettingsScreen(tester, notifier: notifier);

      // Tap the switch to enable
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(lastEnabledValue, isTrue);
      expect(lastHour, 9);
      expect(lastMinute, 0);
    });

    testWidgets('AppBar shows "设置" title', (tester) async {
      await _pumpSettingsScreen(tester);

      expect(find.text('设置'), findsOneWidget);
    });
  });
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  SettingsSnapshot? snapshot,
  bool isLoading = false,
  SettingsNotifier? notifier,
}) async {
  // Use a tall viewport so all sections are rendered without scrolling
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 3000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final effectiveNotifier =
      notifier ??
      _StubSettingsNotifier(
        snapshot: snapshot ?? const SettingsSnapshot(),
        isLoading: isLoading,
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsNotifierProvider.overrideWith((ref) => effectiveNotifier),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A stub [SettingsNotifier] for testing that does not require a real
/// repository. It exposes configurable state and callback hooks for
/// verifying method calls.
class _StubSettingsNotifier extends ChangeNotifier implements SettingsNotifier {
  _StubSettingsNotifier({
    SettingsSnapshot? snapshot,
    this.isLoading = false,
    this.onReminderUpdate,
  }) : _snapshot = snapshot ?? const SettingsSnapshot();

  SettingsSnapshot _snapshot;
  @override
  bool isLoading;
  @override
  bool isSaving = false;
  String? _errorMessage;

  void Function(bool enabled, int hour, int minute)? onReminderUpdate;

  @override
  SettingsSnapshot get snapshot => _snapshot;

  @override
  SettingsLoadStatus get loadStatus =>
      isLoading ? SettingsLoadStatus.loading : SettingsLoadStatus.ready;

  @override
  SettingsSaveStatus get saveStatus =>
      isSaving ? SettingsSaveStatus.saving : SettingsSaveStatus.idle;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get hasError => _errorMessage != null;

  @override
  bool get reminderEnabled => _snapshot.reminderEnabled;

  @override
  int get reminderHour => _snapshot.reminderHour;

  @override
  int get reminderMinute => _snapshot.reminderMinute;

  @override
  String get childName => _snapshot.childName;

  @override
  DateTime? get childBirthDate => _snapshot.childBirthDate;

  @override
  int? get childAgeMonths => _snapshot.childAgeMonths;

  @override
  String get childStage => _snapshot.childStage;

  @override
  String get caregiverRole => _snapshot.caregiverRole;

  @override
  String get preferredLanguage => _snapshot.preferredLanguage;

  @override
  bool get autoPlayEnabled => _snapshot.autoPlayEnabled;

  @override
  double get audioSpeed => _snapshot.audioSpeed;

  @override
  String get appVersion => _snapshot.appVersion;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> refreshAccountProfile() async {}

  @override
  Future<void> updateReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    onReminderUpdate?.call(enabled, hour, minute);
    _snapshot = _snapshot.copyWith(
      reminderEnabled: enabled,
      reminderHour: hour,
      reminderMinute: minute,
    );
    notifyListeners();
  }

  @override
  Future<void> updateBabyProfile({
    String? name,
    DateTime? birthDate,
    bool clearBirthDate = false,
    int? ageMonths,
    String? stage,
  }) async {
    _snapshot = _snapshot.copyWith(
      childName: name,
      childBirthDate: birthDate,
      clearChildBirthDate: clearBirthDate,
      childAgeMonths: ageMonths,
      childStage: stage,
    );
    notifyListeners();
  }

  @override
  Future<void> updateCaregiverPreferences({
    String? role,
    String? language,
  }) async {
    _snapshot = _snapshot.copyWith(
      caregiverRole: role,
      preferredLanguage: language,
    );
    notifyListeners();
  }

  @override
  Future<void> updatePlaybackPreferences({
    bool? autoPlay,
    double? speed,
  }) async {
    _snapshot = _snapshot.copyWith(
      autoPlayEnabled: autoPlay,
      audioSpeed: speed,
    );
    notifyListeners();
  }

  @override
  Future<void> resetToDefaults() async {
    _snapshot = const SettingsSnapshot();
    notifyListeners();
  }
}

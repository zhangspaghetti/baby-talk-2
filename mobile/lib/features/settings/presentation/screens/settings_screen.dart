import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(settingsNotifierProvider);
    final snapshot = notifier.snapshot;
    final colors = context.appColors;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: Text(l.settingsTitle),
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: notifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayoutConstants.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // --- Reminder ---
                    _SettingsSection(
                      title: l.settingsReminderSection,
                      children: [
                        _SettingsTile(
                          icon: Icons.notifications_outlined,
                          title: l.settingsDailyReminder,
                          subtitle: snapshot.reminderEnabled
                              ? '${_padZero(snapshot.reminderHour)}:${_padZero(snapshot.reminderMinute)}'
                              : l.settingsNotEnabled,
                          trailing: Switch(
                            value: snapshot.reminderEnabled,
                            onChanged: (value) {
                              ref
                                  .read(settingsNotifierProvider.notifier)
                                  .updateReminder(
                                    enabled: value,
                                    hour: snapshot.reminderHour,
                                    minute: snapshot.reminderMinute,
                                  );
                            },
                            activeThumbColor: colors.accent,
                          ),
                          onTap: () => context.push('/me/settings/reminder'),
                        ),
                      ],
                    ),

                    // --- Baby Profile ---
                    _SettingsSection(
                      title: l.settingsBabyProfileSection,
                      children: [
                        _SettingsTile(
                          icon: Icons.child_care_outlined,
                          title: l.settingsBabyInfo,
                          subtitle: snapshot.childName.isNotEmpty
                              ? '${snapshot.childName}${snapshot.childAgeMonths != null ? '  ·  ${l.settingsMonthSuffix(snapshot.childAgeMonths!)}' : ''}'
                              : l.settingsTapToSetBabyInfo,
                          onTap: () =>
                              context.push('/me/settings/baby-profile'),
                        ),
                      ],
                    ),

                    // --- Caregiver Preferences ---
                    _SettingsSection(
                      title: l.settingsCaregiverSection,
                      children: [
                        _SettingsTile(
                          icon: Icons.person_outline,
                          title: l.settingsRoleAndLanguage,
                          subtitle: snapshot.caregiverRole.isNotEmpty
                              ? '${snapshot.caregiverRole}  ·  ${_languageLabel(l, snapshot.preferredLanguage)}'
                              : l.settingsTapToSet,
                          onTap: () => context.push('/me/settings/caregiver'),
                        ),
                      ],
                    ),

                    // --- Playback Preferences ---
                    _SettingsSection(
                      title: l.settingsPlaybackSection,
                      children: [
                        _SettingsTile(
                          icon: Icons.play_circle_outline,
                          title: l.settingsPlaybackPrefs,
                          subtitle:
                              '${snapshot.autoPlayEnabled ? l.settingsAutoPlayOn : l.settingsAutoPlayOff}  ·  ${l.settingsSpeed} ${snapshot.audioSpeed}x',
                          onTap: () => context.push('/me/settings/playback'),
                        ),
                      ],
                    ),

                    // --- Help & Feedback ---
                    _SettingsSection(
                      title: l.settingsHelpSection,
                      children: [
                        _SettingsTile(
                          icon: Icons.help_outline,
                          title: l.settingsHelpSection,
                          onTap: () => context.push('/me/settings/help'),
                        ),
                      ],
                    ),

                    // --- About ---
                    _SettingsSection(
                      title: l.settingsAboutSection,
                      children: [
                        _SettingsTile(
                          icon: Icons.info_outline,
                          title: l.settingsAboutBabyTalk,
                          subtitle: snapshot.appVersion.isNotEmpty
                              ? l.settingsVersion(snapshot.appVersion)
                              : null,
                          onTap: () => context.push('/me/settings/about'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static String _padZero(int value) => value.toString().padLeft(2, '0');

  static String _languageLabel(AppLocalizations l, String code) {
    switch (code) {
      case 'zh':
        return l.settingsLanguageZh;
      case 'en':
        return l.settingsLanguageEn;
      case 'bilingual':
        return l.settingsLanguageBilingual;
      default:
        return code;
    }
  }
}

// ---------------------------------------------------------------------------
// Reusable layout widgets
// ---------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: colors.warmShadowSm,
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, color: colors.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13, color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

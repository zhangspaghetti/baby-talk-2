import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(settingsNotifierProvider);
    final snapshot = notifier.snapshot;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: notifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // --- Reminder ---
                _SettingsSection(
                  title: '提醒设置',
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: '每日提醒',
                      subtitle: snapshot.reminderEnabled
                          ? '${_padZero(snapshot.reminderHour)}:${_padZero(snapshot.reminderMinute)}'
                          : '未开启',
                      trailing: Switch(
                        value: snapshot.reminderEnabled,
                        onChanged: (value) {
                          ref.read(settingsNotifierProvider.notifier).updateReminder(
                                enabled: value,
                                hour: snapshot.reminderHour,
                                minute: snapshot.reminderMinute,
                              );
                        },
                        activeThumbColor: colors.accent,
                      ),
                      onTap: () => context.push('/settings/reminder'),
                    ),
                  ],
                ),

                // --- Baby Profile ---
                _SettingsSection(
                  title: '宝宝档案',
                  children: [
                    _SettingsTile(
                      icon: Icons.child_care_outlined,
                      title: '宝宝信息',
                      subtitle: snapshot.childName.isNotEmpty
                          ? '${snapshot.childName}${snapshot.childAgeMonths != null ? '  ·  ${snapshot.childAgeMonths}个月' : ''}'
                          : '点击设置宝宝信息',
                      onTap: () => context.push('/settings/baby-profile'),
                    ),
                  ],
                ),

                // --- Caregiver Preferences ---
                _SettingsSection(
                  title: '看护人偏好',
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline,
                      title: '角色与语言',
                      subtitle: snapshot.caregiverRole.isNotEmpty
                          ? '${snapshot.caregiverRole}  ·  ${_languageLabel(snapshot.preferredLanguage)}'
                          : '点击设置',
                      onTap: () => context.push('/settings/caregiver'),
                    ),
                  ],
                ),

                // --- Playback Preferences ---
                _SettingsSection(
                  title: '播放设置',
                  children: [
                    _SettingsTile(
                      icon: Icons.play_circle_outline,
                      title: '播放偏好',
                      subtitle:
                          '自动播放${snapshot.autoPlayEnabled ? '开启' : '关闭'}  ·  语速 ${snapshot.audioSpeed}x',
                      onTap: () => context.push('/settings/playback'),
                    ),
                  ],
                ),

                // --- Help & Feedback ---
                _SettingsSection(
                  title: '帮助与反馈',
                  children: [
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: '帮助与反馈',
                      onTap: () => context.push('/settings/help'),
                    ),
                  ],
                ),

                // --- About ---
                _SettingsSection(
                  title: '关于',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: '关于 BabyTalk',
                      subtitle: snapshot.appVersion.isNotEmpty
                          ? '版本 ${snapshot.appVersion}'
                          : null,
                      onTap: () => context.push('/settings/about'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _padZero(int value) => value.toString().padLeft(2, '0');

  static String _languageLabel(String code) {
    switch (code) {
      case 'zh':
        return '中文';
      case 'en':
        return 'English';
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
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textMuted,
                      ),
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

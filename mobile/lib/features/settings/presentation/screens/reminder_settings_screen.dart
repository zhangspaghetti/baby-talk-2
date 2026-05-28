import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';

class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(settingsNotifierProvider);
    final snapshot = notifier.snapshot;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('提醒设置'),
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/disable toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: colors.warmShadowSm,
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_outlined, color: colors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '每日提醒',
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '每天提醒宝宝练习',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
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
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Time picker
          if (snapshot.reminderEnabled) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: colors.warmShadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '提醒时间',
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${_padZero(snapshot.reminderHour)}:${_padZero(snapshot.reminderMinute)}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(context, ref, snapshot),
                      icon: const Icon(Icons.access_time, size: 18),
                      label: const Text('修改时间'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accent,
                        side: BorderSide(color: colors.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    dynamic snapshot,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: snapshot.reminderHour,
        minute: snapshot.reminderMinute,
      ),
    );
    if (picked != null) {
      ref.read(settingsNotifierProvider.notifier).updateReminder(
            enabled: true,
            hour: picked.hour,
            minute: picked.minute,
          );
    }
  }

  static String _padZero(int value) => value.toString().padLeft(2, '0');
}

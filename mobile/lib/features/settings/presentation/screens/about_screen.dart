import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(settingsNotifierProvider);
    final snapshot = notifier.snapshot;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('关于 BabyTalk'),
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App logo / icon placeholder
          Center(
            child: Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(top: 24, bottom: 16),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: colors.warmShadowMd,
              ),
              child: const Icon(
                Icons.child_care,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),

          // App name
          Center(
            child: Text(
              'BabyTalk',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '双语启蒙，自然发生',
              style: TextStyle(
                fontSize: 14,
                color: colors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: colors.warmShadowSm,
            ),
            child: Column(
              children: [
                _infoRow(colors, '版本', snapshot.appVersion.isNotEmpty
                    ? snapshot.appVersion
                    : '1.0.0'),
                Divider(color: colors.bgSunken),
                _infoRow(colors, '开发者', 'BabyTalk Studio'),
                Divider(color: colors.bgSunken),
                _infoRow(colors, '数据存储', '仅本地'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Legal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: colors.warmShadowSm,
            ),
            child: Column(
              children: [
                _legalTile(colors, '隐私政策'),
                Divider(color: colors.bgSunken),
                _legalTile(colors, '用户协议'),
                Divider(color: colors.bgSunken),
                _legalTile(colors, '开源许可'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Made with love for little learners',
              style: TextStyle(
                fontSize: 12,
                color: colors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(BabyTalkColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 15, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _legalTile(BabyTalkColors colors, String title) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(fontSize: 15, color: colors.textPrimary),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: colors.textMuted),
      onTap: () {
        // TODO: Implement legal pages
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/runtime/candidate_build_identity.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const buildIdentity = CandidateBuildIdentity.current;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('关于 BabyTalk'),
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
          child: ListView(
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
                  style: TextStyle(fontSize: 14, color: colors.textMuted),
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
                    _infoRow(colors, '版本', buildIdentity.appVersion),
                    Divider(color: colors.bgSunken),
                    _infoRow(colors, '候选 ID', buildIdentity.candidateId),
                    Divider(color: colors.bgSunken),
                    _infoRow(colors, '开发者', 'BabyTalk Studio'),
                    Divider(color: colors.bgSunken),
                    _infoRow(colors, '数据存储', '本地缓存与已登录账号云端数据'),
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
        ),
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
}

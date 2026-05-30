import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('帮助与反馈'),
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
              // FAQ section
              _buildSection(
                colors,
                title: '常见问题',
                children: [
                  _faqTile(
                    colors,
                    question: '如何开始使用 BabyTalk？',
                    answer: '完成引导流程后，系统会根据宝宝的月龄自动匹配适合的启蒙内容。',
                  ),
                  _faqTile(
                    colors,
                    question: '如何修改宝宝信息？',
                    answer: '前往 设置 → 宝宝档案，可以随时更新宝宝的昵称、月龄和成长阶段。',
                  ),
                  _faqTile(
                    colors,
                    question: '如何设置每日提醒？',
                    answer: '前往 设置 → 提醒设置，开启每日提醒并选择合适的提醒时间。',
                  ),
                  _faqTile(
                    colors,
                    question: '数据会同步到云端吗？',
                    answer: '当前版本所有数据仅存储在本地设备，不会上传到服务器。',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Feedback section
              _buildSection(
                colors,
                title: '意见反馈',
                children: [
                  _feedbackTile(
                    colors,
                    icon: Icons.email_outlined,
                    title: '发送邮件',
                    subtitle: 'feedback@babytalk.app',
                  ),
                  _feedbackTile(
                    colors,
                    icon: Icons.star_outline,
                    title: '给我们评分',
                    subtitle: '在应用商店为 BabyTalk 评分',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BabyTalkColors colors, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
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
    );
  }

  Widget _faqTile(
    BabyTalkColors colors, {
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        question,
        style: TextStyle(fontSize: 15, color: colors.textPrimary),
      ),
      iconColor: colors.accent,
      collapsedIconColor: colors.textMuted,
      children: [
        Text(
          answer,
          style: TextStyle(
            fontSize: 14,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _feedbackTile(
    BabyTalkColors colors, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: colors.accent),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, color: colors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: colors.textMuted),
      ),
      trailing: Icon(Icons.open_in_new, size: 16, color: colors.textMuted),
      onTap: () {
        // TODO: Implement external link / mailto
      },
    );
  }
}

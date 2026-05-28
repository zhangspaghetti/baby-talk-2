import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';

class CaregiverPreferencesScreen extends ConsumerStatefulWidget {
  const CaregiverPreferencesScreen({super.key});

  @override
  ConsumerState<CaregiverPreferencesScreen> createState() =>
      _CaregiverPreferencesScreenState();
}

class _CaregiverPreferencesScreenState
    extends ConsumerState<CaregiverPreferencesScreen> {
  String _selectedRole = '';
  String _selectedLanguage = 'zh';
  bool _initialized = false;

  void _syncFromNotifier(dynamic snapshot) {
    if (_initialized) return;
    _initialized = true;
    _selectedRole = snapshot.caregiverRole;
    _selectedLanguage = snapshot.preferredLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(settingsNotifierProvider);
    final snapshot = notifier.snapshot;
    final colors = context.appColors;

    _syncFromNotifier(snapshot);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('看护人偏好'),
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
              style: TextStyle(color: colors.accent, fontSize: 16),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Role
          _buildSection(
            colors,
            title: '您的角色',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _roleChip('妈妈', colors),
                _roleChip('爸爸', colors),
                _roleChip('祖父母', colors),
                _roleChip('其他', colors),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Language
          _buildSection(
            colors,
            title: '偏好语言',
            child: Column(
              children: [
                _languageTile('中文', 'zh', colors),
                _languageTile('English', 'en', colors),
                _languageTile('双语', 'bilingual', colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BabyTalkColors colors,
      {required String title, required Widget child}) {
    return Container(
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
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _roleChip(String role, BabyTalkColors colors) {
    final isSelected = _selectedRole == role;
    return ChoiceChip(
      label: Text(role),
      selected: isSelected,
      selectedColor: colors.accent,
      backgroundColor: colors.bgSunken,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colors.textPrimary,
        fontSize: 14,
      ),
      onSelected: (_) {
        setState(() {
          _selectedRole = role;
        });
      },
    );
  }

  Widget _languageTile(String label, String code, BabyTalkColors colors) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedLanguage = code;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value: code,
              groupValue: _selectedLanguage,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                }
              },
              activeColor: colors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 16, color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    ref.read(settingsNotifierProvider.notifier).updateCaregiverPreferences(
          role: _selectedRole,
          language: _selectedLanguage,
        );
    Navigator.of(context).pop();
  }
}

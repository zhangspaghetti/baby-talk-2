import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

class BabyProfileScreen extends ConsumerStatefulWidget {
  const BabyProfileScreen({super.key});

  @override
  ConsumerState<BabyProfileScreen> createState() => _BabyProfileScreenState();
}

class _BabyProfileScreenState extends ConsumerState<BabyProfileScreen> {
  late TextEditingController _nameController;
  String _selectedStage = '';
  int? _selectedAgeMonths;
  DateTime? _selectedBirthDate;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncFromNotifier(dynamic snapshot) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = snapshot.childName;
    _selectedStage = snapshot.childStage;
    _selectedAgeMonths = snapshot.childAgeMonths;
    _selectedBirthDate = snapshot.childBirthDate;
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
        title: const Text('宝宝档案'),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Name
              _buildSection(
                colors,
                title: '宝宝昵称',
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '请输入宝宝昵称',
                    hintStyle: TextStyle(color: colors.textMuted),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                  maxLength: 12,
                ),
              ),

              const SizedBox(height: 16),

              // Age months
              _buildSection(
                colors,
                title: '月龄',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ageChip(0, '0-3个月', colors),
                    _ageChip(3, '4-6个月', colors),
                    _ageChip(6, '7-9个月', colors),
                    _ageChip(9, '10-12个月', colors),
                    _ageChip(12, '1-2岁', colors),
                    _ageChip(24, '2-3岁', colors),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Birth date
              _buildSection(
                colors,
                title: '出生日期（选填）',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _selectedBirthDate != null
                        ? '${_selectedBirthDate!.year}-${_padZero(_selectedBirthDate!.month)}-${_padZero(_selectedBirthDate!.day)}'
                        : '点击选择',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedBirthDate != null
                          ? colors.textPrimary
                          : colors.textMuted,
                    ),
                  ),
                  trailing: Icon(Icons.calendar_today, color: colors.accent),
                  onTap: _pickBirthDate,
                ),
              ),

              const SizedBox(height: 16),

              // Stage
              _buildSection(
                colors,
                title: '成长阶段',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _stageChip('听觉启蒙', colors),
                    _stageChip('语言萌芽', colors),
                    _stageChip('表达爆发', colors),
                    _stageChip('社交互动', colors),
                  ],
                ),
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
    required Widget child,
  }) {
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
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _ageChip(int months, String label, BabyTalkColors colors) {
    final isSelected = _selectedAgeMonths == months;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: colors.accent,
      backgroundColor: colors.bgSunken,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colors.textPrimary,
        fontSize: 14,
      ),
      onSelected: (_) {
        setState(() {
          _selectedAgeMonths = months;
        });
      },
    );
  }

  Widget _stageChip(String stage, BabyTalkColors colors) {
    final isSelected = _selectedStage == stage;
    return ChoiceChip(
      label: Text(stage),
      selected: isSelected,
      selectedColor: colors.accent,
      backgroundColor: colors.bgSunken,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colors.textPrimary,
        fontSize: 14,
      ),
      onSelected: (_) {
        setState(() {
          _selectedStage = stage;
        });
      },
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
        );
      });
    }
  }

  void _save() {
    ref
        .read(settingsNotifierProvider.notifier)
        .updateBabyProfile(
          name: _nameController.text.trim(),
          birthDate: _selectedBirthDate,
          clearBirthDate: _selectedBirthDate == null,
          ageMonths: _selectedAgeMonths,
          stage: _selectedStage,
        );
    Navigator.of(context).pop();
  }

  static String _padZero(int value) => value.toString().padLeft(2, '0');
}

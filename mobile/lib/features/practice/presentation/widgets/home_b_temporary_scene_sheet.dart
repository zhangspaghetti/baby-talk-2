import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Temporary scene bottom sheet for Home B.
///
/// Opens when a quick rescue chip is tapped. Lets the parent describe
/// their current situation and get Xiaohe's suggested phrase.
///
/// Design spec flow:
/// 1. Xiaohe header: "现在想说什么场景？"
/// 2. Quick chip list (horizontal scroll)
/// 3. User input: "自己说说看"
/// 4. CTA: "帮我一句"
/// 5. Response: main phrase + up to 2 alternatives
class HomeBTemporarySceneSheet extends ConsumerStatefulWidget {
  const HomeBTemporarySceneSheet({
    super.key,
    this.initialScene,
  });

  final String? initialScene;

  @override
  ConsumerState<HomeBTemporarySceneSheet> createState() =>
      _HomeBTemporarySceneSheetState();
}

class _HomeBTemporarySceneSheetState
    extends ConsumerState<HomeBTemporarySceneSheet> {
  final _inputController = TextEditingController();
  String? _selectedScene;
  bool _isGenerating = false;
  _SceneResponse? _response;

  static const List<String> _quickScenes = [
    '宝宝不肯睡',
    '洗澡哭了',
    '要出门了',
    '吃饭时闹',
    '摔倒了哭',
    '不想刷牙',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialScene != null) {
      _selectedScene = widget.initialScene;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _generateSuggestion() async {
    final query = _inputController.text.trim().isNotEmpty
        ? _inputController.text.trim()
        : _selectedScene;
    if (query == null || query.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _response = null;
    });

    // TODO: Connect to actual LLM mentor service
    // For now, return mock responses based on the scene
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      _response = _mockResponseFor(query);
    });
  }

  _SceneResponse _mockResponseFor(String scene) {
    if (scene.contains('睡')) {
      return const _SceneResponse(
        mainPhrase: 'Time to sleep.',
        mainChinese: '该睡觉了',
        tip: '降低声音，不讲长道理，轻轻拍着说。',
        alternatives: [
          _AlternativePhrase(english: 'Sweet dreams.', chinese: '做个好梦'),
          _AlternativePhrase(
            english: "Let's read one more.",
            chinese: '再读一本就睡',
          ),
        ],
      );
    }
    if (scene.contains('洗澡') || scene.contains('哭')) {
      return const _SceneResponse(
        mainPhrase: "It's okay.",
        mainChinese: '没关系的',
        tip: '先安抚情绪，声音放柔，不要急着擦干。',
        alternatives: [
          _AlternativePhrase(english: 'All clean!', chinese: '洗干净啦'),
        ],
      );
    }
    if (scene.contains('出门')) {
      return const _SceneResponse(
        mainPhrase: 'Shoes on.',
        mainChinese: '穿鞋啦',
        tip: '指着鞋子说，给一个明确的下一步。',
        alternatives: [
          _AlternativePhrase(
            english: "Let's go!",
            chinese: '走吧！',
          ),
          _AlternativePhrase(
            english: 'Ready?',
            chinese: '准备好了吗？',
          ),
        ],
      );
    }
    // Generic fallback
    return _SceneResponse(
      mainPhrase: 'You can do it.',
      mainChinese: '你可以的',
      tip: '温柔地说，给一个简单的动作指令。',
      alternatives: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const Key('home-b-temporary-scene-sheet'),
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Xiaohe header
                Text(
                  '现在想说什么场景？',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '小禾帮你挑一句最合适的',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Quick scene chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickScenes.map((scene) {
                    final isSelected = _selectedScene == scene;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedScene = scene;
                          _inputController.clear();
                        });
                      },
                      child: Chip(
                        label: Text(scene),
                        backgroundColor: isSelected
                            ? colors.accentDark
                            : colors.bgSunken,
                        side: BorderSide(
                          color:
                              isSelected ? colors.accentDark : colors.outlineSoft,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : colors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Custom input
                TextField(
                  controller: _inputController,
                  onChanged: (_) {
                    if (_selectedScene != null) {
                      setState(() => _selectedScene = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '自己说说看…',
                    hintStyle: TextStyle(color: colors.textMuted),
                    filled: true,
                    fillColor: colors.bgSunken,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.outlineSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.outlineSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.accentDark),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('home-b-temporary-cta'),
                    onPressed: (_selectedScene != null ||
                            _inputController.text.trim().isNotEmpty)
                        ? _generateSuggestion
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('帮我一句'),
                  ),
                ),

                // Response area
                if (_response != null) ...[
                  const SizedBox(height: 24),
                  _buildResponseArea(theme, colors),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseArea(ThemeData theme, BabyTalkColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main phrase
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.englishSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '小禾推荐',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.accentDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _response!.mainPhrase,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.english,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _response!.mainChinese,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _response!.tip,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        // Alternative phrases
        if (_response!.alternatives.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '也可以试试',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _response!.alternatives.length,
              separatorBuilder: (a, b) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final alt = _response!.alternatives[index];
                return GestureDetector(
                  onTap: () {
                    // TODO: Enter practice with this phrase
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: colors.outlineSoft),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alt.english,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.english,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          alt.chinese,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // Action buttons
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Re-generate with softer tone
                  _generateSuggestion();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('换个更温柔的说法'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('回到今日计划'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SceneResponse {
  const _SceneResponse({
    required this.mainPhrase,
    required this.mainChinese,
    required this.tip,
    required this.alternatives,
  });

  final String mainPhrase;
  final String mainChinese;
  final String tip;
  final List<_AlternativePhrase> alternatives;
}

class _AlternativePhrase {
  const _AlternativePhrase({
    required this.english,
    required this.chinese,
  });

  final String english;
  final String chinese;
}

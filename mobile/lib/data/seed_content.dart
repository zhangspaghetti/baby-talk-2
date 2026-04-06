import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SeedContent {
  static final List<SpaceItem> spaces = [
    SpaceItem(
      id: 'morning-care',
      name: '晨间护理',
      subtitle: 'Morning Care',
      icon: Icons.wb_sunny_outlined,
      color: const Color(0xFFF5B971),
      mapOffset: const Offset(36, 32),
      activities: const [
        ActivityItem(
          id: 'diaper',
          name: '换尿布',
          shortLabel: '准备开工',
          icon: Icons.baby_changing_station_outlined,
          progress: 0.84,
          growthStage: GrowthStage.bloom,
          phrases: [
            PhraseItem(
              id: 'diaper-1',
              english: 'Let\'s change your diaper.',
              chinese: '我们来换尿布啦。',
              mastered: true,
            ),
            PhraseItem(
              id: 'diaper-2',
              english: 'All clean, all cozy.',
              chinese: '干干净净，舒舒服服。',
            ),
          ],
        ),
        ActivityItem(
          id: 'dress-up',
          name: '穿衣服',
          shortLabel: '抬高手臂',
          icon: Icons.checkroom_outlined,
          progress: 0.42,
          growthStage: GrowthStage.bud,
          phrases: [
            PhraseItem(
              id: 'dress-1',
              english: 'Arms up, let\'s get dressed.',
              chinese: '小手举高，我们穿衣服。',
            ),
            PhraseItem(
              id: 'dress-2',
              english: 'One sock, two socks.',
              chinese: '一只袜子，两只袜子。',
            ),
          ],
        ),
      ],
    ),
    SpaceItem(
      id: 'sensory-play',
      name: '感官探索',
      subtitle: 'Sensory Play',
      icon: Icons.bubble_chart_outlined,
      color: AppPalette.english,
      mapOffset: const Offset(204, 144),
      activities: const [
        ActivityItem(
          id: 'bath-time',
          name: '洗澡',
          shortLabel: '泼水时间',
          icon: Icons.bathtub_outlined,
          progress: 0.65,
          growthStage: GrowthStage.bud,
          phrases: [
            PhraseItem(
              id: 'bath-1',
              english: 'Splash splash! Can you splash with me?',
              chinese: '泼水泼水！你能和我一起泼吗？',
            ),
            PhraseItem(
              id: 'bath-2',
              english: 'Water time feels warm and safe.',
              chinese: '水水暖暖的，很安心。',
            ),
          ],
        ),
        ActivityItem(
          id: 'touch-game',
          name: '触觉游戏',
          shortLabel: '摸一摸软软的',
          icon: Icons.pan_tool_alt_outlined,
          progress: 0.28,
          growthStage: GrowthStage.sprout,
          phrases: [
            PhraseItem(
              id: 'touch-1',
              english: 'Soft, fluffy, gentle touch.',
              chinese: '软软的，轻轻摸一摸。',
            ),
            PhraseItem(
              id: 'touch-2',
              english: 'Can you feel the texture?',
              chinese: '你摸到这个触感了吗？',
            ),
          ],
        ),
      ],
    ),
    SpaceItem(
      id: 'bonding',
      name: '亲密互动',
      subtitle: 'Bonding',
      icon: Icons.favorite_border,
      color: const Color(0xFFE68A7B),
      mapOffset: const Offset(386, 112),
      activities: const [
        ActivityItem(
          id: 'feeding',
          name: '喂奶/辅食',
          shortLabel: '张大嘴巴',
          icon: Icons.restaurant_outlined,
          progress: 0.76,
          growthStage: GrowthStage.bud,
          phrases: [
            PhraseItem(
              id: 'feed-1',
              english: 'Open wide, here comes a yummy bite.',
              chinese: '张大嘴巴，好吃的一口来啦。',
            ),
            PhraseItem(
              id: 'feed-2',
              english: 'You did it, little one.',
              chinese: '你做到了，小宝贝。',
              mastered: true,
            ),
          ],
        ),
        ActivityItem(
          id: 'comfort',
          name: '拥抱安抚',
          shortLabel: '抱抱安稳下来',
          icon: Icons.self_improvement_outlined,
          progress: 0.38,
          growthStage: GrowthStage.sprout,
          phrases: [
            PhraseItem(
              id: 'comfort-1',
              english: 'I am right here with you.',
              chinese: '我就在这里陪着你。',
            ),
            PhraseItem(
              id: 'comfort-2',
              english: 'Let\'s take one soft breath together.',
              chinese: '我们一起轻轻呼一口气。',
            ),
          ],
        ),
      ],
    ),
    SpaceItem(
      id: 'active-play',
      name: '活力游戏',
      subtitle: 'Active Play',
      icon: Icons.directions_run_outlined,
      color: const Color(0xFF9FB95A),
      mapOffset: const Offset(88, 288),
      activities: const [
        ActivityItem(
          id: 'tpr',
          name: 'TPR 动作',
          shortLabel: '拍拍小手',
          icon: Icons.waving_hand_outlined,
          progress: 0.52,
          growthStage: GrowthStage.bud,
          phrases: [
            PhraseItem(
              id: 'tpr-1',
              english: 'Clap your hands, clap clap clap!',
              chinese: '拍拍小手，拍拍拍。',
            ),
            PhraseItem(
              id: 'tpr-2',
              english: 'Reach up high, touch the sky.',
              chinese: '把手举高高，碰一碰天空。',
            ),
          ],
        ),
        ActivityItem(
          id: 'walk',
          name: '户外散步',
          shortLabel: '看看树和云',
          icon: Icons.stroller_outlined,
          progress: 0.18,
          growthStage: GrowthStage.seed,
          phrases: [
            PhraseItem(
              id: 'walk-1',
              english: 'Look at the trees swaying.',
              chinese: '看看树在轻轻摇。',
            ),
            PhraseItem(
              id: 'walk-2',
              english: 'Clouds are floating by.',
              chinese: '云朵慢慢飘过去。',
            ),
          ],
        ),
      ],
    ),
    SpaceItem(
      id: 'story-time',
      name: '阅读时光',
      subtitle: 'Story Time',
      icon: Icons.auto_stories_outlined,
      color: const Color(0xFF89A7D3),
      mapOffset: const Offset(292, 300),
      activities: const [
        ActivityItem(
          id: 'picture-book',
          name: '绘本共读',
          shortLabel: '看看书里有什么',
          icon: Icons.menu_book_outlined,
          progress: 0.46,
          growthStage: GrowthStage.sprout,
          phrases: [
            PhraseItem(
              id: 'book-1',
              english: 'What do you see on this page?',
              chinese: '你看到这一页有什么呀？',
            ),
            PhraseItem(
              id: 'book-2',
              english: 'Turn the page, let\'s peek again.',
              chinese: '翻一页，我们再偷看一下。',
            ),
          ],
        ),
        ActivityItem(
          id: 'nursery-rhyme',
          name: '儿歌',
          shortLabel: '轻轻唱出来',
          icon: Icons.music_note_outlined,
          progress: 0.34,
          growthStage: GrowthStage.sprout,
          phrases: [
            PhraseItem(
              id: 'song-1',
              english: 'Twinkle softly, little tune.',
              chinese: '轻轻闪呀，小小旋律。',
            ),
            PhraseItem(
              id: 'song-2',
              english: 'La la la, we sing together.',
              chinese: '啦啦啦，我们一起唱。',
            ),
          ],
        ),
      ],
    ),
    SpaceItem(
      id: 'bedtime',
      name: '睡前仪式',
      subtitle: 'Bedtime',
      icon: Icons.nightlight_outlined,
      color: const Color(0xFF7B73A8),
      mapOffset: const Offset(212, 420),
      activities: const [
        ActivityItem(
          id: 'lullaby',
          name: '摇篮曲',
          shortLabel: '轻轻唱晚安',
          icon: Icons.bedtime_outlined,
          progress: 0.61,
          growthStage: GrowthStage.bud,
          phrases: [
            PhraseItem(
              id: 'sleep-1',
              english: 'Time to sleep, little one.',
              chinese: '该睡觉啦，小宝贝。',
            ),
            PhraseItem(
              id: 'sleep-2',
              english: 'Close your eyes, I am with you.',
              chinese: '闭上眼睛，我就在这里。',
            ),
          ],
        ),
        ActivityItem(
          id: 'goodnight',
          name: '道晚安',
          shortLabel: '给今天一个拥抱',
          icon: Icons.brightness_2_outlined,
          progress: 0.24,
          growthStage: GrowthStage.seed,
          phrases: [
            PhraseItem(
              id: 'night-1',
              english: 'Good night, thank you for today.',
              chinese: '晚安呀，谢谢你今天的陪伴。',
            ),
            PhraseItem(
              id: 'night-2',
              english: 'Tomorrow we\'ll try another little phrase.',
              chinese: '明天我们再试一句新的短语。',
            ),
          ],
        ),
      ],
    ),
  ];

  static const List<DiaryEntry> diaryEntries = [
    DiaryEntry(
      title: '洗澡时你说出 “Splash splash”，小明一边看水花一边发出长长的 “baaa”。',
      subtitle: '自动日记 · 感官探索',
      timeLabel: '今天 18:40',
      type: DiaryEntryType.autoNote,
    ),
    DiaryEntry(
      title: '晚上抱着他时，重复了 “I am right here with you”，哭声安静得更快了。',
      subtitle: '手动记录 · 亲密互动',
      timeLabel: '昨天 21:15',
      type: DiaryEntryType.manualNote,
    ),
    DiaryEntry(
      title: '晨间护理连着第三天完成，节奏明显顺了很多。',
      subtitle: '自动日记 · 晨间护理',
      timeLabel: '昨天 08:05',
      type: DiaryEntryType.autoNote,
    ),
  ];

  static const List<MilestoneEntry> milestones = [
    MilestoneEntry(
      title: '第一次跟着节奏发声',
      detail: '在洗澡短语里听到 “splash” 后，小明主动发出模仿音。',
      timeLabel: '今天',
    ),
    MilestoneEntry(
      title: '连续 5 天打开 app',
      detail: '日常循环开始形成，这才是 Phase 1 真正要验证的东西。',
      timeLabel: '本周',
    ),
  ];

  static const List<CoachSuggestion> coachSuggestions = [
    CoachSuggestion(
      title: '马上要洗澡了，先练两句轻快的短语',
      detail: '从 “Splash splash” 开始，再补一句动作描述，宝宝更容易连动作和声音。',
    ),
    CoachSuggestion(
      title: '今天状态一般，就用更短更稳的安抚句',
      detail: '先说节奏慢、重复高的句子，不要一上来塞长句。',
    ),
    CoachSuggestion(
      title: '如果家里有人围观，先用 whisper 模式',
      detail: '先小声说一句，再慢慢放大。比强行“开麦”靠谱得多。',
    ),
    CoachSuggestion(title: '晚饭后适合切到阅读时光', detail: '让英语从任务感切回陪伴感，第二天更容易继续。'),
    CoachSuggestion(
      title: '今天可以试试一句 “Open wide”',
      detail: '喂辅食时的句子反馈最直接，父母也更容易坚持。',
    ),
  ];
}

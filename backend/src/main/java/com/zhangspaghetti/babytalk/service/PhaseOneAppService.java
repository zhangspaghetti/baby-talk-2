package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.BabyTalkPayloads;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PhaseOneAppService {

    private final Object monitor = new Object();
    private final AppProfileState state = createSeedState();

    public BabyTalkPayloads.AppSnapshotResponse bootstrap() {
        synchronized (monitor) {
            return toSnapshot(state);
        }
    }

    public BabyTalkPayloads.AppSnapshotResponse completeOnboarding(
            BabyTalkPayloads.OnboardingRequest request
    ) {
        synchronized (monitor) {
            state.caregiverName = normalizeName(request.caregiverName(), "陪伴者");
            state.childName = normalizeName(request.childName(), "宝宝");
            state.childAgeMonths = Math.max(0, request.childAgeMonths());
            state.difficulty = normalizeDifficulty(request.difficulty());
            state.onboardingComplete = true;
            prependDiary(
                    "小禾老师帮 " + state.caregiverName + " 完成了入门设定，今天从一句最容易说出口的英语开始。",
                    "自动日记 · 对话式 Onboarding",
                    "刚刚",
                    "auto_note"
            );
            return toSnapshot(state);
        }
    }

    public BabyTalkPayloads.AppActionResponse registerReaction(
            BabyTalkPayloads.PracticeReactionRequest request
    ) {
        synchronized (monitor) {
            ActivityState activity = findActivity(request.activityId());
            PhraseState phrase = findPhrase(activity, request.phraseId());
            String reaction = normalizeReaction(request.reaction());

            phrase.mastered = true;
            double increment = switch (reaction) {
                case "listened" -> 0.08;
                case "babbled" -> 0.18;
                case "skipped" -> 0.04;
                default -> throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Unknown reaction: " + request.reaction()
                );
            };
            int pointGain = switch (reaction) {
                case "listened" -> 2;
                case "babbled" -> 6;
                case "skipped" -> 1;
                default -> 0;
            };

            activity.progress = clamp(activity.progress + increment, 0.0, 1.0);
            activity.growthStage = growthStageFor(activity.progress);
            state.growthPoints += pointGain;
            state.weeklyPhraseCount += 1;

            prependDiary(
                    diaryCopyForReaction(activity, phrase, reaction),
                    "自动日记 · " + findSpaceForActivity(activity.id).name,
                    "刚刚",
                    "auto_note"
            );

            BabyTalkPayloads.CelebrationMomentResponse celebration = null;
            if ("babbled".equals(reaction) && state.earnedMilestoneIds.add("first-babble-ever")) {
                prependMilestone(
                        "第一次跟着发声",
                        state.childName + " 在 " + activity.name + " 里第一次跟着你发出了声音。",
                        "刚刚"
                );
                celebration = new BabyTalkPayloads.CelebrationMomentResponse(
                        state.childName + " 跟着你一起发声了",
                        "这不是 demo 路径，是第一次真正成立的反馈回路。继续把今天这一句说完。",
                        activity.name,
                        pointGain
                );
            }

            String bloomMilestoneId = "activity-bloom-" + activity.id;
            if (celebration == null && activity.progress >= 0.9 && state.earnedMilestoneIds.add(bloomMilestoneId)) {
                prependMilestone(
                        activity.name + " 进入盛开态",
                        findSpaceForActivity(activity.id).name + " 这朵花已经被你练到接近稳定输出。",
                        "刚刚"
                );
                celebration = new BabyTalkPayloads.CelebrationMomentResponse(
                        activity.name + " 开花了",
                        "花园里会留下痕迹，用户就会相信每天说一句这件事值得做。",
                        activity.name,
                        pointGain
                );
            }

            return new BabyTalkPayloads.AppActionResponse(toSnapshot(state), celebration);
        }
    }

    public BabyTalkPayloads.AppActionResponse waterPatch(
            BabyTalkPayloads.WaterPatchRequest request
    ) {
        synchronized (monitor) {
            SpaceState space = findSpace(request.spaceId());
            if (state.growthPoints >= 5) {
                state.growthPoints -= 5;
                prependDiary(
                        "你给 " + space.name + " 浇了水，花园的反馈又清楚了一点。",
                        "自动日记 · 花园系统",
                        "刚刚",
                        "auto_note"
                );
            }
            return new BabyTalkPayloads.AppActionResponse(toSnapshot(state), null);
        }
    }

    private BabyTalkPayloads.AppSnapshotResponse toSnapshot(AppProfileState currentState) {
        List<BabyTalkPayloads.SpaceResponse> spaces = currentState.spaces.stream()
                .map(space -> new BabyTalkPayloads.SpaceResponse(
                        space.id,
                        space.name,
                        space.subtitle,
                        space.iconKey,
                        space.colorHex,
                        space.mapOffsetX,
                        space.mapOffsetY,
                        space.activities.stream()
                                .map(activity -> new BabyTalkPayloads.ActivityResponse(
                                        activity.id,
                                        activity.name,
                                        activity.shortLabel,
                                        activity.iconKey,
                                        activity.progress,
                                        activity.growthStage,
                                        activity.phrases.stream()
                                                .map(phrase -> new BabyTalkPayloads.PhraseResponse(
                                                        phrase.id,
                                                        phrase.english,
                                                        phrase.chinese,
                                                        phrase.mastered
                                                ))
                                                .toList()
                                ))
                                .toList()
                ))
                .toList();

        List<BabyTalkPayloads.DiaryEntryResponse> diaryEntries = currentState.diaryEntries.stream()
                .map(entry -> new BabyTalkPayloads.DiaryEntryResponse(
                        entry.title,
                        entry.subtitle,
                        entry.timeLabel,
                        entry.type
                ))
                .toList();

        List<BabyTalkPayloads.MilestoneEntryResponse> milestones = currentState.milestones.stream()
                .map(entry -> new BabyTalkPayloads.MilestoneEntryResponse(
                        entry.title,
                        entry.detail,
                        entry.timeLabel
                ))
                .toList();

        List<BabyTalkPayloads.CoachSuggestionResponse> coachSuggestions = new ArrayList<>();
        StageInfo stage = stageForAgeMonths(currentState.childAgeMonths);
        coachSuggestions.add(new BabyTalkPayloads.CoachSuggestionResponse(
                stage.title + " 当前最该做什么？",
                stage.coachCopy + " 先用 " + difficultyLabel(currentState.difficulty) + " 难度去跑通今天的一次练习。"
        ));
        coachSuggestions.addAll(currentState.coachSuggestions.stream()
                .map(entry -> new BabyTalkPayloads.CoachSuggestionResponse(entry.title, entry.detail))
                .toList());

        return new BabyTalkPayloads.AppSnapshotResponse(
                currentState.caregiverName,
                currentState.childName,
                currentState.childAgeMonths,
                currentState.difficulty,
                currentState.onboardingComplete,
                currentState.growthPoints,
                currentState.weeklyPhraseCount,
                currentState.streakDays,
                currentState.earnedMilestoneIds.stream().sorted().toList(),
                spaces,
                diaryEntries,
                milestones,
                coachSuggestions
        );
    }

    private void prependDiary(String title, String subtitle, String timeLabel, String type) {
        state.diaryEntries.add(0, new DiaryEntryState(title, subtitle, timeLabel, type));
    }

    private void prependMilestone(String title, String detail, String timeLabel) {
        state.milestones.add(0, new MilestoneState(title, detail, timeLabel));
    }

    private ActivityState findActivity(String activityId) {
        return state.spaces.stream()
                .flatMap(space -> space.activities.stream())
                .filter(activity -> activity.id.equals(activityId))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Unknown activity: " + activityId
                ));
    }

    private PhraseState findPhrase(ActivityState activity, String phraseId) {
        return activity.phrases.stream()
                .filter(phrase -> phrase.id.equals(phraseId))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Unknown phrase: " + phraseId
                ));
    }

    private SpaceState findSpace(String spaceId) {
        return state.spaces.stream()
                .filter(space -> space.id.equals(spaceId))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Unknown space: " + spaceId
                ));
    }

    private SpaceState findSpaceForActivity(String activityId) {
        return state.spaces.stream()
                .filter(space -> space.activities.stream().anyMatch(activity -> activity.id.equals(activityId)))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "No space found for activity: " + activityId
                ));
    }

    private String diaryCopyForReaction(ActivityState activity, PhraseState phrase, String reaction) {
        return switch (reaction) {
            case "listened" -> "在 " + activity.name + " 里说出 “" + phrase.english + "” 时，" + state.childName + " 安静地听了进去。";
            case "babbled" -> "你说 “" + phrase.english + "” 时，" + state.childName + " 立刻给了声音回应。";
            case "skipped" -> activity.name + " 这一句今天没有硬推，先把节奏稳住。";
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown reaction: " + reaction);
        };
    }

    private String normalizeDifficulty(String difficulty) {
        if (difficulty == null || difficulty.isBlank()) {
            return "balanced";
        }
        String normalized = difficulty.trim().toLowerCase();
        return switch (normalized) {
            case "gentle", "balanced", "stretch" -> normalized;
            default -> "balanced";
        };
    }

    private String difficultyLabel(String difficulty) {
        return switch (normalizeDifficulty(difficulty)) {
            case "gentle" -> "轻松";
            case "stretch" -> "进阶";
            default -> "标准";
        };
    }

    private String normalizeReaction(String reaction) {
        if (reaction == null || reaction.isBlank()) {
            return "listened";
        }
        return reaction.trim().toLowerCase();
    }

    private String normalizeName(String value, String fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return value.trim();
    }

    private double clamp(double value, double min, double max) {
        return Math.max(min, Math.min(max, value));
    }

    private String growthStageFor(double progress) {
        if (progress >= 0.9) {
            return "bloom";
        }
        if (progress >= 0.6) {
            return "bud";
        }
        if (progress >= 0.25) {
            return "sprout";
        }
        return "seed";
    }

    private StageInfo stageForAgeMonths(int months) {
        for (StageInfo stage : stages()) {
            if (months >= stage.minMonths && months <= stage.maxMonths) {
                return stage;
            }
        }
        return stages().get(stages().size() - 1);
    }

    private List<StageInfo> stages() {
        return List.of(
                new StageInfo("阶段 1", "听感唤醒", 0, 5, "先让英语像家里的背景音出现"),
                new StageInfo("阶段 2", "日常对话", 6, 11, "把吃睡洗抱接到一句短语上"),
                new StageInfo("阶段 3", "动作互动", 12, 17, "边做动作边说，宝宝更容易跟上"),
                new StageInfo("阶段 4", "绘本联想", 18, 23, "把画面、声音和指令串起来"),
                new StageInfo("阶段 5", "表达跃迁", 24, 36, "从单句走向更完整的情境表达")
        );
    }

    private AppProfileState createSeedState() {
        List<SpaceState> spaces = List.of(
                new SpaceState(
                        "morning-care",
                        "晨间护理",
                        "Morning Care",
                        "wb_sunny_outlined",
                        "#F5B971",
                        36,
                        32,
                        new ArrayList<>(List.of(
                                new ActivityState(
                                        "diaper",
                                        "换尿布",
                                        "准备开工",
                                        "baby_changing_station_outlined",
                                        0.84,
                                        "bloom",
                                        new ArrayList<>(List.of(
                                                new PhraseState("diaper-1", "Let's change your diaper.", "我们来换尿布啦。", true),
                                                new PhraseState("diaper-2", "All clean, all cozy.", "干干净净，舒舒服服。", false)
                                        ))
                                ),
                                new ActivityState(
                                        "dress-up",
                                        "穿衣服",
                                        "抬高手臂",
                                        "checkroom_outlined",
                                        0.42,
                                        "bud",
                                        new ArrayList<>(List.of(
                                                new PhraseState("dress-1", "Arms up, let's get dressed.", "小手举高，我们穿衣服。", false),
                                                new PhraseState("dress-2", "One sock, two socks.", "一只袜子，两只袜子。", false)
                                        ))
                                )
                        ))
                ),
                new SpaceState(
                        "sensory-play",
                        "感官探索",
                        "Sensory Play",
                        "bubble_chart_outlined",
                        "#3B8577",
                        204,
                        144,
                        new ArrayList<>(List.of(
                                new ActivityState(
                                        "bath-time",
                                        "洗澡",
                                        "泼水时间",
                                        "bathtub_outlined",
                                        0.65,
                                        "bud",
                                        new ArrayList<>(List.of(
                                                new PhraseState("bath-1", "Splash splash! Can you splash with me?", "泼水泼水！你能和我一起泼吗？", false),
                                                new PhraseState("bath-2", "Water time feels warm and safe.", "水水暖暖的，很安心。", false)
                                        ))
                                ),
                                new ActivityState(
                                        "touch-game",
                                        "触觉游戏",
                                        "摸一摸软软的",
                                        "pan_tool_alt_outlined",
                                        0.28,
                                        "sprout",
                                        new ArrayList<>(List.of(
                                                new PhraseState("touch-1", "Soft, fluffy, gentle touch.", "软软的，轻轻摸一摸。", false),
                                                new PhraseState("touch-2", "Can you feel the texture?", "你摸到这个触感了吗？", false)
                                        ))
                                )
                        ))
                ),
                new SpaceState(
                        "bonding",
                        "亲密互动",
                        "Bonding",
                        "favorite_border",
                        "#E68A7B",
                        386,
                        112,
                        new ArrayList<>(List.of(
                                new ActivityState(
                                        "feeding",
                                        "喂奶/辅食",
                                        "张大嘴巴",
                                        "restaurant_outlined",
                                        0.76,
                                        "bud",
                                        new ArrayList<>(List.of(
                                                new PhraseState("feed-1", "Open wide, here comes a yummy bite.", "张大嘴巴，好吃的一口来啦。", false),
                                                new PhraseState("feed-2", "You did it, little one.", "你做到了，小宝贝。", true)
                                        ))
                                ),
                                new ActivityState(
                                        "comfort",
                                        "拥抱安抚",
                                        "抱抱安稳下来",
                                        "self_improvement_outlined",
                                        0.38,
                                        "sprout",
                                        new ArrayList<>(List.of(
                                                new PhraseState("comfort-1", "I am right here with you.", "我就在这里陪着你。", false),
                                                new PhraseState("comfort-2", "Let's take one soft breath together.", "我们一起轻轻呼一口气。", false)
                                        ))
                                )
                        ))
                ),
                new SpaceState(
                        "active-play",
                        "活力游戏",
                        "Active Play",
                        "directions_run_outlined",
                        "#9FB95A",
                        88,
                        288,
                        new ArrayList<>(List.of(
                                new ActivityState(
                                        "tpr",
                                        "TPR 动作",
                                        "拍拍小手",
                                        "waving_hand_outlined",
                                        0.52,
                                        "bud",
                                        new ArrayList<>(List.of(
                                                new PhraseState("tpr-1", "Clap your hands, clap clap clap!", "拍拍小手，拍拍拍。", false),
                                                new PhraseState("tpr-2", "Reach up high, touch the sky.", "把手举高高，碰一碰天空。", false)
                                        ))
                                ),
                                new ActivityState(
                                        "walk",
                                        "户外散步",
                                        "看看树和云",
                                        "stroller_outlined",
                                        0.18,
                                        "seed",
                                        new ArrayList<>(List.of(
                                                new PhraseState("walk-1", "Look at the trees swaying.", "看看树在轻轻摇。", false),
                                                new PhraseState("walk-2", "Clouds are floating by.", "云朵慢慢飘过去。", false)
                                        ))
                                )
                        ))
                ),
                new SpaceState(
                        "story-time",
                        "阅读时光",
                        "Story Time",
                        "auto_stories_outlined",
                        "#89A7D3",
                        292,
                        300,
                        new ArrayList<>(List.of(
                                new ActivityState(
                                        "picture-book",
                                        "绘本共读",
                                        "看看书里有什么",
                                        "menu_book_outlined",
                                        0.46,
                                        "sprout",
                                        new ArrayList<>(List.of(
                                                new PhraseState("book-1", "What do you see on this page?", "你看到这一页有什么呀？", false),
                                                new PhraseState("book-2", "Turn the page, let's peek again.", "翻一页，我们再偷看一下。", false)
                                        ))
                                ),
                                new ActivityState(
                                        "nursery-rhyme",
                                        "儿歌",
                                        "轻轻唱出来",
                                        "music_note_outlined",
                                        0.34,
                                        "sprout",
                                        new ArrayList<>(List.of(
                                                new PhraseState("song-1", "Twinkle softly, little tune.", "轻轻闪呀，小小旋律。", false),
                                                new PhraseState("song-2", "La la la, we sing together.", "啦啦啦，我们一起唱。", false)
                                        ))
                                )
                        ))
                ),
                new SpaceState(
                        "bedtime",
                        "睡前仪式",
                        "Bedtime",
                        "nightlight_outlined",
                        "#7B73A8",
                        212,
                        420,
                        new ArrayList<>(List.of(
                                new ActivityState(
                                        "lullaby",
                                        "摇篮曲",
                                        "轻轻唱晚安",
                                        "bedtime_outlined",
                                        0.61,
                                        "bud",
                                        new ArrayList<>(List.of(
                                                new PhraseState("sleep-1", "Time to sleep, little one.", "该睡觉啦，小宝贝。", false),
                                                new PhraseState("sleep-2", "Close your eyes, I am with you.", "闭上眼睛，我就在这里。", false)
                                        ))
                                ),
                                new ActivityState(
                                        "goodnight",
                                        "道晚安",
                                        "给今天一个拥抱",
                                        "brightness_2_outlined",
                                        0.24,
                                        "seed",
                                        new ArrayList<>(List.of(
                                                new PhraseState("night-1", "Good night, thank you for today.", "晚安呀，谢谢你今天的陪伴。", false),
                                                new PhraseState("night-2", "Tomorrow we'll try another little phrase.", "明天我们再试一句新的短语。", false)
                                        ))
                                )
                        ))
                )
        );

        return new AppProfileState(
                "小明妈妈",
                "小明",
                8,
                "balanced",
                false,
                42,
                23,
                5,
                spaces,
                new ArrayList<>(List.of(
                        new DiaryEntryState("洗澡时你说出 “Splash splash”，小明一边看水花一边发出长长的 “baaa”。", "自动日记 · 感官探索", "今天 18:40", "auto_note"),
                        new DiaryEntryState("晚上抱着他时，重复了 “I am right here with you”，哭声安静得更快了。", "手动记录 · 亲密互动", "昨天 21:15", "manual_note"),
                        new DiaryEntryState("晨间护理连着第三天完成，节奏明显顺了很多。", "自动日记 · 晨间护理", "昨天 08:05", "auto_note")
                )),
                new ArrayList<>(List.of(
                        new MilestoneState("第一次跟着节奏发声", "在洗澡短语里听到 “splash” 后，小明主动发出模仿音。", "今天"),
                        new MilestoneState("连续 5 天打开 app", "日常循环开始形成，这才是 Phase 1 真正要验证的东西。", "本周")
                )),
                new ArrayList<>(List.of(
                        new CoachSuggestionState("马上要洗澡了，先练两句轻快的短语", "从 “Splash splash” 开始，再补一句动作描述，宝宝更容易连动作和声音。"),
                        new CoachSuggestionState("今天状态一般，就用更短更稳的安抚句", "先说节奏慢、重复高的句子，不要一上来塞长句。"),
                        new CoachSuggestionState("如果家里有人围观，先用 whisper 模式", "先小声说一句，再慢慢放大。比强行“开麦”靠谱得多。"),
                        new CoachSuggestionState("晚饭后适合切到阅读时光", "让英语从任务感切回陪伴感，第二天更容易继续。"),
                        new CoachSuggestionState("今天可以试试一句 “Open wide”", "喂辅食时的句子反馈最直接，父母也更容易坚持。")
                )),
                new HashSet<>()
        );
    }

    private static final class AppProfileState {
        private String caregiverName;
        private String childName;
        private int childAgeMonths;
        private String difficulty;
        private boolean onboardingComplete;
        private int growthPoints;
        private int weeklyPhraseCount;
        private int streakDays;
        private final List<SpaceState> spaces;
        private final List<DiaryEntryState> diaryEntries;
        private final List<MilestoneState> milestones;
        private final List<CoachSuggestionState> coachSuggestions;
        private final Set<String> earnedMilestoneIds;

        private AppProfileState(
                String caregiverName,
                String childName,
                int childAgeMonths,
                String difficulty,
                boolean onboardingComplete,
                int growthPoints,
                int weeklyPhraseCount,
                int streakDays,
                List<SpaceState> spaces,
                List<DiaryEntryState> diaryEntries,
                List<MilestoneState> milestones,
                List<CoachSuggestionState> coachSuggestions,
                Set<String> earnedMilestoneIds
        ) {
            this.caregiverName = caregiverName;
            this.childName = childName;
            this.childAgeMonths = childAgeMonths;
            this.difficulty = difficulty;
            this.onboardingComplete = onboardingComplete;
            this.growthPoints = growthPoints;
            this.weeklyPhraseCount = weeklyPhraseCount;
            this.streakDays = streakDays;
            this.spaces = spaces;
            this.diaryEntries = diaryEntries;
            this.milestones = milestones;
            this.coachSuggestions = coachSuggestions;
            this.earnedMilestoneIds = earnedMilestoneIds;
        }
    }

    private static final class SpaceState {
        private final String id;
        private final String name;
        private final String subtitle;
        private final String iconKey;
        private final String colorHex;
        private final double mapOffsetX;
        private final double mapOffsetY;
        private final List<ActivityState> activities;

        private SpaceState(
                String id,
                String name,
                String subtitle,
                String iconKey,
                String colorHex,
                double mapOffsetX,
                double mapOffsetY,
                List<ActivityState> activities
        ) {
            this.id = id;
            this.name = name;
            this.subtitle = subtitle;
            this.iconKey = iconKey;
            this.colorHex = colorHex;
            this.mapOffsetX = mapOffsetX;
            this.mapOffsetY = mapOffsetY;
            this.activities = activities;
        }
    }

    private static final class ActivityState {
        private final String id;
        private final String name;
        private final String shortLabel;
        private final String iconKey;
        private double progress;
        private String growthStage;
        private final List<PhraseState> phrases;

        private ActivityState(
                String id,
                String name,
                String shortLabel,
                String iconKey,
                double progress,
                String growthStage,
                List<PhraseState> phrases
        ) {
            this.id = id;
            this.name = name;
            this.shortLabel = shortLabel;
            this.iconKey = iconKey;
            this.progress = progress;
            this.growthStage = growthStage;
            this.phrases = phrases;
        }
    }

    private static final class PhraseState {
        private final String id;
        private final String english;
        private final String chinese;
        private boolean mastered;

        private PhraseState(String id, String english, String chinese, boolean mastered) {
            this.id = id;
            this.english = english;
            this.chinese = chinese;
            this.mastered = mastered;
        }
    }

    private record DiaryEntryState(String title, String subtitle, String timeLabel, String type) {
    }

    private record MilestoneState(String title, String detail, String timeLabel) {
    }

    private record CoachSuggestionState(String title, String detail) {
    }

    private record StageInfo(String badge, String title, int minMonths, int maxMonths, String coachCopy) {
    }
}
package com.zhangspaghetti.babytalk.palace;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 知识宫殿分类体系 — MemPalace Taxonomy。
 *
 * <p>三级结构：Wing（翼楼）→ Room（房间）→ Hall（大厅）。
 * 51 本育儿参考书映射到此体系中，每本书带 age_range 适龄标注。
 *
 * <p>查找策略：精确匹配书名 → 默认分类（general_parenting / overview / main_hall / 0-6）。
 */
public final class MemPalaceTaxonomy {

    private MemPalaceTaxonomy() {}

    // ─── Wing（翼楼）──────────────────────────────────────────
    public enum Wing {
        LANGUAGE_DEVELOPMENT,   // 语言发展
        COGNITIVE,              // 认知发展
        EMOTIONAL,              // 情感发展
        PHYSICAL,               // 身体发展
        PARENTING_SKILLS        // 育儿技能
    }

    // ─── Room（房间）──────────────────────────────────────────
    public enum Room {
        // Language Development rooms
        EARLY_COMMUNICATION,    // 早期沟通（0-1 岁）
        VOCABULARY_BUILDING,    // 词汇构建
        READING_LITERACY,       // 阅读素养
        BILINGUAL,              // 双语教育

        // Cognitive rooms
        BRAIN_SCIENCE,          // 脑科学
        PLAY_LEARNING,          // 游戏学习
        PROBLEM_SOLVING,        // 问题解决
        CREATIVITY,             // 创造力

        // Emotional rooms
        ATTACHMENT_BONDING,     // 依恋与联结
        EMOTIONAL_REGULATION,   // 情绪调节
        SOCIAL_SKILLS,          // 社交技能

        // Physical rooms
        MOTOR_DEVELOPMENT,      // 运动发展
        NUTRITION_HEALTH,       // 营养健康
        SLEEP,                  // 睡眠

        // Parenting Skills rooms
        DISCIPLINE_GUIDANCE,    // 管教与引导
        PARENT_WELLBEING,       // 父母身心健康
        FAMILY_DYNAMICS,        // 家庭动态
        OVERVIEW                // 综合概览
    }

    // ─── Hall（大厅）──────────────────────────────────────────
    public enum Hall {
        // Language halls
        BABBLING_HALL,          // 咿呀学语
        FIRST_WORDS_HALL,       // 第一个词
        STORY_TIME_HALL,        // 故事时间
        PHONICS_HALL,           // 自然拼读
        DUAL_LANGUAGE_HALL,     // 双语输入

        // Cognitive halls
        NEURAL_PATHWAYS_HALL,   // 神经通路
        SENSORY_HALL,           // 感官探索
        MONTESSORI_HALL,        // 蒙台梭利
        STEM_HALL,              // STEM 思维
        IMAGINATION_HALL,       // 想象力

        // Emotional halls
        SECURE_BASE_HALL,       // 安全基地
        CALM_DOWN_HALL,         // 冷静角
        EMPATHY_HALL,           // 共情大厅
        FRIENDSHIP_HALL,        // 友谊大厅

        // Physical halls
        GROSS_MOTOR_HALL,       // 大运动
        FINE_MOTOR_HALL,        // 精细运动
        FEEDING_HALL,           // 喂养大厅
        SLEEP_HALL,             // 睡眠大厅

        // Parenting halls
        POSITIVE_DISCIPLINE_HALL, // 正面管教
        MINDFUL_PARENTING_HALL,   // 正念育儿
        SIBLING_HALL,             // 手足关系
        MAIN_HALL                 // 主大厅（默认）
    }

    // ─── BookMapping ─────────────────────────────────────────
    /**
     * 一本书在知识宫殿中的坐标：wing / room / hall + 适龄范围。
     */
    public record BookMapping(Wing wing, Room room, Hall hall, String ageRange) {}

    // ─── 默认分类（用于未映射的书名）────────────────────────────
    public static final BookMapping DEFAULT_MAPPING = new BookMapping(
            Wing.PARENTING_SKILLS, Room.OVERVIEW, Hall.MAIN_HALL, "0-6"
    );

    // ─── 51 本书映射目录 ────────────────────────────────────────
    private static final Map<String, BookMapping> BOOK_CATALOG;

    static {
        var m = new LinkedHashMap<String, BookMapping>();

        // ── Language Development Wing ──
        m.put("The Whole-Brain Child",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.EARLY_COMMUNICATION, Hall.FIRST_WORDS_HALL, "0-3"));
        m.put("Baby Talk",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.EARLY_COMMUNICATION, Hall.BABBLING_HALL, "0-2"));
        m.put("How to Talk So Kids Will Listen",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.VOCABULARY_BUILDING, Hall.STORY_TIME_HALL, "2-6"));
        m.put("The Read-Aloud Handbook",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.READING_LITERACY, Hall.STORY_TIME_HALL, "0-6"));
        m.put("Reading Magic",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.READING_LITERACY, Hall.PHONICS_HALL, "0-5"));
        m.put("Raising a Bilingual Child",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.BILINGUAL, Hall.DUAL_LANGUAGE_HALL, "0-6"));
        m.put("30 Million Words",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.VOCABULARY_BUILDING, Hall.FIRST_WORDS_HALL, "0-3"));
        m.put("It Takes Two to Talk",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.EARLY_COMMUNICATION, Hall.BABBLING_HALL, "0-3"));
        m.put("Beyond Baby Talk",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.VOCABULARY_BUILDING, Hall.STORY_TIME_HALL, "1-5"));
        m.put("Proust and the Squid",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.READING_LITERACY, Hall.PHONICS_HALL, "3-6"));

        // ── Cognitive Wing ──
        m.put("Brain Rules for Baby",
                new BookMapping(Wing.COGNITIVE, Room.BRAIN_SCIENCE, Hall.NEURAL_PATHWAYS_HALL, "0-5"));
        m.put("NurtureShock",
                new BookMapping(Wing.COGNITIVE, Room.BRAIN_SCIENCE, Hall.NEURAL_PATHWAYS_HALL, "0-6"));
        m.put("The Scientist in the Crib",
                new BookMapping(Wing.COGNITIVE, Room.BRAIN_SCIENCE, Hall.SENSORY_HALL, "0-3"));
        m.put("Einstein Never Used Flash Cards",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.MONTESSORI_HALL, "0-6"));
        m.put("Montessori from the Start",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.MONTESSORI_HALL, "0-3"));
        m.put("The Montessori Toddler",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.MONTESSORI_HALL, "1-3"));
        m.put("Mind in the Making",
                new BookMapping(Wing.COGNITIVE, Room.PROBLEM_SOLVING, Hall.STEM_HALL, "0-6"));
        m.put("The Gardener and the Carpenter",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.IMAGINATION_HALL, "0-6"));
        m.put("Playful Parenting",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.IMAGINATION_HALL, "2-6"));
        m.put("Creative Confidence",
                new BookMapping(Wing.COGNITIVE, Room.CREATIVITY, Hall.IMAGINATION_HALL, "3-6"));

        // ── Emotional Wing ──
        m.put("The Attachment Parenting Book",
                new BookMapping(Wing.EMOTIONAL, Room.ATTACHMENT_BONDING, Hall.SECURE_BASE_HALL, "0-3"));
        m.put("Parenting from the Inside Out",
                new BookMapping(Wing.EMOTIONAL, Room.ATTACHMENT_BONDING, Hall.SECURE_BASE_HALL, "0-6"));
        m.put("Hold On to Your Kids",
                new BookMapping(Wing.EMOTIONAL, Room.ATTACHMENT_BONDING, Hall.SECURE_BASE_HALL, "0-6"));
        m.put("No-Drama Discipline",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.CALM_DOWN_HALL, "2-6"));
        m.put("Raising An Emotionally Intelligent Child",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.EMPATHY_HALL, "2-6"));
        m.put("The Explosive Child",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.CALM_DOWN_HALL, "3-6"));
        m.put("The Whole-Brain Child Workbook",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.CALM_DOWN_HALL, "2-6"));
        m.put("Unselfie",
                new BookMapping(Wing.EMOTIONAL, Room.SOCIAL_SKILLS, Hall.EMPATHY_HALL, "3-6"));
        m.put("How Children Succeed",
                new BookMapping(Wing.EMOTIONAL, Room.SOCIAL_SKILLS, Hall.FRIENDSHIP_HALL, "0-6"));
        m.put("The Danish Way of Parenting",
                new BookMapping(Wing.EMOTIONAL, Room.SOCIAL_SKILLS, Hall.EMPATHY_HALL, "0-6"));

        // ── Physical Wing ──
        m.put("What to Expect the First Year",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.GROSS_MOTOR_HALL, "0-1"));
        m.put("The Wonder Weeks",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.GROSS_MOTOR_HALL, "0-1"));
        m.put("Baby-Led Weaning",
                new BookMapping(Wing.PHYSICAL, Room.NUTRITION_HEALTH, Hall.FEEDING_HALL, "0-2"));
        m.put("Child of Mine",
                new BookMapping(Wing.PHYSICAL, Room.NUTRITION_HEALTH, Hall.FEEDING_HALL, "0-6"));
        m.put("French Kids Eat Everything",
                new BookMapping(Wing.PHYSICAL, Room.NUTRITION_HEALTH, Hall.FEEDING_HALL, "1-6"));
        m.put("Healthy Sleep Habits Happy Child",
                new BookMapping(Wing.PHYSICAL, Room.SLEEP, Hall.SLEEP_HALL, "0-5"));
        m.put("The Happiest Baby on the Block",
                new BookMapping(Wing.PHYSICAL, Room.SLEEP, Hall.SLEEP_HALL, "0-1"));
        m.put("Precious Little Sleep",
                new BookMapping(Wing.PHYSICAL, Room.SLEEP, Hall.SLEEP_HALL, "0-2"));
        m.put("Baby Shark Finger Puppet Book",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.FINE_MOTOR_HALL, "0-2"));
        m.put("Shark Bath Finger Puppet",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.FINE_MOTOR_HALL, "0-2"));

        // ── Parenting Skills Wing ──
        m.put("Positive Discipline",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "1-6"));
        m.put("1-2-3 Magic",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "2-6"));
        m.put("Setting Limits with Your Strong-Willed Child",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "2-6"));
        m.put("Simplicity Parenting",
                new BookMapping(Wing.PARENTING_SKILLS, Room.FAMILY_DYNAMICS, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        m.put("The Conscious Parent",
                new BookMapping(Wing.PARENTING_SKILLS, Room.PARENT_WELLBEING, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        m.put("All Joy and No Fun",
                new BookMapping(Wing.PARENTING_SKILLS, Room.PARENT_WELLBEING, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        m.put("Siblings Without Rivalry",
                new BookMapping(Wing.PARENTING_SKILLS, Room.FAMILY_DYNAMICS, Hall.SIBLING_HALL, "2-6"));
        m.put("Peaceful Parent Happy Kids",
                new BookMapping(Wing.PARENTING_SKILLS, Room.PARENT_WELLBEING, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        m.put("Hunt Gather Parent",
                new BookMapping(Wing.PARENTING_SKILLS, Room.OVERVIEW, Hall.MAIN_HALL, "0-6"));
        m.put("Cribsheet",
                new BookMapping(Wing.PARENTING_SKILLS, Room.OVERVIEW, Hall.MAIN_HALL, "0-3"));
        m.put("The Blessing of a Skinned Knee",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "3-6"));

        BOOK_CATALOG = Collections.unmodifiableMap(m);
    }

    /**
     * 根据书名查找宫殿坐标。精确匹配书名（区分大小写）。
     * 未找到时返回 DEFAULT_MAPPING。
     */
    public static BookMapping resolve(String bookTitle) {
        if (bookTitle == null || bookTitle.isBlank()) {
            return DEFAULT_MAPPING;
        }
        return BOOK_CATALOG.getOrDefault(bookTitle.trim(), DEFAULT_MAPPING);
    }

    /**
     * 返回完整书目映射（只读副本）。
     */
    public static Map<String, BookMapping> catalog() {
        return BOOK_CATALOG;
    }

    /**
     * 检查书名是否有精确映射（非默认分类）。
     */
    public static boolean hasExplicitMapping(String bookTitle) {
        return bookTitle != null && BOOK_CATALOG.containsKey(bookTitle.trim());
    }
}

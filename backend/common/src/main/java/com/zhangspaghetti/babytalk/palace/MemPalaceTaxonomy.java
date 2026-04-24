package com.zhangspaghetti.babytalk.palace;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 知识宫殿分类体系 — MemPalace Taxonomy。
 */
public final class MemPalaceTaxonomy {

    private MemPalaceTaxonomy() {}

    public enum Wing {
        LANGUAGE_DEVELOPMENT,
        COGNITIVE,
        EMOTIONAL,
        PHYSICAL,
        PARENTING_SKILLS
    }

    public enum Room {
        EARLY_COMMUNICATION,
        VOCABULARY_BUILDING,
        READING_LITERACY,
        BILINGUAL,
        BRAIN_SCIENCE,
        PLAY_LEARNING,
        PROBLEM_SOLVING,
        CREATIVITY,
        ATTACHMENT_BONDING,
        EMOTIONAL_REGULATION,
        SOCIAL_SKILLS,
        MOTOR_DEVELOPMENT,
        NUTRITION_HEALTH,
        SLEEP,
        DISCIPLINE_GUIDANCE,
        PARENT_WELLBEING,
        FAMILY_DYNAMICS,
        OVERVIEW
    }

    public enum Hall {
        BABBLING_HALL,
        FIRST_WORDS_HALL,
        STORY_TIME_HALL,
        PHONICS_HALL,
        DUAL_LANGUAGE_HALL,
        NEURAL_PATHWAYS_HALL,
        SENSORY_HALL,
        MONTESSORI_HALL,
        STEM_HALL,
        IMAGINATION_HALL,
        SECURE_BASE_HALL,
        CALM_DOWN_HALL,
        EMPATHY_HALL,
        FRIENDSHIP_HALL,
        GROSS_MOTOR_HALL,
        FINE_MOTOR_HALL,
        FEEDING_HALL,
        SLEEP_HALL,
        POSITIVE_DISCIPLINE_HALL,
        MINDFUL_PARENTING_HALL,
        SIBLING_HALL,
        MAIN_HALL
    }

    public record BookMapping(Wing wing, Room room, Hall hall, String ageRange) {}

    public static final BookMapping DEFAULT_MAPPING = new BookMapping(
            Wing.PARENTING_SKILLS, Room.OVERVIEW, Hall.MAIN_HALL, "0-6"
    );

    private static final Map<String, BookMapping> BOOK_CATALOG;

    static {
        var mappings = new LinkedHashMap<String, BookMapping>();

        mappings.put("The Whole-Brain Child",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.EARLY_COMMUNICATION, Hall.FIRST_WORDS_HALL, "0-3"));
        mappings.put("Baby Talk",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.EARLY_COMMUNICATION, Hall.BABBLING_HALL, "0-2"));
        mappings.put("How to Talk So Kids Will Listen",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.VOCABULARY_BUILDING, Hall.STORY_TIME_HALL, "2-6"));
        mappings.put("The Read-Aloud Handbook",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.READING_LITERACY, Hall.STORY_TIME_HALL, "0-6"));
        mappings.put("Reading Magic",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.READING_LITERACY, Hall.PHONICS_HALL, "0-5"));
        mappings.put("Raising a Bilingual Child",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.BILINGUAL, Hall.DUAL_LANGUAGE_HALL, "0-6"));
        mappings.put("30 Million Words",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.VOCABULARY_BUILDING, Hall.FIRST_WORDS_HALL, "0-3"));
        mappings.put("It Takes Two to Talk",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.EARLY_COMMUNICATION, Hall.BABBLING_HALL, "0-3"));
        mappings.put("Beyond Baby Talk",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.VOCABULARY_BUILDING, Hall.STORY_TIME_HALL, "1-5"));
        mappings.put("Proust and the Squid",
                new BookMapping(Wing.LANGUAGE_DEVELOPMENT, Room.READING_LITERACY, Hall.PHONICS_HALL, "3-6"));

        mappings.put("Brain Rules for Baby",
                new BookMapping(Wing.COGNITIVE, Room.BRAIN_SCIENCE, Hall.NEURAL_PATHWAYS_HALL, "0-5"));
        mappings.put("NurtureShock",
                new BookMapping(Wing.COGNITIVE, Room.BRAIN_SCIENCE, Hall.NEURAL_PATHWAYS_HALL, "0-6"));
        mappings.put("The Scientist in the Crib",
                new BookMapping(Wing.COGNITIVE, Room.BRAIN_SCIENCE, Hall.SENSORY_HALL, "0-3"));
        mappings.put("Einstein Never Used Flash Cards",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.MONTESSORI_HALL, "0-6"));
        mappings.put("Montessori from the Start",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.MONTESSORI_HALL, "0-3"));
        mappings.put("The Montessori Toddler",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.MONTESSORI_HALL, "1-3"));
        mappings.put("Mind in the Making",
                new BookMapping(Wing.COGNITIVE, Room.PROBLEM_SOLVING, Hall.STEM_HALL, "0-6"));
        mappings.put("The Gardener and the Carpenter",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.IMAGINATION_HALL, "0-6"));
        mappings.put("Playful Parenting",
                new BookMapping(Wing.COGNITIVE, Room.PLAY_LEARNING, Hall.IMAGINATION_HALL, "2-6"));
        mappings.put("Creative Confidence",
                new BookMapping(Wing.COGNITIVE, Room.CREATIVITY, Hall.IMAGINATION_HALL, "3-6"));

        mappings.put("The Attachment Parenting Book",
                new BookMapping(Wing.EMOTIONAL, Room.ATTACHMENT_BONDING, Hall.SECURE_BASE_HALL, "0-3"));
        mappings.put("Parenting from the Inside Out",
                new BookMapping(Wing.EMOTIONAL, Room.ATTACHMENT_BONDING, Hall.SECURE_BASE_HALL, "0-6"));
        mappings.put("Hold On to Your Kids",
                new BookMapping(Wing.EMOTIONAL, Room.ATTACHMENT_BONDING, Hall.SECURE_BASE_HALL, "0-6"));
        mappings.put("No-Drama Discipline",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.CALM_DOWN_HALL, "2-6"));
        mappings.put("Raising An Emotionally Intelligent Child",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.EMPATHY_HALL, "2-6"));
        mappings.put("The Explosive Child",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.CALM_DOWN_HALL, "3-6"));
        mappings.put("The Whole-Brain Child Workbook",
                new BookMapping(Wing.EMOTIONAL, Room.EMOTIONAL_REGULATION, Hall.CALM_DOWN_HALL, "2-6"));
        mappings.put("Unselfie",
                new BookMapping(Wing.EMOTIONAL, Room.SOCIAL_SKILLS, Hall.EMPATHY_HALL, "3-6"));
        mappings.put("How Children Succeed",
                new BookMapping(Wing.EMOTIONAL, Room.SOCIAL_SKILLS, Hall.FRIENDSHIP_HALL, "0-6"));
        mappings.put("The Danish Way of Parenting",
                new BookMapping(Wing.EMOTIONAL, Room.SOCIAL_SKILLS, Hall.EMPATHY_HALL, "0-6"));

        mappings.put("What to Expect the First Year",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.GROSS_MOTOR_HALL, "0-1"));
        mappings.put("The Wonder Weeks",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.GROSS_MOTOR_HALL, "0-1"));
        mappings.put("Baby-Led Weaning",
                new BookMapping(Wing.PHYSICAL, Room.NUTRITION_HEALTH, Hall.FEEDING_HALL, "0-2"));
        mappings.put("Child of Mine",
                new BookMapping(Wing.PHYSICAL, Room.NUTRITION_HEALTH, Hall.FEEDING_HALL, "0-6"));
        mappings.put("French Kids Eat Everything",
                new BookMapping(Wing.PHYSICAL, Room.NUTRITION_HEALTH, Hall.FEEDING_HALL, "1-6"));
        mappings.put("Healthy Sleep Habits Happy Child",
                new BookMapping(Wing.PHYSICAL, Room.SLEEP, Hall.SLEEP_HALL, "0-5"));
        mappings.put("The Happiest Baby on the Block",
                new BookMapping(Wing.PHYSICAL, Room.SLEEP, Hall.SLEEP_HALL, "0-1"));
        mappings.put("Precious Little Sleep",
                new BookMapping(Wing.PHYSICAL, Room.SLEEP, Hall.SLEEP_HALL, "0-2"));
        mappings.put("Baby Shark Finger Puppet Book",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.FINE_MOTOR_HALL, "0-2"));
        mappings.put("Shark Bath Finger Puppet",
                new BookMapping(Wing.PHYSICAL, Room.MOTOR_DEVELOPMENT, Hall.FINE_MOTOR_HALL, "0-2"));

        mappings.put("Positive Discipline",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "1-6"));
        mappings.put("1-2-3 Magic",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "2-6"));
        mappings.put("Setting Limits with Your Strong-Willed Child",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "2-6"));
        mappings.put("Simplicity Parenting",
                new BookMapping(Wing.PARENTING_SKILLS, Room.FAMILY_DYNAMICS, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        mappings.put("The Conscious Parent",
                new BookMapping(Wing.PARENTING_SKILLS, Room.PARENT_WELLBEING, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        mappings.put("All Joy and No Fun",
                new BookMapping(Wing.PARENTING_SKILLS, Room.PARENT_WELLBEING, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        mappings.put("Siblings Without Rivalry",
                new BookMapping(Wing.PARENTING_SKILLS, Room.FAMILY_DYNAMICS, Hall.SIBLING_HALL, "2-6"));
        mappings.put("Peaceful Parent Happy Kids",
                new BookMapping(Wing.PARENTING_SKILLS, Room.PARENT_WELLBEING, Hall.MINDFUL_PARENTING_HALL, "0-6"));
        mappings.put("Hunt Gather Parent",
                new BookMapping(Wing.PARENTING_SKILLS, Room.OVERVIEW, Hall.MAIN_HALL, "0-6"));
        mappings.put("Cribsheet",
                new BookMapping(Wing.PARENTING_SKILLS, Room.OVERVIEW, Hall.MAIN_HALL, "0-3"));
        mappings.put("The Blessing of a Skinned Knee",
                new BookMapping(Wing.PARENTING_SKILLS, Room.DISCIPLINE_GUIDANCE, Hall.POSITIVE_DISCIPLINE_HALL, "3-6"));

        BOOK_CATALOG = Collections.unmodifiableMap(mappings);
    }

    public static BookMapping resolve(String bookTitle) {
        if (bookTitle == null || bookTitle.isBlank()) {
            return DEFAULT_MAPPING;
        }
        return BOOK_CATALOG.getOrDefault(bookTitle.trim(), DEFAULT_MAPPING);
    }

    public static Map<String, BookMapping> catalog() {
        return BOOK_CATALOG;
    }

    public static boolean hasExplicitMapping(String bookTitle) {
        return bookTitle != null && BOOK_CATALOG.containsKey(bookTitle.trim());
    }
}

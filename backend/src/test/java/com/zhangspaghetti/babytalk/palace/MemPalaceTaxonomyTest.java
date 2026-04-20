package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.palace.MemPalaceTaxonomy.BookMapping;
import com.zhangspaghetti.babytalk.palace.MemPalaceTaxonomy.Hall;
import com.zhangspaghetti.babytalk.palace.MemPalaceTaxonomy.Room;
import com.zhangspaghetti.babytalk.palace.MemPalaceTaxonomy.Wing;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * MemPalaceTaxonomy 单元测试 — 验证书名映射正确性与默认分类逻辑。
 */
class MemPalaceTaxonomyTest {

    @Test
    void resolve_knownBook_returnsCorrectMapping() {
        BookMapping mapping = MemPalaceTaxonomy.resolve("Brain Rules for Baby");

        assertThat(mapping.wing()).isEqualTo(Wing.COGNITIVE);
        assertThat(mapping.room()).isEqualTo(Room.BRAIN_SCIENCE);
        assertThat(mapping.hall()).isEqualTo(Hall.NEURAL_PATHWAYS_HALL);
        assertThat(mapping.ageRange()).isEqualTo("0-5");
    }

    @Test
    void resolve_languageBook_returnsLanguageWing() {
        BookMapping mapping = MemPalaceTaxonomy.resolve("30 Million Words");

        assertThat(mapping.wing()).isEqualTo(Wing.LANGUAGE_DEVELOPMENT);
        assertThat(mapping.room()).isEqualTo(Room.VOCABULARY_BUILDING);
        assertThat(mapping.hall()).isEqualTo(Hall.FIRST_WORDS_HALL);
    }

    @Test
    void resolve_emotionalBook_returnsEmotionalWing() {
        BookMapping mapping = MemPalaceTaxonomy.resolve("No-Drama Discipline");

        assertThat(mapping.wing()).isEqualTo(Wing.EMOTIONAL);
        assertThat(mapping.room()).isEqualTo(Room.EMOTIONAL_REGULATION);
        assertThat(mapping.hall()).isEqualTo(Hall.CALM_DOWN_HALL);
    }

    @Test
    void resolve_physicalBook_returnsPhysicalWing() {
        BookMapping mapping = MemPalaceTaxonomy.resolve("Baby-Led Weaning");

        assertThat(mapping.wing()).isEqualTo(Wing.PHYSICAL);
        assertThat(mapping.room()).isEqualTo(Room.NUTRITION_HEALTH);
        assertThat(mapping.hall()).isEqualTo(Hall.FEEDING_HALL);
    }

    @Test
    void resolve_parentingBook_returnsParentingSkillsWing() {
        BookMapping mapping = MemPalaceTaxonomy.resolve("Positive Discipline");

        assertThat(mapping.wing()).isEqualTo(Wing.PARENTING_SKILLS);
        assertThat(mapping.room()).isEqualTo(Room.DISCIPLINE_GUIDANCE);
        assertThat(mapping.hall()).isEqualTo(Hall.POSITIVE_DISCIPLINE_HALL);
    }

    @Test
    void resolve_unknownBook_returnsDefaultMapping() {
        BookMapping mapping = MemPalaceTaxonomy.resolve("Some Unknown Book Title");

        assertThat(mapping).isEqualTo(MemPalaceTaxonomy.DEFAULT_MAPPING);
        assertThat(mapping.wing()).isEqualTo(Wing.PARENTING_SKILLS);
        assertThat(mapping.room()).isEqualTo(Room.OVERVIEW);
        assertThat(mapping.hall()).isEqualTo(Hall.MAIN_HALL);
        assertThat(mapping.ageRange()).isEqualTo("0-6");
    }

    @Test
    void resolve_null_returnsDefaultMapping() {
        assertThat(MemPalaceTaxonomy.resolve(null)).isEqualTo(MemPalaceTaxonomy.DEFAULT_MAPPING);
    }

    @Test
    void resolve_blank_returnsDefaultMapping() {
        assertThat(MemPalaceTaxonomy.resolve("  ")).isEqualTo(MemPalaceTaxonomy.DEFAULT_MAPPING);
    }

    @Test
    void resolve_emptyString_returnsDefaultMapping() {
        assertThat(MemPalaceTaxonomy.resolve("")).isEqualTo(MemPalaceTaxonomy.DEFAULT_MAPPING);
    }

    @Test
    void catalog_containsAll51Books() {
        Map<String, BookMapping> catalog = MemPalaceTaxonomy.catalog();
        assertThat(catalog).hasSize(51);
    }

    @Test
    void catalog_isImmutable() {
        Map<String, BookMapping> catalog = MemPalaceTaxonomy.catalog();
        org.junit.jupiter.api.Assertions.assertThrows(
                UnsupportedOperationException.class,
                () -> catalog.put("Fake Book", MemPalaceTaxonomy.DEFAULT_MAPPING)
        );
    }

    @Test
    void hasExplicitMapping_knownBook_returnsTrue() {
        assertThat(MemPalaceTaxonomy.hasExplicitMapping("Baby Talk")).isTrue();
    }

    @Test
    void hasExplicitMapping_unknownBook_returnsFalse() {
        assertThat(MemPalaceTaxonomy.hasExplicitMapping("Nonexistent Book")).isFalse();
    }

    @Test
    void hasExplicitMapping_null_returnsFalse() {
        assertThat(MemPalaceTaxonomy.hasExplicitMapping(null)).isFalse();
    }

    @Test
    void allWingsCovered() {
        // 确保 5 个 Wing 在 catalog 中都有至少 1 本书
        Map<String, BookMapping> catalog = MemPalaceTaxonomy.catalog();
        for (Wing wing : Wing.values()) {
            boolean found = catalog.values().stream().anyMatch(m -> m.wing() == wing);
            assertThat(found).as("Wing %s 应有至少一本书映射", wing).isTrue();
        }
    }
}

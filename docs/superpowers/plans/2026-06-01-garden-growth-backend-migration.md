# 花园 & 成长页后端迁移实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将花园页和成长页数据改为从后端 API 返回，建立 practice catalog 三表，并在 Flutter 移除本地计算逻辑。

**Architecture:** 新建 `practice_spaces/activities/phrases` 三表（V22 migration，BIGSERIAL PK + slug UNIQUE）；新增 `GET /api/v1/growth/insights` 和 `GET /api/v1/garden/snapshot`；Flutter 成长页改为并行 API 调用，花园页接通现有 API service。

**Tech Stack:** Spring Boot 3.4.4 + JdbcTemplate + PostgreSQL + Flyway；Flutter/Riverpod 2.6.1 + Dio；Java 17 Records；SharedPreferences 缓存。

**Spec:** `docs/superpowers/specs/2026-06-01-garden-growth-backend-migration.md`

---

## 文件映射

### 新建（后端）
| 文件 | 职责 |
|------|------|
| `backend/db-migration/src/main/resources/db/migration/V22__create_practice_catalog_tables.sql` | DDL：3张表+索引 |
| `backend/db-migration/src/main/resources/db/migration/V22_1__seed_practice_catalog.sql` | 静态数据：从 seed_content.json 填充 |
| `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthInsightsService.java` | 成长洞察聚合 SQL |
| `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenSnapshotService.java` | 花园快照聚合 SQL |
| `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepository.java` | practice catalog 查询/写入 |
| `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GrowthInsightsController.java` | REST endpoint |
| `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GardenSnapshotController.java` | REST endpoint |

### 修改（后端）
| 文件 | 改动 |
|------|------|
| `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java` | 生成前查 catalog 缓存，生成后写 catalog |
| `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java` | 响应增加 activityId/phraseId |

### 新建（Flutter）
| 文件 | 职责 |
|------|------|
| `mobile/lib/features/growth/data/remote/growth_insights_api_service.dart` | HTTP client for `/api/v1/growth/insights` |
| `mobile/lib/features/growth/data/models/growth_insights_payload.dart` | Deserialization 模型 |
| `mobile/lib/features/garden/data/remote/garden_snapshot_api_service.dart` | HTTP client for `/api/v1/garden/snapshot` |
| `mobile/lib/features/garden/data/models/garden_snapshot_payload.dart` | Deserialization 模型 |

### 修改（Flutter）
| 文件 | 改动 |
|------|------|
| `mobile/lib/features/growth/presentation/growth_insights_notifier.dart` | 改为 API 调用，删本地计算 |
| `mobile/lib/app/providers/repository_providers.dart` | 新增 provider：insights API, snapshot API；GardenFertilizer 接通 remoteDataSource |

---

## Task 1: V22 — 创建 Practice Catalog 表

**Files:**
- Create: `backend/db-migration/src/main/resources/db/migration/V22__create_practice_catalog_tables.sql`

- [ ] **Step 1: 创建 V22 migration 文件**

```sql
-- V22: Practice Catalog tables
-- Three-table structure for practice spaces, activities, and phrases.
-- BIGSERIAL PK for efficient JOINs; slug UNIQUE for human-readable IDs
-- and backward-compat with interaction_events varchar columns.

CREATE TABLE practice_spaces (
    id             BIGSERIAL    PRIMARY KEY,
    slug           VARCHAR(96)  UNIQUE NOT NULL,
    title_zh       VARCHAR(120) NOT NULL,
    description_zh TEXT,
    sort_order     INT NOT NULL DEFAULT 0,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE practice_activities (
    id            BIGSERIAL    PRIMARY KEY,
    slug          VARCHAR(96)  UNIQUE,
    space_id      BIGINT       NOT NULL REFERENCES practice_spaces(id),
    title_zh      VARCHAR(120) NOT NULL,
    scene_tag_en  VARCHAR(120),
    coach_tip     TEXT,
    sort_order    INT NOT NULL DEFAULT 0,
    source        VARCHAR(16)  NOT NULL DEFAULT 'seed',
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT chk_activity_source CHECK (source IN ('seed', 'llm'))
);

CREATE TABLE practice_phrases (
    id            BIGSERIAL    PRIMARY KEY,
    slug          VARCHAR(120) UNIQUE,
    activity_id   BIGINT       NOT NULL REFERENCES practice_activities(id),
    step          INT NOT NULL,
    english       VARCHAR(240) NOT NULL,
    chinese       VARCHAR(240) NOT NULL,
    pronunciation VARCHAR(240),
    difficulty    VARCHAR(16),
    audio_asset   VARCHAR(240),
    source        VARCHAR(16)  NOT NULL DEFAULT 'seed',
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT chk_phrase_source CHECK (source IN ('seed', 'llm')),
    CONSTRAINT chk_phrase_difficulty CHECK (difficulty IS NULL OR difficulty IN ('starter', 'easy', 'medium', 'hard'))
);

CREATE INDEX idx_practice_activities_space_id     ON practice_activities(space_id);
CREATE INDEX idx_practice_activities_slug         ON practice_activities(slug);
CREATE INDEX idx_practice_activities_scene_tag_en ON practice_activities(scene_tag_en);
CREATE INDEX idx_practice_phrases_activity_id     ON practice_phrases(activity_id);
CREATE INDEX idx_practice_phrases_step            ON practice_phrases(activity_id, step);
```

- [ ] **Step 2: 验证 migration 语法正确（dry run）**

```bash
cd backend
./mvnw flyway:info -pl db-migration -Dflyway.url=jdbc:postgresql://localhost:5432/babytalk -Dflyway.user=postgres -Dflyway.password=postgres 2>&1 | tail -20
```

期望输出：包含 `V22 | create_practice_catalog_tables | Pending`

- [ ] **Step 3: commit**

```bash
git add backend/db-migration/src/main/resources/db/migration/V22__create_practice_catalog_tables.sql
git commit -m "db: V22 create practice catalog tables (BIGSERIAL PK + slug)"
```

---

## Task 2: V22_1 — Seed Practice Catalog

**Files:**
- Create: `backend/db-migration/src/main/resources/db/migration/V22_1__seed_practice_catalog.sql`

> 以 `mobile/assets/content/seed_content.json` 为权威数据源。下面是完整 INSERT（从 JSON 提取的所有 spaces/activities/phrases）。

- [ ] **Step 1: 读取 seed_content.json 并生成 V22_1 INSERT 语句**

```bash
# 确认 seed 文件位置
cat "mobile/assets/content/seed_content.json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('schemaVersion:', data.get('schemaVersion'))
for s in data.get('spaces', []):
    print('SPACE:', s['id'], '-', s.get('title'))
    for a in s.get('activities', []):
        print('  ACTIVITY:', a['id'], '-', a.get('title'))
        print('    phrases:', len(a.get('phrases', [])))
"
```

期望输出：列出全部 spaces、activities、phrases 数量

- [ ] **Step 2: 创建完整的 V22_1 seed 文件**

完整内容须从上一步输出生成。结构如下：

```sql
-- V22_1: Seed practice catalog from seed_content.json
-- Source of truth: mobile/assets/content/seed_content.json schemaVersion

-- Spaces
INSERT INTO practice_spaces (slug, title_zh, description_zh, sort_order) VALUES
  ('daily_care',    '日常照护', '洗澡、换尿布等日常护理场景', 1),
  ('mealtime',      '用餐时间', '辅食、喂奶等进食场景',       2),
  ('play_time',     '游戏时间', '玩具、游戏互动场景',         3),
  ('bedtime',       '睡前时间', '入睡、睡前故事场景',         4),
  ('outdoor',       '户外活动', '散步、公园等户外场景',        5);
-- （以实际 seed 文件为准，补全所有 spaces）

-- Activities（使用 subquery 取 space_id）
INSERT INTO practice_activities (slug, space_id, title_zh, scene_tag_en, sort_order) VALUES
  ('bath_time',     (SELECT id FROM practice_spaces WHERE slug = 'daily_care'), '洗澡时间',  'Bath time',     1),
  ('diaper_change', (SELECT id FROM practice_spaces WHERE slug = 'daily_care'), '换尿布',    'Diaper change', 2);
-- （以实际 seed 文件为准，补全所有 activities）

-- Phrases（使用 subquery 取 activity_id）
INSERT INTO practice_phrases (slug, activity_id, step, english, chinese, pronunciation, difficulty, audio_asset) VALUES
  ('bath_time_warm_water',
   (SELECT id FROM practice_activities WHERE slug = 'bath_time'),
   1, 'Warm water.', '水暖暖的。', 'wɔːrm ˈwɔːtɚ', 'starter', 'audio/bath_time/warm_water.mp3'),
  ('bath_time_splash_splash',
   (SELECT id FROM practice_activities WHERE slug = 'bath_time'),
   2, 'Splash, splash!', '哗啦，哗啦！', 'splæʃ splæʃ', 'starter', 'audio/bath_time/splash_splash.mp3'),
  ('bath_time_all_clean',
   (SELECT id FROM practice_activities WHERE slug = 'bath_time'),
   3, 'All clean.', '洗干净啦。', 'ɔːl kliːn', 'starter', 'audio/bath_time/all_clean.mp3');
-- （以实际 seed 文件为准，补全所有 phrases）
```

> **注意**：实现时从 Step 1 的输出实际生成完整 SQL，不留 placeholder。

- [ ] **Step 3: 验证 seed 数据条数**

运行 migration 后：
```sql
SELECT 
  (SELECT count(*) FROM practice_spaces) AS spaces,
  (SELECT count(*) FROM practice_activities) AS activities,
  (SELECT count(*) FROM practice_phrases) AS phrases;
```

期望：与 seed_content.json 中数量一致（约 5 spaces / 20 activities / 60 phrases）

- [ ] **Step 4: commit**

```bash
git add backend/db-migration/src/main/resources/db/migration/V22_1__seed_practice_catalog.sql
git commit -m "db: V22_1 seed practice catalog from seed_content.json"
```

---

## Task 3: GrowthInsightsService + Controller

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthInsightsService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GrowthInsightsController.java`

- [ ] **Step 1: 创建 GrowthInsightsService.java**

```java
package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GrowthInsightsService {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");
    private final JdbcTemplate jdbc;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock;

    public GrowthInsightsService(JdbcTemplate jdbc,
                                  AuthConsentSyncService authConsentSyncService) {
        this(jdbc, authConsentSyncService, Clock.systemUTC());
    }

    GrowthInsightsService(JdbcTemplate jdbc,
                           AuthConsentSyncService authConsentSyncService,
                           Clock clock) {
        this.jdbc = jdbc;
        this.authConsentSyncService = authConsentSyncService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public GrowthInsightsResponse loadInsights(String sessionId, String periodRaw) {
        var period   = normalizePeriod(periodRaw);
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now       = Instant.now(clock);
        var window    = resolveWindow(period, now);

        // --- base stats ---
        var stats = loadStats(accountId, window);

        // --- streak ---
        var streak = loadStreak(accountId, now);

        // --- bars ---
        var bars = loadBars(accountId, window, period);

        // --- scenes ---
        var scenes = loadScenes(accountId, window);

        // --- recentActivity ---
        var recentActivity = loadRecentActivity(accountId, now);

        // --- suggestion (week/month only) ---
        GrowthSuggestion suggestion = null;
        if (!period.equals("year")) {
            suggestion = loadSuggestion(accountId, window);
        }

        return new GrowthInsightsResponse(
                period, window.start(), window.end(), now,
                stats, streak, bars, scenes, recentActivity, suggestion);
    }

    // ── stats ──────────────────────────────────────────────────────────────
    private Stats loadStats(String accountId, Window window) {
        return jdbc.queryForObject(
                """
                SELECT COUNT(*)                                                   AS total_events,
                       COUNT(DISTINCT phrase_id)                                  AS unique_phrases,
                       COUNT(DISTINCT activity_id)                                AS unique_activities,
                       COUNT(*) FILTER (WHERE reaction_type = 'imitated')         AS imitation_count,
                       COUNT(DISTINCT DATE(client_timestamp AT TIME ZONE 'Asia/Shanghai'))
                                                                                  AS practiced_days,
                       MIN(client_timestamp)                                      AS first_event_at,
                       MAX(client_timestamp)                                      AS last_event_at
                FROM interaction_events
                WHERE account_id = ?
                  AND client_timestamp >= ?
                  AND client_timestamp < ?
                """,
                (rs, n) -> new Stats(
                        rs.getLong("total_events"),
                        rs.getInt("unique_phrases"),
                        rs.getInt("unique_activities"),
                        rs.getInt("imitation_count"),
                        rs.getInt("practiced_days"),
                        toInstant(rs.getTimestamp("first_event_at")),
                        toInstant(rs.getTimestamp("last_event_at"))
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── streak ─────────────────────────────────────────────────────────────
    private Streak loadStreak(String accountId, Instant now) {
        var today = now.atZone(SHANGHAI).toLocalDate();
        var rows = jdbc.queryForList(
                """
                SELECT DISTINCT DATE(client_timestamp AT TIME ZONE 'Asia/Shanghai') AS practice_date
                FROM interaction_events
                WHERE account_id = ?
                ORDER BY practice_date DESC
                """,
                accountId
        );

        var dates = rows.stream()
                .map(r -> ((java.sql.Date) r.get("practice_date")).toLocalDate())
                .toList();

        int current = 0;
        int longest = 0;
        int streak  = 0;
        LocalDate prev = today;
        for (LocalDate d : dates) {
            long gap = java.time.temporal.ChronoUnit.DAYS.between(d, prev);
            if (gap <= 1) {
                streak++;
            } else {
                if (streak > longest) longest = streak;
                streak = 1;
            }
            prev = d;
        }
        if (streak > longest) longest = streak;

        // "current streak" resets if no practice today or yesterday
        if (!dates.isEmpty()) {
            long gap = java.time.temporal.ChronoUnit.DAYS.between(dates.get(0), today);
            current = (gap <= 1) ? streak : 0;
        }

        Instant lastPracticed = dates.isEmpty() ? null :
                dates.get(0).atStartOfDay(SHANGHAI).toInstant();

        return new Streak(current, longest, dates.size(), lastPracticed);
    }

    // ── bars ───────────────────────────────────────────────────────────────
    private List<BarBucket> loadBars(String accountId, Window window, String period) {
        var truncUnit = switch (period) {
            case "week"  -> "day";
            case "month" -> "week";
            default      -> "month";
        };
        return jdbc.query(
                """
                SELECT DATE_TRUNC(?, client_timestamp AT TIME ZONE 'Asia/Shanghai') AS bucket_start,
                       COUNT(*) AS count
                FROM interaction_events
                WHERE account_id = ?
                  AND client_timestamp >= ?
                  AND client_timestamp < ?
                GROUP BY bucket_start
                ORDER BY bucket_start
                """,
                (rs, n) -> new BarBucket(rs.getTimestamp("bucket_start").toInstant(), rs.getLong("count")),
                truncUnit,
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── scenes ─────────────────────────────────────────────────────────────
    private List<SceneEntry> loadScenes(String accountId, Window window) {
        long total = jdbc.queryForObject(
                "SELECT COUNT(*) FROM interaction_events WHERE account_id = ? AND client_timestamp >= ? AND client_timestamp < ?",
                Long.class,
                accountId, Timestamp.from(window.start()), Timestamp.from(window.end())
        );
        if (total == 0) return List.of();

        return jdbc.query(
                """
                SELECT COALESCE(ps.slug, ie.activity_id)  AS space_id,
                       COALESCE(ps.title_zh, ie.activity_id) AS scene_tag,
                       COUNT(*)                             AS event_count,
                       COUNT(DISTINCT ie.activity_id)       AS activity_count
                FROM interaction_events ie
                LEFT JOIN practice_activities pa ON pa.slug = ie.activity_id
                LEFT JOIN practice_spaces ps      ON ps.id  = pa.space_id
                WHERE ie.account_id = ?
                  AND ie.client_timestamp >= ?
                  AND ie.client_timestamp < ?
                GROUP BY space_id, scene_tag
                ORDER BY event_count DESC
                LIMIT 5
                """,
                (rs, n) -> new SceneEntry(
                        rs.getString("space_id"),
                        rs.getString("scene_tag"),
                        rs.getLong("event_count"),
                        rs.getInt("activity_count"),
                        total > 0 ? (double) rs.getLong("event_count") / total * 100 : 0.0
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── recentActivity ─────────────────────────────────────────────────────
    private RecentActivity loadRecentActivity(String accountId, Instant now) {
        var weekEnd   = now.atZone(SHANGHAI).with(DayOfWeek.MONDAY).toLocalDate().atStartOfDay(SHANGHAI).toInstant();
        var weekStart = weekEnd.atZone(SHANGHAI).minusWeeks(1).toInstant();
        var prevStart = weekStart.atZone(SHANGHAI).minusWeeks(1).toInstant();

        var row = jdbc.queryForMap(
                """
                SELECT
                  COUNT(*) FILTER (WHERE client_timestamp >= ? AND client_timestamp < ?) AS this_week,
                  COUNT(*) FILTER (WHERE client_timestamp >= ? AND client_timestamp < ?) AS last_week
                FROM interaction_events
                WHERE account_id = ?
                """,
                Timestamp.from(weekEnd), Timestamp.from(now),
                Timestamp.from(weekStart), Timestamp.from(weekEnd),
                accountId
        );
        return new RecentActivity(
                ((Number) row.get("this_week")).intValue(),
                ((Number) row.get("last_week")).intValue()
        );
    }

    // ── suggestion ─────────────────────────────────────────────────────────
    private GrowthSuggestion loadSuggestion(String accountId, Window window) {
        var rows = jdbc.query(
                """
                SELECT pa.slug         AS activity_id,
                       ps.slug         AS space_id,
                       ps.title_zh     AS scene_label,
                       pp.english      AS phrase_english
                FROM practice_activities pa
                JOIN practice_spaces ps  ON ps.id = pa.space_id
                JOIN practice_phrases pp ON pp.activity_id = pa.id AND pp.step = 1
                WHERE NOT EXISTS (
                    SELECT 1 FROM interaction_events ie
                    WHERE ie.activity_id = pa.slug
                      AND ie.account_id = ?
                      AND ie.client_timestamp >= ?
                      AND ie.client_timestamp < ?
                )
                ORDER BY ps.sort_order, pa.sort_order
                LIMIT 1
                """,
                (rs, n) -> new GrowthSuggestion(
                        rs.getString("space_id"),
                        rs.getString("activity_id"),
                        rs.getString("scene_label"),
                        rs.getString("phrase_english")
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
        return rows.isEmpty() ? null : rows.get(0);
    }

    // ── window / period ────────────────────────────────────────────────────
    private String normalizePeriod(String raw) {
        if (raw == null || raw.isBlank()) return "week";
        return switch (raw.trim().toLowerCase()) {
            case "month" -> "month";
            case "year"  -> "year";
            default      -> "week";
        };
    }

    private Window resolveWindow(String period, Instant now) {
        var zoned = now.atZone(SHANGHAI);
        return switch (period) {
            case "month" -> {
                var start = zoned.with(TemporalAdjusters.firstDayOfMonth()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                var end = zoned.with(TemporalAdjusters.firstDayOfNextMonth()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                yield new Window(start, end);
            }
            case "year" -> {
                var start = zoned.with(TemporalAdjusters.firstDayOfYear()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                var end = zoned.with(TemporalAdjusters.firstDayOfNextYear()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                yield new Window(start, end);
            }
            default -> {
                var monday = zoned.with(DayOfWeek.MONDAY).toLocalDate().atStartOfDay(SHANGHAI).toInstant();
                var nextMonday = monday.atZone(SHANGHAI).plusWeeks(1).toInstant();
                yield new Window(monday, nextMonday);
            }
        };
    }

    private static Instant toInstant(Timestamp ts) {
        return ts == null ? null : ts.toInstant();
    }

    // ── Records (Response / Internal) ──────────────────────────────────────
    public record Window(Instant start, Instant end) {}

    public record Stats(long totalEvents, int uniquePhrases, int uniqueActivities,
                        int imitationCount, int practicedDays,
                        Instant firstEventAt, Instant lastEventAt) {}

    public record Streak(int currentStreak, int longestStreak,
                         int totalDaysPracticed, Instant lastPracticedAt) {}

    public record BarBucket(Instant bucketStart, long count) {}

    public record SceneEntry(String spaceId, String sceneTag, long eventCount,
                              int activityCount, double percentage) {}

    public record RecentActivity(int thisWeekCount, int lastWeekCount) {}

    public record GrowthSuggestion(String spaceId, String activityId,
                                    String sceneLabel, String phraseEnglish) {}

    public record GrowthInsightsResponse(
            String period,
            Instant windowStart, Instant windowEnd, Instant generatedAt,
            Stats stats,
            Streak streak,
            List<BarBucket> bars,
            List<SceneEntry> scenes,
            RecentActivity recentActivity,
            GrowthSuggestion suggestion
    ) {}
}
```

- [ ] **Step 2: 创建 GrowthInsightsController.java**

```java
package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.GrowthInsightsService;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/growth")
public class GrowthInsightsController {

    private final GrowthInsightsService growthInsightsService;

    public GrowthInsightsController(GrowthInsightsService growthInsightsService) {
        this.growthInsightsService = growthInsightsService;
    }

    @GetMapping("/insights")
    public GrowthInsightsService.GrowthInsightsResponse getInsights(
            JwtAuthenticationToken authentication,
            @RequestParam(value = "period", required = false) String period
    ) {
        return growthInsightsService.loadInsights(sessionId(authentication), period);
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid",
                    "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        if (sid == null || sid.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid",
                    "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        return sid;
    }
}
```

- [ ] **Step 3: 编译验证**

```bash
cd backend
./mvnw compile -pl app-api -q 2>&1 | tail -20
```

期望：`BUILD SUCCESS`，无编译错误

- [ ] **Step 4: 冒烟测试（本地环境）**

```bash
# 启动 app-api（需要本地 DB 已运行且 migration 已执行）
# 手动调用：
curl -H "Authorization: Bearer <token>" \
     "http://localhost:8080/api/v1/growth/insights?period=week" | python3 -m json.tool
```

期望：返回 JSON，包含 `period`, `stats`, `streak`, `bars`, `scenes` 字段

- [ ] **Step 5: commit**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthInsightsService.java
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GrowthInsightsController.java
git commit -m "feat(backend): add GET /api/v1/growth/insights endpoint"
```

---

## Task 4: GardenSnapshotService + Controller

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenSnapshotService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GardenSnapshotController.java`

- [ ] **Step 1: 创建 GardenSnapshotService.java**

```java
package com.zhangspaghetti.babytalk.service;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GardenSnapshotService {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");
    private final JdbcTemplate jdbc;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock;

    public GardenSnapshotService(JdbcTemplate jdbc,
                                   AuthConsentSyncService authConsentSyncService) {
        this(jdbc, authConsentSyncService, Clock.systemUTC());
    }

    GardenSnapshotService(JdbcTemplate jdbc,
                           AuthConsentSyncService authConsentSyncService,
                           Clock clock) {
        this.jdbc = jdbc;
        this.authConsentSyncService = authConsentSyncService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public GardenSnapshotResponse loadSnapshot(String sessionId) {
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now = Instant.now(clock);

        var agg = jdbc.queryForMap(
                """
                SELECT
                  COUNT(*)                                                              AS known_events,
                  COUNT(DISTINCT phrase_id)                                             AS unique_phrases,
                  COUNT(DISTINCT COALESCE(
                      (SELECT ps.id FROM practice_activities pa
                       JOIN practice_spaces ps ON ps.id = pa.space_id
                       WHERE pa.slug = ie.activity_id LIMIT 1),
                      0))                                                               AS covered_space_count
                FROM interaction_events ie
                WHERE ie.account_id = ?
                """,
                accountId
        );

        long knownEvents     = ((Number) agg.get("known_events")).longValue();
        long uniquePhrases   = ((Number) agg.get("unique_phrases")).longValue();
        int coveredSpaceCount = ((Number) agg.get("covered_space_count")).intValue();

        int currentStreak = loadCurrentStreak(accountId, now);

        var milestones = computeMilestones(knownEvents, uniquePhrases, coveredSpaceCount, currentStreak);

        var pendingEventKeys = loadPendingEventKeys(accountId);

        return new GardenSnapshotResponse(now, knownEvents, coveredSpaceCount,
                currentStreak, milestones, pendingEventKeys);
    }

    private int loadCurrentStreak(String accountId, Instant now) {
        var today = now.atZone(SHANGHAI).toLocalDate();
        var dates = jdbc.queryForList(
                """
                SELECT DISTINCT DATE(client_timestamp AT TIME ZONE 'Asia/Shanghai') AS d
                FROM interaction_events
                WHERE account_id = ?
                ORDER BY d DESC
                LIMIT 365
                """,
                accountId
        );
        int streak = 0;
        var prev = today;
        for (var row : dates) {
            var d = ((java.sql.Date) row.get("d")).toLocalDate();
            long gap = java.time.temporal.ChronoUnit.DAYS.between(d, prev);
            if (gap <= 1) { streak++; prev = d; }
            else break;
        }
        if (!dates.isEmpty()) {
            var last = ((java.sql.Date) dates.get(0).get("d")).toLocalDate();
            long gap = java.time.temporal.ChronoUnit.DAYS.between(last, today);
            if (gap > 1) return 0;
        }
        return streak;
    }

    private List<MilestoneEntry> computeMilestones(long knownEvents, long uniquePhrases,
                                                     int coveredSpaceCount, int currentStreak) {
        // Milestone definitions — must stay in sync with Flutter garden_growth_repository.dart
        record MilestoneDef(String id, String title, int sortOrder) {}
        var defs = List.of(
            new MilestoneDef("first_practice",  "开始记录",   1),
            new MilestoneDef("ten_phrases",      "练习了10句", 2),
            new MilestoneDef("three_spaces",     "探索3个场景",3),
            new MilestoneDef("streak_7",         "坚持7天",    4),
            new MilestoneDef("fifty_events",     "练习了50次", 5)
        );

        var result = new ArrayList<MilestoneEntry>();
        for (var def : defs) {
            boolean achieved;
            String hint = null;
            switch (def.id()) {
                case "first_practice" -> achieved = knownEvents >= 1;
                case "ten_phrases"    -> {
                    achieved = uniquePhrases >= 10;
                    if (!achieved) hint = "还差 " + (10 - uniquePhrases) + " 句";
                }
                case "three_spaces"   -> {
                    achieved = coveredSpaceCount >= 3;
                    if (!achieved) hint = "还差 " + (3 - coveredSpaceCount) + " 个场景";
                }
                case "streak_7"       -> {
                    achieved = currentStreak >= 7;
                    if (!achieved) hint = "还差 " + (7 - currentStreak) + " 天";
                }
                case "fifty_events"   -> {
                    achieved = knownEvents >= 50;
                    if (!achieved) hint = "还差 " + (50 - knownEvents) + " 次";
                }
                default -> achieved = false;
            }
            result.add(new MilestoneEntry(def.id(), def.title(), def.sortOrder(),
                    achieved ? Instant.now() : null, achieved ? null : hint));
        }
        return result;
    }

    private List<String> loadPendingEventKeys(String accountId) {
        return jdbc.queryForList(
                """
                SELECT ie.event_key
                FROM interaction_events ie
                WHERE ie.account_id = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM garden_fertilizer_claim_log fcl
                      WHERE fcl.event_key = ie.event_key
                  )
                ORDER BY ie.client_timestamp ASC
                LIMIT 20
                """,
                String.class,
                accountId
        );
    }

    // ── Records ────────────────────────────────────────────────────────────
    public record MilestoneEntry(String id, String title, int sortOrder,
                                  Instant achievedAt, String remainingHint) {}

    public record GardenSnapshotResponse(
            Instant generatedAt,
            long knownEvents,
            int coveredSpaceCount,
            int currentStreakDays,
            List<MilestoneEntry> milestones,
            List<String> pendingEventKeys
    ) {}
}
```

- [ ] **Step 2: 创建 GardenSnapshotController.java**

```java
package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.GardenSnapshotService;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/garden")
public class GardenSnapshotController {

    private final GardenSnapshotService gardenSnapshotService;

    public GardenSnapshotController(GardenSnapshotService gardenSnapshotService) {
        this.gardenSnapshotService = gardenSnapshotService;
    }

    @GetMapping("/snapshot")
    public GardenSnapshotService.GardenSnapshotResponse getSnapshot(
            JwtAuthenticationToken authentication
    ) {
        return gardenSnapshotService.loadSnapshot(sessionId(authentication));
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid",
                    "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        if (sid == null || sid.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid",
                    "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        return sid;
    }
}
```

- [ ] **Step 3: 编译验证**

```bash
cd backend
./mvnw compile -pl app-api -q 2>&1 | tail -20
```

期望：`BUILD SUCCESS`

- [ ] **Step 4: commit**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenSnapshotService.java
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GardenSnapshotController.java
git commit -m "feat(backend): add GET /api/v1/garden/snapshot endpoint"
```

---

## Task 5: MentorService — Catalog Cache + Write-through（D2/D3）

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepository.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`（响应 DTO）

- [ ] **Step 1: 创建 PracticeCatalogRepository.java**

```java
package com.zhangspaghetti.babytalk.service;

import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

/**
 * Read/write access to practice_spaces, practice_activities, practice_phrases.
 * <p>Used by MentorService to: (1) cache-check before LLM call,
 * (2) persist LLM-generated content immediately after generation.
 */
@Repository
public class PracticeCatalogRepository {

    private final JdbcTemplate jdbc;

    public PracticeCatalogRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── lookup ─────────────────────────────────────────────────────────────

    /** Find cached activity by sceneTag (exact match on scene_tag_en). */
    public Optional<CachedActivity> findActivityBySceneTag(String sceneTagEn) {
        var rows = jdbc.query(
                """
                SELECT pa.id AS activity_id, pa.slug, pa.title_zh, pa.coach_tip,
                       ps.slug AS space_slug
                FROM practice_activities pa
                JOIN practice_spaces ps ON ps.id = pa.space_id
                WHERE pa.scene_tag_en = ?
                LIMIT 1
                """,
                (rs, n) -> new CachedActivity(
                        rs.getLong("activity_id"),
                        rs.getString("slug"),
                        rs.getString("space_slug"),
                        rs.getString("title_zh"),
                        rs.getString("coach_tip")
                ),
                sceneTagEn
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** Fetch phrases for a cached activity, ordered by step. */
    public List<CachedPhrase> findPhrasesByActivityId(long activityId) {
        return jdbc.query(
                """
                SELECT id, slug, step, english, chinese, pronunciation, difficulty
                FROM practice_phrases
                WHERE activity_id = ?
                ORDER BY step
                """,
                (rs, n) -> new CachedPhrase(
                        rs.getLong("id"),
                        rs.getString("slug"),
                        rs.getInt("step"),
                        rs.getString("english"),
                        rs.getString("chinese"),
                        rs.getString("pronunciation"),
                        rs.getString("difficulty")
                ),
                activityId
        );
    }

    /** Find space id by slug. */
    public Optional<Long> findSpaceIdBySlug(String slug) {
        var rows = jdbc.queryForList(
                "SELECT id FROM practice_spaces WHERE slug = ?", Long.class, slug);
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** Fetch all space slugs for LLM classification prompt. */
    public List<String> findAllSpaceSlugs() {
        return jdbc.queryForList(
                "SELECT slug FROM practice_spaces ORDER BY sort_order", String.class);
    }

    // ── write ──────────────────────────────────────────────────────────────

    @Transactional
    public long insertSpace(String slug, String titleZh) {
        var kh = new GeneratedKeyHolder();
        jdbc.update(con -> {
            var ps = con.prepareStatement(
                    "INSERT INTO practice_spaces (slug, title_zh, source) VALUES (?, ?, 'llm')" +
                    " ON CONFLICT (slug) DO NOTHING RETURNING id",
                    java.sql.Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, slug);
            ps.setString(2, titleZh);
            return ps;
        }, kh);
        return kh.getKey() != null ? kh.getKey().longValue()
                : findSpaceIdBySlug(slug).orElseThrow();
    }

    @Transactional
    public long insertActivity(String slug, long spaceId, String titleZh,
                                String sceneTagEn, String coachTip) {
        var kh = new GeneratedKeyHolder();
        jdbc.update(con -> {
            var ps = con.prepareStatement(
                    """
                    INSERT INTO practice_activities
                        (slug, space_id, title_zh, scene_tag_en, coach_tip, source)
                    VALUES (?, ?, ?, ?, ?, 'llm')
                    ON CONFLICT (slug) DO NOTHING
                    """,
                    java.sql.Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, slug);
            ps.setLong(2, spaceId);
            ps.setString(3, titleZh);
            ps.setString(4, sceneTagEn);
            ps.setString(5, coachTip);
            return ps;
        }, kh);
        return kh.getKey() != null ? kh.getKey().longValue()
                : jdbc.queryForObject("SELECT id FROM practice_activities WHERE slug = ?",
                        Long.class, slug);
    }

    @Transactional
    public long insertPhrase(String slug, long activityId, int step,
                              String english, String chinese,
                              String pronunciation, String difficulty) {
        var kh = new GeneratedKeyHolder();
        jdbc.update(con -> {
            var ps = con.prepareStatement(
                    """
                    INSERT INTO practice_phrases
                        (slug, activity_id, step, english, chinese, pronunciation, difficulty, source)
                    VALUES (?, ?, ?, ?, ?, ?, ?, 'llm')
                    ON CONFLICT (slug) DO NOTHING
                    """,
                    java.sql.Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, slug);
            ps.setLong(2, activityId);
            ps.setInt(3, step);
            ps.setString(4, english);
            ps.setString(5, chinese);
            ps.setString(6, pronunciation);
            ps.setString(7, difficulty);
            return ps;
        }, kh);
        return kh.getKey() != null ? kh.getKey().longValue()
                : jdbc.queryForObject("SELECT id FROM practice_phrases WHERE slug = ?",
                        Long.class, slug);
    }

    // ── Records ────────────────────────────────────────────────────────────
    public record CachedActivity(long id, String slug, String spaceSlug,
                                  String titleZh, String coachTip) {}

    public record CachedPhrase(long id, String slug, int step,
                                String english, String chinese,
                                String pronunciation, String difficulty) {}
}
```

- [ ] **Step 2: 修改 MentorService.generatePractice() — 加入缓存命中 + 生成后写库**

在 `MentorService` 中：
1. 注入 `PracticeCatalogRepository catalogRepo`  
2. `generatePractice()` 最前端加：
```java
// 1. Cache check — avoid LLM if catalog already has this sceneTag
var cached = catalogRepo.findActivityBySceneTag(request.sceneTag());
if (cached.isPresent()) {
    var act = cached.get();
    var phrases = catalogRepo.findPhrasesByActivityId(act.id());
    return buildResponseFromCache(act, phrases);
}
```
3. 现有 LLM 生成逻辑保持不变，追加调用：
```java
// 2. After LLM generation, persist to catalog
var spaceSlug = classifySceneTagToSpace(llmResult.sceneTag(), llmResult.spaceTitle());
var spaceId = catalogRepo.findSpaceIdBySlug(spaceSlug)
    .orElseGet(() -> catalogRepo.insertSpace(spaceSlug, llmResult.spaceTitle()));
var activitySlug = "llm_" + sanitize(llmResult.sceneTag()) + "_" + uuid8();
var activityId = catalogRepo.insertActivity(activitySlug, spaceId,
    llmResult.title(), llmResult.sceneTag(), llmResult.coachTip());
for (int i = 0; i < llmResult.phrases().size(); i++) {
    var p = llmResult.phrases().get(i);
    var phraseSlug = activitySlug + "_" + i;
    catalogRepo.insertPhrase(phraseSlug, activityId, i + 1,
        p.english(), p.chinese(), p.pronunciation(), p.difficulty());
}
// 3. Return with DB IDs
return buildResponseWithIds(llmResult, activitySlug, activityId, phraseSlug, phraseId);
```

**LLM prompt 修改**：在现有 system prompt 末尾追加：
```
已有场景空间（spaceSlug 列表）：
{{SPACES_SLUGS}}
请将本次练习内容归入最匹配的已有 space。若确实没有匹配（全新场景），请在响应 JSON 中额外输出 "spaceSlug": "<new_slug>" 和 "spaceTitleZh": "<中文名>"。
若归入已有 space，只输出 "spaceSlug": "<existing_slug>"，"spaceTitleZh" 为空。
```

- [ ] **Step 3: 编译 + 基础单元测试**

验证 `PracticeCatalogRepository` 能正确找到 seed 数据：

```bash
cd backend
./mvnw test -pl app-api -Dtest=PracticeCatalogRepositoryTest -q 2>&1 | tail -20
```

（测试文件在 app-api/src/test/java 中创建，使用嵌入式 H2 或 @DataJpaTest 模式）

- [ ] **Step 4: commit**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepository.java
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java
git commit -m "feat(backend): MentorService catalog cache-hit + write-through (D2/D3)"
```

---

## Task 6: Flutter — GrowthInsightsApiService + 数据模型

**Files:**
- Create: `mobile/lib/features/growth/data/remote/growth_insights_api_service.dart`
- Create: `mobile/lib/features/growth/data/models/growth_insights_payload.dart`
- Modify: `mobile/lib/app/providers/repository_providers.dart`（新增 provider）

- [ ] **Step 1: 创建 growth_insights_payload.dart**

```dart
// mobile/lib/features/growth/data/models/growth_insights_payload.dart

class GrowthInsightsPayload {
  const GrowthInsightsPayload({
    required this.period,
    required this.windowStart,
    required this.windowEnd,
    required this.generatedAt,
    required this.stats,
    required this.streak,
    required this.bars,
    required this.scenes,
    required this.recentActivity,
    this.suggestion,
  });

  final String period;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime generatedAt;
  final InsightsStats stats;
  final InsightsStreak streak;
  final List<InsightsBarBucket> bars;
  final List<InsightsScene> scenes;
  final InsightsRecentActivity recentActivity;
  final InsightsSuggestion? suggestion;

  factory GrowthInsightsPayload.fromJson(Map<String, dynamic> json) =>
      GrowthInsightsPayload(
        period: json['period'] as String,
        windowStart: DateTime.parse(json['windowStart'] as String),
        windowEnd: DateTime.parse(json['windowEnd'] as String),
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        stats: InsightsStats.fromJson(json['stats'] as Map<String, dynamic>),
        streak: InsightsStreak.fromJson(json['streak'] as Map<String, dynamic>),
        bars: (json['bars'] as List<dynamic>)
            .map((e) => InsightsBarBucket.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        scenes: (json['scenes'] as List<dynamic>)
            .map((e) => InsightsScene.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        recentActivity: InsightsRecentActivity.fromJson(
            json['recentActivity'] as Map<String, dynamic>),
        suggestion: json['suggestion'] == null
            ? null
            : InsightsSuggestion.fromJson(
                json['suggestion'] as Map<String, dynamic>),
      );
}

class InsightsStats {
  const InsightsStats({
    required this.totalEvents,
    required this.uniquePhrases,
    required this.uniqueActivities,
    required this.imitationCount,
    required this.practicedDays,
    this.firstEventAt,
    this.lastEventAt,
  });
  final int totalEvents;
  final int uniquePhrases;
  final int uniqueActivities;
  final int imitationCount;
  final int practicedDays;
  final DateTime? firstEventAt;
  final DateTime? lastEventAt;

  factory InsightsStats.fromJson(Map<String, dynamic> j) => InsightsStats(
        totalEvents: j['totalEvents'] as int,
        uniquePhrases: j['uniquePhrases'] as int,
        uniqueActivities: j['uniqueActivities'] as int,
        imitationCount: j['imitationCount'] as int,
        practicedDays: j['practicedDays'] as int,
        firstEventAt: j['firstEventAt'] == null
            ? null
            : DateTime.parse(j['firstEventAt'] as String),
        lastEventAt: j['lastEventAt'] == null
            ? null
            : DateTime.parse(j['lastEventAt'] as String),
      );
}

class InsightsStreak {
  const InsightsStreak({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysPracticed,
    this.lastPracticedAt,
  });
  final int currentStreak;
  final int longestStreak;
  final int totalDaysPracticed;
  final DateTime? lastPracticedAt;

  factory InsightsStreak.fromJson(Map<String, dynamic> j) => InsightsStreak(
        currentStreak: j['currentStreak'] as int,
        longestStreak: j['longestStreak'] as int,
        totalDaysPracticed: j['totalDaysPracticed'] as int,
        lastPracticedAt: j['lastPracticedAt'] == null
            ? null
            : DateTime.parse(j['lastPracticedAt'] as String),
      );
}

class InsightsBarBucket {
  const InsightsBarBucket({required this.bucketStart, required this.count});
  final DateTime bucketStart;
  final int count;

  factory InsightsBarBucket.fromJson(Map<String, dynamic> j) =>
      InsightsBarBucket(
        bucketStart: DateTime.parse(j['bucketStart'] as String),
        count: j['count'] as int,
      );
}

class InsightsScene {
  const InsightsScene({
    required this.spaceId,
    required this.sceneTag,
    required this.eventCount,
    required this.activityCount,
    required this.percentage,
  });
  final String spaceId;
  final String sceneTag;
  final int eventCount;
  final int activityCount;
  final double percentage;

  factory InsightsScene.fromJson(Map<String, dynamic> j) => InsightsScene(
        spaceId: j['spaceId'] as String,
        sceneTag: j['sceneTag'] as String,
        eventCount: j['eventCount'] as int,
        activityCount: j['activityCount'] as int,
        percentage: (j['percentage'] as num).toDouble(),
      );
}

class InsightsRecentActivity {
  const InsightsRecentActivity({
    required this.thisWeekCount,
    required this.lastWeekCount,
  });
  final int thisWeekCount;
  final int lastWeekCount;

  factory InsightsRecentActivity.fromJson(Map<String, dynamic> j) =>
      InsightsRecentActivity(
        thisWeekCount: j['thisWeekCount'] as int,
        lastWeekCount: j['lastWeekCount'] as int,
      );
}

class InsightsSuggestion {
  const InsightsSuggestion({
    required this.spaceId,
    required this.activityId,
    required this.sceneLabel,
    required this.phraseEnglish,
  });
  final String spaceId;
  final String activityId;
  final String sceneLabel;
  final String phraseEnglish;

  factory InsightsSuggestion.fromJson(Map<String, dynamic> j) =>
      InsightsSuggestion(
        spaceId: j['spaceId'] as String,
        activityId: j['activityId'] as String,
        sceneLabel: j['sceneLabel'] as String,
        phraseEnglish: j['phraseEnglish'] as String,
      );
}
```

- [ ] **Step 2: 创建 growth_insights_api_service.dart**

（完全对照 `growth_summary_api_service.dart` 模式）

```dart
// mobile/lib/features/growth/data/remote/growth_insights_api_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';

enum GrowthInsightsApiFailureKind { network, timeout, malformed, http }

class GrowthInsightsApiException implements Exception {
  const GrowthInsightsApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });
  final GrowthInsightsApiFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'GrowthInsightsApiException(kind: $kind, statusCode: $statusCode, message: $message)';
}

class GrowthInsightsApiService {
  GrowthInsightsApiService({
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;
  final String appVersion;

  Future<GrowthInsightsPayload> fetchInsights(String period) async {
    try {
      final response = await _dio.get<String>(
        '/api/v1/growth/insights',
        queryParameters: {'period': period},
        options: Options(responseType: ResponseType.plain),
      );

      final body = response.data;
      if (body == null || body.isEmpty) {
        throw const GrowthInsightsApiException(
          kind: GrowthInsightsApiFailureKind.malformed,
          message: 'Empty response body',
        );
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return GrowthInsightsPayload.fromJson(json);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GrowthInsightsApiException(
          kind: GrowthInsightsApiFailureKind.timeout,
          message: e.message ?? 'timeout',
        );
      }
      if (e.response != null) {
        throw GrowthInsightsApiException(
          kind: GrowthInsightsApiFailureKind.http,
          message: e.message ?? 'http error',
          statusCode: e.response!.statusCode,
        );
      }
      throw GrowthInsightsApiException(
        kind: GrowthInsightsApiFailureKind.network,
        message: e.message ?? 'network error',
      );
    } on SocketException catch (e) {
      throw GrowthInsightsApiException(
        kind: GrowthInsightsApiFailureKind.network,
        message: e.message,
      );
    } on FormatException catch (e) {
      throw GrowthInsightsApiException(
        kind: GrowthInsightsApiFailureKind.malformed,
        message: e.message,
      );
    }
  }

  void dispose() {
    if (_ownsDio) _dio.close();
  }
}
```

- [ ] **Step 3: 在 repository_providers.dart 注册 provider**

在现有 `growthSummaryApiServiceProvider` 下方添加：

```dart
// 在 import 区增加
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';

// 在 provider 定义区增加
final growthInsightsApiServiceProvider = Provider<GrowthInsightsApiService>((ref) {
  return GrowthInsightsApiService();
});
```

- [ ] **Step 4: Flutter 分析**

```bash
cd mobile
flutter analyze lib/features/growth/data/ 2>&1 | tail -20
```

期望：`No issues found!`

- [ ] **Step 5: commit**

```bash
git add mobile/lib/features/growth/data/models/growth_insights_payload.dart
git add mobile/lib/features/growth/data/remote/growth_insights_api_service.dart
git add mobile/lib/app/providers/repository_providers.dart
git commit -m "feat(flutter): add GrowthInsightsApiService + payload models"
```

---

## Task 7: Flutter — GrowthInsightsNotifier 改造

**Files:**
- Modify: `mobile/lib/features/growth/presentation/growth_insights_notifier.dart`
- Modify: `mobile/lib/app/providers/repository_providers.dart`（更新 notifier provider）

- [ ] **Step 1: 重写 GrowthInsightsNotifier**

完全替换 `growth_insights_notifier.dart` 内容：

```dart
// mobile/lib/features/growth/presentation/growth_insights_notifier.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads growth insights from the backend API (parallel calls for all 3 periods)
/// and maps responses to [GrowthInsightsViewState].
///
/// Cache: SharedPreferences JSON per period, TTL 15 minutes.
/// Offline: On network failure, shows stale cache data with [cachedAt] timestamp.
class GrowthInsightsNotifier extends ChangeNotifier {
  GrowthInsightsNotifier({
    required GrowthInsightsApiService apiService,
    DateTime Function()? now,
  }) : _apiService = apiService,
       _now = now ?? DateTime.now;

  final GrowthInsightsApiService _apiService;
  final DateTime Function() _now;

  static const _ttlMinutes = 15;
  static const _cacheKeyPrefix = 'growth_insights_v1_';

  Map<GrowthPeriod, GrowthInsightsViewState> _states = {};
  bool _loaded = false;
  bool _hasError = false;
  bool _disposed = false;

  bool get isLoaded => _loaded;
  bool get hasError => _hasError;

  Future<void> initialize() async {
    if (_loaded) return;

    // First: populate from cache (instant paint)
    final cachedStates = await _loadFromCache();
    if (cachedStates.isNotEmpty) {
      _states = cachedStates;
      if (!_disposed) notifyListeners();
    }

    // Then: fetch fresh data in parallel
    try {
      final results = await Future.wait([
        _fetchWithFallback(GrowthPeriod.week),
        _fetchWithFallback(GrowthPeriod.month),
        _fetchWithFallback(GrowthPeriod.year),
      ]);
      _states = {
        GrowthPeriod.week:  results[0],
        GrowthPeriod.month: results[1],
        GrowthPeriod.year:  results[2],
      };
      _hasError = false;
    } catch (_) {
      _hasError = _states.isEmpty;  // only error if no cache
    } finally {
      _loaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  GrowthInsightsViewState viewFor(GrowthPeriod period) {
    if (!_loaded && _states.isEmpty) return GrowthInsightsViewState.loading(period);
    return _states[period] ?? GrowthInsightsViewState.loading(period);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── internal ──────────────────────────────────────────────────────────

  Future<GrowthInsightsViewState> _fetchWithFallback(GrowthPeriod period) async {
    try {
      final payload = await _apiService.fetchInsights(_periodWire(period));
      final state = _mapPayloadToViewState(payload, period);
      await _saveToCache(period, payload);
      return state;
    } catch (_) {
      return _states[period] ?? GrowthInsightsViewState.error(period);
    }
  }

  GrowthInsightsViewState _mapPayloadToViewState(
      GrowthInsightsPayload p, GrowthPeriod period) {
    final bars = p.bars
        .map((b) => GrowthBarBucket(
              label: _bucketLabel(b.bucketStart, period),
              count: b.count,
            ))
        .toList(growable: false);

    final scenes = p.scenes
        .map((s) => GrowthSceneEntry(
              spaceId: s.spaceId,
              sceneTag: s.sceneTag,
              eventCount: s.eventCount,
              percentage: s.percentage,
            ))
        .toList(growable: false);

    final suggestion = p.suggestion == null
        ? null
        : GrowthNextStepSuggestion(
            sceneLabel: p.suggestion!.sceneLabel,
            phraseEnglish: p.suggestion!.phraseEnglish,
            spaceId: p.suggestion!.spaceId,
            activityId: p.suggestion!.activityId,
          );

    final recentActivity = GrowthRecentActivity(
      thisWeekCount: p.recentActivity.thisWeekCount,
      lastWeekCount: p.recentActivity.lastWeekCount,
    );

    return GrowthInsightsViewState(
      isLoading: false,
      hasError: false,
      period: period,
      totalEvents: p.stats.totalEvents,
      uniquePhrases: p.stats.uniquePhrases,
      uniqueActivities: p.stats.uniqueActivities,
      imitationCount: p.stats.imitationCount,
      practicedDays: p.stats.practicedDays,
      currentStreak: p.streak.currentStreak,
      longestStreak: p.streak.longestStreak,
      bars: bars,
      scenes: scenes,
      suggestion: suggestion,
      recentActivity: recentActivity,
      windowStart: p.windowStart,
      windowEnd: p.windowEnd,
    );
  }

  String _bucketLabel(DateTime dt, GrowthPeriod period) {
    switch (period) {
      case GrowthPeriod.week:
        const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        return weekdays[dt.weekday - 1];
      case GrowthPeriod.month:
        return '${dt.month}/${dt.day}';
      case GrowthPeriod.year:
        return '${dt.month}月';
    }
  }

  String _periodWire(GrowthPeriod p) {
    switch (p) {
      case GrowthPeriod.week:  return 'week';
      case GrowthPeriod.month: return 'month';
      case GrowthPeriod.year:  return 'year';
    }
  }

  // ── cache ─────────────────────────────────────────────────────────────

  Future<Map<GrowthPeriod, GrowthInsightsViewState>> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <GrowthPeriod, GrowthInsightsViewState>{};
    for (final period in GrowthPeriod.values) {
      final key = '$_cacheKeyPrefix${_periodWire(period)}';
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final wrapper = jsonDecode(raw) as Map<String, dynamic>;
        final cachedAt = DateTime.parse(wrapper['cachedAt'] as String);
        if (_now().difference(cachedAt).inMinutes > _ttlMinutes) continue;
        final payload = GrowthInsightsPayload.fromJson(
            wrapper['payload'] as Map<String, dynamic>);
        result[period] = _mapPayloadToViewState(payload, period);
      } catch (_) {
        // Corrupt cache — ignore
      }
    }
    return result;
  }

  Future<void> _saveToCache(GrowthPeriod period, GrowthInsightsPayload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix${_periodWire(period)}';
      // Re-serialize payload for cache (store the raw json map)
      await prefs.setString(key, jsonEncode({
        'cachedAt': _now().toIso8601String(),
        'payload': _payloadToJson(payload),
      }));
    } catch (_) {
      // Cache failure must never block the caller
    }
  }

  Map<String, dynamic> _payloadToJson(GrowthInsightsPayload p) => {
    'period': p.period,
    'windowStart': p.windowStart.toIso8601String(),
    'windowEnd': p.windowEnd.toIso8601String(),
    'generatedAt': p.generatedAt.toIso8601String(),
    'stats': {
      'totalEvents': p.stats.totalEvents,
      'uniquePhrases': p.stats.uniquePhrases,
      'uniqueActivities': p.stats.uniqueActivities,
      'imitationCount': p.stats.imitationCount,
      'practicedDays': p.stats.practicedDays,
      'firstEventAt': p.stats.firstEventAt?.toIso8601String(),
      'lastEventAt': p.stats.lastEventAt?.toIso8601String(),
    },
    'streak': {
      'currentStreak': p.streak.currentStreak,
      'longestStreak': p.streak.longestStreak,
      'totalDaysPracticed': p.streak.totalDaysPracticed,
      'lastPracticedAt': p.streak.lastPracticedAt?.toIso8601String(),
    },
    'bars': p.bars.map((b) => {
      'bucketStart': b.bucketStart.toIso8601String(),
      'count': b.count,
    }).toList(),
    'scenes': p.scenes.map((s) => {
      'spaceId': s.spaceId,
      'sceneTag': s.sceneTag,
      'eventCount': s.eventCount,
      'activityCount': s.activityCount,
      'percentage': s.percentage,
    }).toList(),
    'recentActivity': {
      'thisWeekCount': p.recentActivity.thisWeekCount,
      'lastWeekCount': p.recentActivity.lastWeekCount,
    },
    if (p.suggestion != null) 'suggestion': {
      'spaceId': p.suggestion!.spaceId,
      'activityId': p.suggestion!.activityId,
      'sceneLabel': p.suggestion!.sceneLabel,
      'phraseEnglish': p.suggestion!.phraseEnglish,
    },
  };
}
```

> **注意**：`GrowthInsightsViewState` 的字段（`scenes`, `windowStart/End` 等）可能需要在 `growth_insights_models.dart` 中补充。实现时先检查现有字段，仅添加缺少的字段，不修改已有字段。

- [ ] **Step 2: 更新 growthInsightsNotifierProvider**

在 `repository_providers.dart` 中找到现有的 growthInsightsNotifier provider，改为：

```dart
// 在 import 区增加
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';

// 替换现有 provider（如果存在）或新增
final growthInsightsNotifierProvider =
    ChangeNotifierProvider<GrowthInsightsNotifier>((ref) {
  return GrowthInsightsNotifier(
    apiService: ref.watch(growthInsightsApiServiceProvider),
  );
});
```

- [ ] **Step 3: Flutter 分析**

```bash
cd mobile
flutter analyze lib/features/growth/ 2>&1 | tail -20
```

期望：`No issues found!`（或仅 info 级别提示）

- [ ] **Step 4: 运行 growth 相关测试**

```bash
cd mobile
flutter test test/features/growth/ 2>&1 | tail -30
```

期望：所有测试 PASS（若已有测试引用本地计算方法，需相应更新）

- [ ] **Step 5: commit**

```bash
git add mobile/lib/features/growth/presentation/growth_insights_notifier.dart
git add mobile/lib/app/providers/repository_providers.dart
git commit -m "feat(flutter): GrowthInsightsNotifier — replace local calc with API calls + cache"
```

---

## Task 8: Flutter — Garden Snapshot + Fertilizer 接通

**Files:**
- Create: `mobile/lib/features/garden/data/remote/garden_snapshot_api_service.dart`
- Create: `mobile/lib/features/garden/data/models/garden_snapshot_payload.dart`
- Modify: `mobile/lib/app/providers/repository_providers.dart`（接通 remoteDataSource）

- [ ] **Step 1: 创建 garden_snapshot_payload.dart**

```dart
// mobile/lib/features/garden/data/models/garden_snapshot_payload.dart

class GardenSnapshotPayload {
  const GardenSnapshotPayload({
    required this.generatedAt,
    required this.knownEvents,
    required this.coveredSpaceCount,
    required this.currentStreakDays,
    required this.milestones,
    required this.pendingEventKeys,
  });

  final DateTime generatedAt;
  final int knownEvents;
  final int coveredSpaceCount;
  final int currentStreakDays;
  final List<MilestonePayload> milestones;
  final List<String> pendingEventKeys;

  factory GardenSnapshotPayload.fromJson(Map<String, dynamic> json) =>
      GardenSnapshotPayload(
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        knownEvents: json['knownEvents'] as int,
        coveredSpaceCount: json['coveredSpaceCount'] as int,
        currentStreakDays: json['currentStreakDays'] as int,
        milestones: (json['milestones'] as List<dynamic>)
            .map((e) => MilestonePayload.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        pendingEventKeys: (json['pendingEventKeys'] as List<dynamic>)
            .map((e) => e as String)
            .toList(growable: false),
      );
}

class MilestonePayload {
  const MilestonePayload({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.achievedAt,
    this.remainingHint,
  });

  final String id;
  final String title;
  final int sortOrder;
  final DateTime? achievedAt;
  final String? remainingHint;

  factory MilestonePayload.fromJson(Map<String, dynamic> j) => MilestonePayload(
        id: j['id'] as String,
        title: j['title'] as String,
        sortOrder: j['sortOrder'] as int,
        achievedAt: j['achievedAt'] == null
            ? null
            : DateTime.parse(j['achievedAt'] as String),
        remainingHint: j['remainingHint'] as String?,
      );
}
```

- [ ] **Step 2: 创建 garden_snapshot_api_service.dart**

```dart
// mobile/lib/features/garden/data/remote/garden_snapshot_api_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/garden/data/models/garden_snapshot_payload.dart';

enum GardenSnapshotApiFailureKind { network, timeout, malformed, http }

class GardenSnapshotApiException implements Exception {
  const GardenSnapshotApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });
  final GardenSnapshotApiFailureKind kind;
  final String message;
  final int? statusCode;
}

class GardenSnapshotApiService {
  GardenSnapshotApiService({
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;
  final String appVersion;

  Future<GardenSnapshotPayload> fetchSnapshot() async {
    try {
      final response = await _dio.get<String>(
        '/api/v1/garden/snapshot',
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        throw const GardenSnapshotApiException(
          kind: GardenSnapshotApiFailureKind.malformed,
          message: 'Empty response body',
        );
      }
      return GardenSnapshotPayload.fromJson(
          jsonDecode(body) as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GardenSnapshotApiException(
          kind: GardenSnapshotApiFailureKind.timeout,
          message: e.message ?? 'timeout',
        );
      }
      throw GardenSnapshotApiException(
        kind: e.response != null
            ? GardenSnapshotApiFailureKind.http
            : GardenSnapshotApiFailureKind.network,
        message: e.message ?? 'error',
        statusCode: e.response?.statusCode,
      );
    } on SocketException catch (e) {
      throw GardenSnapshotApiException(
        kind: GardenSnapshotApiFailureKind.network,
        message: e.message,
      );
    }
  }

  void dispose() {
    if (_ownsDio) _dio.close();
  }
}
```

- [ ] **Step 3: 接通 GardenFertilizerRepository remoteDataSource（1行）**

在 `repository_providers.dart` 找到：
```dart
// 约第 412-419 行
final gardenFertilizerRepositoryProvider =
    FutureProvider<GardenFertilizerRepository>((ref) async {
  final localDataSource = await GardenFertilizerLocalDataSource.open(...);
  return GardenFertilizerRepository(localDataSource: localDataSource);
```

替换为：
```dart
final gardenFertilizerApiServiceProvider = Provider<GardenFertilizerApiService>((ref) {
  return GardenFertilizerApiService();
});

final gardenFertilizerRepositoryProvider =
    FutureProvider<GardenFertilizerRepository>((ref) async {
  final localDataSource = await GardenFertilizerLocalDataSource.open(...);
  return GardenFertilizerRepository(
    localDataSource: localDataSource,
    remoteDataSource: ref.watch(gardenFertilizerApiServiceProvider),  // ← 接通
  );
```

- [ ] **Step 4: 新增 gardenSnapshotApiServiceProvider**

```dart
// 在 import 区增加
import 'package:mobile/features/garden/data/remote/garden_snapshot_api_service.dart';

// 在 provider 定义区增加
final gardenSnapshotApiServiceProvider = Provider<GardenSnapshotApiService>((ref) {
  return GardenSnapshotApiService();
});
```

- [ ] **Step 5: Flutter 分析 + 测试**

```bash
cd mobile
flutter analyze lib/features/garden/ 2>&1 | tail -20
flutter test test/features/garden/ 2>&1 | tail -20
```

期望：analyze = `No issues found!`；tests PASS

- [ ] **Step 6: commit**

```bash
git add mobile/lib/features/garden/data/models/garden_snapshot_payload.dart
git add mobile/lib/features/garden/data/remote/garden_snapshot_api_service.dart
git add mobile/lib/app/providers/repository_providers.dart
git commit -m "feat(flutter): add GardenSnapshotApiService + wire GardenFertilizerRepository remote"
```

---

## Task 9: 端到端验证

- [ ] **Step 1: 启动完整 QA 环境**

```bash
# 在项目根目录
./scripts/qa-up-helm.sh
# 等待 pod 就绪
kubectl -n babytalk-qa get pods --watch
```

期望：所有 pod 状态为 `Running`

- [ ] **Step 2: 验证 growth insights API**

```bash
# 替换 <TOKEN> 为有效的 JWT
curl -s -H "Authorization: Bearer <TOKEN>" \
  "http://127.0.0.1:8091/api/v1/growth/insights?period=week" | python3 -m json.tool | head -40
```

期望：返回包含 `stats`, `streak`, `bars`, `scenes` 的 JSON

- [ ] **Step 3: 验证 garden snapshot API**

```bash
curl -s -H "Authorization: Bearer <TOKEN>" \
  "http://127.0.0.1:8091/api/v1/garden/snapshot" | python3 -m json.tool
```

期望：返回包含 `knownEvents`, `milestones`, `pendingEventKeys` 的 JSON

- [ ] **Step 4: Flutter 集成验证**

在 Flutter 成长页：
- 切换 week/month/year → 每次切换显示正确数据（不再从 Isar 读取）
- 断网时显示缓存数据 + 时间戳提示（SharedPreferences TTL 15min）

在 Flutter 花园页：
- fertilizer claim/apply 请求命中后端 API（检查网络 log）
- garden snapshot 里程碑显示与后端一致

- [ ] **Step 5: 最终 commit**

```bash
git add .
git commit -m "feat: garden & growth data migrated to backend APIs

- V22/V22_1: practice_spaces/activities/phrases catalog tables
- GET /api/v1/growth/insights?period=week|month|year
- GET /api/v1/garden/snapshot  
- Flutter: GrowthInsightsNotifier → API calls (parallel, 15min cache)
- Flutter: GardenFertilizerRepository remoteDataSource wired
- Flutter: GardenSnapshotApiService added

Closes: garden-growth-backend-migration"
```

---

## 快速参考

| 命令 | 用途 |
|------|------|
| `cd backend && ./mvnw compile -pl app-api -q` | 后端编译检查 |
| `cd mobile && flutter analyze lib/` | Flutter 静态分析 |
| `cd mobile && flutter test` | Flutter 单测 |
| `./scripts/qa-up-helm.sh` | 启动 QA 环境 |
| `kubectl -n babytalk-qa get pods` | 检查 pod 状态 |

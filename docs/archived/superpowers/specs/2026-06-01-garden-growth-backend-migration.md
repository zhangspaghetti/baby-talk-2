# 花园页 & 成长页数据后端迁移设计

**日期**: 2026-06-01  
**状态**: 待实现  
**分支**: Develop

---

## 背景与目标

### 当前痛点

- 成长页（Growth）所有统计数据（连续打卡天数、场景分布、下一步建议等）由 Flutter 客户端本地计算，依赖 Isar 本地事件表，无法跨设备同步。
- 花园页（Garden）肥料数据虽有后端 API，但 `GardenFertilizerRepository.remoteDataSource` 被注入为 `null`，实际未使用。
- 练习短语仅存在于 Flutter 打包的 `seed_content.json`，后端无 catalog 表，无法作为数据源支撑 API。

### 目标

1. 建立后端 practice catalog 表，成为场景/活动/短语的单一真相源。  
2. 新增 `GET /api/v1/growth/insights?period=` 返回完整成长洞察数据。  
3. 新增 `GET /api/v1/garden/snapshot` 返回花园全量快照。  
4. Flutter 成长页移除本地 `GrowthStatsService` 计算，改为调用后端 API。  
5. Flutter 花园页接通现有 `GardenFertilizerApiService`（当前 remoteDataSource=null）。  

---

## 架构决策

### D1 — Catalog 存储：正规 3 表结构

新建三张关系表（V22 migration）：`practice_spaces`, `practice_activities`, `practice_phrases`。  
数据量小（~5 spaces / ~20 activities / ~60 phrases），JOIN 高效，可扩展多语言。

### D2 — LLM 内容持久化：生成时即保存

`POST /mentor/practice/generate` 生成内容后立即写 DB，返回 `activity_id` + `phrase_id`。  
Flutter 使用这些 ID 记录 `interaction_events`。

### D3 — LLM sceneTag 归属 space：分类归入已有 space

先查 `practice_activities.scene_tag_en = sceneTag`（精确缓存命中）。  
未命中时：LLM prompt 附上已有 space 列表，LLM 分类归入最近 space 或创建新 space（提供 `title_zh`）。  
LLM agent 可调用 `palace_vector_search` 工具辅助理解场景语义。

---

## 数据模型

### V22 Flyway Migration — 新建 Catalog 表

**主键策略**：BIGSERIAL 作内部主键（高效 JOIN），`slug` UNIQUE 列保留人可读 ID 以兼容 `interaction_events`（该表存的是 varchar 标识，无 FK 约束）。

```sql
CREATE TABLE practice_spaces (
    id             BIGSERIAL    PRIMARY KEY,
    slug           VARCHAR(96)  UNIQUE NOT NULL,     -- 'daily_care'（与 interaction_events.space_id 对应）
    title_zh       VARCHAR(120) NOT NULL,             -- '日常照护'
    description_zh TEXT,
    sort_order     INT NOT NULL DEFAULT 0,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE practice_activities (
    id            BIGSERIAL    PRIMARY KEY,
    slug          VARCHAR(96)  UNIQUE,               -- 'bath_time'（与 interaction_events.activity_id 对应）
    space_id      BIGINT       NOT NULL REFERENCES practice_spaces(id),
    title_zh      VARCHAR(120) NOT NULL,             -- '洗澡时间'
    scene_tag_en  VARCHAR(120),                      -- 'Bath time'（sceneTag 缓存命中用）
    coach_tip     TEXT,
    sort_order    INT NOT NULL DEFAULT 0,
    source        VARCHAR(16)  NOT NULL DEFAULT 'seed', -- 'seed' | 'llm'
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE practice_phrases (
    id            BIGSERIAL    PRIMARY KEY,
    slug          VARCHAR(120) UNIQUE,               -- 'bath_time_warm_water'（与 interaction_events.phrase_id 对应）
    activity_id   BIGINT       NOT NULL REFERENCES practice_activities(id),
    step          INT NOT NULL,
    english       VARCHAR(240) NOT NULL,             -- 'Warm water.'
    chinese       VARCHAR(240) NOT NULL,             -- '水暖暖的。'
    pronunciation VARCHAR(240),
    difficulty    VARCHAR(16),                       -- 'starter' | 'easy' | 'medium'
    audio_asset   VARCHAR(240),
    source        VARCHAR(16)  NOT NULL DEFAULT 'seed', -- 'seed' | 'llm'
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_practice_activities_space_id ON practice_activities(space_id);
CREATE INDEX idx_practice_activities_slug ON practice_activities(slug);
CREATE INDEX idx_practice_activities_scene_tag_en ON practice_activities(scene_tag_en);
CREATE INDEX idx_practice_phrases_activity_id ON practice_phrases(activity_id);
CREATE INDEX idx_practice_phrases_step ON practice_phrases(activity_id, step);
```

**JOIN 模式**（`interaction_events` → catalog）：
```sql
-- 示例：按场景聚合事件数
SELECT ps.title_zh, COUNT(*) AS event_count
FROM interaction_events ie
LEFT JOIN practice_activities pa ON pa.slug = ie.activity_id
LEFT JOIN practice_spaces      ps ON ps.id  = pa.space_id
WHERE ie.account_id = :accountId
GROUP BY ps.id, ps.title_zh;
```

### V22_1 Seed Migration — 从 seed_content.json 填充

以 seed_content.json 中的真实数据为准，Flyway INSERT 语句覆盖全部静态场景。  
关键记录示例（不完整，实现时以文件为准）：

```sql
-- 使用 slug 列插入（BIGSERIAL id 自动生成）
INSERT INTO practice_spaces (slug, title_zh, sort_order) VALUES
  ('daily_care',    '日常照护', 1),
  ('mealtime',      '用餐时间', 2),
  ('play_time',     '游戏时间', 3),
  ('bedtime',       '睡前时间', 4),
  ('outdoor',       '户外活动', 5);

INSERT INTO practice_activities (slug, space_id, title_zh, scene_tag_en, sort_order) VALUES
  ('bath_time',     (SELECT id FROM practice_spaces WHERE slug='daily_care'), '洗澡时间', 'Bath time',     1),
  ('diaper_change', (SELECT id FROM practice_spaces WHERE slug='daily_care'), '换尿布',   'Diaper change', 2),
  ...;

INSERT INTO practice_phrases (slug, activity_id, step, english, chinese, pronunciation, difficulty) VALUES
  ('bath_time_warm_water',    (SELECT id FROM practice_activities WHERE slug='bath_time'), 1, 'Warm water.',     '水暖暖的。',   'wɔːrm ˈwɔːtɚ', 'starter'),
  ('bath_time_splash_splash', (SELECT id FROM practice_activities WHERE slug='bath_time'), 2, 'Splash, splash!', '哗啦，哗啦！', 'splæʃ splæʃ',  'starter'),
  ('bath_time_all_clean',     (SELECT id FROM practice_activities WHERE slug='bath_time'), 3, 'All clean.',       '洗干净啦。',   'ɔːl kliːn',    'starter'),
  ...;
```

---

## 后端新增 API

### 1. `GET /api/v1/growth/insights?period=week|month|year`

**响应体**：

```json
{
  "period": "week",
  "windowStart": "2026-05-25T00:00:00Z",
  "windowEnd": "2026-06-01T12:00:00Z",
  "generatedAt": "2026-06-01T12:00:00Z",
  "stats": {
    "totalEvents": 42,
    "uniquePhrases": 15,
    "uniqueActivities": 7,
    "imitationCount": 12,
    "practicedDays": 5,
    "firstEventAt": "2026-05-26T08:00:00Z",
    "lastEventAt": "2026-06-01T09:30:00Z"
  },
  "streak": {
    "currentStreak": 3,
    "longestStreak": 7,
    "totalDaysPracticed": 21,
    "lastPracticedAt": "2026-06-01T09:30:00Z"
  },
  "bars": [
    { "bucketStart": "2026-05-25T00:00:00Z", "count": 4 },
    { "bucketStart": "2026-05-26T00:00:00Z", "count": 8 }
  ],
  "scenes": [
    {
      "spaceId": "daily_care",
      "sceneTag": "日常照护",
      "eventCount": 25,
      "activityCount": 4,
      "percentage": 59.5
    }
  ],
  "recentActivity": {
    "thisWeekCount": 12,
    "lastWeekCount": 8
  },
  "suggestion": {
    "spaceId": "daily_care",
    "activityId": "bath_time",
    "sceneLabel": "日常照护",
    "phraseEnglish": "Warm water."
  }
}
```

**注意事项**：
- `bars`：week=7天桶，month≈4-5周桶，year=12月桶。`bucketStart` 为 ISO8601，Flutter 负责生成展示标签。
- `scenes`：仅返回前 5 名，按 eventCount DESC。`sceneTag` 来自 `practice_spaces.title_zh`（LEFT JOIN，未知 spaceId 返回 spaceId 原始值）。
- `suggestion`：year period 返回 null；week/month 返回当前时间窗口内 eventCount=0 的第一个 activity（按 space.sort_order + activity.sort_order 排序），取 step=1 的 phrase.english。
- `streak` 计算：以 `client_timestamp` 按天分组（上海时区），找连续日期序列。

**Spring Boot 实现**：
- 新建 `GrowthInsightsController`（`GET /api/v1/growth/insights`）
- 新建 `GrowthInsightsService`（独立于现有 `GrowthSummaryService`，现有接口保持兼容）
- 核心 SQL：
  - stats/streak：单次查询 `interaction_events` 聚合
  - bars：`DATE_TRUNC('day'/'week'/'month', client_timestamp)` GROUP BY
  - scenes：JOIN `practice_spaces` GROUP BY space_id
  - suggestion：LEFT JOIN `practice_activities` WHERE NOT EXISTS (events in window)

### 2. `GET /api/v1/garden/snapshot`

**响应体**：

```json
{
  "generatedAt": "2026-06-01T12:00:00Z",
  "knownEvents": 87,
  "coveredSpaceCount": 4,
  "currentStreakDays": 3,
  "milestones": [
    {
      "id": "first_practice",
      "title": "开始记录",
      "sortOrder": 1,
      "achievedAt": "2026-03-15T10:00:00Z",
      "remainingHint": null
    },
    {
      "id": "ten_phrases",
      "title": "练习了10句",
      "sortOrder": 2,
      "achievedAt": "2026-03-20T09:00:00Z",
      "remainingHint": null
    },
    {
      "id": "three_spaces",
      "title": "探索3个场景",
      "sortOrder": 3,
      "achievedAt": null,
      "remainingHint": "还差 1 个场景"
    }
  ],
  "pendingEventKeys": ["evt_abc123", "evt_def456"]
}
```

**里程碑定义**（复制自 Flutter `garden_growth_repository.dart` 阈值）：

| id | title | 触发条件 |
|---|---|---|
| `first_practice` | 开始记录 | knownEvents >= 1 |
| `ten_phrases` | 练习了10句 | uniquePhrases >= 10 |
| `three_spaces` | 探索3个场景 | coveredSpaceCount >= 3 |
| `streak_7` | 坚持7天 | currentStreak >= 7 |
| `fifty_events` | 练习了50次 | knownEvents >= 50 |

**`pendingEventKeys`**：`interaction_events.event_key` 中不在 `garden_fertilizer_claim_log.event_key` 的记录（最多 20 条，按 `client_timestamp` ASC 排序）。

**Spring Boot 实现**：
- 新建 `GardenSnapshotController`（`GET /api/v1/garden/snapshot`）
- 新建 `GardenSnapshotService`：
  - 单次 SQL 聚合 `interaction_events` → knownEvents, uniquePhrases, coveredSpaceCount, streak
  - LEFT JOIN `garden_fertilizer_claim_log` → pendingEventKeys
  - Java 侧计算里程碑状态（纯 if/switch，无额外 SQL）

---

## `mentor/practice/generate` 改造（D2）

### 变更范围

`MentorService.generatePractice()` 增加：
1. 先查 `practice_activities WHERE scene_tag_en = :sceneTag`
   - 命中 → 查 `practice_phrases WHERE activity_id = :activityId` 返回（无需 LLM）
2. 未命中 → LLM 生成（现有 prompt + palace tools，追加 space 列表提示 LLM 分类）
3. LLM 结果验证后：
   - 若 `spaceId` 不存在于 `practice_spaces` → INSERT 新 space（`title_zh` 来自 LLM 响应新增字段）
   - INSERT `practice_activities`（`source='llm'`，id = `llm_<sceneTag>_<uuid8>`）
   - INSERT `practice_phrases`（`source='llm'`）
4. 返回响应增加 `activityId` 和每个 phrase 的 `phraseId` 字段

### `PracticeGenerateResponse` 变更

```java
// 新增字段
public record GeneratedActivity(
    Long   activityId,     // practice_activities.id (BIGSERIAL)
    String activitySlug,   // practice_activities.slug (供 interaction_events JOIN)
    String title,
    String summary,
    String sceneTag,
    String coachTip,
    List<GeneratedPhrase> phrases
) {}

public record GeneratedPhrase(
    Long   phraseId,       // practice_phrases.id (BIGSERIAL)（新增）
    String phraseSlug,     // practice_phrases.slug（新增）
    String english,
    String chinese,
    String pronunciation,
    String difficulty
) {}
```

---

## Flutter 层变更

### 1. `GrowthInsightsNotifier` 改造

**文件**：`mobile/lib/features/growth/presentation/growth_insights_notifier.dart`

```dart
// 改造前：本地计算
// initialize() → listEventHistory() → GrowthStatsService → _periodStats

// 改造后：并行 API 调用
Future<void> initialize() async {
  state = GrowthInsightsState.loading();
  
  final futures = await Future.wait([
    _apiService.fetchInsights(GrowthPeriod.week),
    _apiService.fetchInsights(GrowthPeriod.month),
    _apiService.fetchInsights(GrowthPeriod.year),
  ]);
  
  _periodStats = {
    GrowthPeriod.week: futures[0].toViewState(),
    GrowthPeriod.month: futures[1].toViewState(),
    GrowthPeriod.year: futures[2].toViewState(),
  };
  
  state = GrowthInsightsState.loaded();
}
```

**缓存策略**：SharedPreferences 存 3 个 period 的最后响应 JSON，TTL 15 分钟。网络失败时展示缓存数据 + 最后更新时间。

### 2. 新建 `GrowthInsightsApiService`

**文件**：`mobile/lib/features/growth/data/remote/growth_insights_api_service.dart`

- `fetchInsights(GrowthPeriod period)` → `GET /api/v1/growth/insights?period=xxx`
- 现有 `GrowthSummaryApiService` 保留不删（其他地方可能引用）

### 3. `GardenFertilizerRepository` 接通 remoteDataSource

**文件**：`mobile/lib/features/garden/presentation/providers/garden_fertilizer_provider.dart`

```dart
// 改造前
GardenFertilizerRepository(remoteDataSource: null, ...)

// 改造后
GardenFertilizerRepository(
  remoteDataSource: ref.watch(gardenFertilizerApiServiceProvider),
  ...
)
```

### 4. 新建 `GardenSnapshotApiService` + 接通 `GardenGrowthRepository`

**文件**：`mobile/lib/features/garden/data/remote/garden_snapshot_api_service.dart`

- `fetchSnapshot()` → `GET /api/v1/garden/snapshot`

**`GardenGrowthRepository`** 改为远端优先，本地 Isar 作 fallback：
```dart
Future<GardenGrowthState> loadSnapshot() async {
  try {
    final remote = await _remoteDataSource.fetchSnapshot();
    await _cacheLocally(remote);  // SharedPreferences
    return remote.toState();
  } catch (_) {
    return _loadFromCache() ?? _loadFromIsar();
  }
}
```

**缓存 TTL**：garden snapshot 5 分钟。

---

## 离线策略

| 数据 | 缓存位置 | TTL | 降级行为 |
|------|---------|-----|---------|
| Growth insights (3 periods) | SharedPreferences JSON | 15 分钟 | 展示缓存 + "xx分钟前更新" |
| Garden snapshot | SharedPreferences JSON | 5 分钟 | 展示缓存 + "xx分钟前更新" |
| Fertilizer state | SharedPreferences JSON | 5 分钟 | 降级到本地 Isar 状态 |

---

## 实现顺序

1. **V22 DB Migration** → `practice_spaces` + `practice_activities` + `practice_phrases`
2. **V22_1 Seed Migration** → 从 seed_content.json 填充全部静态数据
3. **`GrowthInsightsService` + `GrowthInsightsController`** → `GET /api/v1/growth/insights`
4. **`GardenSnapshotService` + `GardenSnapshotController`** → `GET /api/v1/garden/snapshot`
5. **`MentorService.generatePractice()` 改造** → 缓存命中优先 + LLM 生成后写 DB
6. **Flutter `GrowthInsightsApiService`** + `GrowthInsightsNotifier` 改造
7. **Flutter `GardenSnapshotApiService`** + `GardenGrowthRepository` 接通
8. **Flutter `GardenFertilizerRepository` remoteDataSource** 接通（1 行改动）
9. **SharedPreferences 缓存层** 对 growth/garden 两个接口
10. **端到端测试**

---

## 风险与边界

- **互操作性**：`interaction_events` 已有历史数据（`space_id/activity_id` 为静态 catalog 值），V22 seed migration 后 JOIN 自动兼容。
- **LLM space 分类准确性**：LLM 可能将 `sceneTag` 归入错误 space；需人工审核或 admin-web 提供修正入口（V2 需求）。
- **`practice_activities.id` 唯一性**：LLM-generated 使用 UUID 前缀格式，与静态字符串 ID 不冲突。
- **`GrowthSummaryController` 保留**：现有 `GET /api/v1/growth/summary` 不变，向后兼容旧版 Flutter。
- **时区**：streak 计算以 `client_timestamp` 上海时区 (Asia/Shanghai) 为准，与 Flutter 行为一致。

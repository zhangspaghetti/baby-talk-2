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

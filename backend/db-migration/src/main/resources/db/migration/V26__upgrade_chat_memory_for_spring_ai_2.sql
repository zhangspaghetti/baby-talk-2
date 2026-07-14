-- Spring AI 2 JdbcChatMemoryRepository persists and reads messages by sequence_id.
-- V13 retained no immutable historical message key. For timestamp ties, ctid is a
-- deterministic tie-breaker for this one migration; sequence_id is canonical afterwards.
ALTER TABLE spring_ai_chat_memory
    ADD COLUMN IF NOT EXISTS sequence_id BIGINT;

WITH ordered_messages AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY conversation_id
            ORDER BY "timestamp", ctid
        ) AS assigned_sequence_id
    FROM spring_ai_chat_memory
    WHERE sequence_id IS NULL
)
UPDATE spring_ai_chat_memory AS memory
SET sequence_id = ordered_messages.assigned_sequence_id
FROM ordered_messages
WHERE memory.ctid = ordered_messages.ctid;

ALTER TABLE spring_ai_chat_memory
    ALTER COLUMN sequence_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_spring_ai_chat_memory_conversation_sequence
    ON spring_ai_chat_memory(conversation_id, sequence_id);

CREATE SEQUENCE IF NOT EXISTS spring_ai_chat_memory_sequence_id_seq AS BIGINT;

ALTER SEQUENCE spring_ai_chat_memory_sequence_id_seq
    OWNED BY spring_ai_chat_memory.sequence_id;

SELECT setval(
    'spring_ai_chat_memory_sequence_id_seq',
    GREATEST(COALESCE((SELECT MAX(sequence_id) FROM spring_ai_chat_memory), 1), 1),
    EXISTS (SELECT 1 FROM spring_ai_chat_memory)
);

ALTER TABLE spring_ai_chat_memory
    ALTER COLUMN sequence_id SET DEFAULT nextval('spring_ai_chat_memory_sequence_id_seq'::regclass);

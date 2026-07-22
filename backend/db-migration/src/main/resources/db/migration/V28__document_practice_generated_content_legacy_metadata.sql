-- V25 parent-level metadata remains only to preserve historical rows.  V27+
-- runtime lineage belongs to the per-operation, per-provider, and per-bundle
-- audit tables; application writers must leave these legacy columns untouched.
comment on column practice_generated_content.provider_trace_id is
    'Legacy V25 read-only provider trace metadata. V27+ writes provider traces only to practice_ai_provider_calls.';

comment on column practice_generated_content.retrieval_trace_id is
    'Legacy V25 read-only retrieval trace metadata. V27+ writes retrieval traces only to practice_generated_content_evidence_bundles.';

comment on column practice_generated_content.model_name is
    'Legacy V25 read-only model metadata. V27+ writes model names only to practice_ai_provider_calls.';

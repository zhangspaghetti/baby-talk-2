alter table interaction_events
    drop constraint if exists chk_interaction_events_reaction_type;

update interaction_events
set reaction_type = case reaction_type
    when 'calm' then 'cooperating'
    when 'engaged' then 'cooperating'
    when 'imitated' then 'cooperating'
    when 'needs_break' then 'resisting'
    else reaction_type
end
where reaction_type in ('calm', 'engaged', 'imitated', 'needs_break');

alter table interaction_events
    add constraint chk_interaction_events_reaction_type
    check (reaction_type in ('cooperating', 'hesitant', 'resisting', 'no_response', 'other'));

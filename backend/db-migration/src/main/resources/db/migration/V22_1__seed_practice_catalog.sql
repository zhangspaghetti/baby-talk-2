-- V22_1: Seed practice catalog from mobile/assets/content/seed_content.json
-- Sources: 2 spaces, 4 activities, 9 phrases

-- ─── practice_spaces ────────────────────────────────────────────────────────
INSERT INTO practice_spaces (slug, title_zh, description_zh, sort_order) VALUES
  ('daily_care',   '日常照护', '把洗澡、换尿布这些重复动作变成可预测、可重复的英文互动。', 1),
  ('family_rhythm', '家庭节奏', '把吃饭和睡前这些每天都会发生的时刻，变成稳定的英语输入节奏。', 2);

-- ─── practice_activities ────────────────────────────────────────────────────
INSERT INTO practice_activities (slug, space_id, title_zh, scene_tag_en, coach_tip, sort_order) VALUES
  ('bath_time',
   (SELECT id FROM practice_spaces WHERE slug = 'daily_care'),
   '洗澡时间', 'Bath time',
   '用慢速、夸张表情和重复节奏，让宝宝先把英语和舒服、安全的体验绑定起来。',
   1),
  ('diaper_change',
   (SELECT id FROM practice_spaces WHERE slug = 'daily_care'),
   '换尿布', 'Diaper change',
   '先说动作，再做动作，让宝宝把英文和被照顾的安全感连在一起。',
   2),
  ('feeding_time',
   (SELECT id FROM practice_spaces WHERE slug = 'family_rhythm'),
   '吃饭时间', 'Feeding time',
   '一边递勺子一边说短句，节奏要稳，让宝宝先记住声音和动作的对应关系。',
   1),
  ('bedtime',
   (SELECT id FROM practice_spaces WHERE slug = 'family_rhythm'),
   '睡前时间', 'Bedtime',
   '放慢语速、压低音量，把 bedtime 的英文做成固定的收尾仪式。',
   2);

-- ─── practice_phrases ───────────────────────────────────────────────────────

-- bath_time phrases
INSERT INTO practice_phrases (slug, activity_id, step, english, chinese, pronunciation, difficulty, audio_asset) VALUES
  ('bath_time_warm_water',
   (SELECT id FROM practice_activities WHERE slug = 'bath_time'),
   1, 'Warm water.', '水暖暖的。', 'wɔːrm ˈwɔː.t̬ɚ', 'starter',
   'assets/audio/phrases/bath_time_warm_water.mp3'),
  ('bath_time_splash_splash',
   (SELECT id FROM practice_activities WHERE slug = 'bath_time'),
   2, 'Splash, splash!', '哗啦，哗啦！', 'splæʃ splæʃ', 'starter',
   'assets/audio/phrases/bath_time_splash_splash.mp3'),
  ('bath_time_all_clean',
   (SELECT id FROM practice_activities WHERE slug = 'bath_time'),
   3, 'All clean.', '洗干净啦。', 'ɔːl kliːn', 'starter',
   'assets/audio/phrases/bath_time_all_clean.mp3');

-- diaper_change phrases
INSERT INTO practice_phrases (slug, activity_id, step, english, chinese, pronunciation, difficulty, audio_asset) VALUES
  ('diaper_change_clean_bottom',
   (SELECT id FROM practice_activities WHERE slug = 'diaper_change'),
   1, 'Clean bottom.', '擦干净屁屁。', 'kliːn ˈbɑː.t̬əm', 'starter',
   'assets/audio/phrases/diaper_change_clean_bottom.mp3'),
  ('diaper_change_all_dry',
   (SELECT id FROM practice_activities WHERE slug = 'diaper_change'),
   2, 'All dry.', '现在都干爽啦。', 'ɔːl draɪ', 'starter',
   'assets/audio/phrases/diaper_change_all_dry.mp3');

-- feeding_time phrases
INSERT INTO practice_phrases (slug, activity_id, step, english, chinese, pronunciation, difficulty, audio_asset) VALUES
  ('feeding_time_open_wide',
   (SELECT id FROM practice_activities WHERE slug = 'feeding_time'),
   1, 'Open wide.', '张大嘴巴。', 'ˈoʊ.pən waɪd', 'starter',
   'assets/audio/phrases/feeding_time_open_wide.mp3'),
  ('feeding_time_yummy_bite',
   (SELECT id FROM practice_activities WHERE slug = 'feeding_time'),
   2, 'Yummy bite.', '来一口香香的。', 'ˈjʌm.i baɪt', 'starter',
   'assets/audio/phrases/feeding_time_yummy_bite.mp3');

-- bedtime phrases
INSERT INTO practice_phrases (slug, activity_id, step, english, chinese, pronunciation, difficulty, audio_asset) VALUES
  ('bedtime_dim_the_lights',
   (SELECT id FROM practice_activities WHERE slug = 'bedtime'),
   1, 'Dim the lights.', '把灯光调暗一点。', 'dɪm ðə laɪts', 'starter',
   'assets/audio/phrases/bedtime_dim_the_lights.mp3'),
  ('bedtime_time_to_sleep',
   (SELECT id FROM practice_activities WHERE slug = 'bedtime'),
   2, 'Time to sleep.', '该睡觉啦。', 'taɪm tə sliːp', 'starter',
   'assets/audio/phrases/bedtime_time_to_sleep.mp3');

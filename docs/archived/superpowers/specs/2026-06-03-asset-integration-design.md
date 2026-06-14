# Asset Integration Design Spec

**Date:** 2026-06-03
**Status:** Approved
**Scope:** Sub-project 1 of 10 (UI Iteration)

## Overview

Extract individual PNG illustrations from the GPT-generated sprite sheet and organize them as Flutter assets for the BabyTalk 2 mobile app.

## Source

- **File:** `C:\Users\zhang\Downloads\gpt\ChatGPT Image 2026年6月3日 08_59_49.png`
- **Type:** Sprite sheet with 80+ hand-drawn illustrations
- **Background:** White
- **Style:** Warm, watercolor-like, matching the "暖纸亲和" design system

## Target Structure

```
mobile/assets/images/
├── plants/
│   ├── tulip_1.png
│   ├── tulip_2.png
│   ├── daisy_1.png
│   ├── leaf_1.png
│   ├── leaf_2.png
│   ├── seed_1.png
│   ├── sprout_1.png
│   ├── sprout_2.png
│   └── ...
├── baby/
│   ├── sleeping.png
│   ├── eating.png
│   ├── bathing.png
│   └── playing.png
├── items/
│   ├── bottle.png
│   ├── diaper.png
│   ├── pacifier.png
│   ├── teddy_bear.png
│   ├── car.png
│   ├── blocks.png
│   ├── book.png
│   ├── ball.png
│   ├── house.png
│   ├── cup.png
│   ├── bowl.png
│   └── bib.png
├── emotions/
│   ├── happy.png
│   ├── neutral.png
│   ├── sad.png
│   ├── surprised.png
│   ├── sleepy.png
│   └── love.png
├── mentor/
│   ├── xiaohe_wave.png
│   ├── xiaohe_think.png
│   ├── xiaohe_smile.png
│   ├── xiaohe_listen.png
│   ├── xiaohe_teach.png
│   ├── xiaohe_pray.png
│   └── xiaohe_hair.png
├── garden/
│   ├── pot_1.png
│   ├── pot_2.png
│   ├── pot_3.png
│   ├── watering_can.png
│   ├── shovel.png
│   ├── fence.png
│   ├── tree.png
│   ├── sign.png
│   └── basket.png
├── decorative/
│   ├── heart.png
│   ├── heart_small.png
│   ├── star.png
│   ├── sparkle.png
│   ├── butterfly.png
│   ├── bird.png
│   ├── music_note.png
│   ├── moon.png
│   ├── sun.png
│   ├── night_sky.png
│   ├── rainbow.png
│   ├── candle.png
│   └── leaves_decorative.png
└── ui/
    ├── chair.png
    ├── blanket.png
    └── jar.png
```

## Extraction Algorithm

### Step 1: Pre-processing
1. Load sprite sheet as RGB image
2. Convert to grayscale
3. Apply Gaussian blur (kernel=3) to reduce noise
4. Threshold (binary) to separate illustrations from white background
5. Invert to get foreground objects as white on black

### Step 2: Contour Detection
1. Find contours using `cv2.findContours(RETR_EXTERNAL, CHAIN_APPROX_SIMPLE)`
2. Filter contours by area (minimum 500px² to ignore specks)
3. Get bounding rectangles for each valid contour

### Step 3: Classification
Classify each bounding box by its position in the sprite sheet:
- **Top 25%:** plants (flowers, leaves, growth stages)
- **25-50%:** baby items and activities
- **50-70%:** emotions and decorative elements
- **70-85%:** mentor character poses
- **85-100%:** garden elements and UI items

### Step 4: Extraction
1. For each contour, expand bounding box by 10px padding
2. Crop from original RGB image
3. Apply alpha mask from thresholded image
4. Save as PNG with transparent background
5. Name: `{category}_{index}.png` (e.g., `plants_01.png`)

### Step 5: Manifest Generation
Generate `asset_manifest.json`:
```json
{
  "version": "1.0",
  "categories": {
    "plants": ["plants_01.png", "plants_02.png", ...],
    "baby": ["baby_01.png", ...],
    "items": ["items_01.png", ...],
    "emotions": ["emotions_01.png", ...],
    "mentor": ["mentor_01.png", ...],
    "garden": ["garden_01.png", ...],
    "decorative": ["decorative_01.png", ...],
    "ui": ["ui_01.png", ...]
  },
  "mapping": {
    "plants_01.png": {"description": "Tulip flower", "usage": "garden, home header"},
    ...
  }
}
```

## Flutter Integration

### pubspec.yaml Update
```yaml
flutter:
  assets:
    - assets/images/plants/
    - assets/images/baby/
    - assets/images/items/
    - assets/images/emotions/
    - assets/images/mentor/
    - assets/images/garden/
    - assets/images/decorative/
    - assets/images/ui/
```

### Asset Access Pattern
```dart
// Example usage
Image.asset('assets/images/plants/tulip_1.png')
Image.asset('assets/images/mentor/xiaohe_wave.png')
```

## Requirements

1. **Extraction script** — Python script using OpenCV + PIL
2. **Minimum quality** — Each extracted PNG must be clean, no partial crops
3. **Transparent background** — All PNGs must have alpha channel
4. **Consistent padding** — 10px padding around each illustration
5. **Naming convention** — `{category}_{two_digit_index}.png`
6. **Manifest** — JSON file mapping categories to files with descriptions
7. **pubspec.yaml** — Updated with image asset directories

## Out of Scope

- Image optimization (compression, resizing) — defer to later
- Sprite sheet rendering in Flutter — using individual PNGs instead
- Animation frames — these are static illustrations
- Vector conversion — keeping as raster PNGs

## Success Criteria

- [ ] All 80+ illustrations extracted as individual PNGs
- [ ] Transparent backgrounds on all files
- [ ] Organized by category in correct directories
- [ ] pubspec.yaml updated and compiles
- [ ] Asset manifest generated
- [ ] No broken or partial crops

## Dependencies

- Python 3.x
- OpenCV (`cv2`)
- Pillow (`PIL`)
- NumPy

## Testing

1. Run extraction script on sprite sheet
2. Verify file count matches expected (80+)
3. Spot-check 10 random files for quality
4. Run `flutter pub get` to verify asset registration
5. Test loading a few assets in Flutter widget tree

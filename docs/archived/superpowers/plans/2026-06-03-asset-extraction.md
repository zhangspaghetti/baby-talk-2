# Asset Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract 80+ individual PNG illustrations from the GPT sprite sheet and organize them as Flutter assets.

**Architecture:** Python script using OpenCV for contour detection and PIL for image cropping. Outputs organized PNGs with transparent backgrounds and a JSON manifest.

**Tech Stack:** Python 3.x, OpenCV (cv2), Pillow (PIL), NumPy

---

## File Structure

```
tool/
├── extract_assets.py          # Main extraction script
├── asset_manifest.json        # Generated manifest (output)
mobile/assets/images/          # Extracted PNGs (output)
├── plants/
├── baby/
├── items/
├── emotions/
├── mentor/
├── garden/
├── decorative/
└── ui/
```

---

### Task 1: Setup Python Environment

**Files:**
- Create: `tool/extract_assets.py` (empty initially)
- Create: `tool/requirements.txt`

- [ ] **Step 1: Create requirements.txt**

```txt
opencv-python>=4.8.0
Pillow>=10.0.0
numpy>=1.24.0
```

- [ ] **Step 2: Install dependencies**

Run: `pip install -r tool/requirements.txt`

- [ ] **Step 3: Create empty extract_assets.py**

```python
#!/usr/bin/env python3
"""Extract individual illustrations from sprite sheet."""

import cv2
import numpy as np
from PIL import Image
import json
import os
from pathlib import Path


def main():
    print("Asset extraction script ready.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Verify script runs**

Run: `python tool/extract_assets.py`
Expected: "Asset extraction script ready."

- [ ] **Step 5: Commit**

```bash
git add tool/extract_assets.py tool/requirements.txt
git commit -m "feat: add asset extraction script skeleton"
```

---

### Task 2: Image Loading and Pre-processing

**Files:**
- Modify: `tool/extract_assets.py`

- [ ] **Step 1: Add image loading function**

```python
SPRITE_SHEET_PATH = r"C:\Users\zhang\Downloads\gpt\ChatGPT Image 2026年6月3日 08_59_49.png"
OUTPUT_DIR = Path("mobile/assets/images")
MIN_CONTOUR_AREA = 500  # Minimum area to consider as valid illustration
PADDING = 10  # Pixels of padding around each crop


def load_sprite_sheet(path: str) -> np.ndarray:
    """Load sprite sheet as RGB numpy array."""
    img = cv2.imread(path)
    if img is None:
        raise FileNotFoundError(f"Could not load image: {path}")
    # Convert BGR to RGB
    return cv2.cvtColor(img, cv2.COLOR_BGR2RGB)


def preprocess(img: np.ndarray) -> np.ndarray:
    """Convert to grayscale and threshold to find foreground."""
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    # Gaussian blur to reduce noise
    blurred = cv2.GaussianBlur(gray, (3, 3), 0)
    # Threshold: white background becomes 0, illustrations become 255
    _, thresh = cv2.threshold(blurred, 240, 255, cv2.THRESH_BINARY_INV)
    return thresh
```

- [ ] **Step 2: Add preprocessing test**

Add to `main()`:

```python
def main():
    print("Loading sprite sheet...")
    img = load_sprite_sheet(SPRITE_SHEET_PATH)
    print(f"Image shape: {img.shape}")
    
    print("Preprocessing...")
    thresh = preprocess(img)
    print(f"Threshold shape: {thresh.shape}")
    print(f"Non-zero pixels: {cv2.countNonZero(thresh)}")
```

- [ ] **Step 3: Verify preprocessing works**

Run: `python tool/extract_assets.py`
Expected: Shows image dimensions and non-zero pixel count (should be significant number)

- [ ] **Step 4: Commit**

```bash
git add tool/extract_assets.py
git commit -m "feat: add image loading and preprocessing"
```

---

### Task 3: Contour Detection and Filtering

**Files:**
- Modify: `tool/extract_assets.py`

- [ ] **Step 1: Add contour detection function**

```python
@dataclass
class ContourInfo:
    """Information about a detected contour."""
    x: int
    y: int
    width: int
    height: int
    area: float
    center_x: int
    center_y: int


def detect_contours(thresh: np.ndarray) -> list[ContourInfo]:
    """Find and filter contours from thresholded image."""
    contours, _ = cv2.findContours(
        thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )
    
    result = []
    for contour in contours:
        area = cv2.contourArea(contour)
        if area < MIN_CONTOUR_AREA:
            continue
        
        x, y, w, h = cv2.boundingRect(contour)
        center_x = x + w // 2
        center_y = y + h // 2
        
        result.append(ContourInfo(
            x=x, y=y, width=w, height=h,
            area=area, center_x=center_x, center_y=center_y
        ))
    
    # Sort by position (top-to-bottom, left-to-right)
    result.sort(key=lambda c: (c.center_y, c.center_x))
    
    return result
```

- [ ] **Step 2: Add dataclass import and test**

Add to imports: `from dataclasses import dataclass`

Update `main()`:

```python
def main():
    print("Loading sprite sheet...")
    img = load_sprite_sheet(SPRITE_SHEET_PATH)
    
    print("Preprocessing...")
    thresh = preprocess(img)
    
    print("Detecting contours...")
    contours = detect_contours(thresh)
    print(f"Found {len(contours)} contours")
    
    # Show first 5 contours
    for i, c in enumerate(contours[:5]):
        print(f"  {i}: pos=({c.x},{c.y}) size={c.width}x{c.height} area={c.area}")
```

- [ ] **Step 3: Verify contour detection**

Run: `python tool/extract_assets.py`
Expected: Found 80+ contours, each with reasonable size and position

- [ ] **Step 4: Commit**

```bash
git add tool/extract_assets.py
git commit -m "feat: add contour detection and filtering"
```

---

### Task 4: Category Classification

**Files:**
- Modify: `tool/extract_assets.py`

- [ ] **Step 1: Add classification function**

```python
CATEGORIES = {
    "plants": (0.0, 0.25),      # Top 25%
    "baby": (0.25, 0.45),       # 25-45%
    "items": (0.45, 0.60),      # 45-60%
    "emotions": (0.60, 0.70),   # 60-70%
    "mentor": (0.70, 0.85),     # 70-85%
    "garden": (0.85, 0.95),     # 85-95%
    "decorative": (0.95, 1.0),  # 95-100%
}


def classify_contour(contour: ContourInfo, image_height: int) -> str:
    """Classify contour into category based on vertical position."""
    relative_y = contour.center_y / image_height
    
    for category, (y_min, y_max) in CATEGORIES.items():
        if y_min <= relative_y < y_max:
            return category
    
    return "ui"  # Default category for unrecognized
```

- [ ] **Step 2: Add classification test**

Update `main()`:

```python
def main():
    print("Loading sprite sheet...")
    img = load_sprite_sheet(SPRITE_SHEET_PATH)
    image_height = img.shape[0]
    
    print("Preprocessing...")
    thresh = preprocess(img)
    
    print("Detecting contours...")
    contours = detect_contours(thresh)
    print(f"Found {len(contours)} contours")
    
    print("Classifying contours...")
    categorized = {}
    for c in contours:
        category = classify_contour(c, image_height)
        categorized.setdefault(category, []).append(c)
    
    for category, items in categorized.items():
        print(f"  {category}: {len(items)} items")
```

- [ ] **Step 3: Verify classification**

Run: `python tool/extract_assets.py`
Expected: Each category has reasonable number of items (plants: 15+, baby: 5+, items: 10+, etc.)

- [ ] **Step 4: Commit**

```bash
git add tool/extract_assets.py
git commit -m "feat: add category classification"
```

---

### Task 5: Image Cropping and Saving

**Files:**
- Modify: `tool/extract_assets.py`

- [ ] **Step 1: Add cropping function**

```python
def crop_and_save(
    img: np.ndarray,
    thresh: np.ndarray,
    contour: ContourInfo,
    output_path: Path,
) -> bool:
    """Crop illustration from image and save with transparent background."""
    # Calculate crop bounds with padding
    x1 = max(0, contour.x - PADDING)
    y1 = max(0, contour.y - PADDING)
    x2 = min(img.shape[1], contour.x + contour.width + PADDING)
    y2 = min(img.shape[0], contour.y + contour.height + PADDING)
    
    # Crop RGB image
    cropped_rgb = img[y1:y2, x1:x2]
    
    # Crop threshold for alpha mask
    cropped_thresh = thresh[y1:y2, x1:x2]
    
    # Create RGBA image
    h, w = cropped_rgb.shape[:2]
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = cropped_rgb
    rgba[:, :, 3] = cropped_thresh  # Alpha channel from threshold
    
    # Save as PNG
    output_path.parent.mkdir(parents=True, exist_ok=True)
    pil_img = Image.fromarray(rgba, 'RGBA')
    pil_img.save(output_path, 'PNG')
    
    return True
```

- [ ] **Step 2: Add saving logic to main**

```python
def main():
    print("Loading sprite sheet...")
    img = load_sprite_sheet(SPRITE_SHEET_PATH)
    thresh = preprocess(img)
    contours = detect_contours(thresh)
    
    print("Classifying and saving...")
    categorized = {}
    for c in contours:
        category = classify_contour(c, img.shape[0])
        categorized.setdefault(category, []).append(c)
    
    total_saved = 0
    for category, items in categorized.items():
        category_dir = OUTPUT_DIR / category
        for i, contour in enumerate(items):
            filename = f"{category}_{i+1:02d}.png"
            output_path = category_dir / filename
            
            if crop_and_save(img, thresh, contour, output_path):
                total_saved += 1
                print(f"  Saved: {category}/{filename}")
    
    print(f"\nTotal saved: {total_saved} assets")
```

- [ ] **Step 3: Run extraction**

Run: `python tool/extract_assets.py`
Expected: 80+ files saved across category directories

- [ ] **Step 4: Verify output**

Check: `ls mobile/assets/images/*/` should show PNG files in each category

- [ ] **Step 5: Commit**

```bash
git add tool/extract_assets.py mobile/assets/images/
git commit -m "feat: extract illustrations from sprite sheet"
```

---

### Task 6: Asset Manifest Generation

**Files:**
- Modify: `tool/extract_assets.py`

- [ ] **Step 1: Add manifest generation function**

```python
def generate_manifest(categorized: dict[str, list]) -> dict:
    """Generate JSON manifest of extracted assets."""
    manifest = {
        "version": "1.0",
        "source": "ChatGPT Image 2026年6月3日 08_59_49.png",
        "categories": {},
        "mapping": {},
    }
    
    for category, items in categorized.items():
        files = []
        for i in range(len(items)):
            filename = f"{category}_{i+1:02d}.png"
            files.append(filename)
            
            # Add to mapping with description placeholder
            manifest["mapping"][filename] = {
                "category": category,
                "index": i + 1,
                "description": f"{category} illustration {i+1}",
            }
        
        manifest["categories"][category] = files
    
    return manifest


def save_manifest(manifest: dict, output_path: Path):
    """Save manifest to JSON file."""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
```

- [ ] **Step 2: Add manifest generation to main**

```python
def main():
    # ... existing code ...
    
    print("Generating manifest...")
    manifest = generate_manifest(categorized)
    manifest_path = OUTPUT_DIR / "asset_manifest.json"
    save_manifest(manifest, manifest_path)
    print(f"Manifest saved to: {manifest_path}")
```

- [ ] **Step 3: Verify manifest**

Run: `python tool/extract_assets.py`
Check: `cat mobile/assets/images/asset_manifest.json` shows proper JSON with all categories

- [ ] **Step 4: Commit**

```bash
git add tool/extract_assets.py mobile/assets/images/asset_manifest.json
git commit -m "feat: generate asset manifest"
```

---

### Task 7: Update pubspec.yaml

**Files:**
- Modify: `mobile/pubspec.yaml:64-74`

- [ ] **Step 1: Add image asset directories**

```yaml
  assets:
    - assets/content/seed_content.json
    - assets/audio/phrases/bath_time_warm_water.mp3
    - assets/audio/phrases/bath_time_splash_splash.mp3
    - assets/audio/phrases/bath_time_all_clean.mp3
    - assets/audio/phrases/diaper_change_clean_bottom.mp3
    - assets/audio/phrases/diaper_change_all_dry.mp3
    - assets/audio/phrases/feeding_time_open_wide.mp3
    - assets/audio/phrases/feeding_time_yummy_bite.mp3
    - assets/audio/phrases/bedtime_dim_the_lights.mp3
    - assets/audio/phrases/bedtime_time_to_sleep.mp3
    - assets/images/plants/
    - assets/images/baby/
    - assets/images/items/
    - assets/images/emotions/
    - assets/images/mentor/
    - assets/images/garden/
    - assets/images/decorative/
    - assets/images/ui/
```

- [ ] **Step 2: Verify Flutter recognizes assets**

Run: `cd mobile && flutter pub get`
Expected: No errors about missing assets

- [ ] **Step 3: Test loading an asset in Flutter**

Create temporary test widget or use existing screen:

```dart
// Temporary test - add to any screen
Image.asset(
  'assets/images/mentor/mentor_01.png',
  width: 100,
  height: 100,
)
```

- [ ] **Step 4: Commit**

```bash
git add mobile/pubspec.yaml
git commit -m "feat: register image assets in pubspec.yaml"
```

---

### Task 8: Quality Verification

**Files:**
- None (verification only)

- [ ] **Step 1: Count extracted files**

Run: `find mobile/assets/images -name "*.png" | wc -l`
Expected: 80+

- [ ] **Step 2: Check for empty files**

Run: `find mobile/assets/images -name "*.png" -size 0`
Expected: No output (no empty files)

- [ ] **Step 3: Verify transparent backgrounds**

Spot-check 5 random files by opening in image viewer — backgrounds should be transparent

- [ ] **Step 4: Run Flutter build**

Run: `cd mobile && flutter build apk --debug`
Expected: Build succeeds without asset errors

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete asset extraction from GPT sprite sheet"
```

---

## Summary

| Task | Description | Files Changed |
|------|-------------|---------------|
| 1 | Setup Python environment | `tool/extract_assets.py`, `tool/requirements.txt` |
| 2 | Image loading and preprocessing | `tool/extract_assets.py` |
| 3 | Contour detection | `tool/extract_assets.py` |
| 4 | Category classification | `tool/extract_assets.py` |
| 5 | Image cropping and saving | `tool/extract_assets.py`, `mobile/assets/images/` |
| 6 | Manifest generation | `tool/extract_assets.py`, `asset_manifest.json` |
| 7 | Update pubspec.yaml | `mobile/pubspec.yaml` |
| 8 | Quality verification | None |

**Total estimated time:** 30-45 minutes

#!/usr/bin/env python3
"""Extract individual illustrations from sprite sheet."""

import cv2
import numpy as np
from PIL import Image
import json
import os
from pathlib import Path
from dataclasses import dataclass

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


def classify_contours(contours: list[ContourInfo], image_height: int) -> dict[str, list[ContourInfo]]:
    """Classify contours into categories based on vertical position.
    
    Sprite sheet layout (top to bottom):
    - Row 1 (0-25%): Plants, flowers, leaves, growth stages
    - Row 2 (25-45%): Seeds, sprouts, baby items
    - Row 3 (45-65%): Baby activities, toys
    - Row 4 (65-80%): Emotions, decorative elements
    - Row 5 (80-95%): Mentor character poses
    - Row 6 (95-100%): Garden elements
    """
    categories = {
        'plants': [],
        'baby_items': [],
        'activities': [],
        'emotions': [],
        'mentor': [],
        'garden': [],
    }
    
    for c in contours:
        ratio = c.center_y / image_height
        if ratio < 0.25:
            categories['plants'].append(c)
        elif ratio < 0.45:
            categories['baby_items'].append(c)
        elif ratio < 0.65:
            categories['activities'].append(c)
        elif ratio < 0.80:
            categories['emotions'].append(c)
        elif ratio < 0.95:
            categories['mentor'].append(c)
        else:
            categories['garden'].append(c)
    
    return categories


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


def generate_manifest(categories: dict[str, list[ContourInfo]]) -> dict:
    """Generate JSON manifest of extracted assets."""
    manifest = {
        "version": "1.0",
        "source": "ChatGPT Image 2026年6月3日 08_59_49.png",
        "categories": {},
        "total_assets": 0,
    }
    
    for category, contours_list in categories.items():
        files = []
        for i in range(len(contours_list)):
            filename = f"{category}_{i+1:02d}.png"
            files.append(filename)
        
        manifest["categories"][category] = {
            "count": len(files),
            "files": files,
        }
        manifest["total_assets"] += len(files)
    
    return manifest


def save_manifest(manifest: dict, output_path: Path) -> None:
    """Save manifest to JSON file."""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"Manifest saved to: {output_path}")


def main():
    print("Loading sprite sheet...")
    img = load_sprite_sheet(SPRITE_SHEET_PATH)
    
    print("Preprocessing...")
    thresh = preprocess(img)
    
    print("Detecting contours...")
    contours = detect_contours(thresh)
    print(f"Found {len(contours)} contours")
    
    # Classify contours by position
    categories = classify_contours(contours, img.shape[0])
    print("\nCategory classification:")
    for cat, items in categories.items():
        print(f'  {cat}: {len(items)} items')
    
    # Crop and save all contours
    saved_count = 0
    for category, contours_list in categories.items():
        category_dir = OUTPUT_DIR / category
        category_dir.mkdir(parents=True, exist_ok=True)
        
        for i, contour in enumerate(contours_list):
            filename = f"{category}_{i+1:02d}.png"
            output_path = category_dir / filename
            
            if crop_and_save(img, thresh, contour, output_path):
                saved_count += 1
                print(f"Saved: {category}/{filename}")

    print(f"\nTotal saved: {saved_count} assets")
    
    # Generate and save manifest
    manifest = generate_manifest(categories)
    manifest_path = OUTPUT_DIR / "manifest.json"
    save_manifest(manifest, manifest_path)


if __name__ == "__main__":
    main()

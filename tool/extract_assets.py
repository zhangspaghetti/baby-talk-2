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


if __name__ == "__main__":
    main()

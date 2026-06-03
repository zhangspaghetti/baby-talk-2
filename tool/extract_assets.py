#!/usr/bin/env python3
"""Extract individual illustrations from sprite sheet."""

import cv2
import numpy as np
from PIL import Image
import json
import os
from pathlib import Path

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


def main():
    print("Loading sprite sheet...")
    img = load_sprite_sheet(SPRITE_SHEET_PATH)
    print(f"Image shape: {img.shape}")
    
    print("Preprocessing...")
    thresh = preprocess(img)
    print(f"Threshold shape: {thresh.shape}")
    print(f"Non-zero pixels: {cv2.countNonZero(thresh)}")


if __name__ == "__main__":
    main()

import cv2
import numpy as np
import os
import sys

# Usage: python extract_picture.py <scene_images_dir> <scene_picture_dir>
if len(sys.argv) != 3:
    print("Usage: python extract_picture.py <scene_images_dir> <scene_picture_dir>")
    sys.exit(2)

IMG_DIR = sys.argv[1]
OUT_DIR = sys.argv[2]
os.makedirs(OUT_DIR, exist_ok=True)

for fname in os.listdir(IMG_DIR):
    if not fname.lower().endswith('.jpg'):
        continue
    img_path = os.path.join(IMG_DIR, fname)
    img = cv2.imread(img_path)
    if img is None:
        print(f"Failed to read {img_path}")
        continue

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # Threshold to remove white background
    _, thresh = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)

    # Find contours
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        print(f"No picture detected in {img_path}")
        continue

    # Find largest contour (likely the picture)
    largest = max(contours, key=cv2.contourArea)
    x, y, w, h = cv2.boundingRect(largest)
    # Ignore very small regions
    if w*h < 10000:
        print(f"Detected region too small in {img_path}")
        continue

    # Crop and save
    cropped = img[y:y+h, x:x+w]
    out_path = os.path.join(OUT_DIR, fname)
    cv2.imwrite(out_path, cropped)
    print(f"Saved cropped picture to {out_path}")

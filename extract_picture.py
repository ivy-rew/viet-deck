import cv2
import os
import sys

# Usage: python extract_picture.py <scene_images_dir> <scene_picture_dir>
if len(sys.argv) != 3:
    print("Usage: python extract_picture.py <scene_images_dir> <scene_picture_dir>")
    sys.exit(2)

IMG_DIR = sys.argv[1]
OUT_DIR = sys.argv[2]
os.makedirs(OUT_DIR, exist_ok=True)


def detect_picture_regions(img):
    """Return bounding boxes for likely picture regions as (x, y, w, h)."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Keep non-white pixels. Most slide background is near white.
    _, mask = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)

    # Remove tiny OCR/text noise while keeping larger blocks.
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return []

    img_h, img_w = gray.shape
    img_area = img_w * img_h
    min_area = int(img_area * 0.01)  # at least 1% of slide area
    min_w = int(img_w * 0.08)
    min_h = int(img_h * 0.08)

    boxes = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        area = w * h
        if area < min_area:
            continue
        if w < min_w or h < min_h:
            continue
        boxes.append((x, y, w, h))

    boxes.sort(key=lambda b: (b[1], b[0]))
    return boxes

for fname in os.listdir(IMG_DIR):
    if not fname.lower().endswith('.jpg'):
        continue
    img_path = os.path.join(IMG_DIR, fname)
    img = cv2.imread(img_path)
    if img is None:
        print(f"Failed to read {img_path}")
        continue

    boxes = detect_picture_regions(img)
    if not boxes:
        print(f"No picture detected in {img_path}")
        continue

    base, ext = os.path.splitext(fname)
    for idx, (x, y, w, h) in enumerate(boxes, start=1):
        cropped = img[y:y + h, x:x + w]
        out_name = f"{base}_{idx:02d}{ext}"
        out_path = os.path.join(OUT_DIR, out_name)
        cv2.imwrite(out_path, cropped)
        print(f"Saved cropped picture to {out_path}")

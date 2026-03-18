#!/usr/bin/env bash
set -euo pipefail

# Optional install function for tesseract language data
install_tesseract_langs() {
  echo "Installing tesseract Vietnamese and English language data..."
  sudo apt install -y tesseract-ocr-vie tesseract-ocr-eng
  echo "Installing OpenCV for Python..."
  sudo "apt install -y python3-opencv" || pip install opencv-python
  #pip install opencv-python
  echo "Installation complete."
}

# Usage: ./extract_scene_assets.sh <slides_folder>
if [ $# -ne 1 ]; then
  echo "Usage: $0 <slides_folder>"
  exit 2
fi

SLIDES_DIR="$1"
IMG_DIR="${SLIDES_DIR}/scene_images"
AUDIO_DIR="${SLIDES_DIR}/scene_audio"
mkdir -p "$IMG_DIR" "$AUDIO_DIR"

for SLIDE in "$SLIDES_DIR"/*.mp4; do
  BASENAME=$(basename "$SLIDE" .mp4)
  # Extract image after 2 seconds
  ffmpeg -hide_banner -y -ss 2 -i "$SLIDE" -frames:v 1 -q:v 2 "$IMG_DIR/${BASENAME}.jpg"
  # Extract audio as is
  ffmpeg -hide_banner -y -i "$SLIDE" -vn -acodec copy "$AUDIO_DIR/${BASENAME}.m4a"
  # Preprocess image for better OCR
  mkdir -p "$SLIDES_DIR/scene_text"
  mkdir -p "$SLIDES_DIR/scene_bw"
  convert "$IMG_DIR/${BASENAME}.jpg" -threshold 80% "$SLIDES_DIR/scene_bw/${BASENAME}.jpg"
  # Use the BW image for OCR
  BW_IMG="$SLIDES_DIR/scene_bw/${BASENAME}.jpg"
  tesseract -l vie+eng --psm 4 "$BW_IMG" "$SLIDES_DIR/scene_text/${BASENAME}" > /dev/null 2>&1

  # Use OpenCV script to crop main picture from each scene image
  SCENE_PICTURE_DIR="$SLIDES_DIR/scene_picture"
  python3 "$(dirname "$0")/extract_picture.py" "$IMG_DIR" "$SCENE_PICTURE_DIR"

  # Detect if image contains a picture (not just text/background)
  mkdir -p "$SLIDES_DIR/scene_picture"
  # Use ImageMagick to check for color variance (simple heuristic for picture detection)
  COLOR_STD=$(convert "$IMG_DIR/${BASENAME}.jpg" -format "%[standard-deviation]" info:)
  # Threshold: if stddev > 0.01, likely contains a picture
  if (( $(echo "$COLOR_STD > 0.01" | bc -l) )); then
    # Crop white background using ImageMagick
    convert "$IMG_DIR/${BASENAME}.jpg" -fuzz 10% -trim +repage "$SLIDES_DIR/scene_picture/${BASENAME}.jpg"
    echo "Detected and cropped picture in $IMG_DIR/${BASENAME}.jpg"
  fi
done

echo "Extraction complete. Images in $IMG_DIR, audio in $AUDIO_DIR."

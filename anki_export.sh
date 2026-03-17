#!/usr/bin/env bash
set -euo pipefail

# Usage: ./anki_export.sh <slides_folder> <output_csv>
if [ $# -ne 2 ]; then
  echo "Usage: $0 <slides_folder> <output_csv>"
  exit 2
fi

SLIDES_DIR="$1"
OUT_CSV="$2"
TEXT_DIR="$SLIDES_DIR/scene_text"
AUDIO_DIR="$SLIDES_DIR/scene_audio"
PIC_DIR="$SLIDES_DIR/scene_picture"

# Header for Anki CSV: Front,Back,Audio,Picture
# (You may adjust fields as needed for your Anki template)
echo "Front,Back,Audio,Picture" > "$OUT_CSV"

for txtfile in "$TEXT_DIR"/*.txt; do
  BASENAME=$(basename "$txtfile" .txt)
  AUDIO="$AUDIO_DIR/${BASENAME}.m4a"
  PIC="$PIC_DIR/${BASENAME}.jpg"
  FRONT=$(cat "$txtfile" | tr '\n' ' ' | sed 's/  */ /g')
  BACK=""
  # Only add card if all assets exist
  if [[ -f "$AUDIO" && -f "$PIC" ]]; then
    echo "$FRONT,$BACK,[sound:${BASENAME}.m4a],[img:${BASENAME}.jpg]" >> "$OUT_CSV"
  fi
done

echo "Anki CSV created at $OUT_CSV. Copy audio and images to Anki's media folder."

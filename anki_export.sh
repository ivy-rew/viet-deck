#!/usr/bin/env bash
set -euo pipefail

# Usage: ./anki_export.sh <slides_folder>
if [ $# -ne 1 ]; then
  echo "Usage: $0 <slides_folder>"
  exit 2
fi

SLIDES_DIR="$1"
ANKI_DIR="${SLIDES_DIR}_anki"
MEDIA_DIR="$ANKI_DIR/media"
CSV_FILE="$ANKI_DIR/anki_cards.csv"
TEXT_DIR="$SLIDES_DIR/scene_text"
AUDIO_DIR="$SLIDES_DIR/scene_audio"
PIC_DIR="$SLIDES_DIR/scene_picture"

mkdir -p "$ANKI_DIR" "$MEDIA_DIR"

# Header for Anki CSV: Front,Back,Audio,Picture
echo "Front,Back,Audio,Picture" > "$CSV_FILE"

for txtfile in "$TEXT_DIR"/*.txt; do
  BASENAME=$(basename "$txtfile" .txt)
  AUDIO_SRC="$AUDIO_DIR/${BASENAME}.m4a"
  PIC_SRC="$PIC_DIR/${BASENAME}.jpg"
  AUDIO_DST="$MEDIA_DIR/${BASENAME}.m4a"
  PIC_DST="$MEDIA_DIR/${BASENAME}.jpg"
  FRONT=$(cat "$txtfile" | tr '\n' ' ' | sed 's/  */ /g')
  BACK=""
  # Only add card if all assets exist
  if [[ -f "$AUDIO_SRC" && -f "$PIC_SRC" ]]; then
    cp "$AUDIO_SRC" "$AUDIO_DST"
    cp "$PIC_SRC" "$PIC_DST"
    echo "$FRONT,$BACK,[sound:${BASENAME}.m4a],[img:${BASENAME}.jpg]" >> "$CSV_FILE"
  fi
done

echo "Anki CSV and media created in $ANKI_DIR."

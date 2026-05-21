#!/usr/bin/env bash

set -euo pipefail

# Usage:
#   ./tts.sh "Rất vui được gặp bạn"
#   ./tts.sh "Rất vui được gặp bạn" Vinh
#   ./tts.sh "Rất vui được gặp bạn" Vinh tts-custom-name

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 \"<text>\" [voice_id] [output_file]" >&2
	exit 1
fi

TEXT="$1"
VOICE_ID="${2:-Vinh}"
OUTPUT_FILE="${3:-}"

# pre-condition: ../VietNeu-tts runs > `uv run vieneu-stream`
BASE_URL="http://localhost:8001/stream"

urlencode() {
	local raw="$1"
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$raw" | jq -sRr @uri
		return
	fi
	echo "Error: URL encoder not found. Install jq or perl (URI::Escape)." >&2
	exit 1
}

simplify_name() {
	local raw="$1"
	local ascii
	local simplified
	ascii="$(printf '%s' "$raw" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$raw")"
	simplified="$(printf '%s' "$ascii" | sed -E 's/[[:space:]]+/-/g; s/^-+//; s/-+$//')"
	echo "tts-${simplified}"
}

mp3_encode() {
    sound=$1
    ffmpeg -i "$sound" -c:a libmp3lame -b:a 64k "${sound%.*}.mp3"
    echo "${sound%.*}.mp3"
}

# URL-encode Unicode text so raw Vietnamese characters are handled correctly.
ENCODED_TEXT="$(urlencode "$TEXT")"
ENCODED_VOICE="$(urlencode "$VOICE_ID")"

if [[ -z "$OUTPUT_FILE" ]]; then
	OUTPUT_FILE="$(simplify_name "$TEXT").wav"
fi

TTS_URL="${BASE_URL}?text=${ENCODED_TEXT}&voice_id=${ENCODED_VOICE}"
echo "fetching: $TTS_URL"
curl --fail --location --progress-bar \
	--output "$OUTPUT_FILE" \
	"${TTS_URL}"
echo "Saved: $OUTPUT_FILE"
sleep 1
MP3_FILE="$(mp3_encode $OUTPUT_FILE)"
rm $OUTPUT_FILE
echo "Converted: $MP3_FILE"

read -p "Copy $MP3_FILE to ANKI media? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	cp -v "$MP3_FILE" collection.media/
    echo "ready for usage in Anki field:"
    echo "[sound:$MP3_FILE]"
fi




#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <slides_folder>"
  exit 2
fi

slides="$1"
text_dir="${slides}/scene_text"
audio_dir="${slides}/scene_audio"
picture_dir="${slides}/scene_picture"
out_csv="$PWD/${slides}.csv"

if [ ! -d "$text_dir" ]; then
  echo "Missing directory: $text_dir"
  exit 2
fi

tmp_csv="$(mktemp "${out_csv}.tmp.XXXXXX")"
cleanup() {
  rm -f "$tmp_csv"
}
trap cleanup EXIT

prompt="$(cat <<EOF
Read all txt files in ${text_dir}.
Fix Vietnamese character issues/spelling mistakes.
Return only CSV rows (no markdown, no code fences, no explanations) with this format:
word_vn;word_en;synonyms (optional);usage1_vn;usage1_en;usage2_vn;usage2_en;audio;picture;

Rules:
- Audio is the corresponding .mp3 file in ${audio_dir}
- Picture is the corresponding .jpg file in ${picture_dir}
- If multiple picture crops exist (basename_01.jpg, basename_02.jpg), use basename_01.jpg
- Audio format must be [sound:filename.mp3]
- Picture field must include filename and extension (.jpg)
- Never output picture without extension (invalid: basename_01, valid: basename_01.jpg)
- Keep audio and picture as plain filenames only (no paths)
- Omit header row
EOF
)"

echo "Generating CSV for ${slides}..."

if ! copilot -s -p "${prompt}" --model gpt-4.1 > "$tmp_csv"; then
  echo "Copilot command failed. CSV was not written."
  exit 1
fi

# Remove accidental markdown fences if they appear.
sed -i '/^```/d' "$tmp_csv"

# Keep only CSV rows: expect at least 8 semicolons (9 fields including trailing ';').
filtered_csv="$(mktemp "${out_csv}.filtered.XXXXXX")"
awk -F';' 'NF >= 9' "$tmp_csv" > "$filtered_csv"
mv "$filtered_csv" "$tmp_csv"

if ! grep -q ';' "$tmp_csv"; then
  echo "No CSV-like rows were produced. CSV was not written."
  exit 1
fi

mv "$tmp_csv" "$out_csv"
sync "$out_csv" 2>/dev/null || true
echo "CSV written safely to: $out_csv"

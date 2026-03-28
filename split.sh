#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 input.mp4"
  exit 2
fi

INPUT="$1"
BASENAME="$(basename "$INPUT" | sed 's/\.[^.]*$//')"
WORKDIR="./${BASENAME}_slides_tmp"

# Scene-detection tuning knobs (override with environment variables)
SCENE_THRESH="${SCENE_THRESH:-0.009}"
ANALYZE_FPS="${ANALYZE_FPS:-2}"
ANALYZE_WIDTH="${ANALYZE_WIDTH:-960}"
MIN_GAP="${MIN_GAP:-0.5}"
ANALYZE_GRAY="${ANALYZE_GRAY:-1}"

if ! [ -d "$WORKDIR" ]; then
  mkdir -p "$WORKDIR"
  scene_log="$WORKDIR/scene_log.txt"
  times_file="$WORKDIR/times.txt"

  # 1) Get duration in seconds (float)
  DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT" | sed 's/\./,/g' )
  # sanitize: remove spaces/newlines, ensure dot decimal
  DURATION=$(echo "$DURATION" | tr -d '[:space:]' | awk '{printf "%.3f", $1}' | sed 's/,/./g')
  echo "Video duration: $DURATION seconds"

  # 2) Run scene detection on preprocessed frames.
  #    Use a minimum gap in-filter so one transition does not emit many close cuts.
  COLOR_FILTER=""
  if [ "$ANALYZE_GRAY" = "1" ]; then
    COLOR_FILTER=",format=gray"
  fi
  DETECT_FILTER="fps=${ANALYZE_FPS},scale=${ANALYZE_WIDTH}:-1:flags=fast_bilinear${COLOR_FILTER},select='isnan(prev_selected_t)+gte(t-prev_selected_t,${MIN_GAP})*gt(scene,${SCENE_THRESH})',showinfo"
  echo "Detect config: thresh=${SCENE_THRESH} fps=${ANALYZE_FPS} width=${ANALYZE_WIDTH} min_gap=${MIN_GAP} gray=${ANALYZE_GRAY}"
  ffmpeg -hide_banner -i "$INPUT" -vf "$DETECT_FILTER" -f null - 2> "$scene_log"

  # 3) Parse pts_time lines into sorted list and produce segment boundaries
  # Collect detected times
  grep -oP "pts_time:\K[0-9]+\.[0-9]+" "$scene_log" | sed 's/\./,/g' | awk '{printf "%.3f\n",$1}' | sort -n > "$times_file"

  # Always start at 0.000
  TMP_TIMES="$WORKDIR/_all_times.txt"
  echo "0.000" > "$TMP_TIMES"
  cat "$times_file" >> "$TMP_TIMES"
  # Ensure last boundary is video duration (rounded to 3 decimals)
  echo "$DURATION" | awk '{printf "%.3f\n", $1}' >> "$TMP_TIMES"

  # Remove possible duplicate/very-close timestamps (merge if closer than MIN_GAP)
  awk -v min_gap="$MIN_GAP" 'BEGIN{prev=-1}
  { if(prev<0){ prev=$1; printf("%.3f\n",$1) }
    else if(($1-prev) >= min_gap){ printf("%.3f\n",prev); prev=$1 }
    else { prev=$1 }
  }
  END{ if(prev>=0) printf("%.3f\n",prev) }' "$TMP_TIMES" > "$WORKDIR/_clean_times.txt"
else
  echo "Skipping scene detect, re-using _tmp"
fi


# Build pairs (start,end)
mapfile -t BOUNDS < "$WORKDIR/_clean_times.txt"
N=${#BOUNDS[@]}
if [ "$N" -lt 2 ]; then
  echo "No scene changes detected; producing single file."
  exit 1
fi


mkdir -p "${BASENAME}_slides"

SKIP_DURATION="${SKIP_DURATION:-6.0}"
for i in $(seq 0 $((N-2))); do
  # Sanitize times: convert comma to dot
  START=$(echo "${BOUNDS[$i]}" | sed 's/,/./g')
  END=$(echo "${BOUNDS[$i+1]}" | sed 's/,/./g')
  # Compute duration = END - START
  DUR=$(awk -v a="$START" -v b="$END" 'BEGIN{printf "%.3f", b-a}')
  DUR=$(echo "$DUR" | sed 's/,/./g')
  if (( $(echo "$DUR >= ${SKIP_DURATION}" | bc -l) )); then
    idx=$(printf "%03d" $((i+1)))
    OUT="${BASENAME}_slides/${BASENAME}_slide_${idx}.mp4"
    # Use re-encoding for frame-accurate cuts and to avoid timestamp issues
    ffmpeg -hide_banner -y -ss "$START" -i "$INPUT" -t "$DUR" -c:v libx264 -preset veryfast -crf 20 -c:a aac -b:a 128k "$OUT"
    echo "Wrote $OUT (start=$START duration=$DUR)"
  else
    echo "Skipped segment (start=$START duration=$DUR < ${SKIP_DURATION}s)"
  fi
done

# Cleanup (optional)
#rm -rf "$WORKDIR"

echo "Done: splitted into $((N-1)) slides in ./${BASENAME}_slides/"

#!/usr/bin/env bash
set -euo pipefail

# Split audio file at silence pauses, trimming trailing beep from each segment.

export LC_ALL=C

usage() {
  echo "Usage: $0 input_audio [output_dir] [output_base_name]" >&2
  exit 2
}

silencedetect() {
  local input_path=$1
  local noise=${2:--30dB}
  local detect_duration=${3:-1.0}
  local prefix_filter=${4:-}
  local af
  af="${prefix_filter}silencedetect=noise=${noise}:d=${detect_duration}"

  ffmpeg -i "$input_path" -af "$af" -f null - 2>&1 | awk '
    /silence_start:/ {
      val=$0
      sub(/.*silence_start: /, "", val)
      sub(/[[:space:]].*$/, "", val)
      starts[++sidx]=val
    }
    /silence_end:/ {
      val=$0
      sub(/.*silence_end: /, "", val)
      sub(/[[:space:]].*$/, "", val)
      ends[++eidx]=val
    }
    END {
      n=(sidx<eidx ? sidx : eidx)
      for (i=1; i<=n; i++) {
        printf "%.6f %.6f\n", starts[i], ends[i]
      }
    }
  '
}

audio_duration() {
  local input_path=$1
  ffprobe -i "$input_path" -show_entries format=duration -v quiet -of csv=p=0 | tr -d '[:space:]'
}

main() {
  [[ $# -lt 1 || $# -gt 3 ]] && usage

  local input_file=$1
  local output_dir=${2:-split}
  local output_base_name=${3:-}

  if [[ ! -f "$input_file" ]]; then
    echo "Input file not found: $input_file" >&2
    exit 1
  fi

  mkdir -p "$output_dir"

  mapfile -t pauses < <(silencedetect "$input_file" "-30dB" "1.0")

  local total
  total=$(audio_duration "$input_file")

  local -a segment_starts=()
  local -a segment_ends=()

  if [[ ${#pauses[@]} -gt 0 ]]; then
    local first_start
    first_start=$(awk '{print $1}' <<<"${pauses[0]}")
    segment_starts+=("0.0")
    segment_ends+=("$first_start")

    local i
    for ((i=0; i<${#pauses[@]}-1; i++)); do
      local cur_end next_start
      cur_end=$(awk '{print $2}' <<<"${pauses[$i]}")
      next_start=$(awk '{print $1}' <<<"${pauses[$((i+1))]}")
      segment_starts+=("$cur_end")
      segment_ends+=("$next_start")
    done

    local last_end
    last_end=$(awk '{print $2}' <<<"${pauses[$((${#pauses[@]}-1))]}")
    segment_starts+=("$last_end")
    segment_ends+=("$total")
  fi

  local -a final_starts=()
  local -a final_ends=()

  local idx
  for ((idx=0; idx<${#segment_starts[@]}; idx++)); do
    local seg_start seg_end seg_len
    seg_start=${segment_starts[$idx]}
    seg_end=${segment_ends[$idx]}
    seg_len=$(awk -v s="$seg_start" -v e="$seg_end" 'BEGIN { printf "%.6f", (e-s) }')

    if awk -v l="$seg_len" 'BEGIN { exit !(l > 0.15) }'; then
      final_starts+=("$seg_start")
      final_ends+=("$seg_end")
    fi
  done

  echo "Splitting into ${#final_starts[@]} segments -> ${output_dir}/"

  local base
  if [[ -n "$output_base_name" ]]; then
    base=$output_base_name
  else
    base=$(basename "$input_file")
    base=${base%.*}
  fi

  for ((idx=0; idx<${#final_starts[@]}; idx++)); do
    local s e out
    s=${final_starts[$idx]}
    e=${final_ends[$idx]}
    out=$(printf "%s/%s_%03d.mp3" "$output_dir" "$base" "$((idx+1))")

    ffmpeg -y -i "$input_file" -ss "$s" -to "$e" -c copy "$out" >/dev/null 2>&1

    awk -v i="$((idx+1))" -v s="$s" -v e="$e" -v out="$out" '
      BEGIN {
        n=split(out, p, "/")
        dur=e-s
        printf "  %3d: %8.3fs - %8.3fs  (%.2fs)  -> %s\n", i, s, e, dur, p[n]
      }
    '
  done
}

main "$@"

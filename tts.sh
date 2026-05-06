#!/usr/bin/env bash

set -euo pipefail

# Usage:
#   ./tts.sh "Rất vui được gặp bạn"
#   ./tts.sh "Rất vui được gặp bạn" Vinh

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 \"<text>\" [voice_id]" >&2
	exit 1
fi

TEXT="$1"
VOICE_ID="${2:-Vinh}"
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

# URL-encode Unicode text so raw Vietnamese characters are handled correctly.
ENCODED_TEXT="$(urlencode "$TEXT")"
ENCODED_VOICE="$(urlencode "$VOICE_ID")"

wget "${BASE_URL}?text=${ENCODED_TEXT}&voice_id=${ENCODED_VOICE}"


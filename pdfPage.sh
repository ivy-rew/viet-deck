#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <pdf_file> <page_number>" >&2
    exit 1
fi

PDF="$1"
PAGE="$2"

if [[ ! -f "$PDF" ]]; then
    echo "Error: file not found: $PDF" >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Extract the requested page as a single-page PDF (no rasterisation = no quality loss)
# pdfseparate inserts the page number into the filename (%d placeholder)
pdfseparate -f "$PAGE" -l "$PAGE" "$PDF" "$TMP_DIR/page-%d.pdf"
PAGE_PDF="$TMP_DIR/page-${PAGE}.pdf"

if [[ ! -f "$PAGE_PDF" ]]; then
    echo "Error: could not extract page $PAGE from $PDF" >&2
    exit 1
fi

# Rasterise the single extracted page to PNG for tesseract
pdftoppm -r 300 -png "$PAGE_PDF" "$TMP_DIR/img"
PAGE_IMG=$(ls "$TMP_DIR"/img-*.png 2>/dev/null | head -n 1)

if [[ -z "$PAGE_IMG" ]]; then
    echo "Error: could not rasterise page $PAGE" >&2
    exit 1
fi

# Run OCR — capture output and show it immediately
echo "=== Raw OCR ===" >&2
RAW=$(tesseract -l vie+eng --oem 1 --psm 4 "$PAGE_IMG" stdout 2>&1 | grep -v '^Tesseract')
echo "$RAW"

# Ask before running Copilot
echo "" >&2
read -r -p "Run Copilot to fix scanning errors? [y/N] " RUN_COPILOT
[[ "$RUN_COPILOT" =~ ^[Yy]$ ]] || exit 0

echo "=== Copilot (fixing Vietnamese …) ===" >&2
PROMPT="Fix Vietnamese character issues and spelling mistakes in the following OCR text. Return only the corrected plain text, no explanations, no markdown.

${RAW}"

copilot -s -p "$PROMPT" --model gpt-4.1

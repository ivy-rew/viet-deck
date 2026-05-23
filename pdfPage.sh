#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <pdf_file> <page> [end_page]" >&2
    exit 1
fi

PDF="$1"
PAGE_FROM="$2"
PAGE_TO="${3:-$PAGE_FROM}"

if [[ ! -f "$PDF" ]]; then
    echo "Error: file not found: $PDF" >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Extract the requested page range as a single PDF
pdfseparate -f "$PAGE_FROM" -l "$PAGE_TO" "$PDF" "$TMP_DIR/page-%d.pdf"

# Rasterise each page and OCR them in order
RAW=""
for PAGE_PDF in $(ls "$TMP_DIR"/page-*.pdf 2>/dev/null | sort -V); do
    pdftoppm -r 300 -png "$PAGE_PDF" "$TMP_DIR/img"
    PAGE_IMG=$(ls "$TMP_DIR"/img-*.png 2>/dev/null | head -n 1)
    if [[ -z "$PAGE_IMG" ]]; then
        echo "Error: could not rasterise $PAGE_PDF" >&2
        exit 1
    fi
    PAGE_TEXT=$(tesseract -l vie+eng --oem 1 --psm 4 "$PAGE_IMG" stdout 2>&1 | grep -v '^Tesseract')
    RAW="${RAW}${PAGE_TEXT}"$'\n'
    rm -f "$TMP_DIR"/img-*.png
done

# Run OCR — capture output and show it immediately
echo "=== Raw OCR ===" >&2
echo "$RAW"

# Ask before running Copilot
echo "" >&2
read -r -p "Run Copilot to fix scanning errors? [y/N] " RUN_COPILOT
[[ "$RUN_COPILOT" =~ ^[Yy]$ ]] || exit 0

echo "=== Copilot (fixing Vietnamese …) ===" >&2
PROMPT="Fix Vietnamese character issues and spelling mistakes in the following OCR text. Return only the corrected plain text, no explanations, no markdown.

${RAW}"

COPILOT_OUT=$(copilot -s -p "$PROMPT" --model gpt-4.1)
echo "$COPILOT_OUT"

echo "" >&2
read -r -p "Save Copilot output to file? (enter filename or leave blank to skip): " SAVE_FILE
if [[ -n "$SAVE_FILE" ]]; then
    echo "$COPILOT_OUT" > "$SAVE_FILE"
    echo "Saved to $SAVE_FILE" >&2
fi

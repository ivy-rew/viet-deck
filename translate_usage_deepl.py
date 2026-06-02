#!/usr/bin/env python3
"""Fill usage English columns in glossary CSV using DeepL.

Default behavior:
- Translate usage1_vn -> usage1_en only if usage1_en is empty
- Translate usage2_vn -> usage2_en only if usage2_en is empty
- Preserve all non-target columns and row order
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from dataclasses import dataclass
from typing import List, Tuple
from urllib import error, parse, request


EXPECTED_COLUMNS = [
    "VN",
    "EN",
    "synonym",
    "usage1_vn",
    "usage1_en",
    "usage2_vn",
    "usage2_en",
    "audio",
    "picture",
]


@dataclass
class TranslationFailure:
    row_number: int
    target_field: str
    source_text: str
    error_message: str


class DeepLClient:
    def __init__(
        self,
        api_key: str,
        api_url: str,
        timeout_seconds: float,
        max_retries: int,
        retry_base_seconds: float,
    ) -> None:
        self.api_key = api_key
        self.api_url = api_url
        self.timeout_seconds = timeout_seconds
        self.max_retries = max_retries
        self.retry_base_seconds = retry_base_seconds

    def translate(self, text: str, target_lang: str) -> str:
        payload = parse.urlencode(
            {
                "text": text,
                "target_lang": target_lang,
            }
        ).encode("utf-8")

        last_error = "unknown error"
        for attempt in range(self.max_retries + 1):
            req = request.Request(
                self.api_url,
                data=payload,
                method="POST",
                headers={
                    "Authorization": f"DeepL-Auth-Key {self.api_key}",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
            )
            try:
                with request.urlopen(req, timeout=self.timeout_seconds) as resp:
                    body = resp.read().decode("utf-8")
                    data = json.loads(body)
                    translations = data.get("translations", [])
                    if not translations:
                        raise RuntimeError("DeepL response missing translations")
                    translated = translations[0].get("text", "").strip()
                    if not translated:
                        raise RuntimeError("DeepL returned empty translation")
                    return translated
            except error.HTTPError as exc:
                details = exc.read().decode("utf-8", errors="replace")
                last_error = f"HTTP {exc.code}: {details}"
                if exc.code in (429, 500, 502, 503, 504) and attempt < self.max_retries:
                    time.sleep(self.retry_base_seconds * (2 ** attempt))
                    continue
                break
            except error.URLError as exc:
                last_error = f"URL error: {exc.reason}"
                if attempt < self.max_retries:
                    time.sleep(self.retry_base_seconds * (2 ** attempt))
                    continue
                break
            except Exception as exc:  # pragma: no cover - safety net
                last_error = str(exc)
                break

        raise RuntimeError(last_error)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Translate usage Vietnamese fields into usage English fields using DeepL",
    )
    parser.add_argument("--input", required=True, help="Input glossary CSV path")
    parser.add_argument(
        "--output",
        default="",
        help="Output CSV path. Defaults to in-place update of --input.",
    )
    parser.add_argument(
        "--api-key",
        default="",
        help="DeepL API key. If omitted, DEEPL_API_KEY is used.",
    )
    parser.add_argument(
        "--target-lang",
        default="EN-GB",
        help="DeepL target language, for example EN-GB or EN-US",
    )
    parser.add_argument(
        "--api-url",
        default="",
        help="DeepL translate endpoint. Auto-detected from API key when omitted.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite non-empty usage*_en fields.",
    )
    parser.add_argument(
        "--max-retries",
        type=int,
        default=4,
        help="Maximum retries for transient API failures.",
    )
    parser.add_argument(
        "--retry-base-seconds",
        type=float,
        default=1.0,
        help="Base duration for exponential backoff.",
    )
    parser.add_argument(
        "--request-timeout-seconds",
        type=float,
        default=30.0,
        help="HTTP timeout for each request.",
    )
    parser.add_argument(
        "--delay-seconds",
        type=float,
        default=0.15,
        help="Delay between successful requests.",
    )
    parser.add_argument(
        "--failure-report",
        default="",
        help="Write failures as TSV to this path.",
    )
    return parser.parse_args()


def resolve_api_key(arg_key: str) -> str:
    key = arg_key.strip() if arg_key else ""
    if key:
        return key
    env_key = os.environ.get("DEEPL_API_KEY", "").strip()
    if env_key:
        return env_key
    raise SystemExit("DeepL API key missing. Pass --api-key or set DEEPL_API_KEY.")


def resolve_api_url(api_key: str, arg_url: str) -> str:
    if arg_url:
        return arg_url
    if ":fx" in api_key:
        return "https://api-free.deepl.com/v2/translate"
    return "https://api.deepl.com/v2/translate"


def validate_header(header: List[str]) -> None:
    if header != EXPECTED_COLUMNS:
        raise SystemExit(
            "Unexpected header columns. Expected exactly: "
            + ";".join(EXPECTED_COLUMNS)
            + "\nFound: "
            + ";".join(header)
        )


def read_rows(path: str) -> Tuple[List[str], List[List[str]]]:
    with open(path, "r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle, delimiter=";")
        rows = list(reader)

    if not rows:
        raise SystemExit("Input CSV is empty")

    header = rows[0]
    validate_header(header)

    width = len(header)
    bad_rows = []
    for idx, row in enumerate(rows[1:], start=2):
        if len(row) != width:
            bad_rows.append((idx, len(row)))

    if bad_rows:
        sample = ", ".join([f"line {line} has {count} fields" for line, count in bad_rows[:10]])
        raise SystemExit(
            "Field width validation failed before translation: "
            + sample
            + (" ..." if len(bad_rows) > 10 else "")
        )

    return header, rows[1:]


def write_rows(path: str, header: List[str], data_rows: List[List[str]]) -> None:
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter=";", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(data_rows)


def translate_rows(
    data_rows: List[List[str]],
    client: DeepLClient,
    target_lang: str,
    overwrite: bool,
    delay_seconds: float,
) -> Tuple[List[List[str]], List[TranslationFailure], dict]:
    usage_pairs = [
        (3, 4, "usage1_en"),
        (5, 6, "usage2_en"),
    ]

    counts = {
        "translated": 0,
        "skipped_existing": 0,
        "skipped_empty_source": 0,
        "failed": 0,
    }
    failures: List[TranslationFailure] = []

    for row_number, row in enumerate(data_rows, start=2):
        for src_idx, dst_idx, dst_name in usage_pairs:
            src_text = row[src_idx].strip()
            dst_text = row[dst_idx].strip()

            if not src_text:
                counts["skipped_empty_source"] += 1
                continue

            if dst_text and not overwrite:
                counts["skipped_existing"] += 1
                continue

            try:
                translated = client.translate(src_text, target_lang=target_lang)
                row[dst_idx] = translated
                counts["translated"] += 1
                if delay_seconds > 0:
                    time.sleep(delay_seconds)
            except Exception as exc:  # noqa: BLE001
                counts["failed"] += 1
                failures.append(
                    TranslationFailure(
                        row_number=row_number,
                        target_field=dst_name,
                        source_text=src_text,
                        error_message=str(exc),
                    )
                )

    return data_rows, failures, counts


def write_failure_report(path: str, failures: List[TranslationFailure]) -> None:
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write("row_number\ttarget_field\tsource_text\terror\n")
        for item in failures:
            handle.write(
                f"{item.row_number}\t{item.target_field}\t{item.source_text}\t{item.error_message}\n"
            )


def choose_output_paths(input_path: str, output_arg: str) -> Tuple[str, str]:
    output_path = output_arg.strip() if output_arg else input_path
    if output_path == input_path:
        temp_path = input_path + ".tmp_translation"
        return output_path, temp_path
    return output_path, output_path


def main() -> int:
    args = parse_args()
    api_key = resolve_api_key(args.api_key)
    api_url = resolve_api_url(api_key=api_key, arg_url=args.api_url)

    header, rows = read_rows(args.input)

    client = DeepLClient(
        api_key=api_key,
        api_url=api_url,
        timeout_seconds=args.request_timeout_seconds,
        max_retries=args.max_retries,
        retry_base_seconds=args.retry_base_seconds,
    )

    translated_rows, failures, counts = translate_rows(
        data_rows=rows,
        client=client,
        target_lang=args.target_lang,
        overwrite=args.overwrite,
        delay_seconds=args.delay_seconds,
    )

    output_path, write_path = choose_output_paths(args.input, args.output)
    write_rows(write_path, header, translated_rows)

    if write_path != output_path:
        os.replace(write_path, output_path)

    failure_report = args.failure_report.strip()
    if failures and failure_report:
        write_failure_report(failure_report, failures)

    print("DeepL usage translation finished")
    print(f"input={args.input}")
    print(f"output={output_path}")
    print(f"target_lang={args.target_lang}")
    print(f"api_url={api_url}")
    print(f"translated={counts['translated']}")
    print(f"skipped_existing={counts['skipped_existing']}")
    print(f"skipped_empty_source={counts['skipped_empty_source']}")
    print(f"failed={counts['failed']}")
    if failures and failure_report:
        print(f"failure_report={failure_report}")
    elif failures:
        print("failures occurred. re-run with --failure-report <path> to persist details")

    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())

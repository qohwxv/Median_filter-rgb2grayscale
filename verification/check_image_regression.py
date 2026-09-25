#!/usr/bin/env python3
"""Compare full-frame simulation output with an independent golden model.

Examples:
  python3 verification/check_image_regression.py rgb2gray \
      --input lab2_preprocessing/image_rgb_hex.txt \
      --actual lab2_preprocessing/gray_output_hex.txt --offset -100

  python3 verification/check_image_regression.py median \
      --input lab2_preprocessing/anh1_hex_1d.txt \
      --actual lab2_preprocessing/anh1_filtered.txt --width 430 --height 554
"""

from __future__ import annotations

import argparse
import sys
from itertools import zip_longest
from pathlib import Path
from typing import Iterator


def hex_values(path: Path) -> Iterator[int]:
    """Yield one hexadecimal value per non-empty line with useful diagnostics."""
    with path.open(encoding="ascii") as source:
        for line_number, line in enumerate(source, start=1):
            value = line.strip()
            if not value:
                continue
            try:
                yield int(value, 16)
            except ValueError as error:
                raise ValueError(f"{path}:{line_number}: invalid hex value {value!r}") from error


def clipped_gray(rgb: int, offset: int) -> int:
    red = (rgb >> 16) & 0xFF
    green = (rgb >> 8) & 0xFF
    blue = rgb & 0xFF
    gray = ((77 * red + 150 * green + 29 * blue) >> 8) + offset
    return min(255, max(0, gray))


def report_mismatches(name: str, mismatches: int, total: int) -> int:
    if mismatches:
        print(f"FAIL {name}: {mismatches}/{total} mismatches", file=sys.stderr)
        return 1
    print(f"PASS {name}: {total} pixels match the golden model")
    return 0


def check_rgb2gray(input_path: Path, actual_path: Path, offset: int) -> int:
    mismatches = 0
    total = 0

    for index, pair in enumerate(zip_longest(hex_values(input_path), hex_values(actual_path))):
        rgb, actual = pair
        total += 1
        if rgb is None or actual is None:
            print(
                f"  index {index}: input/output length differs "
                f"(input={rgb!r}, actual={actual!r})",
                file=sys.stderr,
            )
            mismatches += 1
            continue

        expected = clipped_gray(rgb, offset)
        if actual != expected:
            if mismatches < 10:
                print(
                    f"  index {index}: rgb={rgb:06x}, "
                    f"expected={expected:02x}, actual={actual:02x}",
                    file=sys.stderr,
                )
            mismatches += 1

    return report_mismatches("rgb2gray full-image regression", mismatches, total)


def zero_padded_median(source: list[int], width: int, height: int, index: int) -> int:
    row, col = divmod(index, width)
    window = []
    for row_offset in (-1, 0, 1):
        for col_offset in (-1, 0, 1):
            sample_row = row + row_offset
            sample_col = col + col_offset
            if 0 <= sample_row < height and 0 <= sample_col < width:
                window.append(source[sample_row * width + sample_col])
            else:
                window.append(0)
    return sorted(window)[4]


def check_median(input_path: Path, actual_path: Path, width: int, height: int) -> int:
    source = list(hex_values(input_path))
    expected_pixels = width * height
    if len(source) != expected_pixels:
        print(
            f"FAIL median input: expected {expected_pixels} pixels, found {len(source)}",
            file=sys.stderr,
        )
        return 1

    mismatches = 0
    actual = hex_values(actual_path)
    for index in range(expected_pixels):
        try:
            observed = next(actual)
        except StopIteration:
            print(f"  index {index}: output ended early", file=sys.stderr)
            return 1

        expected = zero_padded_median(source, width, height, index)
        if observed != expected:
            if mismatches < 10:
                print(
                    f"  index {index}: expected={expected:02x}, actual={observed:02x}",
                    file=sys.stderr,
                )
            mismatches += 1

    try:
        extra = next(actual)
    except StopIteration:
        extra = None
    if extra is not None:
        print(f"  output contains extra data beginning with {extra:02x}", file=sys.stderr)
        mismatches += 1

    return report_mismatches("median_filter full-image regression", mismatches, expected_pixels)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)

    rgb_parser = subparsers.add_parser("rgb2gray")
    rgb_parser.add_argument("--input", type=Path, required=True)
    rgb_parser.add_argument("--actual", type=Path, required=True)
    rgb_parser.add_argument("--offset", type=int, default=0)

    median_parser = subparsers.add_parser("median")
    median_parser.add_argument("--input", type=Path, required=True)
    median_parser.add_argument("--actual", type=Path, required=True)
    median_parser.add_argument("--width", type=int, required=True)
    median_parser.add_argument("--height", type=int, required=True)

    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    if arguments.mode == "rgb2gray":
        return check_rgb2gray(arguments.input, arguments.actual, arguments.offset)
    return check_median(arguments.input, arguments.actual, arguments.width, arguments.height)


if __name__ == "__main__":
    raise SystemExit(main())

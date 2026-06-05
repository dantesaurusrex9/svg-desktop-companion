#!/usr/bin/env python3
import argparse
import os
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path


CANVAS_SIZE = 220
DEFAULT_SAMPLE_SIZE = 44
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert a raster image into a bounded SVG mosaic.")
    parser.add_argument("source_image")
    parser.add_argument("target_svg")
    parser.add_argument("--sample-size", type=int, default=DEFAULT_SAMPLE_SIZE)
    args = parser.parse_args()

    if args.sample_size < 8 or args.sample_size > 80:
        print("sample size must be between 8 and 80", file=sys.stderr)
        return 65

    source = Path(args.source_image)
    target = Path(args.target_svg)

    with tempfile.TemporaryDirectory(prefix="desktop-companion-") as temp_dir:
        normalized_png = Path(temp_dir) / "normalized.png"
        normalize_with_sips(source, normalized_png, args.sample_size)
        pixels = read_png(normalized_png)

    target.write_text(render_svg(pixels), encoding="utf-8")
    return 0


def normalize_with_sips(source: Path, target: Path, sample_size: int) -> None:
    result = subprocess.run(
        [
            "sips",
            "-s",
            "format",
            "png",
            "-z",
            str(sample_size),
            str(sample_size),
            str(source),
            "--out",
            str(target),
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip() or "sips failed to normalize image")


def read_png(path: Path) -> list[list[tuple[int, int, int, int]]]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise SystemExit(f"not a PNG after normalization: {path}")

    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    palette: list[tuple[int, int, int, int]] = []
    transparency = b""
    idat = bytearray()

    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_data = data[offset + 8 : offset + 8 + length]
        offset += 12 + length

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
            if compression != 0 or filter_method != 0 or interlace != 0:
                raise SystemExit("unsupported PNG encoding")
            if bit_depth != 8:
                raise SystemExit("unsupported PNG bit depth")
        elif chunk_type == b"PLTE":
            palette = [
                (chunk_data[i], chunk_data[i + 1], chunk_data[i + 2], 255)
                for i in range(0, len(chunk_data), 3)
            ]
        elif chunk_type == b"tRNS":
            transparency = chunk_data
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None or bit_depth is None or color_type is None:
        raise SystemExit("missing PNG header")

    if color_type == 3 and transparency:
        palette = [
            (red, green, blue, transparency[index] if index < len(transparency) else alpha)
            for index, (red, green, blue, alpha) in enumerate(palette)
        ]

    channels = channels_for(color_type)
    row_length = width * channels
    raw = zlib.decompress(bytes(idat))
    rows = []
    previous = bytearray(row_length)
    index = 0

    for _ in range(height):
        filter_type = raw[index]
        index += 1
        current = bytearray(raw[index : index + row_length])
        index += row_length
        unfilter(current, previous, filter_type, channels)
        rows.append(decode_row(current, color_type, palette))
        previous = current

    return rows


def channels_for(color_type: int) -> int:
    if color_type == 0:
        return 1
    if color_type == 2:
        return 3
    if color_type == 3:
        return 1
    if color_type == 4:
        return 2
    if color_type == 6:
        return 4
    raise SystemExit(f"unsupported PNG color type: {color_type}")


def unfilter(current: bytearray, previous: bytearray, filter_type: int, channels: int) -> None:
    for i, value in enumerate(current):
        left = current[i - channels] if i >= channels else 0
        up = previous[i]
        upper_left = previous[i - channels] if i >= channels else 0

        if filter_type == 0:
            continue
        if filter_type == 1:
            current[i] = (value + left) & 0xFF
        elif filter_type == 2:
            current[i] = (value + up) & 0xFF
        elif filter_type == 3:
            current[i] = (value + ((left + up) // 2)) & 0xFF
        elif filter_type == 4:
            current[i] = (value + paeth(left, up, upper_left)) & 0xFF
        else:
            raise SystemExit(f"unsupported PNG filter: {filter_type}")


def paeth(left: int, up: int, upper_left: int) -> int:
    estimate = left + up - upper_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    upper_left_distance = abs(estimate - upper_left)

    if left_distance <= up_distance and left_distance <= upper_left_distance:
        return left
    if up_distance <= upper_left_distance:
        return up
    return upper_left


def decode_row(row: bytearray, color_type: int, palette: list[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    pixels = []
    if color_type == 0:
        return [(value, value, value, 255) for value in row]
    if color_type == 2:
        for i in range(0, len(row), 3):
            pixels.append((row[i], row[i + 1], row[i + 2], 255))
    elif color_type == 3:
        for index in row:
            pixels.append(palette[index] if index < len(palette) else (0, 0, 0, 0))
    elif color_type == 4:
        for i in range(0, len(row), 2):
            pixels.append((row[i], row[i], row[i], row[i + 1]))
    elif color_type == 6:
        for i in range(0, len(row), 4):
            pixels.append((row[i], row[i + 1], row[i + 2], row[i + 3]))
    return pixels


def render_svg(rows: list[list[tuple[int, int, int, int]]]) -> str:
    height = len(rows)
    width = len(rows[0]) if rows else 0
    cell_width = CANVAS_SIZE / width
    cell_height = CANVAS_SIZE / height
    rects = []

    for y, row in enumerate(rows):
        x = 0
        while x < len(row):
            color = row[x]
            start = x
            x += 1
            while x < len(row) and row[x] == color:
                x += 1
            if color[3] == 0:
                continue
            rects.append(rect_for_run(start, y, x - start, cell_width, cell_height, color))

    return "\n".join(
        [
            '<svg id="companion-art" viewBox="0 0 220 220" role="img" aria-label="Desktop companion image trace" xmlns="http://www.w3.org/2000/svg">',
            *rects,
            "</svg>",
            "",
        ]
    )


def rect_for_run(
    x: int,
    y: int,
    width: int,
    cell_width: float,
    cell_height: float,
    color: tuple[int, int, int, int],
) -> str:
    red, green, blue, alpha = color
    attributes = [
        f'x="{format_number(x * cell_width)}"',
        f'y="{format_number(y * cell_height)}"',
        f'width="{format_number(width * cell_width)}"',
        f'height="{format_number(cell_height)}"',
        f'fill="#{red:02X}{green:02X}{blue:02X}"',
    ]
    if alpha < 255:
        attributes.append(f'opacity="{format_number(alpha / 255)}"')
    return "  <rect " + " ".join(attributes) + "/>"


def format_number(value: float) -> str:
    return f"{value:.4f}".rstrip("0").rstrip(".")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)

#!/usr/bin/env python3
import re
import sys
from pathlib import Path
from typing import NoReturn

MAX_SVG_BYTES = 1_000_000


def fail(message: str) -> NoReturn:
    print(message, file=sys.stderr)
    sys.exit(65)


if len(sys.argv) != 2:
    fail("usage: scripts/validate-svg.py path/to/companion.svg")

svg_path = Path(sys.argv[1])
data = svg_path.read_bytes()
if len(data) > MAX_SVG_BYTES:
    fail(f"SVG is too large: {svg_path}")

try:
    markup = data.decode("utf-8")
except UnicodeDecodeError:
    fail(f"Expected UTF-8 SVG: {svg_path}")

if not re.search(r"<svg([\s>])", markup, re.IGNORECASE):
    fail(f"Expected an SVG root element in: {svg_path}")

if not re.search(r"viewBox=[\"'][\s]*0[\s]+0[\s]+220[\s]+220[\s]*[\"']", markup):
    fail('Expected SVG bounds: viewBox="0 0 220 220"')

for pattern in (
    r"<!DOCTYPE\b",
    r"<!ENTITY\b",
    r"<script\b",
    r"<foreignObject\b",
    r"\son[a-zA-Z]+\s*=",
):
    if re.search(pattern, markup, re.IGNORECASE):
        fail(f"Unsafe SVG feature is not supported: {svg_path}")

for value in re.findall(r"\b(?:href|xlink:href)\s*=\s*[\"']([^\"']*)[\"']", markup, re.IGNORECASE):
    if not value.strip().startswith("#"):
        fail(f"External SVG references are not supported: {svg_path}")

for value in re.findall(r"url\(\s*[\"']?([^'\"\)\s]+)", markup, re.IGNORECASE):
    if not value.strip().startswith("#"):
        fail(f"External CSS url() references are not supported: {svg_path}")

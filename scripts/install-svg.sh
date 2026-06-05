#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: scripts/install-svg.sh path/to/companion.svg" >&2
	exit 64
fi

source_svg=$1

if [ ! -f "$source_svg" ]; then
	echo "SVG file not found: $source_svg" >&2
	exit 66
fi

case "$source_svg" in
*.svg) ;;
*)
	echo "Expected a .svg file: $source_svg" >&2
	exit 65
	;;
esac

if command -v xmllint >/dev/null 2>&1; then
	xmllint --noout "$source_svg"
fi

if ! grep -Eq '<svg([[:space:]>])' "$source_svg"; then
	echo "Expected an SVG root element in: $source_svg" >&2
	exit 65
fi

if ! grep -Eq "viewBox=[\"'][[:space:]]*0[[:space:]]+0[[:space:]]+220[[:space:]]+220[[:space:]]*[\"']" "$source_svg"; then
	echo "Expected SVG bounds: viewBox=\"0 0 220 220\"" >&2
	exit 65
fi

target_dir="$HOME/Library/Application Support/DesktopCompanion"
target_svg="$target_dir/companion.svg"

mkdir -p "$target_dir"
if ! cmp -s "$source_svg" "$target_svg"; then
	cp "$source_svg" "$target_svg"
fi

echo "Installed $target_svg"

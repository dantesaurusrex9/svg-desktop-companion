#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: scripts/install-svg.sh path/to/companion.svg" >&2
	exit 64
fi

source_svg=$1
script_dir=$(cd "$(dirname "$0")" && pwd)

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

python3 "$script_dir/validate-svg.py" "$source_svg"

support_dir_name=${DESKTOP_COMPANION_SUPPORT_DIR_NAME:-DesktopCompanion}
target_dir="$HOME/Library/Application Support/$support_dir_name"
target_svg="$target_dir/companion.svg"

mkdir -p "$target_dir"
if ! cmp -s "$source_svg" "$target_svg"; then
	cp "$source_svg" "$target_svg"
fi

echo "Installed $target_svg"

#!/bin/sh
set -eu

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
	echo "usage: scripts/create-companion-package.sh path/to/companion.svg package-dir companion-id 'Companion Name' [themes-dir]" >&2
	exit 64
fi

source_svg=$1
target_dir=$2
package_id=$3
display_name=$4
themes_dir=${5:-}
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

if ! printf '%s\n' "$package_id" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
	echo "Companion ID must use lowercase letters, numbers, or hyphens: $package_id" >&2
	exit 65
fi

if command -v xmllint >/dev/null 2>&1; then
	xmllint --noout "$source_svg"
fi

python3 "$script_dir/validate-svg.py" "$source_svg"

mkdir -p "$target_dir"
cp "$source_svg" "$target_dir/companion.svg"

if [ -n "$themes_dir" ]; then
	if [ ! -d "$themes_dir" ]; then
		echo "Themes directory not found: $themes_dir" >&2
		exit 66
	fi

	rm -rf "$target_dir/ConversationThemes"
	cp -R "$themes_dir" "$target_dir/ConversationThemes"
else
	rm -rf "$target_dir/ConversationThemes"
fi

python3 - "$package_id" "$display_name" "$target_dir/companion.json" "$themes_dir" <<'PY'
import json
import sys

package_id, display_name, manifest_path, themes_dir = sys.argv[1:]
manifest = {
    "schemaVersion": 1,
    "id": package_id,
    "displayName": display_name,
    "companionSVG": "companion.svg",
    "speechAnchor": {
        "x": 121,
        "y": 94,
    },
    "bubblePlacement": "automatic",
    "animationPreset": "wholeObjectReaction",
}
if themes_dir:
    manifest["conversationThemesDirectory"] = "ConversationThemes"

with open(manifest_path, "w", encoding="utf-8") as manifest_file:
    json.dump(manifest, manifest_file, ensure_ascii=False, indent=2)
    manifest_file.write("\n")
PY

echo "Created companion package at $target_dir"

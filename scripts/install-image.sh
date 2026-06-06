#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: scripts/install-image.sh path/to/image.png" >&2
	exit 64
fi

source_image=$1

if [ ! -f "$source_image" ]; then
	echo "Image file not found: $source_image" >&2
	exit 66
fi

case "$source_image" in
*.png | *.PNG) ;;
*.jpg | *.JPG | *.jpeg | *.JPEG) ;;
*.webp | *.WEBP) ;;
*.gif | *.GIF) ;;
*)
	echo "Expected PNG, JPEG, WebP, or GIF image: $source_image" >&2
	exit 65
	;;
esac

support_dir_name=${DESKTOP_COMPANION_SUPPORT_DIR_NAME:-DesktopCompanion}
target_dir="$HOME/Library/Application Support/$support_dir_name"
target_svg="$target_dir/companion.svg"
script_dir=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$target_dir"
python3 "$script_dir/raster_to_svg.py" "$source_image" "$target_svg"

echo "Installed $target_svg"

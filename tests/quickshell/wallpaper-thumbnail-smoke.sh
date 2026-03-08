#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
thumbnail_script="$repo_root/config/quickshell/scripts/wallpaper-thumbnail.sh"
theme_matrix="$repo_root/config/quickshell/components/ThemeMatrix.qml"

tmp_dir="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

export HOME="$tmp_dir/home"
mkdir -p "$HOME"

image_dir="$tmp_dir/images"
mkdir -p "$image_dir"
image_path="$image_dir/wall paper #1.png"
directory_image_path="$image_dir/second-wallpaper.jpg"

magick -size 640x480 xc:'#89b4fa' "$image_path"
magick -size 720x360 xc:'#f38ba8' "$directory_image_path"

bash "$thumbnail_script" --file "$image_path"

expected_md5="$({ IMAGE_PATH="$image_path" python - <<'PY'
from pathlib import Path
from urllib.parse import quote
import hashlib
import os

path = str(Path(os.environ["IMAGE_PATH"]).resolve())
canonical_uri = "file://" + quote(path, safe='/-._~')
print(hashlib.md5(canonical_uri.encode()).hexdigest())
PY
} )"

expected_path="$HOME/.cache/thumbnails/large/$expected_md5.png"

[[ -f "$expected_path" ]]

large_dimensions="$(magick identify -format '%w %h' "$expected_path")"
[[ "$large_dimensions" == "256 192" ]]

before_mtime="$(stat -c %Y "$expected_path")"
sleep 1
bash "$thumbnail_script" --file "$image_path"
after_mtime="$(stat -c %Y "$expected_path")"
[[ "$before_mtime" == "$after_mtime" ]]

bash "$thumbnail_script" --directory "$image_dir" --size normal

expected_normal_md5="$({ IMAGE_PATH="$directory_image_path" python - <<'PY'
from pathlib import Path
from urllib.parse import quote
import hashlib
import os

path = str(Path(os.environ["IMAGE_PATH"]).resolve())
canonical_uri = "file://" + quote(path, safe='/-._~')
print(hashlib.md5(canonical_uri.encode()).hexdigest())
PY
} )"

expected_normal_path="$HOME/.cache/thumbnails/normal/$expected_normal_md5.png"

[[ -f "$expected_normal_path" ]]

normal_dimensions="$(magick identify -format '%w %h' "$expected_normal_path")"
[[ "$normal_dimensions" == "128 64" ]]

grep -q 'property string activeWallpaperPath' "$theme_matrix"
grep -q 'property string wallpapersDirectoryPath: Quickshell.env("HOME") + "/Wallpapers"' "$theme_matrix"
grep -q 'function normalizeWallpaperPath' "$theme_matrix"
grep -q 'if (thumbnailBatchProcess.running || root.count === 0)' "$theme_matrix"
grep -q 'property string normalizedFilePath: root.normalizeWallpaperPath(fileUrl)' "$theme_matrix"
grep -q 'property bool isActiveWallpaper: normalizedFilePath.length > 0 && normalizedFilePath === root.activeWallpaperPath' "$theme_matrix"
grep -q 'current_wallpaper' "$theme_matrix"
grep -q 'activeWallpaperPath = normalizedFilePath' "$theme_matrix"
grep -q 'border.color: isActiveWallpaper ? GlobalState.matugenPrimary : (hoverArea.containsMouse ? Qt.alpha(GlobalState.matugenPrimary, 0.45) : "transparent")' "$theme_matrix"
grep -q 'border.width: isActiveWallpaper ? 3 : 1' "$theme_matrix"

theme_pane="$repo_root/config/quickshell/components/ThemePane.qml"

grep -q 'function ensureBackgroundThumbnails()' "$theme_matrix"
grep -q 'if (thumbnailBatchProcess.running)' "$theme_matrix"
grep -q 'id: thumbnailBatchProcess' "$theme_matrix"
grep -q 'wallpaper-thumbnail.sh' "$theme_matrix"
grep -q -- '--directory' "$theme_matrix"
grep -q 'root.wallpapersDirectoryPath' "$theme_matrix"
grep -q -- '--size' "$theme_matrix"
grep -q 'themeMatrix.ensureBackgroundThumbnails()' "$theme_pane"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$ROOT/AwakeBar/Assets.xcassets"

build_icon() {
  local src_name="$1"
  local set_name="$2"
  local src="$ROOT/Design/icons/$src_name"
  local set_dir="$ASSETS_DIR/$set_name.imageset"
  local svg_name="$set_name.svg"

  mkdir -p "$set_dir"
  cp "$src" "$set_dir/$svg_name"

  cat > "$set_dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$svg_name",
      "idiom" : "mac",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
JSON
}

build_icon "awakebar-off.svg" "AwakeBarStatusOff"
build_icon "awakebar-open.svg" "AwakeBarStatusOpen"
build_icon "awakebar-closed.svg" "AwakeBarStatusClosed"

echo "Icons generated into $ASSETS_DIR"

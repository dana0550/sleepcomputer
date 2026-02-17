#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$ROOT/AwakeBar/Assets.xcassets"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

build_icon() {
  local src_name="$1"
  local set_name="$2"
  local src="$ROOT/Design/icons/$src_name"
  local set_dir="$ASSETS_DIR/$set_name.imageset"
  local pdf_name="$set_name.pdf"
  local tmp_pdf="$TMP_DIR/$pdf_name"

  mkdir -p "$set_dir"
  sips -s format pdf "$src" --out "$tmp_pdf" >/dev/null
  cp "$tmp_pdf" "$set_dir/$pdf_name"

  cat > "$set_dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$pdf_name",
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

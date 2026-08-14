#!/usr/bin/env bash
# 从 archives/<pkg>/ 解压受控源码到 sources/<pkg>/src
# 用法: ./scripts/extract_archive.sh opencv
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${1:-}"

if [[ -z "$PKG" ]]; then
  echo "Usage: $0 <opencv|...>" >&2
  exit 1
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print toupper($1)}'
  else
    shasum -a 256 "$1" | awk '{print toupper($1)}'
  fi
}

case "$PKG" in
  opencv)
    ZIP="$REPO_ROOT/archives/opencv/opencv-4.5.5.zip"
    DEST="$REPO_ROOT/sources/opencv/src"
    MARKER="$DEST/CMakeLists.txt"
    EXPECT="FB16B734DB3A28E5119D513BD7C61EF417EDF3756165DC6259519BB9D23D04E2"
    INNER_NAME="opencv-4.5.5"
    ;;
  *)
    echo "ERROR: unsupported package '$PKG'" >&2
    exit 1
    ;;
esac

if [[ -f "$MARKER" && "${FORCE:-0}" != "1" ]]; then
  echo "$PKG already extracted: $DEST"
  exit 0
fi

if [[ ! -f "$ZIP" ]]; then
  echo "ERROR: missing archive: $ZIP" >&2
  exit 1
fi

ACTUAL="$(sha256_file "$ZIP")"
if [[ "$ACTUAL" != "$EXPECT" ]]; then
  echo "ERROR: SHA256 mismatch for $ZIP" >&2
  echo "  expect=$EXPECT" >&2
  echo "  actual=$ACTUAL" >&2
  exit 1
fi

TMP="$REPO_ROOT/build/_extract/$PKG"
rm -rf "$TMP"
mkdir -p "$TMP"
echo "Extracting $ZIP ..."
tar -xf "$ZIP" -C "$TMP"
INNER="$TMP/$INNER_NAME"
if [[ ! -f "$INNER/CMakeLists.txt" ]]; then
  echo "ERROR: unexpected archive layout (need $INNER_NAME/CMakeLists.txt)" >&2
  exit 1
fi
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$INNER" "$DEST"
echo "$PKG -> $DEST"

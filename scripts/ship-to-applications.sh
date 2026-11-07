#!/bin/bash
# Builds HEAD (committed code only) for macOS and installs it to /Applications/Yois/lottoApp2.app.
# Log: ~/Library/Logs/lottoApp2-ship.log
set -euo pipefail
DEST_DIR="/Applications/Yois"
APP_NAME="lottoApp2"
CACHE="$HOME/Library/Caches/lottoApp2-ship"
LOG="$HOME/Library/Logs/lottoApp2-ship.log"
REPO="$(git rev-parse --show-toplevel)"
SHA="$(git rev-parse --short HEAD)"

mkdir -p "$CACHE" "$DEST_DIR"
SRC="$(mktemp -d "$CACHE/src.XXXXXX")"
trap 'rm -rf "$SRC"' EXIT
git -C "$REPO" archive HEAD | tar -x -C "$SRC"

echo "== $(date '+%F %T') building $SHA ==" 
cd "$SRC"
xcodebuild build -scheme "$APP_NAME" -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$CACHE/DerivedData" \
  -clonedSourcePackagesDirPath "$CACHE/SourcePackages" \
  -skipMacroValidation -skipPackagePluginValidation \
  -quiet

APP="$CACHE/DerivedData/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "build product missing: $APP"; exit 1; }
rm -rf "$DEST_DIR/$APP_NAME.app"
ditto "$APP" "$DEST_DIR/$APP_NAME.app"
echo "== shipped $SHA to $DEST_DIR/$APP_NAME.app =="
osascript -e "display notification \"Shipped $SHA\" with title \"$APP_NAME\"" >/dev/null 2>&1 || true

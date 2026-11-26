#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  print -u2 "Full Xcode is required. xcodebuild was not found in the active developer toolchain."
  exit 2
fi

flutter build macos --release

app_path="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$app_path" || ! -d "$app_path" ]]; then
  print -u2 "The macOS build completed but no .app bundle was found."
  exit 3
fi

version="$(sed -n 's/^version: \([^+]*\).*/\1/p' pubspec.yaml)"
if [[ -z "$version" ]]; then
  print -u2 "Could not read the application version from pubspec.yaml."
  exit 4
fi

mkdir -p dist
app_name="Brigade Bridge-${version}.app"
staged_app="dist/${app_name}"
connector_dir="dist/Brigade Bridge Chrome Connector"
staging_root="dist/.package-staging/Brigade Bridge"
rm -rf "$staged_app"
rm -rf "$connector_dir"
rm -rf "dist/.package-staging"
ditto "$app_path" "$staged_app"
ditto chrome-extension "$connector_dir"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --deep --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" "$staged_app"
else
  codesign --deep --force --sign - "$staged_app"
fi

zip_path="dist/Brigade-Bridge-${version}.zip"
dmg_path="dist/Brigade-Bridge-${version}.dmg"
rm -f "$zip_path" "$dmg_path"
mkdir -p "$staging_root"
ditto "$staged_app" "$staging_root/Brigade Bridge.app"
ditto "$connector_dir" "$staging_root/Chrome Connector"
cp README.md "$staging_root/README.md"
ditto -c -k --keepParent "$staging_root" "$zip_path"
hdiutil create -volname "Brigade Bridge" -srcfolder "$staging_root" \
  -ov -format UDZO "$dmg_path" >/dev/null
rm -rf "dist/.package-staging"

print "Created: $staged_app"
print "Created: $connector_dir"
print "Created: $zip_path"
print "Created: $dmg_path"

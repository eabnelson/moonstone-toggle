#!/bin/bash
set -euo pipefail
moonstone_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"

if [[ "$(uname -s)" != Darwin ]]; then
    printf 'Moonstone builds on macOS only.\n' >&2
    exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
    printf 'Install Xcode or its command-line tools with Swift 6, then try again.\n' >&2
    exit 1
fi

swift build --package-path "$moonstone_root" -c release
moonstone_bin_dir="$(swift build --package-path "$moonstone_root" -c release --show-bin-path)"
moonstone_app="$moonstone_root/build/Moonstone.app"
mkdir -p "$moonstone_root/build"
rm -rf "$moonstone_app"
mkdir -p "$moonstone_app/Contents/MacOS" "$moonstone_app/Contents/Resources"
cp "$moonstone_bin_dir/Moonstone" "$moonstone_app/Contents/MacOS/Moonstone"
cp "$moonstone_root/Resources/Info.plist" "$moonstone_app/Contents/Info.plist"
cp "$moonstone_root/Resources/Moonstone.icns" "$moonstone_app/Contents/Resources/Moonstone.icns"
codesign --force --sign - "$moonstone_app"
codesign --verify --strict "$moonstone_app"
printf '\nBuilt %s\n' "$moonstone_app"

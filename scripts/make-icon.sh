#!/bin/bash
set -euo pipefail
moonstone_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
moonstone_icon_dir="$(mktemp -d "${TMPDIR:-/tmp}/moonstone-icon.XXXXXX")"
trap 'rm -rf "$moonstone_icon_dir"' EXIT

xcrun swiftc -parse-as-library \
    "$moonstone_root/Sources/Moonstone/MoonstoneIcon.swift" \
    "$moonstone_root/Tools/MakeIcon.swift" \
    -o "$moonstone_icon_dir/make-icon"
"$moonstone_icon_dir/make-icon" "$moonstone_icon_dir/Moonstone.iconset"
iconutil -c icns "$moonstone_icon_dir/Moonstone.iconset" \
    -o "$moonstone_root/Resources/Moonstone.icns"
printf 'Updated Moonstone.icns from the menu bar artwork.\n'

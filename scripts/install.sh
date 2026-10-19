#!/bin/bash
set -euo pipefail
moonstone_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
moonstone_install_dir="${MOONSTONE_INSTALL_DIR:-$HOME/Applications}"

if [[ "$(uname -s)" != Darwin ]]; then
    printf 'Moonstone runs on macOS only.\n' >&2
    exit 1
fi
moonstone_usb_tool=""
for moonstone_candidate in /opt/homebrew/bin/uhubctl /usr/local/bin/uhubctl /opt/local/bin/uhubctl; do
    if [[ -x "$moonstone_candidate" ]]; then moonstone_usb_tool="$moonstone_candidate"; break; fi
done
if [[ -z "$moonstone_usb_tool" ]]; then
    printf 'Install the USB power utility, then run this script again:\n\n  brew install uhubctl\n' >&2
    exit 1
fi
if pgrep -x Moonstone >/dev/null; then
    printf 'Quit Moonstone first (right-click its moon icon → Quit Moonstone), then run this script again.\n' >&2
    exit 1
fi

"$moonstone_root/scripts/build.sh"
mkdir -p "$moonstone_install_dir"
moonstone_destination="$moonstone_install_dir/Moonstone.app"
if [[ -e "$moonstone_destination" ]]; then
    moonstone_existing_id="$(plutil -extract CFBundleIdentifier raw -o - "$moonstone_destination/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$moonstone_existing_id" != local.moonstone.lamp ]]; then
        printf 'Another app already exists at %s. Choose a different MOONSTONE_INSTALL_DIR.\n' "$moonstone_destination" >&2
        exit 1
    fi
fi
rsync -a --delete "$moonstone_root/build/Moonstone.app/" "$moonstone_destination/"
codesign --verify --strict "$moonstone_destination"
open "$moonstone_install_dir/Moonstone.app"
printf '\nInstalled %s/Moonstone.app. Follow the one-time lamp setup window.\n' "$moonstone_install_dir"

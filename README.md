# Moonstone

A tiny macOS menu bar switch for your [Moonstone lamp](https://moonstonelamp.com/).

Click the moon icon, flip the switch, and the lamp turns on or off. A one-time setup connects the app to your own USB hub and lamp port. The daily interface stays a single switch.

This is an independent companion app. It controls USB power; it does not use a native lamp protocol or add dimming.

## Requirements

- macOS 14 or later, on Apple silicon or Intel. Builds use your Mac’s native architecture; Intel has not been tested locally.
- Swift 6 or later, supplied by Xcode 16+ or compatible Xcode command-line tools. See [Swift’s macOS installation instructions](https://www.swift.org/install/macos/).
- [Homebrew](https://brew.sh/) with `uhubctl` installed, or an existing MacPorts installation of `uhubctl`.
- A USB hub or monitor that can switch **actual power** to individual ports. Ordinary USB power alone is not enough. See [uhubctl’s compatible hubs and testing instructions](https://github.com/mvp/uhubctl#compatible-usb-hubs).

The lamp’s physical switch should stay on. Your hub’s upstream USB/data cable must connect to the Mac.

## Install from source

Clone this repository, open its folder in Terminal, and run:

```sh
brew install uhubctl
./scripts/install.sh
```

The script builds an app for your Mac, installs it in `~/Applications`, and opens it. It never requests administrator access or changes hub power during installation. If Moonstone is already running, quit it before updating.

On macOS 26+, uhubctl requires libusb 1.0.30 or later. Homebrew installs libusb as a dependency; use `brew upgrade uhubctl libusb` if needed.

### First launch

1. Choose the USB hub or monitor that powers the lamp.
2. Choose the lamp’s port. Ports with a detected USB data device are unavailable.
3. Click **Test Lamp** and watch the lamp. Only that port changes power, then returns to its original state.
4. If the lamp blinked, check the confirmation box and click **Use This Port**. Otherwise, try a different port.

After setup, click the moon icon to use the switch. Right-click or Option-click the icon for **Set Up Lamp** and **Quit Moonstone**.

## Compatibility and reconnecting

Some hubs advertise power control without actually cutting voltage. Setup cannot detect light visually: confirm that the lamp really blinked. Moonstone acts only on the exact selected hub and port; it does not force unsupported hardware or automatically switch USB 3 companion hubs. A hub requiring companion switching may not work.

If you move the hub to a different Mac socket, replace the hub, or move the lamp to a different hub port, run setup again. Moonstone checks the saved hub location, identity, description, and port before switching. If a USB data device is later plugged into the selected port, control is disabled.

Connection settings stay on your Mac in `~/Library/Application Support/Moonstone/connection.json`. They contain the selected hub’s description, which can include hardware serial numbers. This file is not part of the repository and should not be included in bug reports.

## Development

```sh
swift test
./scripts/build.sh
open build/Moonstone.app
```

`MoonstoneCore` handles hub parsing, connection settings, subprocess timeouts, and port control. `Moonstone` contains the AppKit switch and setup window. Tests use fake USB output and never switch your hardware. CI runs tests and builds the app on macOS.

The build is locally ad hoc signed. Public prebuilt releases would need a separate signing and notarization process. `uhubctl` stays a separately installed runtime dependency; this repository and the generated app do not bundle third-party executables or libraries.

See [CONTRIBUTING.md](CONTRIBUTING.md) for changes and compatibility reports.

## License

Moonstone’s Swift code and original icon are [MIT licensed](LICENSE). `uhubctl` and libusb have their own licenses; see [THIRD_PARTY.md](THIRD_PARTY.md).

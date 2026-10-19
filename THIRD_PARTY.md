# Runtime dependencies

Moonstone executes `uhubctl` as a separate program. Install it through Homebrew or MacPorts. It is not copied into this repository or app bundle.

| Project | Purpose | Upstream license |
| --- | --- | --- |
| [uhubctl](https://github.com/mvp/uhubctl) | Individual USB port power control | [GPL-2.0-only](https://github.com/mvp/uhubctl/blob/master/LICENSE) |
| [libusb](https://github.com/libusb/libusb) | USB access used by uhubctl | [LGPL-2.1-or-later](https://github.com/libusb/libusb/blob/master/COPYING) |

Local verification used uhubctl 2.6.0 and libusb 1.0.30. These projects retain their own notices and licensing. If you choose to bundle or redistribute them in a different release process, include their notices and corresponding source as required by their licenses.

Moonstone has no Swift package dependencies. AppKit and Foundation are provided by macOS.

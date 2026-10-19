# Contributing

Keep normal use to a single on/off switch. Configuration belongs in the one-time setup window.

Run `swift test` and `./scripts/build.sh` before proposing a change. Hardware-independent tests belong in `Tests/MoonstoneCoreTests`; fixtures must use fictional names and serial numbers. Changes to hub selection or power commands should test rejected targets as well as successful commands.

For compatibility reports, include the macOS version, Mac architecture, monitor or hub model, uhubctl version, and whether the setup test physically changed the lamp. Remove serial numbers from any USB output. Never include your `connection.json` file.

The default test suite must not power-cycle real devices. Manually test with a lamp on its own port, and restore its original state afterward.

Do not add fallback commands that force unsupported hubs, affect every port, or switch data devices. If a hub requires behavior outside the current exact-port model, discuss the design first.

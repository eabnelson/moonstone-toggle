import AppKit
import MoonstoneCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let powerSwitch = NSSwitch()
    private let nameLabel = NSTextField(labelWithString: "Moonstone")
    private let store = ConnectionStore()
    private var setupWindow: SetupWindow?
    private var connection: Connection?
    private var refreshTimer: Timer?
    private var busy = false
    private var power: LampPower?
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        statusItem.autosaveName = "Moonstone"
        statusItem.isVisible = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(iconClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.imageScaling = .scaleNone
        buildSwitch()
        do { connection = try store.load() } catch { lastError = error.localizedDescription }
        updateAppearance()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reconnect),
            name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reconnect),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if connection == nil { configure() } else { showSwitch() }
        }
    }

    private func buildSwitch() {
        let viewController = NSViewController()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 64))
        viewController.view = view
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        powerSwitch.target = self
        powerSwitch.action = #selector(switchChanged)
        powerSwitch.setAccessibilityLabel("Moonstone power")
        for control in [nameLabel, powerSwitch] {
            control.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(control)
        }
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            nameLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            powerSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            powerSwitch.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        popover.contentViewController = viewController
        popover.contentSize = view.frame.size
        popover.behavior = .transient
    }

    private func request(_ desiredPower: LampPower?) {
        guard !busy, let selected = connection else { return }
        refreshTimer?.invalidate()
        busy = true
        updateAppearance()
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result<LampState, Error> {
                    let controller = try LampController.system()
                    let state = try controller.state(selected)
                    if let desiredPower {
                        return LampState(connection: state.connection,
                            power: try controller.setPower(desiredPower, connection: state.connection))
                    }
                    return state
                }
            }.value
            guard let self else { return }
            busy = false
            guard connection == selected else { request(nil); return }
            switch result {
            case .success(let state):
                power = state.power
                lastError = nil
                if state.connection != selected {
                    do {
                        try store.save(state.connection)
                        connection = state.connection
                    } catch { lastError = "Could not remember the new hub location: " + error.localizedDescription }
                }
            case .failure(let error): power = nil; lastError = error.localizedDescription
            }
            updateAppearance()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: power == nil ? 3 : 30, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.request(nil) }
            }
        }
    }

    @objc private func iconClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            popover.performClose(nil)
            let menu = NSMenu()
            menu.autoenablesItems = false
            let setup = NSMenuItem(title: "Set Up Lamp…", action: #selector(configure), keyEquivalent: "")
            setup.target = self
            menu.addItem(setup)
            if connection != nil {
                let reconnect = NSMenuItem(title: "Reconnect Now", action: #selector(reconnect), keyEquivalent: "")
                reconnect.target = self
                menu.addItem(reconnect)
            }
            menu.addItem(.separator())
            let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "Quit Moonstone", action: #selector(quit), keyEquivalent: "")
            quit.target = self
            quit.isEnabled = setupWindow?.isTestingPort != true
            menu.addItem(quit)
            if let button = statusItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            }
        } else if connection == nil {
            configure()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showSwitch()
        }
    }

    private func showSwitch() {
        statusItem.isVisible = true
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.title = "Moonstone"
        popover.contentViewController?.view.window?.makeKey()
        request(nil)
    }

    @objc private func switchChanged() { request(powerSwitch.state == .on ? .on : .off) }

    @objc private func reconnect() {
        statusItem.isVisible = true
        request(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func updateAppearance() {
        let label = power.map { $0 == .on ? "Light is on" : "Light is off" }
            ?? (connection == nil ? "Set up your lamp" : "Light unavailable")
        statusItem.button?.image = power == .on ? MoonstoneIcon.on : MoonstoneIcon.off
        let help = lastError ?? "Moonstone — " + label
        statusItem.button?.toolTip = help
        statusItem.button?.setAccessibilityLabel("Moonstone")
        statusItem.button?.setAccessibilityValue(label)
        powerSwitch.isEnabled = !busy && power != nil
        if !busy { powerSwitch.state = power == .on ? .on : .off }
        powerSwitch.toolTip = help
        nameLabel.toolTip = help
    }

    @objc private func configure() {
        popover.performClose(nil)
        if setupWindow == nil {
            setupWindow = SetupWindow { [weak self] selected in
                guard let self else { return }
                try store.save(selected)
                connection = selected
                power = nil
                lastError = nil
                DispatchQueue.main.async { [weak self] in self?.showSwitch() }
            }
        }
        setupWindow?.present()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        setupWindow?.isTestingPort == true ? .terminateCancel : .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem.isVisible = true
        if connection == nil { configure() } else { showSwitch() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

@main
struct MoonstoneApplication {
    @MainActor
    static func main() {
        let arguments = Set(CommandLine.arguments.dropFirst())
        if arguments.contains("--enable-login") || arguments.contains("--disable-login") || arguments.contains("--login-status") {
            do {
                if arguments.contains("--enable-login"), SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                } else if arguments.contains("--disable-login") {
                    try SMAppService.mainApp.unregister()
                }
                print("Launch at Login: \(SMAppService.mainApp.status == .enabled ? "enabled" : SMAppService.mainApp.status == .requiresApproval ? "requires approval" : "disabled")")
                return
            } catch { fputs(error.localizedDescription + "\n", stderr); exit(1) }
        }
        if arguments.contains("--status") {
            do {
                let store = ConnectionStore()
                guard let saved = try store.load() else { throw MoonstoneError("Set up your lamp once in Moonstone first.") }
                let state = try LampController.system().state(saved)
                if state.connection != saved { try store.save(state.connection) }
                let data = try JSONSerialization.data(withJSONObject: [
                    "power": state.power.rawValue, "port": state.connection.port,
                    "hubLocation": state.connection.hubLocation, "connected": true
                ], options: [.prettyPrinted, .sortedKeys])
                print(String(decoding: data, as: UTF8.self))
                return
            } catch { fputs(error.localizedDescription + "\n", stderr); exit(1) }
        }
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "local.moonstone.lamp"
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) { return }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

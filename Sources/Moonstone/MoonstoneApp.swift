import AppKit
import MoonstoneCore

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(iconClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        buildSwitch()
        do { connection = try store.load() } catch { lastError = error.localizedDescription }
        updateAppearance()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.request(nil) }
        }
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
        busy = true
        updateAppearance()
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result<LampPower, Error> {
                    let controller = try LampController.system()
                    if let desiredPower { return try controller.setPower(desiredPower, connection: selected) }
                    return try controller.status(selected)
                }
            }.value
            guard let self else { return }
            busy = false
            guard connection == selected else { request(nil); return }
            switch result {
            case .success(let value): power = value; lastError = nil
            case .failure(let error): power = nil; lastError = error.localizedDescription
            }
            updateAppearance()
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
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.title = "Moonstone"
        popover.contentViewController?.view.window?.makeKey()
        request(nil)
    }

    @objc private func switchChanged() { request(powerSwitch.state == .on ? .on : .off) }

    private func updateAppearance() {
        let label = power.map { $0 == .on ? "Light is on" : "Light is off" }
            ?? (connection == nil ? "Set up your lamp" : "Light unavailable")
        let symbol = power.map { $0 == .on ? "moon.stars.fill" : "moon" } ?? "moon.circle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Moonstone")
        image?.isTemplate = true
        statusItem.button?.image = image
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
        if connection == nil { configure() } else { showSwitch() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) { refreshTimer?.invalidate() }
}

@main
struct MoonstoneApplication {
    @MainActor
    static func main() {
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

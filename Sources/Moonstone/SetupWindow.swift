import AppKit
import MoonstoneCore

@MainActor
final class SetupWindow: NSWindowController {
    private let hubPopup = NSPopUpButton()
    private let portPopup = NSPopUpButton()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let refreshButton = NSButton(title: "Refresh Hubs", target: nil, action: nil)
    private let testButton = NSButton(title: "Test Lamp", target: nil, action: nil)
    private let confirmation = NSButton(checkboxWithTitle: "The lamp blinked when I tested this port.", target: nil, action: nil)
    private let saveButton = NSButton(title: "Use This Port", target: nil, action: nil)
    private var hubs: [USBHub] = []
    private var busy = false
    private var testedConnection: Connection?
    private(set) var isTestingPort = false
    private let onSave: (Connection) throws -> Void

    init(onSave: @escaping (Connection) throws -> Void) {
        self.onSave = onSave
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Set Up Moonstone"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
        buildInterface()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        refresh()
    }

    private func buildInterface() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])
        let heading = NSTextField(labelWithString: "Connect your lamp")
        heading.font = .boldSystemFont(ofSize: 20)
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString:
            "Leave the lamp’s own button on. Choose its USB hub and port, then test it while you watch the lamp."))
        hubPopup.target = self
        hubPopup.action = #selector(hubChanged)
        hubPopup.setAccessibilityLabel("USB hub")
        portPopup.target = self
        portPopup.action = #selector(portChanged)
        portPopup.setAccessibilityLabel("Lamp port")
        for (title, popup) in [("USB hub", hubPopup), ("Port", portPopup)] {
            let label = NSTextField(labelWithString: title)
            label.widthAnchor.constraint(equalToConstant: 65).isActive = true
            let row = NSStackView(views: [label, popup])
            row.spacing = 12
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        refreshButton.target = self
        refreshButton.action = #selector(refresh)
        testButton.target = self
        testButton.action = #selector(testPort)
        let tests = NSStackView(views: [refreshButton, testButton])
        tests.spacing = 10
        stack.addArrangedSubview(tests)
        confirmation.target = self
        confirmation.action = #selector(updateControls)
        stack.addArrangedSubview(confirmation)
        statusLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(statusLabel)
        statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelSetup))
        saveButton.target = self
        saveButton.action = #selector(save)
        let buttons = NSStackView(views: [cancel, saveButton])
        buttons.spacing = 10
        stack.addArrangedSubview(buttons)
    }

    private var selectedConnection: Connection? {
        let index = hubPopup.indexOfSelectedItem - 1
        guard hubs.indices.contains(index), let item = portPopup.selectedItem, item.tag > 0 else { return nil }
        return Connection(hub: hubs[index], port: item.tag)
    }

    @objc private func refresh() {
        guard !busy else { return }
        busy = true
        hubs = []
        resetTest()
        hubPopup.removeAllItems()
        hubPopup.addItem(withTitle: "Looking for USB hubs…")
        portPopup.removeAllItems()
        portPopup.addItem(withTitle: "Choose a port")
        statusLabel.stringValue = "Checking which hubs support individual port power."
        updateControls()
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result<[USBHub], Error> { try LampController.system().discover() }
            }.value
            guard let self else { return }
            busy = false
            hubPopup.removeAllItems()
            hubPopup.addItem(withTitle: "Choose a hub")
            switch result {
            case .success(let discovered):
                hubs = discovered
                for hub in hubs { hubPopup.addItem(withTitle: hub.name + " (" + hub.location + ")") }
                statusLabel.stringValue = hubs.isEmpty
                    ? "No compatible hub found. Connect a hub that supports individual USB power switching, then refresh."
                    : "Only test a port used by the lamp. Ports with USB data devices cannot be selected."
            case .failure(let error): statusLabel.stringValue = error.localizedDescription
            }
            updateControls()
        }
    }

    @objc private func hubChanged() {
        resetTest()
        portPopup.removeAllItems()
        portPopup.addItem(withTitle: "Choose a port")
        let index = hubPopup.indexOfSelectedItem - 1
        if hubs.indices.contains(index) {
            for port in hubs[index].ports {
                let usable = !port.hasDataDevice && port.power != nil
                portPopup.addItem(withTitle: "Port \(port.number)" + (usable ? "" : " — unavailable (USB device or unknown state)"))
                portPopup.lastItem?.tag = port.number
                portPopup.lastItem?.isEnabled = usable
            }
        }
        portPopup.autoenablesItems = false
        updateControls()
    }

    @objc private func portChanged() { resetTest(); updateControls() }

    private func resetTest() {
        testedConnection = nil
        confirmation.state = .off
    }

    @objc private func updateControls() {
        hubPopup.isEnabled = !busy && !hubs.isEmpty
        portPopup.isEnabled = !busy && hubPopup.indexOfSelectedItem > 0
        refreshButton.isEnabled = !busy
        testButton.isEnabled = !busy && selectedConnection != nil
        confirmation.isEnabled = !busy && testedConnection != nil
        saveButton.isEnabled = !busy && confirmation.state == .on
            && testedConnection != nil && testedConnection == selectedConnection
        window?.standardWindowButton(.closeButton)?.isEnabled = !busy
    }

    @objc private func testPort() {
        guard !busy, let selected = selectedConnection else { return }
        busy = true
        isTestingPort = true
        resetTest()
        statusLabel.stringValue = "Watch the lamp. Its port will briefly change power, then return to its original state."
        updateControls()
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result<Void, Error> { try LampController.system().testPort(selected) }
            }.value
            guard let self else { return }
            busy = false
            isTestingPort = false
            switch result {
            case .success:
                testedConnection = selected
                statusLabel.stringValue = "If the lamp blinked, check the box and save. If it did not, try another port or hub."
            case .failure(let error): statusLabel.stringValue = error.localizedDescription
            }
            updateControls()
        }
    }

    @objc private func save() {
        guard saveButton.isEnabled, let selected = selectedConnection else { return }
        do { try onSave(selected); close() }
        catch { statusLabel.stringValue = error.localizedDescription }
    }

    @objc private func cancelSetup() { if !busy { close() } }
}

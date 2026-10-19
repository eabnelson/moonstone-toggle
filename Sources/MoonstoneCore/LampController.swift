import Foundation

public struct LampController: Sendable {
    private let runner: any USBCommandRunning

    public init(runner: any USBCommandRunning) { self.runner = runner }

    public static func system() throws -> LampController {
        LampController(runner: try UhubctlRunner.locate())
    }

    public func discover() throws -> [USBHub] {
        USBHubParser.parse(try runner.run([])).filter(\.supportsIndividualPower)
    }

    public func status(_ connection: Connection) throws -> LampPower {
        try selectedPort(connection).power!
    }

    @discardableResult
    public func setPower(_ power: LampPower, connection: Connection) throws -> LampPower {
        let current = try selectedPort(connection)
        if current.power == power { return power }
        _ = try runner.run(["-e", "-l", connection.hubLocation, "-n", connection.hubIdentifier,
                            "-p", String(connection.port), "-a", power.rawValue])
        let confirmed = try status(connection)
        guard confirmed == power else { throw MoonstoneError("The hub did not accept the power change.") }
        return confirmed
    }

    public func testPort(_ connection: Connection) throws {
        let original = try status(connection)
        do {
            try setPower(original == .on ? .off : .on, connection: connection)
            Thread.sleep(forTimeInterval: 1.5)
            try setPower(original, connection: connection)
        } catch {
            // Always try to return a tested port to its original state.
            let failure = error.localizedDescription
            do { try setPower(original, connection: connection) }
            catch { throw MoonstoneError(failure + " The original power state could not be restored: " + error.localizedDescription) }
            throw MoonstoneError(failure)
        }
    }

    private func selectedPort(_ connection: Connection) throws -> USBPort {
        try connection.validate()
        let matches = try discover().filter {
            $0.location == connection.hubLocation && $0.identifier == connection.hubIdentifier
                && $0.descriptor == connection.hubDescriptor
        }
        guard matches.count == 1, let hub = matches.first else {
            throw MoonstoneError("The configured USB hub is missing or has changed. Option-click the moon icon to configure the connection again.")
        }
        let ports = hub.ports.filter { $0.number == connection.port }
        guard ports.count == 1, let port = ports.first else {
            throw MoonstoneError("The configured port could not be identified uniquely. Run setup again.")
        }
        guard !port.hasDataDevice else {
            throw MoonstoneError("This port now has a USB data device connected. Moonstone will not switch its power. Run setup again.")
        }
        guard port.power != nil else { throw MoonstoneError("The hub did not report this port’s power state.") }
        return port
    }
}

import Foundation

public struct LampState: Sendable {
    public let connection: Connection
    public let power: LampPower

    public init(connection: Connection, power: LampPower) {
        self.connection = connection
        self.power = power
    }
}

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
        try state(connection).power
    }

    @discardableResult
    public func setPower(_ power: LampPower, connection: Connection) throws -> LampPower {
        let current = try state(connection)
        if current.power == power { return power }
        let resolved = current.connection
        _ = try runner.run(["-e", "-l", resolved.hubLocation, "-n", resolved.hubIdentifier,
                            "-p", String(resolved.port), "-a", power.rawValue])
        let confirmed = try status(resolved)
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

    public func state(_ connection: Connection) throws -> LampState {
        try connection.validate()
        let matches = try discover().filter {
            $0.identifier == connection.hubIdentifier && $0.descriptor == connection.hubDescriptor
        }
        guard !matches.isEmpty else {
            throw MoonstoneError("Waiting for your saved USB hub. Moonstone will reconnect automatically when it returns.")
        }
        guard matches.count == 1, let hub = matches.first else {
            throw MoonstoneError("More than one matching USB hub was found. Disconnect the extra hub so Moonstone can identify your lamp’s hub.")
        }
        let ports = hub.ports.filter { $0.number == connection.port }
        guard ports.count == 1, let port = ports.first else {
            throw MoonstoneError("The configured port could not be identified uniquely. Run setup again.")
        }
        guard !port.hasDataDevice else {
            throw MoonstoneError("This port now has a USB data device connected. Moonstone will not switch its power. Run setup again.")
        }
        guard let power = port.power else { throw MoonstoneError("The hub did not report this port’s power state.") }
        return LampState(connection: Connection(hub: hub, port: connection.port), power: power)
    }
}

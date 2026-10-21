import Foundation
import XCTest
@testable import MoonstoneCore

private func fixture(_ power: LampPower = .on) -> String {
    """
    Current status for hub 1-2 [1234:abcd Example USB Hub TEST-HUB, USB 2.10, 3 ports, ppps]
      Port 1: 0103 power enable connect [9999:0001 Example Keyboard TEST-KEYBOARD]
      Port 2: \(power == .on ? "0100 power" : "0000 off")
      Port 3: 0000 off
    """
}

private func connection(port: Int = 2) -> Connection {
    Connection(hub: USBHubParser.parse(fixture())[0], port: port)
}

private final class FakeRunner: USBCommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String]
    private var calls: [[String]] = []

    init(_ responses: [String]) { self.responses = responses }

    func run(_ arguments: [String]) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        calls.append(arguments)
        guard !responses.isEmpty else { throw MoonstoneError("No mock response available.") }
        return responses.removeFirst()
    }

    var invocations: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

final class MoonstoneCoreTests: XCTestCase {
    func testParseHubAndPortStates() throws {
        let hub = try XCTUnwrap(USBHubParser.parse(fixture()).first)
        XCTAssertEqual(hub.location, "1-2")
        XCTAssertEqual(hub.identifier, "1234:abcd")
        XCTAssertEqual(hub.name, "Example USB Hub TEST-HUB")
        XCTAssertTrue(hub.supportsIndividualPower)
        XCTAssertEqual(hub.ports.map(\.power), [.on, .on, .off])
        XCTAssertTrue(hub.ports[0].hasDataDevice)
        XCTAssertFalse(hub.ports[1].hasDataDevice)
    }

    func testMalformedHeaderDoesNotReusePreviousHub() {
        let output = fixture() + "\nCurrent status for hub INVALID [broken]\n  Port 4: 0100 power\n"
        XCTAssertEqual(USBHubParser.parse(output).first?.ports.count, 3)
    }

    func testGangedHubIsExcluded() throws {
        let runner = FakeRunner([fixture().replacingOccurrences(of: ", ppps]", with: ", ganged]")])
        XCTAssertTrue(try LampController(runner: runner).discover().isEmpty)
    }

    func testOnlyExactConfiguredPortIsSwitched() throws {
        let runner = FakeRunner([fixture(), "power changed", fixture(.off)])
        XCTAssertEqual(try LampController(runner: runner).setPower(.off, connection: connection()), .off)
        XCTAssertEqual(runner.invocations, [[], ["-e", "-l", "1-2", "-n", "1234:abcd", "-p", "2", "-a", "off"], []])
    }

    func testNoCommandWhenPowerAlreadyMatches() throws {
        let runner = FakeRunner([fixture()])
        XCTAssertEqual(try LampController(runner: runner).setPower(.on, connection: connection()), .on)
        XCTAssertEqual(runner.invocations, [[]])
    }

    func testConnectedDataDeviceCannotBeSwitched() {
        let runner = FakeRunner([fixture()])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection(port: 1)))
        XCTAssertEqual(runner.invocations, [[]])
    }

    func testChangedHubCannotBeSwitched() {
        let runner = FakeRunner([fixture().replacingOccurrences(of: "TEST-HUB", with: "ANOTHER-HUB")])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection()))
        XCTAssertEqual(runner.invocations, [[]])
    }

    func testMovedHubReconnectsToRememberedPort() throws {
        let moved = fixture().replacingOccurrences(of: "hub 1-2", with: "hub 1-3")
        let off = fixture(.off).replacingOccurrences(of: "hub 1-2", with: "hub 1-3")
        let runner = FakeRunner([moved, "power changed", off])
        XCTAssertEqual(try LampController(runner: runner).setPower(.off, connection: connection()), .off)
        XCTAssertEqual(runner.invocations, [[], ["-e", "-l", "1-3", "-n", "1234:abcd", "-p", "2", "-a", "off"], []])
    }

    func testIdenticalHubsAtDifferentLocationsAreRejected() {
        let moved = fixture().replacingOccurrences(of: "hub 1-2", with: "hub 1-3")
        let runner = FakeRunner([fixture() + "\n" + moved])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection()))
        XCTAssertEqual(runner.invocations, [[]])
    }

    func testMovedHubReturnsConnectionToPersist() throws {
        let moved = fixture().replacingOccurrences(of: "hub 1-2", with: "hub 1-3")
        let state = try LampController(runner: FakeRunner([moved])).state(connection())
        XCTAssertEqual(state.connection.hubLocation, "1-3")
        XCTAssertEqual(state.connection.port, 2)
        XCTAssertEqual(state.power, .on)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ConnectionStore(url: folder.appendingPathComponent("connection.json"))
        try store.save(state.connection)
        XCTAssertEqual(try store.load(), state.connection)
    }

    func testDisconnectThenReconnectKeepsRememberedPort() throws {
        let runner = FakeRunner(["", fixture().replacingOccurrences(of: "hub 1-2", with: "hub 1-3")])
        let controller = LampController(runner: runner)
        XCTAssertThrowsError(try controller.status(connection()))
        let reconnected = try controller.state(connection())
        XCTAssertEqual(reconnected.connection.port, 2)
        XCTAssertEqual(reconnected.connection.hubLocation, "1-3")
        XCTAssertEqual(runner.invocations, [[], []])
    }

    func testMovedHubWithDataDeviceCannotBeSwitched() {
        let runner = FakeRunner([fixture().replacingOccurrences(of: "hub 1-2", with: "hub 1-3")])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection(port: 1)))
        XCTAssertEqual(runner.invocations, [[]])
    }

    func testDuplicateHubIsRejected() {
        let runner = FakeRunner([fixture() + "\n" + fixture()])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection()))
        XCTAssertEqual(runner.invocations, [[]])
    }

    func testMissingPortIsRejected() {
        let runner = FakeRunner([fixture()])
        XCTAssertThrowsError(try LampController(runner: runner).status(connection(port: 4)))
    }

    func testUnknownPowerStateIsRejected() {
        let runner = FakeRunner([fixture().replacingOccurrences(of: "Port 2: 0100 power", with: "Port 2: 0000")])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection()))
        XCTAssertEqual(runner.invocations, [[]])
    }

    func testInvalidConfigurationDoesNotReachUSB() {
        let runner = FakeRunner([])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection(port: 0)))
        XCTAssertTrue(runner.invocations.isEmpty)
        var future = connection()
        future.version = 999
        XCTAssertThrowsError(try future.validate())
    }

    func testPowerChangeMustBeConfirmed() {
        let runner = FakeRunner([fixture(), "request accepted", fixture()])
        XCTAssertThrowsError(try LampController(runner: runner).setPower(.off, connection: connection()))
    }

    func testConnectionRoundTripAndPermissions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ConnectionStore(url: folder.appendingPathComponent("connection.json"))
        XCTAssertNil(try store.load())
        try store.save(connection())
        XCTAssertEqual(try store.load(), connection())
        let attributes = try FileManager.default.attributesOfItem(atPath: store.url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try Data("invalid config".utf8).write(to: store.url)
        XCTAssertThrowsError(try store.load())
    }

    func testRunnerCapturesFailureOutput() throws {
        try withExecutable("#!/bin/sh\nprintf 'USB unavailable' >&2\nexit 7\n") { url in
            XCTAssertThrowsError(try UhubctlRunner(executable: url).run([])) { error in
                XCTAssertEqual(error.localizedDescription, "USB unavailable")
            }
        }
    }

    func testRunnerHasBoundedTimeout() throws {
        try withExecutable("#!/bin/sh\nexec /bin/sleep 30\n") { url in
            let started = Date()
            XCTAssertThrowsError(try UhubctlRunner(executable: url, timeout: 0.1).run([])) { error in
                XCTAssertTrue(error.localizedDescription.contains("too long"))
            }
            XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        }
    }

    private func withExecutable(_ contents: String, body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let script = folder.appendingPathComponent("usb-tool")
        try Data(contents.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        try body(script)
    }
}

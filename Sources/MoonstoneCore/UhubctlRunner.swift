import Foundation
import Darwin

public protocol USBCommandRunning: Sendable {
    func run(_ arguments: [String]) throws -> String
}

public struct UhubctlRunner: USBCommandRunning {
    public let executable: URL
    private let timeout: TimeInterval

    public init(executable: URL, timeout: TimeInterval = 8) {
        self.executable = executable
        self.timeout = timeout
    }

    public static func locate() throws -> UhubctlRunner {
        for path in ["/opt/homebrew/bin/uhubctl", "/usr/local/bin/uhubctl", "/opt/local/bin/uhubctl"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return UhubctlRunner(executable: URL(fileURLWithPath: path))
            }
        }
        throw MoonstoneError("Install the USB power utility with ‘brew install uhubctl’, then reopen setup.")
    }

    public func run(_ arguments: [String]) throws -> String {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("moonstone-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw MoonstoneError("Moonstone could not create a temporary output file.")
        }
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if process.isRunning {
            process.terminate()
            let gracePeriod = Date().addingTimeInterval(0.3)
            while process.isRunning && Date() < gracePeriod { Thread.sleep(forTimeInterval: 0.025) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw MoonstoneError("The USB hub took too long to respond. Check its connection and try again.")
        }
        process.waitUntilExit()
        let text = String(decoding: try Data(contentsOf: outputURL), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            let details = text.trimmingCharacters(in: .whitespacesAndNewlines)
            throw MoonstoneError(details.isEmpty ? "USB control failed. Check the hub’s connection." : details)
        }
        return text
    }
}

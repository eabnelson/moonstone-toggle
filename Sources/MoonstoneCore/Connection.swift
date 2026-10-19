import Foundation

public struct MoonstoneError: LocalizedError, Sendable {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

public struct Connection: Codable, Equatable, Sendable {
    public var version: Int = 1
    public let hubLocation: String
    public let hubIdentifier: String
    public let hubDescriptor: String
    public let port: Int

    public init(hub: USBHub, port: Int) {
        hubLocation = hub.location
        hubIdentifier = hub.identifier
        hubDescriptor = hub.descriptor
        self.port = port
    }

    public func validate() throws {
        guard version == 1,
              hubLocation.range(of: #"^[0-9]+(?:-[0-9]+(?:\.[0-9]+)*)?$"#, options: .regularExpression) != nil,
              hubIdentifier.range(of: #"^[0-9a-f]{4}:[0-9a-f]{4}$"#, options: .regularExpression) != nil,
              hubDescriptor.hasPrefix(hubIdentifier + " "), hubDescriptor.hasSuffix(", ppps"),
              (1...31).contains(port) else {
            throw MoonstoneError("The saved connection is invalid. Option-click the moon icon to set up your lamp again.")
        }
    }
}

public struct ConnectionStore: Sendable {
    public let url: URL

    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Moonstone/connection.json")
    }

    public func load() throws -> Connection? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let connection = try JSONDecoder().decode(Connection.self, from: Data(contentsOf: url))
        try connection.validate()
        return connection
    }

    public func save(_ connection: Connection) throws {
        try connection.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(connection).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

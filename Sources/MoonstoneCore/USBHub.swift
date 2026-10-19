import Foundation

public enum LampPower: String, Codable, Sendable {
    case on, off
}

public struct USBPort: Equatable, Sendable {
    public let number: Int
    public let power: LampPower?
    public let hasDataDevice: Bool
    public let description: String
}

public struct USBHub: Equatable, Sendable {
    public let location: String
    public let identifier: String
    public let descriptor: String
    public let supportsIndividualPower: Bool
    public var ports: [USBPort]

    public var name: String {
        String(descriptor.dropFirst(identifier.count + 1))
            .components(separatedBy: ", USB ").first ?? descriptor
    }
}

public enum USBHubParser {
    private static let header = try! NSRegularExpression(
        pattern: #"^Current status for hub ([0-9]+(?:-[0-9]+(?:\.[0-9]+)*)?) \[([0-9a-fA-F]{4}:[0-9a-fA-F]{4}) (.+)\]$"#)
    private static let port = try! NSRegularExpression(pattern: #"^\s+Port ([0-9]+): [0-9a-fA-F]{4}(?: (.*))?$"#)

    public static func parse(_ output: String) -> [USBHub] {
        var hubs: [USBHub] = []
        for line in output.components(separatedBy: .newlines) {
            if let parts = captures(header, line) {
                let identifier = parts[1].lowercased()
                hubs.append(USBHub(location: parts[0], identifier: identifier,
                                   descriptor: identifier + " " + parts[2],
                                   supportsIndividualPower: parts[2].hasSuffix(", ppps"), ports: []))
            } else if line.hasPrefix("Current status for hub ") {
                // A malformed header must never attach its ports to a previous hub.
                hubs.append(USBHub(location: "", identifier: "", descriptor: "",
                                   supportsIndividualPower: false, ports: []))
            } else if let parts = captures(port, line), !hubs.isEmpty,
                      let number = Int(parts[0]), (1...31).contains(number) {
                let details = parts[1]
                let flags = details.components(separatedBy: " [")[0].split(separator: " ")
                let power: LampPower? = flags.contains("power") ? .on : (flags.contains("off") ? .off : nil)
                hubs[hubs.count - 1].ports.append(USBPort(number: number, power: power,
                                                        hasDataDevice: flags.contains("connect"),
                                                        description: details))
            }
        }
        return hubs.filter { !$0.location.isEmpty }
    }

    private static func captures(_ expression: NSRegularExpression, _ line: String) -> [String]? {
        guard let match = expression.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: line).map { String(line[$0]) } ?? ""
        }
    }
}

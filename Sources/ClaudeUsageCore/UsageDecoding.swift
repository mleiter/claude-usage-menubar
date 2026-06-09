import Foundation

// ISO8601FormatStyle ist Sendable und darf daher — anders als ISO8601DateFormatter —
// vom @Sendable Decoding-Closure gefahrlos einmalig gecacht werden.
private let isoWithFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
private let isoPlain = Date.ISO8601FormatStyle()

public extension JSONDecoder {
    static func usageDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? isoWithFractionalSeconds.parse(string) { return date }
            if let date = try? isoPlain.parse(string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return decoder
    }
}

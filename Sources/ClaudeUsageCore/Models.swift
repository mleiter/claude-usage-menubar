import Foundation

public enum ClaudeUsageCore {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
}

public struct UsageWindow: Decodable, Equatable, Sendable {
    public let utilization: Double
    public let resetsAt: Date?
}

public struct ExtraUsage: Decodable, Equatable, Sendable {
    public let isEnabled: Bool
    public let monthlyLimit: Double
    public let usedCredits: Double
    public let currency: String
}

public struct Usage: Decodable, Equatable, Sendable {
    public let fiveHour: UsageWindow
    public let sevenDay: UsageWindow
    public let sevenDayOpus: UsageWindow?
    public let sevenDaySonnet: UsageWindow?
    public let extraUsage: ExtraUsage?
}

public enum UsageError: Error, Equatable, Sendable {
    case noToken
    case keychainDenied
    case tokenExpired
    case rateLimited
    case network(String)
    case decoding
}

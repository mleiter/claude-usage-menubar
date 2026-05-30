import Foundation

public enum ClaudeUsageCore {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
}

public struct Window: Decodable, Equatable {
    public let utilization: Double
    public let resetsAt: Date?
}

public struct ExtraUsage: Decodable, Equatable {
    public let isEnabled: Bool
    public let monthlyLimit: Double
    public let usedCredits: Double
    public let currency: String
}

public struct Usage: Decodable, Equatable {
    public let fiveHour: Window
    public let sevenDay: Window
    public let sevenDayOpus: Window?
    public let sevenDaySonnet: Window?
    public let extraUsage: ExtraUsage?
}

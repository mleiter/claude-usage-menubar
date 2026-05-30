import Foundation

public enum UsageLevel: Equatable {
    case normal, warning, critical
}

public func usageLevel(_ maxUtilization: Double) -> UsageLevel {
    if maxUtilization >= 95 { return .critical }
    if maxUtilization >= 80 { return .warning }
    return .normal
}

public func formatTitle(fiveHour: Double, sevenDay: Double) -> String {
    "5h \(Int(fiveHour.rounded()))% · 7d \(Int(sevenDay.rounded()))%"
}

public func usageBar(_ utilization: Double, segments: Int = 10) -> String {
    let clamped = max(0, min(100, utilization))
    var filled = Int((clamped / 100 * Double(segments)).rounded())
    if clamped > 0 { filled = max(1, filled) }
    filled = min(segments, filled)
    return String(repeating: "▓", count: filled)
         + String(repeating: "░", count: segments - filled)
}

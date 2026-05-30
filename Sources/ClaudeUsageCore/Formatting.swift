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

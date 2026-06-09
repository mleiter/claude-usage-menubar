import Foundation

/// Ein neu überschrittener Warn-Schwellwert eines Limit-Fensters.
public struct ThresholdAlert: Equatable, Sendable {
    public let label: String
    public let level: UsageLevel
    public let utilization: Double

    public init(label: String, level: UsageLevel, utilization: Double) {
        self.label = label
        self.level = level
        self.utilization = utilization
    }
}

/// Meldet pro Fenster genau dann einen Alert, wenn die Warnstufe gegenüber dem
/// vorherigen Stand gestiegen ist — kein erneuter Alert innerhalb derselben Stufe,
/// keiner beim Absinken. `previous == nil` zählt als `.normal` (erster Fetch).
public func thresholdAlerts(previous: Usage?, current: Usage) -> [ThresholdAlert] {
    let windows: [(label: String, old: Double?, new: Double)] = [
        ("5-Stunden-Limit", previous?.fiveHour.utilization, current.fiveHour.utilization),
        ("Woche (7 Tage)", previous?.sevenDay.utilization, current.sevenDay.utilization),
    ]
    return windows.compactMap { label, old, new in
        let newLevel = usageLevel(new)
        let oldLevel = old.map(usageLevel) ?? .normal
        guard newLevel > oldLevel else { return nil }
        return ThresholdAlert(label: label, level: newLevel, utilization: new)
    }
}

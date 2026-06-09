import Foundation

public enum UsageLevel: Int, Equatable, Comparable, Sendable {
    case normal = 0, warning, critical

    public static func < (lhs: UsageLevel, rhs: UsageLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public func usageLevel(_ maxUtilization: Double) -> UsageLevel {
    if maxUtilization >= 95 { return .critical }
    if maxUtilization >= 80 { return .warning }
    return .normal
}

/// Prozentwert für die Anzeige: gerundet und auf 0–100 begrenzt,
/// damit Text und Balken (`usageBar` clampt ebenfalls) nie widersprechen.
public func formatPercent(_ value: Double) -> String {
    "\(Int(max(0, min(100, value)).rounded()))%"
}

public func formatTitle(fiveHour: Double, sevenDay: Double) -> String {
    "5h \(formatPercent(fiveHour)) · 7d \(formatPercent(sevenDay))"
}

/// Statuszeile im Menü, solange noch keine Daten angezeigt werden können.
public func statusMessage(for error: UsageError?) -> String {
    switch error {
    case nil:                   return "Lade …"
    case .noToken:              return "Kein Claude-Login gefunden"
    case .keychainDenied:       return "Keychain-Zugriff verweigert"
    case .tokenExpired:         return "In Claude Code neu einloggen"
    case .rateLimited:          return "Rate-Limit erreicht"
    case .network(let message): return "Netzwerkfehler: \(message)"
    case .decoding:             return "Unerwartete API-Antwort"
    }
}

public func usageBar(_ utilization: Double, segments: Int = 10) -> String {
    let clamped = max(0, min(100, utilization))
    var filled = Int((clamped / 100 * Double(segments)).rounded())
    if clamped > 0 { filled = max(1, filled) }
    filled = min(segments, filled)
    return String(repeating: "▓", count: filled)
         + String(repeating: "░", count: segments - filled)
}

/// Wochentag nur anzeigen, wenn der Reset nicht am selben Tag (in `timeZone`) liegt.
public func formatReset(
    _ date: Date,
    timeZone: TimeZone = .current,
    locale: Locale = Locale(identifier: "de_DE"),
    now: Date = Date()
) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateFormat = calendar.isDate(date, inSameDayAs: now) ? "HH:mm" : "ccc HH:mm"
    return formatter.string(from: date)
}

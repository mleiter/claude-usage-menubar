import Foundation

/// Nächstes Poll-Intervall: Basis bei Erfolg, exponentielles Backoff bei
/// aufeinanderfolgenden Fehlern (Netz weg, Rate-Limit), gedeckelt bei `cap`.
public func nextPollInterval(
    base: TimeInterval = 60,
    consecutiveFailures: Int,
    cap: TimeInterval = 600
) -> TimeInterval {
    guard consecutiveFailures > 0 else { return base }
    return min(cap, base * pow(2, Double(consecutiveFailures)))
}

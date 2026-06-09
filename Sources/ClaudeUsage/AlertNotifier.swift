import Foundation
import UserNotifications
import ClaudeUsageCore

/// Postet macOS-Benachrichtigungen für neu überschrittene Warnstufen.
@MainActor
final class AlertNotifier {
    private var authorizationRequested = false

    func post(_ alerts: [ThresholdAlert]) {
        // UNUserNotificationCenter braucht ein App-Bundle; im Dev-Modus
        // (nacktes Binary via `swift run`) gibt es keines — dann überspringen.
        guard !alerts.isEmpty, Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        if !authorizationRequested {
            authorizationRequested = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = "Claude Usage"
            content.body = alert.level == .critical
                ? "\(alert.label) bei \(formatPercent(alert.utilization)) — kritisch"
                : "\(alert.label) bei \(formatPercent(alert.utilization))"
            center.add(UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

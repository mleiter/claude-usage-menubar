import Foundation
import SwiftUI
import AppKit
import ClaudeUsageCore

@MainActor
final class UsageStore: ObservableObject {
    @Published var usage: Usage?
    @Published var lastUpdated: Date?
    @Published var lastError: UsageError?
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }

    private let client = UsageClient()
    private let tokenProvider = KeychainTokenProvider()
    private let notifier = AlertNotifier()
    private var timer: Timer?
    private var started = false
    private var isFetching = false
    private var consecutiveFailures = 0
    private var wakeObserver: NSObjectProtocol?
    private static let notificationsKey = "notificationsEnabled"

    init() {
        notificationsEnabled =
            UserDefaults.standard.object(forKey: Self.notificationsKey) as? Bool ?? true
    }

    func start() {
        // Idempotent: onAppear des MenuBarExtra-Labels kann mehrfach feuern
        // (z. B. nach Display-Wechsel) und darf den Poll-Zyklus nicht neu starten.
        guard !started else { return }
        started = true
        // Nach dem Ruhezustand sofort aktualisieren statt auf den Timer zu warten.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        guard !isFetching else { return }
        isFetching = true
        let provider = tokenProvider
        let client = client
        // Task {} erbt hier die MainActor-Isolation von refresh().
        Task {
            defer {
                isFetching = false
                scheduleNextPoll()
            }
            do {
                // Blockierender security-Subprozess und Netzwerk laufen off-main.
                let usage = try await Task.detached(priority: .userInitiated) {
                    let token = try provider.currentToken()
                    return try await client.fetch(token: token)
                }.value
                let alerts = thresholdAlerts(previous: self.usage, current: usage)
                self.usage = usage
                self.lastUpdated = Date()
                self.lastError = nil
                self.consecutiveFailures = 0
                if notificationsEnabled { notifier.post(alerts) }
            } catch let error as UsageError {
                // Letzten bekannten Wert behalten, Fehler nur markieren.
                self.lastError = error
                self.consecutiveFailures += 1
            } catch {
                self.lastError = .network(error.localizedDescription)
                self.consecutiveFailures += 1
            }
        }
    }

    /// Einzelner One-Shot-Timer: Intervall wächst bei Fehlern exponentiell.
    private func scheduleNextPoll() {
        timer?.invalidate()
        let delay = nextPollInterval(consecutiveFailures: consecutiveFailures)
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = delay * 0.1
    }

    /// Titel für die Menüleiste.
    var title: String {
        guard let usage else { return "⚠︎" }
        return formatTitle(
            fiveHour: usage.fiveHour.utilization,
            sevenDay: usage.sevenDay.utilization)
    }

    var level: UsageLevel {
        guard let usage else { return .normal }
        return usageLevel(max(usage.fiveHour.utilization, usage.sevenDay.utilization))
    }
}

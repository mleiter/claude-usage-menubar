import Foundation
import SwiftUI
import ClaudeUsageCore

@MainActor
final class UsageStore: ObservableObject {
    @Published var usage: Usage?
    @Published var lastUpdated: Date?
    @Published var lastError: UsageError?

    private let client = UsageClient()
    private let tokenProvider = KeychainTokenProvider()
    private var timer: Timer?
    private let interval: TimeInterval = 60

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        Task { @MainActor in
            do {
                let token = try tokenProvider.currentToken()
                let usage = try await client.fetch(token: token)
                self.usage = usage
                self.lastUpdated = Date()
                self.lastError = nil
            } catch let error as UsageError {
                // Rate-Limit: letzten Wert behalten, Fehler nur intern markieren.
                self.lastError = error
            } catch {
                self.lastError = .network(error.localizedDescription)
            }
        }
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

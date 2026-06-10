import Foundation
import Testing
@testable import ClaudeUsageCore

@Test func formatsTitleWithRoundedPercents() {
    #expect(formatTitle(fiveHour: 5.0, sevenDay: 3.0) == "5h 5% · 7d 3%")
    #expect(formatTitle(fiveHour: 5.6, sevenDay: 0.0) == "5h 6% · 7d 0%")
}

@Test func computesUsageLevelThresholds() {
    #expect(usageLevel(79) == .normal)
    #expect(usageLevel(80) == .warning)
    #expect(usageLevel(94) == .warning)
    #expect(usageLevel(95) == .critical)
}

@Test func formatsPercentRoundedAndClamped() {
    #expect(formatPercent(5.0) == "5%")
    #expect(formatPercent(5.6) == "6%")
    #expect(formatPercent(0) == "0%")
    #expect(formatPercent(105) == "100%")
    #expect(formatPercent(-2) == "0%")
}

@Test func titleClampsOutOfRangeValues() {
    #expect(formatTitle(fiveHour: 105, sevenDay: -1) == "5h 100% · 7d 0%")
}

@Test func versionLabelShowsBundleVersionOrDevFallback() {
    #expect(versionLabel("1.1.0") == "Version 1.1.0")
    #expect(versionLabel(nil) == "Version dev")
}

@Test func statusMessageCoversEveryErrorCase() {
    #expect(statusMessage(for: nil) == "Lade …")
    #expect(statusMessage(for: .noToken) == "Kein Claude-Login gefunden")
    #expect(statusMessage(for: .keychainDenied) == "Keychain-Zugriff verweigert")
    #expect(statusMessage(for: .tokenExpired) == "In Claude Code neu einloggen")
    #expect(statusMessage(for: .rateLimited) == "Rate-Limit erreicht")
    #expect(statusMessage(for: .network("timeout")) == "Netzwerkfehler: timeout")
    #expect(statusMessage(for: .decoding) == "Unerwartete API-Antwort")
}

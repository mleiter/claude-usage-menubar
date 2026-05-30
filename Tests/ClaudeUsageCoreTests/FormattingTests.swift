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

import Testing
@testable import ClaudeUsageCore

@Test func barIsEmptyAtZero() {
    #expect(usageBar(0) == "░░░░░░░░░░")
}

@Test func barShowsAtLeastOneSegmentWhenNonZero() {
    #expect(usageBar(3) == "▓░░░░░░░░░")
    #expect(usageBar(5) == "▓░░░░░░░░░")
}

@Test func barFillsProportionally() {
    #expect(usageBar(50) == "▓▓▓▓▓░░░░░")
    #expect(usageBar(100) == "▓▓▓▓▓▓▓▓▓▓")
}

@Test func barClampsAboveHundred() {
    #expect(usageBar(150) == "▓▓▓▓▓▓▓▓▓▓")
}

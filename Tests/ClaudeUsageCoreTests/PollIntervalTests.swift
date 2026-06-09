import Foundation
import Testing
@testable import ClaudeUsageCore

@Test func usesBaseIntervalWithoutFailures() {
    #expect(nextPollInterval(consecutiveFailures: 0) == 60)
}

@Test func doublesIntervalPerConsecutiveFailure() {
    #expect(nextPollInterval(consecutiveFailures: 1) == 120)
    #expect(nextPollInterval(consecutiveFailures: 2) == 240)
    #expect(nextPollInterval(consecutiveFailures: 3) == 480)
}

@Test func capsBackoffAtTenMinutes() {
    #expect(nextPollInterval(consecutiveFailures: 4) == 600)
    #expect(nextPollInterval(consecutiveFailures: 10) == 600)
}

@Test func respectsCustomBaseAndCap() {
    #expect(nextPollInterval(base: 30, consecutiveFailures: 1, cap: 90) == 60)
    #expect(nextPollInterval(base: 30, consecutiveFailures: 5, cap: 90) == 90)
}

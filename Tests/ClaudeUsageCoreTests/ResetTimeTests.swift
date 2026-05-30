import Foundation
import Testing
@testable import ClaudeUsageCore

private let resetDate = ISO8601DateFormatter().date(from: "2026-05-30T19:10:00Z")!

@Test func formatsResetInUTC() {
    let s = formatReset(resetDate, timeZone: TimeZone(identifier: "UTC")!)
    #expect(s.contains("19:10"))
}

@Test func formatsResetInLocalOffset() {
    let s = formatReset(resetDate, timeZone: TimeZone(identifier: "Europe/Berlin")!)
    #expect(s.contains("21:10")) // UTC+2 im Mai
}

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

@Test func omitsWeekdayWhenResetIsToday() {
    let now = ISO8601DateFormatter().date(from: "2026-05-30T15:00:00Z")!
    let s = formatReset(resetDate, timeZone: TimeZone(identifier: "UTC")!, now: now)
    #expect(s == "19:10")
}

@Test func showsWeekdayWhenResetIsOnAnotherDay() {
    let now = ISO8601DateFormatter().date(from: "2026-05-29T15:00:00Z")!
    let s = formatReset(resetDate, timeZone: TimeZone(identifier: "UTC")!, now: now)
    #expect(s == "Sa 19:10") // 30.05.2026 ist ein Samstag
}

@Test func sameDayBoundaryUsesGivenTimeZone() {
    // 19:10 UTC ist in Auckland (UTC+12) bereits der Folgetag (So 07:10).
    let now = ISO8601DateFormatter().date(from: "2026-05-30T07:00:00Z")!
    let s = formatReset(resetDate, timeZone: TimeZone(identifier: "Pacific/Auckland")!, now: now)
    #expect(s == "So 07:10")
}

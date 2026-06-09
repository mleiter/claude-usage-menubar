import Foundation
import Testing
@testable import ClaudeUsageCore

private let sampleJSON = """
{
  "five_hour": {"utilization": 5.0, "resets_at": "2026-05-30T19:10:00.132744+00:00"},
  "seven_day": {"utilization": 3.0, "resets_at": "2026-06-01T06:00:01.132772+00:00"},
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": {"utilization": 1.0, "resets_at": "2026-06-01T06:00:00.132784+00:00"},
  "extra_usage": {"is_enabled": true, "monthly_limit": 2000, "used_credits": 0.0,
                  "utilization": null, "currency": "USD", "disabled_reason": null}
}
""".data(using: .utf8)!

@Test func decodesRealResponse() throws {
    let usage = try JSONDecoder.usageDecoder().decode(Usage.self, from: sampleJSON)
    #expect(usage.fiveHour.utilization == 5.0)
    #expect(usage.sevenDay.utilization == 3.0)
    #expect(usage.sevenDayOpus == nil)
    #expect(usage.sevenDaySonnet?.utilization == 1.0)
    #expect(usage.extraUsage?.isEnabled == true)
    #expect(usage.extraUsage?.monthlyLimit == 2000)
    #expect(usage.extraUsage?.currency == "USD")
    #expect(usage.fiveHour.resetsAt != nil)
}

@Test func parsesNonFractionalResetDate() throws {
    let json = #"{"five_hour": {"utilization": 5.0, "resets_at": "2026-05-30T19:10:00+00:00"},"#
        + #""seven_day": {"utilization": 3.0, "resets_at": null}}"#
    let usage = try JSONDecoder.usageDecoder().decode(Usage.self, from: json.data(using: .utf8)!)
    let expected = ISO8601DateFormatter().date(from: "2026-05-30T19:10:00Z")!
    #expect(abs(usage.fiveHour.resetsAt!.timeIntervalSince(expected)) < 1.0)
}

@Test func parsesFractionalResetDate() throws {
    let usage = try JSONDecoder.usageDecoder().decode(Usage.self, from: sampleJSON)
    // 2026-05-30T19:10:00Z == 1780site... assert via interval, tz-unabhängig
    let expected = ISO8601DateFormatter().date(from: "2026-05-30T19:10:00Z")!
    #expect(abs(usage.fiveHour.resetsAt!.timeIntervalSince(expected)) < 1.0)
}

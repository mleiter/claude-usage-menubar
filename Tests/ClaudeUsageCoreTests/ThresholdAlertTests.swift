import Foundation
import Testing
@testable import ClaudeUsageCore

private func makeUsage(fiveHour: Double, sevenDay: Double) -> Usage {
    Usage(
        fiveHour: UsageWindow(utilization: fiveHour, resetsAt: nil),
        sevenDay: UsageWindow(utilization: sevenDay, resetsAt: nil),
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        extraUsage: nil)
}

@Test func usageLevelsAreOrdered() {
    #expect(UsageLevel.normal < .warning)
    #expect(UsageLevel.warning < .critical)
}

@Test func noAlertBelowWarningThreshold() {
    let alerts = thresholdAlerts(previous: nil, current: makeUsage(fiveHour: 50, sevenDay: 79))
    #expect(alerts.isEmpty)
}

@Test func alertsOnFirstFetchAlreadyAboveThreshold() {
    let alerts = thresholdAlerts(previous: nil, current: makeUsage(fiveHour: 85, sevenDay: 10))
    #expect(alerts == [ThresholdAlert(label: "5-Stunden-Limit", level: .warning, utilization: 85)])
}

@Test func alertsWhenCrossingIntoWarning() {
    let alerts = thresholdAlerts(
        previous: makeUsage(fiveHour: 70, sevenDay: 10),
        current: makeUsage(fiveHour: 85, sevenDay: 10))
    #expect(alerts == [ThresholdAlert(label: "5-Stunden-Limit", level: .warning, utilization: 85)])
}

@Test func doesNotRepeatAlertWithinSameLevel() {
    let alerts = thresholdAlerts(
        previous: makeUsage(fiveHour: 85, sevenDay: 10),
        current: makeUsage(fiveHour: 90, sevenDay: 10))
    #expect(alerts.isEmpty)
}

@Test func alertsAgainWhenEscalatingToCritical() {
    let alerts = thresholdAlerts(
        previous: makeUsage(fiveHour: 85, sevenDay: 10),
        current: makeUsage(fiveHour: 96, sevenDay: 10))
    #expect(alerts == [ThresholdAlert(label: "5-Stunden-Limit", level: .critical, utilization: 96)])
}

@Test func noAlertWhenUsageDrops() {
    let alerts = thresholdAlerts(
        previous: makeUsage(fiveHour: 96, sevenDay: 10),
        current: makeUsage(fiveHour: 40, sevenDay: 10))
    #expect(alerts.isEmpty)
}

@Test func reportsBothWindowsIndependently() {
    let alerts = thresholdAlerts(previous: nil, current: makeUsage(fiveHour: 85, sevenDay: 97))
    #expect(alerts == [
        ThresholdAlert(label: "5-Stunden-Limit", level: .warning, utilization: 85),
        ThresholdAlert(label: "Woche (7 Tage)", level: .critical, utilization: 97),
    ])
}

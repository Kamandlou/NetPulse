import Foundation
import Testing
@testable import NetPulseCore

@Suite struct StatisticsServiceTests {

    @Test func overlapDurationCalculation() {
        let stats = StatisticsService()
        let t0 = Date(timeIntervalSince1970: 1000)
        let t100 = Date(timeIntervalSince1970: 1100)
        let interval = DateInterval(start: t0, end: t100)

        // Case 1: Outage entirely inside interval
        let r1 = OutageRecord(startDate: Date(timeIntervalSince1970: 1020), endDate: Date(timeIntervalSince1970: 1050), duration: 30)
        #expect(stats.overlapDuration(of: r1, within: interval) == 30)

        // Case 2: Outage starts before interval and ends inside
        let r2 = OutageRecord(startDate: Date(timeIntervalSince1970: 980), endDate: Date(timeIntervalSince1970: 1030), duration: 50)
        #expect(stats.overlapDuration(of: r2, within: interval) == 30) // from 1000 to 1030

        // Case 3: Outage starts inside interval and ends after
        let r3 = OutageRecord(startDate: Date(timeIntervalSince1970: 1070), endDate: Date(timeIntervalSince1970: 1120), duration: 50)
        #expect(stats.overlapDuration(of: r3, within: interval) == 30) // from 1070 to 1100

        // Case 4: Outage completely outside interval
        let r4 = OutageRecord(startDate: Date(timeIntervalSince1970: 1200), endDate: Date(timeIntervalSince1970: 1300), duration: 100)
        #expect(stats.overlapDuration(of: r4, within: interval) == 0)
    }

    @Test func statisticsSummaryCalculation() {
        let stats = StatisticsService()
        let now = Date(timeIntervalSince1970: 10000)
        let records = [
            OutageRecord(startDate: now.addingTimeInterval(-300), endDate: now.addingTimeInterval(-200), duration: 100),
            OutageRecord(startDate: now.addingTimeInterval(-100), endDate: now.addingTimeInterval(-50), duration: 50)
        ]

        let summary = stats.computeStatistics(records: records, filter: .today, now: now)
        #expect(summary.outageCount == 2)
        #expect(summary.totalDowntime == 150)
        #expect(summary.longestOutage == 100)
        #expect(summary.averageOutage == 75)
        #expect(summary.availabilityPercentage > 0 && summary.availabilityPercentage <= 100)
    }
}

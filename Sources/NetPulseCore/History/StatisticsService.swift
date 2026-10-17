import Foundation

public enum HistoryFilterRange: String, CaseIterable, Identifiable {
    case today
    case last7Days
    case last30Days
    case allTime

    public var id: String { rawValue }

    public func localizedName(for language: AppLanguage) -> String {
        switch self {
        case .today: return L10n.string(.filterToday, language: language)
        case .last7Days: return L10n.string(.filter7Days, language: language)
        case .last30Days: return L10n.string(.filter30Days, language: language)
        case .allTime: return L10n.string(.filterAllTime, language: language)
        }
    }

    public func dateInterval(relativeTo now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 86400)
            return DateInterval(start: start, end: now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 86400)
            return DateInterval(start: start, end: now)
        case .allTime:
            return DateInterval(start: Date.distantPast, end: now)
        }
    }
}

public struct DailyDowntimePoint: Identifiable, Sendable {
    public var id: String { dateString }
    public let date: Date
    public let dateString: String
    public let downtimeMinutes: Double

    public init(date: Date, dateString: String, downtimeMinutes: Double) {
        self.date = date
        self.dateString = dateString
        self.downtimeMinutes = downtimeMinutes
    }
}

public struct StatisticsSummary: Sendable {
    public let outageCount: Int
    public let totalDowntime: TimeInterval
    public let longestOutage: TimeInterval
    public let averageOutage: TimeInterval
    public let availabilityPercentage: Double
    public let dailyPoints: [DailyDowntimePoint]

    public init(
        outageCount: Int,
        totalDowntime: TimeInterval,
        longestOutage: TimeInterval,
        averageOutage: TimeInterval,
        availabilityPercentage: Double,
        dailyPoints: [DailyDowntimePoint] = []
    ) {
        self.outageCount = outageCount
        self.totalDowntime = totalDowntime
        self.longestOutage = longestOutage
        self.averageOutage = averageOutage
        self.availabilityPercentage = availabilityPercentage
        self.dailyPoints = dailyPoints
    }
}

public final class StatisticsService: Sendable {
    public static let shared = StatisticsService()

    public init() {}

    /// Calculates exact overlap of an outage record within a specific date window
    public func overlapDuration(of record: OutageRecord, within interval: DateInterval, now: Date = Date()) -> TimeInterval {
        let recordStart = record.startDate
        let recordEnd = record.endDate ?? now

        let overlapStart = max(recordStart, interval.start)
        let overlapEnd = min(recordEnd, interval.end)

        if overlapEnd > overlapStart {
            return overlapEnd.timeIntervalSince(overlapStart)
        }
        return 0
    }

    /// Computes summary statistics for a given filter range
    public func computeStatistics(
        records: [OutageRecord],
        filter: HistoryFilterRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StatisticsSummary {
        let interval = filter.dateInterval(relativeTo: now, calendar: calendar)

        // Find records that overlap with the interval
        var matchingRecords: [OutageRecord] = []
        var totalDowntime: TimeInterval = 0
        var longestOutage: TimeInterval = 0

        for record in records {
            let overlap = overlapDuration(of: record, within: interval, now: now)
            if overlap > 0 {
                matchingRecords.append(record)
                totalDowntime += overlap
                if overlap > longestOutage {
                    longestOutage = overlap
                }
            }
        }

        let count = matchingRecords.count
        let average = count > 0 ? (totalDowntime / Double(count)) : 0

        // Calculate availability
        let totalWindowSeconds: TimeInterval
        if filter == .allTime {
            if let earliest = records.map(\.startDate).min() {
                totalWindowSeconds = max(60, now.timeIntervalSince(earliest))
            } else {
                totalWindowSeconds = 86400
            }
        } else {
            totalWindowSeconds = max(60, interval.duration)
        }

        let availability = max(0.0, min(100.0, ((totalWindowSeconds - totalDowntime) / totalWindowSeconds) * 100.0))

        // Daily chart data points for last 7 or 30 days
        let dailyPoints = computeDailyPoints(records: matchingRecords, filter: filter, now: now, calendar: calendar)

        return StatisticsSummary(
            outageCount: count,
            totalDowntime: totalDowntime,
            longestOutage: longestOutage,
            averageOutage: average,
            availabilityPercentage: availability,
            dailyPoints: dailyPoints
        )
    }

    private func computeDailyPoints(
        records: [OutageRecord],
        filter: HistoryFilterRange,
        now: Date,
        calendar: Calendar
    ) -> [DailyDowntimePoint] {
        let numberOfDays: Int
        switch filter {
        case .today: numberOfDays = 1
        case .last7Days: numberOfDays = 7
        case .last30Days: numberOfDays = 30
        case .allTime: numberOfDays = min(30, max(7, records.count))
        }

        var points: [DailyDowntimePoint] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        for dayOffset in (0..<numberOfDays).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now)),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            let dayInterval = DateInterval(start: dayStart, end: min(dayEnd, now))
            var dayDowntimeSec: TimeInterval = 0

            for record in records {
                dayDowntimeSec += overlapDuration(of: record, within: dayInterval, now: now)
            }

            let dateLabel = dateFormatter.string(from: dayStart)
            points.append(DailyDowntimePoint(
                date: dayStart,
                dateString: dateLabel,
                downtimeMinutes: dayDowntimeSec / 60.0
            ))
        }

        return points
    }
}

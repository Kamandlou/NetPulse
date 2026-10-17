import Foundation

public struct OutageRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let startDate: Date
    public var endDate: Date?
    public var duration: TimeInterval
    public var interfaceType: NetworkInterfaceType
    public var technicalReason: String?

    public var isOngoing: Bool {
        endDate == nil
    }

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        duration: TimeInterval = 0,
        interfaceType: NetworkInterfaceType = .other,
        technicalReason: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.interfaceType = interfaceType
        self.technicalReason = technicalReason
    }

    public func activeDuration(at date: Date = Date()) -> TimeInterval {
        if let end = endDate {
            return max(0, duration > 0 ? duration : end.timeIntervalSince(startDate))
        }
        return max(0, date.timeIntervalSince(startDate))
    }

    public static func formatDuration(_ interval: TimeInterval, language: AppLanguage = .english) -> String {
        let totalSeconds = Int(max(0, interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        switch language {
        case .english:
            if hours > 0 {
                return "\(hours)h \(minutes)m \(seconds)s"
            } else if minutes > 0 {
                return "\(minutes)m \(seconds)s"
            } else {
                return "\(seconds)s"
            }
        case .persian:
            if hours > 0 {
                return "\(hours) ساعت و \(minutes) دقیقه و \(seconds) ثانیه"
            } else if minutes > 0 {
                return "\(minutes) دقیقه و \(seconds) ثانیه"
            } else {
                return "\(seconds) ثانیه"
            }
        }
    }
}

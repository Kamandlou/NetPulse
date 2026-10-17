import Foundation

@MainActor
public final class OutageHistoryStore: ObservableObject {
    public static let shared = OutageHistoryStore()

    @Published public private(set) var records: [OutageRecord] = []
    @Published public private(set) var ongoingOutage: OutageRecord?

    private let fileURL: URL
    private let settings: SettingsManager
    private var sleepDurationDeductions: [UUID: TimeInterval] = [:]

    @MainActor
    public init(
        fileURL: URL? = nil,
        settings: SettingsManager? = nil
    ) {
        let activeSettings = settings ?? .shared
        self.settings = activeSettings

        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("ir.kamandlou.NetPulse", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("outages.json")
        }

        loadRecords()
        cleanupOldRecords()
    }

    public func loadRecords() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            records = []
            ongoingOutage = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([OutageRecord].self, from: data)
            records = decoded.sorted(by: { $0.startDate > $1.startDate })
            ongoingOutage = records.first(where: { $0.isOngoing })
        } catch {
            records = []
            ongoingOutage = nil
        }
    }

    public func saveRecords() {
        guard settings.historyEnabled else { return }
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Error writing history
        }
    }

    public func recordOutageStarted(
        startDate: Date = Date(),
        interfaceType: NetworkInterfaceType,
        technicalReason: String?
    ) -> OutageRecord {
        if let existing = ongoingOutage {
            return existing
        }

        let newOutage = OutageRecord(
            id: UUID(),
            startDate: startDate,
            endDate: nil,
            duration: 0,
            interfaceType: interfaceType,
            technicalReason: technicalReason
        )

        ongoingOutage = newOutage
        records.insert(newOutage, at: 0)
        saveRecords()
        return newOutage
    }

    public func recordOutageEnded(
        endDate: Date = Date()
    ) -> OutageRecord? {
        guard var outage = ongoingOutage else { return nil }

        let sleepDeduction = sleepDurationDeductions.removeValue(forKey: outage.id) ?? 0
        let totalElapsed = max(0, endDate.timeIntervalSince(outage.startDate))
        let realDowntime = max(0, totalElapsed - sleepDeduction)

        outage.endDate = endDate
        outage.duration = realDowntime

        // Update in records array
        if let index = records.firstIndex(where: { $0.id == outage.id }) {
            records[index] = outage
        }
        ongoingOutage = nil
        saveRecords()
        return outage
    }

    public func deductSleepDuration(_ duration: TimeInterval) {
        guard let ongoing = ongoingOutage else { return }
        let current = sleepDurationDeductions[ongoing.id] ?? 0
        sleepDurationDeductions[ongoing.id] = current + duration
    }

    public func clearAllHistory() {
        records.removeAll()
        ongoingOutage = nil
        sleepDurationDeductions.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    public func cleanupOldRecords() {
        guard let maxAge = settings.historyRetention.maxAgeInSeconds else { return }
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        let initialCount = records.count
        records.removeAll(where: { !$0.isOngoing && $0.startDate < cutoffDate })
        if records.count != initialCount {
            saveRecords()
        }
    }

    // MARK: - Export

    public func exportCSV() -> String {
        var csv = "ID,Start Time (ISO8601),End Time (ISO8601),Duration (Seconds),Duration (Formatted),Interface,Status,Technical Reason\n"
        let isoFormatter = ISO8601DateFormatter()

        for record in records {
            let start = isoFormatter.string(from: record.startDate)
            let end = record.endDate != nil ? isoFormatter.string(from: record.endDate!) : "Ongoing"
            let durationSec = Int(record.activeDuration())
            let durationStr = OutageRecord.formatDuration(record.activeDuration(), language: .english)
            let iface = record.interfaceType.rawValue
            let status = record.isOngoing ? "Ongoing" : "Resolved"
            let reason = (record.technicalReason ?? "N/A").replacingOccurrences(of: ",", with: ";")

            csv += "\(record.id),\(start),\(end),\(durationSec),\(durationStr),\(iface),\(status),\(reason)\n"
        }
        return csv
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

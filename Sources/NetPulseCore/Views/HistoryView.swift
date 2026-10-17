import SwiftUI
import Charts
import AppKit

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public var selectedFilter: HistoryFilterRange = .last7Days
    @Published public var searchText: String = ""
    @Published public var now: Date = Date()
    @Published public var exportMessage: String?
    private var timer: Timer?

    public init() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.now = Date()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}

public struct HistoryView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var historyStore: OutageHistoryStore
    @ObservedObject var monitor: ConnectivityMonitor
    @StateObject private var vm = HistoryViewModel()

    @MainActor
    public init(
        settings: SettingsManager? = nil,
        historyStore: OutageHistoryStore? = nil,
        monitor: ConnectivityMonitor? = nil
    ) {
        self.settings = settings ?? .shared
        self.historyStore = historyStore ?? .shared
        self.monitor = monitor ?? .shared
    }

    public var body: some View {
        let stats = StatisticsService.shared.computeStatistics(
            records: historyStore.records,
            filter: vm.selectedFilter,
            now: vm.now
        )

        let filteredRecords = filterRecords(statsInterval: vm.selectedFilter.dateInterval(relativeTo: vm.now))

        VStack(spacing: 16) {
            topControlBar

            summaryCardsView(stats)

            if !stats.dailyPoints.isEmpty {
                chartSection(stats)
            }

            outagesTable(filteredRecords)

            bottomStatusBar(filteredCount: filteredRecords.count)
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 540)
        .environment(\.layoutDirection, settings.language.layoutDirection)
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    // MARK: - Top Controls

    private var topControlBar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $vm.selectedFilter) {
                ForEach(HistoryFilterRange.allCases) { filter in
                    Text(filter.localizedName(for: settings.language)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)

            Spacer()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(L10n.string(.searchOutages, language: settings.language), text: $vm.searchText)
                    .textFieldStyle(.plain)
                if !vm.searchText.isEmpty {
                    Button(action: { vm.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            .frame(width: 220)

            Menu {
                Button(action: {
                    exportFile(content: historyStore.exportCSV(), defaultFilename: "NetPulse-Outages.csv")
                }) {
                    Label(L10n.string(.exportCSV, language: settings.language), systemImage: "tablecells")
                }
                Button(action: {
                    exportFile(content: historyStore.exportJSON(), defaultFilename: "NetPulse-Outages.json")
                }) {
                    Label(L10n.string(.exportJSON, language: settings.language), systemImage: "curlybraces")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
    }

    // MARK: - Summary Cards

    private func summaryCardsView(_ stats: StatisticsSummary) -> some View {
        HStack(spacing: 12) {
            summaryCard(
                title: L10n.string(.totalOutages, language: settings.language),
                value: "\(stats.outageCount)",
                icon: "bolt.slash.fill",
                color: stats.outageCount > 0 ? .orange : .secondary
            )

            summaryCard(
                title: L10n.string(.totalDowntime, language: settings.language),
                value: OutageRecord.formatDuration(stats.totalDowntime, language: settings.language),
                icon: "clock.fill",
                color: stats.totalDowntime > 0 ? .red : .green
            )

            summaryCard(
                title: L10n.string(.longestOutage, language: settings.language),
                value: OutageRecord.formatDuration(stats.longestOutage, language: settings.language),
                icon: "hourglass",
                color: .secondary
            )

            summaryCard(
                title: L10n.string(.averageDuration, language: settings.language),
                value: OutageRecord.formatDuration(stats.averageOutage, language: settings.language),
                icon: "chart.line.uptrend.xyaxis",
                color: .secondary
            )

            summaryCard(
                title: L10n.string(.availability, language: settings.language),
                value: String(format: "%.2f%%", stats.availabilityPercentage),
                icon: "shield.checkerboard",
                color: stats.availabilityPercentage >= 99.5 ? .green : (stats.availabilityPercentage >= 95.0 ? .orange : .red)
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Swift Chart

    private func chartSection(_ stats: StatisticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Downtime Timeline (Minutes)")
                .font(.caption)
                .foregroundColor(.secondary)

            Chart {
                ForEach(stats.dailyPoints) { point in
                    BarMark(
                        x: .value("Date", point.dateString),
                        y: .value("Downtime (min)", point.downtimeMinutes)
                    )
                    .foregroundStyle(point.downtimeMinutes > 0 ? Color.red.gradient : Color.secondary.opacity(0.2).gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 110)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Outages Table

    private func outagesTable(_ records: [OutageRecord]) -> some View {
        Group {
            if records.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                    Text(L10n.string(.noOutagesRecorded, language: settings.language))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(records) {
                    TableColumn(L10n.string(.startTime, language: settings.language)) { record in
                        HStack(spacing: 6) {
                            if record.isOngoing {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            Text(formatDate(record.startDate))
                                .font(.system(size: 11))
                        }
                    }
                    .width(min: 130, ideal: 140)

                    TableColumn(L10n.string(.endTime, language: settings.language)) { record in
                        if let end = record.endDate {
                            Text(formatDate(end))
                                .font(.system(size: 11))
                        } else {
                            Text(L10n.string(.ongoingOutage, language: settings.language))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    .width(min: 130, ideal: 140)

                    TableColumn(L10n.string(.duration, language: settings.language)) { record in
                        let dur = record.activeDuration(at: vm.now)
                        Text(OutageRecord.formatDuration(dur, language: settings.language))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(record.isOngoing ? .red : .primary)
                    }
                    .width(min: 90, ideal: 100)

                    TableColumn(L10n.string(.interface, language: settings.language)) { record in
                        HStack(spacing: 4) {
                            Image(systemName: record.interfaceType.sfSymbol)
                            Text(record.interfaceType.localizedName(for: settings.language))
                        }
                        .font(.system(size: 11))
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn(L10n.string(.reason, language: settings.language)) { record in
                        Text(record.technicalReason ?? "Connection check failed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Bottom Status Bar

    private func bottomStatusBar(filteredCount: Int) -> some View {
        HStack {
            Text("Total Records: \(filteredCount)")
                .font(.caption2)
                .foregroundColor(.secondary)

            if let msg = vm.exportMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.leading, 12)
            }

            Spacer()

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(historyStore.exportCSV(), forType: .string)
                vm.exportMessage = "Copied to clipboard!"
            }) {
                Label(L10n.string(.copy, language: settings.language), systemImage: "doc.on.doc")
                    .font(.caption2)
            }
        }
    }

    // MARK: - Helpers

    private func filterRecords(statsInterval: DateInterval) -> [OutageRecord] {
        return historyStore.records.filter { record in
            let overlap = StatisticsService.shared.overlapDuration(of: record, within: statsInterval, now: vm.now)
            guard overlap > 0 else { return false }

            if vm.searchText.isEmpty { return true }
            let lower = vm.searchText.lowercased()
            if record.technicalReason?.lowercased().contains(lower) == true { return true }
            if record.interfaceType.rawValue.lowercased().contains(lower) { return true }
            return false
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func exportFile(content: String, defaultFilename: String) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = defaultFilename
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    self.vm.exportMessage = "Exported to \(url.lastPathComponent)"
                } catch {
                    self.vm.exportMessage = "Export failed"
                }
            }
        }
    }
}

import SwiftUI
import Charts
import AppKit

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public var selectedFilter: HistoryFilterRange = .last7Days
    @Published public var searchText: String = ""
    @Published public var now: Date = Date()
    @Published public var exportMessage: String?
    @Published public var showingClearAlert: Bool = false
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

        VStack(spacing: 14) {
            topControlBar

            summaryCardsView(stats)

            if !stats.dailyPoints.isEmpty {
                chartSection(stats)
            }

            outagesTable(filteredRecords)

            bottomStatusBar(filteredCount: filteredRecords.count)
        }
        .padding(16)
        .frame(minWidth: 740, minHeight: 560)
        .environment(\.layoutDirection, settings.language.layoutDirection)
        .preferredColorScheme(settings.appearance.colorScheme)
        .alert(
            L10n.string(.clearHistoryConfirmTitle, language: settings.language),
            isPresented: $vm.showingClearAlert
        ) {
            Button(L10n.string(.delete, language: settings.language), role: .destructive) {
                historyStore.clearAllHistory()
                vm.exportMessage = "All history cleared"
            }
            Button(L10n.string(.cancel, language: settings.language), role: .cancel) {}
        } message: {
            Text(L10n.string(.clearHistoryConfirmMessage, language: settings.language))
        }
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
            .frame(width: 330)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                TextField(L10n.string(.searchOutages, language: settings.language), text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !vm.searchText.isEmpty {
                    Button(action: { vm.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            )
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
                Divider()
                Button(role: .destructive, action: {
                    vm.showingClearAlert = true
                }) {
                    Label(L10n.string(.clearAllHistory, language: settings.language), systemImage: "trash")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)
        }
    }

    // MARK: - Summary Cards

    private func summaryCardsView(_ stats: StatisticsSummary) -> some View {
        HStack(spacing: 10) {
            summaryCard(
                title: L10n.string(.totalOutages, language: settings.language),
                value: "\(stats.outageCount)",
                icon: "bolt.slash.fill",
                accentColor: stats.outageCount > 0 ? .orange : .secondary
            )

            summaryCard(
                title: L10n.string(.totalDowntime, language: settings.language),
                value: OutageRecord.formatDuration(stats.totalDowntime, language: settings.language),
                icon: "clock.fill",
                accentColor: stats.totalDowntime > 0 ? .red : .green
            )

            summaryCard(
                title: L10n.string(.longestOutage, language: settings.language),
                value: OutageRecord.formatDuration(stats.longestOutage, language: settings.language),
                icon: "hourglass",
                accentColor: .indigo
            )

            summaryCard(
                title: L10n.string(.averageDuration, language: settings.language),
                value: OutageRecord.formatDuration(stats.averageOutage, language: settings.language),
                icon: "chart.line.uptrend.xyaxis",
                accentColor: .blue
            )

            summaryCard(
                title: L10n.string(.availability, language: settings.language),
                value: String(format: "%.2f%%", stats.availabilityPercentage),
                icon: "shield.checkerboard",
                accentColor: stats.availabilityPercentage >= 99.5 ? .green : (stats.availabilityPercentage >= 95.0 ? .orange : .red)
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 18, height: 18)
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }

            Text(value)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Swift Chart

    private func chartSection(_ stats: StatisticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Downtime History (Minutes)", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if stats.totalDowntime > 0 {
                    Text("Total: \(OutageRecord.formatDuration(stats.totalDowntime, language: settings.language))")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                }
            }

            Chart {
                ForEach(stats.dailyPoints) { point in
                    BarMark(
                        x: .value("Date", point.dateString),
                        y: .value("Downtime (min)", point.downtimeMinutes)
                    )
                    .foregroundStyle(
                        point.downtimeMinutes > 0
                        ? LinearGradient(colors: [Color.red.opacity(0.85), Color.orange.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.secondary.opacity(0.15), Color.secondary.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(5)
                }
            }
            .frame(height: 115)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Outages Table

    private func outagesTable(_ records: [OutageRecord]) -> some View {
        Group {
            if records.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 60, height: 60)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    Text(L10n.string(.noOutagesRecorded, language: settings.language))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
            } else {
                Table(records) {
                    TableColumn(L10n.string(.startTime, language: settings.language)) { record in
                        HStack(spacing: 6) {
                            if record.isOngoing {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 7, height: 7)
                            }
                            Text(formatDate(record.startDate))
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .width(min: 130, ideal: 140)

                    TableColumn(L10n.string(.endTime, language: settings.language)) { record in
                        if let end = record.endDate {
                            Text(formatDate(end))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 5, height: 5)
                                Text(L10n.string(.ongoingOutage, language: settings.language))
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                        }
                    }
                    .width(min: 130, ideal: 140)

                    TableColumn(L10n.string(.duration, language: settings.language)) { record in
                        let dur = record.activeDuration(at: vm.now)
                        Text(OutageRecord.formatDuration(dur, language: settings.language))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(record.isOngoing ? .red : .primary)
                    }
                    .width(min: 90, ideal: 105)

                    TableColumn(L10n.string(.interface, language: settings.language)) { record in
                        HStack(spacing: 5) {
                            Image(systemName: record.interfaceType.sfSymbol)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(record.interfaceType.localizedName(for: settings.language))
                        }
                        .font(.system(size: 11))
                    }
                    .width(min: 110, ideal: 130)

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
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            if let msg = vm.exportMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.leading, 12)
            }

            Spacer()

            Button(role: .destructive, action: {
                vm.showingClearAlert = true
            }) {
                Label(L10n.string(.clearAllHistory, language: settings.language), systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(historyStore.exportCSV(), forType: .string)
                vm.exportMessage = "Copied to clipboard!"
            }) {
                Label(L10n.string(.copy, language: settings.language), systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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

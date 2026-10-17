import SwiftUI
import AppKit

@MainActor
public final class MenuBarPopupViewModel: ObservableObject {
    @Published public var now: Date = Date()
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

public struct MenuBarPopupView: View {
    @ObservedObject var monitor: ConnectivityMonitor
    @ObservedObject var settings: SettingsManager
    @ObservedObject var historyStore: OutageHistoryStore
    @StateObject private var viewModel = MenuBarPopupViewModel()

    @MainActor
    public init(
        monitor: ConnectivityMonitor? = nil,
        settings: SettingsManager? = nil,
        historyStore: OutageHistoryStore? = nil
    ) {
        self.monitor = monitor ?? .shared
        self.settings = settings ?? .shared
        self.historyStore = historyStore ?? .shared
    }

    public var body: some View {
        VStack(spacing: 12) {
            headerCard

            detailsSection

            Divider()

            todayStatsSection

            Divider()

            actionsSection
        }
        .padding(14)
        .frame(width: 320)
        .environment(\.layoutDirection, settings.language.layoutDirection)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(monitor.state.color.opacity(0.18))
                    .frame(width: 44, height: 44)

                Image(systemName: monitor.state.sfSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(monitor.state.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.isPaused ? L10n.string(.monitoringPaused, language: settings.language) : monitor.state.localizedTitle(for: settings.language))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                if let reason = monitor.lastFailureReason, monitor.state == .offline || monitor.state == .unstable {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if monitor.state == .online, let latency = monitor.currentLatencyMs {
                    Text("\(L10n.string(.latency, language: settings.language)): \(Int(latency)) ms")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(spacing: 6) {
            detailRow(
                title: L10n.string(.networkInterface, language: settings.language),
                value: monitor.currentInterface.localizedName(for: settings.language),
                icon: monitor.currentInterface.sfSymbol
            )

            if let ssid = monitor.currentSSID, !ssid.isEmpty {
                detailRow(
                    title: L10n.string(.wifiSSID, language: settings.language),
                    value: ssid,
                    icon: "wifi"
                )
            }

            detailRow(
                title: L10n.string(.lastCheck, language: settings.language),
                value: formattedLastCheck(),
                icon: "clock"
            )

            if let uptimeStart = monitor.uptimeStartDate, monitor.state == .online {
                let uptimeInterval = max(0, viewModel.now.timeIntervalSince(uptimeStart))
                detailRow(
                    title: L10n.string(.currentUptime, language: settings.language),
                    value: OutageRecord.formatDuration(uptimeInterval, language: settings.language),
                    icon: "timer"
                )
            }
        }
        .font(.system(size: 12))
    }

    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Today Stats

    private var todayStatsSection: some View {
        let todaySummary = StatisticsService.shared.computeStatistics(
            records: historyStore.records,
            filter: .today,
            now: viewModel.now
        )

        return HStack(spacing: 8) {
            statBox(
                title: L10n.string(.totalDowntimeToday, language: settings.language),
                value: OutageRecord.formatDuration(todaySummary.totalDowntime, language: settings.language),
                color: todaySummary.totalDowntime > 0 ? .red : .green
            )

            statBox(
                title: L10n.string(.outagesToday, language: settings.language),
                value: "\(todaySummary.outageCount)",
                color: todaySummary.outageCount > 0 ? .orange : .secondary
            )

            statBox(
                title: L10n.string(.availability, language: settings.language),
                value: String(format: "%.1f%%", todaySummary.availabilityPercentage),
                color: todaySummary.availabilityPercentage >= 99.0 ? .green : .orange
            )
        }
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 4) {
            Button(action: {
                monitor.checkNow()
            }) {
                HStack {
                    if monitor.isCheckInProgress {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(L10n.string(.checkNow, language: settings.language))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)

            Button(action: {
                if monitor.isPaused {
                    monitor.resumeMonitoring()
                } else {
                    monitor.pauseMonitoring()
                }
            }) {
                HStack {
                    Image(systemName: monitor.isPaused ? "play.fill" : "pause.fill")
                    Text(monitor.isPaused ? L10n.string(.resumeMonitoring, language: settings.language) : L10n.string(.pauseMonitoring, language: settings.language))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)

            Divider()

            Button(action: {
                WindowManager.shared.showHistory()
            }) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                    Text(L10n.string(.connectionHistory, language: settings.language))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)

            Button(action: {
                WindowManager.shared.showSettings()
            }) {
                HStack {
                    Image(systemName: "gearshape")
                    Text(L10n.string(.settings, language: settings.language))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)

            Divider()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text(L10n.string(.quit, language: settings.language))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .font(.system(size: 12))
    }

    private func formattedLastCheck() -> String {
        guard let last = monitor.lastCheckDate else {
            return L10n.string(.notAvailable, language: settings.language)
        }
        let elapsed = Int(max(0, viewModel.now.timeIntervalSince(last)))
        if elapsed < 2 {
            return L10n.string(.justNow, language: settings.language)
        }
        return String(format: L10n.string(.secondsAgo, language: settings.language), elapsed)
    }
}

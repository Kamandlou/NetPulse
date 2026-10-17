import SwiftUI
import AppKit

@MainActor
public final class MenuBarPopupViewModel: ObservableObject {
    @Published public var now: Date = Date()
    @Published public var hoveredAction: String? = nil
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
    @StateObject private var vm = MenuBarPopupViewModel()

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
            heroStatusCard

            metricsCardsSection

            detailsCardSection

            actionsSection
        }
        .padding(14)
        .frame(width: 328)
        .environment(\.layoutDirection, settings.language.layoutDirection)
    }

    // MARK: - Hero Status Card

    private var heroStatusCard: some View {
        HStack(spacing: 12) {
            // Status Icon with Soft Glowing Background
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(statusGradients(for: monitor.state))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(monitor.state.color.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: monitor.state.sfSymbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(monitor.state.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(monitor.isPaused ? L10n.string(.monitoringPaused, language: settings.language) : monitor.state.localizedTitle(for: settings.language))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    if monitor.isCheckInProgress {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 12, height: 12)
                    }
                }

                if let reason = monitor.lastFailureReason, monitor.state == .offline || monitor.state == .unstable {
                    Text(reason)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if monitor.state == .online, let latency = monitor.currentLatencyMs {
                    latencyChip(latency)
                } else {
                    Text(monitor.currentInterface.localizedName(for: settings.language))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func statusGradients(for state: ConnectionState) -> LinearGradient {
        switch state {
        case .online:
            return LinearGradient(
                colors: [Color.green.opacity(0.25), Color.mint.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .offline:
            return LinearGradient(
                colors: [Color.red.opacity(0.25), Color.pink.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .unstable:
            return LinearGradient(
                colors: [Color.orange.opacity(0.25), Color.yellow.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .checking:
            return LinearGradient(
                colors: [Color.blue.opacity(0.25), Color.cyan.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .unknown:
            return LinearGradient(
                colors: [Color.secondary.opacity(0.20), Color.secondary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func latencyChip(_ latency: Double) -> some View {
        let (color, quality): (Color, String) = {
            if latency < 50 { return (.green, "Fast") }
            if latency < 120 { return (.blue, "Good") }
            if latency < 250 { return (.orange, "Fair") }
            return (.red, "Slow")
        }()

        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text("\(Int(latency)) ms")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)

            Text("• \(quality)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color(nsColor: .windowBackgroundColor).opacity(0.8)))
    }

    // MARK: - Metrics Cards Section

    private var metricsCardsSection: some View {
        let todaySummary = StatisticsService.shared.computeStatistics(
            records: historyStore.records,
            filter: .today,
            now: vm.now
        )

        return HStack(spacing: 8) {
            metricCard(
                title: L10n.string(.totalDowntimeToday, language: settings.language),
                value: OutageRecord.formatDuration(todaySummary.totalDowntime, language: settings.language),
                icon: "clock.fill",
                accentColor: todaySummary.totalDowntime > 0 ? .red : .green
            )

            metricCard(
                title: L10n.string(.outagesToday, language: settings.language),
                value: "\(todaySummary.outageCount)",
                icon: "bolt.slash.fill",
                accentColor: todaySummary.outageCount > 0 ? .orange : .secondary
            )

            metricCard(
                title: L10n.string(.availability, language: settings.language),
                value: String(format: "%.1f%%", todaySummary.availabilityPercentage),
                icon: "shield.checkerboard",
                accentColor: todaySummary.availabilityPercentage >= 99.0 ? .green : .orange
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(accentColor.opacity(0.8))
            }

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Details Section

    private var detailsCardSection: some View {
        VStack(spacing: 7) {
            detailRow(
                title: L10n.string(.networkInterface, language: settings.language),
                value: monitor.currentInterface.localizedName(for: settings.language),
                icon: monitor.currentInterface.sfSymbol,
                iconColor: .blue
            )

            if let ssid = monitor.currentSSID, !ssid.isEmpty {
                detailRow(
                    title: L10n.string(.wifiSSID, language: settings.language),
                    value: ssid,
                    icon: "wifi",
                    iconColor: .indigo
                )
            }

            detailRow(
                title: L10n.string(.lastCheck, language: settings.language),
                value: formattedLastCheck(),
                icon: "arrow.clockwise.circle.fill",
                iconColor: .teal
            )

            if let uptimeStart = monitor.uptimeStartDate, monitor.state == .online {
                let uptimeInterval = max(0, vm.now.timeIntervalSince(uptimeStart))
                detailRow(
                    title: L10n.string(.currentUptime, language: settings.language),
                    value: OutageRecord.formatDuration(uptimeInterval, language: settings.language),
                    icon: "timer",
                    iconColor: .green
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func detailRow(title: String, value: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 20, height: 20)

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 3) {
            actionButton(
                id: "check",
                title: L10n.string(.checkNow, language: settings.language),
                icon: monitor.isCheckInProgress ? nil : "arrow.clockwise",
                showsProgress: monitor.isCheckInProgress,
                shortcut: "⌘R"
            ) {
                monitor.checkNow()
            }

            actionButton(
                id: "pause",
                title: monitor.isPaused ? L10n.string(.resumeMonitoring, language: settings.language) : L10n.string(.pauseMonitoring, language: settings.language),
                icon: monitor.isPaused ? "play.fill" : "pause.fill",
                shortcut: nil
            ) {
                if monitor.isPaused {
                    monitor.resumeMonitoring()
                } else {
                    monitor.pauseMonitoring()
                }
            }

            Divider()
                .padding(.vertical, 3)

            actionButton(
                id: "history",
                title: L10n.string(.connectionHistory, language: settings.language),
                icon: "chart.bar.xaxis",
                shortcut: "⌘H"
            ) {
                WindowManager.shared.showHistory()
            }

            actionButton(
                id: "settings",
                title: L10n.string(.settings, language: settings.language),
                icon: "gearshape",
                shortcut: "⌘,"
            ) {
                WindowManager.shared.showSettings()
            }

            Divider()
                .padding(.vertical, 3)

            actionButton(
                id: "quit",
                title: L10n.string(.quit, language: settings.language),
                icon: "power",
                shortcut: "⌘Q",
                isDestructive: true
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func actionButton(
        id: String,
        title: String,
        icon: String?,
        showsProgress: Bool = false,
        shortcut: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = vm.hoveredAction == id

        return Button(action: action) {
            HStack(spacing: 8) {
                if showsProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDestructive ? .red : (isHovered ? .primary : .secondary))
                        .frame(width: 16)
                }

                Text(title)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundColor(isDestructive ? .red : .primary)

                Spacer()

                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? (isDestructive ? Color.red.opacity(0.12) : Color.primary.opacity(0.07)) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            vm.hoveredAction = hovering ? id : nil
        }
    }

    private func formattedLastCheck() -> String {
        guard let last = monitor.lastCheckDate else {
            return L10n.string(.notAvailable, language: settings.language)
        }
        let elapsed = Int(max(0, vm.now.timeIntervalSince(last)))
        if elapsed < 2 {
            return L10n.string(.justNow, language: settings.language)
        }
        return String(format: L10n.string(.secondsAgo, language: settings.language), elapsed)
    }
}

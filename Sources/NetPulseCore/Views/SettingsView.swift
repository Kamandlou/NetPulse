import SwiftUI
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case notifications
    case connectivity
    case history
    case about

    public var id: String { rawValue }

    public func localizedTitle(for language: AppLanguage) -> String {
        switch self {
        case .general: return L10n.string(.tabGeneral, language: language)
        case .notifications: return L10n.string(.tabNotifications, language: language)
        case .connectivity: return L10n.string(.tabConnectivity, language: language)
        case .history: return L10n.string(.tabHistory, language: language)
        case .about: return L10n.string(.tabAbout, language: language)
        }
    }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .connectivity: return "network"
        case .history: return "clock.arrow.circlepath"
        case .about: return "info.circle"
        }
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: SettingsTab = .general
    @Published public var showingAddEndpoint = false
    @Published public var editingEndpoint: ConnectivityEndpoint?
    @Published public var showingClearHistoryAlert = false
    @Published public var endpointTestResults: [UUID: EndpointCheckResult] = [:]
    @Published public var isTestingEndpoints = false
    @Published public var exportMessage: String?

    public init() {}
}

public struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var monitor: ConnectivityMonitor
    @ObservedObject var historyStore: OutageHistoryStore
    @StateObject private var vm = SettingsViewModel()

    @MainActor
    public init(
        settings: SettingsManager? = nil,
        monitor: ConnectivityMonitor? = nil,
        historyStore: OutageHistoryStore? = nil
    ) {
        self.settings = settings ?? .shared
        self.monitor = monitor ?? .shared
        self.historyStore = historyStore ?? .shared
    }

    public var body: some View {
        TabView(selection: $vm.selectedTab) {
            generalTab
                .tabItem {
                    Label(SettingsTab.general.localizedTitle(for: settings.language), systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)

            notificationsTab
                .tabItem {
                    Label(SettingsTab.notifications.localizedTitle(for: settings.language), systemImage: SettingsTab.notifications.icon)
                }
                .tag(SettingsTab.notifications)

            connectivityTab
                .tabItem {
                    Label(SettingsTab.connectivity.localizedTitle(for: settings.language), systemImage: SettingsTab.connectivity.icon)
                }
                .tag(SettingsTab.connectivity)

            historyTab
                .tabItem {
                    Label(SettingsTab.history.localizedTitle(for: settings.language), systemImage: SettingsTab.history.icon)
                }
                .tag(SettingsTab.history)

            aboutTab
                .tabItem {
                    Label(SettingsTab.about.localizedTitle(for: settings.language), systemImage: SettingsTab.about.icon)
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 580, height: 500)
        .padding(16)
        .environment(\.layoutDirection, settings.language.layoutDirection)
        .preferredColorScheme(settings.appearance.colorScheme)
        .sheet(isPresented: $vm.showingAddEndpoint) {
            EndpointEditorSheet(settings: settings) { newEndpoint in
                settings.endpoints.append(newEndpoint)
            }
        }
        .sheet(item: $vm.editingEndpoint) { ep in
            EndpointEditorSheet(settings: settings, endpoint: ep) { updated in
                if let idx = settings.endpoints.firstIndex(where: { $0.id == updated.id }) {
                    settings.endpoints[idx] = updated
                }
            }
        }
        .alert(
            L10n.string(.clearHistoryConfirmTitle, language: settings.language),
            isPresented: $vm.showingClearHistoryAlert
        ) {
            Button(L10n.string(.delete, language: settings.language), role: .destructive) {
                historyStore.clearAllHistory()
            }
            Button(L10n.string(.cancel, language: settings.language), role: .cancel) {}
        } message: {
            Text(L10n.string(.clearHistoryConfirmMessage, language: settings.language))
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Toggle(L10n.string(.launchAtLogin, language: settings.language), isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        _ = LaunchAtLoginManager.shared.setEnabled(newValue)
                    }
                ))

                Toggle(L10n.string(.startMonitoringAuto, language: settings.language), isOn: $settings.startMonitoringAutomatically)

                Toggle(L10n.string(.showLatencyMenuBar, language: settings.language), isOn: $settings.showLatencyInMenuBar)

                Toggle(L10n.string(.showDockIcon, language: settings.language), isOn: Binding(
                    get: { settings.showDockIcon },
                    set: { val in
                        settings.showDockIcon = val
                        NSApp.setActivationPolicy(val ? .regular : .accessory)
                    }
                ))

                Toggle(L10n.string(.enableMonitoring, language: settings.language), isOn: $settings.isMonitoringEnabled)
            }

            Section {
                Picker(L10n.string(.language, language: settings.language), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }

                Picker(L10n.string(.appearance, language: settings.language), selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { app in
                        Text(app.localizedName(for: settings.language)).tag(app)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Notifications Tab

    private var notificationsTab: some View {
        Form {
            Section {
                Toggle(L10n.string(.enableNotifications, language: settings.language), isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { _, enabled in
                        if enabled {
                            Task {
                                _ = await NotificationManager.shared.requestAuthorization()
                            }
                        }
                    }

                Toggle(L10n.string(.notifyOnDisconnect, language: settings.language), isOn: $settings.notifyOnDisconnect)
                    .disabled(!settings.notificationsEnabled)

                Toggle(L10n.string(.notifyOnReconnect, language: settings.language), isOn: $settings.notifyOnReconnect)
                    .disabled(!settings.notificationsEnabled)

                Toggle(L10n.string(.playNotificationSounds, language: settings.language), isOn: $settings.playNotificationSounds)
                    .disabled(!settings.notificationsEnabled)

                Toggle(L10n.string(.includeDowntime, language: settings.language), isOn: $settings.includeDowntimeInNotification)
                    .disabled(!settings.notificationsEnabled || !settings.notifyOnReconnect)
            }

            Section {
                Picker(L10n.string(.minimumOutageDuration, language: settings.language), selection: $settings.minimumOutageDurationForNotification) {
                    Text("Immediate (0s)").tag(0.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("60 seconds").tag(60.0)
                }
                .disabled(!settings.notificationsEnabled)

                Picker(L10n.string(.notificationCooldown, language: settings.language), selection: $settings.notificationCooldown) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("60 seconds").tag(60.0)
                }
                .disabled(!settings.notificationsEnabled)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Connectivity Tab

    private var connectivityTab: some View {
        VStack(spacing: 12) {
            Form {
                Section {
                    Picker(L10n.string(.checkingStrategy, language: settings.language), selection: $settings.checkingStrategy) {
                        ForEach(CheckingStrategy.allCases) { strat in
                            Text(strat.localizedName(for: settings.language)).tag(strat)
                        }
                    }

                    Picker(L10n.string(.checkInterval, language: settings.language), selection: $settings.checkInterval) {
                        Text("2 seconds").tag(2.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                        Text("15 seconds").tag(15.0)
                        Text("30 seconds").tag(30.0)
                        Text("60 seconds").tag(60.0)
                    }

                    Picker(L10n.string(.requestTimeout, language: settings.language), selection: $settings.requestTimeout) {
                        Text("1 second").tag(1.0)
                        Text("2 seconds").tag(2.0)
                        Text("3 seconds").tag(3.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                    }

                    Stepper("\(L10n.string(.consecutiveFailures, language: settings.language)): \(settings.consecutiveFailuresThreshold)", value: $settings.consecutiveFailuresThreshold, in: 1...5)

                    Stepper("\(L10n.string(.consecutiveSuccesses, language: settings.language)): \(settings.consecutiveSuccessesThreshold)", value: $settings.consecutiveSuccessesThreshold, in: 1...5)
                }
            }
            .formStyle(.grouped)
            .frame(height: 200)

            // Endpoints List
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.string(.endpoints, language: settings.language))
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        testAllEndpoints()
                    }) {
                        Label(L10n.string(.testSelected, language: settings.language), systemImage: "bolt.fill")
                    }
                    .disabled(vm.isTestingEndpoints)

                    Button(action: {
                        settings.resetEndpointsToDefaults()
                    }) {
                        Text(L10n.string(.resetDefaults, language: settings.language))
                    }

                    Button(action: {
                        vm.showingAddEndpoint = true
                    }) {
                        Image(systemName: "plus")
                    }
                }

                List {
                    ForEach($settings.endpoints) { $ep in
                        HStack {
                            Toggle("", isOn: $ep.isEnabled)
                                .labelsHidden()

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ep.name)
                                    .fontWeight(.medium)
                                Text(ep.url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if let result = vm.endpointTestResults[ep.id] {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(result.isSuccessful ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(result.isSuccessful ? "\(Int(result.latencyMs))ms" : L10n.string(.testFailure, language: settings.language))
                                        .font(.caption2)
                                        .foregroundColor(result.isSuccessful ? .green : .red)
                                }
                            }

                            Button(action: {
                                vm.editingEndpoint = ep
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                settings.endpoints.removeAll(where: { $0.id == ep.id })
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
                .frame(maxHeight: 180)
            }
        }
    }

    private func testAllEndpoints() {
        vm.isTestingEndpoints = true
        vm.endpointTestResults.removeAll()
        let timeout = settings.requestTimeout
        let probe = URLSessionConnectivityProbe()

        Task {
            for ep in settings.endpoints {
                let res = await probe.probe(endpoint: ep, timeout: timeout)
                await MainActor.run {
                    self.vm.endpointTestResults[ep.id] = res
                }
            }
            await MainActor.run {
                self.vm.isTestingEndpoints = false
            }
        }
    }

    // MARK: - History Tab

    private var historyTab: some View {
        Form {
            Section {
                Toggle(L10n.string(.enableLocalHistory, language: settings.language), isOn: $settings.historyEnabled)

                Picker(L10n.string(.historyRetention, language: settings.language), selection: $settings.historyRetention) {
                    ForEach(HistoryRetention.allCases) { ret in
                        Text(ret.localizedName(for: settings.language)).tag(ret)
                    }
                }
            }

            Section {
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

                Button(role: .destructive, action: {
                    vm.showingClearHistoryAlert = true
                }) {
                    Label(L10n.string(.clearAllHistory, language: settings.language), systemImage: "trash")
                        .foregroundColor(.red)
                }
            }

            if let msg = vm.exportMessage {
                Section {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func exportFile(content: String, defaultFilename: String) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = defaultFilename
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    self.vm.exportMessage = "Exported successfully to \(url.lastPathComponent)"
                } catch {
                    self.vm.exportMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.2), Color.indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)

                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .cornerRadius(16)
                } else {
                    Image(systemName: "wifi")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                }
            }

            VStack(spacing: 4) {
                Text(L10n.string(.appName, language: settings.language))
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Version 1.3.0 (Build 6)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(L10n.string(.appDescription, language: settings.language))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Divider()
                .frame(width: 320)

            VStack(spacing: 6) {
                Text("Designed & Built for macOS 14 Sonoma and newer")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Pure Native Swift • Apple Network Framework • Privacy-First")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Developer: \(L10n.string(.developerName, language: settings.language))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Button(action: {
                    if let url = URL(string: "https://github.com/Kamandlou/NetPulse") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("GitHub Repository", systemImage: "link")
                        .font(.caption)
                }
                .buttonStyle(.link)
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

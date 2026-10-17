import Foundation
import Testing
@testable import NetPulseCore

@Suite struct SettingsManagerTests {

    @Test @MainActor func defaultsAndStrategySwitch() {
        let testDefaults = UserDefaults(suiteName: "test_suite_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        let settings = SettingsManager(defaults: testDefaults)
        #expect(settings.consecutiveFailuresThreshold == 2)
        #expect(settings.consecutiveSuccessesThreshold == 2)
        #expect(settings.checkingStrategy == .balanced)
        #expect(settings.checkInterval == 5.0)

        // Switch to fast strategy
        settings.checkingStrategy = .fast
        #expect(settings.checkInterval == 2.0)
        #expect(settings.requestTimeout == 2.0)

        // Switch to battery saving
        settings.checkingStrategy = .batterySaving
        #expect(settings.checkInterval == 15.0)
        #expect(settings.requestTimeout == 4.0)

        // Custom endpoints
        settings.resetEndpointsToDefaults()
        #expect(settings.endpoints.count == 3)
    }
}

@Suite struct ConnectivityMonitorIntegrationTests {

    @Test @MainActor func endToEndStateTransitionsAndNotifications() async {
        let testDefaults = UserDefaults(suiteName: "monitor_test_\(UUID().uuidString)")!
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("monitor_outages_\(UUID().uuidString).json")
        defer {
            testDefaults.removePersistentDomain(forName: testDefaults.description)
            try? FileManager.default.removeItem(at: tempURL)
        }

        let settings = SettingsManager(defaults: testDefaults)
        settings.minimumOutageDurationForNotification = 0 // Instant notification
        settings.notificationCooldown = 0
        settings.consecutiveFailuresThreshold = 1
        settings.consecutiveSuccessesThreshold = 1

        let probe = MockConnectivityProbe()
        let pathMonitor = MockNetworkPathMonitor()
        let notifManager = MockNotificationManager()
        let historyStore = OutageHistoryStore(fileURL: tempURL, settings: settings)
        let sleepWake = MockSleepWakeObserver()

        let monitor = ConnectivityMonitor(
            pathMonitor: pathMonitor,
            probe: probe,
            settings: settings,
            historyStore: historyStore,
            notificationManager: notifManager,
            sleepWakeObserver: sleepWake
        )
        monitor.start()
        defer { monitor.stop() }

        // Check 1: probe succeeds -> online
        probe.defaultSuccess = true
        monitor.performCheck()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(monitor.state == .online)
        // Initial online does NOT trigger reconnect notification
        #expect(notifManager.reconnectNotifications.isEmpty)

        // Check 2: probe fails -> offline
        probe.defaultSuccess = false
        probe.defaultErrorMessage = "Simulated internet loss"
        monitor.performCheck()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(monitor.state == .offline)
        #expect(historyStore.ongoingOutage != nil)
        #expect(notifManager.disconnectNotifications.count == 1)
        #expect(notifManager.disconnectNotifications.first?.reason == "Simulated internet loss")

        // Check 3: probe succeeds -> restored
        probe.defaultSuccess = true
        monitor.performCheck()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(monitor.state == .online)
        #expect(historyStore.ongoingOutage == nil)
        #expect(notifManager.reconnectNotifications.count == 1)

        // Check 4: Turning off Wi-Fi -> interface becomes .none, unsatisfied
        pathMonitor.simulateChange(to: NetworkPathInfo(isSatisfied: false, interfaceType: .none))
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(monitor.state == .offline)
        #expect(historyStore.ongoingOutage != nil)
        #expect(notifManager.disconnectNotifications.count == 2)
    }
}

import SwiftUI
import AppKit
import NetPulseCore

@main
struct NetPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = ConnectivityMonitor.shared
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var historyStore = OutageHistoryStore.shared

    init() {
        if !SingleInstanceGuard.enforceSingleInstance() {
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopupView(monitor: monitor, settings: settings, historyStore: historyStore)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: monitor.state.menuBarSymbol)
                if settings.showLatencyInMenuBar, monitor.state == .online, let latency = monitor.currentLatencyMs {
                    Text("\(Int(latency))ms")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, monitor: monitor, historyStore: historyStore)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsManager.shared

        // Set activation policy: accessory (menu bar only) or regular (shows in dock)
        if !settings.showDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

        // Start connectivity monitor if set to start automatically
        if settings.startMonitoringAutomatically {
            ConnectivityMonitor.shared.start()
        }

        // Request notification authorization
        if settings.notificationsEnabled {
            Task {
                _ = await NotificationManager.shared.requestAuthorization()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ConnectivityMonitor.shared.stop()
    }
}

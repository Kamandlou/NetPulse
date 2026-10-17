import SwiftUI
import AppKit

@MainActor
public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()

    private var settingsWindowController: NSWindowController?
    private var historyWindowController: NSWindowController?

    public init() {}

    public func showSettings() {
        if let controller = settingsWindowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(SettingsManager.shared)
            .environmentObject(ConnectivityMonitor.shared)
            .environmentObject(OutageHistoryStore.shared)

        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "NetPulse Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 580, height: 520))

        let controller = NSWindowController(window: window)
        self.settingsWindowController = controller

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showHistory() {
        if let controller = historyWindowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let historyView = HistoryView()
            .environmentObject(SettingsManager.shared)
            .environmentObject(OutageHistoryStore.shared)
            .environmentObject(ConnectivityMonitor.shared)

        let hostingController = NSHostingController(rootView: historyView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "NetPulse Connection History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 650, height: 480)
        window.setContentSize(NSSize(width: 760, height: 560))

        let controller = NSWindowController(window: window)
        self.historyWindowController = controller

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

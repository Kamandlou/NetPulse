import Foundation
import SwiftUI
import Combine

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    private let defaults: UserDefaults

    public enum Keys {
        public static let launchAtLogin = "NetPulse_launchAtLogin"
        public static let startMonitoringAutomatically = "NetPulse_startMonitoringAutomatically"
        public static let showDockIcon = "NetPulse_showDockIcon"
        public static let showLatencyInMenuBar = "NetPulse_showLatencyInMenuBar"
        public static let isMonitoringEnabled = "NetPulse_isMonitoringEnabled"
        public static let language = "NetPulse_language"
        public static let appearance = "NetPulse_appearance"

        public static let notificationsEnabled = "NetPulse_notificationsEnabled"
        public static let notifyOnDisconnect = "NetPulse_notifyOnDisconnect"
        public static let notifyOnReconnect = "NetPulse_notifyOnReconnect"
        public static let playNotificationSounds = "NetPulse_playNotificationSounds"
        public static let includeDowntimeInNotification = "NetPulse_includeDowntimeInNotification"
        public static let minOutageDuration = "NetPulse_minOutageDuration"
        public static let notificationCooldown = "NetPulse_notificationCooldown"

        public static let checkInterval = "NetPulse_checkInterval"
        public static let requestTimeout = "NetPulse_requestTimeout"
        public static let consecutiveFailuresThreshold = "NetPulse_consecutiveFailuresThreshold"
        public static let consecutiveSuccessesThreshold = "NetPulse_consecutiveSuccessesThreshold"
        public static let checkingStrategy = "NetPulse_checkingStrategy"
        public static let endpoints = "NetPulse_endpoints"

        public static let historyEnabled = "NetPulse_historyEnabled"
        public static let historyRetention = "NetPulse_historyRetention"
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published public var startMonitoringAutomatically: Bool {
        didSet { defaults.set(startMonitoringAutomatically, forKey: Keys.startMonitoringAutomatically) }
    }

    @Published public var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Keys.showDockIcon) }
    }

    @Published public var showLatencyInMenuBar: Bool {
        didSet { defaults.set(showLatencyInMenuBar, forKey: Keys.showLatencyInMenuBar) }
    }

    @Published public var isMonitoringEnabled: Bool {
        didSet { defaults.set(isMonitoringEnabled, forKey: Keys.isMonitoringEnabled) }
    }

    @Published public var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published public var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published public var notifyOnDisconnect: Bool {
        didSet { defaults.set(notifyOnDisconnect, forKey: Keys.notifyOnDisconnect) }
    }

    @Published public var notifyOnReconnect: Bool {
        didSet { defaults.set(notifyOnReconnect, forKey: Keys.notifyOnReconnect) }
    }

    @Published public var playNotificationSounds: Bool {
        didSet { defaults.set(playNotificationSounds, forKey: Keys.playNotificationSounds) }
    }

    @Published public var includeDowntimeInNotification: Bool {
        didSet { defaults.set(includeDowntimeInNotification, forKey: Keys.includeDowntimeInNotification) }
    }

    @Published public var minimumOutageDurationForNotification: TimeInterval {
        didSet { defaults.set(minimumOutageDurationForNotification, forKey: Keys.minOutageDuration) }
    }

    @Published public var notificationCooldown: TimeInterval {
        didSet { defaults.set(notificationCooldown, forKey: Keys.notificationCooldown) }
    }

    @Published public var checkInterval: TimeInterval {
        didSet { defaults.set(checkInterval, forKey: Keys.checkInterval) }
    }

    @Published public var requestTimeout: TimeInterval {
        didSet { defaults.set(requestTimeout, forKey: Keys.requestTimeout) }
    }

    @Published public var consecutiveFailuresThreshold: Int {
        didSet { defaults.set(consecutiveFailuresThreshold, forKey: Keys.consecutiveFailuresThreshold) }
    }

    @Published public var consecutiveSuccessesThreshold: Int {
        didSet { defaults.set(consecutiveSuccessesThreshold, forKey: Keys.consecutiveSuccessesThreshold) }
    }

    @Published public var checkingStrategy: CheckingStrategy {
        didSet {
            defaults.set(checkingStrategy.rawValue, forKey: Keys.checkingStrategy)
            // Adjust interval & timeout to match strategy defaults if user switches strategy
            checkInterval = checkingStrategy.defaultInterval
            requestTimeout = checkingStrategy.defaultTimeout
        }
    }

    @Published public var endpoints: [ConnectivityEndpoint] {
        didSet {
            if let data = try? JSONEncoder().encode(endpoints) {
                defaults.set(data, forKey: Keys.endpoints)
            }
        }
    }

    @Published public var historyEnabled: Bool {
        didSet { defaults.set(historyEnabled, forKey: Keys.historyEnabled) }
    }

    @Published public var historyRetention: HistoryRetention {
        didSet { defaults.set(historyRetention.rawValue, forKey: Keys.historyRetention) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.startMonitoringAutomatically = defaults.object(forKey: Keys.startMonitoringAutomatically) as? Bool ?? true
        self.showDockIcon = defaults.object(forKey: Keys.showDockIcon) as? Bool ?? false
        self.showLatencyInMenuBar = defaults.object(forKey: Keys.showLatencyInMenuBar) as? Bool ?? false
        self.isMonitoringEnabled = defaults.object(forKey: Keys.isMonitoringEnabled) as? Bool ?? true

        if let langStr = defaults.string(forKey: Keys.language), let lang = AppLanguage(rawValue: langStr) {
            self.language = lang
        } else {
            self.language = .english
        }

        if let appStr = defaults.string(forKey: Keys.appearance), let app = AppAppearance(rawValue: appStr) {
            self.appearance = app
        } else {
            self.appearance = .system
        }

        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.notifyOnDisconnect = defaults.object(forKey: Keys.notifyOnDisconnect) as? Bool ?? true
        self.notifyOnReconnect = defaults.object(forKey: Keys.notifyOnReconnect) as? Bool ?? true
        self.playNotificationSounds = defaults.object(forKey: Keys.playNotificationSounds) as? Bool ?? true
        self.includeDowntimeInNotification = defaults.object(forKey: Keys.includeDowntimeInNotification) as? Bool ?? true
        self.minimumOutageDurationForNotification = defaults.object(forKey: Keys.minOutageDuration) as? TimeInterval ?? 0.0
        self.notificationCooldown = defaults.object(forKey: Keys.notificationCooldown) as? TimeInterval ?? 5.0

        self.checkInterval = defaults.object(forKey: Keys.checkInterval) as? TimeInterval ?? 5.0
        self.requestTimeout = defaults.object(forKey: Keys.requestTimeout) as? TimeInterval ?? 3.0
        self.consecutiveFailuresThreshold = defaults.object(forKey: Keys.consecutiveFailuresThreshold) as? Int ?? 2
        self.consecutiveSuccessesThreshold = defaults.object(forKey: Keys.consecutiveSuccessesThreshold) as? Int ?? 2

        if let stratStr = defaults.string(forKey: Keys.checkingStrategy), let strat = CheckingStrategy(rawValue: stratStr) {
            self.checkingStrategy = strat
        } else {
            self.checkingStrategy = .balanced
        }

        if let data = defaults.data(forKey: Keys.endpoints),
           let decoded = try? JSONDecoder().decode([ConnectivityEndpoint].self, from: data),
           !decoded.isEmpty {
            self.endpoints = decoded
        } else {
            self.endpoints = ConnectivityEndpoint.defaults
        }

        self.historyEnabled = defaults.object(forKey: Keys.historyEnabled) as? Bool ?? true

        if let retStr = defaults.string(forKey: Keys.historyRetention), let ret = HistoryRetention(rawValue: retStr) {
            self.historyRetention = ret
        } else {
            self.historyRetention = .oneMonth
        }
    }

    public func resetEndpointsToDefaults() {
        self.endpoints = ConnectivityEndpoint.defaults
    }
}

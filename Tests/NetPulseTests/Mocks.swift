import Foundation
@testable import NetPulseCore

public final class MockConnectivityProbe: ConnectivityProbing, @unchecked Sendable {
    public var results: [EndpointCheckResult] = []
    public var defaultSuccess: Bool = true
    public var defaultLatency: Double = 25.0
    public var defaultStatusCode: Int? = 200
    public var defaultErrorMessage: String? = nil
    public var probeCallCount: Int = 0

    public init() {}

    public func probe(endpoint: ConnectivityEndpoint, timeout: TimeInterval) async -> EndpointCheckResult {
        probeCallCount += 1
        if !results.isEmpty {
            return results.removeFirst()
        }
        return EndpointCheckResult(
            endpoint: endpoint,
            isSuccessful: defaultSuccess,
            latencyMs: defaultLatency,
            statusCode: defaultStatusCode,
            errorMessage: defaultErrorMessage,
            timestamp: Date()
        )
    }
}

public final class MockNetworkPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    private var handler: (@Sendable (NetworkPathInfo) -> Void)?
    public var currentInfo: NetworkPathInfo

    public init(initialInfo: NetworkPathInfo = NetworkPathInfo(isSatisfied: true, interfaceType: .wifi, ssid: "Test-WiFi")) {
        self.currentInfo = initialInfo
    }

    public func start(onUpdate: @escaping @Sendable (NetworkPathInfo) -> Void) {
        self.handler = onUpdate
        onUpdate(currentInfo)
    }

    public func stop() {
        self.handler = nil
    }

    public func currentPathInfo() -> NetworkPathInfo {
        return currentInfo
    }

    public func simulateChange(to info: NetworkPathInfo) {
        self.currentInfo = info
        handler?(info)
    }
}

@MainActor
public final class MockNotificationManager: NotificationManaging {
    public struct DisconnectNotification: Equatable {
        public let date: Date
        public let reason: String?
        public let language: AppLanguage
    }

    public struct ReconnectNotification: Equatable {
        public let downtime: TimeInterval?
        public let language: AppLanguage
    }

    public var disconnectNotifications: [DisconnectNotification] = []
    public var reconnectNotifications: [ReconnectNotification] = []
    public var authorizationResult: Bool = true

    public init() {}

    public func requestAuthorization() async -> Bool {
        return authorizationResult
    }

    public func sendDisconnectionNotification(at date: Date, reason: String?, language: AppLanguage) {
        disconnectNotifications.append(DisconnectNotification(date: date, reason: reason, language: language))
    }

    public func sendReconnectionNotification(downtime: TimeInterval?, language: AppLanguage) {
        reconnectNotifications.append(ReconnectNotification(downtime: downtime, language: language))
    }
}

public final class MockSleepWakeObserver: SleepWakeObserving, @unchecked Sendable {
    private var sleepHandler: (@Sendable (Date) -> Void)?
    private var wakeHandler: (@Sendable (Date, TimeInterval) -> Void)?

    public init() {}

    public func start(
        onSleep: @escaping @Sendable (Date) -> Void,
        onWake: @escaping @Sendable (Date, TimeInterval) -> Void
    ) {
        self.sleepHandler = onSleep
        self.wakeHandler = onWake
    }

    public func stop() {
        self.sleepHandler = nil
        self.wakeHandler = nil
    }

    public func simulateSleep(at date: Date = Date()) {
        sleepHandler?(date)
    }

    public func simulateWake(at date: Date = Date(), duration: TimeInterval) {
        wakeHandler?(date, duration)
    }
}

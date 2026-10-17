import Foundation
import SwiftUI
import Combine

@MainActor
public final class ConnectivityMonitor: ObservableObject {
    public static let shared = ConnectivityMonitor()

    @Published public private(set) var state: ConnectionState = .unknown
    @Published public private(set) var currentInterface: NetworkInterfaceType = .none
    @Published public private(set) var currentSSID: String?
    @Published public private(set) var currentLatencyMs: Double?
    @Published public private(set) var lastCheckDate: Date?
    @Published public private(set) var lastFailureReason: String?
    @Published public private(set) var uptimeStartDate: Date?
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var isCheckInProgress: Bool = false
    @Published public private(set) var isVPNConnected: Bool = false
    @Published public private(set) var vpnInterfaceName: String? = nil

    private var stateMachine: ConnectivityStateMachine
    private let pathMonitor: NetworkPathMonitoring
    private let probe: ConnectivityProbing
    private let settings: SettingsManager
    private let historyStore: OutageHistoryStore
    private let notificationManager: NotificationManaging
    private let sleepWakeObserver: SleepWakeObserving

    private var checkTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var checkGeneration: UInt64 = 0
    private var lastPathChangeTime: Date = .distantPast

    @MainActor
    public init(
        pathMonitor: NetworkPathMonitoring = SystemNetworkPathMonitor(),
        probe: ConnectivityProbing = URLSessionConnectivityProbe(),
        settings: SettingsManager? = nil,
        historyStore: OutageHistoryStore? = nil,
        notificationManager: NotificationManaging? = nil,
        sleepWakeObserver: SleepWakeObserving = SleepWakeObserver()
    ) {
        let activeSettings = settings ?? .shared
        let activeHistory = historyStore ?? .shared
        let activeNotifications = notificationManager ?? NotificationManager.shared

        self.pathMonitor = pathMonitor
        self.probe = probe
        self.settings = activeSettings
        self.historyStore = activeHistory
        self.notificationManager = activeNotifications
        self.sleepWakeObserver = sleepWakeObserver

        self.stateMachine = ConnectivityStateMachine(
            consecutiveFailuresThreshold: activeSettings.consecutiveFailuresThreshold,
            consecutiveSuccessesThreshold: activeSettings.consecutiveSuccessesThreshold
        )

        setupSubscriptions()
    }

    public func start() {
        guard settings.isMonitoringEnabled else {
            isPaused = true
            return
        }

        // Start Path Monitor
        pathMonitor.start { [weak self] pathInfo in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(pathInfo)
            }
        }

        // Start Sleep/Wake Observer
        sleepWakeObserver.start(
            onSleep: { [weak self] sleepDate in
                Task { @MainActor [weak self] in
                    self?.handleSystemSleep(sleepDate)
                }
            },
            onWake: { [weak self] wakeDate, sleepDuration in
                Task { @MainActor [weak self] in
                    self?.handleSystemWake(wakeDate, sleepDuration: sleepDuration)
                }
            }
        )

        scheduleNextCheck(interval: 0.1) // Check immediately on launch
    }

    public func stop() {
        checkTimer?.cancel()
        checkTimer = nil
        pathMonitor.stop()
        sleepWakeObserver.stop()
    }

    public func pauseMonitoring() {
        isPaused = true
        checkTimer?.cancel()
        checkTimer = nil
    }

    public func resumeMonitoring() {
        isPaused = false
        performCheck()
        scheduleNextCheck(interval: settings.checkInterval)
    }

    public func checkNow() {
        guard !isCheckInProgress else { return }
        performCheck()
    }

    // MARK: - Internal Logic

    private func setupSubscriptions() {
        // Observe settings changes
        settings.$consecutiveFailuresThreshold
            .combineLatest(settings.$consecutiveSuccessesThreshold)
            .sink { [weak self] failures, successes in
                self?.stateMachine.updateThresholds(failures: failures, successes: successes)
            }
            .store(in: &cancellables)

        settings.$checkInterval
            .dropFirst()
            .sink { [weak self] interval in
                guard let self = self, !self.isPaused else { return }
                self.scheduleNextCheck(interval: interval)
            }
            .store(in: &cancellables)

        settings.$isMonitoringEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.resumeMonitoring()
                } else {
                    self?.pauseMonitoring()
                }
            }
            .store(in: &cancellables)
    }

    private func handlePathUpdate(_ pathInfo: NetworkPathInfo) {
        let oldInterface = currentInterface
        currentInterface = pathInfo.interfaceType
        currentSSID = pathInfo.ssid

        let now = Date()

        // Check for immediate physical disconnection (Wi-Fi turned off or interface down)
        // Physical disconnection must NEVER be dropped by debounce.
        if !pathInfo.isSatisfied || pathInfo.interfaceType == .none {
            lastPathChangeTime = now
            let reason = (pathInfo.interfaceType == .none) ? "Network interface disconnected" : "Network path unsatisfied"
            lastFailureReason = reason
            currentLatencyMs = nil
            refreshVPNStatus()
            if let transition = stateMachine.markImmediateOffline(reason: reason, now: now) {
                self.state = stateMachine.currentState
                handleTransition(transition)
            } else {
                self.state = stateMachine.currentState
            }
            return
        }

        // Debounce rapid path updates (300ms)
        guard now.timeIntervalSince(lastPathChangeTime) > 0.3 else { return }
        lastPathChangeTime = now

        if oldInterface != pathInfo.interfaceType {
            stateMachine.resetCounters()
        }

        // Immediate check when network interface or path is satisfied
        if !isPaused {
            performCheck()
        }
    }

    private func handleSystemSleep(_ date: Date) {
        checkTimer?.cancel()
        checkTimer = nil
    }

    private func handleSystemWake(_ date: Date, sleepDuration: TimeInterval) {
        historyStore.deductSleepDuration(sleepDuration)
        stateMachine.resetCounters()
        if !isPaused {
            performCheck()
            scheduleNextCheck(interval: settings.checkInterval)
        }
    }

    private func scheduleNextCheck(interval: TimeInterval) {
        checkTimer?.cancel()
        guard !isPaused else { return }

        checkTimer = Timer.publish(every: max(1.0, interval), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performCheck()
            }
    }

    public func refreshVPNStatus() {
        let vpnInfo = VPNDetector.shared.detectVPN()
        self.isVPNConnected = vpnInfo.isConnected
        self.vpnInterfaceName = vpnInfo.interfaceName
    }

    public func performCheck() {
        guard !isPaused, !isCheckInProgress else { return }
        isCheckInProgress = true

        // Only mark state as checking on initial launch before any state is confirmed
        // to prevent distracting menu bar icon flickering on routine periodic checks.
        if !stateMachine.isInitialStateEstablished {
            stateMachine.markChecking()
            state = stateMachine.currentState
        }

        checkGeneration &+= 1
        let currentGen = checkGeneration

        let endpoints = settings.endpoints.filter(\.isEnabled)
        let timeout = settings.requestTimeout

        Task { [weak self] in
            guard let self = self else { return }

            // If no endpoints enabled, fall back to defaults
            let activeEndpoints = endpoints.isEmpty ? ConnectivityEndpoint.defaults : endpoints

            var overallSuccess = false
            var bestLatency: Double?
            var primaryFailureReason: String?

            for endpoint in activeEndpoints {
                let result = await self.probe.probe(endpoint: endpoint, timeout: timeout)
                if result.isSuccessful {
                    overallSuccess = true
                    bestLatency = min(bestLatency ?? Double.infinity, result.latencyMs)
                    break // Healthy endpoint confirmed internet access
                } else {
                    if primaryFailureReason == nil {
                        primaryFailureReason = result.errorMessage
                    }
                }
            }

            await MainActor.run { [weak self] in
                guard let self = self, self.checkGeneration == currentGen else { return }
                self.processCheckResult(
                    isSuccess: overallSuccess,
                    latency: bestLatency,
                    failureReason: primaryFailureReason
                )
                self.isCheckInProgress = false
            }
        }
    }

    private func processCheckResult(
        isSuccess: Bool,
        latency: Double?,
        failureReason: String?
    ) {
        lastCheckDate = Date()
        currentLatencyMs = latency
        if !isSuccess {
            lastFailureReason = failureReason
        }

        // Refresh VPN state on every check
        refreshVPNStatus()

        let transition = stateMachine.recordResult(
            isSuccess: isSuccess,
            failureReason: failureReason,
            now: Date()
        )

        self.state = stateMachine.currentState

        if let transition = transition {
            handleTransition(transition)
        }

        // Adaptive scheduling: if state is unstable, recheck quickly (1.5s) to confirm transition
        if stateMachine.currentState == .unstable && !isPaused {
            scheduleNextCheck(interval: 1.5)
        } else if !isPaused {
            scheduleNextCheck(interval: settings.checkInterval)
        }
    }

    private func handleTransition(_ transition: StateTransition) {
        if transition.isConfirmedDisconnection {
            uptimeStartDate = nil
            let outage = historyStore.recordOutageStarted(
                startDate: transition.timestamp,
                interfaceType: currentInterface,
                technicalReason: transition.technicalReason
            )

            // Notify if threshold exceeded
            if settings.minimumOutageDurationForNotification == 0 {
                notificationManager.sendDisconnectionNotification(
                    at: transition.timestamp,
                    reason: transition.technicalReason,
                    language: settings.language
                )
            } else {
                // If min outage duration > 0, schedule delayed notification check
                let minDuration = settings.minimumOutageDurationForNotification
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(minDuration * 1_000_000_000))
                    await MainActor.run { [weak self] in
                        guard let self = self, self.state == .offline else { return }
                        self.notificationManager.sendDisconnectionNotification(
                            at: outage.startDate,
                            reason: outage.technicalReason,
                            language: self.settings.language
                        )
                    }
                }
            }
        } else if transition.isConfirmedReconnection {
            uptimeStartDate = Date()
            let endedOutage = historyStore.recordOutageEnded(endDate: transition.timestamp)
            let downtime = endedOutage?.duration

            notificationManager.sendReconnectionNotification(
                downtime: downtime,
                language: settings.language
            )
        } else if transition.toState == .online && uptimeStartDate == nil {
            uptimeStartDate = Date()
        }
    }
}

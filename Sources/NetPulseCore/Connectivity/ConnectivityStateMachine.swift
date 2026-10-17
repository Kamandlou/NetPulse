import Foundation

public struct StateTransition: Equatable, Sendable {
    public let fromState: ConnectionState
    public let toState: ConnectionState
    public let isConfirmedDisconnection: Bool
    public let isConfirmedReconnection: Bool
    public let technicalReason: String?
    public let timestamp: Date

    public init(
        fromState: ConnectionState,
        toState: ConnectionState,
        isConfirmedDisconnection: Bool,
        isConfirmedReconnection: Bool,
        technicalReason: String? = nil,
        timestamp: Date = Date()
    ) {
        self.fromState = fromState
        self.toState = toState
        self.isConfirmedDisconnection = isConfirmedDisconnection
        self.isConfirmedReconnection = isConfirmedReconnection
        self.technicalReason = technicalReason
        self.timestamp = timestamp
    }
}

public struct ConnectivityStateMachine: Sendable {
    public private(set) var currentState: ConnectionState = .unknown
    public private(set) var lastConfirmedState: ConnectionState = .unknown
    public private(set) var consecutiveSuccesses: Int = 0
    public private(set) var consecutiveFailures: Int = 0
    public private(set) var isInitialStateEstablished: Bool = false

    public var consecutiveFailuresThreshold: Int
    public var consecutiveSuccessesThreshold: Int

    public init(
        consecutiveFailuresThreshold: Int = 2,
        consecutiveSuccessesThreshold: Int = 2
    ) {
        self.consecutiveFailuresThreshold = max(1, consecutiveFailuresThreshold)
        self.consecutiveSuccessesThreshold = max(1, consecutiveSuccessesThreshold)
    }

    /// Update threshold configurations dynamically
    public mutating func updateThresholds(failures: Int, successes: Int) {
        self.consecutiveFailuresThreshold = max(1, failures)
        self.consecutiveSuccessesThreshold = max(1, successes)
    }

    /// Sets state to checking without resetting confirmed state
    public mutating func markChecking() {
        if currentState != .checking {
            currentState = .checking
        }
    }

    /// Immediately marks offline when the physical network interface is disconnected (e.g. Wi-Fi off or cable unplugged)
    public mutating func markImmediateOffline(
        reason: String = "Network interface disconnected",
        now: Date = Date()
    ) -> StateTransition? {
        let previousState = currentState
        let wasOnline = (lastConfirmedState == .online)
        let isFirstTime = !isInitialStateEstablished

        consecutiveFailures = consecutiveFailuresThreshold
        consecutiveSuccesses = 0

        currentState = .offline
        lastConfirmedState = .offline
        isInitialStateEstablished = true

        if previousState != .offline || wasOnline {
            let isDisconnection = wasOnline && !isFirstTime
            return StateTransition(
                fromState: previousState,
                toState: .offline,
                isConfirmedDisconnection: isDisconnection,
                isConfirmedReconnection: false,
                technicalReason: reason,
                timestamp: now
            )
        }
        return nil
    }

    /// Records the result of a network probe
    public mutating func recordResult(
        isSuccess: Bool,
        failureReason: String? = nil,
        now: Date = Date()
    ) -> StateTransition? {
        let previousState = currentState

        if isSuccess {
            consecutiveSuccesses += 1
            consecutiveFailures = 0

            if consecutiveSuccesses >= consecutiveSuccessesThreshold {
                let wasOffline = (lastConfirmedState == .offline)
                let isFirstTime = !isInitialStateEstablished

                currentState = .online
                lastConfirmedState = .online
                isInitialStateEstablished = true

                if previousState != .online || wasOffline {
                    let isReconnection = wasOffline && !isFirstTime
                    return StateTransition(
                        fromState: previousState,
                        toState: .online,
                        isConfirmedDisconnection: false,
                        isConfirmedReconnection: isReconnection,
                        technicalReason: nil,
                        timestamp: now
                    )
                }
            } else {
                // Not yet met threshold
                if lastConfirmedState == .offline {
                    currentState = .unstable
                } else if lastConfirmedState == .online {
                    currentState = .online
                } else {
                    currentState = .unstable
                }
            }
        } else {
            // Failure
            consecutiveFailures += 1
            consecutiveSuccesses = 0

            if consecutiveFailures >= consecutiveFailuresThreshold {
                let wasOnline = (lastConfirmedState == .online)
                let isFirstTime = !isInitialStateEstablished

                currentState = .offline
                lastConfirmedState = .offline
                isInitialStateEstablished = true

                if previousState != .offline || wasOnline {
                    let isDisconnection = wasOnline && !isFirstTime
                    return StateTransition(
                        fromState: previousState,
                        toState: .offline,
                        isConfirmedDisconnection: isDisconnection,
                        isConfirmedReconnection: false,
                        technicalReason: failureReason,
                        timestamp: now
                    )
                }
            } else {
                // Not yet reached threshold of failures
                if lastConfirmedState == .online {
                    currentState = .unstable
                } else if lastConfirmedState == .offline {
                    currentState = .offline
                } else {
                    currentState = .unstable
                }
            }
        }

        if previousState != currentState {
            return StateTransition(
                fromState: previousState,
                toState: currentState,
                isConfirmedDisconnection: false,
                isConfirmedReconnection: false,
                technicalReason: failureReason,
                timestamp: now
            )
        }

        return nil
    }

    /// Resets counters (e.g. when network interface changes or system wakes from sleep)
    public mutating func resetCounters() {
        consecutiveSuccesses = 0
        consecutiveFailures = 0
    }
}

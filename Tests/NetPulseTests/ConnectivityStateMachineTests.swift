import Foundation
import Testing
@testable import NetPulseCore

@Suite struct ConnectivityStateMachineTests {

    @Test func initialState() {
        let sm = ConnectivityStateMachine(consecutiveFailuresThreshold: 2, consecutiveSuccessesThreshold: 2)
        #expect(sm.currentState == .unknown)
        #expect(sm.lastConfirmedState == .unknown)
        #expect(!sm.isInitialStateEstablished)
        #expect(sm.consecutiveSuccesses == 0)
        #expect(sm.consecutiveFailures == 0)
    }

    @Test func onlineThresholdTransitions() {
        var sm = ConnectivityStateMachine(consecutiveFailuresThreshold: 2, consecutiveSuccessesThreshold: 2)

        // 1st success -> unstable / pending
        let t1 = sm.recordResult(isSuccess: true)
        #expect(sm.consecutiveSuccesses == 1)
        #expect(sm.currentState == .unstable)
        #expect(t1 != nil)
        #expect(t1?.toState == .unstable)
        #expect(!t1!.isConfirmedReconnection)

        // 2nd success -> confirmed online
        let t2 = sm.recordResult(isSuccess: true)
        #expect(sm.consecutiveSuccesses == 2)
        #expect(sm.currentState == .online)
        #expect(sm.lastConfirmedState == .online)
        #expect(sm.isInitialStateEstablished)
        #expect(t2 != nil)
        #expect(t2?.toState == .online)
        // Initial transition to online does not count as a reconnection alert!
        #expect(!t2!.isConfirmedReconnection)
    }

    @Test func onlineToOfflineWithHysteresis() {
        var sm = ConnectivityStateMachine(consecutiveFailuresThreshold: 2, consecutiveSuccessesThreshold: 2)
        // Bring to online
        _ = sm.recordResult(isSuccess: true)
        _ = sm.recordResult(isSuccess: true)
        #expect(sm.currentState == .online)

        // 1 failure -> unstable
        let t1 = sm.recordResult(isSuccess: false, failureReason: "DNS failure")
        #expect(sm.consecutiveFailures == 1)
        #expect(sm.currentState == .unstable)
        #expect(t1?.toState == .unstable)
        #expect(!t1!.isConfirmedDisconnection)

        // 2nd failure -> confirmed offline!
        let t2 = sm.recordResult(isSuccess: false, failureReason: "DNS failure")
        #expect(sm.consecutiveFailures == 2)
        #expect(sm.currentState == .offline)
        #expect(sm.lastConfirmedState == .offline)
        #expect(t2 != nil)
        #expect(t2!.isConfirmedDisconnection)
        #expect(t2?.technicalReason == "DNS failure")
    }

    @Test func offlineToOnlineReconnection() {
        var sm = ConnectivityStateMachine(consecutiveFailuresThreshold: 2, consecutiveSuccessesThreshold: 2)
        // Bring online then offline
        _ = sm.recordResult(isSuccess: true)
        _ = sm.recordResult(isSuccess: true)
        _ = sm.recordResult(isSuccess: false)
        _ = sm.recordResult(isSuccess: false)
        #expect(sm.currentState == .offline)

        // 1 success -> unstable
        let t1 = sm.recordResult(isSuccess: true)
        #expect(sm.consecutiveSuccesses == 1)
        #expect(sm.currentState == .unstable)
        #expect(!t1!.isConfirmedReconnection)

        // 2nd success -> confirmed reconnection!
        let t2 = sm.recordResult(isSuccess: true)
        #expect(sm.currentState == .online)
        #expect(t2 != nil)
        #expect(t2!.isConfirmedReconnection)
    }

    @Test func fluctuatingConnectivityDoesNotTriggerFalseAlerts() {
        var sm = ConnectivityStateMachine(consecutiveFailuresThreshold: 2, consecutiveSuccessesThreshold: 2)
        _ = sm.recordResult(isSuccess: true)
        _ = sm.recordResult(isSuccess: true)
        #expect(sm.currentState == .online)

        // Rapid fluctuation: fail, success, fail, success
        let t1 = sm.recordResult(isSuccess: false)
        #expect(!t1!.isConfirmedDisconnection)

        let t2 = sm.recordResult(isSuccess: true)
        #expect(t2 == nil || !t2!.isConfirmedReconnection)

        let t3 = sm.recordResult(isSuccess: false)
        #expect(!t3!.isConfirmedDisconnection)

        let t4 = sm.recordResult(isSuccess: true)
        #expect(t4 == nil || !t4!.isConfirmedReconnection)

        #expect(sm.lastConfirmedState == .online)
    }

    @Test func customThresholdConfiguration() {
        var sm = ConnectivityStateMachine(consecutiveFailuresThreshold: 3, consecutiveSuccessesThreshold: 3)
        _ = sm.recordResult(isSuccess: true)
        _ = sm.recordResult(isSuccess: true)
        #expect(sm.currentState != .online)
        _ = sm.recordResult(isSuccess: true)
        #expect(sm.currentState == .online)

        // Change thresholds dynamically
        sm.updateThresholds(failures: 1, successes: 1)
        #expect(sm.consecutiveFailuresThreshold == 1)
        #expect(sm.consecutiveSuccessesThreshold == 1)

        let t = sm.recordResult(isSuccess: false)
        #expect(t?.isConfirmedDisconnection == true)
    }

    @Test func immediateOfflineOnInterfaceDisconnect() {
        var sm = ConnectivityStateMachine(consecutiveFailuresThreshold: 2, consecutiveSuccessesThreshold: 2)
        // Bring online
        _ = sm.recordResult(isSuccess: true)
        _ = sm.recordResult(isSuccess: true)
        #expect(sm.currentState == .online)

        // Turn off Wi-Fi -> immediate offline
        let t = sm.markImmediateOffline(reason: "Network interface disconnected")
        #expect(sm.currentState == .offline)
        #expect(sm.lastConfirmedState == .offline)
        #expect(t != nil)
        #expect(t!.isConfirmedDisconnection)
        #expect(t!.technicalReason == "Network interface disconnected")
    }
}

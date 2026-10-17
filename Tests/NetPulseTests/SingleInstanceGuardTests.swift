import Foundation
import Testing
@testable import NetPulseCore

@Suite struct SingleInstanceGuardTests {

    @Test func enforceSingleInstanceBehavior() {
        let uniqueID = "test.instance.\(UUID().uuidString)"

        // First instance acquisition succeeds
        let firstResult = SingleInstanceGuard.enforceSingleInstance(bundleIdentifier: uniqueID)
        #expect(firstResult == true)

        // Calling enforceSingleInstance again in the same process returns true (idempotent)
        let secondResult = SingleInstanceGuard.enforceSingleInstance(bundleIdentifier: uniqueID)
        #expect(secondResult == true)
    }
}

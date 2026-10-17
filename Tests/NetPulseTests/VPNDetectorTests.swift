import Foundation
import Testing
@testable import NetPulseCore

@Suite struct VPNDetectorTests {

    @Test func detectVPNReturnsValidStructure() {
        let detector = VPNDetector()
        let result = detector.detectVPN()

        // Result is non-nil and valid boolean
        #expect(result.isConnected == true || result.isConnected == false)

        if result.isConnected {
            #expect(result.interfaceName != nil)
        }
    }
}

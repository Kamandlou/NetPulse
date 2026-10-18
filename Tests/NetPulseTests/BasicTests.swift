import Testing
@testable import NetPulseCore

@Suite struct BasicTests {
    @Test func version() {
        #expect(NetPulseVersion.current == "1.3.2")
    }
}

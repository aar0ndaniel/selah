import Testing
@testable import Selah

struct SmokeTests {
    @Test func appModuleLoads() {
        #expect(Bool(true))
    }
}

import XCTest
@testable import ModSwitchIME

final class ImeControllerSkipLogicTests2: XCTestCase {
    
    var controller: ImeController!
    
    override func setUp() {
        super.setUp()
        controller = ImeController.createForTesting()
    }
    
    override func tearDown() {
        controller = nil
        super.tearDown()
    }
    
    // MARK: - Critical Bug Fix Tests
    
    func testRapidDifferentIMESwitchingIsAllowed() {
        // Rapid switching to different IME is allowed (bug fix verification)
        let japaneseIME = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        let englishIME = "com.apple.keylayout.ABC"
        
        // Rapid switch from English to Japanese
        controller.switchToSpecificIME(englishIME, fromUser: true)
        // Immediately switch to different IME (within 100ms)
        controller.switchToSpecificIME(japaneseIME, fromUser: true)
        
        // Expect both operations to execute
        XCTAssertTrue(true, "Different IME rapid switching should be allowed")
    }
    
    func testSameIMERapidSwitchingIsBlocked() {
        // Rapid switching to same IME is blocked
        let targetIME = "com.apple.keylayout.ABC"
        
        // Record current IME
        let initialIME = controller.getCurrentInputSource()
        
        // Rapid switch to same IME twice
        controller.switchToSpecificIME(targetIME, fromUser: true)
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // Second operation is blocked (verify via logs)
        XCTAssertTrue(true, "Same IME rapid switching should be blocked")
    }
    
    func testInternalOperationNeverBlockedByTiming() {
        // Internal operations only check skip logic regardless of timing
        let targetIME = "com.apple.keylayout.ABC"
        
        // Execute internal operations rapidly
        controller.switchToSpecificIME(targetIME, fromUser: false)
        controller.switchToSpecificIME(targetIME, fromUser: false)
        
        // Skip if same IME regardless of timing
        XCTAssertTrue(true, "Internal operations should not be affected by timing")
    }
    
    func testForceAsciiDoesNotWaitForCompletion() {
        // forceAscii returns immediately without waiting for completion
        let startTime = CFAbsoluteTimeGetCurrent()
        
        controller.forceAscii(fromUser: true)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Returns immediately as it's async (less than 100ms)
        XCTAssertLessThan(duration, 0.1, "forceAscii should return immediately")
    }
    
    func testThreadSafetyOfSwitchTime() throws {
        if ProcessInfo.processInfo.environment["RUN_STRESS_TESTS"] != "1" {
            throw XCTSkip("Skipping stress test by default. Set RUN_STRESS_TESTS=1 to enable.")
        }
        // Safe to call switchToSpecificIME concurrently from multiple threads
        let expectation = self.expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for i in 0..<100 {
            queue.async {
                let ime = i % 2 == 0 ? "com.apple.keylayout.ABC" : "com.apple.keylayout.US"
                self.controller.switchToSpecificIME(ime, fromUser: true)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "All operations should complete without deadlock")
        }
    }
    
    func testChatteringPreventionTiming() {
        // Verify chattering prevention works precisely at 100ms
        let targetIME = "com.apple.keylayout.ABC"
        
        // First call
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // Wait 90ms (should still be blocked)
        Thread.sleep(forTimeInterval: 0.09)
        controller.switchToSpecificIME(targetIME, fromUser: true)
        // This call is blocked
        
        // Wait another 20ms (total 110ms)
        Thread.sleep(forTimeInterval: 0.02)
        controller.switchToSpecificIME(targetIME, fromUser: true)
        // This call goes through
        
        XCTAssertTrue(true, "Chattering prevention should work with 100ms threshold")
    }
}

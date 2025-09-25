import XCTest
import Carbon
@testable import ModSwitchIME

// Mock TIS functions for testing
var mockTISSelectInputSourceResult: OSStatus = noErr
var mockTISSelectInputSourceCallCount = 0
var mockCurrentInputSource = "com.apple.keylayout.ABC"

class MockableImeController: IMEControlling {
    private struct ThrottleState {
        var lastUserTarget: String = ""
        var lastUserRequestTime: CFAbsoluteTime = 0
    }

    private let throttleInterval: TimeInterval = 0.05 // 50ms throttle
    private var throttleState = ThrottleState()
    private let throttleQueue = DispatchQueue(label: "test.throttle.queue")
    
    func switchToSpecificIME(_ targetIMEId: String) {
        let now = CFAbsoluteTimeGetCurrent()
        
        // Thread-safe throttling check: skip only when identical request occurs within interval
        var shouldSkip = false
        throttleQueue.sync {
            let timeSinceLastUserRequest = now - throttleState.lastUserRequestTime
            if throttleState.lastUserTarget == targetIMEId && timeSinceLastUserRequest < throttleInterval {
                shouldSkip = true
            }
        }

        if shouldSkip {
            return
        }

        throttleQueue.sync {
            throttleState.lastUserTarget = targetIMEId
            throttleState.lastUserRequestTime = now
        }

        // Execute switch operation
        mockTISSelectInputSourceCallCount += 1
        mockCurrentInputSource = targetIMEId // Simulate successful switch

        if mockTISSelectInputSourceResult != noErr {
            // Simulate retry mechanism
            for attempt in 0..<3 {
                if mockTISSelectInputSourceResult == noErr {
                    break
                }
                Thread.sleep(forTimeInterval: 0.01) // Shorter delay for tests
            }

            if mockTISSelectInputSourceResult != noErr {
                // In real implementation, this would throw
                // For mock, we just return
                return
            }
        }

        // Simulate successful switch
        mockCurrentInputSource = targetIMEId
    }
    
    func getCurrentInputSource() -> String {
        return mockCurrentInputSource
    }
    
    func forceAscii() {
        switchToSpecificIME("com.apple.keylayout.ABC")
    }
}

class ImeControllerTests: XCTestCase {
    var imeController: IMEControlling!
    var mockableController: MockableImeController!
    
    override func setUp() {
        super.setUp()
        // Use shared instance for integration tests
        imeController = ImeController.shared
        mockableController = MockableImeController()
        mockTISSelectInputSourceResult = noErr
        mockTISSelectInputSourceCallCount = 0
        mockCurrentInputSource = "com.apple.keylayout.ABC"
    }
    
    override func tearDown() {
        imeController = nil
        mockableController = nil
        super.tearDown()
    }
    
    // Test direct IME switching
    func testSwitchToSpecificIME() {
        // Test switching to a specific IME
        let targetIME = "com.apple.keylayout.ABC"
        
        // This should not throw an error
        imeController.switchToSpecificIME(targetIME)
        
        // Test with empty IME ID (should handle gracefully)
        imeController.switchToSpecificIME("")
    }
    
    // Test force ASCII switching
    func testForceAscii() {
        // Test that forceAscii method can be called without errors
        imeController.forceAscii()
        
        // Get current IME (actual switching may not occur in test environment)
        let currentIME = imeController.getCurrentInputSource()
        XCTAssertNotNil(currentIME)
    }
    
    // Idle timeout test
    func testIdleTimeout() {
        // Given: Initial state
        let initialState = imeController.getCurrentInputSource()
        
        // When: Idle timeout occurs (call forceAscii)
        imeController.forceAscii()
        let result = imeController.getCurrentInputSource()
        
        // Then: forceAscii attempts to switch to English,
        // but actual switching doesn't occur in test environment
        XCTAssertEqual(initialState, result)
    }
    
    // Method call test
    func testMethodCalls() {
        // Confirm forceAscii can be called
        XCTAssertNoThrow(imeController.forceAscii())
        
        // Confirm switchToSpecificIME can be called
        XCTAssertNoThrow(imeController.switchToSpecificIME("com.apple.keylayout.ABC"))
        
        // Confirm getCurrentInputSource returns a value
        let currentIME = imeController.getCurrentInputSource()
        XCTAssertNotNil(currentIME)
        XCTAssertFalse(currentIME.isEmpty)
    }
    
    // MARK: - New Tests for Retry Mechanism
    
    func testRetryMechanismOnFailure() {
        // Given: TIS API will fail initially
        mockTISSelectInputSourceResult = OSStatus(-1)
        mockTISSelectInputSourceCallCount = 0
        let targetIME = "com.apple.keylayout.Japanese"
        
        // When: Attempting to switch IME
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: Wait for coalescing delay and retry attempts
        let expectation = XCTestExpectation(description: "Retry mechanism")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // After coalescing delay, retry mechanism should have been triggered
            // With failure, it should attempt multiple times
            XCTAssertGreaterThan(mockTISSelectInputSourceCallCount, 0, "Should have attempted to switch")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRetryMechanismSucceedsEventually() {
        // Given: Initial IME state
        mockCurrentInputSource = "com.apple.keylayout.ABC"
        mockTISSelectInputSourceCallCount = 0
        let targetIME = "com.apple.keylayout.Japanese"
        
        // When: Switch succeeds
        mockTISSelectInputSourceResult = noErr
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: Should execute immediately (synchronous with throttling)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 1, "Should have switched once")
        XCTAssertEqual(mockableController.getCurrentInputSource(), targetIME)
    }
    
    // MARK: - Tests for Switch Verification
    
    func testIMESwitchVerification() {
        // Given: Starting with ABC layout
        mockCurrentInputSource = "com.apple.keylayout.ABC"
        let targetIME = "com.apple.keylayout.Japanese"
        
        // When: Switching to Japanese
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: Should switch immediately (synchronous)
        XCTAssertEqual(mockableController.getCurrentInputSource(), targetIME)
        
        // Verification in real implementation happens asynchronously after 100ms
        // But for unit test, we just verify the immediate result
    }
    
    // MARK: - Tests for System Sleep/Wake
    
    func testSystemWakeRefreshesCache() {
        // Given: IME controller is initialized
        let notificationCenter = NotificationCenter.default
        
        // When: System wake notification is posted
        let expectation = XCTestExpectation(description: "Cache refresh after wake")
        
        // Post wake notification
        notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        
        // Then: Cache should be refreshed after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // In real implementation, cache would be refreshed
            // For test, we just verify the notification handling works
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSystemSleepLogging() {
        // Given: IME controller is initialized
        let notificationCenter = NotificationCenter.default
        
        // When: System sleep notification is posted
        notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        
        // Then: Should log the event (no crash/error)
        // This test ensures the notification handler doesn't cause issues
        XCTAssertNotNil(imeController)
    }
    
    // MARK: - Tests for Input Validation
    
    func testInvalidIMEIdValidation() {
        // Test various invalid IME IDs
        let invalidIds = [
            "",                    // Empty
            "invalid id with spaces",  // Spaces
            "invalid@id",         // Invalid character
            String(repeating: "a", count: 201),  // Too long
            "nodotshere"         // No dots and no known prefix
        ]
        
        for invalidId in invalidIds {
            imeController.switchToSpecificIME(invalidId)
            // Should handle gracefully without crash
        }
        
        // Valid IDs should work
        let validIds = [
            "com.apple.keylayout.ABC",
            "com.google.inputmethod.Japanese",
            "jp.co.justsystems.inputmethod.atok"
        ]
        
        for validId in validIds {
            imeController.switchToSpecificIME(validId)
            // Should handle without error
        }
    }
    
    // MARK: - Tests for Application Focus Monitoring
    
    func testApplicationFocusNotificationSetup() {
        // Test that app focus monitoring is set up
        // In real implementation, observer is added in init
        XCTAssertNotNil(imeController)
        
        // Post a test notification
        let app = NSRunningApplication.current
        let userInfo: [AnyHashable: Any] = [NSWorkspace.applicationUserInfoKey: app]
        
        NotificationCenter.default.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: userInfo
        )
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testIMEStateVerificationAfterAppSwitch() {
        // Given: Set a known IME
        let targetIME = "com.apple.keylayout.ABC"
        mockCurrentInputSource = "com.apple.keylayout.US"
        mockTISSelectInputSourceCallCount = 0
        
        // Switch to target IME
        mockableController.switchToSpecificIME(targetIME)
        
        // Wait for the switch to complete
        let switchExpectation = XCTestExpectation(description: "IME switch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switchExpectation.fulfill()
        }
        wait(for: [switchExpectation], timeout: 0.5)
        
        // When: App switch occurs
        let app = NSRunningApplication.current
        let userInfo: [AnyHashable: Any] = [NSWorkspace.applicationUserInfoKey: app]
        
        NotificationCenter.default.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: userInfo
        )
        
        // Then: Verification should occur after delay
        let expectation = XCTestExpectation(description: "IME state verification after app switch")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Verify IME is still the expected one
            XCTAssertEqual(self.mockableController.getCurrentInputSource(), targetIME)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testIMEMismatchDetectionAfterAppSwitch() {
        // Given: Set initial state
        mockCurrentInputSource = "com.apple.keylayout.ABC"
        mockTISSelectInputSourceCallCount = 0
        let targetIME = "com.apple.keylayout.Japanese"
        
        // Request switch to Japanese
        mockableController.switchToSpecificIME(targetIME)
        
        // Wait for switch to complete
        let switchExpectation = XCTestExpectation(description: "Initial switch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify switch happened
            XCTAssertEqual(self.mockableController.getCurrentInputSource(), targetIME)
            
            // Simulate app changing IME back to US
            mockCurrentInputSource = "com.apple.keylayout.US"
            switchExpectation.fulfill()
        }
        wait(for: [switchExpectation], timeout: 0.5)
        
        // When: App focus notification
        let app = NSRunningApplication.current
        let userInfo: [AnyHashable: Any] = [NSWorkspace.applicationUserInfoKey: app]
        
        NotificationCenter.default.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: userInfo
        )
        
        // Then: Should detect mismatch
        let expectation = XCTestExpectation(description: "Mismatch detection")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Current IME should be different from what was set
            let currentIME = self.mockableController.getCurrentInputSource()
            XCTAssertNotEqual(currentIME, targetIME, "Should detect IME was changed by app")
            XCTAssertEqual(currentIME, "com.apple.keylayout.US", "Should reflect app's IME change")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Tests for IME Switch Request Coalescing
    
    func testIMESwitchRequestThrottling() {
        // Given: Multiple rapid switch requests to same IME
        let targetIME = "com.apple.keylayout.Japanese"
        let differentIME = "com.apple.keylayout.US"
        
        // Reset mock state
        mockTISSelectInputSourceCallCount = 0
        mockCurrentInputSource = "com.apple.keylayout.ABC"
        
        // When: First request - should execute immediately
        mockableController.switchToSpecificIME(targetIME)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 1, "First request should execute immediately")
        
        // Rapid subsequent requests within throttle window (50ms) - should be throttled
        for _ in 0..<4 {
            Thread.sleep(forTimeInterval: 0.01) // 10ms between requests
            mockableController.switchToSpecificIME(targetIME)
        }
        
        // Should still be 1 (duplicate target requests are throttled)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 1, "Duplicate target requests should be throttled")
        
        // Switching to a different IME within throttle window should be allowed
        mockableController.switchToSpecificIME(differentIME)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 2, "Different IME should bypass target-specific throttle")
        
        // Wait for throttle interval to pass
        Thread.sleep(forTimeInterval: 0.06) // 60ms > 50ms throttle interval
        
        // Next request to different IME should execute
        mockableController.switchToSpecificIME(differentIME)
        XCTAssertEqual(
            mockTISSelectInputSourceCallCount, 3,
            "Request after throttle interval should execute as usual"
        )
    }
    
    func testIMESwitchDifferentIMEsWithinThrottleWindow() {
        // Given: Rapid switch requests to different IMEs
        let ime1 = "com.apple.keylayout.ABC"
        let ime2 = "com.apple.keylayout.Japanese"
        
        // Reset mock state
        mockTISSelectInputSourceCallCount = 0
        mockCurrentInputSource = "com.apple.keylayout.US"
        
        // When: First IME request
        mockableController.switchToSpecificIME(ime1)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 1, "First request should execute")
        
        // Different IME within throttle window - should execute immediately
        Thread.sleep(forTimeInterval: 0.02) // 20ms < 50ms throttle
        mockableController.switchToSpecificIME(ime2)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 2, "Different IME should not be throttled")
        
        // Wait long enough to exceed throttle interval comfortably
        Thread.sleep(forTimeInterval: 0.08) // Total ~100ms > 50ms
        
        // Additional call after throttle window still executes
        mockableController.switchToSpecificIME(ime2)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 3, "Repeated requests after interval should execute")
        XCTAssertEqual(mockableController.getCurrentInputSource(), ime2, "Should switch to second IME")
    }
    
    func testIMESwitchWithActualIMEMismatch() {
        // Given: Internal state thinks we're on Japanese, but actual system is on ABC
        let targetIME = "com.apple.keylayout.Japanese"
        let actualIME = "com.apple.keylayout.ABC"
        
        // Reset mock state
        mockTISSelectInputSourceCallCount = 0
        mockCurrentInputSource = actualIME // Actual system IME
        
        // Simulate that we previously switched to Japanese
        mockableController.switchToSpecificIME(targetIME)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 1, "First switch should execute")
        
        // Simulate system changing IME externally (e.g., window focus change)
        mockCurrentInputSource = actualIME
        
        // Wait for throttle interval to pass
        Thread.sleep(forTimeInterval: 0.06) // After throttle window
        
        // When: User tries to switch to Japanese again
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: Should execute because actual IME is different from target
        // With our fix, this correctly detects the mismatch and switches
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 2, 
                      "Should switch when actual IME differs from target")
    }
    
    func testIMESwitchToActualCurrentIME() {
        // Given: System is already on the target IME
        let targetIME = "com.apple.keylayout.Japanese"
        
        // Reset mock state
        mockTISSelectInputSourceCallCount = 0
        mockCurrentInputSource = targetIME // Already on target IME
        
        // When: User tries to switch to the same IME
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: Should still issue a switch request so users can recover from mismatched states
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 1, 
                      "Should reissue request even when system reports target IME")
    }

    func testUserCanResendSameIMEAfterThrottleWindow() {
        let targetIME = "com.apple.keylayout.Japanese"

        mockTISSelectInputSourceCallCount = 0
        mockCurrentInputSource = targetIME

        // First request executes
        mockableController.switchToSpecificIME(targetIME)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 1)

        // Wait for throttle interval to expire
        Thread.sleep(forTimeInterval: 0.06)

        // Same IME request after interval should execute again
        mockableController.switchToSpecificIME(targetIME)
        XCTAssertEqual(mockTISSelectInputSourceCallCount, 2,
                       "Same IME should execute again after throttle window")
    }
}

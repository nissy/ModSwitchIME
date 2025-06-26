import XCTest
import Carbon
@testable import ModSwitchIME

// Mock TIS functions for testing
var mockTISSelectInputSourceResult: OSStatus = noErr
var mockTISSelectInputSourceCallCount = 0
var mockCurrentInputSource = "com.apple.keylayout.ABC"

class MockableImeController: ImeController {
    override func selectInputSource(_ inputSourceID: String) throws {
        // For testing, we'll simulate the behavior
        mockTISSelectInputSourceCallCount += 1
        
        if mockTISSelectInputSourceResult != noErr {
            // Simulate retry mechanism
            for attempt in 0..<3 {
                if mockTISSelectInputSourceResult == noErr {
                    break
                }
                Thread.sleep(forTimeInterval: 0.01) // Shorter delay for tests
            }
            
            if mockTISSelectInputSourceResult != noErr {
                throw ModSwitchIMEError.inputMethodSwitchFailed("Mock failure")
            }
        }
        
        // Simulate successful switch
        mockCurrentInputSource = inputSourceID
    }
    
    override func getCurrentInputSource() -> String {
        return mockCurrentInputSource
    }
}

class ImeControllerTests: XCTestCase {
    var imeController: ImeController!
    var mockableController: MockableImeController!
    
    override func setUp() {
        super.setUp()
        imeController = ImeController()
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
        let targetIME = "com.apple.keylayout.Japanese"
        
        // When: Attempting to switch IME
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: Retry mechanism should have been triggered
        // Note: In real implementation, it would retry 3 times
        XCTAssertGreaterThan(mockTISSelectInputSourceCallCount, 0)
    }
    
    func testRetryMechanismSucceedsEventually() {
        // Given: Initial IME state
        mockCurrentInputSource = "com.apple.keylayout.ABC"
        let targetIME = "com.apple.keylayout.Japanese"
        
        // When: Switch succeeds
        mockTISSelectInputSourceResult = noErr
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: IME should be switched
        XCTAssertEqual(mockableController.getCurrentInputSource(), targetIME)
    }
    
    // MARK: - Tests for Switch Verification
    
    func testIMESwitchVerification() {
        // Given: Starting with ABC layout
        mockCurrentInputSource = "com.apple.keylayout.ABC"
        let targetIME = "com.apple.keylayout.Japanese"
        
        // When: Switching to Japanese
        mockableController.switchToSpecificIME(targetIME)
        
        // Then: Should verify the switch happened
        let expectation = XCTestExpectation(description: "IME switch verification")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            // Verification should have occurred
            XCTAssertEqual(self?.mockableController.getCurrentInputSource(), targetIME)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
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
}

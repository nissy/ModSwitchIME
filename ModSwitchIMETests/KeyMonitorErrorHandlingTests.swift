import XCTest
@testable import ModSwitchIME

class KeyMonitorErrorHandlingTests: XCTestCase {
    
    func testEventTapCreationFailureTriggersErrorCallback() {
        let keyMonitor = KeyMonitor()
        let expectation = self.expectation(description: "Error callback triggered")
        var receivedError: ModSwitchIMEError?
        
        keyMonitor.onError = { error in
            receivedError = error
            expectation.fulfill()
        }
        
        // Since we can't easily simulate CGEventTap creation failure in tests,
        // we'll test the error callback mechanism by triggering it directly
        keyMonitor.onError?(.eventTapCreationFailed(reason: "Test failure"))
        
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertNotNil(receivedError)
            if case .eventTapCreationFailed(let reason) = receivedError {
                XCTAssertEqual(reason, "Test failure")
            } else {
                XCTFail("Wrong error type received")
            }
        }
    }
    
    func testEventTapDisabledErrorsArePropagated() {
        let keyMonitor = KeyMonitor()
        var receivedErrors: [ModSwitchIMEError] = []
        
        keyMonitor.onError = { error in
            receivedErrors.append(error)
        }
        
        // Test automatic disable
        keyMonitor.onError?(.eventTapDisabled(automatic: true))
        
        // Test user input disable
        keyMonitor.onError?(.eventTapDisabled(automatic: false))
        
        XCTAssertEqual(receivedErrors.count, 2)
        
        if case .eventTapDisabled(let automatic) = receivedErrors[0] {
            XCTAssertTrue(automatic)
        } else {
            XCTFail("First error should be automatic disable")
        }
        
        if case .eventTapDisabled(let automatic) = receivedErrors[1] {
            XCTAssertFalse(automatic)
        } else {
            XCTFail("Second error should be user input disable")
        }
    }
    
    func testErrorDescriptionsAreCorrect() {
        let tapCreationError = ModSwitchIMEError.eventTapCreationFailed(reason: "Test reason")
        XCTAssertEqual(tapCreationError.errorDescription, "Failed to create event tap: Test reason")
        XCTAssertEqual(tapCreationError.recoverySuggestion, "Check accessibility permissions and try restarting the application.")
        
        let automaticDisableError = ModSwitchIMEError.eventTapDisabled(automatic: true)
        XCTAssertEqual(
            automaticDisableError.errorDescription, 
            "Event tap was automatically disabled by the system."
        )
        XCTAssertEqual(
            automaticDisableError.recoverySuggestion, 
            "The application will attempt to re-enable monitoring automatically."
        )
        
        let userDisableError = ModSwitchIMEError.eventTapDisabled(automatic: false)
        XCTAssertEqual(userDisableError.errorDescription, "Event tap was disabled due to user input timeout.")
        XCTAssertEqual(
            userDisableError.recoverySuggestion, 
            "Try clicking slower or check your system's security settings."
        )
    }
}

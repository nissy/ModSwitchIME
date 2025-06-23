import XCTest
@testable import ModSwitchIME

class ImeControllerTests: XCTestCase {
    var imeController: ImeController!
    
    override func setUp() {
        super.setUp()
        imeController = ImeController()
    }
    
    override func tearDown() {
        imeController = nil
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
}

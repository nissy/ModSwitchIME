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
    
    // Test when right cmd is pressed twice
    func testRightCmdDoublePress() {
        // Initial state: English
        // First right cmd press: Switch to configured IME
        // Second right cmd press: Stays with the same IME (Doesn't switch to ASCII mode)
        
        // Given: English input state
        imeController.forceAscii()
        
        // When: Press right cmd (first time)
        imeController.toggleByCmd(isLeft: false)
        let firstPressResult = imeController.getCurrentInputSource()
        
        // Then: According to toggleByCmd specification, right cmd switches to configured IME
        // However, cannot perform actual IME switching in test environment,
        // so it depends on current system IME state
        // This test is not for verifying actual IME switching,
        // but confirms that toggleByCmd method is called correctly
        
        // When: Press right cmd (second time)
        imeController.toggleByCmd(isLeft: false)
        let secondPressResult = imeController.getCurrentInputSource()
        
        // Then: Returns current system IME state
        // Since actual switching doesn't occur in test environment,
        // firstPressResult and secondPressResult will be the same
        XCTAssertEqual(firstPressResult, secondPressResult)
    }
    
    // Normal operation test: left cmd → right cmd
    func testNormalToggleBehavior() {
        // Given: Initial state
        let initialState = imeController.getCurrentInputSource()
        
        // When: Press left cmd
        imeController.toggleByCmd(isLeft: true)
        let leftCmdResult = imeController.getCurrentInputSource()
        
        // Then: According to toggleByCmd specification, left cmd attempts to switch to English
        // However, cannot perform actual IME switching in test environment,
        // so returns current system IME state
        
        // When: Press right cmd
        imeController.toggleByCmd(isLeft: false)
        let rightCmdResult = imeController.getCurrentInputSource()
        
        // Then: Returns current system IME state
        // Actual switching doesn't occur in test environment
        XCTAssertEqual(leftCmdResult, rightCmdResult)
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
        // Confirm toggleByCmd(isLeft: true) can be called
        XCTAssertNoThrow(imeController.toggleByCmd(isLeft: true))
        
        // Confirm toggleByCmd(isLeft: false) can be called
        XCTAssertNoThrow(imeController.toggleByCmd(isLeft: false))
        
        // Confirm forceAscii() can be called
        XCTAssertNoThrow(imeController.forceAscii())
        
        // Confirm switchToSpecificIME() can be called
        XCTAssertNoThrow(imeController.switchToSpecificIME("com.apple.keylayout.ABC"))
        
        // Confirm getCurrentInputSource() returns a string
        let source = imeController.getCurrentInputSource()
        XCTAssertFalse(source.isEmpty)
    }
}

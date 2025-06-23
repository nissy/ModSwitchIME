import XCTest
import CoreGraphics
@testable import ModSwitchIME

class KeyMonitorSimpleTest: XCTestCase {
    var keyMonitor: KeyMonitor!
    var mockImeController: MockImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
        
        // Setup test IME mappings
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        
        preferences.setIME("com.justsystems.inputmethod.atok34.Japanese", for: .rightCommand)
        preferences.setKeyEnabled(true, for: .rightCommand)
        
        // Create KeyMonitor with mock ImeController
        keyMonitor = KeyMonitor(preferences: preferences)
        mockImeController = MockImeController()
        #if DEBUG
        keyMonitor.setImeController(mockImeController)
        #endif
    }
    
    override func tearDown() {
        keyMonitor?.stop()
        keyMonitor = nil
        mockImeController = nil
        preferences = nil
        super.tearDown()
    }
    
    func testSingleKeyPress() {
        // Test single key press and release
        #if DEBUG
        // Press left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Release left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        // Should switch to ABC
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.first?.ime, "com.apple.keylayout.ABC")
        #endif
    }
    
    func testMultiKeyPress() {
        #if DEBUG
        // Press left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Press right command while left is still pressed
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        // Should switch twice: first to right command when pressed, then to left command when pressed
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls[0].ime, "com.justsystems.inputmethod.atok34.Japanese")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls[1].ime, "com.apple.keylayout.ABC")
        
        // Release left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        // Should NOT switch on release
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        
        // Release right command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        
        // Should NOT switch on release
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        #endif
    }
    
    func testMultiKeyPressWithoutIME() {
        #if DEBUG
        // Disable IME for right command
        preferences.setKeyEnabled(false, for: .rightCommand)
        
        // Press left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Press right command while left is still pressed
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        // Should NOT switch (right command has no IME)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 0)
        
        // Release both keys
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        
        // Still no switch
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 0)
        #endif
    }
}
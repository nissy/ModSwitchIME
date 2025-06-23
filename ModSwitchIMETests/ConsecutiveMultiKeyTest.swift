import XCTest
import CoreGraphics
@testable import ModSwitchIME

// Simple Mock ImeController for testing
class SimpleMockImeController: ImeController {
    var switchToSpecificIMECalls: [(ime: String, time: CFAbsoluteTime)] = []
    private var currentIME: String = "com.apple.keylayout.ABC"  // Default to ABC
    
    override func switchToSpecificIME(_ targetIMEId: String) {
        switchToSpecificIMECalls.append((ime: targetIMEId, time: CFAbsoluteTimeGetCurrent()))
        currentIME = targetIMEId
        print("SimpleMockImeController: Switching to \(targetIMEId)")
    }
    
    override func getCurrentInputSource() -> String {
        return currentIME
    }
}

class ConsecutiveMultiKeyTest: XCTestCase {
    var keyMonitor: KeyMonitor!
    var mockImeController: SimpleMockImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
        
        // Setup test IME mappings for all command keys
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        
        preferences.setIME("com.justsystems.inputmethod.atok34.Japanese", for: .rightCommand)
        preferences.setKeyEnabled(true, for: .rightCommand)
        
        // Create KeyMonitor with mock ImeController
        keyMonitor = KeyMonitor(preferences: preferences)
        mockImeController = SimpleMockImeController()
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
    
    func testConsecutiveMultiKeyPress() {
        #if DEBUG
        // Test the specific sequence that was failing:
        // Left CMD → Right CMD (switches) → release both → Right CMD → Left CMD (doesn't switch)
        
        // First sequence: Left CMD → Right CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        // Should switch to Japanese (right command)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, "com.justsystems.inputmethod.atok34.Japanese")
        
        // Release right command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Should NOT switch (other key still pressed)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        
        // Release left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        // Should NOT switch (was multi-key, already handled)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        
        // Second sequence: Right CMD → Left CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        // Should switch to ABC (left command)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, "com.apple.keylayout.ABC")
        
        // Release left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        // Should NOT switch
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2)
        
        // Release right command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        
        // Should NOT switch
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2)
        #endif
    }
    
    func testSingleKeyAfterMultiKey() {
        #if DEBUG
        // Test that single key press works correctly after multi-key press
        
        // Multi-key sequence
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        
        // Release both
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        // Now test single key press
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        // Should switch for single key press
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, "com.apple.keylayout.ABC")
        #endif
    }
}
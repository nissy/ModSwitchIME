import XCTest
import CoreGraphics
@testable import ModSwitchIME

class MultiKeyPressTest: XCTestCase {
    var keyMonitor: KeyMonitor!
    var mockImeController: FixedMockImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
        
        // Setup test IME mappings for multi-key test
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        
        preferences.setIME("com.justsystems.inputmethod.atok34.Japanese", for: .rightCommand)
        preferences.setKeyEnabled(true, for: .rightCommand)
        
        // Create KeyMonitor with mock ImeController
        keyMonitor = KeyMonitor(preferences: preferences)
        mockImeController = FixedMockImeController()
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
    
    func testMultiKeyPressBasicFunctionality() {
        #if DEBUG
        print("\n=== Testing Basic Multi-Key Press Functionality ===")
        
        // Clear previous calls
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Test: Left CMD -> Right CMD (should switch to Right CMD's IME)
        print("1. Left CMD press")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        let beforeRightCmd = mockImeController.switchToSpecificIMECalls.count
        print("2. Right CMD press (should trigger multi-key and switch to ATOK)")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        let afterRightCmd = mockImeController.switchToSpecificIMECalls.count
        print("IME switches after right CMD: \(afterRightCmd - beforeRightCmd)")
        
        // Should switch to the IME of the last pressed key (Right CMD)
        XCTAssertEqual(afterRightCmd, beforeRightCmd + 1, "Should switch IME on multi-key press")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, 
                      "com.justsystems.inputmethod.atok34.Japanese",
                      "Should switch to Right CMD's IME (ATOK)")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
        
        print("Total switches: \(mockImeController.switchToSpecificIMECalls.count)")
        #endif
    }
    
    func testReverseMultiKeyPress() {
        #if DEBUG
        print("\n=== Testing Reverse Multi-Key Press ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Test: Right CMD -> Left CMD (should switch to Left CMD's IME)
        print("1. Right CMD press")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        let beforeLeftCmd = mockImeController.switchToSpecificIMECalls.count
        print("2. Left CMD press (should trigger multi-key and switch to ABC)")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        let afterLeftCmd = mockImeController.switchToSpecificIMECalls.count
        print("IME switches after left CMD: \(afterLeftCmd - beforeLeftCmd)")
        
        // Should switch to the IME of the last pressed key (Left CMD)
        XCTAssertEqual(afterLeftCmd, beforeLeftCmd + 1, "Should switch IME on multi-key press")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, 
                      "com.apple.keylayout.ABC",
                      "Should switch to Left CMD's IME (ABC)")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        print("Total switches: \(mockImeController.switchToSpecificIMECalls.count)")
        #endif
    }
    
    func testMixedKeyPressWithoutIME() {
        #if DEBUG
        print("\n=== Testing Mixed Key Press (One without IME) ===")
        
        // Set up one key without IME
        preferences.setIME(nil, for: .leftShift)
        preferences.setKeyEnabled(false, for: .leftShift)
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Test: Left Shift (no IME) -> Left CMD (with IME)
        print("1. Left Shift press (no IME configured)")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftShift.keyCode,
            flags: ModifierKey.leftShift.flagMask
        )
        
        let beforeLeftCmd = mockImeController.switchToSpecificIMECalls.count
        print("2. Left CMD press (should NOT trigger multi-key since Left Shift has no IME)")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: [ModifierKey.leftShift.flagMask, ModifierKey.leftCommand.flagMask]
        )
        
        let afterLeftCmd = mockImeController.switchToSpecificIMECalls.count
        print("IME switches after left CMD: \(afterLeftCmd - beforeLeftCmd)")
        
        // Should NOT switch because one key doesn't have IME configured
        XCTAssertEqual(afterLeftCmd, beforeLeftCmd, "Should NOT switch when one key has no IME")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftShift.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        print("Total switches: \(mockImeController.switchToSpecificIMECalls.count)")
        #endif
    }
    
    func testRealWorldScenario() {
        #if DEBUG
        print("\n=== Testing Real World Scenario ===")
        
        // Configure multiple keys with different IMEs
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        
        preferences.setIME("com.justsystems.inputmethod.atok34.Japanese", for: .rightCommand)
        preferences.setKeyEnabled(true, for: .rightCommand)
        
        preferences.setIME("com.google.inputmethod.Japanese", for: .leftOption)
        preferences.setKeyEnabled(true, for: .leftOption)
        
        // No IME for rightOption
        preferences.setIME(nil, for: .rightOption)
        preferences.setKeyEnabled(false, for: .rightOption)
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        print("Test 1: Left CMD -> Right CMD (both have IME)")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        let before1 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
        let after1 = mockImeController.switchToSpecificIMECalls.count
        print("  Switches: \(after1 - before1) (should be 1)")
        XCTAssertEqual(after1, before1 + 1, "Should switch to Right CMD's IME")
        
        // Release both
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
        
        print("Test 2: Left CMD -> Right Option (one has no IME)")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        let before2 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightOption.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightOption.flagMask])
        let after2 = mockImeController.switchToSpecificIMECalls.count
        print("  Switches: \(after2 - before2) (should be 0)")
        XCTAssertEqual(after2, before2, "Should NOT switch when one key has no IME")
        
        // Release both
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightOption.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightOption.keyCode, flags: [])
        
        print("Test 3: Left Option -> Left CMD (both have IME, different order)")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: ModifierKey.leftOption.flagMask)
        let before3 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [ModifierKey.leftOption.flagMask, ModifierKey.leftCommand.flagMask])
        let after3 = mockImeController.switchToSpecificIMECalls.count
        print("  Switches: \(after3 - before3) (should be 1, to Left CMD's IME)")
        XCTAssertEqual(after3, before3 + 1, "Should switch to Left CMD's IME (last pressed)")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, "com.apple.keylayout.ABC", "Should switch to ABC")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        print("Total switches: \(mockImeController.switchToSpecificIMECalls.count)")
        #endif
    }
}
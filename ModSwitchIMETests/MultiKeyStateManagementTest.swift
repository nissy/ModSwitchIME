import XCTest
import CoreGraphics
@testable import ModSwitchIME

class MultiKeyStateManagementTest: XCTestCase {
    var keyMonitor: KeyMonitor!
    var mockImeController: FixedMockImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
        
        // Setup test IME mappings
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        
        preferences.setIME("com.justsystems.inputmethod.atok34.Japanese", for: .rightCommand)
        preferences.setKeyEnabled(true, for: .rightCommand)
        
        preferences.setIME("com.google.inputmethod.Japanese", for: .leftOption)
        preferences.setKeyEnabled(true, for: .leftOption)
        
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
    
    func testMultiKeyStatePersistence() {
        #if DEBUG
        print("\n=== Testing Multi-Key State Persistence ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Test sequence: Left CMD -> Right CMD -> Release Right CMD -> Release Left CMD
        // Then repeat: Left CMD -> Right CMD (should still work)
        
        print("Phase 1: First multi-key sequence")
        
        // Step 1: Left CMD press
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Step 2: Right CMD press (should trigger multi-key)
        let before1 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        let after1 = mockImeController.switchToSpecificIMECalls.count
        
        print("  Multi-key switches: \(after1 - before1)")
        XCTAssertEqual(after1, before1 + 1, "First multi-key should work")
        
        // Step 3: Release Right CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Step 4: Release Left CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        print("Phase 2: Second multi-key sequence (should still work)")
        
        // Step 5: Left CMD press again
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Step 6: Right CMD press again (should trigger multi-key)
        let before2 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        let after2 = mockImeController.switchToSpecificIMECalls.count
        
        print("  Second multi-key switches: \(after2 - before2)")
        XCTAssertEqual(after2, before2 + 1, "Second multi-key should also work")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        print("Total switches: \(mockImeController.switchToSpecificIMECalls.count)")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2, "Should have exactly 2 switches")
        #endif
    }
    
    func testLeftRightCommandKeyDetection() {
        #if DEBUG
        print("\n=== Testing Left/Right Command Key Detection ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Test that left and right command keys are detected correctly
        // even though they share the same flagMask
        
        print("Test 1: Left CMD single press")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        let leftSwitches = mockImeController.switchToSpecificIMECalls.count
        print("  Left CMD switches: \(leftSwitches)")
        
        print("Test 2: Right CMD single press")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
        
        let rightSwitches = mockImeController.switchToSpecificIMECalls.count - leftSwitches
        print("  Right CMD switches: \(rightSwitches)")
        
        print("Test 3: Left CMD -> Right CMD multi-key")
        let beforeMulti = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
        let afterMulti = mockImeController.switchToSpecificIMECalls.count
        
        print("  Multi-key switches: \(afterMulti - beforeMulti)")
        XCTAssertEqual(afterMulti, beforeMulti + 1, "Multi-key should work")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
        
        print("Total switches: \(mockImeController.switchToSpecificIMECalls.count)")
        #endif
    }
    
    func testProblematicSequences() {
        #if DEBUG
        print("\n=== Testing Problematic Sequences ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Test sequences that might cause state confusion
        
        print("Sequence 1: Rapid press/release cycles")
        for i in 0..<3 {
            print("  Cycle \(i + 1)")
            keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
            let before = mockImeController.switchToSpecificIMECalls.count
            keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
            let after = mockImeController.switchToSpecificIMECalls.count
            print("    Switches: \(after - before)")
            
            keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
            keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
            
            // Each cycle should produce exactly 1 switch
            XCTAssertEqual(after, before + 1, "Cycle \(i + 1) should produce 1 switch")
        }
        
        print("Sequence 2: Mixed key combinations")
        // Left CMD + Left Option (different flag masks)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        let beforeMixed = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.leftOption.flagMask])
        let afterMixed = mockImeController.switchToSpecificIMECalls.count
        
        print("  Mixed key switches: \(afterMixed - beforeMixed)")
        XCTAssertEqual(afterMixed, beforeMixed + 1, "Mixed keys should work")
        
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftOption.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: [])
        
        print("Total switches: \(mockImeController.switchToSpecificIMECalls.count)")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 4, "Should have 4 switches total")
        #endif
    }
}
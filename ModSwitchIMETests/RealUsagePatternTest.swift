import XCTest
import CoreGraphics
@testable import ModSwitchIME

class RealUsagePatternTest: XCTestCase {
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
    
    func testRepeatedMultiKeyUsage() {
        #if DEBUG
        print("\n=== Testing Repeated Multi-Key Usage (Real Usage Pattern) ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Simulate 10 cycles of multi-key usage to find cumulative issues
        for cycle in 1...10 {
            print("\n--- Cycle \(cycle) ---")
            
            let beforeCycle = mockImeController.switchToSpecificIMECalls.count
            
            // Alternate between patterns to avoid "already on target IME" issue
            if cycle % 2 == 1 {
                // Pattern 1: Left CMD -> Right CMD (switches to ATOK)
                print("  Pattern: Left CMD -> Right CMD (to ATOK)")
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
                
                let afterMultiKey = mockImeController.switchToSpecificIMECalls.count
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
                
                let switchesInCycle = afterMultiKey - beforeCycle
                print("  Cycle \(cycle) switches: \(switchesInCycle)")
                
                if switchesInCycle != 1 {
                    print("  ❌ Expected 1 switch, got \(switchesInCycle)")
                    XCTFail("Cycle \(cycle): Expected 1 switch, got \(switchesInCycle)")
                    break
                } else {
                    print("  ✅ Cycle \(cycle) OK")
                }
            } else {
                // Pattern 2: Right CMD -> Left CMD (switches to ABC)
                print("  Pattern: Right CMD -> Left CMD (to ABC)")
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
                
                let afterMultiKey = mockImeController.switchToSpecificIMECalls.count
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
                keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
                
                let switchesInCycle = afterMultiKey - beforeCycle
                print("  Cycle \(cycle) switches: \(switchesInCycle)")
                
                if switchesInCycle != 1 {
                    print("  ❌ Expected 1 switch, got \(switchesInCycle)")
                    XCTFail("Cycle \(cycle): Expected 1 switch, got \(switchesInCycle)")
                    break
                } else {
                    print("  ✅ Cycle \(cycle) OK")
                }
            }
            
            // Small delay to simulate real usage
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        print("\nTotal switches after 10 cycles: \(mockImeController.switchToSpecificIMECalls.count)")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 10, "Should have exactly 10 switches (1 per cycle)")
        #endif
    }
    
    func testMixedUsagePatterns() {
        #if DEBUG
        print("\n=== Testing Mixed Usage Patterns ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Pattern 1: Multi-key -> Single key -> Multi-key
        print("Pattern 1: Multi-key -> Single key -> Multi-key")
        
        // Multi-key: Left CMD + Right CMD
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
        
        let afterPattern1 = mockImeController.switchToSpecificIMECalls.count
        print("  After pattern 1: \(afterPattern1) switches")
        
        // Single key: Left Option
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: ModifierKey.leftOption.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: [])
        
        let afterSingle = mockImeController.switchToSpecificIMECalls.count
        print("  After single key: \(afterSingle) switches")
        
        // Multi-key again: Right CMD + Left Option
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: [ModifierKey.rightCommand.flagMask, ModifierKey.leftOption.flagMask])
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftOption.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftOption.keyCode, flags: [])
        
        let afterPattern2 = mockImeController.switchToSpecificIMECalls.count
        print("  After pattern 2: \(afterPattern2) switches")
        
        // Should have 3 switches total (1 multi-key + 1 single + 1 multi-key)
        XCTAssertEqual(afterPattern2, 3, "Mixed usage should result in 3 switches")
        #endif
    }
    
    func testIncompleteSequences() {
        #if DEBUG
        print("\n=== Testing Incomplete Sequences (Edge Cases) ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Edge case 1: Press keys but don't complete the sequence properly
        print("Edge case 1: Incomplete sequence")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
        // Don't release properly - just clear flags
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        let afterIncomplete = mockImeController.switchToSpecificIMECalls.count
        print("  After incomplete sequence: \(afterIncomplete) switches")
        
        // Try to use multi-key again - should still work
        print("Edge case 2: After incomplete sequence, try again")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [ModifierKey.rightCommand.flagMask, ModifierKey.leftCommand.flagMask])
        
        let afterRetry = mockImeController.switchToSpecificIMECalls.count
        print("  After retry: \(afterRetry) switches")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        // Should still work after incomplete sequences
        XCTAssertTrue(afterRetry > afterIncomplete, "Multi-key should still work after incomplete sequences")
        #endif
    }
    
    func testStateDebugging() {
        #if DEBUG
        print("\n=== State Debugging Test ===")
        
        // Helper function to print current state
        func printState(_ label: String) {
            let pressedKeys = keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName }
            print("  \(label): KeyPressTimestamps = \(pressedKeys)")
        }
        
        printState("Initial")
        
        // Sequence that might cause issues
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        printState("After Left CMD press")
        
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
        printState("After Right CMD press (multi-key)")
        
        // Simulate incomplete release (common in real usage)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        printState("After Right CMD release")
        
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        printState("After Left CMD release")
        
        // Force state sync to clean up any issues
        #if DEBUG
        keyMonitor.forceStateSync(flags: [])
        printState("After force sync")
        #endif
        
        // Verify clean state
        XCTAssertTrue(keyMonitor.getKeyPressTimestamps().isEmpty, "State should be clean after complete sequence")
        #endif
    }
}
import XCTest
import CoreGraphics
@testable import ModSwitchIME

class DebugCycle2Test: XCTestCase {
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
    
    func testCycle2DebugStep() {
        #if DEBUG
        print("\n=== Debug Cycle 2 Issue ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // First, complete Cycle 1 to set up the state
        print("\n--- Cycle 1 (Complete) ---")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: [])
        
        print("After Cycle 1 - KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        print("Switches after Cycle 1: \(mockImeController.switchToSpecificIMECalls.count)")
        
        // Now debug Cycle 2 step by step
        print("\n--- Cycle 2 (Debug) ---")
        
        print("Step 1: Press Right CMD")
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.rightCommand.flagMask)
        print("  KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        
        print("Step 2: Press Left CMD (should trigger multi-key with Left CMD as latest)")
        let beforeStep2 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask])
        let afterStep2 = mockImeController.switchToSpecificIMECalls.count
        print("  KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        print("  Switches in Step 2: \(afterStep2 - beforeStep2)")
        
        if afterStep2 > beforeStep2 {
            print("  ✅ IME switch occurred")
            print("  Switched to: \(mockImeController.switchToSpecificIMECalls.last?.ime ?? "unknown")")
        } else {
            print("  ❌ No IME switch occurred")
        }
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        XCTAssertEqual(afterStep2, beforeStep2 + 1, "Should have 1 switch in Cycle 2")
        #endif
    }
}
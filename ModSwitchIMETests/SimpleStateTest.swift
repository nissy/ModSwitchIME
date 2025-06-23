import XCTest
import CoreGraphics
@testable import ModSwitchIME

class SimpleStateTest: XCTestCase {
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
    
    func testBasicMultiKeyPress() {
        #if DEBUG
        print("\n=== Basic Multi-Key Press Test ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        print("Step 1: Press Left CMD")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        print("  KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        
        print("Step 2: Press Right CMD (should trigger multi-key)")
        let before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        let after = mockImeController.switchToSpecificIMECalls.count
        print("  KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        print("  Switches: \(after - before)")
        
        print("Step 3: Release Right CMD")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        print("  KeyPressTimestamps after right release: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        
        print("Step 4: Release Left CMD")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        print("  KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        
        // Force sync to ensure clean state
        keyMonitor.forceStateSync(flags: [])
        print("  KeyPressTimestamps after sync: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        
        print("\n=== Second Attempt ===")
        
        print("Step 5: Press Left CMD again")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        print("  KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        
        print("Step 6: Press Right CMD again (should trigger multi-key)")
        let before2 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        let after2 = mockImeController.switchToSpecificIMECalls.count
        print("  KeyPressTimestamps: \(keyMonitor.getKeyPressTimestamps().keys.map { $0.displayName })")
        print("  Switches: \(after2 - before2)")
        
        XCTAssertEqual(after, before + 1, "First multi-key should work")
        XCTAssertEqual(after2, before2 + 1, "Second multi-key should also work")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        #endif
    }
}
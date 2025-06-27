import XCTest
import CoreGraphics
@testable import ModSwitchIME

class UserScenarioTest: XCTestCase {
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
        
        // Create mock ImeController
        mockImeController = FixedMockImeController()
        
        // Create KeyMonitor with mock dependencies
        keyMonitor = KeyMonitor(preferences: preferences, imeController: mockImeController)
    }
    
    override func tearDown() {
        keyMonitor?.stop()
        keyMonitor = nil
        mockImeController = nil
        preferences = nil
        super.tearDown()
    }
    
    func testUserSpecificSequence() {
        #if DEBUG
        // User's specific sequence:
        // 左CMD押す（切り替わらない） → 右CMD押す（切り替わる） → 左CMD離す（切り替わらない）→ 左CMD押す（切り替わる）
        
        // Testing User Specific Sequence
        
        // Clear initial state
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Step 1: 左CMD押す（切り替わらない）
        // Step 1: Press left CMD (should NOT switch)
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 0, "First key press should not trigger IME switch")
        
        // Step 2: 右CMD押す（切り替わる）
        // Step 2: Press right CMD while left CMD is held (should switch to ATOK)
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls[0].ime, "com.justsystems.inputmethod.atok34.Japanese")
        
        // Step 3: 左CMD離す（切り替わらない）
        // Step 3: Release left CMD (should NOT switch)
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1, "Should not switch on left CMD release")
        
        // Verify state after release
        
        // Step 4: 左CMD押す（切り替わる）
        // Step 4: Press left CMD again while right CMD is still held (should switch to ABC)
        
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        // Verify the switch happened
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls[1].ime, "com.apple.keylayout.ABC", 
                      "Should switch to left CMD's IME")
        
        // Step 5: 右CMD離す（切り替わらない）
        // Step 5: Release right CMD (should NOT switch)
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2, "Should not switch on right CMD release")
        
        // Step 6: 右CMD押す（切り替わる）
        // Step 6: Press right CMD again while left CMD is still held (should switch to ATOK)
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 3)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls[2].ime, "com.justsystems.inputmethod.atok34.Japanese", 
                      "Should switch to right CMD's IME")
        
        // Verify final state
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 3, "Should have exactly 3 IME switches")
        
        // Clean up
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        #endif
    }
}

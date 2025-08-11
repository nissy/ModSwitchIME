import XCTest
import CoreGraphics
@testable import ModSwitchIME

class FixedMultiKeyTest: XCTestCase {
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
    
    // swiftlint:disable:next function_body_length
    func testUserReportedProblemIsFixed() {
        #if DEBUG
        // Test the exact sequence user reported:
        // Press left CMD → Press right CMD (switches) → Release right CMD → Release left CMD → Press right CMD → Press left CMD (doesn't switch)
        
        // Testing User Reported Problem
        
        // Step 1: Press left CMD
        // 1. Press left CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Step 2: Press right CMD (switches)
        // 2. Press right CMD (should switch to ATOK)
        let initialCalls = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        XCTAssertEqual(
            mockImeController.switchToSpecificIMECalls.count,
            initialCalls + 1,
            "Should switch to ATOK on right CMD press"
        )
        XCTAssertEqual(
            mockImeController.switchToSpecificIMECalls.last?.ime,
            "com.justsystems.inputmethod.atok34.Japanese",
            "Should switch to ATOK"
        )
        
        // Step 3: Release right CMD
        // 3. Release right CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Should NOT switch (was involved in multi-key press)
        XCTAssertEqual(
            mockImeController.switchToSpecificIMECalls.count,
            initialCalls + 1,
            "Should NOT switch on right CMD release"
        )
        
        // Step 4: Release left CMD
        // 4. Release left CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        // Should NOT switch (was involved in multi-key press)
        XCTAssertEqual(
            mockImeController.switchToSpecificIMECalls.count,
            initialCalls + 1,
            "Should NOT switch on left CMD release"
        )
        
        // Step 5: Press right CMD  
        // 5. Press right CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        // Step 6: Press left CMD (This is where the bug was - should switch now)
        // 6. Press left CMD (should switch to ABC - this was the bug)
        let beforeStep6 = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        let afterStep6 = mockImeController.switchToSpecificIMECalls.count
        
        // This is the key test - the bug was that this didn't switch
        XCTAssertEqual(afterStep6, beforeStep6 + 1, 
                      "❌ BUG CHECK: Left CMD press should trigger IME switch to ABC")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime,
                      "com.apple.keylayout.ABC",
                      "Should switch to ABC")
        
        // Clean up: release both keys
        // 7. Release left CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        // 8. Release right CMD
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        
        // Test Summary
        // Total IME switches: \(mockImeController.switchToSpecificIMECalls.count)
        // Expected: 2 (step 2 and step 6)
        
        for (index, call) in mockImeController.switchToSpecificIMECalls.enumerated() {
            // Switch \(index + 1): \(call.ime)
        }
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2,
                      "Should have exactly 2 IME switches total")
        #endif
    }
    
    func testActualUserBugReport() {
        #if DEBUG
        // Test the ACTUAL user reported sequence:
        // Press left CMD (switches) → Press right CMD (switches) → Release left CMD (switches - this is the problem!) → Release right CMD (doesn't switch)
        
        // Testing ACTUAL User Reported Problem
        // User says: Press left CMD (switches) → Press right CMD (switches) → Release left CMD (switches - this is the problem!) → Release right CMD (doesn't switch)
        
        // Clear calls
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Step 1: Press left CMD (switches)
        // 1. Press left CMD
        let step1Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        let step1After = mockImeController.switchToSpecificIMECalls.count
        // Step 1 switches: \(step1After - step1Before)
        
        // Step 2: Press right CMD (switches)
        // 2. Press right CMD (should switch to ATOK)
        let step2Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        let step2After = mockImeController.switchToSpecificIMECalls.count
        // Step 2 switches: \(step2After - step2Before)
        
        XCTAssertEqual(step2After, step2Before + 1, "Should switch on multi-key press")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, 
                      "com.justsystems.inputmethod.atok34.Japanese",
                      "Should switch to ATOK")
        
        // Step 3: Release left CMD (switches - this is the problem!)
        // 3. Release left CMD (should NOT switch - this is the bug!) 
        let step3Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask  // Only right CMD still pressed
        )
        let step3After = mockImeController.switchToSpecificIMECalls.count
        // Step 3 switches: \(step3After - step3Before)
        
        // THIS IS THE KEY TEST - should NOT switch on key release during multi-key
        if step3After > step3Before {
            // BUG REPRODUCED: Left CMD release triggered unwanted switch!
            // Switched to: \(mockImeController.switchToSpecificIMECalls.last?.ime ?? "unknown")
            XCTFail("Left CMD release should NOT trigger IME switch during multi-key press")
        } else {
            // Correct: Left CMD release did NOT trigger switch
        }
        
        // Step 4: Release right CMD (doesn't switch)
        // 4. Release right CMD (should NOT switch)
        let step4Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []  // All keys released
        )
        let step4After = mockImeController.switchToSpecificIMECalls.count
        // Step 4 switches: \(step4After - step4Before)
        
        XCTAssertEqual(step4After, step4Before, "Right CMD release should NOT switch")
        
        // Final Summary
        // Total IME switches: \(mockImeController.switchToSpecificIMECalls.count)
        // Expected: 1 (only step 2)
        
        for (index, call) in mockImeController.switchToSpecificIMECalls.enumerated() {
            // Switch \(index + 1): \(call.ime)
        }
        
        // Final assertion: should have exactly 1 switch (step 2 only)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1,
                      "Should have exactly 1 IME switch (step 2 only)")
        #endif
    }
}

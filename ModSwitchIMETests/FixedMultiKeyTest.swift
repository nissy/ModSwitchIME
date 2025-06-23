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
    
    func testUserReportedProblemIsFixed() {
        #if DEBUG
        // Test the exact sequence user reported:
        // 左CMD押す → 右CMD押す（切り替わっている） → 右CMD離す → 左CMD離す → 右CMD押す → 左CMD押す（切り替わっていない）
        
        print("=== Testing User Reported Problem ===")
        
        // Step 1: 左CMD押す
        print("1. 左CMD押す")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Step 2: 右CMD押す（切り替わっている）
        print("2. 右CMD押す（should switch to ATOK）")
        let initialCalls = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, initialCalls + 1, 
                      "Should switch to ATOK on right CMD press")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, 
                      "com.justsystems.inputmethod.atok34.Japanese",
                      "Should switch to ATOK")
        
        // Step 3: 右CMD離す
        print("3. 右CMD離す")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Should NOT switch (was involved in multi-key press)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, initialCalls + 1,
                      "Should NOT switch on right CMD release")
        
        // Step 4: 左CMD離す
        print("4. 左CMD離す")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        // Should NOT switch (was involved in multi-key press)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, initialCalls + 1,
                      "Should NOT switch on left CMD release")
        
        // Step 5: 右CMD押す  
        print("5. 右CMD押す")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        // Step 6: 左CMD押す（This is where the bug was - should switch now）
        print("6. 左CMD押す（should switch to ABC - this was the bug）")
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
        print("7. 左CMD離す")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        print("8. 右CMD離す")
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        
        print("=== Test Summary ===")
        // Total IME switches: \(mockImeController.switchToSpecificIMECalls.count)
        print("Expected: 2 (step 2 and step 6)")
        
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
        // 左CMD押す（切り替わる）→ 右CMD押す（切り替わる）→ 左CMD離す（切り替わるここが問題！）→ 右CMD離す（切り替わらない）
        
        print("\n=== Testing ACTUAL User Reported Problem ===")
        print("User says: 左CMD押す（切り替わる）→ 右CMD押す（切り替わる）→ 左CMD離す（切り替わるここが問題！）→ 右CMD離す（切り替わらない）")
        
        // Clear calls
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Step 1: 左CMD押す（切り替わる）
        print("\n1. 左CMD押す")
        let step1Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        let step1After = mockImeController.switchToSpecificIMECalls.count
        print("   Step 1 switches: \(step1After - step1Before)")
        
        // Step 2: 右CMD押す（切り替わる）
        print("\n2. 右CMD押す（should switch to ATOK）")
        let step2Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        let step2After = mockImeController.switchToSpecificIMECalls.count
        print("   Step 2 switches: \(step2After - step2Before)")
        
        XCTAssertEqual(step2After, step2Before + 1, "Should switch on multi-key press")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, 
                      "com.justsystems.inputmethod.atok34.Japanese",
                      "Should switch to ATOK")
        
        // Step 3: 左CMD離す（切り替わるここが問題！）
        print("\n3. 左CMD離す（should NOT switch - this is the bug!)") 
        let step3Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask  // Only right CMD still pressed
        )
        let step3After = mockImeController.switchToSpecificIMECalls.count
        print("   Step 3 switches: \(step3After - step3Before)")
        
        // THIS IS THE KEY TEST - should NOT switch on key release during multi-key
        if step3After > step3Before {
            print("   ❌ BUG REPRODUCED: Left CMD release triggered unwanted switch!")
            print("   Switched to: \(mockImeController.switchToSpecificIMECalls.last?.ime ?? "unknown")")
            XCTFail("Left CMD release should NOT trigger IME switch during multi-key press")
        } else {
            print("   ✅ Correct: Left CMD release did NOT trigger switch")
        }
        
        // Step 4: 右CMD離す（切り替わらない）
        print("\n4. 右CMD離す（should NOT switch）")
        let step4Before = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []  // All keys released
        )
        let step4After = mockImeController.switchToSpecificIMECalls.count
        print("   Step 4 switches: \(step4After - step4Before)")
        
        XCTAssertEqual(step4After, step4Before, "Right CMD release should NOT switch")
        
        print("\n=== Final Summary ===")
        // Total IME switches: \(mockImeController.switchToSpecificIMECalls.count)
        print("Expected: 1 (only step 2)")
        
        for (index, call) in mockImeController.switchToSpecificIMECalls.enumerated() {
            // Switch \(index + 1): \(call.ime)
        }
        
        // Final assertion: should have exactly 1 switch (step 2 only)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1,
                      "Should have exactly 1 IME switch (step 2 only)")
        #endif
    }
}

import XCTest
import CoreGraphics
@testable import ModSwitchIME

// Mock ImeController for testing
class MockImeController: ImeController {
    var switchToSpecificIMECalls: [(ime: String, time: CFAbsoluteTime)] = []
    
    override func switchToSpecificIME(_ targetIMEId: String) {
        switchToSpecificIMECalls.append((ime: targetIMEId, time: CFAbsoluteTimeGetCurrent()))
        print("MockImeController: Switching to \(targetIMEId)")
    }
}

class KeyMonitorConsecutiveMultiKeyTests: XCTestCase {
    var keyMonitor: KeyMonitor!
    var mockImeController: MockImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
        
        // Setup test IME mappings - matching user's configuration
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        
        preferences.setIME("com.justsystems.inputmethod.atok34.Japanese", for: .rightCommand)
        preferences.setKeyEnabled(true, for: .rightCommand)
        
        // Create KeyMonitor with mock ImeController
        keyMonitor = KeyMonitor()
        mockImeController = MockImeController()
        #if DEBUG
        keyMonitor.setImeController(mockImeController)
        #endif
        
        // Don't start KeyMonitor to avoid CGEventTap permission issues in tests
        // We'll use simulateFlagsChanged instead
    }
    
    override func tearDown() {
        keyMonitor?.stop()
        keyMonitor = nil
        mockImeController = nil
        preferences = nil
        super.tearDown()
    }
    
    // Helper to simulate key press/release
    private func simulateKeyPress(_ key: ModifierKey, down: Bool) {
        #if DEBUG
        let flags: CGEventFlags = down ? key.flagMask : []
        keyMonitor.simulateFlagsChanged(keyCode: key.keyCode, flags: flags)
        #endif
    }
    
    private func getKeyStates() -> [ModifierKey: Bool] {
        #if DEBUG
        let states = keyMonitor.getModifierKeyStates()
        return states.mapValues { $0.isDown }
        #else
        return [:]
        #endif
    }
    
    private func isInMultiKeyMode() -> Bool {
        #if DEBUG
        return keyMonitor.getIsValidMultiKeyPress()
        #else
        return false
        #endif
    }
    
    private func getLastPressedKey() -> ModifierKey? {
        #if DEBUG
        return keyMonitor.getLastPressedModifierKey()
        #else
        return nil
        #endif
    }
    
    // MARK: - Test the exact problematic sequence
    
    func testConsecutiveMultiKeyPress_ProblematicSequence() {
        print("\n=== Testing Problematic Sequence ===")
        
        // First sequence: 左CMD → 右CMD
        print("\n--- First Sequence ---")
        print("1. Press Left CMD")
        simulateKeyPress(.leftCommand, down: true)
        
        XCTAssertTrue(getKeyStates()[.leftCommand] ?? false, "Left CMD should be down")
        XCTAssertFalse(isInMultiKeyMode(), "Not in multi-key mode yet")
        
        print("2. Press Right CMD (should switch to ATOK)")
        let callsBefore = mockImeController.switchToSpecificIMECalls.count
        simulateKeyPress(.rightCommand, down: true)
        
        XCTAssertTrue(getKeyStates()[.rightCommand] ?? false, "Right CMD should be down")
        XCTAssertTrue(isInMultiKeyMode(), "Should be in multi-key mode")
        XCTAssertEqual(getLastPressedKey(), .rightCommand, "Last pressed should be Right CMD")
        
        let callsAfter = mockImeController.switchToSpecificIMECalls.count
        XCTAssertEqual(callsAfter, callsBefore + 1, "Should have triggered one IME switch")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime, 
                      "com.justsystems.inputmethod.atok34.Japanese",
                      "Should switch to ATOK")
        
        print("3. Release Right CMD")
        simulateKeyPress(.rightCommand, down: false)
        XCTAssertFalse(getKeyStates()[.rightCommand] ?? true, "Right CMD should be up")
        
        print("4. Release Left CMD")
        simulateKeyPress(.leftCommand, down: false)
        XCTAssertFalse(getKeyStates()[.leftCommand] ?? true, "Left CMD should be up")
        XCTAssertFalse(isInMultiKeyMode(), "Multi-key mode should be reset")
        
        // Second sequence: 右CMD → 左CMD (problematic)
        print("\n--- Second Sequence (Problematic) ---")
        print("5. Press Right CMD")
        simulateKeyPress(.rightCommand, down: true)
        
        XCTAssertTrue(getKeyStates()[.rightCommand] ?? false, "Right CMD should be down")
        XCTAssertFalse(isInMultiKeyMode(), "Not in multi-key mode yet")
        
        print("6. Press Left CMD (should switch to ABC)")
        let callsBeforeSecond = mockImeController.switchToSpecificIMECalls.count
        simulateKeyPress(.leftCommand, down: true)
        
        XCTAssertTrue(getKeyStates()[.leftCommand] ?? false, "Left CMD should be down")
        
        let callsAfterSecond = mockImeController.switchToSpecificIMECalls.count
        
        // This is where we check if the bug occurs
        if callsAfterSecond == callsBeforeSecond {
            XCTFail("❌ BUG REPRODUCED: Left CMD press did not trigger IME switch!")
            print("❌ BUG REPRODUCED: No IME switch occurred")
        } else {
            print("✅ IME switch occurred correctly")
            XCTAssertTrue(isInMultiKeyMode(), "Should be in multi-key mode")
            XCTAssertEqual(getLastPressedKey(), .leftCommand, "Last pressed should be Left CMD")
            XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime,
                          "com.apple.keylayout.ABC",
                          "Should switch to ABC")
        }
        
        print("7. Release Left CMD")
        simulateKeyPress(.leftCommand, down: false)
        
        print("8. Release Right CMD")
        simulateKeyPress(.rightCommand, down: false)
        
        print("\n=== Test Summary ===")
        print("Total IME switches: \(mockImeController.switchToSpecificIMECalls.count)")
        print("Expected: 2 switches (one for each multi-key sequence)")
        
        for (index, call) in mockImeController.switchToSpecificIMECalls.enumerated() {
            print("  Switch \(index + 1): \(call.ime)")
        }
    }
    
    // Add another test for the exact user-reported sequence
    func testExactUserReportedSequence() {
        print("\n=== Testing Exact User-Reported Sequence ===")
        print("左CMD押す → 右CMD押す → 右CMD離す → 左CMD離す → 右CMD押す → 左CMD押す → 左CMD離す → 右CMD離す")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Step 1: 左CMD押す
        print("\n1. 左CMD押す")
        simulateKeyPress(.leftCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01)
        
        // Step 2: 右CMD押す（切り替わっている）
        print("2. 右CMD押す（切り替わっている）")
        simulateKeyPress(.rightCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01)
        
        let firstSwitchCount = mockImeController.switchToSpecificIMECalls.count
        XCTAssertEqual(firstSwitchCount, 1, "First sequence should trigger switch")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime,
                      "com.justsystems.inputmethod.atok34.Japanese",
                      "Should switch to ATOK")
        
        // Step 3: 右CMD離す
        print("3. 右CMD離す")
        simulateKeyPress(.rightCommand, down: false)
        Thread.sleep(forTimeInterval: 0.01)
        
        // Step 4: 左CMD離す
        print("4. 左CMD離す")
        simulateKeyPress(.leftCommand, down: false)
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertFalse(isInMultiKeyMode(), "Multi-key mode should be reset")
        
        // Step 5: 右CMD押す
        print("\n5. 右CMD押す")
        simulateKeyPress(.rightCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01)
        
        // Step 6: 左CMD押す（切り替わっていない - THIS IS THE BUG）
        print("6. 左CMD押す（切り替わっていない）")
        let countBeforeStep6 = mockImeController.switchToSpecificIMECalls.count
        simulateKeyPress(.leftCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01)
        
        let countAfterStep6 = mockImeController.switchToSpecificIMECalls.count
        
        if countAfterStep6 == countBeforeStep6 {
            XCTFail("❌ BUG REPRODUCED: Step 6 - Left CMD press did not trigger IME switch!")
            print("❌ BUG REPRODUCED at Step 6")
        } else {
            print("✅ Step 6 - IME switch occurred correctly")
            XCTAssertEqual(mockImeController.switchToSpecificIMECalls.last?.ime,
                          "com.apple.keylayout.ABC",
                          "Should switch to ABC")
        }
        
        // Step 7: 左CMD離す
        print("7. 左CMD離す")
        simulateKeyPress(.leftCommand, down: false)
        Thread.sleep(forTimeInterval: 0.01)
        
        // Step 8: 右CMD離す
        print("8. 右CMD離す")
        simulateKeyPress(.rightCommand, down: false)
        
        print("\n=== Final Summary ===")
        print("Total IME switches: \(mockImeController.switchToSpecificIMECalls.count)")
        print("Expected: At least 2 (one at step 2, one at step 6)")
        
        for (index, call) in mockImeController.switchToSpecificIMECalls.enumerated() {
            print("  Switch \(index + 1): \(call.ime) at step ?")
        }
    }
    
    // MARK: - Test rapid sequence debouncing
    
    func testRapidSequenceDebouncing() {
        print("\n=== Testing Rapid Sequence Debouncing ===")
        
        // First multi-key press
        simulateKeyPress(.leftCommand, down: true)
        simulateKeyPress(.rightCommand, down: true)
        
        let firstSwitchCount = mockImeController.switchToSpecificIMECalls.count
        XCTAssertEqual(firstSwitchCount, 1, "First sequence should trigger switch")
        
        // Release both keys
        simulateKeyPress(.rightCommand, down: false)
        simulateKeyPress(.leftCommand, down: false)
        
        // Immediately press the same sequence again (within debounce window)
        print("\nRapid re-press of same sequence...")
        simulateKeyPress(.leftCommand, down: true)
        simulateKeyPress(.rightCommand, down: true)
        
        let secondSwitchCount = mockImeController.switchToSpecificIMECalls.count
        
        // Check if debouncing worked
        if secondSwitchCount > firstSwitchCount {
            print("⚠️ Switch occurred - checking if it was debounced")
            // Look for "MULTI-KEY IGNORED" in logs would be ideal here
        }
        
        simulateKeyPress(.rightCommand, down: false)
        simulateKeyPress(.leftCommand, down: false)
        
        print("\nTotal switches after rapid sequence: \(secondSwitchCount)")
    }
    
    // MARK: - Test state consistency
    
    func testMultiKeyStateTransitions() {
        print("\n=== Testing State Transitions ===")
        
        // Test 1: Single key press shouldn't trigger multi-key mode
        simulateKeyPress(.leftCommand, down: true)
        XCTAssertFalse(isInMultiKeyMode(), "Single key shouldn't trigger multi-key mode")
        simulateKeyPress(.leftCommand, down: false)
        
        // Test 2: Two keys with IME should trigger multi-key mode
        simulateKeyPress(.leftCommand, down: true)
        simulateKeyPress(.rightCommand, down: true)
        XCTAssertTrue(isInMultiKeyMode(), "Two keys with IME should trigger multi-key mode")
        
        // Test 3: Releasing one key should maintain multi-key mode
        simulateKeyPress(.leftCommand, down: false)
        XCTAssertTrue(isInMultiKeyMode(), "Multi-key mode should persist with one key still down")
        
        // Test 4: Releasing all keys should reset multi-key mode
        simulateKeyPress(.rightCommand, down: false)
        XCTAssertFalse(isInMultiKeyMode(), "Multi-key mode should reset when all keys released")
    }
    
    // MARK: - Test the exact debug problem with detailed tracking
    
    func testDetailedProblematicSequence() {
        print("\n=== Testing Detailed Problematic Sequence ===")
        print("This test tracks each IME switch call in detail to identify the issue")
        
        // Clear any previous calls
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Verify initial state
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 0, "Should start with no calls")
        XCTAssertFalse(isInMultiKeyMode(), "Should not be in multi-key mode initially")
        
        print("\n--- Step 1: Start with no keys pressed ---")
        // Ensure all keys are up
        for key in [ModifierKey.leftCommand, .rightCommand] {
            XCTAssertFalse(getKeyStates()[key] ?? true, "\(key.displayName) should be up")
        }
        
        print("\n--- Step 2: Left CMD down ---")
        simulateKeyPress(.leftCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01) // Small delay to simulate real user input
        
        XCTAssertTrue(getKeyStates()[.leftCommand] ?? false, "Left CMD should be down")
        XCTAssertFalse(isInMultiKeyMode(), "Should not be in multi-key mode with single key")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 0, "No switch should occur yet")
        
        print("\n--- Step 3: Right CMD down (should switch to ATOK) ---")
        let callsBeforeStep3 = mockImeController.switchToSpecificIMECalls.count
        simulateKeyPress(.rightCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01)
        
        let callsAfterStep3 = mockImeController.switchToSpecificIMECalls.count
        print("Calls before step 3: \(callsBeforeStep3), after: \(callsAfterStep3)")
        
        XCTAssertTrue(getKeyStates()[.rightCommand] ?? false, "Right CMD should be down")
        XCTAssertTrue(isInMultiKeyMode(), "Should be in multi-key mode now")
        XCTAssertEqual(getLastPressedKey(), .rightCommand, "Last pressed should be Right CMD")
        XCTAssertEqual(callsAfterStep3, 1, "Should have exactly 1 IME switch")
        
        if let lastCall = mockImeController.switchToSpecificIMECalls.last {
            print("Step 3 IME switch: \(lastCall.ime)")
            XCTAssertEqual(lastCall.ime, "com.justsystems.inputmethod.atok34.Japanese", 
                          "Should switch to ATOK")
        } else {
            XCTFail("No IME switch occurred in step 3")
        }
        
        print("\n--- Step 4: Right CMD up ---")
        simulateKeyPress(.rightCommand, down: false)
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertFalse(getKeyStates()[.rightCommand] ?? true, "Right CMD should be up")
        XCTAssertTrue(getKeyStates()[.leftCommand] ?? false, "Left CMD should still be down")
        print("Multi-key mode after step 4: \(isInMultiKeyMode())")
        
        print("\n--- Step 5: Left CMD up ---")
        simulateKeyPress(.leftCommand, down: false)
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertFalse(getKeyStates()[.leftCommand] ?? true, "Left CMD should be up")
        XCTAssertFalse(isInMultiKeyMode(), "Multi-key mode should be reset")
        print("All keys released, multi-key mode reset")
        
        // Wait a bit to ensure clean state
        Thread.sleep(forTimeInterval: 0.05)
        
        print("\n--- Step 6: Right CMD down ---")
        simulateKeyPress(.rightCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertTrue(getKeyStates()[.rightCommand] ?? false, "Right CMD should be down")
        XCTAssertFalse(isInMultiKeyMode(), "Should not be in multi-key mode with single key")
        
        print("\n--- Step 7: Left CMD down (should switch to ABC but may fail) ---")
        let callsBeforeStep7 = mockImeController.switchToSpecificIMECalls.count
        print("Calls before step 7: \(callsBeforeStep7)")
        
        simulateKeyPress(.leftCommand, down: true)
        Thread.sleep(forTimeInterval: 0.01)
        
        let callsAfterStep7 = mockImeController.switchToSpecificIMECalls.count
        print("Calls after step 7: \(callsAfterStep7)")
        
        XCTAssertTrue(getKeyStates()[.leftCommand] ?? false, "Left CMD should be down")
        
        // This is the critical check
        if callsAfterStep7 == callsBeforeStep7 {
            print("❌ BUG REPRODUCED: No IME switch occurred in step 7!")
            print("Expected switch to: com.apple.keylayout.ABC")
            print("Multi-key mode: \(isInMultiKeyMode())")
            print("Last pressed key: \(getLastPressedKey()?.displayName ?? "nil")")
            XCTFail("Step 7 should have triggered IME switch to ABC but didn't")
        } else {
            print("✅ IME switch occurred in step 7")
            XCTAssertTrue(isInMultiKeyMode(), "Should be in multi-key mode")
            XCTAssertEqual(getLastPressedKey(), .leftCommand, "Last pressed should be Left CMD")
            
            if let lastCall = mockImeController.switchToSpecificIMECalls.last {
                print("Step 7 IME switch: \(lastCall.ime)")
                XCTAssertEqual(lastCall.ime, "com.apple.keylayout.ABC", 
                              "Should switch to ABC")
            }
        }
        
        print("\n--- Step 8: Left CMD up ---")
        simulateKeyPress(.leftCommand, down: false)
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertFalse(getKeyStates()[.leftCommand] ?? true, "Left CMD should be up")
        
        print("\n--- Step 9: Right CMD up ---")
        simulateKeyPress(.rightCommand, down: false)
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertFalse(getKeyStates()[.rightCommand] ?? true, "Right CMD should be up")
        XCTAssertFalse(isInMultiKeyMode(), "Multi-key mode should be reset")
        
        print("\n=== Final Analysis ===")
        print("Total IME switch calls: \(mockImeController.switchToSpecificIMECalls.count)")
        print("Expected: 2 (step 3 and step 7)")
        print("\nDetailed call history:")
        for (index, call) in mockImeController.switchToSpecificIMECalls.enumerated() {
            print("  Call \(index + 1): switchToSpecificIME(\"\(call.ime)\") at time \(call.time)")
        }
        
        // Final assertion
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 2, 
                      "Should have exactly 2 IME switches")
    }
    
    // MARK: - Test sequence variations
    
    func testAlternatingSequences() {
        print("\n=== Testing Alternating Sequences ===")
        
        var expectedSwitches = 0
        
        // Pattern: L+R, release, R+L, release, L+R, release
        for i in 1...3 {
            print("\n--- Iteration \(i) ---")
            
            if i % 2 == 1 {
                // Left then Right
                simulateKeyPress(.leftCommand, down: true)
                simulateKeyPress(.rightCommand, down: true)
                expectedSwitches += 1
                XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, expectedSwitches,
                             "Should have \(expectedSwitches) switches")
                simulateKeyPress(.rightCommand, down: false)
                simulateKeyPress(.leftCommand, down: false)
            } else {
                // Right then Left
                simulateKeyPress(.rightCommand, down: true)
                simulateKeyPress(.leftCommand, down: true)
                expectedSwitches += 1
                XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, expectedSwitches,
                             "Should have \(expectedSwitches) switches")
                simulateKeyPress(.leftCommand, down: false)
                simulateKeyPress(.rightCommand, down: false)
            }
            
            // Small delay between sequences
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        print("\nFinal switch count: \(mockImeController.switchToSpecificIMECalls.count)")
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 3,
                      "All three sequences should have triggered switches")
    }
}
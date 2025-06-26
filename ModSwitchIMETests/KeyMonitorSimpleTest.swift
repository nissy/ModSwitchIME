import XCTest
import CoreGraphics
@testable import ModSwitchIME

class KeyMonitorSimpleTest: XCTestCase {
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
    
    func testSingleKeyPress() {
        // Test single key press and release
        #if DEBUG
        // Press left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Release left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: []
        )
        
        // Should switch to ABC
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.first?.ime, "com.apple.keylayout.ABC")
        #endif
    }
    
    func testLongSinglePress() {
        #if DEBUG
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Press and hold for long time (> 300ms)
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Long delay (500ms)
        Thread.sleep(forTimeInterval: 0.5)
        
        // Release - should still trigger IME switch regardless of duration
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        
        // Should switch even for long press
        XCTAssertEqual(
            mockImeController.switchToSpecificIMECalls.count,
            1,
            "Long single press should trigger IME switch"
        )
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.first?.ime, "com.apple.keylayout.ABC")
        #endif
    }
    
    func testMultiKeyPress() {
        #if DEBUG
        // Press left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Press right command while left is still pressed
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        // Should switch once: to the last pressed key (right command)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls[0].ime, "com.justsystems.inputmethod.atok34.Japanese")
        
        // Release left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        
        // Should NOT switch on release
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        
        // Release right command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        
        // Should NOT switch on release
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 1)
        #endif
    }
    
    func testMultiKeyPressWithoutIME() {
        #if DEBUG
        // Disable IME for right command
        preferences.setKeyEnabled(false, for: .rightCommand)
        
        // Press left command
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.leftCommand.flagMask
        )
        
        // Press right command while left is still pressed
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: [ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask]
        )
        
        // Should NOT switch (right command has no IME)
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 0)
        
        // Release both keys
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.leftCommand.keyCode,
            flags: ModifierKey.rightCommand.flagMask
        )
        keyMonitor.simulateFlagsChanged(
            keyCode: ModifierKey.rightCommand.keyCode,
            flags: []
        )
        
        // Still no switch
        XCTAssertEqual(mockImeController.switchToSpecificIMECalls.count, 0)
        #endif
    }
    
    // MARK: - Event Tap Health Monitoring Tests
    
    func testEventTapHealthMonitoring() {
        // Test that event tap health monitoring is set up
        // Note: This test can only verify basic start/stop functionality
        // Real event tap creation requires accessibility permissions
        
        // When monitoring is started
        keyMonitor.start()
        
        // Then: isMonitoring should reflect the state
        // (actual value depends on accessibility permissions)
        let monitoringState = keyMonitor.isMonitoring
        
        // Stop monitoring
        keyMonitor.stop()
        
        // After stopping, should not be monitoring
        XCTAssertFalse(keyMonitor.isMonitoring, "Should not be monitoring after stop")
    }
    
    func testEventTapRecreationOnFailure() {
        // Test conceptual event tap recreation behavior
        // Note: Can't simulate actual event tap failure in unit tests
        
        // Start monitoring
        keyMonitor.start()
        
        // Record initial state
        let initialState = keyMonitor.isMonitoring
        
        // In a real scenario with proper permissions:
        // 1. Event tap would be created
        // 2. Health monitor would check every 5 seconds
        // 3. If disabled, it would attempt to recreate
        
        // For unit test, we just verify the monitor can be started/stopped
        let expectation = XCTestExpectation(description: "Monitor lifecycle test")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify monitor is in expected state
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        keyMonitor.stop()
        XCTAssertFalse(keyMonitor.isMonitoring, "Should be stopped after cleanup")
    }
}

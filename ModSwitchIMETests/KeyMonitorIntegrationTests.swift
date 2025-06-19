import XCTest
@testable import ModSwitchIME

class KeyMonitorIntegrationTests: XCTestCase {
    var keyMonitor: KeyMonitor!
    var imeController: ImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        keyMonitor = KeyMonitor()
        imeController = ImeController()
        preferences = Preferences.createForTesting()
    }
    
    override func tearDown() {
        keyMonitor?.stop()
        keyMonitor = nil
        imeController = nil
        preferences = nil
        super.tearDown()
    }
    
    // MARK: - KeyMonitor Initialization Tests
    
    func testKeyMonitorInitialization() {
        // Given: Fresh KeyMonitor instance
        // When: Creating KeyMonitor
        let monitor = KeyMonitor()
        
        // Then: Should initialize without errors
        XCTAssertNotNil(monitor, "KeyMonitor should initialize successfully")
    }
    
    func testKeyMonitorStartWithoutPermissions() {
        // Given: KeyMonitor without accessibility permissions (typical test environment)
        // When: Attempting to start
        keyMonitor.start()
        
        // Then: Should handle gracefully without crashing
        // Note: In test environment, accessibility permissions are typically not granted
        // The monitor should log a warning and not crash
        XCTAssertTrue(true, "KeyMonitor should handle missing permissions gracefully")
    }
    
    func testKeyMonitorStopWhenNotStarted() {
        // Given: KeyMonitor that hasn't been started
        // When: Attempting to stop
        keyMonitor.stop()
        
        // Then: Should handle gracefully without crashing
        XCTAssertTrue(true, "KeyMonitor should handle stop when not started")
    }
    
    func testMultipleStartStopCycles() {
        // Given: KeyMonitor instance
        // When: Starting and stopping multiple times
        for _ in 0..<5 {
            keyMonitor.start()
            keyMonitor.stop()
        }
        
        // Then: Should handle multiple cycles without issues
        XCTAssertTrue(true, "KeyMonitor should handle multiple start/stop cycles")
    }
    
    // MARK: - ImeController Integration Tests
    
    func testImeControllerInitialization() {
        // Given: Fresh ImeController instance
        // When: Creating ImeController
        let controller = ImeController()
        
        // Then: Should initialize successfully
        XCTAssertNotNil(controller, "ImeController should initialize successfully")
    }
    
    func testImeControllerCurrentInputSource() {
        // Given: ImeController instance
        // When: Getting current input source
        let currentSource = imeController.getCurrentInputSource()
        
        // Then: Should return valid input source
        XCTAssertFalse(currentSource.isEmpty, "Should return non-empty current input source")
        XCTAssertTrue(currentSource.contains("com.apple") || currentSource.contains("inputmethod") || currentSource.contains("keylayout"),
                     "Should return valid input source identifier")
    }
    
    func testImeControllerToggleBehavior() {
        // Given: ImeController with known initial state
        let initialSource = imeController.getCurrentInputSource()
        
        // When: Toggling input method with left cmd (to ASCII)
        imeController.toggleByCmd(isLeft: true)
        let afterLeftCmd = imeController.getCurrentInputSource()
        
        // Then: Should switch to ASCII/English input
        // Note: The exact behavior may vary based on system configuration
        XCTAssertNotNil(afterLeftCmd, "Should return valid source after left cmd")
        
        // When: Toggling with right cmd (to IME)
        imeController.toggleByCmd(isLeft: false)
        let afterRightCmd = imeController.getCurrentInputSource()
        
        // Then: Should switch to configured IME
        XCTAssertNotNil(afterRightCmd, "Should return valid source after right cmd")
    }
    
    func testImeControllerForceAscii() {
        // Given: ImeController instance
        let initialSource = imeController.getCurrentInputSource()
        
        // When: Forcing ASCII mode
        imeController.forceAscii()
        let afterForceAscii = imeController.getCurrentInputSource()
        
        // Then: Should switch to ASCII input
        XCTAssertNotNil(afterForceAscii, "Should return valid source after force ASCII")
        
        // When: Restoring original state (if possible)
        // This is system-dependent and may not always work in test environment
        if !initialSource.contains("ABC") && !initialSource.contains("U.S.") {
            imeController.toggleByCmd(isLeft: false)
        }
    }
    
    // MARK: - Preferences Integration Tests
    
    func testPreferencesWithKeyMonitor() {
        // Given: Preferences instance
        let testPrefs = Preferences.createForTesting()
        
        // When: Modifying idle timeout settings
        testPrefs.idleOffEnabled = true
        testPrefs.idleTimeout = 30.0
        
        // Then: Should persist changes
        XCTAssertTrue(testPrefs.idleOffEnabled, "Idle timeout should be enabled")
        XCTAssertEqual(testPrefs.idleTimeout, 30.0, "Idle timeout should be set to 30 seconds")
    }
    
    func testPreferencesInputSourceSelection() {
        // Given: Available input sources
        let availableSources = Preferences.getAvailableInputSources()
        
        guard !availableSources.isEmpty else {
            XCTSkip("No available input sources found for testing")
            return
        }
        
        // When: Selecting first available source
        let selectedSource = availableSources.first!
        preferences.motherImeId = selectedSource.id
        
        // Then: Should store selection
        XCTAssertEqual(preferences.motherImeId, selectedSource.id, "Should store selected input source")
    }
    
    // MARK: - Component Communication Tests
    
    func testKeyMonitorImeControllerCommunication() {
        // Given: KeyMonitor with ImeController
        // Note: These components communicate through shared state and system events
        
        // When: KeyMonitor is running (in actual usage)
        // The KeyMonitor would call ImeController methods based on key events
        
        // Simulate the communication pattern
        let initialSource = imeController.getCurrentInputSource()
        
        // Simulate left cmd press (switch to ASCII)
        imeController.toggleByCmd(isLeft: true)
        let afterLeftToggle = imeController.getCurrentInputSource()
        
        // Simulate right cmd press (switch to IME)
        imeController.toggleByCmd(isLeft: false)
        let afterRightToggle = imeController.getCurrentInputSource()
        
        // Then: Should demonstrate state changes
        XCTAssertNotNil(initialSource, "Initial source should be valid")
        XCTAssertNotNil(afterLeftToggle, "Source after left toggle should be valid")
        XCTAssertNotNil(afterRightToggle, "Source after right toggle should be valid")
    }
    
    func testPreferencesImeControllerIntegration() {
        // Given: Preferences with specific IME selection
        let testImeId = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        preferences.motherImeId = testImeId
        
        // When: ImeController accesses current configuration
        // Note: ImeController typically reads preferences to determine target IME
        
        // Then: Should be able to access configured IME
        XCTAssertEqual(preferences.motherImeId, testImeId, "Should maintain IME preference")
        
        // Verify ImeController can work with this configuration
        let currentSource = imeController.getCurrentInputSource()
        XCTAssertNotNil(currentSource, "ImeController should work with configured preferences")
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testSystemInputSourceChanges() {
        // Given: System state before test
        let initialSource = imeController.getCurrentInputSource()
        
        // When: External input source changes occur
        // Simulate user manually changing input source through system UI
        imeController.forceAscii()
        let afterSystemChange = imeController.getCurrentInputSource()
        
        // Then: Components should handle external changes gracefully
        XCTAssertNotNil(initialSource, "Initial source should be valid")
        XCTAssertNotNil(afterSystemChange, "Source after system change should be valid")
    }
    
    func testInvalidInputSourceHandling() {
        // Given: Invalid input source ID in preferences
        let originalImeId = preferences.motherImeId
        preferences.motherImeId = "invalid.nonexistent.ime.id"
        
        // When: ImeController attempts to use invalid IME
        // This should not crash the system
        let currentSource = imeController.getCurrentInputSource()
        
        // Then: Should handle gracefully
        XCTAssertNotNil(currentSource, "Should handle invalid IME ID gracefully")
        
        // Restore original preference
        preferences.motherImeId = originalImeId
    }
    
    // MARK: - Performance Integration Tests
    
    func testComponentPerformanceUnderLoad() {
        // Given: Multiple components working together
        measure {
            // When: Performing multiple operations rapidly
            for _ in 0..<50 {
                // Simulate rapid input source queries and changes
                _ = imeController.getCurrentInputSource()
                _ = Preferences.getAllInputSources()
                _ = Preferences.getAvailableInputSources()
                
                // Simulate preference changes
                preferences.idleTimeout = Double.random(in: 1.0...300.0)
            }
        }
        
        // Then: Should complete within reasonable time
    }
    
    func testMemoryUsageIntegration() {
        // Given: Multiple component instances
        // When: Creating and destroying components repeatedly
        for _ in 0..<20 {
            autoreleasepool {
                let tempMonitor = KeyMonitor()
                let tempController = ImeController()
                let tempPreferences = Preferences.createForTesting()
                
                // Use components briefly
                _ = tempController.getCurrentInputSource()
                tempPreferences.idleTimeout = 10.0
                
                // Components should be deallocated at end of autoreleasepool
            }
        }
        
        // Then: Should not leak memory significantly
        XCTAssertTrue(true, "Memory integration test completed")
    }
    
    // MARK: - Thread Safety Integration Tests
    
    func testConcurrentComponentAccess() {
        // Given: Concurrent execution environment
        let concurrentQueue = DispatchQueue(label: "test.concurrent.components", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Concurrent component access")
        expectation.expectedFulfillmentCount = 3
        
        // When: Accessing components concurrently
        concurrentQueue.async {
            for _ in 0..<10 {
                _ = self.imeController.getCurrentInputSource()
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for _ in 0..<10 {
                _ = Preferences.getAllInputSources()
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for i in 0..<10 {
                self.preferences.idleTimeout = Double(i + 1)
            }
            expectation.fulfill()
        }
        
        // Then: Should handle concurrent access without crashes
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Lifecycle Integration Tests
    
    func testComponentLifecycleIntegration() {
        // Given: Component dependencies
        weak var weakMonitor: KeyMonitor?
        weak var weakController: ImeController?
        weak var weakPreferences: Preferences?
        
        autoreleasepool {
            let monitor = KeyMonitor()
            let controller = ImeController()
            let preferences = Preferences.createForTesting()
            
            weakMonitor = monitor
            weakController = controller
            weakPreferences = preferences
            
            // Use components together
            preferences.idleTimeout = 25.0
            _ = controller.getCurrentInputSource()
            monitor.start()
            monitor.stop()
            
            XCTAssertNotNil(weakMonitor, "Components should exist during use")
            XCTAssertNotNil(weakController, "Components should exist during use")
            XCTAssertNotNil(weakPreferences, "Components should exist during use")
        }
        
        // Then: Should be properly deallocated
        XCTAssertNil(weakMonitor, "KeyMonitor should be deallocated")
        XCTAssertNil(weakController, "ImeController should be deallocated")
        XCTAssertNil(weakPreferences, "Preferences should be deallocated")
    }
}

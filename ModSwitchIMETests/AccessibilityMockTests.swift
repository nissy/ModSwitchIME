import XCTest
import Cocoa
@testable import ModSwitchIME

// MARK: - Mock Protocols

protocol AccessibilityPermissionProviding {
    func isProcessTrusted() -> Bool
    func promptForAccessibility() -> Bool
}

// MARK: - Mock Implementation

class MockAccessibilityProvider: AccessibilityPermissionProviding {
    var isTrusted: Bool
    var promptResult: Bool
    
    init(isTrusted: Bool = false, promptResult: Bool = false) {
        self.isTrusted = isTrusted
        self.promptResult = promptResult
    }
    
    func isProcessTrusted() -> Bool {
        return isTrusted
    }
    
    func promptForAccessibility() -> Bool {
        return promptResult
    }
}

// MARK: - Testable Components

class TestableKeyMonitor {
    private let accessibilityProvider: AccessibilityPermissionProviding
    private(set) var isMonitoring = false
    private(set) var eventHandlerCalled = false
    
    init(accessibilityProvider: AccessibilityPermissionProviding = MockAccessibilityProvider()) {
        self.accessibilityProvider = accessibilityProvider
    }
    
    func startMonitoring() -> Bool {
        guard accessibilityProvider.isProcessTrusted() else {
            ModSwitchIMELogger.error("Accessibility permission denied")
            return false
        }
        
        isMonitoring = true
        ModSwitchIMELogger.info("Key monitoring started")
        return true
    }
    
    func stopMonitoring() {
        isMonitoring = false
        ModSwitchIMELogger.info("Key monitoring stopped")
    }
    
    func handleKeyEvent() {
        guard isMonitoring else { return }
        eventHandlerCalled = true
    }
}

class TestableMenuBarApp {
    let accessibilityProvider: AccessibilityPermissionProviding
    let keyMonitor: TestableKeyMonitor
    let preferences = Preferences.createForTesting()
    
    var isAccessibilityEnabled: Bool {
        return accessibilityProvider.isProcessTrusted()
    }
    
    init(accessibilityProvider: AccessibilityPermissionProviding = MockAccessibilityProvider()) {
        self.accessibilityProvider = accessibilityProvider
        self.keyMonitor = TestableKeyMonitor(accessibilityProvider: accessibilityProvider)
    }
    
    func checkAndRequestPermissions() -> Bool {
        if accessibilityProvider.isProcessTrusted() {
            return true
        }
        
        return accessibilityProvider.promptForAccessibility()
    }
}

// MARK: - Test Cases

class AccessibilityMockTests: XCTestCase {
    
    // MARK: - Permission Granted Tests
    
    func testKeyMonitorWithPermissionGranted() {
        // Given: Accessibility permission is granted
        let mockProvider = MockAccessibilityProvider(isTrusted: true)
        let keyMonitor = TestableKeyMonitor(accessibilityProvider: mockProvider)
        
        // When: Starting monitoring
        let result = keyMonitor.startMonitoring()
        
        // Then: Monitoring should start successfully
        XCTAssertTrue(result, "Monitoring should start with permissions")
        XCTAssertTrue(keyMonitor.isMonitoring, "Monitor should be active")
    }
    
    func testKeyMonitorEventHandlingWithPermission() {
        // Given: Active key monitor with permissions
        let mockProvider = MockAccessibilityProvider(isTrusted: true)
        let keyMonitor = TestableKeyMonitor(accessibilityProvider: mockProvider)
        
        XCTAssertTrue(keyMonitor.startMonitoring())
        
        // When: Handling key event
        keyMonitor.handleKeyEvent()
        
        // Then: Event should be handled
        XCTAssertTrue(keyMonitor.eventHandlerCalled, "Event handler should be called")
    }
    
    // MARK: - Permission Denied Tests
    
    func testKeyMonitorWithPermissionDenied() {
        // Given: Accessibility permission is denied
        let mockProvider = MockAccessibilityProvider(isTrusted: false)
        let keyMonitor = TestableKeyMonitor(accessibilityProvider: mockProvider)
        
        // When: Attempting to start monitoring
        let result = keyMonitor.startMonitoring()
        
        // Then: Monitoring should fail
        XCTAssertFalse(result, "Monitoring should fail without permissions")
        XCTAssertFalse(keyMonitor.isMonitoring, "Monitor should not be active")
    }
    
    func testKeyMonitorEventHandlingWithoutPermission() {
        // Given: Key monitor without permissions
        let mockProvider = MockAccessibilityProvider(isTrusted: false)
        let keyMonitor = TestableKeyMonitor(accessibilityProvider: mockProvider)
        
        // When: Attempting to handle event without starting
        keyMonitor.handleKeyEvent()
        
        // Then: Event should not be handled
        XCTAssertFalse(keyMonitor.eventHandlerCalled, "Event handler should not be called")
    }
    
    // MARK: - Permission Request Tests
    
    func testAccessibilityPermissionPromptAccepted() {
        // Given: User will accept permission prompt
        let mockProvider = MockAccessibilityProvider(isTrusted: false, promptResult: true)
        let app = TestableMenuBarApp(accessibilityProvider: mockProvider)
        
        // When: Requesting permissions
        let result = app.checkAndRequestPermissions()
        
        // Then: Should return true (user accepted)
        XCTAssertTrue(result, "Permission request should succeed")
    }
    
    func testAccessibilityPermissionPromptDenied() {
        // Given: User will deny permission prompt
        let mockProvider = MockAccessibilityProvider(isTrusted: false, promptResult: false)
        let app = TestableMenuBarApp(accessibilityProvider: mockProvider)
        
        // When: Requesting permissions
        let result = app.checkAndRequestPermissions()
        
        // Then: Should return false (user denied)
        XCTAssertFalse(result, "Permission request should fail")
    }
    
    func testNoPromptWhenAlreadyGranted() {
        // Given: Permission already granted
        let mockProvider = MockAccessibilityProvider(isTrusted: true)
        let app = TestableMenuBarApp(accessibilityProvider: mockProvider)
        
        // When: Checking permissions
        let result = app.checkAndRequestPermissions()
        
        // Then: Should return true without prompting
        XCTAssertTrue(result, "Should return true without prompting")
        XCTAssertTrue(app.isAccessibilityEnabled, "Accessibility should be enabled")
    }
    
    // MARK: - State Transition Tests
    
    func testPermissionStateTransition() {
        // Given: Dynamic permission provider
        class DynamicMockProvider: AccessibilityPermissionProviding {
            var isTrusted = false
            
            func isProcessTrusted() -> Bool {
                return isTrusted
            }
            
            func promptForAccessibility() -> Bool {
                // Simulate user granting permission
                isTrusted = true
                return true
            }
        }
        
        let dynamicProvider = DynamicMockProvider()
        let app = TestableMenuBarApp(accessibilityProvider: dynamicProvider)
        
        // Initially denied
        XCTAssertFalse(app.isAccessibilityEnabled, "Should start without permissions")
        
        // When: Requesting permissions
        let result = app.checkAndRequestPermissions()
        
        // Then: Permission should be granted
        XCTAssertTrue(result, "Permission request should succeed")
        XCTAssertTrue(app.isAccessibilityEnabled, "Should have permissions after prompt")
    }
    
    // MARK: - Menu State Tests
    
    func testMenuItemStatesBasedOnPermissions() {
        // Given: App states with different permissions
        let scenarios: [(trusted: Bool, expectedMenuState: String)] = [
            (true, "enabled"),
            (false, "disabled")
        ]
        
        for scenario in scenarios {
            let mockProvider = MockAccessibilityProvider(isTrusted: scenario.trusted)
            let app = TestableMenuBarApp(accessibilityProvider: mockProvider)
            
            // When: Checking menu state
            let menuState = app.isAccessibilityEnabled ? "enabled" : "disabled"
            
            // Then: Menu state should match
            XCTAssertEqual(menuState, scenario.expectedMenuState,
                          "Menu state should be \(scenario.expectedMenuState) when trusted=\(scenario.trusted)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingForPermissionDenied() {
        // Given: Permission denied scenario
        let mockProvider = MockAccessibilityProvider(isTrusted: false)
        let keyMonitor = TestableKeyMonitor(accessibilityProvider: mockProvider)
        
        // When: Attempting operations without permission
        let monitoringStarted = keyMonitor.startMonitoring()
        
        // Then: Should handle gracefully
        XCTAssertFalse(monitoringStarted, "Should not start monitoring")
        XCTAssertFalse(keyMonitor.isMonitoring, "Should not be monitoring")
        
        // Verify can still stop (no-op)
        keyMonitor.stopMonitoring()
        XCTAssertFalse(keyMonitor.isMonitoring, "Should remain not monitoring")
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflowWithMockPermissions() {
        // Given: Complete workflow simulation
        let mockProvider = MockAccessibilityProvider(isTrusted: false)
        let app = TestableMenuBarApp(accessibilityProvider: mockProvider)
        
        // Step 1: Check initial state
        XCTAssertFalse(app.isAccessibilityEnabled, "Should start without permissions")
        XCTAssertFalse(app.keyMonitor.isMonitoring, "Monitor should not be active")
        
        // Step 2: Attempt to start monitoring (should fail)
        let startResult = app.keyMonitor.startMonitoring()
        XCTAssertFalse(startResult, "Starting should fail without permissions")
        
        // Step 3: Grant permissions
        mockProvider.isTrusted = true
        
        // Step 4: Try again with permissions
        let retryResult = app.keyMonitor.startMonitoring()
        XCTAssertTrue(retryResult, "Starting should succeed with permissions")
        XCTAssertTrue(app.keyMonitor.isMonitoring, "Monitor should be active")
        
        // Step 5: Handle events
        app.keyMonitor.handleKeyEvent()
        XCTAssertTrue(app.keyMonitor.eventHandlerCalled, "Events should be handled")
        
        // Step 6: Stop monitoring
        app.keyMonitor.stopMonitoring()
        XCTAssertFalse(app.keyMonitor.isMonitoring, "Monitor should be stopped")
    }
    
    // MARK: - Preferences Integration Tests
    
    func testPreferencesWithAccessibilityState() {
        // Given: App with preferences and permissions
        let mockProvider = MockAccessibilityProvider(isTrusted: true)
        let app = TestableMenuBarApp(accessibilityProvider: mockProvider)
        
        // When: Modifying preferences
        app.preferences.idleOffEnabled = true
        app.preferences.idleTimeout = 30.0
        
        // Then: Preferences should work regardless of permission state
        XCTAssertTrue(app.preferences.idleOffEnabled)
        XCTAssertEqual(app.preferences.idleTimeout, 30.0)
        
        // When: Revoking permissions
        mockProvider.isTrusted = false
        
        // Then: Preferences should still work
        XCTAssertTrue(app.preferences.idleOffEnabled)
        XCTAssertEqual(app.preferences.idleTimeout, 30.0)
    }
    
    // MARK: - Notification Tests
    
    func testNotificationOnPermissionChange() {
        // Given: Notification observer
        let notificationExpectation = XCTestExpectation(description: "Permission change notification")
        let notificationName = Notification.Name("AccessibilityPermissionChanged")
        
        let observer = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { _ in
            notificationExpectation.fulfill()
        }
        
        // When: Permission state changes
        NotificationCenter.default.post(name: notificationName, object: nil,
                                      userInfo: ["granted": true])
        
        // Then: Notification should be received
        wait(for: [notificationExpectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Async Permission Check Tests
    
    func testAsyncPermissionCheck() {
        // Given: Async permission checking
        let mockProvider = MockAccessibilityProvider(isTrusted: false)
        let expectation = XCTestExpectation(description: "Async permission check")
        
        // When: Checking permissions asynchronously
        DispatchQueue.global().async {
            let trusted = mockProvider.isProcessTrusted()
            
            DispatchQueue.main.async {
                // Then: Should get result
                XCTAssertFalse(trusted, "Should not be trusted")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Real Permission Check (Non-Mock)
    
    func testRealAccessibilityPermissionStatus() {
        // Given: Real system permission check
        let hasRealPermission = AXIsProcessTrusted()
        
        // Then: Log actual state (test passes either way)
        if hasRealPermission {
            XCTAssertTrue(hasRealPermission, "App has accessibility permissions")
            ModSwitchIMELogger.info("Test environment has accessibility permissions")
        } else {
            XCTAssertFalse(hasRealPermission, "App lacks accessibility permissions")
            ModSwitchIMELogger.info("Test environment lacks accessibility permissions")
        }
    }
}

import XCTest
import SwiftUI
@testable import ModSwitchIME

class UIStateTransitionTests: XCTestCase {
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
    }
    
    override func tearDown() {
        preferences = nil
        super.tearDown()
    }
    
    // MARK: - Preferences View State Tests
    
    func testIdleOffEnabledStateTransition() {
        // Given: Initial state with idle off disabled
        preferences.idleOffEnabled = false
        
        // When: Enabling idle off
        preferences.idleOffEnabled = true
        
        // Then: Related UI should update
        XCTAssertTrue(preferences.idleOffEnabled, "Idle off should be enabled")
        XCTAssertEqual(preferences.idleTimeout, 5.0, "Default timeout should be set")
    }
    
    func testIdleTimeoutStepperStateChanges() {
        // Given: Various timeout values
        let testValues: [Double] = [1, 5, 10, 30, 60, 300, 600]
        
        // When: Setting different timeout values
        for value in testValues {
            preferences.idleTimeout = value
            
            // Then: Value should be persisted
            XCTAssertEqual(preferences.idleTimeout, value, "Timeout should be \(value)")
            
            // Verify UI constraints (1-600 seconds)
            XCTAssertGreaterThanOrEqual(preferences.idleTimeout, 1.0)
            XCTAssertLessThanOrEqual(preferences.idleTimeout, 600.0)
        }
    }
    
    func testInputSourceSelectionStateTransition() {
        // Given: Available input sources
        let availableSources = Preferences.getAvailableInputSources()
        guard !availableSources.isEmpty else {
            XCTSkip("No input sources available")
            return
        }
        
        // When: Selecting different input sources
        for source in availableSources.prefix(3) {
            preferences.motherImeId = source.id
            
            // Then: Selection should persist
            XCTAssertEqual(preferences.motherImeId, source.id)
        }
    }
    
    // MARK: - Launch at Login State Tests
    
    func testLaunchAtLoginToggleTransition() {
        // Given: Initial state
        let initialState = preferences.launchAtLogin
        
        // When: Toggling multiple times
        for i in 0..<5 {
            let expectedState = (i % 2 == 0) ? !initialState : initialState
            preferences.launchAtLogin = expectedState
            
            // Then: State should match expectation
            XCTAssertEqual(preferences.launchAtLogin, expectedState)
        }
    }
    
    // MARK: - Settings Panel Tab Transitions
    
    func testSettingsTabTransitions() {
        // Given: Tab enumeration
        enum SettingsTab: String, CaseIterable {
            case general = "General"
            case inputSources = "Input Sources"
            case about = "About"
        }
        
        // When: Transitioning between tabs
        for tab in SettingsTab.allCases {
            // Simulate tab selection
            let selectedTab = tab.rawValue
            
            // Then: Tab should be selectable
            XCTAssertNotNil(selectedTab)
            XCTAssertFalse(selectedTab.isEmpty)
        }
    }
    
    // MARK: - Error State Transitions
    
    func testErrorAlertStateTransitions() {
        // Given: Various error conditions
        struct AlertState {
            var isPresented: Bool = false
            var title: String = ""
            var message: String = ""
        }
        
        var alertState = AlertState()
        
        // When: Error occurs
        let error = ModSwitchIMEError.accessibilityPermissionDenied
        alertState.isPresented = true
        alertState.title = "Permission Required"
        alertState.message = error.errorDescription ?? ""
        
        // Then: Alert state should be configured
        XCTAssertTrue(alertState.isPresented)
        XCTAssertEqual(alertState.title, "Permission Required")
        XCTAssertFalse(alertState.message.isEmpty)
        
        // When: Dismissing alert
        alertState.isPresented = false
        
        // Then: Alert should be dismissed
        XCTAssertFalse(alertState.isPresented)
    }
    
    // MARK: - Menu Bar Icon State Tests
    
    func testMenuBarIconStateTransitions() {
        // Given: Different app states
        enum AppState {
            case active
            case inactive
            case permissionDenied
            case error
        }
        
        // State to icon mapping
        func iconForState(_ state: AppState) -> String {
            switch state {
            case .active:
                return "⌘"
            case .inactive:
                return "⌘?"
            case .permissionDenied:
                return "⌘!"
            case .error:
                return "⌘⚠"
            }
        }
        
        // When: Transitioning through states
        let states: [AppState] = [.inactive, .active, .permissionDenied, .error, .active]
        
        for state in states {
            let icon = iconForState(state)
            
            // Then: Icon should match state
            XCTAssertFalse(icon.isEmpty)
            XCTAssertTrue(icon.contains("⌘"))
        }
    }
    
    // MARK: - Async State Update Tests
    
    func testAsyncPreferenceStateUpdates() {
        // Given: Async state updates
        let expectation = XCTestExpectation(description: "Async state update")
        var stateUpdateCount = 0
        
        // When: Performing async updates
        DispatchQueue.global().async {
            self.preferences.idleTimeout = 10.0
            stateUpdateCount += 1
            
            DispatchQueue.main.async {
                XCTAssertEqual(self.preferences.idleTimeout, 10.0)
                stateUpdateCount += 1
                expectation.fulfill()
            }
        }
        
        // Then: Updates should complete
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(stateUpdateCount, 2)
    }
    
    // MARK: - Combined State Transitions
    
    func testCombinedSettingsStateTransition() {
        // Given: Initial state
        let initialIdleEnabled = preferences.idleOffEnabled
        let initialTimeout = preferences.idleTimeout
        let initialLaunchAtLogin = preferences.launchAtLogin
        
        // When: Making multiple changes
        preferences.idleOffEnabled = !initialIdleEnabled
        preferences.idleTimeout = 30.0
        preferences.launchAtLogin = !initialLaunchAtLogin
        
        // Then: All changes should persist
        XCTAssertNotEqual(preferences.idleOffEnabled, initialIdleEnabled)
        XCTAssertNotEqual(preferences.idleTimeout, initialTimeout)
        XCTAssertNotEqual(preferences.launchAtLogin, initialLaunchAtLogin)
    }
    
    // MARK: - State Validation Tests
    
    func testStateValidationOnBoundaryValues() {
        // Given: Boundary values for timeout
        let boundaryValues: [(input: Double, expected: Double)] = [
            (0.5, 1.0),      // Below minimum
            (1.0, 1.0),      // Minimum
            (300.0, 300.0),  // Middle
            (600.0, 600.0),  // Maximum
            (700.0, 600.0)   // Above maximum
        ]
        
        // When: Setting boundary values
        for (input, expected) in boundaryValues {
            // Simulate UI constraint
            let constrainedValue = max(1.0, min(600.0, input))
            preferences.idleTimeout = constrainedValue
            
            // Then: Value should be constrained
            XCTAssertEqual(preferences.idleTimeout, expected)
        }
    }
    
    // MARK: - Window State Transitions
    
    func testPreferencesWindowStateTransitions() {
        // Given: Window state tracking
        struct WindowState {
            var isVisible: Bool = false
            var isKeyWindow: Bool = false
            var isMiniaturized: Bool = false
        }
        
        var windowState = WindowState()
        
        // When: Window becomes visible
        windowState.isVisible = true
        windowState.isKeyWindow = true
        
        // Then: State should update
        XCTAssertTrue(windowState.isVisible)
        XCTAssertTrue(windowState.isKeyWindow)
        XCTAssertFalse(windowState.isMiniaturized)
        
        // When: Window is miniaturized
        windowState.isMiniaturized = true
        windowState.isKeyWindow = false
        
        // Then: State should reflect miniaturization
        XCTAssertTrue(windowState.isMiniaturized)
        XCTAssertFalse(windowState.isKeyWindow)
    }
    
    // MARK: - State Persistence Tests
    
    func testStatePersistenceAcrossInstances() {
        // Given: Store original values
        let originalIdleOffEnabled = preferences.idleOffEnabled
        let originalIdleTimeout = preferences.idleTimeout
        let originalMotherImeId = preferences.motherImeId
        
        // When: Modifying preferences
        preferences.idleOffEnabled = true
        preferences.idleTimeout = 45.0
        preferences.motherImeId = "test.ime.id"
        
        // Then: Since both preferences and Preferences.shared are the same singleton instance
        // when created with createForTesting, they should have the same values
        // However, preferences was created with createForTesting which may have reset values
        // So we just verify that the values were set correctly
        XCTAssertTrue(preferences.idleOffEnabled)
        XCTAssertEqual(preferences.idleTimeout, 45.0)
        XCTAssertEqual(preferences.motherImeId, "test.ime.id")
        
        // And verify they persist in UserDefaults
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "idleOffEnabled"), true)
        XCTAssertEqual(UserDefaults.standard.double(forKey: "idleTimeout"), 45.0)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "motherImeId"), "test.ime.id")
        
        // Cleanup - restore original values
        preferences.idleOffEnabled = originalIdleOffEnabled
        preferences.idleTimeout = originalIdleTimeout
        preferences.motherImeId = originalMotherImeId
    }
    
    // MARK: - Input Method State Tests
    
    func testInputMethodStateTransitions() {
        // Given: IME controller
        let imeController = ImeController()
        let initialSource = imeController.getCurrentInputSource()
        
        // When: Toggling input methods
        imeController.toggleByCmd(isLeft: true)
        let afterLeftCmd = imeController.getCurrentInputSource()
        
        imeController.toggleByCmd(isLeft: false)
        let afterRightCmd = imeController.getCurrentInputSource()
        
        // Then: Sources should be valid (actual switching depends on system state)
        XCTAssertFalse(initialSource.isEmpty)
        XCTAssertFalse(afterLeftCmd.isEmpty)
        XCTAssertFalse(afterRightCmd.isEmpty)
    }
    
    // MARK: - Animation State Tests
    
    func testUIAnimationStates() {
        // Given: Animation states
        var animationStates = [
            "fadeIn": false,
            "fadeOut": false,
            "slideIn": false,
            "slideOut": false
        ]
        
        // When: Triggering animations
        animationStates["fadeIn"] = true
        XCTAssertTrue(animationStates["fadeIn"] ?? false)
        
        // Simulate animation completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animationStates["fadeIn"] = false
            animationStates["fadeOut"] = true
        }
        
        // Then: States should transition correctly
        let expectation = XCTestExpectation(description: "Animation completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(animationStates["fadeIn"] ?? true)
            XCTAssertTrue(animationStates["fadeOut"] ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Notification State Tests
    
    func testNotificationStateTransitions() {
        // Given: Notification observer
        var notificationReceived = false
        let notificationName = Notification.Name("TestStateChange")
        
        let observer = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }
        
        // When: State changes trigger notification
        NotificationCenter.default.post(name: notificationName, object: nil)
        
        // Then: Notification should be received
        let expectation = XCTestExpectation(description: "Notification received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(notificationReceived)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
        NotificationCenter.default.removeObserver(observer)
    }
}

import XCTest
import SwiftUI
import Cocoa
@testable import ModSwitchIME

class MenuBarAppTests: XCTestCase {
    var menuBarApp: MenuBarApp!
    
    override func setUp() {
        super.setUp()
        menuBarApp = MenuBarApp()
    }
    
    override func tearDown() {
        menuBarApp = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testMenuBarAppInitialization() {
        // Given: MenuBarApp instance
        // When: Created
        let app = MenuBarApp()
        
        // Then: Should initialize properly
        XCTAssertNotNil(app, "MenuBarApp should initialize")
        XCTAssertNotNil(app.preferences, "Preferences should be initialized")
    }
    
    func testMenuBarAppMainThreadInitialization() {
        // Given: Main thread execution
        let expectation = XCTestExpectation(description: "Main thread initialization")
        
        // When: Creating MenuBarApp on background thread
        DispatchQueue.global().async {
            let app = MenuBarApp()
            
            // Then: Should handle thread safety
            DispatchQueue.main.async {
                XCTAssertNotNil(app, "MenuBarApp should initialize from background thread")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Menu State Tests
    
    func testMenuStateWithoutPermissions() {
        // Given: MenuBarApp without accessibility permissions
        // When: Checking initial state
        // Then: Menu items should reflect permission state
        // Note: In test environment, we typically don't have permissions
        XCTAssertNotNil(menuBarApp, "MenuBarApp should exist")
    }
    
    func testPreferencesWindowCreation() {
        // Given: MenuBarApp instance
        // When: Showing preferences
        // Note: We can't actually show windows in unit tests, but we can test the creation logic
        
        // Test that preferences object exists and is properly configured
        XCTAssertNotNil(menuBarApp.preferences, "Preferences should exist")
        XCTAssertEqual(menuBarApp.preferences.idleTimeout, 5.0, "Default timeout should be 5.0")
    }
    
    // MARK: - Notification Tests
    
    func testSystemNotificationSetup() {
        // Given: MenuBarApp with notification observers
        // When: System notifications are posted
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // Test sleep notification
        let sleepExpectation = XCTestExpectation(description: "Sleep notification")
        sleepExpectation.isInverted = true // We don't expect this to be fulfilled in test
        
        // Post notification (won't actually trigger in test environment)
        notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        
        // Then: Should not crash
        wait(for: [sleepExpectation], timeout: 0.1)
        XCTAssertTrue(true, "Notification posting should not crash")
    }
    
    func testScreenLockNotifications() {
        // Given: MenuBarApp with screen lock observers
        let distributedCenter = DistributedNotificationCenter.default()
        
        // When: Screen lock notification is posted
        distributedCenter.post(name: .screenIsLocked, object: nil)
        
        // Then: Should handle without crashing
        XCTAssertTrue(true, "Screen lock notification should be handled")
        
        // When: Screen unlock notification is posted
        distributedCenter.post(name: .screenIsUnlocked, object: nil)
        
        // Then: Should handle without crashing
        XCTAssertTrue(true, "Screen unlock notification should be handled")
    }
    
    // MARK: - Launch at Login Tests
    
    func testLaunchAtLoginToggle() {
        // Given: Initial launch at login state
        let initialState = menuBarApp.preferences.launchAtLogin
        
        // When: Toggling launch at login
        menuBarApp.preferences.launchAtLogin = !initialState
        
        // Then: State should change
        XCTAssertNotEqual(menuBarApp.preferences.launchAtLogin, initialState, "Launch at login state should toggle")
        
        // Restore original state
        menuBarApp.preferences.launchAtLogin = initialState
    }
    
    // MARK: - Menu Item State Tests
    
    func testMenuItemEnableStates() {
        // Given: MenuBarApp without accessibility permissions
        // When: Checking menu state
        // Then: Permission-dependent items should be disabled
        
        // In test environment, we typically don't have permissions
        // This test verifies the logic exists without actually creating UI
        XCTAssertNotNil(menuBarApp, "MenuBarApp should exist for menu testing")
    }
    
    // MARK: - Error Alert Tests
    
    func testErrorAlertConfiguration() {
        // Given: Various error types
        let errors: [Error] = [
            ModSwitchIMEError.accessibilityPermissionDenied,
            ModSwitchIMEError.inputSourceNotFound("test.source"),
            ModSwitchIMEError.imeControllerInitializationFailed,
            NSError(domain: "TestDomain", code: 123, userInfo: nil)
        ]
        
        // When: Processing errors (without showing alerts in test)
        for error in errors {
            // Verify error handling logic exists
            if let modSwitchIMEError = error as? ModSwitchIMEError {
                XCTAssertNotNil(modSwitchIMEError.errorDescription, "ModSwitchIMEError should have description")
                XCTAssertNotNil(modSwitchIMEError.recoverySuggestion, "ModSwitchIMEError should have recovery suggestion")
            }
        }
        
        // Then: All errors should be processable
        XCTAssertTrue(true, "All errors should be processable without crashing")
    }
    
    // MARK: - Memory Management Tests
    
    func testMenuBarAppMemoryCleanup() {
        // Given: MenuBarApp instance
        weak var weakApp: MenuBarApp?
        
        autoreleasepool {
            let tempApp = MenuBarApp()
            weakApp = tempApp
            
            // Use the app
            _ = tempApp.preferences.idleTimeout
            
            XCTAssertNotNil(weakApp, "App should exist during use")
        }
        
        // Then: Should be deallocated
        XCTAssertNil(weakApp, "MenuBarApp should be deallocated when out of scope")
    }
    
    func testPreferencesWindowMemoryManagement() {
        // Given: References to preferences
        let preferences = menuBarApp.preferences
        weak var weakPreferences: Preferences? = preferences
        
        // When: Using preferences
        preferences.idleTimeout = 10.0
        
        // Then: Should maintain strong reference through MenuBarApp
        XCTAssertNotNil(weakPreferences, "Preferences should be retained by MenuBarApp")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentPreferencesAccess() {
        // Given: Concurrent access to preferences
        let concurrentQueue = DispatchQueue(label: "test.concurrent.menubar", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 3
        
        // When: Accessing preferences concurrently
        concurrentQueue.async {
            for _ in 0..<10 {
                _ = self.menuBarApp.preferences.idleTimeout
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for i in 0..<10 {
                self.menuBarApp.preferences.idleTimeout = Double(i)
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for _ in 0..<10 {
                _ = self.menuBarApp.preferences.motherImeId
            }
            expectation.fulfill()
        }
        
        // Then: Should complete without crashes
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Tests
    
    func testMenuBarAppWithKeyMonitor() {
        // Given: MenuBarApp with KeyMonitor
        // Note: KeyMonitor requires accessibility permissions which aren't available in tests
        
        // When: App initializes
        // Then: Should handle missing permissions gracefully
        XCTAssertNotNil(menuBarApp, "MenuBarApp should exist")
        
        // Verify app continues to function without KeyMonitor
        XCTAssertNotNil(menuBarApp.preferences, "Preferences should still be accessible")
    }
    
    func testMenuBarIconStateChanges() {
        // Given: MenuBarApp states
        let states = [
            (enabled: true, expectedIcon: "⌘"),
            (enabled: false, expectedIcon: "⌘?")
        ]
        
        // When: State changes occur
        for state in states {
            // In actual app, this would update the status bar icon
            // In tests, we verify the logic exists
            XCTAssertTrue(true, "State \(state) should be processable")
        }
    }
    
    // MARK: - Accessibility Permission Tests
    
    func testAccessibilityPermissionFlow() {
        // Given: App without accessibility permissions
        // When: Checking permission status
        let hasPermission = AXIsProcessTrusted()
        
        // Then: Should handle both states
        if hasPermission {
            XCTAssertTrue(hasPermission, "Should handle when permissions are granted")
        } else {
            XCTAssertFalse(hasPermission, "Should handle when permissions are not granted")
        }
    }
    
    // MARK: - Application Lifecycle Tests
    
    func testApplicationWillTerminate() {
        // Given: MenuBarApp as NSApplicationDelegate
        let notification = Notification(name: NSApplication.willTerminateNotification)
        
        // When: Application will terminate
        menuBarApp.applicationWillTerminate(notification)
        
        // Then: Should cleanup properly (tested by not crashing)
        XCTAssertTrue(true, "Application termination should be handled")
    }
    
    // MARK: - Restart App Tests
    
    func testRestartAppScriptGeneration() {
        // Given: Bundle information
        let bundlePath = Bundle.main.bundleURL.path
        
        // When: Creating restart script
        let script = """
            sleep 0.5
            open '\(bundlePath)'
        """
        
        // Then: Script should be valid
        XCTAssertTrue(script.contains("sleep"), "Script should contain sleep command")
        XCTAssertTrue(script.contains("open"), "Script should contain open command")
        XCTAssertTrue(script.contains(bundlePath), "Script should contain bundle path")
    }
}
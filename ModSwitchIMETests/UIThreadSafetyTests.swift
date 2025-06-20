import XCTest
import SwiftUI
@testable import ModSwitchIME

final class UIThreadSafetyTests: XCTestCase {
    
    // MARK: - Main Thread Enforcement Tests
    
    func testTISAPIMainThreadEnforcement() {
        // Test that TIS API calls are properly handled on main thread
        let expectation = self.expectation(description: "TIS calls should complete")
        
        // Call from background thread - should automatically dispatch to main thread
        DispatchQueue.global(qos: .background).async {
            let sources = Preferences.getAllInputSources(includeDisabled: false)
            XCTAssertFalse(sources.isEmpty, "Should get at least some input sources")
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testImeControllerThreadSafety() {
        // Test ImeController handles thread safety properly
        let expectation = self.expectation(description: "IME operations should complete")
        let controller = ImeController()
        
        DispatchQueue.global(qos: .background).async {
            // This should be handled safely
            let currentSource = controller.getCurrentInputSource()
            XCTAssertFalse(currentSource.isEmpty)
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentPreferencesAccess() {
        // Test concurrent access to preferences
        let preferences = Preferences.createForTesting()
        let group = DispatchGroup()
        let iterations = 50
        
        // Multiple threads reading/writing preferences
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                // Randomly read or write
                if i % 2 == 0 {
                    preferences.idleOffEnabled = Bool.random()
                } else {
                    _ = preferences.idleOffEnabled
                }
                group.leave()
            }
        }
        
        let result = group.wait(timeout: .now() + 5)
        XCTAssertEqual(result, .success, "Concurrent access should complete without deadlock")
    }
    
    func testAccessibilityManagerCacheSafety() {
        // Test AccessibilityManager cache is thread-safe
        let manager = AccessibilityManager.shared
        let group = DispatchGroup()
        
        // Multiple threads accessing permission status
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                _ = manager.hasPermission
                group.leave()
            }
        }
        
        // Refresh cache from another thread
        group.enter()
        DispatchQueue.global().async {
            manager.refreshPermissionStatus()
            group.leave()
        }
        
        let result = group.wait(timeout: .now() + 3)
        XCTAssertEqual(result, .success)
    }
    
    // MARK: - UI Update Safety Tests
    
    func testMenuBarUIUpdateSafety() {
        // Test that UI updates are dispatched to main thread
        let expectation = self.expectation(description: "UI updates should complete")
        
        // Create menu bar app on main thread
        DispatchQueue.main.async {
            let menuBarApp = MenuBarApp()
            
            // Try to trigger UI updates from background thread
            DispatchQueue.global().async {
                // Access properties that might trigger UI updates
                _ = menuBarApp.preferences.launchAtLogin
                
                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Real Crash Scenario Tests
    
    func testRapidInputSourceSwitching() {
        // Simulate the crash scenario: rapid preference UI interaction
        let preferences = Preferences.createForTesting()
        let controller = ImeController()
        let group = DispatchGroup()
        
        // Thread 1: Simulate UI rapidly accessing input sources
        group.enter()
        DispatchQueue.global().async {
            for _ in 0..<20 {
                _ = Preferences.getAllInputSources(includeDisabled: Bool.random())
                Thread.sleep(forTimeInterval: 0.05)
            }
            group.leave()
        }
        
        // Thread 2: Simulate IME switching
        group.enter()
        DispatchQueue.global().async {
            for _ in 0..<10 {
                _ = controller.getCurrentInputSource()
                Thread.sleep(forTimeInterval: 0.1)
            }
            group.leave()
        }
        
        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success, "Should handle rapid switching without crash")
    }
    
    func testPreferencesViewRapidUpdates() {
        // Test rapid UI updates don't cause crashes
        let preferences = Preferences.createForTesting()
        
        // Set up some initial IME mappings
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setIME("com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", for: .rightCommand)
        
        // Simulate rapid preference changes (like user clicking quickly)
        for _ in 0..<30 {
            preferences.idleOffEnabled.toggle()
            preferences.cmdKeyTimeoutEnabled.toggle()
            
            // This would trigger UI updates in a real SwiftUI context
            _ = preferences.objectWillChange
        }
        
        // If we get here without crash, test passes
        XCTAssertTrue(true)
    }
    
    // MARK: - Timer Safety Tests
    
    func testImeControllerTimerSafety() {
        // Test that timer-based cache refresh is thread-safe
        let controller = ImeController()
        let expectation = self.expectation(description: "Timer should fire safely")
        
        // Wait for at least one timer fire (cache refresh is every 30 seconds)
        // For testing, we'll just verify initialization doesn't crash
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Access controller after timer might have fired
            _ = controller.getCurrentInputSource()
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testAutoreleasePoolUsage() {
        // Test that autoreleasepool properly manages memory
        let iterations = 100
        
        for _ in 0..<iterations {
            autoreleasepool {
                _ = Preferences.getAllInputSources(includeDisabled: true)
            }
        }
        
        // If we don't crash from memory issues, test passes
        XCTAssertTrue(true)
    }
}

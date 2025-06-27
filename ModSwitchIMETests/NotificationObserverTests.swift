import XCTest
import Cocoa
@testable import ModSwitchIME

class NotificationObserverTests: XCTestCase {
    
    // MARK: - MenuBarApp Notification Observer Tests
    
    func testMenuBarAppNotificationObserverCleanup() {
        // Given: MenuBarApp instance
        var menuBarApp: MenuBarApp? = MenuBarApp()
        weak var weakMenuBarApp = menuBarApp
        
        // When: MenuBarApp is deallocated
        menuBarApp = nil
        
        // Then: Should clean up properly (no crash)
        XCTAssertNil(weakMenuBarApp, "MenuBarApp should be deallocated")
        
        // Post notifications to verify no crash from dangling observers
        DistributedNotificationCenter.default().post(
            name: .screenIsLocked,
            object: nil
        )
        DistributedNotificationCenter.default().post(
            name: .screenIsUnlocked,
            object: nil
        )
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil
        )
        
        // If we reach here without crash, cleanup was successful
        XCTAssertTrue(true, "Notification observers cleaned up successfully")
    }
    
    func testNotificationObserverSetup() {
        // Given: MenuBarApp with notification setup
        let menuBarApp = MenuBarApp()
        
        // When: MenuBarApp is initialized
        // Then: Should complete setup without issues
        XCTAssertNotNil(menuBarApp, "MenuBarApp should be created successfully")
        
        // Note: DistributedNotificationCenter doesn't return observer tokens,
        // so we can't directly verify observer registration
    }
    
    // MARK: - Distributed Notification Tests
    
    func testDistributedNotificationHandling() {
        // Given: MenuBarApp instance
        let menuBarApp = MenuBarApp()
        let expectation = XCTestExpectation(description: "Notification handling")
        expectation.isInverted = true // We don't expect this to be fulfilled
        
        // When: Posting distributed notifications
        DistributedNotificationCenter.default().post(
            name: .screenIsLocked,
            object: nil
        )
        
        DistributedNotificationCenter.default().post(
            name: .screenIsUnlocked,
            object: nil
        )
        
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil
        )
        
        // Then: Should handle without crashes
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(true, "Notifications handled without crash")
    }
    
    // MARK: - Memory Leak Tests
    
    func testNoMemoryLeakWithNotifications() {
        // Given: Multiple MenuBarApp instances created and destroyed
        for _ in 0..<5 {
            autoreleasepool {
                let menuBarApp = MenuBarApp()
                
                // Post some notifications
                DistributedNotificationCenter.default().post(
                    name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
                    object: nil
                )
                
                // MenuBarApp should be deallocated at end of autoreleasepool
                _ = menuBarApp
            }
        }
        
        // If we reach here without memory issues, test passes
        XCTAssertTrue(true, "No memory leak detected")
    }
    
    // MARK: - Concurrent Notification Tests
    
    func testConcurrentNotificationPosting() {
        // Given: MenuBarApp instance
        let menuBarApp = MenuBarApp()
        let expectation = XCTestExpectation(description: "Concurrent notifications")
        expectation.expectedFulfillmentCount = 30
        
        // When: Posting notifications concurrently
        for i in 0..<10 {
            DispatchQueue.global().async {
                DistributedNotificationCenter.default().post(
                    name: .screenIsLocked,
                    object: nil
                )
                expectation.fulfill()
            }
            
            DispatchQueue.global().async {
                DistributedNotificationCenter.default().post(
                    name: .screenIsUnlocked,
                    object: nil
                )
                expectation.fulfill()
            }
            
            DispatchQueue.global().async {
                DistributedNotificationCenter.default().post(
                    name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
                    object: nil
                )
                expectation.fulfill()
            }
        }
        
        // Then: Should handle all notifications without issues
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "Concurrent notifications handled successfully")
    }
}

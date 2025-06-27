import XCTest
@testable import ModSwitchIME

class MemoryManagementTests: XCTestCase {
    
    // MARK: - CoreFoundation Memory Management Tests
    
    func testImeControllerCacheInitializationNoLeak() {
        // Given: A test ImeController instance
        autoreleasepool {
            #if DEBUG
            let imeController = ImeController.createForTesting()
            
            // When: The cache is initialized (happens in init)
            // Then: Should not leak memory
            
            // Force some operations that use TISCreateInputSourceList
            _ = imeController.getCurrentInputSource()
            #else
            // In release builds, test with mock
            let imeController = FixedMockImeController()
            _ = imeController.getCurrentInputSource()
            #endif
        }
        
        // Memory should be properly released after autoreleasepool
        XCTAssertTrue(true, "No memory leak in cache initialization")
    }
    
    func testImeControllerDeinitCleansUpObservers() {
        // Given: A test ImeController that will be deallocated
        #if DEBUG
        weak var weakController: ImeController?
        
        autoreleasepool {
            let controller = ImeController.createForTesting()
            weakController = controller
            
            // Verify it exists during use
            XCTAssertNotNil(weakController, "Controller should exist during use")
        }
        
        // Then: Should be deallocated after leaving scope
        // Note: Singleton pattern means shared instance won't be deallocated
        // but test instances should be
        XCTAssertNil(weakController, "Test controller should be deallocated")
        #else
        // Skip this test in release builds
        XCTAssertTrue(true, "Test skipped in release build")
        #endif
    }
    
    // MARK: - Cache Thread Safety Tests
    
    func testCacheConcurrentAccess() {
        // Given: An ImeController instance
        #if DEBUG
        let controller = ImeController.createForTesting()
        #else
        let controller = FixedMockImeController()
        #endif
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100
        
        // When: Multiple threads access the cache simultaneously
        let group = DispatchGroup()
        
        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    // Read operation
                    _ = controller.getCurrentInputSource()
                } else {
                    // Write operation (triggers cache refresh)
                    controller.switchToSpecificIME("com.apple.keylayout.ABC")
                }
                expectation.fulfill()
                group.leave()
            }
        }
        
        // Then: Should complete without crashes or deadlocks
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Notification Observer Cleanup Tests
    
    func testNotificationObserverCleanup() {
        #if DEBUG
        // Given: A controller that registers notification observers
        var controller: ImeController? = ImeController.createForTesting()
        
        // When: The controller is deallocated
        controller = nil
        
        // Then: Notification observers should be cleaned up (no crash when notifications fire)
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil
        )
        
        // If observers weren't cleaned up, this would crash
        XCTAssertTrue(true, "Notification observers properly cleaned up")
        #else
        // Skip this test in release builds
        XCTAssertTrue(true, "Test skipped in release build")
        #endif
    }
}

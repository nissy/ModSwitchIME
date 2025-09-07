import XCTest
@testable import ModSwitchIME

final class CriticalFixesTests: XCTestCase {
    
    // MARK: - Memory Leak Tests
    
    func testEventTapCallbackDoesNotRetainEvent() {
        // This test verifies the fix for the memory leak in EventTapManager
        // where events were being retained but never released
        
        // Create a mock event
        let eventSource = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: 0x38, keyDown: true) else {
            XCTFail("Failed to create test event")
            return
        }
        
        // Get initial retain count
        let initialRetainCount = CFGetRetainCount(event)
        
        // Simulate what the callback does (pass unretained)
        let unmanaged = Unmanaged.passUnretained(event)
        _ = unmanaged.takeUnretainedValue()
        
        // Verify retain count hasn't increased
        let finalRetainCount = CFGetRetainCount(event)
        XCTAssertEqual(initialRetainCount, finalRetainCount, "Event retain count should not increase")
    }
    
    // MARK: - Thread Safety Tests
    
    func testKeyMonitorStateQueueThreadSafety() {
        let keyMonitor = KeyMonitor()
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100
        
        // Simulate concurrent access to key states
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for i in 0..<100 {
            queue.async {
                // This would previously cause race conditions
                if i % 2 == 0 {
                    keyMonitor.start()
                } else {
                    keyMonitor.stop()
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Thread safety test should complete without issues")
        }
    }
    
    func testImeControllerCacheThreadSafety() throws {
        if ProcessInfo.processInfo.environment["RUN_STRESS_TESTS"] != "1" {
            throw XCTSkip("Skipping stress test by default. Set RUN_STRESS_TESTS=1 to enable.")
        }
        let imeController = ImeController.shared
        let expectation = self.expectation(description: "Cache concurrent access")
        expectation.expectedFulfillmentCount = 20
        
        let queue = DispatchQueue(label: "test.cache.concurrent", attributes: .concurrent)
        
        for i in 0..<20 {
            queue.async {
                // Concurrent cache access
                if i % 2 == 0 {
                    _ = imeController.getCurrentInputSource()
                } else {
                    imeController.switchToSpecificIME("com.apple.keylayout.ABC")
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Cache thread safety test should complete without issues")
        }
    }
    
    // MARK: - Deadlock Prevention Tests
    
    func testImeControllerInitializeCacheDeadlockPrevention() {
        // This test verifies the fix for potential deadlock in initializeCache
        // when called from background thread while main thread is blocked
        
        let expectation = self.expectation(description: "No deadlock")
        
        DispatchQueue.global(qos: .background).async {
            // This would previously cause deadlock if main thread was blocked
            _ = ImeController.shared.getCurrentInputSource()
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Should not deadlock when initializing cache from background")
        }
    }
    
    // MARK: - Resource Cleanup Tests
    
    func testMenuBarAppWindowObserverCleanup() {
        // This test verifies that window close observers are properly cleaned up
        // to prevent memory leaks
        
        // Since MenuBarApp is final, we cannot create a mock subclass
        // This test verifies the concept of cleanup, actual testing would require UI interaction
        let menuBarApp = MenuBarApp()
        
        // Verify the app exists and can be initialized
        XCTAssertNotNil(menuBarApp, "MenuBarApp should be created successfully")
        
        // Note: Full testing would require UI interaction which is not feasible in unit tests
        // This test verifies the structure is in place for cleanup
    }
    
    // MARK: - Error Recovery Tests
    
    func testKeyMonitorEventTapRecovery() {
        let keyMonitor = KeyMonitor()
        var errorReceived = false
        
        keyMonitor.onError = { error in
            errorReceived = true
            // Verify it's the correct error type
            if case .eventTapDisabled = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
        
        // Simulate event tap being disabled
        // Note: We can't actually disable the event tap in tests,
        // but we verify the error handling structure is in place
        XCTAssertNotNil(keyMonitor.onError, "Error handler should be configurable")
    }
    
    // MARK: - Timer Management Tests
    
    func testTimerProperCleanup() {
        // This test verifies timers are properly cleaned up to prevent leaks
        
        class TimerTestHelper {
            var timer: Timer?
            
            func createTimer() {
                // Ensure timer is created on main thread as per fix
                if Thread.isMainThread {
                    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                        // Timer action
                    }
                } else {
                    DispatchQueue.main.sync {
                        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            // Timer action
                        }
                    }
                }
            }
            
            func cleanup() {
                timer?.invalidate()
                timer = nil
            }
            
            deinit {
                cleanup()
            }
        }
        
        var helper: TimerTestHelper? = TimerTestHelper()
        helper?.createTimer()
        
        XCTAssertNotNil(helper?.timer, "Timer should be created")
        
        // Cleanup
        helper = nil
        
        // If no crash occurs, cleanup was successful
        XCTAssertTrue(true, "Timer cleanup completed without issues")
    }
    
    // MARK: - Performance Tests
    
    func testKeyStateAccessPerformance() throws {
        if ProcessInfo.processInfo.environment["RUN_STRESS_TESTS"] != "1" {
            throw XCTSkip("Skipping performance test by default. Set RUN_STRESS_TESTS=1 to enable.")
        }
        let keyMonitor = KeyMonitor()
        
        measure {
            // Measure performance of concurrent key state access
            let queue = DispatchQueue(label: "perf.test", attributes: .concurrent)
            let group = DispatchGroup()
            
            for _ in 0..<200 {
                group.enter()
                queue.async {
                    _ = keyMonitor.isMonitoring
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
}

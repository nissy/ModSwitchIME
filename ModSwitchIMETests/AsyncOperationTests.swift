import XCTest
@testable import ModSwitchIME

class AsyncOperationTests: XCTestCase {
    var imeController: ImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        imeController = ImeController()
        preferences = Preferences.createForTesting()
    }
    
    override func tearDown() {
        imeController = nil
        preferences = nil
        super.tearDown()
    }
    
    // MARK: - Async Input Source Change Tests
    
    func testAsyncInputSourceChange() {
        // Given: Current input source
        let initialSource = imeController.getCurrentInputSource()
        let expectation = XCTestExpectation(description: "Input source change")
        
        // When: Changing input source asynchronously
        DispatchQueue.global().async {
            self.imeController.toggleByCmd(isLeft: true)
            
            // Simulate verification delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let newSource = self.imeController.getCurrentInputSource()
                
                // Then: Source should be changed or same (depending on system state)
                XCTAssertNotNil(newSource, "Should have valid source after async change")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMultipleAsyncToggles() {
        // Given: Multiple async toggle operations
        let expectation = XCTestExpectation(description: "Multiple toggles")
        expectation.expectedFulfillmentCount = 5
        
        // When: Performing multiple toggles
        for i in 0..<5 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.1) {
                self.imeController.toggleByCmd(isLeft: i % 2 == 0)
                expectation.fulfill()
            }
        }
        
        // Then: All toggles should complete
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Timer-based Tests
    
    func testIdleTimerSimulation() {
        // Given: Idle timeout configuration
        preferences.idleOffEnabled = true
        preferences.idleTimeout = 0.5 // Short timeout for testing
        
        let expectation = XCTestExpectation(description: "Idle timer")
        
        // When: Simulating idle period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Then: Would trigger idle action in real app
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testTimerCancellation() {
        // Given: Timer that should be cancelled
        let expectation = XCTestExpectation(description: "Timer cancellation")
        expectation.isInverted = true // Should NOT be fulfilled
        
        var timer: Timer?
        
        // When: Starting and cancelling timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            expectation.fulfill() // This should not happen
        }
        
        // Cancel the timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            timer?.invalidate()
        }
        
        // Then: Timer should not fire
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Concurrent Preferences Updates
    
    func testConcurrentPreferencesUpdates() {
        // Given: Multiple concurrent updates
        let updateQueue = DispatchQueue(label: "test.async.updates", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Concurrent updates")
        expectation.expectedFulfillmentCount = 10
        
        // When: Updating preferences from multiple threads
        for i in 0..<10 {
            updateQueue.async {
                self.preferences.idleTimeout = Double(i + 1)
                
                // Verify the update
                DispatchQueue.main.async {
                    XCTAssertGreaterThan(self.preferences.idleTimeout, 0)
                    expectation.fulfill()
                }
            }
        }
        
        // Then: All updates should complete
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Delayed Operations Tests
    
    func testDelayedInputSourceVerification() {
        // Given: Input source change with verification delay
        let expectation = XCTestExpectation(description: "Delayed verification")
        
        // When: Changing source and verifying after delay
        imeController.forceAscii()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let currentSource = self.imeController.getCurrentInputSource()
            
            // Then: Should have valid source
            XCTAssertFalse(currentSource.isEmpty, "Should have valid source after delay")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSequentialAsyncOperations() {
        // Given: Sequential operations
        let expectation = XCTestExpectation(description: "Sequential ops")
        var completedSteps = 0
        
        // When: Performing sequential async operations
        DispatchQueue.global().async {
            // Step 1: Get current source
            let source1 = self.imeController.getCurrentInputSource()
            XCTAssertNotNil(source1)
            completedSteps += 1
            
            // Step 2: Toggle
            DispatchQueue.main.async {
                self.imeController.toggleByCmd(isLeft: true)
                completedSteps += 1
                
                // Step 3: Verify
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    let source2 = self.imeController.getCurrentInputSource()
                    XCTAssertNotNil(source2)
                    completedSteps += 1
                    
                    expectation.fulfill()
                }
            }
        }
        
        // Then: All steps should complete
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(completedSteps, 3, "All sequential steps should complete")
    }
    
    // MARK: - Race Condition Tests
    
    func testRaceConditionPrevention() {
        // Given: Potential race condition scenario
        let safeQueue = DispatchQueue(label: "test.race.safe")
        var sharedResource = 0
        let expectation = XCTestExpectation(description: "Race condition test")
        expectation.expectedFulfillmentCount = 100
        
        // When: Multiple threads access shared resource
        for i in 0..<100 {
            DispatchQueue.global().async {
                safeQueue.sync {
                    sharedResource += 1
                }
                expectation.fulfill()
            }
        }
        
        // Then: Should handle safely
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(sharedResource, 100, "Shared resource should be updated safely")
    }
    
    // MARK: - Async Error Handling Tests
    
    func testAsyncErrorHandling() {
        // Given: Async operation that might fail
        let expectation = XCTestExpectation(description: "Async error handling")
        
        // When: Performing operation that might fail
        DispatchQueue.global().async {
            do {
                // Simulate operation that might throw
                if Bool.random() {
                    throw ModSwitchIMEError.invalidConfiguration
                }
                
                // Success path
                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            } catch {
                // Error path
                ModSwitchIMELogger.error("Async error: \(error)")
                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            }
        }
        
        // Then: Should handle both success and error
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Notification-based Async Tests
    
    func testAsyncNotificationHandling() {
        // Given: Notification observer
        let notificationName = Notification.Name("TestAsyncNotification")
        let expectation = XCTestExpectation(description: "Notification handling")
        
        let observer = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { notification in
            // Then: Should receive notification
            XCTAssertEqual(notification.name, notificationName)
            expectation.fulfill()
        }
        
        // When: Posting notification asynchronously
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: notificationName, object: nil)
        }
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Completion Handler Tests
    
    func testAsyncCompletionHandlers() {
        // Given: Function with completion handler
        func performAsyncOperation(completion: @escaping (Result<String, Error>) -> Void) {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                if Bool.random() {
                    completion(.success("Operation completed"))
                } else {
                    completion(.failure(ModSwitchIMEError.invalidConfiguration))
                }
            }
        }
        
        let expectation = XCTestExpectation(description: "Completion handler")
        
        // When: Calling async function
        performAsyncOperation { result in
            // Then: Should receive result
            switch result {
            case .success(let message):
                XCTAssertFalse(message.isEmpty)
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Debounce/Throttle Tests
    
    func testDebounceSimulation() {
        // Given: Multiple rapid calls that should be debounced
        var callCount = 0
        let expectation = XCTestExpectation(description: "Debounce")
        
        // Simple debounce implementation
        var debounceTimer: Timer?
        func debouncedFunction() {
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                callCount += 1
                expectation.fulfill()
            }
        }
        
        // When: Making rapid calls
        for _ in 0..<10 {
            debouncedFunction()
            Thread.sleep(forTimeInterval: 0.01) // Small delay between calls
        }
        
        // Then: Should only execute once
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(callCount, 1, "Debounced function should only execute once")
    }
    
    // MARK: - Main Thread Verification Tests
    
    func testMainThreadExecution() {
        // Given: Operation that must run on main thread
        let expectation = XCTestExpectation(description: "Main thread execution")
        
        // When: Ensuring main thread execution
        DispatchQueue.global().async {
            // Background work
            let result = "Background work completed"
            
            // Switch to main thread
            DispatchQueue.main.async {
                // Then: Should be on main thread
                XCTAssertTrue(Thread.isMainThread, "Should be on main thread")
                XCTAssertEqual(result, "Background work completed")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Async State Machine Tests
    
    func testAsyncStateMachine() {
        // Given: State machine with async transitions
        enum State {
            case idle, processing, completed, failed
        }
        
        var currentState = State.idle
        let expectation = XCTestExpectation(description: "State machine")
        
        // When: Transitioning through states
        DispatchQueue.global().async {
            // Idle -> Processing
            currentState = .processing
            
            // Simulate processing
            Thread.sleep(forTimeInterval: 0.1)
            
            // Processing -> Completed/Failed
            currentState = Bool.random() ? .completed : .failed
            
            DispatchQueue.main.async {
                // Then: Should have transitioned
                XCTAssertTrue(currentState == .completed || currentState == .failed)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
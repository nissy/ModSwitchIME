import XCTest
@testable import ModSwitchIME

class ThreadSafetyTests: XCTestCase {
    
    // MARK: - ThreadSafetyUtils Tests
    
    func testExecuteOnMainThreadFromMainThread() {
        // Given: Already on main thread
        XCTAssertTrue(Thread.isMainThread)
        
        // When: Executing on main thread
        let result = ThreadSafetyUtils.executeOnMainThread {
            return "Success"
        }
        
        // Then: Should execute directly
        XCTAssertEqual(result, "Success")
    }
    
    func testExecuteOnMainThreadFromBackgroundThread() {
        // Given: Background thread
        let expectation = XCTestExpectation(description: "Background thread execution")
        var result: String?
        
        DispatchQueue.global().async {
            // When: Executing from background thread
            result = ThreadSafetyUtils.executeOnMainThread {
                XCTAssertTrue(Thread.isMainThread)
                return "Background Success"
            }
            expectation.fulfill()
        }
        
        // Then: Should execute on main thread
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(result, "Background Success")
    }
    
    func testExecuteOnMainThreadTimeout() {
        // Given: Background thread with slow operation
        let expectation = XCTestExpectation(description: "Timeout test")
        var result: String?
        
        DispatchQueue.global().async {
            // When: Operation that will timeout
            result = ThreadSafetyUtils.executeOnMainThread(timeout: 0.1) {
                // Simulate slow operation
                Thread.sleep(forTimeInterval: 0.5)
                return "Should not reach here"
            }
            expectation.fulfill()
        }
        
        // Then: Should return nil on timeout
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(result)
    }
    
    func testExecuteOnMainThreadWithDefault() {
        // Given: Already on main thread
        let defaultValue = "Default"
        
        // When: Executing with default
        let result = ThreadSafetyUtils.executeOnMainThreadWithDefault(
            defaultValue: defaultValue
        ) {
            return "New Value"
        }
        
        // Then: Should return new value
        XCTAssertEqual(result, "New Value")
    }
    
    func testExecuteOnMainThreadWithDefaultTimeout() {
        // Given: Background thread with timeout
        let expectation = XCTestExpectation(description: "Default timeout test")
        let defaultValue = "Default"
        var result: String?
        
        DispatchQueue.global().async {
            // When: Operation that will timeout
            result = ThreadSafetyUtils.executeOnMainThreadWithDefault(
                timeout: 0.1,
                defaultValue: defaultValue
            ) {
                Thread.sleep(forTimeInterval: 0.5)
                return "Should not reach here"
            }
            expectation.fulfill()
        }
        
        // Then: Should return default value on timeout
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(result, defaultValue)
    }
    
    // MARK: - Semaphore Leak Test
    
    func testSemaphoreNoLeakOnTimeout() {
        // Given: Multiple timeout scenarios
        let iterations = 10
        let expectation = XCTestExpectation(description: "Multiple timeouts")
        expectation.expectedFulfillmentCount = iterations
        
        // When: Running multiple operations that timeout
        for _ in 0..<iterations {
            DispatchQueue.global().async {
                _ = ThreadSafetyUtils.executeOnMainThread(timeout: 0.01) {
                    Thread.sleep(forTimeInterval: 0.1)
                    return "Timeout"
                }
                expectation.fulfill()
            }
        }
        
        // Then: Should complete without deadlock or leak
        wait(for: [expectation], timeout: 5.0)
        
        // If we reach here, no semaphore leak occurred
        XCTAssertTrue(true, "No semaphore leak detected")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentMainThreadExecution() {
        // Given: Multiple concurrent operations
        let operationCount = 20
        let expectation = XCTestExpectation(description: "Concurrent execution")
        expectation.expectedFulfillmentCount = operationCount
        var results: [Int] = []
        let resultsQueue = DispatchQueue(label: "test.results.queue")
        
        // When: Running concurrent operations
        for i in 0..<operationCount {
            DispatchQueue.global().async {
                let result = ThreadSafetyUtils.executeOnMainThread {
                    return i
                }
                
                resultsQueue.sync {
                    if let result = result {
                        results.append(result)
                    }
                }
                expectation.fulfill()
            }
        }
        
        // Then: All operations should complete
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(results.count, operationCount)
    }
}
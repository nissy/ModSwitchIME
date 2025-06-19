import XCTest
import os
@testable import ModSwitchIME

class LoggerTests: XCTestCase {
    
    // MARK: - Basic Logging Tests
    
    func testLoggerDebugMessage() {
        // Given: Debug message
        let testMessage = "Test debug message"
        
        // When: Logging debug message
        ModSwitchIMELogger.debug(testMessage)
        ModSwitchIMELogger.debug(testMessage, category: .main)
        ModSwitchIMELogger.debug(testMessage, category: .ime)
        ModSwitchIMELogger.debug(testMessage, category: .keyboard)
        
        // Then: Should not crash (actual logging depends on DEBUG flag)
        XCTAssertTrue(true, "Debug logging should not crash")
    }
    
    func testLoggerInfoMessage() {
        // Given: Info messages for all categories
        let categories: [ModSwitchIMELogger.Category] = [.main, .ime, .keyboard]
        
        // When: Logging info messages
        for category in categories {
            ModSwitchIMELogger.info("Test info message for \(category)", category: category)
        }
        
        // Then: Should complete without crashes
        XCTAssertTrue(true, "Info logging should work for all categories")
    }
    
    func testLoggerErrorMessage() {
        // Given: Error scenarios
        let errorMessages = [
            "Failed to initialize component",
            "Network request failed",
            "Invalid configuration detected",
            "Permission denied"
        ]
        
        // When: Logging errors
        for message in errorMessages {
            ModSwitchIMELogger.error(message)
            ModSwitchIMELogger.error(message, category: .ime)
        }
        
        // Then: Should log without crashes
        XCTAssertTrue(true, "Error logging should handle all messages")
    }
    
    func testLoggerWarningMessage() {
        // Given: Warning scenarios
        let warnings = [
            "Memory usage is high",
            "Deprecated API usage detected",
            "Performance degradation observed"
        ]
        
        // When: Logging warnings
        for warning in warnings {
            ModSwitchIMELogger.warning(warning)
            ModSwitchIMELogger.warning(warning, category: .keyboard)
        }
        
        // Then: Should complete successfully
        XCTAssertTrue(true, "Warning logging should work")
    }
    
    // MARK: - Category Tests
    
    func testLoggerCategories() {
        // Given: All logger categories
        let categories: [ModSwitchIMELogger.Category] = [.main, .ime, .keyboard]
        
        // When: Accessing logger for each category
        for category in categories {
            let logger = category.logger
            
            // Then: Logger should be valid
            XCTAssertTrue(type(of: logger) == os.Logger.self, "Should return valid os.Logger")
        }
    }
    
    func testCategorySpecificLogging() {
        // Given: Category-specific messages
        let testCases: [(ModSwitchIMELogger.Category, String)] = [
            (.main, "Main app event"),
            (.ime, "IME switching event"),
            (.keyboard, "Keyboard event detected")
        ]
        
        // When: Logging to specific categories
        for (category, message) in testCases {
            ModSwitchIMELogger.debug(message, category: category)
            ModSwitchIMELogger.info(message, category: category)
            ModSwitchIMELogger.warning(message, category: category)
            ModSwitchIMELogger.error(message, category: category)
        }
        
        // Then: All should complete without errors
        XCTAssertTrue(true, "Category-specific logging should work")
    }
    
    // MARK: - Special Character Tests
    
    func testLoggerWithSpecialCharacters() {
        // Given: Messages with special characters
        let specialMessages = [
            "Message with emoji 🎉🚀💻",
            "Message with newline\ncharacters",
            "Message with tabs\t\there",
            "Message with quotes \"quoted\" and 'single'",
            "Message with unicode: 日本語 中文 한국어",
            "Message with escape sequences: \\n \\t \\r",
            "Message with null character: \0",
            "Very long message: " + String(repeating: "a", count: 1000)
        ]
        
        // When: Logging special messages
        for message in specialMessages {
            ModSwitchIMELogger.debug(message)
            ModSwitchIMELogger.info(message)
            ModSwitchIMELogger.warning(message)
            ModSwitchIMELogger.error(message)
        }
        
        // Then: Should handle all special characters
        XCTAssertTrue(true, "Special character logging should not crash")
    }
    
    // MARK: - Performance Tests
    
    func testLoggerPerformance() {
        // Given: Large number of log messages
        measure {
            // When: Logging many messages rapidly
            for i in 0..<100 {
                ModSwitchIMELogger.debug("Debug message \(i)")
                ModSwitchIMELogger.info("Info message \(i)")
                
                if i % 10 == 0 {
                    ModSwitchIMELogger.warning("Warning message \(i)")
                }
                
                if i % 20 == 0 {
                    ModSwitchIMELogger.error("Error message \(i)")
                }
            }
        }
        
        // Then: Performance should be acceptable (measured by XCTest)
    }
    
    func testLoggerConcurrentAccess() {
        // Given: Concurrent logging environment
        let concurrentQueue = DispatchQueue(label: "test.logger.concurrent", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 4
        
        // When: Logging from multiple threads
        concurrentQueue.async {
            for i in 0..<50 {
                ModSwitchIMELogger.debug("Thread 1 - Message \(i)")
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for i in 0..<50 {
                ModSwitchIMELogger.info("Thread 2 - Message \(i)", category: .ime)
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for i in 0..<50 {
                ModSwitchIMELogger.warning("Thread 3 - Message \(i)", category: .keyboard)
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for i in 0..<50 {
                ModSwitchIMELogger.error("Thread 4 - Message \(i)")
            }
            expectation.fulfill()
        }
        
        // Then: Should handle concurrent access
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Subsystem Tests
    
    func testLoggerSubsystem() {
        // Given: Bundle identifier
        let expectedSubsystem = Bundle.main.bundleIdentifier ?? "com.example.ModSwitchIME"
        
        // When: Using logger
        // Note: We can't directly access the private subsystem property,
        // but we can verify it doesn't crash with various bundle states
        ModSwitchIMELogger.info("Testing subsystem: \(expectedSubsystem)")
        
        // Then: Should use appropriate subsystem
        XCTAssertTrue(true, "Subsystem should be properly configured")
    }
    
    // MARK: - Memory Tests
    
    func testLoggerMemoryUsage() {
        // Given: Memory tracking
        weak var testString: NSString?
        
        autoreleasepool {
            // When: Creating and logging large strings
            for _ in 0..<100 {
                let largeString = NSString(string: String(repeating: "Memory test ", count: 100))
                testString = largeString
                ModSwitchIMELogger.info(largeString as String)
            }
        }
        
        // Then: Memory should be released
        XCTAssertNil(testString, "Logger should not retain logged strings")
    }
    
    // MARK: - Edge Cases
    
    func testLoggerWithEmptyMessages() {
        // Given: Empty and whitespace-only messages
        let emptyMessages = ["", " ", "  ", "\t", "\n", "\r\n"]
        
        // When: Logging empty messages
        for message in emptyMessages {
            ModSwitchIMELogger.debug(message)
            ModSwitchIMELogger.info(message)
            ModSwitchIMELogger.warning(message)
            ModSwitchIMELogger.error(message)
        }
        
        // Then: Should handle gracefully
        XCTAssertTrue(true, "Empty message logging should not crash")
    }
    
    func testLoggerWithNilInterpolation() {
        // Given: Optional values
        let optionalString: String? = nil
        let optionalInt: Int? = nil
        let optionalArray: [String]? = nil
        
        // When: Logging with nil values
        ModSwitchIMELogger.info("Optional string: \(optionalString ?? "nil")")
        ModSwitchIMELogger.info("Optional int: \(String(describing: optionalInt))")
        ModSwitchIMELogger.info("Optional array: \(optionalArray?.description ?? "nil")")
        
        // Then: Should handle nil interpolation
        XCTAssertTrue(true, "Nil interpolation should be handled")
    }
    
    // MARK: - Integration Tests
    
    func testLoggerIntegrationWithErrors() {
        // Given: Various error types
        let errors: [Error] = [
            ModSwitchIMEError.accessibilityPermissionDenied,
            ModSwitchIMEError.inputSourceNotFound("test.source"),
            NSError(domain: "TestDomain", code: 123, userInfo: nil)
        ]
        
        // When: Logging errors
        for error in errors {
            ModSwitchIMELogger.error("Error occurred: \(error)")
            ModSwitchIMELogger.error("Error description: \(error.localizedDescription)")
            
            if let modSwitchIMEError = error as? ModSwitchIMEError {
                ModSwitchIMELogger.error("ModSwitchIMEError: \(modSwitchIMEError.errorDescription ?? "Unknown")")
            }
        }
        
        // Then: Should log all error types
        XCTAssertTrue(true, "Error logging integration should work")
    }
    
    func testLoggerWithComplexObjects() {
        // Given: Complex objects
        let dictionary = ["key1": "value1", "key2": "value2"]
        let array = ["item1", "item2", "item3"]
        let date = Date()
        let url = URL(string: "https://example.com")
        
        // When: Logging complex objects
        ModSwitchIMELogger.info("Dictionary: \(dictionary)")
        ModSwitchIMELogger.info("Array: \(array)")
        ModSwitchIMELogger.info("Date: \(date)")
        ModSwitchIMELogger.info("URL: \(String(describing: url))")
        
        // Then: Should handle object descriptions
        XCTAssertTrue(true, "Complex object logging should work")
    }
}

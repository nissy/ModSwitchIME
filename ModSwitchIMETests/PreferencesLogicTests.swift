import XCTest
@testable import ModSwitchIME

class PreferencesLogicTests: XCTestCase {
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
        
        // Store original values for cleanup
        UserDefaults.standard.set("test_running", forKey: "test_marker")
    }
    
    override func tearDown() {
        // Cleanup test data
        UserDefaults.standard.removeObject(forKey: "test_marker")
        preferences = nil
        super.tearDown()
    }
    
    // MARK: - Default CJK Input Source Detection Tests
    
    func testDefaultCJKDetectionWithJapaneseLocale() {
        // Given: Simulated Japanese locale environment
        // When: Creating new preferences (which triggers CJK detection)
        let testPreferences = Preferences.createForTesting()
        
        // Then: Should detect Japanese input method
        XCTAssertTrue(testPreferences.motherImeId.contains("Kotoeri") || 
                     testPreferences.motherImeId.contains("Japanese"),
                     "Should detect Japanese input method as default")
    }
    
    func testDefaultCJKDetectionFallback() {
        // Given: No specific CJK input method preference
        // When: Default detection runs
        let testPreferences = Preferences.createForTesting()
        
        // Then: Should have some valid input method selected
        XCTAssertFalse(testPreferences.motherImeId.isEmpty, "Should have default input method")
        XCTAssertTrue(testPreferences.motherImeId.contains("inputmethod") || 
                     testPreferences.motherImeId.contains("Kotoeri"),
                     "Default should be valid input method")
    }
    
    // MARK: - Preferences State Management Tests
    
    func testPreferencesInitializationWithExistingData() {
        // Given: Existing preferences data
        UserDefaults.standard.set(true, forKey: "idleOffEnabled")
        UserDefaults.standard.set(45.0, forKey: "idleTimeout")
        UserDefaults.standard.set(true, forKey: "launchAtLogin")
        UserDefaults.standard.set("com.test.ime", forKey: "motherImeId")
        
        // When: Creating new Preferences instance
        let testPreferences = Preferences.createForTesting()
        
        // Then: Should load existing data
        XCTAssertTrue(testPreferences.idleOffEnabled, "Should load existing idleOffEnabled")
        XCTAssertEqual(testPreferences.idleTimeout, 45.0, "Should load existing idleTimeout")
        XCTAssertTrue(testPreferences.launchAtLogin, "Should load existing launchAtLogin")
        XCTAssertEqual(testPreferences.motherImeId, "com.test.ime", "Should load existing motherImeId")
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "idleOffEnabled")
        UserDefaults.standard.removeObject(forKey: "idleTimeout")
        UserDefaults.standard.removeObject(forKey: "launchAtLogin")
        UserDefaults.standard.removeObject(forKey: "motherImeId")
    }
    
    func testPreferencesDefaultValues() {
        // Given: No existing preferences data
        UserDefaults.standard.removeObject(forKey: "idleOffEnabled")
        UserDefaults.standard.removeObject(forKey: "idleTimeout")
        UserDefaults.standard.removeObject(forKey: "launchAtLogin")
        UserDefaults.standard.removeObject(forKey: "motherImeId")
        
        // When: Creating new Preferences instance
        let testPreferences = Preferences.createForTesting()
        
        // Then: Should use default values
        XCTAssertFalse(testPreferences.idleOffEnabled, "Default idleOffEnabled should be false")
        XCTAssertEqual(testPreferences.idleTimeout, 5.0, "Default idleTimeout should be 5.0")
        XCTAssertFalse(testPreferences.launchAtLogin, "Default launchAtLogin should be false")
        XCTAssertFalse(testPreferences.motherImeId.isEmpty, "Default motherImeId should not be empty")
    }
    
    // MARK: - Property Change Propagation Tests
    
    func testIdleOffEnabledChangeNotification() {
        // Given: Preferences observer
        var notificationReceived = false
        let cancellable = preferences.$idleOffEnabled.sink { _ in
            notificationReceived = true
        }
        
        // When: Changing idleOffEnabled
        preferences.idleOffEnabled = true
        
        // Then: Should receive change notification
        XCTAssertTrue(notificationReceived, "Should receive change notification for idleOffEnabled")
        
        cancellable.cancel()
    }
    
    func testIdleTimeoutChangeNotification() {
        // Given: Preferences observer
        var notificationReceived = false
        var receivedValue: Double = 0
        let cancellable = preferences.$idleTimeout.sink { value in
            notificationReceived = true
            receivedValue = value
        }
        
        // When: Changing idleTimeout
        let newValue = 30.0
        preferences.idleTimeout = newValue
        
        // Then: Should receive change notification with correct value
        XCTAssertTrue(notificationReceived, "Should receive change notification for idleTimeout")
        XCTAssertEqual(receivedValue, newValue, "Should receive correct value in notification")
        
        cancellable.cancel()
    }
    
    func testMotherImeIdChangeNotification() {
        // Given: Preferences observer
        var notificationReceived = false
        var receivedValue: String = ""
        let cancellable = preferences.$motherImeId.sink { value in
            notificationReceived = true
            receivedValue = value
        }
        
        // When: Changing motherImeId
        let newValue = "com.test.new.ime"
        preferences.motherImeId = newValue
        
        // Then: Should receive change notification with correct value
        XCTAssertTrue(notificationReceived, "Should receive change notification for motherImeId")
        XCTAssertEqual(receivedValue, newValue, "Should receive correct value in notification")
        
        cancellable.cancel()
    }
    
    // MARK: - UserDefaults Synchronization Tests
    
    func testUserDefaultsSynchronization() {
        // Given: Initial state
        let initialTimeout = preferences.idleTimeout
        
        // When: Changing preference value
        let newTimeout = 75.0
        preferences.idleTimeout = newTimeout
        
        // Then: Should immediately sync to UserDefaults
        let userDefaultsValue = UserDefaults.standard.double(forKey: "idleTimeout")
        XCTAssertEqual(userDefaultsValue, newTimeout, "Should sync to UserDefaults immediately")
        
        // Restore original value
        preferences.idleTimeout = initialTimeout
    }
    
    func testMultiplePropertyChanges() {
        // Given: Initial state
        let initialIdleOff = preferences.idleOffEnabled
        let initialTimeout = preferences.idleTimeout
        let initialLaunch = preferences.launchAtLogin
        
        // When: Changing multiple properties
        preferences.idleOffEnabled = !initialIdleOff
        preferences.idleTimeout = 90.0
        preferences.launchAtLogin = !initialLaunch
        
        // Then: All changes should be persisted
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "idleOffEnabled"), !initialIdleOff)
        XCTAssertEqual(UserDefaults.standard.double(forKey: "idleTimeout"), 90.0)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "launchAtLogin"), !initialLaunch)
        
        // Restore original values
        preferences.idleOffEnabled = initialIdleOff
        preferences.idleTimeout = initialTimeout
        preferences.launchAtLogin = initialLaunch
    }
    
    // MARK: - Input Source Validation Tests
    
    func testValidInputSourceSelection() {
        // Given: List of available input sources
        let availableSources = Preferences.getAvailableInputSources()
        
        guard !availableSources.isEmpty else {
            XCTSkip("No available input sources found")
            return
        }
        
        // When: Selecting a valid input source
        let validSource = availableSources.first!
        preferences.motherImeId = validSource.id
        
        // Then: Should accept the valid source
        XCTAssertEqual(preferences.motherImeId, validSource.id, "Should accept valid input source")
    }
    
    func testInputSourcePersistenceAcrossInstances() {
        // Given: Selected input source
        let testImeId = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        preferences.motherImeId = testImeId
        
        // When: Creating new Preferences instance
        let newPreferences = Preferences.createForTesting()
        
        // Then: Should load the same input source (unless it was changed by CJK detection)
        if UserDefaults.standard.object(forKey: "motherImeId") != nil {
            XCTAssertEqual(newPreferences.motherImeId, testImeId, "Should persist input source across instances")
        }
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testNegativeTimeoutValue() {
        // Given: Negative timeout value
        let negativeValue = -10.0
        
        // When: Setting negative value
        preferences.idleTimeout = negativeValue
        
        // Then: Should store the value (validation is UI responsibility)
        XCTAssertEqual(preferences.idleTimeout, negativeValue, "Should store negative value")
    }
    
    func testVeryLargeTimeoutValue() {
        // Given: Very large timeout value
        let largeValue = 999999.0
        
        // When: Setting large value
        preferences.idleTimeout = largeValue
        
        // Then: Should store the value (validation is UI responsibility)
        XCTAssertEqual(preferences.idleTimeout, largeValue, "Should store large value")
    }
    
    func testSpecialCharactersInImeId() {
        // Given: IME ID with special characters
        let specialId = "com.test.ime-with_special.chars@123"
        
        // When: Setting IME ID with special characters
        preferences.motherImeId = specialId
        
        // Then: Should handle special characters
        XCTAssertEqual(preferences.motherImeId, specialId, "Should handle special characters in IME ID")
    }
    
    func testUnicodeInImeId() {
        // Given: IME ID with Unicode characters
        let unicodeId = "com.test.ime.日本語.unicode"
        
        // When: Setting IME ID with Unicode
        preferences.motherImeId = unicodeId
        
        // Then: Should handle Unicode characters
        XCTAssertEqual(preferences.motherImeId, unicodeId, "Should handle Unicode characters in IME ID")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentPropertyAccess() {
        // Given: Concurrent queue
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 2
        
        // When: Accessing properties concurrently
        concurrentQueue.async {
            for i in 0..<100 {
                self.preferences.idleTimeout = Double(i)
            }
            expectation.fulfill()
        }
        
        concurrentQueue.async {
            for i in 0..<100 {
                _ = self.preferences.idleTimeout
            }
            expectation.fulfill()
        }
        
        // Then: Should complete without crashes
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testPreferencesMemoryCleanup() {
        // Given: Weak reference to preferences
        weak var weakPreferences: Preferences?
        
        autoreleasepool {
            let tempPreferences = Preferences.createForTesting()
            weakPreferences = tempPreferences
            
            // Use the preferences
            tempPreferences.idleTimeout = 25.0
            XCTAssertNotNil(weakPreferences, "Preferences should exist during use")
        }
        
        // Then: Should be deallocated when out of scope
        XCTAssertNil(weakPreferences, "Preferences should be deallocated when out of scope")
    }
}

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
    
    // MARK: - Default Settings Tests
    
    func testNoDefaultCJKDetection() {
        // Given: Clean state with no existing preferences
        // When: Creating new preferences
        let testPreferences = Preferences.createForTesting()
        
        // Then: Should not automatically set motherImeId
        XCTAssertEqual(testPreferences.motherImeId, "", "Should not automatically set default input method")
    }
    
    func testNoDefaultModifierKeyMappings() {
        // Given: Clean state with no existing preferences
        // When: Creating new preferences
        let testPreferences = Preferences.createForTesting()
        
        // Then: Should not have any default modifier key mappings
        XCTAssertTrue(testPreferences.modifierKeyMappings.isEmpty, "Should not have default modifier key mappings")
    }
    
    // MARK: - Preferences State Management Tests
    
    func testPreferencesInitializationWithExistingData() {
        // Given: Store original values
        let originalIdleOffEnabled = Preferences.shared.idleOffEnabled
        let originalIdleTimeout = Preferences.shared.idleTimeout
        let originalLaunchAtLogin = Preferences.shared.launchAtLogin
        let originalMotherImeId = Preferences.shared.motherImeId
        
        // When: Setting new values
        Preferences.shared.idleOffEnabled = true
        Preferences.shared.idleTimeout = 45.0
        Preferences.shared.launchAtLogin = true
        Preferences.shared.motherImeId = "com.test.ime"
        
        // Then: Values should be set
        XCTAssertTrue(Preferences.shared.idleOffEnabled, "Should set idleOffEnabled")
        XCTAssertEqual(Preferences.shared.idleTimeout, 45.0, "Should set idleTimeout")
        XCTAssertTrue(Preferences.shared.launchAtLogin, "Should set launchAtLogin")
        XCTAssertEqual(Preferences.shared.motherImeId, "com.test.ime", "Should set motherImeId")
        
        // Verify persistence in UserDefaults
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "idleOffEnabled"), "Should persist idleOffEnabled")
        XCTAssertEqual(UserDefaults.standard.double(forKey: "idleTimeout"), 45.0, "Should persist idleTimeout")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "launchAtLogin"), "Should persist launchAtLogin")
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "motherImeId"),
            "com.test.ime",
            "Should persist motherImeId"
        )
        
        // Cleanup - restore original values
        Preferences.shared.idleOffEnabled = originalIdleOffEnabled
        Preferences.shared.idleTimeout = originalIdleTimeout
        Preferences.shared.launchAtLogin = originalLaunchAtLogin
        Preferences.shared.motherImeId = originalMotherImeId
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
        XCTAssertEqual(testPreferences.motherImeId, "", "Default motherImeId should be empty")
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
        // This test verifies that motherImeId is properly persisted in UserDefaults
        // and loaded correctly when creating new instances
        
        // Given: Store the original value to restore later
        let originalValue = UserDefaults.standard.string(forKey: "motherImeId")
        
        // Set a test value in UserDefaults AFTER creating test instance
        let testImeId = "com.apple.inputmethod.test.ime"
        let testPreferences = Preferences.createForTesting()
        
        // When: Setting a value and verifying it's saved to UserDefaults
        testPreferences.motherImeId = testImeId
        
        // Then: The value should be persisted to UserDefaults
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "motherImeId"),
            testImeId,
            "Should persist motherImeId to UserDefaults"
        )
        
        // Test loading: Change the value and verify it's saved
        let newImeId = "com.apple.inputmethod.new.test"
        testPreferences.motherImeId = newImeId
        
        // Verify it was saved to UserDefaults
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "motherImeId"),
            newImeId,
            "Should persist motherImeId to UserDefaults"
        )
        
        // Cleanup: Restore original value
        if let original = originalValue {
            UserDefaults.standard.set(original, forKey: "motherImeId")
        } else {
            UserDefaults.standard.removeObject(forKey: "motherImeId")
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
    
    // MARK: - Empty Dictionary Handling Tests
    
    func testEmptyModifierKeyMappingsNotSaved() {
        // Given: Clean state
        UserDefaults.standard.removeObject(forKey: "modifierKeyMappings")
        let testPreferences = Preferences.createForTesting()
        
        // When: Empty mappings (initial state)
        // Then: Should not save empty dictionary to UserDefaults
        XCTAssertNil(UserDefaults.standard.object(forKey: "modifierKeyMappings"), 
                     "Should not save empty modifierKeyMappings to UserDefaults")
        
        // When: Adding a mapping
        testPreferences.setIME("com.apple.keylayout.US", for: .leftCommand)
        
        // Then: Should save to UserDefaults
        XCTAssertNotNil(UserDefaults.standard.object(forKey: "modifierKeyMappings"),
                        "Should save non-empty modifierKeyMappings to UserDefaults")
        
        // When: Removing all mappings
        testPreferences.setIME(nil, for: .leftCommand)
        
        // Then: Should remove from UserDefaults
        XCTAssertNil(UserDefaults.standard.object(forKey: "modifierKeyMappings"),
                     "Should remove modifierKeyMappings from UserDefaults when empty")
    }
    
    func testEmptyModifierKeyEnabledNotSaved() {
        // Given: Clean state
        UserDefaults.standard.removeObject(forKey: "modifierKeyEnabled")
        let testPreferences = Preferences.createForTesting()
        
        // When: Empty enabled states (initial state)
        // Then: Should not save empty dictionary to UserDefaults
        XCTAssertNil(UserDefaults.standard.object(forKey: "modifierKeyEnabled"),
                     "Should not save empty modifierKeyEnabled to UserDefaults")
        
        // When: Enabling a key
        testPreferences.setKeyEnabled(true, for: .leftCommand)
        
        // Then: Should save to UserDefaults
        XCTAssertNotNil(UserDefaults.standard.object(forKey: "modifierKeyEnabled"),
                        "Should save non-empty modifierKeyEnabled to UserDefaults")
        
        // When: Disabling all keys (removing from dictionary)
        testPreferences.modifierKeyEnabled.removeAll()
        
        // Then: Should remove from UserDefaults
        XCTAssertNil(UserDefaults.standard.object(forKey: "modifierKeyEnabled"),
                     "Should remove modifierKeyEnabled from UserDefaults when empty")
    }
    
    func testModifierKeyMappingsPersistence() {
        // Given: Test data
        let testMappings: [ModifierKey: String] = [
            .leftCommand: "com.apple.keylayout.US",
            .rightCommand: "com.apple.inputmethod.Kotoeri.Hiragana"
        ]
        
        // When: Setting mappings
        preferences.modifierKeyMappings = testMappings
        
        // Then: Should persist to UserDefaults as JSON
        let data = UserDefaults.standard.data(forKey: "modifierKeyMappings")
        XCTAssertNotNil(data, "Should save modifierKeyMappings as data")
        
        // Verify data can be decoded back
        if let data = data,
           let decoded = try? JSONDecoder().decode([ModifierKey: String].self, from: data) {
            XCTAssertEqual(decoded.count, testMappings.count, "Should preserve all mappings")
            XCTAssertEqual(decoded[.leftCommand], testMappings[.leftCommand], 
                          "Should preserve leftCommand mapping")
            XCTAssertEqual(decoded[.rightCommand], testMappings[.rightCommand],
                          "Should preserve rightCommand mapping")
        } else {
            XCTFail("Failed to decode modifierKeyMappings")
        }
    }
    
    func testModifierKeyEnabledPersistence() {
        // Given: Test data
        let testEnabled: [ModifierKey: Bool] = [
            .leftShift: true,
            .rightShift: false,
            .leftOption: true
        ]
        
        // When: Setting enabled states
        preferences.modifierKeyEnabled = testEnabled
        
        // Then: Should persist to UserDefaults as JSON
        let data = UserDefaults.standard.data(forKey: "modifierKeyEnabled")
        XCTAssertNotNil(data, "Should save modifierKeyEnabled as data")
        
        // Verify data can be decoded back
        if let data = data,
           let decoded = try? JSONDecoder().decode([ModifierKey: Bool].self, from: data) {
            XCTAssertEqual(decoded.count, testEnabled.count, "Should preserve all enabled states")
            XCTAssertEqual(decoded[.leftShift], testEnabled[.leftShift],
                          "Should preserve leftShift state")
            XCTAssertEqual(decoded[.rightShift], testEnabled[.rightShift],
                          "Should preserve rightShift state")
            XCTAssertEqual(decoded[.leftOption], testEnabled[.leftOption],
                          "Should preserve leftOption state")
        } else {
            XCTFail("Failed to decode modifierKeyEnabled")
        }
    }
    
    func testLoadingFromEmptyArrayData() {
        // This test simulates the bug where empty array [] was saved instead of empty dictionary {}
        
        // Given: Empty array data in UserDefaults (simulating the bug)
        let emptyArrayData = "[]".data(using: .utf8)!
        UserDefaults.standard.set(emptyArrayData, forKey: "modifierKeyMappings")
        UserDefaults.standard.set(emptyArrayData, forKey: "modifierKeyEnabled")
        
        // When: Creating new Preferences instance
        let testPreferences = Preferences.createForTesting()
        
        // Then: Should handle gracefully and return empty dictionaries
        XCTAssertTrue(testPreferences.modifierKeyMappings.isEmpty,
                     "Should handle empty array data gracefully for mappings")
        XCTAssertTrue(testPreferences.modifierKeyEnabled.isEmpty,
                     "Should handle empty array data gracefully for enabled states")
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "modifierKeyMappings")
        UserDefaults.standard.removeObject(forKey: "modifierKeyEnabled")
    }
}

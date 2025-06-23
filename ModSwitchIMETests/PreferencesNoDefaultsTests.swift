import XCTest
@testable import ModSwitchIME

class PreferencesNoDefaultsTests: XCTestCase {
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        // Clear all UserDefaults to ensure clean state
        let keysToRemove = [
            "idleOffEnabled", "idleTimeout", "launchAtLogin", "motherImeId",
            "cmdKeyTimeout", "cmdKeyTimeoutEnabled", "idleReturnIME",
            "modifierKeyMappings", "modifierKeyEnabled"
        ]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        preferences = Preferences.createForTesting()
    }
    
    override func tearDown() {
        preferences = nil
        super.tearDown()
    }
    
    // MARK: - No Default Settings Tests
    
    func testNoDefaultCJKInputMethodSet() {
        // Given: Fresh preferences instance with clean UserDefaults
        // When: Checking motherImeId property
        // Then: Should be empty string (no automatic detection)
        XCTAssertEqual(preferences.motherImeId, "", "motherImeId should be empty by default")
    }
    
    func testNoDefaultModifierKeyMappings() {
        // Given: Fresh preferences instance with clean UserDefaults
        // When: Checking modifierKeyMappings property
        // Then: Should be empty dictionary (no automatic mappings)
        XCTAssertTrue(preferences.modifierKeyMappings.isEmpty, "modifierKeyMappings should be empty by default")
        
        // Verify specific keys are not set
        XCTAssertNil(preferences.modifierKeyMappings[.leftCommand], "Left Command should not be mapped by default")
        XCTAssertNil(preferences.modifierKeyMappings[.rightCommand], 
                    "Right Command should not be mapped by default")
        XCTAssertNil(preferences.modifierKeyMappings[.leftControl], 
                    "Left Control should not be mapped by default")
        XCTAssertNil(preferences.modifierKeyMappings[.rightControl], 
                    "Right Control should not be mapped by default")
        XCTAssertNil(preferences.modifierKeyMappings[.leftShift], "Left Shift should not be mapped by default")
        XCTAssertNil(preferences.modifierKeyMappings[.rightShift], "Right Shift should not be mapped by default")
        XCTAssertNil(preferences.modifierKeyMappings[.leftOption], "Left Option should not be mapped by default")
        XCTAssertNil(preferences.modifierKeyMappings[.rightOption], "Right Option should not be mapped by default")
    }
    
    func testNoDefaultEnabledModifierKeys() {
        // Given: Fresh preferences instance with clean UserDefaults
        // When: Checking modifierKeyEnabled property
        // Then: Should be empty dictionary (no keys enabled by default)
        XCTAssertTrue(preferences.modifierKeyEnabled.isEmpty, "modifierKeyEnabled should be empty by default")
        
        // Verify all keys are disabled by default
        for key in ModifierKey.allCases {
            XCTAssertFalse(preferences.isKeyEnabled(key), "\(key.displayName) should be disabled by default")
        }
    }
    
    func testNoMigrationFromOldMotherImeId() {
        // Given: Old motherImeId is set in UserDefaults but no modifier key mappings exist
        let testImeId = "com.apple.inputmethod.test.japanese"
        
        // Clear all UserDefaults first
        let keysToRemove = [
            "idleOffEnabled", "idleTimeout", "launchAtLogin", "motherImeId",
            "cmdKeyTimeout", "cmdKeyTimeoutEnabled", "idleReturnIME",
            "modifierKeyMappings", "modifierKeyEnabled"
        ]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Set up the scenario: motherImeId exists but no modifier mappings
        UserDefaults.standard.set(testImeId, forKey: "motherImeId")
        UserDefaults.standard.synchronize()
        
        // When: Creating new preferences instance (using migration testing method)
        let testPreferences = Preferences.createForMigrationTesting()
        
        // Then: Should NOT migrate motherImeId to any command mapping
        XCTAssertEqual(testPreferences.motherImeId, testImeId, "motherImeId should be preserved")
        XCTAssertNil(testPreferences.modifierKeyMappings[.rightCommand], 
                    "Should NOT migrate to right command mapping")
        XCTAssertNil(testPreferences.modifierKeyMappings[.leftCommand], 
                    "Left command should not be set automatically")
        XCTAssertTrue(testPreferences.modifierKeyMappings.isEmpty, "No automatic mappings should be created")
    }
    
    func testNoMigrationWhenBothOldAndNewDataExist() {
        // Given: Both old motherImeId and new modifier key mappings exist
        let oldImeId = "com.apple.inputmethod.old.japanese"
        let newImeId = "com.apple.inputmethod.new.japanese"
        
        // Clear all UserDefaults first
        let keysToRemove = [
            "idleOffEnabled", "idleTimeout", "launchAtLogin", "motherImeId",
            "cmdKeyTimeout", "cmdKeyTimeoutEnabled", "idleReturnIME",
            "modifierKeyMappings", "modifierKeyEnabled"
        ]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Set up the scenario: both old motherImeId and existing mappings
        UserDefaults.standard.set(oldImeId, forKey: "motherImeId")
        
        // Set up existing modifier key mappings
        let mappings = [ModifierKey.leftCommand: newImeId]
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(mappings) {
            UserDefaults.standard.set(data, forKey: "modifierKeyMappings")
        }
        UserDefaults.standard.synchronize()
        
        // When: Creating new preferences instance (using migration testing method)
        let testPreferences = Preferences.createForMigrationTesting()
        
        // Then: Should keep existing mappings and NOT do any migration
        XCTAssertEqual(testPreferences.motherImeId, oldImeId, "motherImeId should be preserved")
        XCTAssertEqual(testPreferences.modifierKeyMappings[.leftCommand], newImeId, 
                      "Existing mapping should be preserved")
        XCTAssertNil(testPreferences.modifierKeyMappings[.rightCommand], 
                    "Should not migrate - no automatic mappings")
    }
    
    func testEmptyStateAfterCleanInstall() {
        // Given: Completely clean UserDefaults (simulating fresh app install)
        // When: Creating preferences instance
        // Then: All settings should be at their basic default values without any automatic configuration
        
        // Basic property defaults
        XCTAssertFalse(preferences.idleOffEnabled, "idleOffEnabled should default to false")
        XCTAssertEqual(preferences.idleTimeout, 5.0, "idleTimeout should default to 5.0")
        XCTAssertFalse(preferences.launchAtLogin, "launchAtLogin should default to false")
        XCTAssertEqual(preferences.cmdKeyTimeout, 0.3, "cmdKeyTimeout should default to 0.3")
        XCTAssertFalse(preferences.cmdKeyTimeoutEnabled, "cmdKeyTimeoutEnabled should default to false")
        XCTAssertNil(preferences.idleReturnIME, "idleReturnIME should default to nil")
        
        // No automatic IME detection or configuration
        XCTAssertEqual(preferences.motherImeId, "", "motherImeId should be empty")
        XCTAssertTrue(preferences.modifierKeyMappings.isEmpty, "modifierKeyMappings should be empty")
        XCTAssertTrue(preferences.modifierKeyEnabled.isEmpty, "modifierKeyEnabled should be empty")
    }
    
    func testUserMustManuallyConfigureAllSettings() {
        // Given: Fresh preferences instance
        // When: User wants to use the app
        // Then: They need to manually configure IME mappings and enable keys
        
        // Verify no functionality is available by default
        XCTAssertNil(preferences.getIME(for: .leftCommand), "Left Command should have no IME by default")
        XCTAssertNil(preferences.getIME(for: .rightCommand), "Right Command should have no IME by default")
        XCTAssertFalse(preferences.isKeyEnabled(.leftCommand), "Left Command should be disabled by default")
        XCTAssertFalse(preferences.isKeyEnabled(.rightCommand), "Right Command should be disabled by default")
        
        // Simulate user configuration
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setIME("com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", 
                           for: .rightCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        preferences.setKeyEnabled(true, for: .rightCommand)
        
        // Verify configuration is applied
        XCTAssertEqual(preferences.getIME(for: .leftCommand), "com.apple.keylayout.ABC", 
                      "Left Command should be configured")
        XCTAssertEqual(preferences.getIME(for: .rightCommand), "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", 
                      "Right Command should be configured")
        XCTAssertTrue(preferences.isKeyEnabled(.leftCommand), "Left Command should be enabled after configuration")
        XCTAssertTrue(preferences.isKeyEnabled(.rightCommand), "Right Command should be enabled after configuration")
    }
}

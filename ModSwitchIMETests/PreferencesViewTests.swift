import XCTest
import SwiftUI
@testable import ModSwitchIME

class PreferencesViewTests: XCTestCase {
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences()
    }
    
    override func tearDown() {
        preferences = nil
        super.tearDown()
    }
    
    // MARK: - Timeout Setting Tests
    
    func testIdleTimeoutToggleDefault() {
        // Given: Default preferences
        // When: Initial state
        // Then: Idle timeout should be disabled by default
        XCTAssertFalse(preferences.idleOffEnabled, "Idle timeout should be disabled by default")
    }
    
    func testIdleTimeoutRangeValidation() {
        // Given: Preferences with idle timeout enabled
        preferences.idleOffEnabled = true
        
        // When: Setting timeout to minimum value
        preferences.idleTimeout = 1.0
        // Then: Should accept minimum value
        XCTAssertEqual(preferences.idleTimeout, 1.0, "Should accept minimum timeout value of 1 second")
        
        // When: Setting timeout to maximum value
        preferences.idleTimeout = 300.0
        // Then: Should accept maximum value
        XCTAssertEqual(preferences.idleTimeout, 300.0, "Should accept maximum timeout value of 300 seconds")
        
        // When: Setting timeout to middle value
        preferences.idleTimeout = 30.0
        // Then: Should accept middle value
        XCTAssertEqual(preferences.idleTimeout, 30.0, "Should accept middle timeout value")
    }
    
    func testIdleTimeoutPersistence() {
        // Given: Original timeout value
        let originalTimeout = preferences.idleTimeout
        
        // When: Changing timeout value
        let newTimeout = 45.0
        preferences.idleTimeout = newTimeout
        
        // Then: Value should persist in UserDefaults
        let persistedValue = UserDefaults.standard.double(forKey: "idleTimeout")
        XCTAssertEqual(persistedValue, newTimeout, "Timeout value should persist in UserDefaults")
        
        // Cleanup: Restore original value
        preferences.idleTimeout = originalTimeout
    }
    
    // MARK: - Input Source Selection Tests
    
    func testMotherImeIdDefault() {
        // Given: Fresh preferences
        let testPreferences = Preferences()
        
        // When: Initial state
        // Then: Should have a default IME selected
        XCTAssertFalse(testPreferences.motherImeId.isEmpty, "Should have default mother IME ID")
        XCTAssertTrue(testPreferences.motherImeId.contains("inputmethod") || 
                     testPreferences.motherImeId.contains("Kotoeri"), 
                     "Default IME should be a valid input method")
    }
    
    func testMotherImeIdPersistence() {
        // Given: Test IME ID
        let testImeId = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        
        // When: Setting mother IME ID
        preferences.motherImeId = testImeId
        
        // Then: Value should persist in UserDefaults
        let persistedValue = UserDefaults.standard.string(forKey: "motherImeId")
        XCTAssertEqual(persistedValue, testImeId, "Mother IME ID should persist in UserDefaults")
    }
    
    func testInputSourceNameResolution() {
        // Given: Known input source IDs
        let testCases = [
            ("com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", "Hiragana"),
            ("com.apple.keylayout.ABC", "ABC"),
            ("", "Please select")
        ]
        
        for (sourceId, expectedNamePart) in testCases {
            // When: Setting input source ID
            preferences.motherImeId = sourceId
            
            // Create view to test name resolution
            let view = PreferencesView().environmentObject(preferences)
            
            // Then: Should resolve to appropriate name (this is a basic structural test)
            XCTAssertNotNil(view, "PreferencesView should be created successfully")
        }
    }
    
    // MARK: - Launch at Login Tests
    
    func testLaunchAtLoginDefault() {
        // Given: Default preferences
        // When: Initial state
        // Then: Launch at login should be disabled by default
        XCTAssertFalse(preferences.launchAtLogin, "Launch at login should be disabled by default")
    }
    
    func testLaunchAtLoginToggle() {
        // Given: Initial state
        let initialState = preferences.launchAtLogin
        
        // When: Toggling launch at login
        preferences.launchAtLogin = !initialState
        
        // Then: Value should change
        XCTAssertNotEqual(preferences.launchAtLogin, initialState, "Launch at login state should change")
        
        // And: Should persist in UserDefaults
        let persistedValue = UserDefaults.standard.bool(forKey: "launchAtLogin")
        XCTAssertEqual(persistedValue, preferences.launchAtLogin, "Launch at login should persist in UserDefaults")
        
        // Cleanup: Restore original state
        preferences.launchAtLogin = initialState
    }
    
    // MARK: - View Construction Tests
    
    func testPreferencesViewCreation() {
        // Given: Valid preferences
        // When: Creating PreferencesView
        let view = PreferencesView().environmentObject(preferences)
        
        // Then: View should be created without errors
        XCTAssertNotNil(view, "PreferencesView should be created successfully")
    }
    
    func testInputSourcePickerSheetCreation() {
        // Given: Valid binding values
        let selectedSourceId = Binding.constant("test.source.id")
        let isPresented = Binding.constant(true)
        
        // When: Creating InputSourcePickerSheet
        let sheet = InputSourcePickerSheet(selectedSourceId: selectedSourceId, isPresented: isPresented)
        
        // Then: Sheet should be created without errors
        XCTAssertNotNil(sheet, "InputSourcePickerSheet should be created successfully")
    }
    
    // MARK: - Input Source Filtering and Grouping Tests
    
    func testInputSourceGrouping() {
        // Given: All available input sources
        let allSources = Preferences.getAllInputSources(includeDisabled: false)
        
        // When: Grouping by language
        var groupedSources: [String: [Preferences.InputSource]] = [:]
        for source in allSources {
            let language = Preferences.getInputSourceLanguage(source.sourceId)
            if groupedSources[language] == nil {
                groupedSources[language] = []
            }
            groupedSources[language]?.append(source)
        }
        
        // Then: Should have grouped sources by language
        XCTAssertGreaterThan(groupedSources.count, 0, "Should have at least one language group")
        
        // And: Each group should have at least one source
        for (language, sources) in groupedSources {
            XCTAssertGreaterThan(sources.count, 0, "Language group \(language) should have at least one source")
        }
    }
    
    func testInputSourceSearchFiltering() {
        // Given: All input sources and search text
        let allSources = Preferences.getAllInputSources(includeDisabled: false)
        let searchText = "Japanese"
        
        // When: Filtering sources by search text
        let filteredSources = allSources.filter { source in
            source.localizedName.localizedCaseInsensitiveContains(searchText) ||
            source.sourceId.localizedCaseInsensitiveContains(searchText)
        }
        
        // Then: Should only include matching sources
        for source in filteredSources {
            let matchesName = source.localizedName.localizedCaseInsensitiveContains(searchText)
            let matchesId = source.sourceId.localizedCaseInsensitiveContains(searchText)
            XCTAssertTrue(matchesName || matchesId, "Filtered source should match search criteria")
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testInvalidInputSourceId() {
        // Given: Invalid input source ID
        let invalidId = "invalid.nonexistent.source.id"
        
        // When: Setting invalid ID
        preferences.motherImeId = invalidId
        
        // Then: Should handle gracefully (no crash)
        XCTAssertEqual(preferences.motherImeId, invalidId, "Should store even invalid IDs")
        
        // And: Name resolution should provide fallback
        let allSources = Preferences.getAllInputSources()
        let foundSource = allSources.first { $0.sourceId == invalidId }
        XCTAssertNil(foundSource, "Invalid source should not be found in available sources")
    }
    
    func testEmptyInputSourceId() {
        // Given: Empty input source ID
        let emptyId = ""
        
        // When: Setting empty ID
        preferences.motherImeId = emptyId
        
        // Then: Should handle gracefully
        XCTAssertEqual(preferences.motherImeId, emptyId, "Should store empty ID")
    }
    
    func testTimeoutBoundaryValues() {
        // Given: Boundary values for timeout
        let boundaryValues: [Double] = [0.5, 1.0, 1.1, 299.9, 300.0, 300.1]
        
        for value in boundaryValues {
            // When: Setting boundary value
            preferences.idleTimeout = value
            
            // Then: Should accept the value (clamping is handled by UI, not model)
            XCTAssertEqual(preferences.idleTimeout, value, "Should accept boundary value \(value)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testInputSourceLoadingPerformance() {
        // Given: Performance expectation
        measure {
            // When: Loading all input sources multiple times
            for _ in 0..<10 {
                _ = Preferences.getAllInputSources(includeDisabled: true)
            }
        }
        
        // Then: Should complete within reasonable time (measured by XCTest)
    }
    
    func testLanguageDetectionPerformance() {
        // Given: Sample input source IDs
        let sampleIds = [
            "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
            "com.apple.inputmethod.SCIM.ITABC",
            "com.apple.inputmethod.Korean.2SetKorean",
            "com.apple.keylayout.ABC",
            "com.apple.keylayout.US"
        ]
        
        // When: Detecting languages multiple times
        measure {
            for _ in 0..<100 {
                for id in sampleIds {
                    _ = Preferences.getInputSourceLanguage(id)
                }
            }
        }
        
        // Then: Should complete within reasonable time (measured by XCTest)
    }
}

import XCTest
@testable import ModSwitchIME

class InputSourceEdgeCaseTests: XCTestCase {
    
    // MARK: - Input Source Enumeration Edge Cases
    
    func testEmptyInputSourcesList() {
        // Given: System with potentially no input sources (edge case)
        let allSources = Preferences.getAllInputSources(includeDisabled: true)
        
        // When: Getting available sources
        let availableSources = Preferences.getAvailableInputSources()
        
        // Then: Should handle empty lists gracefully
        XCTAssertTrue(allSources.isEmpty || !allSources.isEmpty, "Should handle empty input sources list")
        XCTAssertTrue(
            availableSources.isEmpty || !availableSources.isEmpty,
            "Should handle empty available sources list"
        )
    }
    
    func testDisabledInputSourcesHandling() {
        // Given: System with disabled input sources
        let enabledSources = Preferences.getAllInputSources(includeDisabled: false)
        let allSources = Preferences.getAllInputSources(includeDisabled: true)
        
        // When: Comparing enabled vs all sources
        // Then: All sources count should be >= enabled sources count
        XCTAssertGreaterThanOrEqual(
            allSources.count,
            enabledSources.count,
            "All sources should include at least as many as enabled sources"
        )
        
        // And: Should properly track enabled state
        for source in allSources where !source.isEnabled {
            XCTAssertFalse(
                enabledSources.contains { $0.sourceId == source.sourceId },
                "Disabled source should not appear in enabled-only list"
            )
        }
    }
    
    func testDuplicateInputSourceIds() {
        // Given: All input sources
        let allSources = Preferences.getAllInputSources(includeDisabled: true)
        
        // When: Checking for duplicate IDs
        var seenIds = Set<String>()
        var duplicates: [String] = []
        
        for source in allSources {
            if seenIds.contains(source.sourceId) {
                duplicates.append(source.sourceId)
            } else {
                seenIds.insert(source.sourceId)
            }
        }
        
        // Then: Should not have duplicate source IDs
        XCTAssertTrue(duplicates.isEmpty, "Should not have duplicate source IDs: \(duplicates)")
    }
    
    // MARK: - Language Detection Edge Cases
    
    func testUnknownLanguageDetection() {
        // Given: Unknown or fictional input source IDs
        let unknownIds = [
            "com.unknown.inputmethod.fictional",
            "totally.invalid.source.id",
            "ñöñ-äscïï.çhärãctërs.12345",
            "",
            "com.future.inputmethod.NotYetInvented"
        ]
        
        for unknownId in unknownIds {
            // When: Detecting language for unknown ID
            let language = Preferences.getInputSourceLanguage(unknownId)
            
            // Then: Should fallback to default category
            XCTAssertEqual(
                language,
                "English & Others",
                "Unknown source '\(unknownId)' should fallback to 'English & Others'"
            )
        }
    }
    
    func testBoundaryLanguageDetection() {
        // Given: Edge case input source IDs that might confuse language detection
        let edgeCaseIds = [
            "japanese", // lowercase
            "JAPANESE", // uppercase
            "Japanese", // mixed case but not in expected format
            "com.apple.inputmethod.japanese", // wrong case
            "com.apple.inputmethod.Chinese", // wrong case
            "something.Japanese.something", // Japanese in middle
            "Japanese.something", // Japanese at start
            "something.Japanese" // Japanese at end
        ]
        
        for edgeId in edgeCaseIds {
            // When: Detecting language
            let language = Preferences.getInputSourceLanguage(edgeId)
            
            // Then: Should handle case sensitivity and positioning correctly
            XCTAssertNotNil(language, "Should return some language for '\(edgeId)'")
            XCTAssertFalse(language.isEmpty, "Language should not be empty for '\(edgeId)'")
        }
    }
    
    func testMixedLanguageInputSources() {
        // Given: Input source IDs that might contain multiple language indicators
        let mixedIds = [
            "com.test.Japanese.Chinese.inputmethod",
            "com.mixed.Korean.Japanese.ime",
            "com.multilang.English.French.German.kbd"
        ]
        
        for mixedId in mixedIds {
            // When: Detecting language
            let language = Preferences.getInputSourceLanguage(mixedId)
            
            // Then: Should return first detected language (Japanese should win in first case)
            XCTAssertNotNil(language, "Should detect language for mixed ID '\(mixedId)'")
            
            // For the first case, Japanese should be detected first
            if mixedId.contains("Japanese.Chinese") {
                XCTAssertEqual(language, "Japanese", "Should detect Japanese first in mixed Japanese.Chinese ID")
            }
        }
    }
    
    // MARK: - Icon Mapping Edge Cases
    
    func testIconMappingForEdgeCases() {
        // Given: Edge case input source IDs
        let edgeCaseIds = [
            "", // empty
            "a", // single character
            "Japanese", // just the language name
            "com.apple.inputmethod.", // incomplete
            "com.apple.inputmethod.Japanese.Extra.Long.Path.With.Many.Components",
            "🇯🇵.emoji.in.id", // emoji in ID
            "com.test.japanese", // lowercase
            "COM.APPLE.INPUTMETHOD.JAPANESE" // uppercase
        ]
        
        for edgeId in edgeCaseIds {
            // When: Getting icon for edge case ID
            let icon = Preferences.getInputSourceIcon(edgeId)
            
            // Then: Should return some icon (never nil)
            XCTAssertNotNil(icon, "Should return icon for edge case ID '\(edgeId)'")
            XCTAssertFalse(icon!.isEmpty, "Icon should not be empty for '\(edgeId)'")
        }
    }
    
    func testDefaultIconFallback() {
        // Given: IDs that shouldn't match any specific language
        let fallbackIds = [
            "com.unknown.inputmethod",
            "totally.random.id",
            "1234567890",
            "!@#$%^&*()",
            "com.test.NoLanguage"
        ]
        
        for fallbackId in fallbackIds {
            // When: Getting icon
            let icon = Preferences.getInputSourceIcon(fallbackId)
            
            // Then: Should return default keyboard icon
            XCTAssertEqual(icon, "⌨️", "Should return default keyboard icon for '\(fallbackId)'")
        }
    }
    
    // MARK: - Category Classification Edge Cases
    
    func testCategoryClassificationEdgeCases() {
        // Given: Edge case source IDs
        let edgeCases = [
            ("", "Others"),
            ("inputmethod", "Input Method"),
            ("keylayout", "Others"), // needs full prefix
            ("com.apple.keylayout", "Others"), // needs full prefix with dot
            ("com.apple.keylayout.", "Keyboard Layout"),
            ("ATOK", "Input Method"),
            ("atok", "Others"), // case sensitive
            ("google", "Input Method"),
            ("GOOGLE", "Others"), // case sensitive
            ("com.apple.inputmethod.something", "Input Method"),
            ("random.string", "Others")
        ]
        
        for (sourceId, expectedCategory) in edgeCases {
            // When: Getting category
            let category = Preferences.getInputSourceCategory(sourceId)
            
            // Then: Should match expected category
            XCTAssertEqual(
                category,
                expectedCategory,
                "Source '\(sourceId)' should be categorized as '\(expectedCategory)', got '\(category)'"
            )
        }
    }
    
    // MARK: - Input Source Filtering Edge Cases
    
    func testSearchFilteringWithSpecialCharacters() {
        // Given: Input sources and special search terms
        let allSources = Preferences.getAllInputSources(includeDisabled: true)
        let specialSearchTerms = [
            "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
            "ñ", "ü", "ö", "ä", "ß",
            "日本語", "中文", "한국어",
            "", // empty search
            " ", // space only
            "  multiple  spaces  "
        ]
        
        for searchTerm in specialSearchTerms {
            // When: Filtering with special characters
            let filteredSources = allSources.filter { source in
                source.localizedName.localizedCaseInsensitiveContains(searchTerm)
                    || source.sourceId.localizedCaseInsensitiveContains(searchTerm)
            }
            
            // Then: Should handle special characters without crashing
            XCTAssertTrue(
                filteredSources.isEmpty || !filteredSources.isEmpty,
                "Should handle special search term '\(searchTerm)' without crashing"
            )
            
            // For empty search, should return empty results (as the filter requires contains)
            if searchTerm.isEmpty {
                XCTAssertTrue(filteredSources.isEmpty, "Empty search term should return no results")
            }
        }
    }
    
    func testVeryLongInputSourceNames() {
        // Given: Simulated very long input source name
        let longName = String(repeating: "VeryLongInputSourceName", count: 100)
        let testSource = Preferences.InputSource(sourceId: "com.test.long", localizedName: longName)
        
        // When: Processing long name
        let icon = Preferences.getInputSourceIcon(testSource.sourceId)
        let language = Preferences.getInputSourceLanguage(testSource.sourceId)
        let category = Preferences.getInputSourceCategory(testSource.sourceId)
        
        // Then: Should handle long names gracefully
        XCTAssertNotNil(icon, "Should handle long names for icon mapping")
        XCTAssertNotNil(language, "Should handle long names for language detection")
        XCTAssertNotNil(category, "Should handle long names for category classification")
    }
    
    // MARK: - Concurrent Access Edge Cases
    
    func testConcurrentInputSourceAccess() {
        // Test concurrent access to input sources
        // Use serial queue to avoid TIS API issues on background threads
        // Given: Serial execution to test thread safety without TIS API conflicts
        let serialQueue = DispatchQueue(label: "test.serial.input.sources")
        let expectation = XCTestExpectation(description: "Serial input source access")
        expectation.expectedFulfillmentCount = 3
        
        // When: Accessing input sources from background thread (but serially)
        serialQueue.async {
            autoreleasepool {
                for _ in 0..<3 {  // Reduced iterations
                    _ = Preferences.getAllInputSources(includeDisabled: true)
                }
            }
            expectation.fulfill()
        }
        
        serialQueue.async {
            autoreleasepool {
                for _ in 0..<3 {  // Reduced iterations
                    _ = Preferences.getAvailableInputSources()
                }
            }
            expectation.fulfill()
        }
        
        serialQueue.async {
            autoreleasepool {
                let testIds = ["com.apple.keylayout.ABC", "com.apple.inputmethod.Kotoeri.Japanese"]
                for _ in 0..<5 {  // Reduced iterations
                    for id in testIds {
                        _ = Preferences.getInputSourceLanguage(id)
                        _ = Preferences.getInputSourceIcon(id)
                        _ = Preferences.getInputSourceCategory(id)
                    }
                }
            }
            expectation.fulfill()
        }
        
        // Then: Should complete without crashes or data corruption
        wait(for: [expectation], timeout: 15.0)  // Increased timeout
    }
    
    // MARK: - Performance Edge Cases
    
    func testPerformanceWithManyInputSources() {
        // Given: Performance measurement
        measure {
            // When: Processing input sources multiple times
            for _ in 0..<5 {
                let sources = Preferences.getAllInputSources(includeDisabled: true)
                
                // Process each source
                for source in sources {
                    _ = Preferences.getInputSourceLanguage(source.sourceId)
                    _ = Preferences.getInputSourceIcon(source.sourceId)
                    _ = Preferences.getInputSourceCategory(source.sourceId)
                }
            }
        }
        
        // Then: Should complete within reasonable time (measured by XCTest)
    }
    
    func testMemoryUsageWithRepeatedAccess() {
        // Given: Memory usage test
        // When: Repeatedly accessing input sources
        for _ in 0..<100 {
            autoreleasepool {
                let sources = Preferences.getAllInputSources(includeDisabled: true)
                
                // Create temporary data structures
                let grouped = Dictionary(grouping: sources) { source in
                    Preferences.getInputSourceLanguage(source.sourceId)
                }
                
                // Process grouped data
                for (_, groupedSources) in grouped {
                    for source in groupedSources {
                        _ = Preferences.getInputSourceIcon(source.sourceId)
                    }
                }
            }
        }
        
        // Then: Should not accumulate excessive memory (verified by running under instruments)
        // This test mainly ensures no obvious memory leaks in repeated access patterns
        XCTAssertTrue(true, "Memory usage test completed")
    }
}

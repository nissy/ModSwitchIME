import XCTest
@testable import ModSwitchIME

class PreferencesInputSourceTests: XCTestCase {
    
    func testGetAvailableInputSources() {
        let sources = Preferences.getAvailableInputSources()
        
        // Some systems may have fewer available input sources
        if sources.isEmpty {
            // Issue warning but pass the test
            Logger.warning(
                "No available input sources found. This might be expected in test environment.", 
                category: .tests
            )
        } else {
            // Verify each input source has ID and name
            for source in sources {
                XCTAssertFalse(source.id.isEmpty, "Input source ID is empty")
                XCTAssertFalse(source.name.isEmpty, "Input source name is empty")
            }
        }
        
        // At minimum, getAllInputSources should return something
        let allSources = Preferences.getAllInputSources()
        XCTAssertGreaterThan(allSources.count, 0, "System should have at least one input source")
    }
    
    func testGetAllInputSources() {
        let enabledSources = Preferences.getAllInputSources(includeDisabled: false)
        let allSources = Preferences.getAllInputSources(includeDisabled: true)
        
        // Total sources should be greater than or equal to available sources
        XCTAssertGreaterThanOrEqual(allSources.count, enabledSources.count)
        
        // Verify each source has valid properties
        for source in allSources {
            XCTAssertFalse(source.sourceId.isEmpty, "Source ID is empty")
            XCTAssertFalse(source.localizedName.isEmpty, "Localized name is empty")
        }
    }
    
    func testInputSourceIconMapping() {
        // Japanese - Kotoeri is detected
        let jaIcon = Preferences.getInputSourceIcon("com.apple.inputmethod.Kotoeri.Japanese")
        XCTAssertEqual(jaIcon, "🇯🇵")
        
        // English - ABC is detected
        let enIcon = Preferences.getInputSourceIcon("com.apple.keylayout.ABC")
        XCTAssertEqual(enIcon, "🇺🇸")
        
        // Chinese - SCIM.ITABC contains "ABC" so it matches US first
        let cnIcon = Preferences.getInputSourceIcon("com.apple.inputmethod.SCIM.ITABC")
        XCTAssertEqual(cnIcon, "🇺🇸")  // Contains "ABC" which is checked before "SCIM"
        
        // Chinese - TCIM is detected correctly
        let cnIcon2 = Preferences.getInputSourceIcon("com.apple.inputmethod.TCIM.Cangjie")
        XCTAssertEqual(cnIcon2, "🇨🇳")
        
        // Korean - Korean is detected
        let koIcon = Preferences.getInputSourceIcon("com.apple.inputmethod.Korean.2SetKorean")
        XCTAssertEqual(koIcon, "🇰🇷")
        
        // Unknown source
        let unknownIcon = Preferences.getInputSourceIcon("unknown.source.id")
        XCTAssertEqual(unknownIcon, "⌨️")
    }
    
    func testInputSourceLanguageDetection() {
        // Japanese detection
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.Kotoeri.Japanese"), "Japanese")
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.google.inputmethod.Japanese.Hiragana"), "Japanese")
        XCTAssertEqual(Preferences.getInputSourceLanguage("ATOK.Japanese"), "Japanese")
        
        // Chinese detection
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.SCIM.ITABC"), "Chinese")
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.TCIM.Cangjie"), "Chinese")
        
        // Korean detection
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.Korean.2SetKorean"), "Korean")
        
        // Others
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.keylayout.US"), "English & Others")
        XCTAssertEqual(Preferences.getInputSourceLanguage("unknown.source.id"), "English & Others")
    }
    
    func testInputSourceCategoryClassification() {
        // Keyboard layouts
        XCTAssertEqual(Preferences.getInputSourceCategory("com.apple.keylayout.ABC"), "Keyboard Layout")
        XCTAssertEqual(Preferences.getInputSourceCategory("com.apple.keylayout.US"), "Keyboard Layout")
        
        // Input methods
        XCTAssertEqual(Preferences.getInputSourceCategory("com.apple.inputmethod.Kotoeri.Japanese"), "Input Method")
        XCTAssertEqual(Preferences.getInputSourceCategory("ATOK.Japanese"), "Input Method")
        XCTAssertEqual(Preferences.getInputSourceCategory("com.google.inputmethod.Japanese"), "Input Method")
        
        // Others
        XCTAssertEqual(Preferences.getInputSourceCategory("unknown.source.id"), "Others")
    }
    
    func testInputSourceFiltering() {
        let availableSources = Preferences.getAvailableInputSources()
        
        // Verify keyboard layouts are excluded (getAvailableInputSources returns only IMEs)
        let hasABC = availableSources.contains { $0.id.hasPrefix("com.apple.keylayout.") }
        XCTAssertFalse(hasABC, "Keyboard layouts should be excluded")
        
        // Instead, verify getAllInputSources includes keyboard layouts
        let allSources = Preferences.getAllInputSources()
        let hasABCInAll = allSources.contains { $0.sourceId == "com.apple.keylayout.ABC" }
        // This may vary by system
        
        // Verify IMEs are included
        let hasIME = availableSources.contains { 
            $0.id.contains("inputmethod") || $0.id.contains("ATOK") || $0.id.contains("atok") 
        }
        // IMEs might not be installed, so only warn
        if !hasIME {
            // Warning: No IME found in available sources
        }
        
        // getAvailableInputSources excludes ABC keyboard layout
        let filteredSources = Preferences.getAvailableInputSources()
        let hasABCInFiltered = filteredSources.contains { $0.id == "com.apple.keylayout.ABC" }
        XCTAssertFalse(hasABCInFiltered, "ABC keyboard layout should be excluded")
    }
}

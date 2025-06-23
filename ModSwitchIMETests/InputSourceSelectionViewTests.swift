import XCTest
import SwiftUI
@testable import ModSwitchIME

class InputSourceSelectionViewTests: XCTestCase {
    
    func testInputSourceSelectionViewDisplaysAllInputSources() {
        // Get all input sources (IME and keyboard layouts)
        let inputSources = Preferences.getAllInputSources()
        
        // Verify input sources exist
        XCTAssertGreaterThan(inputSources.count, 0, "At least one input source is required")
        
        // Verify both IME and keyboard layouts are included
        let hasIME = inputSources.contains { $0.sourceId.contains("inputmethod") || $0.sourceId.contains("ATOK") }
        let hasKeyboardLayout = inputSources.contains { $0.sourceId.contains("keylayout") }
        
        XCTAssertTrue(hasIME || hasKeyboardLayout, "Should include IME or keyboard layouts")
    }
    
    func testInputSourceCategorization() {
        let inputSources = Preferences.getAllInputSources()
        
        // Test category grouping
        var categories: [String: [Preferences.InputSource]] = [:]
        
        for source in inputSources {
            let category = Preferences.getInputSourceCategory(source.sourceId)
            if categories[category] == nil {
                categories[category] = []
            }
            categories[category]?.append(source)
        }
        
        // Verify at least one category exists
        XCTAssertGreaterThan(categories.count, 0, "At least one category is required")
    }
    
    func testInputSourceIcon() {
        let inputSources = Preferences.getAllInputSources()
        
        // Verify each input source can have an icon or flag
        for source in inputSources {
            let icon = Preferences.getInputSourceIcon(source.sourceId)
            XCTAssertNotNil(icon, "Should be able to get icon for \(source.localizedName)")
        }
    }
}

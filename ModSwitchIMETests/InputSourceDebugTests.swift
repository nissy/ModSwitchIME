import XCTest
import Carbon
@testable import ModSwitchIME

class InputSourceDebugTests: XCTestCase {
    
    func testDebugAllInputSources() {
        // Get all input sources
        guard let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            XCTFail("Failed to get input source list")
            return
        }
        
        // === All input sources list ===
        // Total count: \(inputSourceList.count)
        
        for (index, inputSource) in inputSourceList.enumerated() {
            debugPrintInputSource(inputSource, index: index)
        }
        
        // Find Japanese input
        debugJapaneseInputSources(inputSourceList)
    }
    
    private func debugPrintInputSource(_ inputSource: TISInputSource, index: Int) {
        // --- Input source #\(index + 1) ---
        
        // ID
        if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
            let cfString = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue()
            // ID: \(cfString as String)
        }
        
        // Localized name
        if let localizedName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
            let cfString = Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue()
            // Name: \(cfString as String)
        }
        
        debugPrintInputSourceProperties(inputSource)
    }
    
    private func debugPrintInputSourceProperties(_ inputSource: TISInputSource) {
        // Category
        if let category = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) {
            let cfString = Unmanaged<CFString>.fromOpaque(category).takeUnretainedValue()
            // Category: \(cfString as String)
        }
        
        // Type
        if let type = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceType) {
            let cfString = Unmanaged<CFString>.fromOpaque(type).takeUnretainedValue()
            // Type: \(cfString as String)
        }
        
        // Is selectable
        if let selectablePtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
            let selectable = Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()
            // Is selectable: \(CFBooleanGetValue(selectable))
        }
        
        // Is enabled
        if let enabledPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled) {
            let enabled = Unmanaged<CFBoolean>.fromOpaque(enabledPtr).takeUnretainedValue()
            // Is enabled: \(CFBooleanGetValue(enabled))
        }
    }
    
    private func debugJapaneseInputSources(_ inputSourceList: [TISInputSource]) {
        // === Search for Japanese input ===
        let japaneseInputs = inputSourceList.filter { inputSource in
            if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let cfString = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue() as String
                return cfString.contains("Kotoeri") || cfString.contains("Japanese")
            }
            return false
        }
        
        // Number of Japanese inputs: \(japaneseInputs.count)
        for input in japaneseInputs {
            if let sourceId = TISGetInputSourceProperty(input, kTISPropertyInputSourceID) {
                let cfString = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue()
                // - \(cfString as String)
            }
        }
    }
    
    func testDebugSelectableInputMethods() {
        // Test with the same logic as Preferences.getAvailableInputSources()
        guard let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            XCTFail("Failed to get input source list")
            return
        }
        
        // === Selectable input methods ===
        
        var selectableCount = 0
        for inputSource in inputSourceList {
            guard let selectablePtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable),
                  CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()) else {
                continue
            }
            
            selectableCount += 1
            
            if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
               let localizedName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                let id = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue() as String
                let name = Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue() as String
                // \(selectableCount). \(name) (\(id))
            }
        }
        
        // Total count of selectable input sources: \(selectableCount)
    }
    
    func testDebugInputMethodsOnly() {
        guard let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            XCTFail("Failed to get input source list")
            return
        }
        
        // === Input methods only (filter by category) ===
        
        var inputMethodCount = 0
        for inputSource in inputSourceList {
            // Check category
            guard let categoryPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) else {
                continue
            }
            let category = Unmanaged<CFString>.fromOpaque(categoryPtr).takeUnretainedValue() as String
            
            // Target only input method category
            if category != (kTISCategoryKeyboardInputSource as String) {
                continue
            }
            
            inputMethodCount += 1
            
            if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
               let localizedName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                let id = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue() as String
                let name = Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue() as String
                // \(inputMethodCount). \(name) (\(id))
                
                // Also check if selectable
                if let selectablePtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
                    let selectable = CFBooleanGetValue(
                        Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()
                    )
                    // Is selectable: \(selectable)
                }
            }
        }
        
        // Total count of input methods: \(inputMethodCount)
    }
}

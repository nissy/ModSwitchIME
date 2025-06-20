import Foundation
import Carbon

// MARK: - InputSourceManager

/// Manages input source discovery and categorization
struct InputSourceManager {
    
    // MARK: - Input Source Discovery
    
    /// Check if an IME ID appears to be a child of a parent IME
    static func isChildIME(_ id: String) -> Bool {
        // Common patterns for child IMEs across different input methods:
        // 1. Contains a mode suffix after the main IME name
        // 2. Has multiple dots in the identifier indicating hierarchy
        
        let modePatterns = [
            // Japanese modes
            ".Japanese", ".Hiragana", ".Katakana", ".Roman", ".FullWidth", ".HalfWidth",
            // Chinese modes
            ".Simplified", ".Traditional", ".Pinyin", ".Wubi", ".Zhuyin", ".Cangjie",
            // Korean modes
            ".Hangul", ".Hanja", ".2SetKorean", ".3SetKorean",
            // Other common modes
            ".ABC", ".QWERTY", ".Dvorak", ".Colemak"
        ]
        
        // Check if the ID contains any mode pattern
        for pattern in modePatterns where id.contains(pattern) {
            // Additional check: ensure it has a parent prefix (multiple dots)
            let dotCount = id.filter { $0 == "." }.count
            if dotCount >= 3 { // e.g., com.apple.inputmethod.Kotoeri.Japanese
                return true
            }
        }
        
        return false
    }
    
    /// Get the parent IME ID from a child IME ID
    static func getParentIMEId(_ childId: String) -> String? {
        // Try to extract parent ID by removing the last component after the last dot
        // that matches a known mode pattern
        let modePatterns = [
            ".Japanese", ".Hiragana", ".Katakana", ".Roman", ".FullWidth", ".HalfWidth",
            ".Simplified", ".Traditional", ".Pinyin", ".Wubi", ".Zhuyin", ".Cangjie",
            ".Hangul", ".Hanja", ".2SetKorean", ".3SetKorean",
            ".ABC", ".QWERTY", ".Dvorak", ".Colemak"
        ]
        
        for pattern in modePatterns {
            if let range = childId.range(of: pattern) {
                return String(childId[..<range.lowerBound])
            }
        }
        
        return nil
    }
    
    /// Get the list of actually enabled input sources from system preferences
    static func getSystemEnabledInputSourceIDs() -> Set<String> {
        var enabledIDs = Set<String>()
        
        // Method 1: Check HIToolbox preferences for enabled input sources
        let hiToolboxDefaults = UserDefaults(suiteName: "com.apple.HIToolbox")
        if let appleEnabledInputSources = hiToolboxDefaults?.object(
            forKey: "AppleEnabledInputSources"
        ) as? [[String: Any]] {
            Logger.debug("Found \(appleEnabledInputSources.count) sources in HIToolbox preferences", category: .ime)
            for source in appleEnabledInputSources {
                Logger.debug("HIToolbox source: \(source)", category: .ime)
                if let bundleID = source["Bundle ID"] as? String {
                    enabledIDs.insert(bundleID)
                } else if let keyboardLayoutName = source["KeyboardLayout Name"] as? String {
                    // Handle keyboard layouts like ABC
                    if keyboardLayoutName == "ABC" {
                        enabledIDs.insert("com.apple.keylayout.ABC")
                    }
                }
            }
        } else {
            Logger.debug("No AppleEnabledInputSources found in HIToolbox preferences", category: .ime)
        }
        
        // Method 2: Also check TISCreateInputSourceList with includeAllInstalled = false
        // This gives us the actually active input sources
        if let enabledList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
            Logger.debug("TISCreateInputSourceList(false) returned \(enabledList.count) sources", category: .ime)
            for inputSource in enabledList {
                if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                    let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                    enabledIDs.insert(id)
                    
                    // Also check if this source is actually enabled
                    var isEnabled = false
                    if let enabledRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled) {
                        isEnabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(enabledRef).takeUnretainedValue())
                    }
                    Logger.debug("TIS enabled list: \(id), enabled flag: \(isEnabled)", category: .ime)
                }
            }
        }
        
        Logger.debug("Total system enabled input sources: \(enabledIDs.count) - \(enabledIDs)", category: .ime)
        return enabledIDs
    }
    
    static func getAllInputSources(includeDisabled: Bool = false) -> [Preferences.InputSource] {
        // Cache to avoid frequent expensive system calls
        struct Cache {
            static var enabledSources: [Preferences.InputSource] = []
            static var allSources: [Preferences.InputSource] = []
            static var lastCacheTime: Date = Date.distantPast
        }
        
        let now = Date()
        
        // Refresh cache every 10 seconds or when includeDisabled changes
        if now.timeIntervalSince(Cache.lastCacheTime) > 10.0 {
            Logger.debug("Refreshing input sources cache", category: .ime)
            
            // Ensure TISCreateInputSourceList is called on main thread
            if Thread.isMainThread {
                Cache.enabledSources = fetchInputSources(includeDisabled: false)
                Cache.allSources = fetchInputSources(includeDisabled: true)
                Cache.lastCacheTime = now
                
                Logger.debug("Cache refreshed successfully. Enabled: \(Cache.enabledSources.count), All: \(Cache.allSources.count)", category: .ime)
            } else {
                Logger.warning("getAllInputSources called from background thread, using old cache", category: .ime)
            }
        }
        
        return includeDisabled ? Cache.allSources : Cache.enabledSources
    }
    
    private static func fetchInputSources(includeDisabled: Bool) -> [Preferences.InputSource] {
        var sources: [Preferences.InputSource] = []
        
        Logger.debug("fetchInputSources called with includeDisabled: \(includeDisabled)", category: .ime)
        
        // Choose source list based on includeDisabled flag
        let includeAllInstalled = includeDisabled
        guard let inputSourcesList = TISCreateInputSourceList(nil, includeAllInstalled)?.takeRetainedValue(),
              let inputSources = inputSourcesList as? [TISInputSource] else {
            Logger.warning("TISCreateInputSourceList returned nil or invalid list", category: .ime)
            return sources
        }
        
        Logger.debug("TISCreateInputSourceList returned \(inputSources.count) sources", category: .ime)
        
        for (index, inputSource) in inputSources.enumerated() {
            autoreleasepool {
                // Get source ID
                guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                    Logger.debug("Skipping source \(index): no source ID", category: .ime)
                    return
                }
                
                let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                
                // Check if it's selectable
                if let selectableRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
                    do {
                        let selectable = Unmanaged<CFBoolean>.fromOpaque(selectableRef).takeUnretainedValue()
                        if !CFBooleanGetValue(selectable) {
                            Logger.debug("Skipping source \(id): not selectable", category: .ime)
                            return
                        }
                    } catch {
                        Logger.debug("Skipping source \(id): failed to check selectable", category: .ime)
                        return
                    }
                }
                
                // Get category
                guard let categoryRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) else {
                    Logger.debug("Skipping source \(id): no category", category: .ime)
                    return
                }
                
                let category: String
                do {
                    category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as String
                } catch {
                    Logger.debug("Skipping source \(id): failed to get category", category: .ime)
                    return
                }
                
                // Only include keyboard input sources (not palette input sources)
                guard category == (kTISCategoryKeyboardInputSource as String) else {
                    Logger.debug("Skipping source \(id): wrong category \(category)", category: .ime)
                    return
                }
                
                // Get enabled state
                var isEnabled = false
                if let enabledRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled) {
                    do {
                        isEnabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(enabledRef).takeUnretainedValue())
                    } catch {
                        Logger.debug("Failed to get enabled state for \(id), assuming disabled", category: .ime)
                        isEnabled = false
                    }
                }
                
                // Get localized name
                var name = id
                if let localizedNameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                    do {
                        name = Unmanaged<CFString>.fromOpaque(localizedNameRef).takeUnretainedValue() as String
                    } catch {
                        Logger.debug("Failed to get localized name for \(id), using ID", category: .ime)
                    }
                }
                
                // Filter out disabled sources when includeDisabled is false
                if !includeDisabled && !isEnabled {
                    Logger.debug("Skipping disabled source: \(id)", category: .ime)
                    return
                }
                
                Logger.debug("Adding source: \(id), name: \(name), enabled: \(isEnabled)", category: .ime)
                sources.append(Preferences.InputSource(sourceId: id, localizedName: name, isEnabled: isEnabled))
            }
        }
        
        let sortedSources = sources.sorted { $0.localizedName < $1.localizedName }
        Logger.debug("fetchInputSources returning \(sortedSources.count) sources", category: .ime)
        return sortedSources
    }
    
    // MARK: - Language Detection
    
    static func getInputSourceLanguage(_ sourceId: String) -> String {
        if isAsianLanguage(sourceId) {
            return detectAsianLanguage(sourceId)
        } else if isMiddleEasternLanguage(sourceId) {
            return detectMiddleEasternLanguage(sourceId)
        } else if isIndicLanguage(sourceId) {
            return "Indic Languages"
        } else if isCyrillicLanguage(sourceId) {
            return "Cyrillic Scripts"
        } else if isEuropeanLanguage(sourceId) {
            return "European Languages"
        } else {
            return "English & Others"
        }
    }
    
    // Helper function for Asian languages
    private static func isAsianLanguage(_ sourceId: String) -> Bool {
        return sourceId.contains("Japanese") || sourceId.contains("Kotoeri") ||
               sourceId.contains("ATOK") || sourceId.contains("atok") ||
               sourceId.contains("com.google.inputmethod.Japanese") ||
               sourceId.contains("Chinese") || sourceId.contains("TCIM") ||
               sourceId.contains("SCIM") || sourceId.contains("Pinyin") ||
               sourceId.contains("Cangjie") || sourceId.contains("Zhuyin") ||
               sourceId.contains("Wubi") || sourceId.contains("Stroke") ||
               sourceId.contains("Korean") || sourceId.contains("Hangul") ||
               sourceId.contains("Vietnamese") || sourceId.contains("Telex") ||
               sourceId.contains("VNI") || sourceId.contains("VIQR") ||
               sourceId.contains("Thai")
    }
    
    private static func detectAsianLanguage(_ sourceId: String) -> String {
        if sourceId.contains("Japanese") || sourceId.contains("Kotoeri") ||
           sourceId.contains("ATOK") || sourceId.contains("atok") ||
           sourceId.contains("com.google.inputmethod.Japanese") {
            return "Japanese"
        } else if sourceId.contains("Chinese") || sourceId.contains("TCIM") ||
                  sourceId.contains("SCIM") || sourceId.contains("Pinyin") ||
                  sourceId.contains("Cangjie") || sourceId.contains("Zhuyin") ||
                  sourceId.contains("Wubi") || sourceId.contains("Stroke") {
            return "Chinese"
        } else if sourceId.contains("Korean") || sourceId.contains("Hangul") {
            return "Korean"
        } else if sourceId.contains("Vietnamese") || sourceId.contains("Telex") ||
                  sourceId.contains("VNI") || sourceId.contains("VIQR") {
            return "Vietnamese"
        } else if sourceId.contains("Thai") {
            return "Thai"
        } else {
            return "Asian Language"
        }
    }
    
    // Helper function for Middle Eastern languages
    private static func isMiddleEasternLanguage(_ sourceId: String) -> Bool {
        return sourceId.contains("Arabic") || sourceId.contains("Hebrew")
    }
    
    private static func detectMiddleEasternLanguage(_ sourceId: String) -> String {
        if sourceId.contains("Arabic") {
            return "Arabic"
        } else if sourceId.contains("Hebrew") {
            return "Hebrew"
        } else {
            return "Middle Eastern Language"
        }
    }
    
    // Helper function for Indic languages
    private static func isIndicLanguage(_ sourceId: String) -> Bool {
        return sourceId.contains("Hindi") || sourceId.contains("Devanagari") ||
               sourceId.contains("Tamil") || sourceId.contains("Telugu") ||
               sourceId.contains("Bengali") || sourceId.contains("Bangla") ||
               sourceId.contains("Gujarati") || sourceId.contains("Kannada") ||
               sourceId.contains("Malayalam") || sourceId.contains("Marathi") ||
               sourceId.contains("Punjabi") || sourceId.contains("Sanskrit")
    }
    
    // Helper function for Cyrillic languages
    private static func isCyrillicLanguage(_ sourceId: String) -> Bool {
        return sourceId.contains("Russian") || sourceId.contains("Ukrainian") ||
               sourceId.contains("Bulgarian") || sourceId.contains("Serbian") ||
               sourceId.contains("Macedonian") || sourceId.contains("Belarusian")
    }
    
    // Helper function for European languages
    private static func isEuropeanLanguage(_ sourceId: String) -> Bool {
        return sourceId.contains("French") || sourceId.contains("German") ||
               sourceId.contains("Spanish") || sourceId.contains("Italian") ||
               sourceId.contains("Portuguese") || sourceId.contains("Dutch") ||
               sourceId.contains("Polish") || sourceId.contains("Czech") ||
               sourceId.contains("Hungarian") || sourceId.contains("Romanian") ||
               sourceId.contains("Greek") || sourceId.contains("Turkish")
    }
}

import Foundation
import Combine
import ServiceManagement
import Carbon
import CoreGraphics

// MARK: - InputSourceHelper

struct InputSourceHelper {
    // Helper function to get ATOK display name
    static func getATOKDisplayName(id: String, defaultName: String) -> String {
        guard id.contains("atok") else {
            return defaultName
        }
        
        if id.contains(".Japanese.Katakana") {
            return "ATOK - Katakana"
        } else if id.contains(".Japanese.FullWidthRoman") {
            return "ATOK - Full-width Roman"
        } else if id.contains(".Japanese.HalfWidthEiji") {
            return "ATOK - Half-width Eiji"
        } else if id.contains(".Roman") {
            return "ATOK - Roman"
        } else if id.hasSuffix(".Japanese") {
            return "ATOK - Hiragana"
        } else {
            return "ATOK - \(defaultName)"
        }
    }
    
    static func getInputSourceCategory(_ sourceId: String) -> String {
        if sourceId.hasPrefix("com.apple.keylayout.") {
            return "Keyboard Layout"
        } else if sourceId.contains("inputmethod") || sourceId.contains("ATOK") || sourceId.contains("google") {
            return "Input Method"
        } else {
            return "Others"
        }
    }
    
    static func getInputSourceIcon(_ sourceId: String) -> String? {
        let lowercased = sourceId.lowercased()
        
        // Check for specific patterns in order of priority
        if sourceId.contains("ABC") || sourceId.contains("US") {
            return "🇺🇸"
        } else if lowercased.contains("japanese") || lowercased.contains("kotoeri") || 
                  sourceId.contains("ATOK") || sourceId.contains("atok") ||
                  lowercased.contains("com.google.inputmethod.japanese") {
            return "🇯🇵"
        } else if lowercased.contains("korean") || lowercased.contains("hangul") {
            return "🇰🇷"
        } else if sourceId.contains("TCIM") || lowercased.contains("cangjie") || 
                  lowercased.contains("zhuyin") || lowercased.contains("stroke") {
            return "🇨🇳"
        } else if sourceId.contains("SCIM") || lowercased.contains("pinyin") || 
                  lowercased.contains("wubi") {
            return "🇨🇳"
        } else if lowercased.contains("vietnamese") || lowercased.contains("telex") ||
                  sourceId.contains("VNI") || sourceId.contains("VIQR") {
            return "🇻🇳"
        } else if lowercased.contains("thai") {
            return "🇹🇭"
        } else if lowercased.contains("arabic") {
            return "🇸🇦"
        } else if lowercased.contains("hebrew") {
            return "🇮🇱"
        } else if lowercased.contains("russian") || lowercased.contains("cyrillic") {
            return "🇷🇺"
        } else if lowercased.contains("french") {
            return "🇫🇷"
        } else if lowercased.contains("german") {
            return "🇩🇪"
        } else if lowercased.contains("spanish") {
            return "🇪🇸"
        } else if lowercased.contains("chinese") || sourceId.contains("中文") {
            return "🇨🇳"
        } else {
            return "⌨️"
        }
    }
}

// MARK: - ModifierKey

enum ModifierKey: String, CaseIterable, Codable {
    case leftControl
    case leftShift
    case leftOption
    case leftCommand
    case rightControl
    case rightShift
    case rightOption
    case rightCommand
    
    var displayName: String {
        switch self {
        case .leftControl: return "Left Control"
        case .leftShift: return "Left Shift"
        case .leftOption: return "Left Option"
        case .leftCommand: return "Left Command"
        case .rightControl: return "Right Control"
        case .rightShift: return "Right Shift"
        case .rightOption: return "Right Option"
        case .rightCommand: return "Right Command"
        }
    }
    
    var keyCode: Int64 {
        switch self {
        case .leftControl: return 59    // kVK_Control
        case .leftShift: return 56      // kVK_Shift
        case .leftOption: return 58     // kVK_Option
        case .leftCommand: return 55    // kVK_Command
        case .rightControl: return 62   // kVK_RightControl
        case .rightShift: return 60     // kVK_RightShift
        case .rightOption: return 61    // kVK_RightOption
        case .rightCommand: return 54   // kVK_RightCommand
        }
    }
    
    var flagMask: CGEventFlags {
        switch self {
        case .leftControl, .rightControl: return .maskControl
        case .leftShift, .rightShift: return .maskShift
        case .leftOption, .rightOption: return .maskAlternate
        case .leftCommand, .rightCommand: return .maskCommand
        }
    }
    
    static func from(keyCode: Int64) -> ModifierKey? {
        return ModifierKey.allCases.first { $0.keyCode == keyCode }
    }
}

// MARK: - Preferences

class Preferences: ObservableObject {
    static let shared = Preferences()
    
    // For testing purposes only
    internal static func createForTesting() -> Preferences {
        // Clear test-related UserDefaults to ensure clean state
        let keysToRemove = [
            "idleOffEnabled", "idleTimeout", "launchAtLogin", "motherImeId",
            "cmdKeyTimeout", "cmdKeyTimeoutEnabled", "idleReturnIME"
        ]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        return Preferences()
    }
    
    @Published var idleOffEnabled: Bool {
        didSet {
            Logger.debug("idleOffEnabled didSet called: \(idleOffEnabled)", category: .preferences)
            UserDefaults.standard.set(idleOffEnabled, forKey: "idleOffEnabled")
        }
    }
    
    @Published var idleTimeout: Double {
        didSet {
            UserDefaults.standard.set(idleTimeout, forKey: "idleTimeout")
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        }
    }
    
    @Published var motherImeId: String {
        didSet {
            UserDefaults.standard.set(motherImeId, forKey: "motherImeId")
        }
    }
    
    @Published var cmdKeyTimeout: Double {
        didSet {
            UserDefaults.standard.set(cmdKeyTimeout, forKey: "cmdKeyTimeout")
        }
    }
    
    @Published var cmdKeyTimeoutEnabled: Bool {
        didSet {
            UserDefaults.standard.set(cmdKeyTimeoutEnabled, forKey: "cmdKeyTimeoutEnabled")
        }
    }
    
    @Published var idleReturnIME: String? {
        didSet {
            if let ime = idleReturnIME {
                UserDefaults.standard.set(ime, forKey: "idleReturnIME")
            } else {
                UserDefaults.standard.removeObject(forKey: "idleReturnIME")
            }
        }
    }
    
    // Modifier key IME mappings
    @Published var modifierKeyMappings: [ModifierKey: String] = [:] {
        didSet {
            saveModifierKeyMappings()
        }
    }
    
    // Modifier key enabled states
    @Published var modifierKeyEnabled: [ModifierKey: Bool] = [:] {
        didSet {
            saveModifierKeyEnabled()
        }
    }
    
    private init() {
        self.idleOffEnabled = UserDefaults.standard.object(forKey: "idleOffEnabled") as? Bool ?? false
        self.idleTimeout = UserDefaults.standard.object(forKey: "idleTimeout") as? Double ?? 5.0
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
        self.motherImeId = UserDefaults.standard.object(forKey: "motherImeId") as? String ?? ""
        self.cmdKeyTimeout = UserDefaults.standard.object(forKey: "cmdKeyTimeout") as? Double ?? 0.3
        self.cmdKeyTimeoutEnabled = UserDefaults.standard.object(forKey: "cmdKeyTimeoutEnabled") as? Bool ?? true
        self.idleReturnIME = UserDefaults.standard.object(forKey: "idleReturnIME") as? String
        
        // Load modifier key mappings
        self.modifierKeyMappings = loadModifierKeyMappings()
        self.modifierKeyEnabled = loadModifierKeyEnabled()
        
        // Migrate old motherImeId to right command if mappings are empty
        if modifierKeyMappings.isEmpty && !motherImeId.isEmpty {
            modifierKeyMappings[.rightCommand] = motherImeId
        } else if motherImeId.isEmpty {
            motherImeId = detectDefaultCJKInputSource()
            modifierKeyMappings[.rightCommand] = motherImeId
        }
        
        // Set default for left command to English
        if modifierKeyMappings[.leftCommand] == nil {
            modifierKeyMappings[.leftCommand] = "com.apple.keylayout.ABC"
        }
    }
    
    private func detectDefaultCJKInputSource() -> String {
        // Get list of all input sources
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese" // Default fallback
        }
        
        // Priority list of CJK input methods
        let cjkPrefixes = [
            "com.apple.inputmethod.Kotoeri",     // Japanese
            "com.apple.inputmethod.SCIM",         // Simplified Chinese
            "com.apple.inputmethod.TCIM",         // Traditional Chinese
            "com.apple.inputmethod.Korean",       // Korean
            "com.apple.inputmethod.ChineseHandwriting",
            "com.apple.inputmethod.VietnameseIM"
        ]
        
        // Find the first available CJK input source
        for inputSource in inputSources {
            guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                continue
            }
            
            let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
            
            // Check if it's a CJK input method
            for prefix in cjkPrefixes where id.hasPrefix(prefix) {
                // Additional check: ensure it's selectable
                if let selectableRef = TISGetInputSourceProperty(
                    inputSource, 
                    kTISPropertyInputSourceIsSelectCapable
                ) {
                    let selectable = Unmanaged<CFBoolean>.fromOpaque(selectableRef).takeUnretainedValue()
                    if CFBooleanGetValue(selectable) {
                        return id
                    }
                }
            }
        }
        
        // If no CJK input source found, try to detect by current locale
        let currentLocale = Locale.current
        
        // Use macOS 13+ API (we're targeting macOS 15.0)
        let languageCode = currentLocale.language.languageCode?.identifier ?? ""
        
        switch languageCode {
        case "ja":
            return "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        case "zh":
            let regionCode = currentLocale.region?.identifier ?? ""
            if regionCode == "TW" || regionCode == "HK" {
                return "com.apple.inputmethod.TCIM.Cangjie"
            } else {
                return "com.apple.inputmethod.SCIM.ITABC"
            }
        case "ko":
            return "com.apple.inputmethod.Korean.2SetKorean"
        default:
            break
        }
        
        // Final fallback
        return "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
    }
    
    static func getAvailableInputSources() -> [(id: String, name: String)] {
        var sources: [(id: String, name: String)] = []
        
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return sources
        }
        
        for inputSource in inputSources {
            // Get source ID
            guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                continue
            }
            let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
            
            // Check if it's selectable
            if let selectableRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
                let selectable = Unmanaged<CFBoolean>.fromOpaque(selectableRef).takeUnretainedValue()
                if !CFBooleanGetValue(selectable) {
                    continue
                }
            }
            
            // Get category
            guard let categoryRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) else {
                continue
            }
            let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as String
            
            // Only include keyboard input sources (not palette input sources)
            guard category == (kTISCategoryKeyboardInputSource as String) else {
                continue
            }
            
            // Exclude pure keyboard layouts (not IMEs)
            // com.apple.keylayout.* are keyboard layouts, not input methods
            if id.hasPrefix("com.apple.keylayout.") {
                continue
            }
            
            // Get localized name
            var name = id
            if let localizedNameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                name = Unmanaged<CFString>.fromOpaque(localizedNameRef).takeUnretainedValue() as String
            }
            
            // Display ATOK modes individually
            let displayName = InputSourceHelper.getATOKDisplayName(id: id, defaultName: name)
            sources.append((id: id, name: displayName))
        }
        
        return sources.sorted { $0.name < $1.name }
    }
    
    // MARK: - Input Source Selection UI Support
    
    /// Check if an IME ID appears to be a child of a parent IME
    private static func isChildIME(_ id: String) -> Bool {
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
    private static func getParentIMEId(_ childId: String) -> String? {
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
    private static func getSystemEnabledInputSourceIDs() -> Set<String> {
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
    
    static func getAllInputSources(includeDisabled: Bool = false) -> [InputSource] {
        var sources: [InputSource] = []
        
        // Choose source list based on includeDisabled flag
        let includeAllInstalled = includeDisabled
        guard let inputSourcesList = TISCreateInputSourceList(nil, includeAllInstalled)?.takeRetainedValue(),
              let inputSources = inputSourcesList as? [TISInputSource] else {
            return sources
        }
        
        for inputSource in inputSources {
            // Get source ID
            guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                continue
            }
            let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
            
            // Check if it's selectable
            if let selectableRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
                let selectable = Unmanaged<CFBoolean>.fromOpaque(selectableRef).takeUnretainedValue()
                if !CFBooleanGetValue(selectable) {
                    continue
                }
            }
            
            // Get category
            guard let categoryRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) else {
                continue
            }
            let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as String
            
            // Only include keyboard input sources (not palette input sources)
            guard category == (kTISCategoryKeyboardInputSource as String) else {
                continue
            }
            
            // Get enabled state
            var isEnabled = false
            if let enabledRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled) {
                isEnabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(enabledRef).takeUnretainedValue())
            }
            
            // Get localized name
            var name = id
            if let localizedNameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                name = Unmanaged<CFString>.fromOpaque(localizedNameRef).takeUnretainedValue() as String
            }
            
            // Debug log for all IMEs
            Logger.debug("IME found: \(id), name: \(name), enabled: \(isEnabled), selectable: \(true)", category: .ime)
            
            // When includeDisabled is false, TISCreateInputSourceList(nil, false) 
            // should already return only enabled sources.
            // No additional filtering needed.
            
            sources.append(InputSource(sourceId: id, localizedName: name, isEnabled: isEnabled))
        }
        
        return sources.sorted { $0.localizedName < $1.localizedName }
    }
    
    
    // Public static methods that delegate to InputSourceHelper
    static func getInputSourceCategory(_ sourceId: String) -> String {
        return InputSourceHelper.getInputSourceCategory(sourceId)
    }
    
    static func getInputSourceIcon(_ sourceId: String) -> String? {
        return InputSourceHelper.getInputSourceIcon(sourceId)
    }
    
    // Input Source struct
    struct InputSource: Identifiable {
        let id = UUID()
        let sourceId: String
        let localizedName: String
        var isEnabled: Bool = true
    }
    
    // Detect language
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
    
    // MARK: - Modifier Key Mapping Persistence
    
    private func saveModifierKeyMappings() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(modifierKeyMappings) {
            UserDefaults.standard.set(data, forKey: "modifierKeyMappings")
        }
    }
    
    private func loadModifierKeyMappings() -> [ModifierKey: String] {
        guard let data = UserDefaults.standard.data(forKey: "modifierKeyMappings"),
              let mappings = try? JSONDecoder().decode([ModifierKey: String].self, from: data) else {
            return [:]
        }
        return mappings
    }
    
    private func saveModifierKeyEnabled() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(modifierKeyEnabled) {
            UserDefaults.standard.set(data, forKey: "modifierKeyEnabled")
        }
    }
    
    private func loadModifierKeyEnabled() -> [ModifierKey: Bool] {
        guard let data = UserDefaults.standard.data(forKey: "modifierKeyEnabled"),
              let enabled = try? JSONDecoder().decode([ModifierKey: Bool].self, from: data) else {
            return [:]
        }
        return enabled
    }
    
    // Get IME ID for a specific modifier key
    func getIME(for key: ModifierKey) -> String? {
        // Simply return the mapping if it exists
        return modifierKeyMappings[key]
    }
    
    // Set IME ID for a specific modifier key
    func setIME(_ imeId: String?, for key: ModifierKey) {
        if let imeId = imeId, !imeId.isEmpty {
            modifierKeyMappings[key] = imeId
        } else {
            modifierKeyMappings.removeValue(forKey: key)
        }
    }
    
    // Check if a modifier key is enabled
    func isKeyEnabled(_ key: ModifierKey) -> Bool {
        return modifierKeyEnabled[key] ?? false
    }
    
    // Set enabled state for a modifier key
    func setKeyEnabled(_ enabled: Bool, for key: ModifierKey) {
        modifierKeyEnabled[key] = enabled
    }
}

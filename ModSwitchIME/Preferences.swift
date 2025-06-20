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
        
        // Dictionary mapping patterns to icons
        let iconMappings: [(patterns: [String], icon: String)] = [
            (["ABC", "US"], "🇺🇸"),
            (["japanese", "kotoeri", "ATOK", "atok", "com.google.inputmethod.japanese"], "🇯🇵"),
            (["korean", "hangul"], "🇰🇷"),
            (["TCIM", "cangjie", "zhuyin", "stroke"], "🇨🇳"),
            (["SCIM", "pinyin", "wubi"], "🇨🇳"),
            (["vietnamese", "telex", "VNI", "VIQR"], "🇻🇳"),
            (["thai"], "🇹🇭"),
            (["arabic"], "🇸🇦"),
            (["hebrew"], "🇮🇱"),
            (["russian", "cyrillic"], "🇷🇺"),
            (["french"], "🇫🇷"),
            (["german"], "🇩🇪"),
            (["spanish"], "🇪🇸"),
            (["chinese", "中文"], "🇨🇳")
        ]
        
        // Check each mapping
        for (patterns, icon) in iconMappings {
            for pattern in patterns {
                if pattern.contains(where: { $0.isUppercase }) {
                    // Check original case for uppercase patterns
                    if sourceId.contains(pattern) {
                        return icon
                    }
                } else {
                    // Check lowercase for lowercase patterns
                    if lowercased.contains(pattern) {
                        return icon
                    }
                }
            }
        }
        
        return "⌨️"
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
            
            // Filter out disabled sources when includeDisabled is false
            if !includeDisabled && !isEnabled {
                continue
            }
            
            // Get localized name
            var name = id
            if let localizedNameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                name = Unmanaged<CFString>.fromOpaque(localizedNameRef).takeUnretainedValue() as String
            }
            
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
    
    static func getInputSourceLanguage(_ sourceId: String) -> String {
        return InputSourceManager.getInputSourceLanguage(sourceId)
    }
    
    // Input Source struct
    struct InputSource: Identifiable {
        let id = UUID()
        let sourceId: String
        let localizedName: String
        var isEnabled: Bool = true
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

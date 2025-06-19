import Foundation
import Combine
import ServiceManagement
import Carbon
import CoreGraphics

// MARK: - ModifierKey

enum ModifierKey: String, CaseIterable, Codable {
    case leftControl = "leftControl"
    case leftShift = "leftShift"
    case leftOption = "leftOption"
    case leftCommand = "leftCommand"
    case rightControl = "rightControl"
    case rightShift = "rightShift"
    case rightOption = "rightOption"
    case rightCommand = "rightCommand"
    
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
    @Published var idleOffEnabled: Bool {
        didSet {
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
    
    
    
    init() {
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
            if id.contains("atok") {
                // Display with mode name
                if id.contains(".Japanese.Katakana") {
                    sources.append((id: id, name: "ATOK - Katakana"))
                } else if id.contains(".Japanese.FullWidthRoman") {
                    sources.append((id: id, name: "ATOK - Full-width Roman"))
                } else if id.contains(".Japanese.HalfWidthEiji") {
                    sources.append((id: id, name: "ATOK - Half-width Eiji"))
                } else if id.contains(".Roman") {
                    sources.append((id: id, name: "ATOK - Roman"))
                } else if id.hasSuffix(".Japanese") {
                    sources.append((id: id, name: "ATOK - Hiragana"))
                } else {
                    sources.append((id: id, name: "ATOK - \(name)"))
                }
            } else {
                sources.append((id: id, name: name))
            }
        }
        
        return sources.sorted { $0.name < $1.name }
    }
    
    // MARK: - Input Source Selection UI Support
    
    static func getAllInputSources(includeDisabled: Bool = false) -> [InputSource] {
        var sources: [InputSource] = []
        
        // Always get all input sources, then filter by enabled state
        // Note: TISCreateInputSourceList(nil, false) doesn't return all enabled IMEs
        guard let inputSourcesList = TISCreateInputSourceList(nil, true)?.takeRetainedValue(),
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
            
            // Filter by enabled state if includeDisabled is false
            if !includeDisabled && !isEnabled {
                continue
            }
            
            sources.append(InputSource(sourceId: id, localizedName: name, isEnabled: isEnabled))
        }
        
        return sources.sorted { $0.localizedName < $1.localizedName }
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
        // Simple icon/emoji mapping
        if sourceId.contains("Japanese") || sourceId.contains("ATOK") || sourceId.contains("Kotoeri") {
            return "🇯🇵"
        } else if sourceId.contains("ABC") || sourceId.contains("US") {
            return "🇺🇸"
        } else if sourceId.contains("Chinese") || sourceId.contains("TCIM") || sourceId.contains("SCIM") {
            return "🇨🇳"
        } else if sourceId.contains("Korean") {
            return "🇰🇷"
        } else {
            return "⌨️"
        }
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
        // Japanese
        if sourceId.contains("Japanese") || sourceId.contains("Kotoeri") || 
           sourceId.contains("ATOK") || sourceId.contains("atok") ||
           sourceId.contains("com.google.inputmethod.Japanese") {
            return "Japanese"
        }
        // Chinese
        else if sourceId.contains("Chinese") || sourceId.contains("TCIM") || 
                sourceId.contains("SCIM") || sourceId.contains("Pinyin") ||
                sourceId.contains("Cangjie") || sourceId.contains("Zhuyin") ||
                sourceId.contains("Wubi") || sourceId.contains("Stroke") {
            return "Chinese"
        }
        // Korean
        else if sourceId.contains("Korean") || sourceId.contains("Hangul") {
            return "Korean"
        }
        // Vietnamese
        else if sourceId.contains("Vietnamese") || sourceId.contains("Telex") ||
                sourceId.contains("VNI") || sourceId.contains("VIQR") {
            return "Vietnamese"
        }
        // Arabic
        else if sourceId.contains("Arabic") {
            return "Arabic"
        }
        // Hebrew
        else if sourceId.contains("Hebrew") {
            return "Hebrew"
        }
        // Thai
        else if sourceId.contains("Thai") {
            return "Thai"
        }
        // Indic languages
        else if sourceId.contains("Hindi") || sourceId.contains("Devanagari") ||
                sourceId.contains("Tamil") || sourceId.contains("Telugu") ||
                sourceId.contains("Bengali") || sourceId.contains("Bangla") ||
                sourceId.contains("Gujarati") || sourceId.contains("Kannada") ||
                sourceId.contains("Malayalam") || sourceId.contains("Marathi") ||
                sourceId.contains("Punjabi") || sourceId.contains("Sanskrit") {
            return "Indic Languages"
        }
        // Cyrillic scripts
        else if sourceId.contains("Russian") || sourceId.contains("Ukrainian") ||
                sourceId.contains("Bulgarian") || sourceId.contains("Serbian") ||
                sourceId.contains("Macedonian") || sourceId.contains("Belarusian") {
            return "Cyrillic Scripts"
        }
        // European languages
        else if sourceId.contains("French") || sourceId.contains("German") ||
                sourceId.contains("Spanish") || sourceId.contains("Italian") ||
                sourceId.contains("Portuguese") || sourceId.contains("Dutch") ||
                sourceId.contains("Polish") || sourceId.contains("Czech") ||
                sourceId.contains("Hungarian") || sourceId.contains("Romanian") ||
                sourceId.contains("Greek") || sourceId.contains("Turkish") {
            return "European Languages"
        }
        // English and others
        else {
            return "English & Others"
        }
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

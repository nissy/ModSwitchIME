import Foundation
import Carbon
import CoreGraphics

class ImeController {
    private let preferences = Preferences.shared
    
    private func switchToEnglish() {
        let englishSources = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        
        for sourceID in englishSources {
            do {
                try selectInputSource(sourceID)
                Logger.debug("Switched to English: \(sourceID)", category: .ime)
                return
            } catch {
                // Try next
            }
        }
        
        Logger.error("Failed to switch to English", category: .ime)
    }
    
    func forceAscii() {
        switchToEnglish()
    }
    
    func toggleByCmd(isLeft: Bool) {
        Logger.debug("Cmd toggle: \(isLeft ? "left" : "right")", category: .ime)
        
        if isLeft {
            // Left cmd: Switch to English
            switchToEnglish()
        } else {
            // Right cmd: Switch to configured IME
            let targetIME = preferences.motherImeId
            
            if !targetIME.isEmpty {
                do {
                    try selectInputSource(targetIME)
                } catch {
                    Logger.error("Failed to switch to \(targetIME): \(error)", category: .ime)
                }
            } else {
                Logger.warning("No native IME configured", category: .ime)
            }
        }
    }
    
    func switchToSpecificIME(_ imeId: String) {
        Logger.debug("Switching to IME: \(imeId)", category: .ime)
        
        if !imeId.isEmpty {
            do {
                try selectInputSource(imeId)
            } catch {
                Logger.error("Failed to switch to \(imeId): \(error)", category: .ime)
            }
        } else {
            Logger.warning("Empty IME ID provided", category: .ime)
        }
    }
    
    private var inputSourceCache: [String: TISInputSource] = [:]
    
    func selectInputSource(_ inputSourceID: String) throws {
        // Get current input source
        let currentSource = getCurrentInputSource()
        
        // Skip if same source
        if currentSource == inputSourceID {
            return
        }
        
        // Check cache first
        if let cachedSource = inputSourceCache[inputSourceID] {
            
            // Apply workaround when switching within the same IME family
            let currentFamily = getIMEFamily(currentSource)
            let targetFamily = getIMEFamily(inputSourceID)
            
            if currentFamily == targetFamily && currentFamily != "com.apple.keylayout" {
                // Switch to English first, then to target mode
                if let englishSource = inputSourceCache["com.apple.keylayout.ABC"] {
                    TISSelectInputSource(englishSource)
                    // Wait a bit
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            
            TISSelectInputSource(cachedSource)
            
            // Verify input source after change
            verifyInputSourceSwitch(targetID: inputSourceID, source: cachedSource)
            return
        }
        
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            throw ModSwitchIMEError.systemError(
                NSError(
                    domain: "ModSwitchIME", 
                    code: 1, 
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get input source list"]
                )
            )
        }
        
        var found = false
        for inputSource in inputSources {
            if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let cfStringRef = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue()
                let sourceIDString = String(cfStringRef)
                
                // Cache all sources for future use
                inputSourceCache[sourceIDString] = inputSource
                
                if sourceIDString == inputSourceID {
                    TISSelectInputSource(inputSource)
                    found = true
                    
                    // Verify input source after change
                    verifyInputSourceSwitch(targetID: inputSourceID, source: inputSource)
                }
            }
        }
        
        if !found {
            throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
        }
    }
    
    // Helper function to reduce complexity
    private func getIMEFamily(_ sourceID: String) -> String {
        return sourceID.components(separatedBy: ".").prefix(3).joined(separator: ".")
    }
    
    // Helper function to verify input source switch
    private func verifyInputSourceSwitch(targetID: String, source: TISInputSource) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newSource = self.getCurrentInputSource()
            
            if newSource != targetID {
                Logger.error("Failed to switch. Expected: \(targetID), Actual: \(newSource)", category: .ime)
                
                // Retry for same IME family
                let targetFamily = self.getIMEFamily(targetID)
                if targetFamily != "com.apple.keylayout" {
                    TISSelectInputSource(source)
                }
            }
        }
    }
    
    func getCurrentInputSource() -> String {
        guard let currentSource = TISCopyCurrentKeyboardInputSource() else {
            return "Unknown"
        }
        
        let source = currentSource.takeRetainedValue()
        
        if let sourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            let cfString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue()
            return cfString as String
        }
        
        return "Unknown"
    }
}

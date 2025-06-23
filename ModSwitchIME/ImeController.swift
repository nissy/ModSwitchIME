import Foundation
import Carbon
import CoreGraphics

class ImeController: ErrorHandler {
    private let preferences = Preferences.shared
    var onError: ((ModSwitchIMEError) -> Void)?
    
    // Cache for input sources with size limit
    private var inputSourceCache: [String: TISInputSource] = [:]
    private let cacheQueue = DispatchQueue(label: "com.modswitchime.cache", attributes: .concurrent)
    private let maxCacheSize = 50 // Maximum number of cached input sources
    
    // Cache refresh timer
    private var cacheRefreshTimer: Timer?
    private let cacheRefreshInterval: TimeInterval = 30.0 // Refresh cache every 30 seconds
    
    init() {
        // Initialize cache
        refreshInputSourceCache()
        
        // Disabled automatic cache refresh for performance
        // startCacheRefreshTimer()
    }
    
    deinit {
        cacheRefreshTimer?.invalidate()
    }
    
    private func startCacheRefreshTimer() {
        cacheRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: cacheRefreshInterval, 
            repeats: true
        ) { [weak self] _ in
            self?.refreshInputSourceCache()
        }
    }
    
    private func refreshInputSourceCache() {
        // All TIS functions must be called on main thread
        DispatchQueue.main.async {
            guard let inputSources = TISCreateInputSourceList(nil, false)?
                .takeRetainedValue() as? [TISInputSource] else {
                return
            }
            
            // Process input sources on main thread
            var cacheData: [String: TISInputSource] = [:]
            var addedCount = 0
            
            for inputSource in inputSources {
                // Stop if we've reached the cache limit
                if addedCount >= self.maxCacheSize {
                    break
                }
                
                if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                    let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                    
                    // Only cache enabled input sources to save memory
                    if let enabled = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled) {
                        let cfBoolean = Unmanaged<CFBoolean>.fromOpaque(enabled).takeUnretainedValue()
                        let isEnabled = CFBooleanGetValue(cfBoolean)
                        if isEnabled {
                            cacheData[id] = inputSource
                            addedCount += 1
                        }
                    }
                }
            }
            
            // Update cache on background thread
            self.cacheQueue.async(flags: .barrier) {
                // Clear existing cache to free memory
                self.inputSourceCache.removeAll(keepingCapacity: false)
                // Update with new data
                self.inputSourceCache = cacheData
                
                // Cache refreshed with new sources
            }
        }
    }
    
    private func switchToEnglish() {
        let englishSources = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        
        for sourceID in englishSources {
            do {
                try selectInputSource(sourceID)
                // Successfully switched to English
                return
            } catch {
                // Try next
            }
        }
        
        let error = ModSwitchIMEError.inputSourceNotFound("English input source")
        handleError(error)
    }
    
    func forceAscii() {
        switchToEnglish()
    }
    
    func toggleByCmd(isLeft: Bool) {
        // Toggle IME based on left/right Cmd
        
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
                    let imeError = ModSwitchIMEError.inputSourceNotFound(targetIME)
                    handleError(imeError)
                }
            } else {
                let error = ModSwitchIMEError.invalidConfiguration
                handleError(error)
            }
        }
    }
    
    func switchToSpecificIME(_ imeId: String) {
        // Skip empty IME ID check first for performance
        guard !imeId.isEmpty else {
            Logger.warning("Empty IME ID provided", category: .ime)
            return
        }
        
        // Get current input source before switching
        let currentIME = getCurrentInputSource()
        
        // If switching to the same IME, skip
        if currentIME == imeId {
            // Already on target IME, skipping switch
            return
        }
        
        do {
            try selectInputSource(imeId)
            
            // Verify the switch happened
            let newID = getCurrentInputSource()
            if newID != imeId {
                Logger.warning("IME switch may have failed: requested \(imeId), got \(newID)", category: .ime)
            }
        } catch {
            let imeError = ModSwitchIMEError.inputSourceNotFound(imeId)
            handleError(imeError)
        }
    }
    
    private func getAlternativeIME(excluding: String) -> String? {
        // Try to find an alternative IME for temporary switching
        if excluding != "com.apple.keylayout.ABC" {
            return "com.apple.keylayout.ABC"
        }
        // Find any other available IME
        for (id, _) in inputSourceCache {
            if id != excluding {
                return id
            }
        }
        return nil
    }
    
    func selectInputSource(_ inputSourceID: String) throws {
        // Check cache first for fast path
        if let cachedSource = inputSourceCache[inputSourceID] {
            TISSelectInputSource(cachedSource)
            
            // Debug: Verify the switch actually happened
            let newID = getCurrentInputSource()
            if newID != inputSourceID {
                Logger.warning("IME switch failed: requested \(inputSourceID), got \(newID)", category: .ime)
            }
            
            return
        }
        
        // Source not in cache, find it directly
        // TIS APIs are actually thread-safe for read operations
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
        }
        
        // Find the target source
        for inputSource in inputSources {
            if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                if id == inputSourceID {
                    TISSelectInputSource(inputSource)
                    
                    // Update cache without blocking
                    inputSourceCache[inputSourceID] = inputSource
                    
                    // Debug: Verify the switch actually happened
                    let newID = getCurrentInputSource()
                    if newID != inputSourceID {
                        Logger.warning("IME switch failed: requested \(inputSourceID), got \(newID)", category: .ime)
                    }
                    
                    return
                }
            }
        }
        
        throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
    }
    
    private func performSwitch(from currentID: String, to targetID: String, source: TISInputSource) throws {
        let currentFamily = getIMEFamily(currentID)
        let targetFamily = getIMEFamily(targetID)
        
        // Optimized workaround for same IME family switching
        if currentFamily == targetFamily && currentFamily != "com.apple.keylayout" {
            // Use a faster approach: deactivate current then activate target
            if let currentSource = cacheQueue.sync(execute: { inputSourceCache[currentID] }) {
                TISDeselectInputSource(currentSource)
            }
            
            // Direct switch without delay for better performance
            TISSelectInputSource(source)
            return
        }
        
        // Select the target input source immediately
        TISSelectInputSource(source)
        // Skip verification for better performance
    }
    
    private func verifyInputSourceSwitchAsync(targetID: String, source: TISInputSource) {
        // Removed for performance optimization
        // Verification was causing delays in the switching process
    }
    
    // Helper function to reduce complexity
    private func getIMEFamily(_ sourceID: String) -> String {
        let components = sourceID.components(separatedBy: ".")
        if components.count >= 3 {
            return components.prefix(3).joined(separator: ".")
        }
        return sourceID
    }
    
    func getCurrentInputSource() -> String {
        // TIS APIs must be called on main thread
        if Thread.isMainThread {
            return getCurrentInputSourceSync()
        } else {
            return DispatchQueue.main.sync {
                return getCurrentInputSourceSync()
            }
        }
    }
    
    private func getCurrentInputSourceSync() -> String {
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
    
    // Removed findInputSource methods - integrated into selectInputSource for better performance
    
    // MARK: - ErrorHandler
    
    func handleError(_ error: ModSwitchIMEError) {
        logError(error, category: .ime)
        onError?(error)
    }
}

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
    
    // Cache refresh timer - disabled for performance
    
    init() {
        // Initialize cache
        refreshInputSourceCache()
        
        // Disabled automatic cache refresh for performance
        // startCacheRefreshTimer()
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
            }
        }
    }
    
    private func switchToEnglish() {
        let englishSources = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        
        for sourceID in englishSources {
            do {
                try selectInputSource(sourceID)
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
    
    // Removed toggleByCmd - no longer used after architecture changes
    
    func switchToSpecificIME(_ imeId: String) {
        // Skip empty IME ID check first for performance
        guard !imeId.isEmpty else {
            Logger.warning("Empty IME ID provided", category: .ime)
            return
        }
        
        // Direct switch without checking current IME for better performance
        // TIS API handles switching to the same IME efficiently
        do {
            try selectInputSource(imeId)
        } catch {
            let imeError = ModSwitchIMEError.inputSourceNotFound(imeId)
            handleError(imeError)
        }
    }
    
    func selectInputSource(_ inputSourceID: String) throws {
        // Check cache first for fast path
        if let cachedSource = inputSourceCache[inputSourceID] {
            TISSelectInputSource(cachedSource)
            
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
                    
                    return
                }
            }
        }
        
        throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
    }
    
    // Removed performSwitch and related methods - no longer needed after simplification
    
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
    
    // MARK: - ErrorHandler
    
    func handleError(_ error: ModSwitchIMEError) {
        logError(error, category: .ime)
        onError?(error)
    }
}

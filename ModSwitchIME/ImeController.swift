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
        
        // Start cache refresh timer
        startCacheRefreshTimer()
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
                
                Logger.debug(
                    "Cache refreshed: \(self.inputSourceCache.count) sources (limit: \(self.maxCacheSize))", 
                    category: .ime
                )
            }
        }
    }
    
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
        
        let error = ModSwitchIMEError.inputSourceNotFound("English input source")
        handleError(error)
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
        Logger.debug("Switching to IME: \(imeId)", category: .ime)
        
        if !imeId.isEmpty {
            do {
                try selectInputSource(imeId)
            } catch {
                let imeError = ModSwitchIMEError.inputSourceNotFound(imeId)
                handleError(imeError)
            }
        } else {
            Logger.warning("Empty IME ID provided", category: .ime)
        }
    }
    
    func selectInputSource(_ inputSourceID: String) throws {
        // Get current input source
        let currentSource = getCurrentInputSource()
        
        // Skip if same source
        if currentSource == inputSourceID {
            return
        }
        
        // Get cached source
        let cachedSource = cacheQueue.sync {
            return inputSourceCache[inputSourceID]
        }
        
        if let source = cachedSource {
            // Optimized switching logic
            try performSwitch(from: currentSource, to: inputSourceID, source: source)
        } else {
            // Source not in cache, add it if we have room
            if let newSource = findInputSource(inputSourceID) {
                cacheQueue.async(flags: .barrier) {
                    // Check cache size before adding
                    if self.inputSourceCache.count < self.maxCacheSize {
                        self.inputSourceCache[inputSourceID] = newSource
                    } else {
                        // Cache is full, remove least recently used (simple FIFO for now)
                        if let firstKey = self.inputSourceCache.keys.first {
                            self.inputSourceCache.removeValue(forKey: firstKey)
                        }
                        self.inputSourceCache[inputSourceID] = newSource
                    }
                }
                try performSwitch(from: currentSource, to: inputSourceID, source: newSource)
            } else {
                throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
            }
        }
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
            
            // Small delay without blocking main thread
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                // Continue with switch after delay
                TISSelectInputSource(source)
                self.verifyInputSourceSwitchAsync(targetID: targetID, source: source)
            }
            return
        }
        
        // Select the target input source
        TISSelectInputSource(source)
        
        // Verify the switch asynchronously
        verifyInputSourceSwitchAsync(targetID: targetID, source: source)
    }
    
    private func verifyInputSourceSwitchAsync(targetID: String, source: TISInputSource) {
        // Non-blocking verification with appropriate delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            let newSource = self.getCurrentInputSource()
            
            if newSource != targetID {
                Logger.warning("First switch attempt failed. Expected: \(targetID), Actual: \(newSource)", category: .ime)
                
                // Immediate retry
                TISSelectInputSource(source)
                
                // Final verification after retry
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    let finalSource = self.getCurrentInputSource()
                    
                    if finalSource != targetID {
                        Logger.error(
                            "Failed to switch after retry. Expected: \(targetID), Actual: \(finalSource)", 
                            category: .ime
                        )
                    }
                }
            }
        }
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
        // Ensure TIS API calls are on main thread
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
    
    // Helper function to find a specific input source
    private func findInputSource(_ inputSourceID: String) -> TISInputSource? {
        // Ensure TIS API calls are on main thread
        if Thread.isMainThread {
            return findInputSourceSync(inputSourceID)
        } else {
            return DispatchQueue.main.sync {
                return findInputSourceSync(inputSourceID)
            }
        }
    }
    
    private func findInputSourceSync(_ inputSourceID: String) -> TISInputSource? {
        guard let inputSources = TISCreateInputSourceList(nil, false)?
            .takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        
        for inputSource in inputSources {
            if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                if id == inputSourceID {
                    return inputSource
                }
            }
        }
        
        return nil
    }
    
    // MARK: - ErrorHandler
    
    func handleError(_ error: ModSwitchIMEError) {
        logError(error, category: .ime)
        onError?(error)
    }
}
